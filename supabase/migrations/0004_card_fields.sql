create type public.card_field_type as enum ('phone','email','url','social','address','custom');

create table public.card_fields (
  id uuid primary key default gen_random_uuid(),
  card_id uuid not null references public.cards(id) on delete cascade,
  type public.card_field_type not null,
  label text not null,
  value text not null,
  sort_order int not null default 0
);

create index card_fields_card_id_idx on public.card_fields(card_id);

alter table public.card_fields enable row level security;
create policy "card_fields_select_via_owner" on public.card_fields for select
  using (exists (select 1 from public.cards c where c.id = card_fields.card_id and c.owner_id = auth.uid()));
create policy "card_fields_insert_via_owner" on public.card_fields for insert
  with check (exists (select 1 from public.cards c where c.id = card_fields.card_id and c.owner_id = auth.uid()));
create policy "card_fields_update_via_owner" on public.card_fields for update
  using (exists (select 1 from public.cards c where c.id = card_fields.card_id and c.owner_id = auth.uid()));
create policy "card_fields_delete_via_owner" on public.card_fields for delete
  using (exists (select 1 from public.cards c where c.id = card_fields.card_id and c.owner_id = auth.uid()));
