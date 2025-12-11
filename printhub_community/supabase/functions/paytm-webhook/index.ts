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

interface EpsonPrintSettings {
  media_size: string
  media_type: string
  color_mode: string
  copies: number
  print_quality: string
  borderless: boolean
  two_sided: string
  source: string
  collate: boolean
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
    const { error: updateError } = await supabaseClient
      .from('orders')
      .update({
        payment_status: 'PAID',
        paytm_txn_id: payload.TXNID,
        paid_at: new Date().toISOString(),
        print_status: 'QUEUED',
        updated_at: new Date().toISOString()
      })
      .eq('id', order.id)

    if (updateError) {
      console.error('Failed to update order:', updateError)
      throw updateError
    }

    // Get document from storage
    const documentBytes = await getDocumentFromStorage(supabaseClient, order.id)
    if (!documentBytes) {
      console.error('Document not found for order:', order.id)
      await initiateAutoRefund(supabaseClient, order, 'DOCUMENT_NOT_FOUND')
      return new Response(
        JSON.stringify({ success: false, message: 'Document not found, refund initiated' }),
        { headers: { ...corsHeaders, 'Content-Type': 'application/json' } }
      )
    }

    // Check printer status
    const printerStatus = await checkPrinterStatus(order.stations.epson_printer_email)

    if (!printerStatus.isOnline) {
      console.log('Printer offline, initiating refund')
      await initiateAutoRefund(supabaseClient, order, 'PRINTER_OFFLINE')
      return new Response(
        JSON.stringify({ success: false, message: 'Printer offline, refund initiated' }),
        { headers: { ...corsHeaders, 'Content-Type': 'application/json' } }
      )
    }

    // Submit print job to Epson Connect with document upload
    const printResult = await submitPrintJobWithDocument({
      printerEmail: order.stations.epson_printer_email,
      orderId: order.id,
      fileName: order.file_name,
      documentBytes: documentBytes,
      copies: order.copies,
      hasColor: order.color_pages > 0
    })

    if (!printResult.success) {
      console.log('Print job submission failed:', printResult.error)
      await initiateAutoRefund(supabaseClient, order, printResult.errorCode || 'PRINT_FAILED')
      return new Response(
        JSON.stringify({ success: false, message: 'Print failed, refund initiated' }),
        { headers: { ...corsHeaders, 'Content-Type': 'application/json' } }
      )
    }

    // Update order with print job ID
    await supabaseClient
      .from('orders')
      .update({
        epson_job_id: printResult.jobId,
        print_status: 'PRINTING',
        updated_at: new Date().toISOString()
      })
      .eq('id', order.id)

    // Schedule print status check (via separate scheduled function)
    await supabaseClient
      .from('print_job_queue')
      .insert({
        order_id: order.id,
        epson_job_id: printResult.jobId,
        printer_email: order.stations.epson_printer_email,
        check_count: 0,
        next_check_at: new Date(Date.now() + 30000).toISOString() // Check in 30 seconds
      })

    console.log('Print job submitted successfully:', printResult.jobId)

