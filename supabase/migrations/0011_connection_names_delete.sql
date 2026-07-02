-- Signaturwechsel: alte 7-Arg-Funktion entfernen, bevor die 9-Arg-Variante angelegt wird
drop function public.record_connection(text,text,text,text,text,text,text);

alter table public.connections
  add column first_name text,
  add column last_name text;

-- Owner darf Leads eigener Karten löschen
create policy "connections_delete_via_owner" on public.connections for delete
  using (exists (select 1 from public.cards c where c.id = connections.card_id and c.owner_id = auth.uid()));

-- RPC: neue optionale Params; name wird immer befüllt (Kompat mit altem Web/Anzeige)
create or replace function public.record_connection(
  p_slug text, p_name text default null, p_email text default null, p_phone text default null,
  p_company text default null, p_note text default null, p_coarse_geo text default null,
  p_first_name text default null, p_last_name text default null)
returns void language plpgsql security definer set search_path = public as $$
declare v_card_id uuid; v_name text;
begin
  v_name := nullif(trim(concat_ws(' ', p_first_name, p_last_name)), '');
  if v_name is null then v_name := nullif(trim(coalesce(p_name, '')), ''); end if;
  if v_name is null then return; end if;
  select id into v_card_id from public.cards
    where slug = p_slug and visibility = 'public' and is_active = true;
  if v_card_id is null then return; end if;
  insert into public.connections (card_id, name, first_name, last_name, email, phone, company, note, coarse_geo)
  values (v_card_id, v_name, nullif(trim(coalesce(p_first_name,'')),''), nullif(trim(coalesce(p_last_name,'')),''),
          p_email, p_phone, p_company, p_note, p_coarse_geo);
end; $$;

revoke execute on function public.record_connection(text,text,text,text,text,text,text,text,text) from public;
grant execute on function public.record_connection(text,text,text,text,text,text,text,text,text) to anon, authenticated;
