begin;
select plan(3);
insert into auth.users (id, email) values
  ('aaaaaaaa-0000-0000-0000-000000000001', 'owner@example.com'),
  ('bbbbbbbb-0000-0000-0000-000000000002', 'other@example.com');
set local role authenticated;
select set_config('request.jwt.claims', '{"sub":"aaaaaaaa-0000-0000-0000-000000000001","role":"authenticated"}', true);
insert into public.cards (id, owner_id, slug, display_name)
values ('cccccccc-0000-0000-0000-000000000001','aaaaaaaa-0000-0000-0000-000000000001','jane-doe','Jane Doe');
insert into public.card_fields (card_id, type, label, value, sort_order)
values ('cccccccc-0000-0000-0000-000000000001','email','Work','jane@acme.com',0);
select is((select count(*)::int from public.card_fields), 1, 'owner sees own card field');
select set_config('request.jwt.claims', '{"sub":"bbbbbbbb-0000-0000-0000-000000000002","role":"authenticated"}', true);
select is((select count(*)::int from public.card_fields), 0, 'foreign card fields hidden by RLS');
select throws_ok($$insert into public.card_fields (card_id, type, label, value) values ('cccccccc-0000-0000-0000-000000000001','phone','x','123')$$, '42501', null, 'cannot insert field onto foreign card');
select * from finish();
rollback;
