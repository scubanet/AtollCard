# Card-Editor: Medien + Edit-Korrektheit — Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Cover- + Profilfoto-Upload (PhotosPicker → Downscale → `card-media`-Bucket → Anzeige) im Karten-Editor, plus Backlog-Fixes (Edit erhält Media-URLs; `slugIsAvailable` global via RPC).

**Architecture:** `ImageDownscaler` (ImageIO, cross-platform) verkleinert Picker-Daten; `CardEditorViewModel` bekommt eine `MediaStoring`-Dep, hält pending Bilddaten + bestehende URLs und lädt beim Speichern hoch. `SupabaseCardStore.slugIsAvailable` ruft die neue `slug_available`-RPC. Reine Logik unit-getestet, PhotosPicker-UI dünn.

**Tech Stack:** SwiftUI, PhotosUI (`PhotosPicker`), ImageIO, supabase-swift 2.48, XCTest, XcodeGen, Swift 5.

**Konventionen (jede Task):** Repo `~/Developer/AtollCard`. Nach neuen Dateien `xcodegen generate`. Test: `xcodebuild test -scheme AtollCard -destination 'platform=iOS Simulator,name=iPhone 16e,OS=26.2' [-only-testing:...]`. macOS: `-destination 'platform=macOS,arch=arm64'`. Commits enden mit `Co-Authored-By: Claude Opus 4.8 <noreply@anthropic.com>`. **Backend-Migration (Task 1) wird vom Controller auf lokal + Prod angewandt — der Implementer schreibt nur die Datei + den Store-Swap.**

---

## File Structure
- `supabase/migrations/0009_slug_available.sql` — neue RPC `slug_available(text)`.
- `AtollCard/Stores/SupabaseCardStore.swift` — `slugIsAvailable` via RPC.
- `AtollCard/Features/CardEditor/ImageDownscaler.swift` — ImageIO-Downscale.
- `AtollCard/Stores/AppStores.swift` — `mediaStore`-DI.
- `AtollCard/Features/CardEditor/CardEditorViewModel.swift` — Medien + URL-Erhalt.
- `AtollCard/Features/CardEditor/CardEditorView.swift`, `AtollCard/Features/CardEditor/OnboardingView.swift` — PhotosPicker.
- `AtollCard/Features/Shell/BusinessCardView.swift` — Foto/Cover-Anzeige.
- Tests: `AtollCardTests/ImageDownscalerTests.swift`, `AtollCardTests/CardEditorViewModelTests.swift` (erweitert).

---

## Task 1: Backend `slug_available` RPC + Store-Swap

**Files:** Create `supabase/migrations/0009_slug_available.sql`; Modify `AtollCard/Stores/SupabaseCardStore.swift`.

- [ ] **Step 1: Migration schreiben** `supabase/migrations/0009_slug_available.sql`
```sql
-- Global slug availability check, callable by signed-in users (RLS would otherwise
-- hide other users' cards, so slugIsAvailable was blind across users).
create or replace function public.slug_available(p_slug text)
returns boolean language sql security definer set search_path = public stable as $$
  select not exists (select 1 from public.cards where slug = p_slug);
$$;
revoke execute on function public.slug_available(text) from public;
grant execute on function public.slug_available(text) to authenticated;
```

- [ ] **Step 2: `SupabaseCardStore.slugIsAvailable` umstellen**
Ersetze den bestehenden `slugIsAvailable`-Body durch:
```swift
    func slugIsAvailable(_ slug: String) async throws -> Bool {
        try await client.rpc("slug_available", params: ["p_slug": slug])
            .execute()
            .value
    }
```
(Protokoll + `InMemoryCardStore` bleiben unverändert.)

- [ ] **Step 3: Build verifizieren**
Run: `xcodegen generate && xcodebuild build -scheme AtollCard -destination 'platform=iOS Simulator,name=iPhone 16e,OS=26.2' 2>&1 | grep -iE "error:|BUILD (SUCCEEDED|FAILED)"`
Erwartet: BUILD SUCCEEDED. Falls die RPC-`params`-Signatur in 2.48 abweicht (z. B. expliziter Encodable-Typ nötig), anpassen und melden.

