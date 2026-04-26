import { serve } from "https://deno.land/std@0.168.0/http/server.ts";
import { createClient } from "https://esm.sh/@supabase/supabase-js@2";

const SUPABASE_URL = Deno.env.get("SUPABASE_URL")!;
const SUPABASE_SERVICE_KEY = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!;
const FIREBASE_PROJECT_ID = Deno.env.get("FIREBASE_PROJECT_ID")!;
const FIREBASE_SERVICE_ACCOUNT = Deno.env.get("FIREBASE_SERVICE_ACCOUNT")!;

async function getAccessToken(): Promise<string> {
  const serviceAccount = JSON.parse(FIREBASE_SERVICE_ACCOUNT);

  function base64url(str: string): string {
    return btoa(str)
      .replace(/\+/g, "-")
      .replace(/\//g, "_")
      .replace(/=/g, "");
  }

  function base64urlFromUint8(arr: Uint8Array): string {
    return btoa(String.fromCharCode(...arr))
      .replace(/\+/g, "-")
      .replace(/\//g, "_")
      .replace(/=/g, "");
  }

  const header = base64url(JSON.stringify({ alg: "RS256", typ: "JWT" }));
  const now = Math.floor(Date.now() / 1000);
  const payload = base64url(
    JSON.stringify({
      iss: serviceAccount.client_email,
      scope: "https://www.googleapis.com/auth/firebase.messaging",
      aud: "https://oauth2.googleapis.com/token",
      exp: now + 3600,
      iat: now,
    })
  );

  const privateKey = serviceAccount.private_key;
  const keyData = privateKey
    .replace("-----BEGIN PRIVATE KEY-----", "")
    .replace("-----END PRIVATE KEY-----", "")
    .replace(/\n/g, "")
    .trim();

  const binaryKey = Uint8Array.from(atob(keyData), (c) => c.charCodeAt(0));

  const cryptoKey = await crypto.subtle.importKey(
    "pkcs8",
    binaryKey,
    { name: "RSASSA-PKCS1-v1_5", hash: "SHA-256" },
    false,
    ["sign"]
  );

  const signingInput = `${header}.${payload}`;
  const signature = await crypto.subtle.sign(
    "RSASSA-PKCS1-v1_5",
    cryptoKey,
    new TextEncoder().encode(signingInput)
  );

  const jwt = `${signingInput}.${base64urlFromUint8(new Uint8Array(signature))}`;

  const tokenResponse = await fetch("https://oauth2.googleapis.com/token", {
    method: "POST",
    headers: { "Content-Type": "application/x-www-form-urlencoded" },
    body: `grant_type=urn:ietf:params:oauth:grant-type:jwt-bearer&assertion=${jwt}`,
  });

  const tokenData = await tokenResponse.json();
  console.log("Token response:", JSON.stringify(tokenData));
  
  if (!tokenData.access_token) {
    throw new Error(`Failed to get access token: ${JSON.stringify(tokenData)}`);
  }
  
  return tokenData.access_token;
}

function pad(n: number): string {
  return n.toString().padStart(2, "0");
}

serve(async (req) => {
  try {
    const { appointment_id, status } = await req.json();

    const supabase = createClient(SUPABASE_URL, SUPABASE_SERVICE_KEY);

    const { data: apt } = await supabase
      .from("appointments")
      .select(
        `*, patients(full_name, fcm_token), clinics(name), users!appointments_doctor_id_fkey(full_name)`
      )
      .eq("id", appointment_id)
      .single();

    if (!apt) {
      return new Response(JSON.stringify({ error: "Appointment not found" }), {
        status: 404,
      });
    }

    const fcmToken = apt.patients?.fcm_token;
    if (!fcmToken) {
      return new Response(JSON.stringify({ message: "No FCM token" }), {
        status: 200,
      });
    }

    const scheduledAt = new Date(apt.scheduled_at);
    const dateStr = `${scheduledAt.getFullYear()}/${pad(scheduledAt.getMonth() + 1)}/${pad(scheduledAt.getDate())}`;
    const timeStr = `${pad(scheduledAt.getHours())}:${pad(scheduledAt.getMinutes())}`;

    let title = "";
    let body = "";

    switch (status) {
      case "confirmed":
        title = "✅ تم تأكيد موعدك";
        body = `موعدك في ${apt.clinics?.name} مع ${apt.users?.full_name} بتاريخ ${dateStr} الساعة ${timeStr}`;
        break;
      case "cancelled":
        title = "❌ تم إلغاء موعدك";
        body = `تم إلغاء موعدك في ${apt.clinics?.name} بتاريخ ${dateStr}`;
        break;
      case "in_progress":
        title = "🏥 دورك الآن";
        body = `يمكنك الدخول الآن لـ ${apt.clinics?.name}`;
        break;
      default:
        return new Response(
          JSON.stringify({ message: "No notification needed" }),
          { status: 200 }
        );
    }

    const accessToken = await getAccessToken();

    const fcmResponse = await fetch(
      `https://fcm.googleapis.com/v1/projects/${FIREBASE_PROJECT_ID}/messages:send`,
      {
        method: "POST",
        headers: {
          "Content-Type": "application/json",
          Authorization: `Bearer ${accessToken}`,
        },
        body: JSON.stringify({
  message: {
    token: fcmToken,
    notification: { title, body },
    android: {
      priority: "high",
      notification: {
        channel_id: "medical_channel",
      },
    },
    apns: {
      payload: {
        aps: { sound: "default", badge: 1 },
      },
    },
  },
}),
      }
    );

    const fcmResult = await fcmResponse.json();
    console.log("FCM Result:", JSON.stringify(fcmResult));

    return new Response(JSON.stringify({ success: true, fcmResult }), {
      headers: { "Content-Type": "application/json" },
      status: 200,
    });
  } catch (error) {
    console.error("Error:", error.message);
    return new Response(JSON.stringify({ error: error.message }), {
      status: 500,
    });
  }
});