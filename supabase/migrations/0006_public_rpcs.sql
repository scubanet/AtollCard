create type public.public_card as (
  display_name text, title text, company text, theme text,
  accent_color text, cover_url text, logo_url text, photo_url text, fields jsonb
);

create or replace function public.get_public_card(p_slug text)
returns public.public_card language sql security definer set search_path = public stable as $$
  select c.display_name, c.title, c.company, c.theme, c.accent_color, c.cover_url, c.logo_url, c.photo_url,
    coalesce((select jsonb_agg(jsonb_build_object('type', f.type, 'label', f.label, 'value', f.value) order by f.sort_order)
      from public.card_fields f where f.card_id = c.id), '[]'::jsonb) as fields
  from public.cards c
  where c.slug = p_slug and c.visibility = 'public' and c.is_active = true;
$$;

create or replace function public.record_card_event(p_slug text, p_type public.card_event_type, p_coarse_geo text default null)
returns void language plpgsql security definer set search_path = public as $$
declare v_card_id uuid;
begin
  select id into v_card_id from public.cards where slug = p_slug and visibility = 'public' and is_active = true;
  if v_card_id is null then return; end if;
  insert into public.card_events (card_id, type, coarse_geo) values (v_card_id, p_type, p_coarse_geo);
end;
$$;

grant execute on function public.get_public_card(text) to anon, authenticated;
grant execute on function public.record_card_event(text, public.card_event_type, text) to anon, authenticated;