- [ ] **Step 4: Commit**
```bash
git add supabase/migrations/0009_slug_available.sql AtollCard/Stores/SupabaseCardStore.swift
git commit -m "feat(db): slug_available RPC + store uses it (cross-user slug check)

Co-Authored-By: Claude Opus 4.8 <noreply@anthropic.com>"
```
(Controller wendet 0009 auf lokal + Prod `bhkeplfkuismwyfiqcga` an.)

---

## Task 2: `ImageDownscaler` (ImageIO)

**Files:** Create `AtollCard/Features/CardEditor/ImageDownscaler.swift`; Test `AtollCardTests/ImageDownscalerTests.swift`.

- [ ] **Step 1: Failing test** `AtollCardTests/ImageDownscalerTests.swift`
```swift
import XCTest
import ImageIO
import CoreGraphics
@testable import AtollCard

final class ImageDownscalerTests: XCTestCase {
    /// Builds a large opaque JPEG in memory for input.
    private func makeJPEG(side: Int) throws -> Data {
        let cs = CGColorSpace(name: CGColorSpace.sRGB)!
        let ctx = CGContext(data: nil, width: side, height: side, bitsPerComponent: 8,
                            bytesPerRow: 0, space: cs,
                            bitmapInfo: CGImageAlphaInfo.noneSkipLast.rawValue)!
        ctx.setFillColor(CGColor(red: 0.1, green: 0.5, blue: 0.5, alpha: 1))
        ctx.fill(CGRect(x: 0, y: 0, width: side, height: side))
        let img = ctx.makeImage()!
        let out = NSMutableData()
        let dest = CGImageDestinationCreateWithData(out, "public.jpeg" as CFString, 1, nil)!
        CGImageDestinationAddImage(dest, img, nil)
        XCTAssertTrue(CGImageDestinationFinalize(dest))
        return out as Data
    }

    func test_downscalesLargeImage() throws {
        let big = try makeJPEG(side: 3000)
        let small = try XCTUnwrap(ImageDownscaler.downscaledJPEG(big, maxDimension: 512, quality: 0.8))
        XCTAssertLessThan(small.count, big.count)
        let src = CGImageSourceCreateWithData(small as CFData, nil)!
        let props = CGImageSourceCopyPropertiesAtIndex(src, 0, nil) as! [CFString: Any]
        let w = props[kCGImagePropertyPixelWidth] as! Int
        let h = props[kCGImagePropertyPixelHeight] as! Int
        XCTAssertLessThanOrEqual(max(w, h), 512)
    }

    func test_returnsNilForGarbage() {
        XCTAssertNil(ImageDownscaler.downscaledJPEG(Data([0x00, 0x01, 0x02]), maxDimension: 512, quality: 0.8))
    }
}
```

- [ ] **Step 2: Run → FAIL** (`ImageDownscaler` undefined).

- [ ] **Step 3: Implement** `AtollCard/Features/CardEditor/ImageDownscaler.swift`
```swift
import Foundation
import ImageIO
import UniformTypeIdentifiers

enum ImageDownscaler {
    /// Downscales image `data` so its longest edge is <= maxDimension and re-encodes as JPEG.
    /// Returns nil if the data is not a decodable image.
    static func downscaledJPEG(_ data: Data, maxDimension: CGFloat, quality: CGFloat) -> Data? {
        guard let src = CGImageSourceCreateWithData(data as CFData, nil) else { return nil }
        let opts: [CFString: Any] = [
            kCGImageSourceCreateThumbnailFromImageAlways: true,
            kCGImageSourceCreateThumbnailWithTransform: true,
            kCGImageSourceThumbnailMaxPixelSize: maxDimension,
        ]
        guard let thumb = CGImageSourceCreateThumbnailAtIndex(src, 0, opts as CFDictionary) else { return nil }
        let out = NSMutableData()
        guard let dest = CGImageDestinationCreateWithData(out, UTType.jpeg.identifier as CFString, 1, nil)
        else { return nil }
        CGImageDestinationAddImage(dest, thumb, [kCGImageDestinationLossyCompressionQuality: quality] as CFDictionary)
        guard CGImageDestinationFinalize(dest) else { return nil }
        return out as Data
    }
}
```

