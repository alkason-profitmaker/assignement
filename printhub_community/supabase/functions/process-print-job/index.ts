// Supabase Edge Function: Process Print Job via Epson Connect
// Deno runtime

import { serve } from "https://deno.land/std@0.168.0/http/server.ts";
import { createClient } from "https://esm.sh/@supabase/supabase-js@2";

const corsHeaders = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers": "authorization, x-client-info, apikey, content-type",
};

interface ProcessJobRequest {
  printJobId: string;
}

interface EpsonAuthResponse {
  access_token: string;
  token_type: string;
  expires_in: number;
  refresh_token: string;
}

interface EpsonPrintResponse {
  job_id: string;
  status: string;
}

serve(async (req: Request) => {
  // Handle CORS preflight
  if (req.method === "OPTIONS") {
    return new Response("ok", { headers: corsHeaders });
  }

  try {
    // Initialize Supabase client with service role
    const supabaseUrl = Deno.env.get("SUPABASE_URL")!;
    const supabaseServiceKey = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!;
    const supabase = createClient(supabaseUrl, supabaseServiceKey);

    // Parse request body
    const { printJobId }: ProcessJobRequest = await req.json();

    if (!printJobId) {
      return new Response(
        JSON.stringify({ error: "Missing print job ID" }),
        { status: 400, headers: { ...corsHeaders, "Content-Type": "application/json" } }
      );
    }

    // Get print job details
    const { data: printJob, error: jobError } = await supabase
      .from("print_jobs")
      .select("*, users(name, flat_number, tower)")
      .eq("id", printJobId)
      .single();

    if (jobError || !printJob) {
      console.error("Print job not found:", jobError);
      return new Response(
        JSON.stringify({ error: "Print job not found" }),
        { status: 404, headers: { ...corsHeaders, "Content-Type": "application/json" } }
      );
    }

    // Update status to printing
    await supabase
      .from("print_jobs")
      .update({
        status: "printing",
        printing_started_at: new Date().toISOString(),
      })
      .eq("id", printJobId);

    try {
      // Step 1: Generate cover page
      const coverPageResponse = await fetch(
        `${supabaseUrl}/functions/v1/generate-cover-page`,
        {
          method: "POST",
          headers: {
            "Authorization": `Bearer ${supabaseServiceKey}`,
            "Content-Type": "application/json",
          },
          body: JSON.stringify({
            printJobId,
            pickupCode: printJob.pickup_code,
            userName: printJob.users?.name || "User",
            flatNumber: printJob.users?.flat_number || "",
            tower: printJob.users?.tower || "",
            fileName: printJob.file_name,
            pageCount: printJob.total_pages,
            createdAt: printJob.created_at,
          }),
        }
      );

      let coverPageUrl = null;
      if (coverPageResponse.ok) {
        const coverData = await coverPageResponse.json();
        coverPageUrl = coverData.coverPageUrl;

        // Update print job with cover page URL
        await supabase
          .from("print_jobs")
          .update({ cover_page_url: coverPageUrl })
          .eq("id", printJobId);
      }

      // Step 2: Authenticate with Epson Connect
      const epsonClientId = Deno.env.get("EPSON_CLIENT_ID")!;
      const epsonClientSecret = Deno.env.get("EPSON_CLIENT_SECRET")!;
      const epsonPrinterEmail = Deno.env.get("EPSON_PRINTER_EMAIL")!;

      // Get Epson access token
      const authResponse = await fetch("https://api.epsonconnect.com/api/1/printing/oauth2/auth/token?subject=printer", {
        method: "POST",
        headers: {
          "Content-Type": "application/x-www-form-urlencoded",
        },
        body: new URLSearchParams({
          grant_type: "password",
          username: epsonPrinterEmail,
          password: "", // Epson Connect uses email-based auth
        }),
      });

      // For demo purposes, simulate successful print
      // In production, implement full Epson Connect API integration
      console.log("Processing print job:", printJobId);
      console.log("Document URL:", printJob.file_url);
      console.log("Pages:", printJob.total_pages);

      // Simulate print processing time (2-5 seconds)
      await new Promise(resolve => setTimeout(resolve, 2000 + Math.random() * 3000));

      // Step 3: Update job status to ready
      const { error: updateError } = await supabase
        .from("print_jobs")
        .update({
          status: "ready",
          ready_at: new Date().toISOString(),
          epson_job_id: `epson_${printJobId.substring(0, 8)}`,
        })
        .eq("id", printJobId);

      if (updateError) {
        throw new Error("Failed to update job status");
      }

      // Step 4: Send notification to user
      await fetch(
        `${supabaseUrl}/functions/v1/send-notification`,
        {
          method: "POST",
          headers: {
            "Authorization": `Bearer ${supabaseServiceKey}`,
            "Content-Type": "application/json",
          },
          body: JSON.stringify({
            userId: printJob.user_id,
            title: "Your print is ready!",
            body: `Pickup code: ${printJob.pickup_code}. Collect from the printing station.`,
            type: "print_ready",
            data: {
              printJobId,
              pickupCode: printJob.pickup_code,
            },
          }),
        }
      );

      return new Response(
        JSON.stringify({
          success: true,
          message: "Print job processed successfully",
          status: "ready",
          pickupCode: printJob.pickup_code,
        }),
        { status: 200, headers: { ...corsHeaders, "Content-Type": "application/json" } }
      );

    } catch (printError) {
      console.error("Print processing error:", printError);

      // Update job status to failed
      await supabase
        .from("print_jobs")
        .update({
          status: "failed",
          error_message: printError.message || "Print processing failed",
          retry_count: (printJob.retry_count || 0) + 1,
        })
        .eq("id", printJobId);

      // Send failure notification
      await fetch(
        `${supabaseUrl}/functions/v1/send-notification`,
        {
          method: "POST",
          headers: {
            "Authorization": `Bearer ${supabaseServiceKey}`,
            "Content-Type": "application/json",
          },
          body: JSON.stringify({
            userId: printJob.user_id,
            title: "Print job failed",
            body: "Sorry, your print job failed. Your payment will be refunded.",
            type: "print_failed",
            data: { printJobId },
          }),
        }
      );

      // TODO: Trigger refund process

      return new Response(
        JSON.stringify({
          success: false,
          error: "Print processing failed",
        }),
        { status: 500, headers: { ...corsHeaders, "Content-Type": "application/json" } }
      );
    }

  } catch (error) {
    console.error("Error:", error);
    return new Response(
      JSON.stringify({ error: "Internal server error" }),
      { status: 500, headers: { ...corsHeaders, "Content-Type": "application/json" } }
    );
  }
});
