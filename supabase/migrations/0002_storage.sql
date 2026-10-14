-- Public bucket for listing photos (only approved-listing photos are meant to be shown;
-- paths are unguessable UUIDs). Private bucket for identity/ownership evidence.
insert into storage.buckets (id, name, public, file_size_limit, allowed_mime_types)
values ('cs-property-photos', 'cs-property-photos', true, 5242880, array['image/jpeg','image/png','image/webp'])
on conflict (id) do nothing;

insert into storage.buckets (id, name, public, file_size_limit, allowed_mime_types)
values ('cs-verification-docs', 'cs-verification-docs', false, 10485760, array['image/jpeg','image/png','application/pdf'])
on conflict (id) do nothing;

-- Path convention: <auth.uid()>/<property_id>/<file>
create policy cs_photos_owner_insert on storage.objects for insert to authenticated
  with check (bucket_id = 'cs-property-photos' and (storage.foldername(name))[1] = auth.uid()::text);
create policy cs_photos_owner_update on storage.objects for update to authenticated
  using (bucket_id = 'cs-property-photos' and (storage.foldername(name))[1] = auth.uid()::text);
create policy cs_photos_owner_delete on storage.objects for delete to authenticated
  using (bucket_id = 'cs-property-photos' and (storage.foldername(name))[1] = auth.uid()::text);

create policy cs_vdocs_owner_insert on storage.objects for insert to authenticated
  with check (bucket_id = 'cs-verification-docs' and (storage.foldername(name))[1] = auth.uid()::text);
create policy cs_vdocs_owner_read on storage.objects for select to authenticated
  using (bucket_id = 'cs-verification-docs' and ((storage.foldername(name))[1] = auth.uid()::text or public.cs_is_admin()));
