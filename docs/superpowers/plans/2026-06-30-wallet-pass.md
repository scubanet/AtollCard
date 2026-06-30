# Wallet-Pass Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Aktive Karte als serverseitig signierten `.pkpass` zu Apple Wallet hinzufügen.

**Architecture:** Supabase Edge Function `generate-pass` (Deno) lädt die Karte (RLS via User-JWT), baut + signiert (PKCS#7 detached, node-forge) den `.pkpass` (fflate-ZIP). iOS holt ihn über eine `WalletPassProviding`-Naht und präsentiert `PKAddPassesViewController`.

**Tech Stack:** Deno (`npm:node-forge`, `npm:fflate`, `npm:@supabase/supabase-js`), SwiftUI/PassKit/UIKit, XCTest, XcodeGen.

**Konventionen:** Repo `~/Developer/AtollCard`. Secrets sind gesetzt: `PASS_TYPE_ID`, `APPLE_TEAM_ID`, `PASS_CERT_PEM`, `PASS_KEY_PEM`, `WWDR_PEM`. **Edge-Function-Deploy macht der Controller** (MCP `deploy_edge_function`) — der Implementer schreibt + `deno test` lokal. iOS: nach neuen Dateien `xcodegen generate`; Test `xcodebuild test -scheme AtollCard -destination 'platform=iOS Simulator,name=iPhone 16e,OS=26.2'`; macOS `-destination 'platform=macOS,arch=arm64'`. Commits enden mit `Co-Authored-By: Claude Opus 4.8 <noreply@anthropic.com>`.

---

## File Structure
- `supabase/functions/generate-pass/pass.ts` — reiner `buildPassJSON(card, fields)` (testbar).
- `supabase/functions/generate-pass/pass.test.ts` — `deno test`.
- `supabase/functions/generate-pass/index.ts` — HTTP-Handler: auth, load, build, sign, zip.
- `AtollCard/Features/Share/WalletService.swift` — `WalletPassProviding` + `SupabaseWalletService`.
- `AtollCard/Features/Share/AddPassView.swift` — PassKit-Add-Sheet (iOS).
- `AtollCard/Features/Share/ShareSheet.swift` — „Zu Wallet hinzufügen"-Zeile (iOS).
- Test: `AtollCardTests/WalletServiceTests.swift`.

---

## Task 1: Edge Function `generate-pass`

**Files:** Create `supabase/functions/generate-pass/pass.ts`, `pass.test.ts`, `index.ts`.

- [ ] **Step 1: Failing deno test** `supabase/functions/generate-pass/pass.test.ts`
```ts
import { assertEquals, assert } from "jsr:@std/assert@1";
import { buildPassJSON } from "./pass.ts";

const card = {
  id: "cccccccc-0000-0000-0000-000000000001", slug: "jane-doe",
  display_name: "Jane Doe", title: "CTO", company: "Acme", accent_color: "#0E7C86",
};
const fields = [{ type: "email", label: "Work", value: "jane@acme.com", sort_order: 0 }];

Deno.test("buildPassJSON maps card + QR + colors", () => {
  const p = buildPassJSON(card, fields, "pass.swiss.atoll.card.persona", "XK8V89P2QV");
  assertEquals(p.passTypeIdentifier, "pass.swiss.atoll.card.persona");
  assertEquals(p.teamIdentifier, "XK8V89P2QV");
  assertEquals(p.serialNumber, card.id);
  assertEquals(p.barcodes[0].message, "https://card.atoll-os.com/jane-doe");
  assertEquals(p.barcodes[0].format, "PKBarcodeFormatQR");
  assertEquals(p.generic.primaryFields[0].value, "Jane Doe");
  assert(p.backgroundColor.startsWith("rgb("));
});
```

- [ ] **Step 2: Run → FAIL.** `cd supabase/functions/generate-pass && deno test` → module missing.

- [ ] **Step 3: Implement** `supabase/functions/generate-pass/pass.ts`
```ts
export interface PassCard {
  id: string; slug: string; display_name: string;
  title?: string | null; company?: string | null; accent_color: string;
}
export interface PassField { type: string; label: string; value: string; sort_order: number }

function rgb(hex: string): string {
  const s = hex.replace("#", "");
  const v = parseInt(s.length === 3 ? s.split("").map((c) => c + c).join("") : s, 16);
  const r = (v >> 16) & 255, g = (v >> 8) & 255, b = v & 255;
  return `rgb(${r}, ${g}, ${b})`;
}

export function buildPassJSON(card: PassCard, fields: PassField[], passTypeId: string, teamId: string) {
  const sorted = [...fields].sort((a, b) => a.sort_order - b.sort_order);
  const secondary: { key: string; label: string; value: string }[] = [];
  if (card.title) secondary.push({ key: "title", label: "Titel", value: card.title });
  if (card.company) secondary.push({ key: "company", label: "Firma", value: card.company });
  const auxiliary = sorted.map((f, i) => ({ key: `f${i}`, label: f.label, value: f.value }));
  return {
    formatVersion: 1,
    passTypeIdentifier: passTypeId,
    teamIdentifier: teamId,
    organizationName: "AtollCard",
    description: "AtollCard",
    serialNumber: card.id,
    backgroundColor: rgb(card.accent_color || "#0E7C86"),
    foregroundColor: "rgb(255, 255, 255)",
    labelColor: "rgb(255, 255, 255)",
    barcodes: [{
      format: "PKBarcodeFormatQR",
      message: `https://card.atoll-os.com/${card.slug}`,
      messageEncoding: "iso-8859-1",
    }],
    generic: {
      primaryFields: [{ key: "name", label: "", value: card.display_name }],
      secondaryFields: secondary,
      auxiliaryFields: auxiliary,
    },
  };
}
```

- [ ] **Step 4: Run → PASS.** `deno test`.

- [ ] **Step 5: Handler** `supabase/functions/generate-pass/index.ts`
```ts
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
```

- [ ] **Step 6: Commit** (Controller deployt danach via MCP + verifiziert)
```bash
git add supabase/functions/generate-pass
git commit -m "feat(edge): generate-pass — signed .pkpass for a card

