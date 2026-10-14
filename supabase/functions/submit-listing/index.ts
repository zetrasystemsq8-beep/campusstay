// Public endpoint behind the landlord web form. It only ever creates a private
// "lead" for admins to follow up. It never publishes anything.
// Deploy: supabase functions deploy submit-listing --no-verify-jwt
import { createClient } from "https://esm.sh/@supabase/supabase-js@2.45.4";

const cors = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers": "authorization, apikey, content-type, x-client-info",
  "Access-Control-Allow-Methods": "POST, OPTIONS",
};
const json = (status: number, body: unknown) =>
  new Response(JSON.stringify(body), { status, headers: { ...cors, "Content-Type": "application/json" } });

const ROOM_TYPES = ["single_room", "shared_room", "self_contain", "apartment", "hostel"];
const MAX_PER_HOUR = 5;

async function sha256(text: string) {
  const buf = await crypto.subtle.digest("SHA-256", new TextEncoder().encode(text));
  return Array.from(new Uint8Array(buf)).map((b) => b.toString(16).padStart(2, "0")).join("");
}

Deno.serve(async (req) => {
  if (req.method === "OPTIONS") return new Response("ok", { headers: cors });
  if (req.method !== "POST") return json(405, { error: "method_not_allowed" });

  let b: Record<string, unknown>;
  try {
    b = await req.json();
  } catch {
    return json(400, { error: "bad_json" });
  }

  // Honeypot: real people never fill this hidden field. Pretend success to bots.
  if (typeof b.website === "string" && b.website.length > 0) return json(201, { ok: true });

  const errors: Record<string, string> = {};
  const str = (v: unknown) => (typeof v === "string" ? v.trim() : "");
  const name = str(b.name), phone = str(b.phone), place = str(b.school_or_area), desc = str(b.description);
  const room = str(b.room_type);
  const rent = b.rent_ngn === "" || b.rent_ngn == null ? null : Number(b.rent_ngn);

  if (name.length < 2 || name.length > 100) errors.name = "Enter your name.";
  if (!/^\+?[0-9 ]{7,16}$/.test(phone)) errors.phone = "Enter a phone number using digits only, like 08012345678.";
  if (place.length < 2 || place.length > 150) errors.school_or_area = "Tell us the school or area the property is near.";
  if (!ROOM_TYPES.includes(room)) errors.room_type = "Choose a room type.";
  if (rent !== null && (!Number.isInteger(rent) || rent <= 0 || rent >= 100000000)) errors.rent_ngn = "Enter the rent as a whole number.";
  if (desc.length > 2000) errors.description = "Keep the description under 2000 characters.";
  if (b.consent !== true) errors.consent = "Please tick the box so we can contact you.";
  if (Object.keys(errors).length) return json(422, { error: "validation", errors });

  const url = Deno.env.get("SUPABASE_URL");
  const key = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY");
  if (!url || !key) return json(500, { error: "not_configured" });
  const db = createClient(url, key, { auth: { persistSession: false } });

  const ip = req.headers.get("x-forwarded-for")?.split(",")[0].trim() ?? "unknown";
  const salt = Deno.env.get("IP_HASH_SALT") ?? "campusstay";
  const ipHash = await sha256(`${salt}:${ip}`);

  const since = new Date(Date.now() - 3600_000).toISOString();
  const { count, error: countErr } = await db
    .from("landlord_submissions").select("id", { count: "exact", head: true })
    .eq("ip_hash", ipHash).gte("created_at", since);
  if (countErr) return json(500, { error: "server", detail: countErr.message });
  if ((count ?? 0) >= MAX_PER_HOUR) return json(429, { error: "rate_limited" });

  const { error } = await db.from("landlord_submissions").insert({
    name, phone, school_or_area: place, room_type: room, rent_ngn: rent,
    description: desc || null, consent: true, ip_hash: ipHash,
  });
  if (error) return json(500, { error: "server", detail: error.message });
  return json(201, { ok: true });
});