    return new Response(
      JSON.stringify({
        success: true,
        message: 'Payment processed and print job submitted',
        jobId: printResult.jobId
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

// Get document from Supabase Storage
async function getDocumentFromStorage(
  supabaseClient: any,
  orderId: string
): Promise<Uint8Array | null> {
  try {
    // Documents are stored as: documents/orders/{orderId}/document.pdf
    const { data, error } = await supabaseClient
      .storage
      .from('documents')
      .download(`orders/${orderId}/document.pdf`)

    if (error) {
      console.error('Storage download error:', error)
      return null
    }

    const arrayBuffer = await data.arrayBuffer()
    return new Uint8Array(arrayBuffer)
  } catch (error) {
    console.error('Document retrieval error:', error)
    return null
  }
}

// Verify Paytm webhook signature
async function verifyPaytmSignature(payload: PaytmWebhookPayload): Promise<boolean> {
  try {
    const merchantKey = Deno.env.get('PAYTM_MERCHANT_KEY')
    if (!merchantKey) {
      console.warn('PAYTM_MERCHANT_KEY not set, skipping signature verification')
      return true // For development
    }

    const { CHECKSUMHASH, ...params } = payload
    const sortedKeys = Object.keys(params).sort()
    const paramString = sortedKeys.map(k => `${k}=${params[k as keyof typeof params]}`).join('|')

    const encoder = new TextEncoder()
    const key = encoder.encode(merchantKey)
    const data = encoder.encode(paramString)

    const cryptoKey = await crypto.subtle.importKey(
      'raw',
      key,
      { name: 'HMAC', hash: 'SHA-256' },
      false,
      ['sign']
    )

    const signature = await crypto.subtle.sign('HMAC', cryptoKey, data)
    const expectedHash = btoa(String.fromCharCode(...new Uint8Array(signature)))

    return CHECKSUMHASH === expectedHash
  } catch (error) {
    console.error('Signature verification error:', error)
    return false
  }
}

// Check Epson printer status
async function checkPrinterStatus(printerEmail: string): Promise<{ isOnline: boolean; error?: string }> {
  try {
    const accessToken = await getEpsonAccessToken()
    if (!accessToken) {
      console.warn('No Epson access token')
      return { isOnline: true } // Assume online for development
    }

    const deviceId = printerEmail.split('@')[0]
    const response = await fetch(
      `https://api.epsonconnect.com/api/1/printing/printers/${deviceId}`,
      {
        headers: {
          'Authorization': `Bearer ${accessToken}`,
          'Content-Type': 'application/json'
        }
      }
    )

    if (!response.ok) {
      return { isOnline: false, error: 'Failed to get printer status' }
    }

    const data = await response.json()
    return {
      isOnline: data.connection === 'online',
      error: data.error_code
    }
  } catch (error) {
    console.error('Printer status check error:', error)
    return { isOnline: false, error: error.message }
  }
}

// Get Epson Connect OAuth access token
async function getEpsonAccessToken(): Promise<string | null> {
  try {
    const clientId = Deno.env.get('EPSON_CLIENT_ID')
    const clientSecret = Deno.env.get('EPSON_CLIENT_SECRET')
    const refreshToken = Deno.env.get('EPSON_REFRESH_TOKEN')

    if (!clientId || !clientSecret || !refreshToken) {
      return null
    }

    const response = await fetch('https://api.epsonconnect.com/api/1/printing/oauth2/token', {
      method: 'POST',
      headers: {
        'Content-Type': 'application/x-www-form-urlencoded'
      },
      body: new URLSearchParams({
        grant_type: 'refresh_token',
        client_id: clientId,
        client_secret: clientSecret,
        refresh_token: refreshToken
      })
    })

    if (!response.ok) {
      console.error('Failed to get Epson token')
      return null
    }

    const data = await response.json()
    return data.access_token
  } catch (error) {
    console.error('Epson token error:', error)
    return null
  }
}

// Submit print job to Epson Connect with document upload
async function submitPrintJobWithDocument(params: {
  printerEmail: string
  orderId: string
  fileName: string
  documentBytes: Uint8Array
  copies: number
  hasColor: boolean
}): Promise<{ success: boolean; jobId?: string; error?: string; errorCode?: string }> {
  try {
    const accessToken = await getEpsonAccessToken()
    if (!accessToken) {
      console.warn('EPSON access token not available, simulating success')
      return { success: true, jobId: `SIM_${Date.now()}` }
    }

    const deviceId = params.printerEmail.split('@')[0]

    // Step 1: Create print job
    console.log('Creating Epson print job...')
    const createResponse = await fetch(
      `https://api.epsonconnect.com/api/1/printing/printers/${deviceId}/jobs`,
      {
        method: 'POST',
        headers: {
          'Authorization': `Bearer ${accessToken}`,
          'Content-Type': 'application/json'
        },
        body: JSON.stringify({
          job_name: `PrintHub_${params.orderId}`,
          print_mode: 'document',
          print_setting: {
            media_size: 'ms_a4',
            media_type: 'mt_plainpaper',
            borderless: false,
            color_mode: params.hasColor ? 'color' : 'mono',
            two_sided: 'none',
            reverse_order: false,
            copies: params.copies,
            collate: true,
            print_quality: 'normal'
          } as EpsonPrintSettings
        })
      }
    )

    if (!createResponse.ok) {
      const errorData = await createResponse.json()
      console.error('Failed to create print job:', errorData)
      return {
        success: false,
        error: errorData.message || 'Failed to create print job',
        errorCode: errorData.code || 'EPSON_CREATE_ERROR'
      }
    }

    const jobData = await createResponse.json()
    const jobId = jobData.id
    const uploadUri = jobData.upload_uri

    console.log('Print job created:', jobId, 'Upload URI:', uploadUri)

    // Step 2: Upload document to the provided upload URI
    console.log('Uploading document...')
    const fileExtension = params.fileName.toLowerCase().endsWith('.pdf') ? 'pdf' :
                          params.fileName.toLowerCase().endsWith('.jpg') ||
                          params.fileName.toLowerCase().endsWith('.jpeg') ? 'jpeg' : 'pdf'

    const uploadResponse = await fetch(`${uploadUri}&File=1.${fileExtension}`, {
      method: 'POST',
      headers: {
        'Content-Type': `application/${fileExtension === 'pdf' ? 'pdf' : 'jpeg'}`,
        'Content-Length': params.documentBytes.length.toString()
      },
      body: params.documentBytes
    })

    if (!uploadResponse.ok) {
      const uploadError = await uploadResponse.text()
      console.error('Document upload failed:', uploadError)

      // Cancel the job since upload failed
      await cancelEpsonJob(accessToken, deviceId, jobId)

      return {
        success: false,
        error: 'Document upload failed',
        errorCode: 'EPSON_UPLOAD_ERROR'
      }
    }

    console.log('Document uploaded successfully')

    // Step 3: Execute the print job
    console.log('Executing print job...')
    const executeResponse = await fetch(
      `https://api.epsonconnect.com/api/1/printing/printers/${deviceId}/jobs/${jobId}/print`,
      {
        method: 'POST',
        headers: {
          'Authorization': `Bearer ${accessToken}`,
          'Content-Type': 'application/json'
        }
      }
    )

    if (!executeResponse.ok) {
      const executeError = await executeResponse.json()
      console.error('Job execution failed:', executeError)
      return {
        success: false,
        error: executeError.message || 'Job execution failed',
        errorCode: executeError.code || 'EPSON_EXECUTE_ERROR'
      }
    }

    console.log('Print job executed successfully')

    return {
      success: true,
      jobId: jobId
    }
  } catch (error) {
    console.error('Print job submission error:', error)
    return {
      success: false,
      error: error.message,
      errorCode: 'SUBMISSION_ERROR'
    }
  }
}

// Cancel an Epson print job
async function cancelEpsonJob(accessToken: string, deviceId: string, jobId: string): Promise<void> {
  try {
    await fetch(
      `https://api.epsonconnect.com/api/1/printing/printers/${deviceId}/jobs/${jobId}`,
      {
        method: 'DELETE',
        headers: {
          'Authorization': `Bearer ${accessToken}`
        }
      }
    )
  } catch (error) {
    console.error('Failed to cancel job:', error)
  }
}

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

// Generate Paytm checksum
async function generatePaytmChecksum(params: any, merchantKey: string): Promise<string> {
  const paramString = JSON.stringify(params)
  const encoder = new TextEncoder()
  const key = encoder.encode(merchantKey)
  const data = encoder.encode(paramString)

  const cryptoKey = await crypto.subtle.importKey(
    'raw',
    key,
    { name: 'HMAC', hash: 'SHA-256' },
    false,
    ['sign']
  )

  const signature = await crypto.subtle.sign('HMAC', cryptoKey, data)
  return btoa(String.fromCharCode(...new Uint8Array(signature)))
}
