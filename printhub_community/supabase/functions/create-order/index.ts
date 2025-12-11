// Create Order Edge Function
// Handles order creation and Paytm Dynamic QR generation
// IMPORTANT: This keeps the merchant key secure on server-side

import { serve } from 'https://deno.land/std@0.177.0/http/server.ts'
import { createClient } from 'https://esm.sh/@supabase/supabase-js@2'

const corsHeaders = {
  'Access-Control-Allow-Origin': '*',
  'Access-Control-Allow-Headers': 'authorization, x-client-info, apikey, content-type',
}

interface CreateOrderRequest {
  userId: string
  stationId: string
  fileName: string
  fileHash?: string
  totalPages: number
  bwPages: number
  colorPages: number
  copies: number
}

serve(async (req: Request) => {
  // Handle CORS preflight
  if (req.method === 'OPTIONS') {
    return new Response('ok', { headers: corsHeaders })
  }

  try {
    const supabaseClient = createClient(
      Deno.env.get('SUPABASE_URL') ?? '',
      Deno.env.get('SUPABASE_SERVICE_ROLE_KEY') ?? ''
    )

    const request: CreateOrderRequest = await req.json()
    console.log('Creating order:', JSON.stringify(request))

    // Validate request
    if (!request.userId || !request.stationId || !request.totalPages) {
      return new Response(
        JSON.stringify({ error: 'Missing required fields' }),
        { status: 400, headers: { ...corsHeaders, 'Content-Type': 'application/json' } }
      )
    }

    // Get station and society details for pricing
    const { data: station, error: stationError } = await supabaseClient
      .from('stations')
      .select('*, societies(*)')
      .eq('id', request.stationId)
      .single()

    if (stationError || !station) {
      console.error('Station not found:', stationError)
      return new Response(
        JSON.stringify({ error: 'Station not found' }),
        { status: 404, headers: { ...corsHeaders, 'Content-Type': 'application/json' } }
      )
    }

    if (!station.is_active) {
      return new Response(
        JSON.stringify({ error: 'Station is not active' }),
        { status: 400, headers: { ...corsHeaders, 'Content-Type': 'application/json' } }
      )
    }

    const society = station.societies

    // Calculate pricing
    const bwPricePerPage = society.bw_price_per_page_paise || 300
    const colorPricePerPage = society.color_price_per_page_paise || 1000

    const bwAmount = request.bwPages * bwPricePerPage * request.copies
    const colorAmount = request.colorPages * colorPricePerPage * request.copies
    const totalAmountPaise = bwAmount + colorAmount

    // Check for available credits
    const { data: credits } = await supabaseClient
      .from('credits')
      .select('*')
      .eq('user_id', request.userId)
      .gt('expires_at', new Date().toISOString())
      .order('expires_at', { ascending: true })

    let creditsUsedPaise = 0
    // TODO: Apply credits logic

    const finalAmountPaise = Math.max(0, totalAmountPaise - creditsUsedPaise)
    const finalAmountRupees = finalAmountPaise / 100

    // Generate unique order ID for Paytm
    const timestamp = Date.now()
    const randomSuffix = Math.random().toString(36).substring(2, 8).toUpperCase()
    const paytmOrderId = `PH_${station.id.substring(0, 8)}_${timestamp}_${randomSuffix}`

    // Create order in database
    const expiresAt = new Date(Date.now() + 4 * 60 * 60 * 1000) // 4 hours

    const { data: order, error: orderError } = await supabaseClient
      .from('orders')
      .insert({
        user_id: request.userId,
        society_id: society.id,
        station_id: request.stationId,
        file_name: request.fileName,
        file_hash: request.fileHash,
        total_pages: request.totalPages,
        bw_pages: request.bwPages,
        color_pages: request.colorPages,
        copies: request.copies,
        amount_paise: totalAmountPaise,
        credits_used_paise: creditsUsedPaise,
        final_amount_paise: finalAmountPaise,
        paytm_order_id: paytmOrderId,
        payment_status: 'PENDING',
        print_status: 'WAITING',
        expires_at: expiresAt.toISOString()
      })
      .select()
      .single()

    if (orderError) {
      console.error('Failed to create order:', orderError)
      throw orderError
    }

    console.log('Order created:', order.id)

    // Generate Paytm Dynamic QR
    let qrData = null
    const merchantId = Deno.env.get('PAYTM_MERCHANT_ID')
    const merchantKey = Deno.env.get('PAYTM_MERCHANT_KEY')
    const isProduction = Deno.env.get('ENVIRONMENT') === 'production'

    if (merchantId && merchantKey && finalAmountPaise > 0) {
      const paytmBaseUrl = isProduction
        ? 'https://securegw.paytm.in'
        : 'https://securegw-stage.paytm.in'

      const qrRequestBody = {
        mid: merchantId,
        orderId: paytmOrderId,
        amount: finalAmountRupees.toFixed(2),
        businessType: 'UPI_QR_CODE',
        posId: station.soundbox_id || `STATION_${station.id.substring(0, 8)}`
      }

      // Generate checksum using proper AES algorithm
      const checksum = await generatePaytmChecksum(qrRequestBody, merchantKey)

      const qrResponse = await fetch(`${paytmBaseUrl}/paymentservices/qr/create`, {
        method: 'POST',
        headers: {
          'Content-Type': 'application/json'
        },
        body: JSON.stringify({
          body: qrRequestBody,
          head: {
            signature: checksum
          }
        })
      })

      const qrResponseData = await qrResponse.json()
      console.log('Paytm QR response:', JSON.stringify(qrResponseData))

      const resultCode = qrResponseData.body?.resultInfo?.resultCode
      if (resultCode === '0000' || resultCode === 'SUCCESS') {
        qrData = {
          qrCodeId: qrResponseData.body?.qrCodeId,
          qrData: qrResponseData.body?.qrData,
          qrImage: qrResponseData.body?.image, // Base64 encoded QR image
          deepLink: qrResponseData.body?.deepLink
        }

        // Update order with QR code data for station display
        await supabaseClient
          .from('orders')
          .update({
            qr_data: qrResponseData.body?.qrData,
            qr_code_id: qrResponseData.body?.qrCodeId,
            updated_at: new Date().toISOString()
          })
          .eq('id', order.id)
      } else {
        console.error('Paytm QR generation failed:', qrResponseData.body?.resultInfo)
        // Continue without QR - can retry later
      }
    } else if (finalAmountPaise === 0) {
      // Free order - mark as paid immediately
      await supabaseClient
        .from('orders')
        .update({
          payment_status: 'PAID',
          print_status: 'AWAITING_DEVICE',
          paid_at: new Date().toISOString(),
          updated_at: new Date().toISOString()
        })
        .eq('id', order.id)

      qrData = { isFree: true }
    }

    return new Response(
      JSON.stringify({
        success: true,
        order: {
          id: order.id,
          orderNumber: order.order_number,
          paytmOrderId: paytmOrderId,
          amountPaise: totalAmountPaise,
          creditsUsedPaise: creditsUsedPaise,
          finalAmountPaise: finalAmountPaise,
          expiresAt: expiresAt.toISOString(),
          paymentStatus: order.payment_status,
          printStatus: order.print_status
        },
        qr: qrData,
        station: {
          id: station.id,
          name: station.name,
          location: station.location_description
        }
      }),
      { headers: { ...corsHeaders, 'Content-Type': 'application/json' } }
    )

  } catch (error) {
    console.error('Create order error:', error)
    return new Response(
      JSON.stringify({ error: error.message }),
      { status: 500, headers: { ...corsHeaders, 'Content-Type': 'application/json' } }
    )
  }
})

