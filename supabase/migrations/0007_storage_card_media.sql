insert into storage.buckets (id, name, public) values ('card-media', 'card-media', true)
on conflict (id) do nothing;

create policy "card_media_public_read" on storage.objects for select using (bucket_id = 'card-media');
create policy "card_media_owner_write" on storage.objects for insert
  with check (bucket_id = 'card-media' and (storage.foldername(name))[1] = auth.uid()::text);
create policy "card_media_owner_update" on storage.objects for update
  using (bucket_id = 'card-media' and (storage.foldername(name))[1] = auth.uid()::text);
create policy "card_media_owner_delete" on storage.objects for delete
  using (bucket_id = 'card-media' and (storage.foldername(name))[1] = auth.uid()::text);
