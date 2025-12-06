// Supabase Edge Function: Generate Cover Page PDF
// Deno runtime

import { serve } from "https://deno.land/std@0.168.0/http/server.ts";
import { createClient } from "https://esm.sh/@supabase/supabase-js@2";

const corsHeaders = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers": "authorization, x-client-info, apikey, content-type",
};

interface CoverPageRequest {
  printJobId: string;
  pickupCode: string;
  userName: string;
  flatNumber: string;
  tower?: string;
  fileName: string;
  pageCount: number;
  createdAt: string;
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
    const {
      printJobId,
      pickupCode,
      userName,
      flatNumber,
      tower,
      fileName,
      pageCount,
      createdAt,
    }: CoverPageRequest = await req.json();

    if (!printJobId || !pickupCode) {
      return new Response(
        JSON.stringify({ error: "Missing required fields" }),
        { status: 400, headers: { ...corsHeaders, "Content-Type": "application/json" } }
      );
    }

    // Generate HTML for cover page
    const flatInfo = tower ? `${tower} - ${flatNumber}` : flatNumber;
    const timestamp = new Date(createdAt).toLocaleString("en-IN", {
      timeZone: "Asia/Kolkata",
      dateStyle: "medium",
      timeStyle: "short",
    });

    const coverPageHtml = `
<!DOCTYPE html>
<html>
<head>
  <meta charset="UTF-8">
  <style>
    * {
      margin: 0;
      padding: 0;
      box-sizing: border-box;
    }
    body {
      font-family: 'Arial', sans-serif;
      width: 210mm;
      height: 297mm;
      display: flex;
      justify-content: center;
      align-items: center;
      background: white;
    }
    .container {
      text-align: center;
      padding: 40px;
      border: 4px dashed #333;
      border-radius: 20px;
      width: 180mm;
      background: #f9f9f9;
    }
    .logo {
      font-size: 36px;
      font-weight: bold;
      color: #2563EB;
      margin-bottom: 10px;
    }
    .tagline {
      font-size: 14px;
      color: #666;
      margin-bottom: 30px;
    }
    .pickup-code-label {
      font-size: 16px;
      color: #333;
      margin-bottom: 10px;
    }
    .pickup-code {
      font-size: 72px;
      font-weight: bold;
      color: #000;
      letter-spacing: 8px;
      padding: 20px 40px;
      background: #fff;
      border: 3px solid #333;
      border-radius: 10px;
      margin-bottom: 30px;
      display: inline-block;
    }
    .divider {
      width: 100%;
      height: 2px;
      background: #ddd;
      margin: 20px 0;
    }
    .info-section {
      text-align: left;
      padding: 20px;
      background: white;
      border-radius: 10px;
      margin-top: 20px;
    }
    .info-row {
      display: flex;
      justify-content: space-between;
      margin-bottom: 10px;
      font-size: 14px;
    }
    .info-label {
      color: #666;
    }
    .info-value {
      font-weight: bold;
      color: #333;
    }
    .footer {
      margin-top: 30px;
      font-size: 12px;
      color: #999;
    }
    .important {
      color: #EF4444;
      font-weight: bold;
      margin-top: 20px;
      padding: 10px;
      background: #FEE2E2;
      border-radius: 5px;
    }
  </style>
</head>
<body>
  <div class="container">
    <div class="logo">PrintHub</div>
    <div class="tagline">Community Printing Service</div>

    <div class="pickup-code-label">YOUR PICKUP CODE</div>
    <div class="pickup-code">${pickupCode}</div>

    <div class="divider"></div>

    <div class="info-section">
      <div class="info-row">
        <span class="info-label">Name:</span>
        <span class="info-value">${userName}</span>
      </div>
      <div class="info-row">
        <span class="info-label">Flat:</span>
        <span class="info-value">${flatInfo}</span>
      </div>
      <div class="info-row">
        <span class="info-label">Document:</span>
        <span class="info-value">${fileName}</span>
      </div>
      <div class="info-row">
        <span class="info-label">Pages:</span>
        <span class="info-value">${pageCount} page(s)</span>
      </div>
      <div class="info-row">
        <span class="info-label">Printed:</span>
        <span class="info-value">${timestamp}</span>
      </div>
    </div>

    <div class="important">
      Please collect within 30 minutes to avoid shredding
    </div>

    <div class="footer">
      This cover page helps identify your print. Please don't remove it until you've verified your documents.
    </div>
  </div>
</body>
</html>
    `;

    // In production, use a PDF generation service like Puppeteer or html-pdf
    // For now, we'll store the HTML and convert client-side or use a separate service

    // Store cover page HTML in storage
    const coverPagePath = `cover_pages/${printJobId}.html`;

    const { error: uploadError } = await supabase.storage
      .from("documents")
      .upload(coverPagePath, new Blob([coverPageHtml], { type: "text/html" }), {
        contentType: "text/html",
        upsert: true,
      });

    if (uploadError) {
      console.error("Failed to upload cover page:", uploadError);
      return new Response(
        JSON.stringify({ error: "Failed to generate cover page" }),
        { status: 500, headers: { ...corsHeaders, "Content-Type": "application/json" } }
      );
    }

    // Get public URL
    const { data: { publicUrl } } = supabase.storage
      .from("documents")
      .getPublicUrl(coverPagePath);

    return new Response(
      JSON.stringify({
        success: true,
        coverPageUrl: publicUrl,
        pickupCode,
      }),
      { status: 200, headers: { ...corsHeaders, "Content-Type": "application/json" } }
    );

  } catch (error) {
    console.error("Error:", error);
    return new Response(
      JSON.stringify({ error: "Internal server error" }),
      { status: 500, headers: { ...corsHeaders, "Content-Type": "application/json" } }
    );
  }
});
