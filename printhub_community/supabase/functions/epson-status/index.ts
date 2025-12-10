// Epson Printer Status Checker
// This Edge Function checks printer status and updates station health

import { serve } from 'https://deno.land/std@0.177.0/http/server.ts'
import { createClient } from 'https://esm.sh/@supabase/supabase-js@2'

const corsHeaders = {
  'Access-Control-Allow-Origin': '*',
  'Access-Control-Allow-Headers': 'authorization, x-client-info, apikey, content-type',
}

interface PrinterStatus {
  isOnline: boolean
  inkLevel: number
  paperLevel: number
  hasPaperJam: boolean
  errorCode: string | null
  errorMessage: string | null
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

    const { stationId, printerEmail } = await req.json()

    if (!stationId && !printerEmail) {
      return new Response(
        JSON.stringify({ error: 'stationId or printerEmail required' }),
        { status: 400, headers: { ...corsHeaders, 'Content-Type': 'application/json' } }
      )
    }

    let targetPrinterEmail = printerEmail

    // If stationId provided, get printer email from station
    if (stationId && !printerEmail) {
      const { data: station, error } = await supabaseClient
        .from('stations')
        .select('epson_printer_email')
        .eq('id', stationId)
        .single()

      if (error || !station) {
        return new Response(
          JSON.stringify({ error: 'Station not found' }),
          { status: 404, headers: { ...corsHeaders, 'Content-Type': 'application/json' } }
        )
      }

      targetPrinterEmail = station.epson_printer_email
    }

    // Check printer status
    const status = await checkPrinterStatus(targetPrinterEmail)

    // Update station health check timestamp
    if (stationId) {
      await supabaseClient
        .from('stations')
        .update({
          last_health_check: new Date().toISOString(),
          is_active: status.isOnline && !status.hasPaperJam
        })
        .eq('id', stationId)
    }

    return new Response(
      JSON.stringify({
        success: true,
        status: {
          ...status,
          printerEmail: targetPrinterEmail,
          checkedAt: new Date().toISOString()
        }
      }),
      { headers: { ...corsHeaders, 'Content-Type': 'application/json' } }
    )

  } catch (error) {
    console.error('Status check error:', error)
    return new Response(
      JSON.stringify({ error: error.message }),
      { status: 500, headers: { ...corsHeaders, 'Content-Type': 'application/json' } }
    )
  }
})

// Check Epson printer status via Epson Connect API
async function checkPrinterStatus(printerEmail: string): Promise<PrinterStatus> {
  try {
    const accessToken = Deno.env.get('EPSON_ACCESS_TOKEN')

    if (!accessToken) {
      console.warn('EPSON_ACCESS_TOKEN not set, returning mock status')
      return {
        isOnline: true,
        inkLevel: 80,
        paperLevel: 100,
        hasPaperJam: false,
        errorCode: null,
        errorMessage: null
      }
    }

    const deviceId = printerEmail.split('@')[0]

    // Get printer status
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
      console.error('Epson API error:', response.status)
      return {
        isOnline: false,
        inkLevel: 0,
        paperLevel: 0,
        hasPaperJam: false,
        errorCode: 'API_ERROR',
        errorMessage: `HTTP ${response.status}`
      }
    }

    const data = await response.json()

    return {
      isOnline: data.connection === 'online',
      inkLevel: data.ink_level ?? 100,
      paperLevel: data.paper_level ?? 100,
      hasPaperJam: data.error_code === 'PAPER_JAM',
      errorCode: data.error_code || null,
      errorMessage: data.error_message || null
    }

  } catch (error) {
    console.error('Printer status error:', error)
    return {
      isOnline: false,
      inkLevel: 0,
      paperLevel: 0,
      hasPaperJam: false,
      errorCode: 'CHECK_FAILED',
      errorMessage: error.message
    }
  }
}