// ============================================
// Paytm Checksum Generation (AES-128-CBC)
// ============================================
// Paytm uses AES-128-CBC encryption for checksum
// Algorithm:
// 1. Sort parameters alphabetically and create pipe-separated string
// 2. Generate 16-byte random IV
// 3. Encrypt data using AES-128-CBC with PKCS7 padding
// 4. Prepend IV to encrypted data
// 5. Base64 encode the result

async function generatePaytmChecksum(
  params: Record<string, any>,
  merchantKey: string
): Promise<string> {
  // Sort parameters alphabetically and create pipe-separated string
  const sortedKeys = Object.keys(params).sort()
  const paramString = sortedKeys.map(k => `${k}=${params[k]}`).join('|')

  // Generate 16-byte random IV
  const iv = crypto.getRandomValues(new Uint8Array(16))

  // Prepare the key - Paytm expects 16-byte key
  const encoder = new TextEncoder()
  let keyBytes = encoder.encode(merchantKey)

  if (keyBytes.length > 16) {
    keyBytes = keyBytes.slice(0, 16)
  } else if (keyBytes.length < 16) {
    const paddedKey = new Uint8Array(16)
    paddedKey.set(keyBytes)
    keyBytes = paddedKey
  }

  // Import key for AES-CBC
  const cryptoKey = await crypto.subtle.importKey(
    'raw',
    keyBytes,
    { name: 'AES-CBC' },
    false,
    ['encrypt']
  )

  // Apply PKCS7 padding to data
  const dataBytes = encoder.encode(paramString)
  const padLength = 16 - (dataBytes.length % 16)
  const paddedData = new Uint8Array(dataBytes.length + padLength)
  paddedData.set(dataBytes)
  for (let i = dataBytes.length; i < paddedData.length; i++) {
    paddedData[i] = padLength
  }

  // Encrypt using AES-CBC
  const encrypted = await crypto.subtle.encrypt(
    { name: 'AES-CBC', iv },
    cryptoKey,
    paddedData
  )

  // Combine: IV (16 bytes) + Encrypted data
  const combined = new Uint8Array(iv.length + encrypted.byteLength)
  combined.set(iv)
  combined.set(new Uint8Array(encrypted), iv.length)

  // Base64 encode
  return btoa(String.fromCharCode(...combined))
}

