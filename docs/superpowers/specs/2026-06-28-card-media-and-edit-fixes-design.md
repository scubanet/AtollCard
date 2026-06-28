# Card-Editor: Medien + Edit-Korrektheit — Design

**Datum:** 2026-06-28
**Status:** Entwurf zur Freigabe
**M2-Sub-Projekt 1 von n.** Macht den Karten-Editor medienfähig (Cover + Profilfoto via PhotosPicker) und behebt zwei M1-Backlog-Funde (Edit nullt Media-URLs; `slugIsAvailable` ist RLS-blind).

## Ziel
Nutzer wählt Cover-Bild + rundes Profilfoto aus der Mediathek; Bilder werden runterskaliert, in den `card-media`-Bucket geladen und auf der Karte angezeigt. Edit erhält bestehende Bilder. Slug-Verfügbarkeit prüft global (alle Nutzer).

## Scope-Entscheidungen
- Bilder: **Cover + Profilfoto** (beide).
- Quelle: **nur PhotosPicker** (Mediathek), cross-platform iOS+macOS. Keine Kamera.
- `card-media` bleibt public-read (private Bucket = separater M2-Punkt, nicht hier).

## Architektur / Komponenten

### `ImageDownscaler` (neu, ImageIO, cross-platform)
`static func downscaledJPEG(_ data: Data, maxDimension: CGFloat, quality: CGFloat) -> Data?`. Via `CGImageSourceCreateThumbnailAtIndex` (kCGImageSourceThumbnailMaxPixelSize = maxDimension, kCGImageSourceCreateThumbnailFromImageAlways) → `CGImageDestination` JPEG mit `kCGImageDestinationLossyCompressionQuality`. Kein UIKit/AppKit. Cover maxDimension ~1600, Foto ~512, quality ~0.8. Unit-testbar (Eingabe-Bild → kleineres, wieder dekodierbares JPEG).

### `AppStores` + MediaStore-DI
Feld `mediaStore: MediaStoring` ergänzen. `default` → `SupabaseMediaStore()`, `preview` → `InMemoryMediaStore(publicBase:)`. (Naht + beide Impls existieren aus M1.)

### `CardEditorViewModel` (erweitert)
- Neue Dep `mediaStore: MediaStoring`.
- Neue Felder: `coverURL/photoURL/logoURL` (aus `editing:` geladen → **Fix: Edit erhält URLs**), plus `pendingCoverData/pendingPhotoData: Data?` (vom Picker, schon runterskaliert).
- `save()`:
  1. card-id bestimmen (`editingId ?? UUID()`).
  2. Für jedes pending Bild: `try await mediaStore.upload(data, owner: ownerId, card: id, kind: .cover/.photo)` → URL in `coverURL`/`photoURL`.
  3. Card mit `coverURL/photoURL/logoURL` (neue **oder** durchgereichte bestehende) bauen → create/update.
- Upload-Fehler → `errorMessage`, kein Save.

### `SupabaseCardStore.slugIsAvailable` (Fix)
Ruft neue RPC: `let available: Bool = try await client.rpc("slug_available", params: ["p_slug": slug]).execute().value`. Protokoll unverändert. (`InMemoryCardStore` ist bereits korrekt.)

### UI
- `CardEditorView` + `OnboardingView`: `PhotosPicker` (Cover + Foto), Thumbnail-Vorschau des gewählten/bestehenden Bildes, „Entfernen". `PhotosPickerItem` → `loadTransferable(Data)` → `ImageDownscaler` → `vm.pendingCoverData/pendingPhotoData`.
- `BusinessCardView`: `AsyncImage(url: photoURL)` rund (Fallback Initialen), Cover als Header-Hintergrund (Fallback aktueller Gradient).

## Backend (lokal + Prod `bhkeplfkuismwyfiqcga`)
Migration `0009_slug_available.sql`:
```sql
create or replace function public.slug_available(p_slug text)
returns boolean language sql security definer set search_path = public stable as $$
  select not exists (select 1 from public.cards where slug = p_slug);
$$;
revoke execute on function public.slug_available(text) from public;
grant execute on function public.slug_available(text) to authenticated;
```
Lokal via `supabase db reset`; Prod via MCP `apply_migration`.

## Fehlerbehandlung
- Picker-Abbruch → kein Effekt.
- `loadTransferable`/Downscale schlägt fehl → kein pending-Bild gesetzt, kurze Meldung.
- Upload-Fehler in `save()` → `errorMessage`, Save bricht ab (Card wird nicht halb gespeichert).
- `slug_available`-RPC-Fehler → wie bisher als Save-Fehler behandelt.

## Tests
- `ImageDownscalerTests`: generiertes großes Bild (z. B. 3000px) → Output dekodierbar, max Kante ≤ Ziel, Bytes < Original.
- `CardEditorViewModelTests` (erweitert, Fake `InMemoryMediaStore`):
  - pending Cover+Foto → `mediaStore` erhält 2 Uploads; `card.coverURL/photoURL` = deterministische URLs.
  - **Edit ohne neue Bilder → bestehende `coverURL/photoURL` bleiben erhalten** (Regressionstest für M1-Bug).
- Build iOS+macOS grün; Gesamtsuite grün.

## Bewusst nicht hier
- Kamera-Quelle; `card-media` privater Bucket + signed URLs; Logo-Upload-UI (Feld bleibt durchgereicht, keine UI); Bild-Croppen.