- [ ] **Step 4: Run → PASS** (2 Tests).

- [ ] **Step 5: Commit**
```bash
git add AtollCard/Features/CardEditor/ImageDownscaler.swift AtollCardTests/ImageDownscalerTests.swift
git commit -m "feat(ios): ImageIO downscaler for card media

Co-Authored-By: Claude Opus 4.8 <noreply@anthropic.com>"
```

---

## Task 3: `AppStores` MediaStore-DI + `CardEditorViewModel` Medien

**Files:** Modify `AtollCard/Stores/AppStores.swift`, `AtollCard/Features/CardEditor/CardEditorViewModel.swift`; Test `AtollCardTests/CardEditorViewModelTests.swift` (erweitern).

- [ ] **Step 1: Erweiterte Tests** an `AtollCardTests/CardEditorViewModelTests.swift` anhängen (bestehende Tests bleiben; ihre `CardEditorViewModel(...)`-Inits bekommen das neue `mediaStore`-Argument — siehe Step 3 zu Default). Neue Tests:
```swift
@MainActor
func test_uploadsPendingMediaAndSetsURLs() async throws {
    let store = InMemoryCardStore()
    let media = InMemoryMediaStore(publicBase: "https://x.supabase.co/storage/v1/object/public")
    let owner = UUID()
    let vm = CardEditorViewModel(store: store, mediaStore: media, ownerId: owner, editing: nil)
    vm.displayName = "Jane"; vm.slug = "jane"
    vm.pendingCoverData = Data([0x1]); vm.pendingPhotoData = Data([0x2])
    XCTAssertTrue(await vm.save())
    let card = try await store.cards(forOwner: owner).first!
    XCTAssertEqual(media.stored.count, 2)
    XCTAssertTrue(card.coverURL?.contains("/cover") == true)
    XCTAssertTrue(card.photoURL?.contains("/photo") == true)
}

@MainActor
func test_editPreservesExistingMediaURLs() async throws {
    let store = InMemoryCardStore()
    let media = InMemoryMediaStore(publicBase: "https://x.supabase.co/storage/v1/object/public")
    let owner = UUID()
    let existing = Card(id: UUID(), ownerId: owner, slug: "j", displayName: "J",
        title: nil, company: nil, theme: "default",
        coverURL: "https://x/cover.jpg", logoURL: nil, photoURL: "https://x/photo.jpg",
        visibility: .private, isActive: true)
    try await store.create(existing, fields: [])
    let vm = CardEditorViewModel(store: store, mediaStore: media, ownerId: owner, editing: existing)
    vm.displayName = "J2"            // edit a field, no new images
    XCTAssertTrue(await vm.save())
    let card = try await store.cards(forOwner: owner).first!
    XCTAssertEqual(card.coverURL, "https://x/cover.jpg")
    XCTAssertEqual(card.photoURL, "https://x/photo.jpg")
    XCTAssertEqual(media.stored.count, 0)   // nothing re-uploaded
}
```

- [ ] **Step 2: Run → FAIL** (`mediaStore:`-Param + `pendingCoverData` fehlen).