// Verify Paytm checksum (for webhook verification)
async function verifyPaytmChecksum(
  params: Record<string, any>,
  checksum: string,
  merchantKey: string
): Promise<boolean> {
  try {
    // Decode base64 checksum
    const decoded = Uint8Array.from(atob(checksum), c => c.charCodeAt(0))

    // Extract IV (first 16 bytes) and encrypted data
    const iv = decoded.slice(0, 16)
    const encryptedData = decoded.slice(16)

    // Prepare the key
    const encoder = new TextEncoder()
    let keyBytes = encoder.encode(merchantKey)

    if (keyBytes.length > 16) {
      keyBytes = keyBytes.slice(0, 16)
    } else if (keyBytes.length < 16) {
      const paddedKey = new Uint8Array(16)
      paddedKey.set(keyBytes)
      keyBytes = paddedKey
    }

    // Import key for decryption
    const cryptoKey = await crypto.subtle.importKey(
      'raw',
      keyBytes,
      { name: 'AES-CBC' },
      false,
      ['decrypt']
    )

    // Decrypt
    const decrypted = await crypto.subtle.decrypt(
      { name: 'AES-CBC', iv },
      cryptoKey,
      encryptedData
    )

    // Remove PKCS7 padding
    const decryptedBytes = new Uint8Array(decrypted)
    const padLen = decryptedBytes[decryptedBytes.length - 1]
    const unpadded = decryptedBytes.slice(0, decryptedBytes.length - padLen)

    // Decode to string
    const decoder = new TextDecoder()
    const decryptedString = decoder.decode(unpadded)

    // Generate expected param string
    const sortedKeys = Object.keys(params).sort()
    const expectedString = sortedKeys.map(k => `${k}=${params[k]}`).join('|')

    return decryptedString === expectedString
  } catch (error) {
    console.error('Checksum verification failed:', error)
    return false
  }
}
