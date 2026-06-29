create table public.connections (
  id uuid primary key default gen_random_uuid(),
  card_id uuid not null references public.cards(id) on delete cascade,
  name text not null,
  email text,
  phone text,
  company text,
  note text,
  coarse_geo text,
  created_at timestamptz not null default now()
);
create index connections_card_id_idx on public.connections(card_id);

alter table public.connections enable row level security;
create policy "connections_select_via_owner" on public.connections for select
  using (exists (select 1 from public.cards c where c.id = connections.card_id and c.owner_id = auth.uid()));

create or replace function public.record_connection(
  p_slug text, p_name text, p_email text default null, p_phone text default null,
  p_company text default null, p_note text default null, p_coarse_geo text default null)
returns void language plpgsql security definer set search_path = public as $$
declare v_card_id uuid;
begin
  if coalesce(trim(p_name), '') = '' then return; end if;
  select id into v_card_id from public.cards
    where slug = p_slug and visibility = 'public' and is_active = true;
  if v_card_id is null then return; end if;
  insert into public.connections (card_id, name, email, phone, company, note, coarse_geo)
  values (v_card_id, trim(p_name), p_email, p_phone, p_company, p_note, p_coarse_geo);
end; $$;

revoke execute on function public.record_connection(text,text,text,text,text,text,text) from public;
grant execute on function public.record_connection(text,text,text,text,text,text,text) to anon, authenticated;
