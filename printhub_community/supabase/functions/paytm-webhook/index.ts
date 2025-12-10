// Paytm Payment Webhook Handler
// This Edge Function receives payment confirmation from Paytm Soundbox
// and triggers the print job automatically

import { serve } from 'https://deno.land/std@0.177.0/http/server.ts'
import { createClient } from 'https://esm.sh/@supabase/supabase-js@2'
import { crypto } from 'https://deno.land/std@0.177.0/crypto/mod.ts'

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

interface PrintJobRequest {
  orderId: string
  stationId: string
  documentBytes: string // Base64 encoded
  fileName: string
  copies: number
  hasColor: boolean
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

    // Get order details
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

    // Submit print job to Epson Connect
    const printResult = await submitPrintJob({
      printerEmail: order.stations.epson_printer_email,
      orderId: order.id,
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
    const accessToken = Deno.env.get('EPSON_ACCESS_TOKEN')
    if (!accessToken) {
      console.warn('EPSON_ACCESS_TOKEN not set')
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

// Submit print job to Epson Connect
async function submitPrintJob(params: {
  printerEmail: string
  orderId: string
  copies: number
  hasColor: boolean
}): Promise<{ success: boolean; jobId?: string; error?: string; errorCode?: string }> {
  try {
    const accessToken = Deno.env.get('EPSON_ACCESS_TOKEN')
    if (!accessToken) {
      console.warn('EPSON_ACCESS_TOKEN not set, simulating success')
      return { success: true, jobId: `SIM_${Date.now()}` }
    }

    const deviceId = params.printerEmail.split('@')[0]

    // Create print job
    const createResponse = await fetch(
      `https://api.epsonconnect.com/api/1/printing/printers/${deviceId}/jobs`,
      {
        method: 'POST',
        headers: {
          'Authorization': `Bearer ${accessToken}`,
          'Content-Type': 'application/json'
        },
        body: JSON.stringify({
          job_name: params.orderId,
          print_setting: {
            media_size: 'ms_a4',
            media_type: 'plain',
            color_mode: params.hasColor ? 'color' : 'mono',
            copies: params.copies,
            print_quality: 'normal'
          }
        })
      }
    )

    if (!createResponse.ok) {
      const errorData = await createResponse.json()
      return {
        success: false,
        error: errorData.message || 'Failed to create print job',
        errorCode: errorData.error_code || 'EPSON_ERROR'
      }
    }

    const jobData = await createResponse.json()
    return {
      success: true,
      jobId: jobData.id
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

    if (merchantId && merchantKey) {
      const refundId = `REF_${order.id}_${Date.now()}`
      const refundResponse = await fetch('https://securegw.paytm.in/refund/apply', {
        method: 'POST',
        headers: {
          'Content-Type': 'application/json',
          'Authorization': `Bearer ${merchantKey}`
        },
        body: JSON.stringify({
          mid: merchantId,
          orderId: order.paytm_order_id,
          txnId: order.paytm_txn_id,
          refId: refundId,
          refundAmount: (order.final_amount_paise / 100).toFixed(2)
        })
      })

      const refundData = await refundResponse.json()
      console.log('Refund response:', refundData)

      // Update with refund ID
      await supabaseClient
        .from('orders')
        .update({
          paytm_refund_id: refundId,
          refund_status: 'COMPLETED',
          updated_at: new Date().toISOString()
        })
        .eq('id', order.id)
    }

    // Add goodwill credit
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
        payment_status: 'REFUNDED',
        updated_at: new Date().toISOString()
      })
      .eq('id', order.id)

    console.log('Refund processed for order:', order.id)
  } catch (error) {
    console.error('Refund error:', error)
    throw error
  }
}
