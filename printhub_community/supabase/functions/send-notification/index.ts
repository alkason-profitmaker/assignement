// Supabase Edge Function: Send Push Notification via FCM
// Deno runtime

import { serve } from "https://deno.land/std@0.168.0/http/server.ts";
import { createClient } from "https://esm.sh/@supabase/supabase-js@2";

const corsHeaders = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers": "authorization, x-client-info, apikey, content-type",
};

interface NotificationRequest {
  userId: string;
  title: string;
  body: string;
  type: string;
  data?: Record<string, unknown>;
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
    const { userId, title, body, type, data }: NotificationRequest = await req.json();

    if (!userId || !title || !body || !type) {
      return new Response(
        JSON.stringify({ error: "Missing required fields" }),
        { status: 400, headers: { ...corsHeaders, "Content-Type": "application/json" } }
      );
    }

    // Get user's FCM token
    const { data: user, error: userError } = await supabase
      .from("users")
      .select("fcm_token")
      .eq("id", userId)
      .single();

    if (userError || !user) {
      console.error("User not found:", userError);
      return new Response(
        JSON.stringify({ error: "User not found" }),
        { status: 404, headers: { ...corsHeaders, "Content-Type": "application/json" } }
      );
    }

    // Store notification in database
    const { error: notifError } = await supabase
      .from("notifications")
      .insert({
        user_id: userId,
        title,
        body,
        type,
        data,
      });

    if (notifError) {
      console.error("Failed to store notification:", notifError);
    }

    // If user has FCM token, send push notification
    if (user.fcm_token) {
      const fcmServerKey = Deno.env.get("FCM_SERVER_KEY");

      if (fcmServerKey) {
        const fcmResponse = await fetch("https://fcm.googleapis.com/fcm/send", {
          method: "POST",
          headers: {
            "Authorization": `key=${fcmServerKey}`,
            "Content-Type": "application/json",
          },
          body: JSON.stringify({
            to: user.fcm_token,
            notification: {
              title,
              body,
              sound: "default",
              click_action: "FLUTTER_NOTIFICATION_CLICK",
            },
            data: {
              type,
              ...data,
            },
            priority: "high",
          }),
        });

        if (!fcmResponse.ok) {
          const fcmError = await fcmResponse.json();
          console.error("FCM error:", fcmError);
        } else {
          console.log("Push notification sent successfully");
        }
      }
    }

    return new Response(
      JSON.stringify({
        success: true,
        message: "Notification sent",
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
