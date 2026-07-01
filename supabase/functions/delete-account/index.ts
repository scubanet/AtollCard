import "jsr:@supabase/functions-js/edge-runtime.d.ts";
import { createClient } from "npm:@supabase/supabase-js@2";

const cors = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers": "authorization, x-client-info, apikey, content-type",
};

Deno.serve(async (req) => {
  if (req.method === "OPTIONS") return new Response("ok", { headers: cors });
  const json = (b: unknown, status = 200) =>
    new Response(JSON.stringify(b), { status, headers: { ...cors, "content-type": "application/json" } });
  try {
    // 1) Identify the caller from their JWT (never from parameters).
    const authed = createClient(
      Deno.env.get("SUPABASE_URL")!, Deno.env.get("SUPABASE_ANON_KEY")!,
      { global: { headers: { Authorization: req.headers.get("Authorization") ?? "" } } },
    );
    const { data: userData, error: userErr } = await authed.auth.getUser();
    if (userErr || !userData?.user) return json({ error: "unauthorized" }, 401);
    const uid = userData.user.id;

    // 2) Service-role client for storage cleanup + user deletion.
    const admin = createClient(
      Deno.env.get("SUPABASE_URL")!, Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!,
    );

    // 2a) Remove all card-media under <uid>/ (list card folders, then files).
    const bucket = admin.storage.from("card-media");
    const { data: cardDirs } = await bucket.list(uid, { limit: 1000 });
    const paths: string[] = [];
    for (const entry of cardDirs ?? []) {
      if (entry.id === null) {
        // folder → list its files
        const { data: files } = await bucket.list(`${uid}/${entry.name}`, { limit: 1000 });
        for (const f of files ?? []) paths.push(`${uid}/${entry.name}/${f.name}`);
      } else {
        paths.push(`${uid}/${entry.name}`);
      }
    }
    if (paths.length > 0) await bucket.remove(paths);

    // 2b) Delete the auth user — FK cascade removes profiles/cards/fields/events/connections.
    const { error: delErr } = await admin.auth.admin.deleteUser(uid);
    if (delErr) return json({ error: delErr.message }, 500);

    return json({ ok: true });
  } catch (e) {
    return json({ error: String(e) }, 500);
  }
});
