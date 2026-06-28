begin;
select plan(7);
insert into auth.users (id, email) values
  ('aaaaaaaa-0000-0000-0000-000000000001', 'owner@example.com'),
  ('bbbbbbbb-0000-0000-0000-000000000002', 'other@example.com');
set local role authenticated;
select set_config('request.jwt.claims', '{"sub":"aaaaaaaa-0000-0000-0000-000000000001","role":"authenticated"}', true);
insert into public.cards (id, owner_id, slug, display_name, visibility)
values ('cccccccc-0000-0000-0000-000000000001','aaaaaaaa-0000-0000-0000-000000000001','jane-doe','Jane Doe','public');
select is((select count(*)::int from public.cards), 1, 'owner sees own card');
select throws_ok($$insert into public.cards (owner_id, slug, display_name) values ('aaaaaaaa-0000-0000-0000-000000000001','jane-doe','Dup')$$, '23505', null, 'slug is unique');
select set_config('request.jwt.claims', '{"sub":"bbbbbbbb-0000-0000-0000-000000000002","role":"authenticated"}', true);
select is((select count(*)::int from public.cards), 0, 'other user cannot read foreign card via RLS');
select throws_ok($$insert into public.cards (owner_id, slug, display_name) values ('aaaaaaaa-0000-0000-0000-000000000001','steal','Steal')$$, '42501', null, 'cannot insert card for another owner');
select has_column('public', 'cards', 'visibility', 'cards has visibility');
select has_column('public', 'cards', 'accent_color', 'cards has accent_color');
select has_column('public', 'cards', 'cover_url', 'cards has cover_url');
select * from finish();
rollback;
