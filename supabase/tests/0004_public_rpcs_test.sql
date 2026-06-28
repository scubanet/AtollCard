begin;
select plan(4);
insert into auth.users (id, email) values ('aaaaaaaa-0000-0000-0000-000000000001', 'owner@example.com');
insert into public.cards (id, owner_id, slug, display_name, visibility) values
  ('cccccccc-0000-0000-0000-000000000001','aaaaaaaa-0000-0000-0000-000000000001','jane-doe','Jane Doe','public'),
  ('cccccccc-0000-0000-0000-000000000002','aaaaaaaa-0000-0000-0000-000000000001','secret','Secret','private');
insert into public.card_fields (card_id, type, label, value, sort_order)
values ('cccccccc-0000-0000-0000-000000000001','email','Work','jane@acme.com',0);
set local role anon;
select is((select (get_public_card('jane-doe')).display_name), 'Jane Doe', 'get_public_card returns public card by slug');
select is((select jsonb_array_length((get_public_card('jane-doe')).fields)), 1, 'get_public_card includes card_fields');
select is((select (get_public_card('secret')).display_name), null, 'get_public_card hides non-public cards');
select lives_ok($$select record_card_event('jane-doe','view','CH')$$, 'record_card_event inserts an anonymized view event');
select * from finish();
rollback;
