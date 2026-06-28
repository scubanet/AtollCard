-- Global slug availability check, callable by signed-in users (RLS would otherwise
-- hide other users' cards, so slugIsAvailable was blind across users).
create or replace function public.slug_available(p_slug text)
returns boolean language sql security definer set search_path = public stable as $$
  select not exists (select 1 from public.cards where slug = p_slug);
$$;
-- Supabase default privileges grant EXECUTE to anon/authenticated on new public
-- functions; revoke from public AND anon so only signed-in users can probe slugs.
revoke execute on function public.slug_available(text) from public, anon;
grant execute on function public.slug_available(text) to authenticated;
