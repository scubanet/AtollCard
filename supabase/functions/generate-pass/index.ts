import "jsr:@supabase/functions-js/edge-runtime.d.ts";
import { createClient } from "npm:@supabase/supabase-js@2";
import forge from "npm:node-forge@1.3.1";
import { zipSync, strToU8 } from "npm:fflate@0.8.2";
import { buildPassJSON } from "./pass.ts";

// 29x29 / 58x58 solid teal PNGs (Apple requires icon.png; @2x recommended)
const ICON29 = "iVBORw0KGgoAAAANSUhEUgAAAB0AAAAdCAIAAADZ8fBYAAAAJklEQVR42mPgq2mjBWIYNXfU3FFzR80dNXfU3FFzR80dNXdQmQsAXmt9vlCdnAcAAAAASUVORK5CYII=";
const ICON58 = "iVBORw0KGgoAAAANSUhEUgAAADoAAAA6CAIAAABu2d1/AAAARUlEQVR42u3OQQkAAAgEsEtgYt/mNsfBYAGW2SsSXV1dXV1dXV1dXV1dXV1dXV1dXV1dXV1dXV1dXV1dXV1dXV1dXd0eD+3U9wQ5TWtzAAAAAElFTkSuQmCC";

const cors = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers": "authorization, x-client-info, apikey, content-type",
};
const b64 = (s: string) => Uint8Array.from(atob(s), (c) => c.charCodeAt(0));

function sha1Hex(bytes: Uint8Array): string {
  const md = forge.md.sha1.create();
  md.update(forge.util.binary.raw.encode(bytes));
  return md.digest().toHex();
}

function signManifest(manifest: Uint8Array): Uint8Array {
  const cert = forge.pki.certificateFromPem(Deno.env.get("PASS_CERT_PEM")!);
  const key = forge.pki.privateKeyFromPem(Deno.env.get("PASS_KEY_PEM")!);
  const wwdr = forge.pki.certificateFromPem(Deno.env.get("WWDR_PEM")!);
  const p7 = forge.pkcs7.createSignedData();
  p7.content = forge.util.createBuffer(forge.util.binary.raw.encode(manifest));
  p7.addCertificate(cert);
  p7.addCertificate(wwdr);
  p7.addSigner({
    key, certificate: cert, digestAlgorithm: forge.pki.oids.sha256,
    authenticatedAttributes: [
      { type: forge.pki.oids.contentType, value: forge.pki.oids.data },
      { type: forge.pki.oids.messageDigest },
      { type: forge.pki.oids.signingTime, value: new Date() },
    ],
  });
  p7.sign({ detached: true });
  const der = forge.asn1.toDer(p7.toAsn1()).getBytes();
  return forge.util.binary.raw.decode(der);
}

Deno.serve(async (req) => {
  if (req.method === "OPTIONS") return new Response("ok", { headers: cors });
  const json = (b: unknown, status = 200) =>
    new Response(JSON.stringify(b), { status, headers: { ...cors, "content-type": "application/json" } });
  try {
    const supabase = createClient(
      Deno.env.get("SUPABASE_URL")!, Deno.env.get("SUPABASE_ANON_KEY")!,
      { global: { headers: { Authorization: req.headers.get("Authorization") ?? "" } } },
    );
    const { cardId } = await req.json();
    if (!cardId) return json({ error: "cardId required" }, 400);
    const { data: card } = await supabase.from("cards").select("*").eq("id", cardId).maybeSingle();
    if (!card) return json({ error: "card not found" }, 404);
    const { data: fields } = await supabase.from("card_fields").select("*")
      .eq("card_id", cardId).order("sort_order");

    const passJSON = buildPassJSON(
      card, fields ?? [], Deno.env.get("PASS_TYPE_ID")!, Deno.env.get("APPLE_TEAM_ID")!,
    );
    const files: Record<string, Uint8Array> = {
      "pass.json": strToU8(JSON.stringify(passJSON)),
      "icon.png": b64(ICON29),
      "icon@2x.png": b64(ICON58),
    };
    const manifest: Record<string, string> = {};
    for (const [name, bytes] of Object.entries(files)) manifest[name] = sha1Hex(bytes);
    const manifestBytes = strToU8(JSON.stringify(manifest));
    files["manifest.json"] = manifestBytes;
    files["signature"] = signManifest(manifestBytes);

    const zip = zipSync(files);
    return new Response(zip, {
      headers: { ...cors, "content-type": "application/vnd.apple.pkpass" },
    });
  } catch (e) {
    return json({ error: String(e) }, 500);
  }
});