Co-Authored-By: Claude Opus 4.8 <noreply@anthropic.com>"
```

---

## Task 2: iOS Wallet add flow

**Files:** Create `AtollCard/Features/Share/WalletService.swift`, `AtollCard/Features/Share/AddPassView.swift`; Modify `AtollCard/Features/Share/ShareSheet.swift`; Test `AtollCardTests/WalletServiceTests.swift`.

- [ ] **Step 1: Failing test** `AtollCardTests/WalletServiceTests.swift`
```swift
import XCTest
@testable import AtollCard

@MainActor
final class WalletServiceTests: XCTestCase {
    func test_viewModelLoadsPassData() async {
        let data = Data([0x50, 0x4B]) // "PK" zip magic
        let vm = WalletAddViewModel(service: FakeWalletService(result: .success(data)))
        await vm.fetch(cardId: UUID())
        XCTAssertEqual(vm.passData, data)
        XCTAssertNil(vm.errorMessage)
    }
    func test_viewModelSurfacesError() async {
        let vm = WalletAddViewModel(service: FakeWalletService(result: .failure(
            NSError(domain: "x", code: 1, userInfo: [NSLocalizedDescriptionKey: "nope"]))))
        await vm.fetch(cardId: UUID())
        XCTAssertNil(vm.passData)
        XCTAssertEqual(vm.errorMessage, "nope")
    }
}

struct FakeWalletService: WalletPassProviding {
    var result: Result<Data, Error>
    func passData(forCardId id: UUID) async throws -> Data { try result.get() }
}
```

- [ ] **Step 2: Run → FAIL** (types missing).

- [ ] **Step 3: Service + VM** `AtollCard/Features/Share/WalletService.swift`
```swift
import Foundation
import Supabase

protocol WalletPassProviding {
    func passData(forCardId id: UUID) async throws -> Data
}

struct SupabaseWalletService: WalletPassProviding {
    let client: SupabaseClient
    init(client: SupabaseClient = AtollSupabase.client) { self.client = client }

    func passData(forCardId id: UUID) async throws -> Data {
        try await client.functions.invoke(
            "generate-pass",
            options: FunctionInvokeOptions(body: ["cardId": id.uuidString])
        )
    }
}

@MainActor
final class WalletAddViewModel: ObservableObject {
    @Published var passData: Data?
    @Published var errorMessage: String?
    private let service: WalletPassProviding
    init(service: WalletPassProviding) { self.service = service }

    func fetch(cardId: UUID) async {
        do {
            passData = try await service.passData(forCardId: cardId)
            errorMessage = nil
        } catch {
            passData = nil
            errorMessage = error.localizedDescription
        }
    }
}
```
If supabase-swift's `functions.invoke` returns a typed/`Data` value with a different signature in 2.48, adapt to return raw `Data` (there is an overload returning `Data`); report the exact call used.

- [ ] **Step 4: Run → PASS** (2 tests). (VM is pure; the Supabase impl compiles.)

- [ ] **Step 5: PassKit add sheet** `AtollCard/Features/Share/AddPassView.swift`
```swift
#if os(iOS)
import SwiftUI
import PassKit

