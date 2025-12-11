// Station Poll API - Lightweight endpoint for ESP32/IoT devices
// Simple REST polling - no WebSocket complexity for microcontrollers

import { serve } from 'https://deno.land/std@0.177.0/http/server.ts'
import { createClient } from 'https://esm.sh/@supabase/supabase-js@2'

const corsHeaders = {
  'Access-Control-Allow-Origin': '*',
  'Access-Control-Allow-Headers': 'authorization, x-client-info, apikey, content-type, x-station-key',
}

interface StationPollResponse {
  has_order: boolean
  order?: {
    id: string
    order_number: number
    amount_rupees: number
    qr_data: string | null
    payment_status: string
    print_status: string
    created_at: string
  }
  station?: {
    id: string
    name: string
  }
  error?: string
}

serve(async (req: Request) => {
  // Handle CORS preflight
  if (req.method === 'OPTIONS') {
    return new Response('ok', { headers: corsHeaders })
  }

  try {
    const url = new URL(req.url)
    const stationId = url.searchParams.get('station_id')
    const stationKey = req.headers.get('x-station-key') || url.searchParams.get('key')

    // Validate required params
    if (!stationId) {
      return jsonResponse({ has_order: false, error: 'station_id required' }, 400)
    }

    const supabaseClient = createClient(
      Deno.env.get('SUPABASE_URL') ?? '',
      Deno.env.get('SUPABASE_SERVICE_ROLE_KEY') ?? ''
    )

    // Verify station exists and is active
    const { data: station, error: stationError } = await supabaseClient
      .from('stations')
      .select('id, name, is_active, station_api_key')
      .eq('id', stationId)
      .single()

    if (stationError || !station) {
      return jsonResponse({ has_order: false, error: 'Station not found' }, 404)
    }

    if (!station.is_active) {
      return jsonResponse({ has_order: false, error: 'Station inactive' }, 403)
    }

    // Verify station API key (if configured)
    if (station.station_api_key && station.station_api_key !== stationKey) {
      return jsonResponse({ has_order: false, error: 'Invalid station key' }, 401)
    }

    // Update last poll time for health monitoring (fire and forget)
    supabaseClient
      .from('stations')
      .update({ last_poll_at: new Date().toISOString() })
      .eq('id', stationId)
      .then(() => {})
      .catch(() => {}) // Ignore errors - this is non-critical

    // Get current pending order for this station
    const { data: orders, error: orderError } = await supabaseClient
      .from('orders')
      .select('id, order_number, final_amount_paise, qr_data, payment_status, print_status, created_at')
      .eq('station_id', stationId)
      .eq('payment_status', 'PENDING')
      .gt('expires_at', new Date().toISOString())
      .order('created_at', { ascending: false })
      .limit(1)

    if (orderError) {
      console.error('Order query error:', orderError)
      return jsonResponse({ has_order: false, error: 'Database error' }, 500)
    }

    // No pending orders
    if (!orders || orders.length === 0) {
      return jsonResponse({
        has_order: false,
        station: { id: station.id, name: station.name }
      })
    }

    const order = orders[0]

    // Return order data optimized for IoT display
    return jsonResponse({
      has_order: true,
      order: {
        id: order.id,
        order_number: order.order_number,
        amount_rupees: order.final_amount_paise / 100,
        qr_data: order.qr_data,
        payment_status: order.payment_status,
        print_status: order.print_status,
        created_at: order.created_at
      },
      station: {
        id: station.id,
        name: station.name
      }
    })

  } catch (error) {
    console.error('Station poll error:', error)
    return jsonResponse({ has_order: false, error: 'Server error' }, 500)
  }
})

function jsonResponse(data: StationPollResponse, status = 200): Response {
  return new Response(JSON.stringify(data), {
    status,
    headers: {
      ...corsHeaders,
      'Content-Type': 'application/json',
      'Cache-Control': 'no-cache, no-store, must-revalidate'
    }
  })
}
