begin;
select plan(7);

insert into auth.users (id, email) values
  ('aaaaaaaa-0000-0000-0000-000000000001', 'owner@example.com'),
  ('bbbbbbbb-0000-0000-0000-000000000002', 'other@example.com');

insert into public.cards (id, owner_id, slug, display_name, visibility)
values
  ('cccccccc-0000-0000-0000-000000000001','aaaaaaaa-0000-0000-0000-000000000001','jane-doe','Jane Doe','public'),
  ('cccccccc-0000-0000-0000-000000000002','aaaaaaaa-0000-0000-0000-000000000001','secret','Secret','private');

set local role anon;
select lives_ok(
  $$select record_connection('jane-doe','Max Muster','max@x.com','123','Acme','Hi')$$,
  'anon records a connection for a public card');
select lives_ok(
  $$select record_connection('secret','Nope')$$,
  'recording against private card is a no-op (no error)');

set local role authenticated;
select set_config('request.jwt.claims', '{"sub":"aaaaaaaa-0000-0000-0000-000000000001","role":"authenticated"}', true);
select is((select count(*)::int from public.connections), 1, 'owner sees only the public-card lead');

select set_config('request.jwt.claims', '{"sub":"bbbbbbbb-0000-0000-0000-000000000002","role":"authenticated"}', true);
select is((select count(*)::int from public.connections), 0, 'foreign user sees no leads (RLS)');

-- split-name recording
set local role anon;
select lives_ok(
  $$select record_connection('jane-doe', p_first_name => 'Max', p_last_name => 'Muster')$$,
  'records with split names');

set local role authenticated;
select set_config('request.jwt.claims', '{"sub":"aaaaaaaa-0000-0000-0000-000000000001","role":"authenticated"}', true);
select is(
  (select count(*)::int from public.connections where first_name='Max' and last_name='Muster' and name='Max Muster'),
  1, 'split names stored and combined into name');

-- owner can delete
delete from public.connections;
select is((select count(*)::int from public.connections), 0, 'owner deleted own leads');

select * from finish();
rollback;
