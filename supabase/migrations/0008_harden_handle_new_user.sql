-- handle_new_user is a trigger function; it must not be callable as an RPC.
-- (Supabase advisor: anon/authenticated can execute SECURITY DEFINER function.)
-- The default EXECUTE grant on functions goes to PUBLIC, which anon/authenticated
-- inherit, so the revoke must target PUBLIC (not just the two roles).
revoke execute on function public.handle_new_user() from public;