- [ ] **Step 3: `CardEditorViewModel` erweitern.** Neue Properties direkt nach `@Published var errorMessage`:
```swift
    @Published var pendingCoverData: Data?
    @Published var pendingPhotoData: Data?
    var coverURL: String?
    var photoURL: String?
    var logoURL: String?
```
`mediaStore`-Dep + Init: ergänze `private let mediaStore: MediaStoring`, ändere die Init-Signatur zu `init(store: CardStoring, mediaStore: MediaStoring, ownerId: UUID, editing: Card?)`, setze `self.mediaStore = mediaStore`, und im `if let c = editing`-Block:
```swift
            coverURL = c.coverURL
            photoURL = c.photoURL
            logoURL = c.logoURL
```
`save()` ersetzen durch:
```swift
    func save() async -> Bool {
        guard !displayName.trimmingCharacters(in: .whitespaces).isEmpty else {
            errorMessage = "Name darf nicht leer sein."; return false
        }
        guard !slug.trimmingCharacters(in: .whitespaces).isEmpty else {
            errorMessage = "Slug darf nicht leer sein."; return false
        }
        let id = editingId ?? UUID()
        do {
            if let data = pendingCoverData {
                coverURL = try await mediaStore.upload(data, owner: ownerId, card: id, kind: .cover).absoluteString
            }
            if let data = pendingPhotoData {
                photoURL = try await mediaStore.upload(data, owner: ownerId, card: id, kind: .photo).absoluteString
            }
            let card = Card(id: id, ownerId: ownerId, slug: slug, label: label,
                            displayName: displayName,
                            title: title.isEmpty ? nil : title,
                            company: company.isEmpty ? nil : company,
                            theme: "default", accentColor: accentColor,
                            coverURL: coverURL, logoURL: logoURL, photoURL: photoURL,
                            visibility: visibility, isActive: true)
            if editingId == nil { try await store.create(card, fields: fields) }
            else { try await store.update(card, fields: fields) }
            errorMessage = nil
            return true
        } catch {
            errorMessage = error.localizedDescription
            return false
        }
    }
```

- [ ] **Step 4: `AppStores` + MediaStore-DI** — Feld + Inits:
```swift
struct AppStores {
    let cardStore: CardStoring
    let mediaStore: MediaStoring
    let authenticator: Authenticating

    static let `default` = AppStores(
        cardStore: SupabaseCardStore(),
        mediaStore: SupabaseMediaStore(),
        authenticator: SupabaseAuthenticator()
    )
    static let preview = AppStores(
        cardStore: InMemoryCardStore(),
        mediaStore: InMemoryMediaStore(publicBase: "https://preview.supabase.co/storage/v1/object/public"),
        authenticator: PreviewAuthenticator()
    )
}
```

- [ ] **Step 5: Aufrufer nachziehen.** Jede `CardEditorViewModel(store:ownerId:editing:)`-Konstruktion (in `EditSheet`, `OnboardingView`, `CardEditorView`-Previews, evtl. `MyCardScreen`/`RootTabView`) bekommt `mediaStore:` — beziehe es aus dem durchgereichten `AppStores`/`stores.mediaStore`. Wo nur `cardStore` durchgereicht wird, zusätzlich `mediaStore` durchreichen. **Grep:** `grep -rn "CardEditorViewModel(" AtollCard` und alle Treffer anpassen.

- [ ] **Step 6: Run → PASS** (alle CardEditorViewModelTests inkl. 2 neue). Dann iOS-Test + macOS-Build grün.

- [ ] **Step 7: Commit**
```bash
git add AtollCard/Stores/AppStores.swift AtollCard/Features/CardEditor/CardEditorViewModel.swift AtollCardTests/CardEditorViewModelTests.swift AtollCard/Features
git commit -m "feat(ios): card editor uploads cover/photo, preserves URLs on edit

Co-Authored-By: Claude Opus 4.8 <noreply@anthropic.com>"
```

---

## Task 4: PhotosPicker-UI + Karten-Anzeige

**Files:** Modify `AtollCard/Features/CardEditor/CardEditorView.swift`, `AtollCard/Features/CardEditor/OnboardingView.swift`, `AtollCard/Features/Shell/BusinessCardView.swift`.