struct AddPassView: UIViewControllerRepresentable {
    let passData: Data
    let onFinish: () -> Void

    func makeCoordinator() -> Coordinator { Coordinator(onFinish: onFinish) }

    func makeUIViewController(context: Context) -> UIViewController {
        guard let pass = try? PKPass(data: passData),
              let vc = PKAddPassesViewController(pass: pass) else {
            return UIViewController()
        }
        vc.delegate = context.coordinator
        return vc
    }
    func updateUIViewController(_ vc: UIViewController, context: Context) {}

    final class Coordinator: NSObject, PKAddPassesViewControllerDelegate {
        let onFinish: () -> Void
        init(onFinish: @escaping () -> Void) { self.onFinish = onFinish }
        func addPassesViewControllerDidFinish(_ c: PKAddPassesViewController) { onFinish() }
    }
}
#endif
```

- [ ] **Step 6: ShareSheet entry (iOS).** Read `ShareSheet.swift`. Add a `walletService: WalletPassProviding` (default `SupabaseWalletService()`), and under `#if os(iOS)` a row "Zu Wallet hinzufügen" (icon `wallet.pass`) that, on tap, fetches the pass for the sheet's card and presents `AddPassView` in a sheet. Minimal state:
```swift
    @State private var walletPass: Data?
    @State private var walletError: String?
    // ... in the iOS rows:
    Button { Task { await loadWallet() } } label: { /* row label */ }
    .sheet(isPresented: Binding(get: { walletPass != nil }, set: { if !$0 { walletPass = nil } })) {
        if let data = walletPass { AddPassView(passData: data) { walletPass = nil } }
    }
    // helper:
    private func loadWallet() async {
        do { walletPass = try await walletService.passData(forCardId: card.id) }
        catch { walletError = error.localizedDescription }
    }
```
(`card` is the `Card` the sheet holds. Use `PKPassLibrary.isPassLibraryAvailable()` to hide the row if unavailable, optional. Keep styling consistent.)

- [ ] **Step 7: Build both + tests.** `xcodegen generate`; iOS test (expect prior + 2 new) ; macOS build (Wallet code under `#if os(iOS)`, mac unaffected). All green.

- [ ] **Step 8: Commit**
```bash
git add AtollCard/Features/Share/WalletService.swift AtollCard/Features/Share/AddPassView.swift AtollCard/Features/Share/ShareSheet.swift AtollCardTests/WalletServiceTests.swift
git commit -m "feat(ios): add-to-Wallet flow (fetch signed pass + PKAddPasses)

Co-Authored-By: Claude Opus 4.8 <noreply@anthropic.com>"
```

---

## Task 3: Deploy + Verifikationsgate

**Files:** keine (Controller-Aktionen).

- [ ] **Step 1: Controller deployt** `generate-pass` via MCP `deploy_edge_function` (verify_jwt true).
- [ ] **Step 2: Unauth-Invoke** (kein/ungültiges JWT) → 401 (deployed + auth-gated). `.pkpass`-Strukturcheck, sobald ein echter Pass vorliegt: entpacken → `pass.json`, `manifest.json`, `signature`, `icon.png` vorhanden; `signature` beginnt mit PKCS#7-DER.
- [ ] **Step 3: Echt-Gate (Nutzer):** In der App (iPad) „Zu Wallet hinzufügen" → Pass landet in Wallet. Bei Ablehnung: Controller iteriert an `signManifest` (sha1 statt sha256, authenticatedAttributes, WWDR-Reihenfolge) + redeploy.

---

## Self-Review
- **Spec-Abdeckung:** Edge `buildPassJSON` (T1, getestet) + Handler (auth/load/sign/zip) (T1), iOS `WalletPassProviding`/VM + PassKit-Add + ShareSheet-Zeile (T2), Deploy + Gate (T3). ✓
- **Platzhalter:** keine; voller Deno- + Swift-Code, echte Icon-base64, vollständige Signatur-Funktion. ✓
- **Typkonsistenz:** `buildPassJSON(card, fields, passTypeId, teamId)` in pass.ts + test + index.ts identisch. `WalletPassProviding.passData(forCardId:)` in Protokoll/Fake/Supabase/VM (T2) + ShareSheet (T2). Secret-Namen exakt wie gesetzt (`PASS_TYPE_ID`,`APPLE_TEAM_ID`,`PASS_CERT_PEM`,`PASS_KEY_PEM`,`WWDR_PEM`). ✓
- **Risiko:** CMS-Signatur (sha256 vs sha1) — Iterationspunkt im Gate; `functions.invoke`-Rückgabetyp ggf. anpassen.
