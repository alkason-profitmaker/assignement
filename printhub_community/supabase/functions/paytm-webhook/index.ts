// Paytm Payment Webhook Handler
// This Edge Function receives payment confirmation from Paytm Soundbox
// and triggers the print job automatically

import { serve } from 'https://deno.land/std@0.177.0/http/server.ts'
import { createClient } from 'https://esm.sh/@supabase/supabase-js@2'
import { crypto } from 'https://deno.land/std@0.177.0/crypto/mod.ts'
import { decode as base64Decode } from 'https://deno.land/std@0.177.0/encoding/base64.ts'

const corsHeaders = {
  'Access-Control-Allow-Origin': '*',
  'Access-Control-Allow-Headers': 'authorization, x-client-info, apikey, content-type',
}

interface PaytmWebhookPayload {
  ORDERID: string
  TXNID: string
  STATUS: string
  TXNAMOUNT: string
  PAYMENTMODE: string
  TXNDATE: string
  CHECKSUMHASH: string
  MID: string
}

// NOTE: EpsonPrintSettings removed - printing handled by mobile app

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

    // Parse webhook payload
    const payload: PaytmWebhookPayload = await req.json()
    console.log('Received Paytm webhook:', JSON.stringify(payload))

    // Validate webhook signature
    const isValid = await verifyPaytmSignature(payload)
    if (!isValid) {
      console.error('Invalid webhook signature')
      return new Response(
        JSON.stringify({ error: 'Invalid signature' }),
        { status: 401, headers: { ...corsHeaders, 'Content-Type': 'application/json' } }
      )
    }

    // Check payment status
    if (payload.STATUS !== 'TXN_SUCCESS') {
      console.log('Payment not successful:', payload.STATUS)

      // Update order as failed
      await supabaseClient
        .from('orders')
        .update({
          payment_status: 'FAILED',
          print_error_code: `PAYMENT_${payload.STATUS}`,
          updated_at: new Date().toISOString()
        })
        .eq('paytm_order_id', payload.ORDERID)

      return new Response(
        JSON.stringify({ success: false, message: 'Payment not successful' }),
        { headers: { ...corsHeaders, 'Content-Type': 'application/json' } }
      )
    }

    // Get order details with document
    const { data: order, error: orderError } = await supabaseClient
      .from('orders')
      .select('*, stations(*), societies(*)')
      .eq('paytm_order_id', payload.ORDERID)
      .single()

    if (orderError || !order) {
      console.error('Order not found:', payload.ORDERID)
      return new Response(
        JSON.stringify({ error: 'Order not found' }),
        { status: 404, headers: { ...corsHeaders, 'Content-Type': 'application/json' } }
      )
    }

    // Verify amount matches
    const expectedAmount = (order.final_amount_paise / 100).toFixed(2)
    if (payload.TXNAMOUNT !== expectedAmount) {
      console.error('Amount mismatch:', payload.TXNAMOUNT, expectedAmount)
      return new Response(
        JSON.stringify({ error: 'Amount mismatch' }),
        { status: 400, headers: { ...corsHeaders, 'Content-Type': 'application/json' } }
      )
    }

    // Check if already processed
    if (order.payment_status === 'PAID') {
      console.log('Order already processed:', order.id)
      return new Response(
        JSON.stringify({ success: true, message: 'Already processed' }),
        { headers: { ...corsHeaders, 'Content-Type': 'application/json' } }
      )
    }

    // Update order as paid
    // PRIVACY: Document is NOT stored on server
    // The mobile app will detect this status change via Supabase realtime
    // and send the document directly from device to Epson printer
    const { error: updateError } = await supabaseClient
      .from('orders')
      .update({
        payment_status: 'PAID',
        paytm_txn_id: payload.TXNID,
        paid_at: new Date().toISOString(),
        print_status: 'AWAITING_DEVICE', // App will send document to printer
        updated_at: new Date().toISOString()
      })
      .eq('id', order.id)

    if (updateError) {
      console.error('Failed to update order:', updateError)
      throw updateError
    }

    console.log('Payment confirmed for order:', order.id)
    console.log('Awaiting mobile app to send document directly to printer')

    return new Response(
      JSON.stringify({
        success: true,
        message: 'Payment confirmed. Device will send document to printer.',
        orderId: order.id
      }),
      { headers: { ...corsHeaders, 'Content-Type': 'application/json' } }
    )

  } catch (error) {
    console.error('Webhook error:', error)
    return new Response(
      JSON.stringify({ error: error.message }),
      { status: 500, headers: { ...corsHeaders, 'Content-Type': 'application/json' } }
    )
  }
})

// NOTE: Document storage functions removed for privacy compliance
// Documents are NEVER stored on the server
// Mobile app sends documents directly to Epson printer after payment confirmation

