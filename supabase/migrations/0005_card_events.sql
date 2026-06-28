create type public.card_event_type as enum ('view','tap','save','share');

create table public.card_events (
  id bigint generated always as identity primary key,
  card_id uuid not null references public.cards(id) on delete cascade,
  type public.card_event_type not null,
  occurred_at timestamptz not null default now(),
  coarse_geo text,
  referrer text
);

create index card_events_card_id_idx on public.card_events(card_id);

alter table public.card_events enable row level security;
create policy "card_events_select_via_owner" on public.card_events for select
  using (exists (select 1 from public.cards c where c.id = card_events.card_id and c.owner_id = auth.uid()));
