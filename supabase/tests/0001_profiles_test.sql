begin;
select plan(3);
insert into auth.users (id, email) values ('11111111-1111-1111-1111-111111111111', 'a@example.com');
select is((select count(*)::int from public.profiles where id = '11111111-1111-1111-1111-111111111111'), 1, 'profile auto-created');
select is((select relrowsecurity from pg_class where oid = 'public.profiles'::regclass), true, 'RLS enabled on profiles');
select has_column('public', 'profiles', 'display_name', 'profiles has display_name');
select * from finish();
rollback;