- [ ] **Step 1: PhotosPicker im Editor.** In `CardEditorView` (und im passenden Schritt von `OnboardingView`) je einen `PhotosPicker` für Cover + Profilfoto. Muster (anpassen an bestehende Form-Struktur):
```swift
import PhotosUI
// @State private var coverItem: PhotosPickerItem?
// @State private var photoItem: PhotosPickerItem?

PhotosPicker(selection: $photoItem, matching: .images) {
    Label("Profilfoto wählen", systemImage: "person.crop.circle")
}
.onChange(of: photoItem) { _, item in
    Task {
        if let data = try? await item?.loadTransferable(type: Data.self),
           let small = ImageDownscaler.downscaledJPEG(data, maxDimension: 512, quality: 0.8) {
            vm.pendingPhotoData = small
        }
    }
}
```
Cover analog mit `maxDimension: 1600` → `vm.pendingCoverData`. Vorschau-Thumbnail des gewählten (`pendingPhotoData`/`pendingCoverData` via `Image(uiImage:)`/`Image(nsImage:)` hinter `#if os`) **oder** des bestehenden (`AsyncImage(url:)`), plus „Entfernen" (setzt pending=nil und die URL=nil). `.onChange(of:)` Zwei-Parameter-Form ist iOS17+/macOS14+ — passt.

- [ ] **Step 2: Anzeige auf der Karte.** In `BusinessCardView`: wenn `card.photoURL` vorhanden → rundes `AsyncImage` statt Initialen-Avatar (Platzhalter = bisheriger Initialen-Avatar während Laden/Fehler); wenn `card.coverURL` vorhanden → `AsyncImage` als Header-Hintergrund (clipped), sonst bisheriger Gradient. URLs via `URL(string:)`.

- [ ] **Step 3: Build beide Plattformen + Tests**
```
xcodegen generate
xcodebuild test  -scheme AtollCard -destination 'platform=iOS Simulator,name=iPhone 16e,OS=26.2'
xcodebuild build -scheme AtollCard -destination 'platform=macOS,arch=arm64'
```
Erwartet: TEST SUCCEEDED, beide BUILD SUCCEEDED.

- [ ] **Step 4: Commit**
```bash
git add AtollCard/Features
git commit -m "feat(ios): PhotosPicker for cover/photo, render on business card

Co-Authored-By: Claude Opus 4.8 <noreply@anthropic.com>"
```

---

## Task 5: Verifikationsgate

**Files:** keine.

- [ ] **Step 1: Volle Suite + beide Builds** (`xcodegen generate`; iOS test; macOS build) — alles grün.
- [ ] **Step 2: Controller wendet `0009` auf lokal + Prod an** und verifiziert `slug_available` live (authenticated true für freien Slug, false für vergebenen).
- [ ] **Step 3: App-Boot + manueller Smoke** (Onboarding: Foto wählen → speichern → Karte zeigt Foto; Prod-Bucket erhält Objekt unter `<owner>/<card>/photo`).

---

## Self-Review
- **Spec-Abdeckung:** ImageDownscaler (T2), AppStores-DI (T3), VM Medien+URL-Erhalt (T3, inkl. Regressionstest), slug_available RPC+Store (T1), PhotosPicker-UI + Karten-Anzeige (T4), Backend-Apply + Smoke (T5). ✓
- **Platzhalter:** keine; voller Code für Migration, Downscaler, VM, Tests; UI mit konkreten API-Mustern (Views sind bestehend, Implementer passt an Struktur an). ✓
- **Typkonsistenz:** `MediaStoring.upload(_:owner:card:kind:) -> URL` + `MediaKind.cover/.photo` (M1) wie in VM (T3) genutzt; `CardEditorViewModel.init(store:mediaStore:ownerId:editing:)` einheitlich in T3 + allen Aufrufern (T3 Step 5); `pendingCoverData/pendingPhotoData` in VM (T3) = Picker (T4); `ImageDownscaler.downscaledJPEG(_:maxDimension:quality:)` (T2) = UI (T4). ✓
