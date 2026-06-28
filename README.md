# AtollCard

Digitale Visitenkarte (iOS/macOS + öffentliches Web-Profil). Funktionaler Blinq-Klon **ohne AI Notetaker** — Eigenentwicklung, eigenes Brand.

## Aufbau
- `web/` — öffentliches Empfänger-Profil (Vite + TS). `card.atoll-os.com/<slug>`. **Tests laufen grün.**
- `supabase/` — Datenmodell, RLS, öffentliche RPCs, Storage (Migrationen + pgTAP-Tests).
- `AtollCard/` — iOS/macOS SwiftUI-App (wird in Xcode auf dem Mac erzeugt, siehe Plan).

## Pläne (Quelle der Wahrheit)
Liegen in der PKA unter `Deliverables/2026-06-28-atollcard-*`: Design-Spec, M1-Backend-, M1-iOS-, M1-Web-Plan + Design-Mockup. Ausführung task-by-task per `superpowers:subagent-driven-development`.

## Lokal starten

### Web (funktioniert ohne Mac-Tools)
```bash
cd web && npm install && npm test       # 23 Tests grün
# .env.local mit VITE_SUPABASE_URL / VITE_SUPABASE_ANON_KEY anlegen, dann:
npm run dev
```

### Backend (braucht Docker Desktop)
```bash
supabase start
supabase db reset      # wendet migrations 0001–0007 an
supabase test db       # pgTAP-Tests
supabase gen types typescript --local > supabase/types/database.types.ts
```

### iOS/macOS (braucht Xcode)
Siehe M1-iOS-Plan, Task 0 (Xcode-Projekt anlegen), dann Tasks 1–12.
