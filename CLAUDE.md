# AtollCard — Claude Code Project Guide

AtollCard ist eine digitale Visitenkarte (iOS/macOS + Web-Profil), funktionaler Blinq-Klon **ohne AI Notetaker**. Eigenentwicklung, eigenes Brand — keine Blinq-Assets.

## Ausführung
Implementiere strikt nach den M1-Plänen in der PKA (`~/Desktop/PKA/Deliverables/2026-06-28-atollcard-*`) task-by-task mit `superpowers:subagent-driven-development`. TDD, häufige Commits. Siehe `HANDOFF.md` für den aktuellen Stand.

## Reihenfolge
1. Backend (`supabase/`) verifizieren — ist der Vertrag für alles andere.
2. Web (`web/`) — bereits implementiert + getestet; nur `npm install` + lokal gegen Supabase prüfen.
3. iOS (`AtollCard/`) — ab Task 0 neu in Xcode.

## Stack
SwiftUI (iOS+macOS), Supabase (Postgres/RLS/Storage/Auth), Vite+TS Web auf atoll-os.com (GH Actions → rsync Infomaniak). Visuelle Identität: Manrope, Glas, Akzent #0E7C86 — Mockup unter `Deliverables/2026-06-28-atollcard-design-mockup/`.