// Verify Paytm webhook signature using AES-128-CBC
// Paytm checksums are encrypted with AES, not HMAC
async function verifyPaytmSignature(payload: PaytmWebhookPayload): Promise<boolean> {
  try {
    const merchantKey = Deno.env.get('PAYTM_MERCHANT_KEY')
    if (!merchantKey) {
      console.warn('PAYTM_MERCHANT_KEY not set, skipping signature verification')
      return true // For development only
    }

    const { CHECKSUMHASH, ...params } = payload

    // Decode base64 checksum
    const decoded = Uint8Array.from(atob(CHECKSUMHASH), c => c.charCodeAt(0))

    // Extract IV (first 16 bytes) and encrypted data
    const iv = decoded.slice(0, 16)
    const encryptedData = decoded.slice(16)

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
    const expectedString = sortedKeys.map(k => `${k}=${params[k as keyof typeof params]}`).join('|')

    const isValid = decryptedString === expectedString
    if (!isValid) {
      console.log('Checksum mismatch - expected:', expectedString)
      console.log('Checksum mismatch - got:', decryptedString)
    }

    return isValid
  } catch (error) {
    console.error('Signature verification error:', error)
    return false
  }
}

// NOTE: Epson printer functions removed - all Epson communication handled by mobile app
// This keeps documents on-device (privacy) and reduces server-side complexity

// NOTE: Print job submission functions removed - printing is handled by mobile app
// This webhook only confirms payment status
// Mobile app detects payment via Supabase realtime and sends document directly to Epson

// Initiate automatic refund for failed prints
async function initiateAutoRefund(
  supabaseClient: any,
  order: any,
  reason: string
): Promise<void> {
  try {
    // Update order status
    await supabaseClient
      .from('orders')
      .update({
        print_status: 'FAILED',
        print_error_code: reason,
        refund_status: 'INITIATED',
        refund_reason: reason,
        refund_type: 'AUTO',
        updated_at: new Date().toISOString()
      })
      .eq('id', order.id)

    // Call Paytm refund API
    const merchantId = Deno.env.get('PAYTM_MERCHANT_ID')
    const merchantKey = Deno.env.get('PAYTM_MERCHANT_KEY')
    const isProduction = Deno.env.get('ENVIRONMENT') === 'production'

    if (merchantId && merchantKey && order.paytm_txn_id) {
      const refundId = `REF_${order.id.substring(0, 8)}_${Date.now()}`
      const refundUrl = isProduction
        ? 'https://securegw.paytm.in/refund/apply'
        : 'https://securegw-stage.paytm.in/refund/apply'

      // Generate checksum for refund request
      const refundParams = {
        body: {
          mid: merchantId,
          orderId: order.paytm_order_id,
          txnId: order.paytm_txn_id,
          refId: refundId,
          refundAmount: (order.final_amount_paise / 100).toFixed(2)
        }
      }

      const checksum = await generatePaytmChecksum(refundParams.body, merchantKey)

      const refundResponse = await fetch(refundUrl, {
        method: 'POST',
        headers: {
          'Content-Type': 'application/json'
        },
        body: JSON.stringify({
          ...refundParams,
          head: {
            signature: checksum
          }
        })
      })

      const refundData = await refundResponse.json()
      console.log('Refund response:', JSON.stringify(refundData))

      const refundSuccess = refundData.body?.resultInfo?.resultStatus === 'TXN_SUCCESS' ||
                           refundData.body?.resultInfo?.resultStatus === 'PENDING'

      // Update with refund status
      await supabaseClient
        .from('orders')
        .update({
          paytm_refund_id: refundId,
          refund_status: refundSuccess ? 'COMPLETED' : 'FAILED',
          updated_at: new Date().toISOString()
        })
        .eq('id', order.id)

      if (refundSuccess) {
        // Update payment status to refunded
        await supabaseClient
          .from('orders')
          .update({
            payment_status: 'REFUNDED',
            updated_at: new Date().toISOString()
          })
          .eq('id', order.id)
      }
    }

    // Add goodwill credit regardless of refund success
    await supabaseClient
      .from('credits')
      .insert({
        user_id: order.user_id,
        pages_bw: 1,
        pages_color: 0,
        reason: `Goodwill credit for failed print: ${reason}`,
        source_order_id: order.id,
        expires_at: new Date(Date.now() + 90 * 24 * 60 * 60 * 1000).toISOString() // 90 days
      })

    // Mark credit given
    await supabaseClient
      .from('orders')
      .update({
        goodwill_credit_given: true,
        updated_at: new Date().toISOString()
      })
      .eq('id', order.id)

    console.log('Refund processed for order:', order.id)
  } catch (error) {
    console.error('Refund error:', error)
    throw error
  }
}

// Generate Paytm checksum using AES-128-CBC
// Algorithm: Sort params -> pipe-separate -> encrypt with AES -> prepend IV -> base64
async function generatePaytmChecksum(params: Record<string, any>, merchantKey: string): Promise<string> {
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
