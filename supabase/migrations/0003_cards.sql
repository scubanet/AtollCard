create type public.card_visibility as enum ('public', 'unlisted', 'private');

create table public.cards (
  id uuid primary key default gen_random_uuid(),
  owner_id uuid not null references public.profiles(id) on delete cascade,
  slug text not null unique,
  label text not null default 'Karte',
  display_name text not null,
  title text,
  company text,
  theme text not null default 'default',
  accent_color text not null default '#0E7C86',
  cover_url text,
  logo_url text,
  photo_url text,
  visibility public.card_visibility not null default 'private',
  is_active boolean not null default true,
  created_at timestamptz not null default now()
);

create index cards_owner_id_idx on public.cards(owner_id);

alter table public.cards enable row level security;
create policy "cards_select_own" on public.cards for select using (auth.uid() = owner_id);
create policy "cards_insert_own" on public.cards for insert with check (auth.uid() = owner_id);
create policy "cards_update_own" on public.cards for update using (auth.uid() = owner_id);
create policy "cards_delete_own" on public.cards for delete using (auth.uid() = owner_id);
