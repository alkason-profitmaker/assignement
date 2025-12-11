// Expire Orders Edge Function
// Scheduled function to expire pending orders past their expiry time
// Run via cron: Every 15 minutes
// Supabase cron config: */15 * * * *

import { serve } from 'https://deno.land/std@0.177.0/http/server.ts'
import { createClient } from 'https://esm.sh/@supabase/supabase-js@2'

const corsHeaders = {
  'Access-Control-Allow-Origin': '*',
  'Access-Control-Allow-Headers': 'authorization, x-client-info, apikey, content-type',
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

    const now = new Date().toISOString()
    console.log(`[${now}] Running order expiry check...`)

    // Find all expired pending orders
    const { data: expiredOrders, error: fetchError } = await supabaseClient
      .from('orders')
      .select('id, user_id, paytm_order_id, final_amount_paise, credits_used_paise')
      .eq('payment_status', 'PENDING')
      .lt('expires_at', now)

    if (fetchError) {
      console.error('Error fetching expired orders:', fetchError)
      throw fetchError
    }

    if (!expiredOrders || expiredOrders.length === 0) {
      console.log('No expired orders found')
      return new Response(
        JSON.stringify({ success: true, message: 'No expired orders', expiredCount: 0 }),
        { headers: { ...corsHeaders, 'Content-Type': 'application/json' } }
      )
    }

    console.log(`Found ${expiredOrders.length} expired order(s)`)

    let expiredCount = 0
    let creditsRestoredCount = 0

    for (const order of expiredOrders) {
      // Mark order as expired (FAILED payment)
      const { error: updateError } = await supabaseClient
        .from('orders')
        .update({
          payment_status: 'FAILED',
          print_status: 'FAILED',
          print_error_code: 'ORDER_EXPIRED',
          updated_at: new Date().toISOString()
        })
        .eq('id', order.id)

      if (updateError) {
        console.error(`Failed to expire order ${order.id}:`, updateError)
        continue
      }

      expiredCount++
      console.log(`Expired order: ${order.id} (paytm: ${order.paytm_order_id})`)

      // Restore credits if any were used
      if (order.credits_used_paise > 0) {
        // Create a restoration credit entry
        const { error: creditError } = await supabaseClient
          .from('credits')
          .insert({
            user_id: order.user_id,
            pages_bw: 0,
            pages_color: 0,
            balance_paise: order.credits_used_paise,
            reason: `Credits restored - Order expired (${order.paytm_order_id})`,
            source_order_id: order.id,
            expires_at: new Date(Date.now() + 90 * 24 * 60 * 60 * 1000).toISOString() // 90 days
          })

        if (creditError) {
          console.error(`Failed to restore credits for order ${order.id}:`, creditError)
        } else {
          creditsRestoredCount++
          console.log(`Restored ${order.credits_used_paise} paise credits for user ${order.user_id}`)
        }
      }
    }

    const result = {
      success: true,
      message: `Expired ${expiredCount} orders`,
      expiredCount,
      creditsRestoredCount,
      timestamp: now
    }

    console.log('Expiry job complete:', JSON.stringify(result))

    return new Response(
      JSON.stringify(result),
      { headers: { ...corsHeaders, 'Content-Type': 'application/json' } }
    )

  } catch (error) {
    console.error('Order expiry error:', error)
    return new Response(
      JSON.stringify({ error: error.message }),
      { status: 500, headers: { ...corsHeaders, 'Content-Type': 'application/json' } }
    )
  }
})
