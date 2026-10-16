-- CampusStay schema. Separate from any other product. Run in order.
create extension if not exists pgcrypto;

create type cs_user_role as enum ('student','landlord','agent','admin');
create type cs_moderation_status as enum ('draft','pending','approved','rejected','needs_changes');
create type cs_availability_status as enum ('available','paused','rented');
create type cs_verification_level as enum ('unverified','pending','verified');
create type cs_room_type as enum ('single_room','shared_room','self_contain','apartment','hostel');
create type cs_viewing_status as enum ('requested','confirmed','declined','cancelled');
create type cs_report_status as enum ('open','reviewing','actioned','dismissed');

create table cs_profiles (
  id uuid primary key references auth.users(id) on delete cascade,
  role cs_user_role not null default 'student',
  full_name text,
  is_suspended boolean not null default false,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create or replace function cs_is_admin() returns boolean
language sql stable security definer set search_path = public as $$
  select exists (select 1 from cs_profiles where id = auth.uid() and role = 'admin' and not is_suspended);
$$;

create or replace function cs_is_active_user() returns boolean
language sql stable security definer set search_path = public as $$
  select exists (select 1 from cs_profiles where id = auth.uid() and not is_suspended);
$$;

-- Role is chosen at sign-up from a fixed whitelist. 'admin' can never be self-assigned.
create or replace function cs_handle_new_user() returns trigger
language plpgsql security definer set search_path = public as $$
begin
  insert into cs_profiles (id, role, full_name)
  values (new.id,
    case new.raw_user_meta_data->>'role' when 'landlord' then 'landlord'::cs_user_role
                                         when 'agent' then 'agent'::cs_user_role
                                         else 'student'::cs_user_role end,
    left(coalesce(new.raw_user_meta_data->>'full_name',''), 100));
  return new;
end $$;
create trigger cs_on_auth_user_created after insert on auth.users
  for each row execute function cs_handle_new_user();

create or replace function cs_guard_profile_update() returns trigger
language plpgsql as $$
begin
  if not cs_is_admin() then
    new.role := old.role;
    new.is_suspended := old.is_suspended;
  end if;
  new.updated_at := now();
  return new;
end $$;
create trigger trg_guard_profile before update on cs_profiles
  for each row execute function cs_guard_profile_update();

create table cs_universities (
  id uuid primary key default gen_random_uuid(),
  name text not null unique,
  short_name text not null,
  city text, state text,
  lat double precision, lng double precision
);

create table cs_properties (
  id uuid primary key default gen_random_uuid(),
  owner_id uuid not null references cs_profiles(id) on delete cascade,
  university_id uuid references cs_universities(id),
  title text not null check (char_length(title) between 5 and 120),
  description text not null default '' check (char_length(description) <= 4000),
  area text not null check (char_length(area) between 2 and 120),
  rent_ngn integer not null check (rent_ngn > 0 and rent_ngn < 100000000),
  rent_period text not null default 'year' check (rent_period in ('month','year')),
  extra_fees_note text check (char_length(extra_fees_note) <= 1000),
  distance_km numeric(5,1) check (distance_km >= 0),
  room_type cs_room_type not null,
  moderation_status cs_moderation_status not null default 'draft',
  availability_status cs_availability_status not null default 'available',
  verification_level cs_verification_level not null default 'unverified',
  expires_at timestamptz,
  views_count integer not null default 0,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);
create index on cs_properties (university_id);
create index on cs_properties (owner_id);
create index on cs_properties (moderation_status, availability_status, expires_at);
create index on cs_properties (rent_ngn);
create unique index cs_properties_no_dupes on cs_properties (owner_id, lower(title), lower(area));

-- Owners cannot set moderation, verification or ownership. Server decides.
create or replace function cs_guard_property() returns trigger
language plpgsql security definer set search_path = public as $$
begin
  if tg_op = 'INSERT' then
    if not cs_is_admin() then
      new.moderation_status := 'draft';
      new.verification_level := 'unverified';
      new.expires_at := null;
      new.views_count := 0;
    end if;
    return new;
  end if;
  new.owner_id := old.owner_id;
  new.updated_at := now();
  if not cs_is_admin() then
    new.verification_level := old.verification_level;
    new.expires_at := old.expires_at;
    new.views_count := old.views_count;
    if new.moderation_status is distinct from old.moderation_status then
      if not (new.moderation_status = 'pending' and old.moderation_status in ('draft','needs_changes','rejected')) then
        new.moderation_status := old.moderation_status;
      end if;
    end if;
  end if;
  return new;
end $$;
create trigger trg_guard_property before insert or update on cs_properties
  for each row execute function cs_guard_property();

create table cs_property_photos (
  id uuid primary key default gen_random_uuid(),
  property_id uuid not null references cs_properties(id) on delete cascade,
  storage_path text not null,
  sort_order integer not null default 0,
  created_at timestamptz not null default now()
);
create index on cs_property_photos (property_id, sort_order);

create table cs_amenities (
  id smallint primary key,
  code text not null unique,
  label text not null
);
insert into cs_amenities (id, code, label) values
 (1,'wifi','WiFi'),(2,'water','Water'),(3,'electricity','Electricity'),(4,'parking','Parking'),
 (5,'cctv','CCTV'),(6,'kitchen','Kitchen'),(7,'laundry','Laundry'),(8,'ac','AC');

create table cs_property_amenities (
  property_id uuid references cs_properties(id) on delete cascade,
  amenity_id smallint references cs_amenities(id),
  primary key (property_id, amenity_id)
);

create table cs_favourites (
  user_id uuid references cs_profiles(id) on delete cascade,
  property_id uuid references cs_properties(id) on delete cascade,
  created_at timestamptz not null default now(),
  primary key (user_id, property_id)
);

create table cs_viewing_requests (
  id uuid primary key default gen_random_uuid(),
  property_id uuid not null references cs_properties(id) on delete cascade,
  student_id uuid not null references cs_profiles(id) on delete cascade,
  preferred_at timestamptz not null check (preferred_at > now() - interval '1 day'),
  note text check (char_length(note) <= 1000),
  status cs_viewing_status not null default 'requested',
  created_at timestamptz not null default now()
);
create index on cs_viewing_requests (property_id);
create index on cs_viewing_requests (student_id);

create table cs_conversations (
  id uuid primary key default gen_random_uuid(),
  property_id uuid not null references cs_properties(id) on delete cascade,
  student_id uuid not null references cs_profiles(id) on delete cascade,
  landlord_id uuid not null references cs_profiles(id) on delete cascade,
  created_at timestamptz not null default now(),
  unique (property_id, student_id)
);
create index on cs_conversations (student_id);
create index on cs_conversations (landlord_id);

create table cs_messages (
  id uuid primary key default gen_random_uuid(),
  conversation_id uuid not null references cs_conversations(id) on delete cascade,
  sender_id uuid not null references cs_profiles(id) on delete cascade,
  body text not null check (char_length(body) between 1 and 2000),
  read_at timestamptz,
  created_at timestamptz not null default now()
);
create index on cs_messages (conversation_id, created_at);

create or replace function cs_guard_message_update() returns trigger
language plpgsql as $$
begin
  if new.body is distinct from old.body or new.sender_id is distinct from old.sender_id
     or new.conversation_id is distinct from old.conversation_id then
    raise exception 'messages are immutable except read_at';
  end if;
  return new;
end $$;
create trigger trg_guard_message before update on cs_messages
  for each row execute function cs_guard_message_update();

create table cs_blocks (
  blocker_id uuid references cs_profiles(id) on delete cascade,
  blocked_id uuid references cs_profiles(id) on delete cascade,
  created_at timestamptz not null default now(),
  primary key (blocker_id, blocked_id),
  check (blocker_id <> blocked_id)
);

create table cs_reports (
  id uuid primary key default gen_random_uuid(),
  reporter_id uuid not null references cs_profiles(id) on delete cascade,
  target_type text not null check (target_type in ('property','user','message')),
  target_id uuid not null,
  reason text not null check (char_length(reason) between 2 and 200),
  details text check (char_length(details) <= 2000),
  status cs_report_status not null default 'open',
  created_at timestamptz not null default now()
);
create index on cs_reports (status, created_at);

create table cs_notifications (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references cs_profiles(id) on delete cascade,
  kind text not null,
  title text not null,
  body text,
  read_at timestamptz,
  created_at timestamptz not null default now()
);
create index on cs_notifications (user_id, created_at desc);

-- Private verification evidence. Files live in the private 'cs-verification-docs' bucket.
create table cs_verification_submissions (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references cs_profiles(id) on delete cascade,
  property_id uuid references cs_properties(id) on delete cascade,
  doc_type text not null check (doc_type in ('id_card','agreement','property_document')),
  storage_path text not null,
  status text not null default 'pending' check (status in ('pending','approved','rejected')),
  reviewed_by uuid references cs_profiles(id),
  review_note text,
  created_at timestamptz not null default now()
);

create table cs_audit_events (
  id bigint generated always as identity primary key,
  actor_id uuid references cs_profiles(id),
  action text not null,
  target_type text not null,
  target_id uuid,
  details jsonb not null default '{}',
  created_at timestamptz not null default now()
);

-- =========================== RLS ===========================
alter table cs_profiles enable row level security;
alter table cs_universities enable row level security;
alter table cs_properties enable row level security;
alter table cs_property_photos enable row level security;
alter table cs_amenities enable row level security;
alter table cs_property_amenities enable row level security;
alter table cs_favourites enable row level security;
alter table cs_viewing_requests enable row level security;
alter table cs_conversations enable row level security;
alter table cs_messages enable row level security;
alter table cs_blocks enable row level security;
alter table cs_reports enable row level security;
alter table cs_notifications enable row level security;
alter table cs_verification_submissions enable row level security;
alter table cs_audit_events enable row level security;

create policy profiles_select on cs_profiles for select using (id = auth.uid() or cs_is_admin());
create policy profiles_update on cs_profiles for update using (id = auth.uid() or cs_is_admin()) with check (id = auth.uid() or cs_is_admin());

create policy uni_read on cs_universities for select using (true);
create policy uni_admin on cs_universities for all using (cs_is_admin()) with check (cs_is_admin());
create policy amen_read on cs_amenities for select using (true);

create policy prop_public on cs_properties for select using (
  moderation_status = 'approved' and availability_status = 'available'
  and (expires_at is null or expires_at > now())
);
create policy prop_owner_read on cs_properties for select using (owner_id = auth.uid());
create policy prop_admin_read on cs_properties for select using (cs_is_admin());
create policy prop_insert on cs_properties for insert with check (
  owner_id = auth.uid() and cs_is_active_user()
  and exists (select 1 from cs_profiles where id = auth.uid() and role in ('landlord','agent'))
);
create policy prop_update on cs_properties for update using (owner_id = auth.uid() or cs_is_admin()) with check (owner_id = auth.uid() or cs_is_admin());
create policy prop_delete on cs_properties for delete using (owner_id = auth.uid() or cs_is_admin());

-- Child tables follow the parent's visibility (the subquery runs under cs_properties RLS).
create policy photo_read on cs_property_photos for select using (exists (select 1 from cs_properties p where p.id = property_id));
create policy photo_write on cs_property_photos for all
  using (exists (select 1 from cs_properties p where p.id = property_id and p.owner_id = auth.uid()))
  with check (exists (select 1 from cs_properties p where p.id = property_id and p.owner_id = auth.uid()));
create policy pam_read on cs_property_amenities for select using (exists (select 1 from cs_properties p where p.id = property_id));
create policy pam_write on cs_property_amenities for all
  using (exists (select 1 from cs_properties p where p.id = property_id and p.owner_id = auth.uid()))
  with check (exists (select 1 from cs_properties p where p.id = property_id and p.owner_id = auth.uid()));

create policy fav_own on cs_favourites for all using (user_id = auth.uid()) with check (user_id = auth.uid());

create policy vr_student_read on cs_viewing_requests for select using (student_id = auth.uid());
create policy vr_owner_read on cs_viewing_requests for select using (exists (select 1 from cs_properties p where p.id = property_id and p.owner_id = auth.uid()));
create policy vr_insert on cs_viewing_requests for insert with check (
  student_id = auth.uid() and cs_is_active_user() and status = 'requested'
  and exists (select 1 from cs_properties p where p.id = property_id)
);
create policy vr_student_cancel on cs_viewing_requests for update using (student_id = auth.uid()) with check (student_id = auth.uid() and status = 'cancelled');
create policy vr_owner_decide on cs_viewing_requests for update
  using (exists (select 1 from cs_properties p where p.id = property_id and p.owner_id = auth.uid()))
  with check (status in ('confirmed','declined') and exists (select 1 from cs_properties p where p.id = property_id and p.owner_id = auth.uid()));

-- Conversations are created only through cs_start_enquiry().
create policy conv_read on cs_conversations for select using (student_id = auth.uid() or landlord_id = auth.uid());

create policy msg_read on cs_messages for select using (exists (
  select 1 from cs_conversations c where c.id = conversation_id and (c.student_id = auth.uid() or c.landlord_id = auth.uid())));
create policy msg_insert on cs_messages for insert with check (
  sender_id = auth.uid() and cs_is_active_user() and exists (
    select 1 from cs_conversations c where c.id = conversation_id
      and (c.student_id = auth.uid() or c.landlord_id = auth.uid())
      and not exists (select 1 from cs_blocks b where (b.blocker_id = c.student_id and b.blocked_id = c.landlord_id)
                                              or (b.blocker_id = c.landlord_id and b.blocked_id = c.student_id))));
create policy msg_mark_read on cs_messages for update using (sender_id <> auth.uid() and exists (
  select 1 from cs_conversations c where c.id = conversation_id and (c.student_id = auth.uid() or c.landlord_id = auth.uid())));

create policy blocks_own on cs_blocks for all using (blocker_id = auth.uid()) with check (blocker_id = auth.uid());

create policy reports_insert on cs_reports for insert with check (reporter_id = auth.uid() and cs_is_active_user());
create policy reports_own_read on cs_reports for select using (reporter_id = auth.uid() or cs_is_admin());

create policy notif_own_read on cs_notifications for select using (user_id = auth.uid());
create policy notif_own_update on cs_notifications for update using (user_id = auth.uid()) with check (user_id = auth.uid());

create policy vs_own_read on cs_verification_submissions for select using (user_id = auth.uid() or cs_is_admin());
create policy vs_insert on cs_verification_submissions for insert with check (user_id = auth.uid() and status = 'pending');

create policy audit_admin_read on cs_audit_events for select using (cs_is_admin());
-- No insert/update/delete policies on cs_audit_events: only security-definer functions write to it.

-- =========================== RPCs ===========================
create or replace function cs_start_enquiry(p_property_id uuid, p_body text) returns uuid
language plpgsql security definer set search_path = public as $$
declare v_owner uuid; v_conv uuid;
begin
  if auth.uid() is null then raise exception 'sign in required'; end if;
  if not cs_is_active_user() then raise exception 'account suspended'; end if;
  if char_length(trim(p_body)) not between 1 and 2000 then raise exception 'invalid message'; end if;
  select owner_id into v_owner from cs_properties
   where id = p_property_id and moderation_status = 'approved' and availability_status = 'available'
     and (expires_at is null or expires_at > now());
  if v_owner is null then raise exception 'listing not available'; end if;
  if v_owner = auth.uid() then raise exception 'cannot enquire on your own listing'; end if;
  if exists (select 1 from cs_blocks where (blocker_id = v_owner and blocked_id = auth.uid())
                                      or (blocker_id = auth.uid() and blocked_id = v_owner)) then
    raise exception 'unavailable';
  end if;
  if (select count(*) from cs_messages where sender_id = auth.uid() and created_at > now() - interval '1 hour') >= 20 then
    raise exception 'rate limit: too many cs_messages';
  end if;
  insert into cs_conversations (property_id, student_id, landlord_id)
  values (p_property_id, auth.uid(), v_owner)
  on conflict (property_id, student_id) do update set property_id = excluded.property_id
  returning id into v_conv;
  insert into cs_messages (conversation_id, sender_id, body) values (v_conv, auth.uid(), trim(p_body));
  insert into cs_notifications (user_id, kind, title, body)
  values (v_owner, 'enquiry', 'New enquiry', 'A student sent a message about your listing.');
  return v_conv;
end $$;

create or replace function cs_renew_listing(p_property_id uuid) returns void
language plpgsql security definer set search_path = public as $$
begin
  update cs_properties set expires_at = now() + interval '60 days'
   where id = p_property_id and owner_id = auth.uid() and moderation_status = 'approved';
  if not found then raise exception 'not allowed'; end if;
end $$;

create or replace function cs_record_view(p_property_id uuid) returns void
language sql security definer set search_path = public as $$
  update cs_properties set views_count = views_count + 1
   where id = p_property_id and moderation_status = 'approved' and owner_id <> coalesce(auth.uid(), '00000000-0000-0000-0000-000000000000');
$$;

create or replace function cs_admin_moderate_listing(p_property_id uuid, p_decision text, p_note text) returns void
language plpgsql security definer set search_path = public as $$
begin
  if not cs_is_admin() then raise exception 'forbidden'; end if;
  if p_decision not in ('approved','rejected','needs_changes') then raise exception 'bad decision'; end if;
  update cs_properties set moderation_status = p_decision::cs_moderation_status,
         expires_at = case when p_decision = 'approved' then now() + interval '60 days' else expires_at end
   where id = p_property_id;
  insert into cs_audit_events (actor_id, action, target_type, target_id, details)
  values (auth.uid(), 'moderate_listing', 'property', p_property_id, jsonb_build_object('decision', p_decision, 'note', p_note));
end $$;

create or replace function cs_admin_review_verification(p_submission_id uuid, p_approved boolean, p_note text) returns void
language plpgsql security definer set search_path = public as $$
declare v_prop uuid;
begin
  if not cs_is_admin() then raise exception 'forbidden'; end if;
  update cs_verification_submissions set status = case when p_approved then 'approved' else 'rejected' end,
         reviewed_by = auth.uid(), review_note = p_note
   where id = p_submission_id returning property_id into v_prop;
  if p_approved and v_prop is not null then
    update cs_properties set verification_level = 'verified' where id = v_prop;
  end if;
  insert into cs_audit_events (actor_id, action, target_type, target_id, details)
  values (auth.uid(), 'review_verification', 'verification', p_submission_id, jsonb_build_object('approved', p_approved, 'note', p_note));
end $$;

create or replace function cs_admin_set_suspension(p_user_id uuid, p_suspended boolean, p_reason text) returns void
language plpgsql security definer set search_path = public as $$
begin
  if not cs_is_admin() then raise exception 'forbidden'; end if;
  update cs_profiles set is_suspended = p_suspended where id = p_user_id and role <> 'admin';
  insert into cs_audit_events (actor_id, action, target_type, target_id, details)
  values (auth.uid(), 'set_suspension', 'user', p_user_id, jsonb_build_object('suspended', p_suspended, 'reason', p_reason));
end $$;

revoke all on function cs_admin_moderate_listing, cs_admin_review_verification, cs_admin_set_suspension from public, anon;
grant execute on function cs_admin_moderate_listing, cs_admin_review_verification, cs_admin_set_suspension, cs_start_enquiry, cs_renew_listing, cs_record_view to authenticated;

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

-- Stage 2: landlord support + fixes to Stage 1 guards.

alter table cs_properties add column if not exists moderation_note text check (char_length(moderation_note) <= 1000);

-- FIX: security-definer functions (renew, cs_record_view, verification trigger) must be able to
-- change guarded columns. They set a transaction-local flag; clients cannot set it
-- because the guard only trusts it inside the same transaction as those functions.
create or replace function cs_guard_property() returns trigger
language plpgsql security definer set search_path = public as $$
declare bypass boolean := coalesce(current_setting('campusstay.bypass', true), '') = '1';
begin
  if tg_op = 'INSERT' then
    if not cs_is_admin() then
      new.moderation_status := 'draft';
      new.verification_level := 'unverified';
      new.expires_at := null;
      new.views_count := 0;
      new.moderation_note := null;
    end if;
    return new;
  end if;

  new.owner_id := old.owner_id;
  new.updated_at := now();
  if bypass or cs_is_admin() then
    return new;
  end if;

  new.verification_level := old.verification_level;
  new.expires_at := old.expires_at;
  new.views_count := old.views_count;
  new.moderation_note := old.moderation_note;

  if new.moderation_status is distinct from old.moderation_status then
    if not (new.moderation_status = 'pending' and old.moderation_status in ('draft','needs_changes','rejected')) then
      new.moderation_status := old.moderation_status;
    end if;
  end if;

  -- Editing the substance of an approved listing sends it back for review.
  if old.moderation_status = 'approved' and new.moderation_status = 'approved' and
     row(new.title, new.description, new.area, new.rent_ngn, new.rent_period, new.room_type,
         new.university_id, new.extra_fees_note, new.distance_km)
     is distinct from
     row(old.title, old.description, old.area, old.rent_ngn, old.rent_period, old.room_type,
         old.university_id, old.extra_fees_note, old.distance_km) then
    new.moderation_status := 'pending';
  end if;
  return new;
end $$;

create or replace function cs_renew_listing(p_property_id uuid) returns void
language plpgsql security definer set search_path = public as $$
begin
  perform set_config('campusstay.bypass', '1', true);
  update cs_properties set expires_at = now() + interval '60 days'
   where id = p_property_id and owner_id = auth.uid() and moderation_status = 'approved';
  if not found then raise exception 'not allowed'; end if;
end $$;

create or replace function cs_record_view(p_property_id uuid) returns void
language plpgsql security definer set search_path = public as $$
begin
  perform set_config('campusstay.bypass', '1', true);
  update cs_properties set views_count = views_count + 1
   where id = p_property_id and moderation_status = 'approved'
     and owner_id is distinct from auth.uid();
end $$;

create or replace function cs_admin_moderate_listing(p_property_id uuid, p_decision text, p_note text) returns void
language plpgsql security definer set search_path = public as $$
begin
  if not cs_is_admin() then raise exception 'forbidden'; end if;
  if p_decision not in ('approved','rejected','needs_changes') then raise exception 'bad decision'; end if;
  update cs_properties set moderation_status = p_decision::cs_moderation_status,
         moderation_note = left(p_note, 1000),
         expires_at = case when p_decision = 'approved' then now() + interval '60 days' else expires_at end
   where id = p_property_id;
  insert into cs_audit_events (actor_id, action, target_type, target_id, details)
  values (auth.uid(), 'moderate_listing', 'property', p_property_id, jsonb_build_object('decision', p_decision, 'note', p_note));
end $$;

-- Uploading evidence marks the listing "pending review" (never "verified").
create or replace function cs_on_verification_submitted() returns trigger
language plpgsql security definer set search_path = public as $$
begin
  if new.property_id is not null then
    perform set_config('campusstay.bypass', '1', true);
    update cs_properties set verification_level = 'pending'
     where id = new.property_id and owner_id = new.user_id and verification_level = 'unverified';
  end if;
  return new;
end $$;
drop trigger if exists trg_verification_submitted on cs_verification_submissions;
create trigger trg_verification_submitted after insert on cs_verification_submissions
  for each row execute function cs_on_verification_submitted();

-- Evidence may only be attached to the submitter's own property.
drop policy if exists vs_insert on cs_verification_submissions;
create policy vs_insert on cs_verification_submissions for insert with check (
  user_id = auth.uid() and status = 'pending'
  and (property_id is null or exists (select 1 from cs_properties p where p.id = property_id and p.owner_id = auth.uid()))
);

create or replace function cs_landlord_stats() returns json
language sql stable security invoker set search_path = public as $$
  select json_build_object(
    'total', count(*),
    'active', count(*) filter (where moderation_status = 'approved' and availability_status = 'available'
                                 and (expires_at is null or expires_at > now())),
    'pending', count(*) filter (where moderation_status = 'pending'),
    'views', coalesce(sum(views_count), 0),
    'enquiries', (select count(*) from cs_conversations c where c.landlord_id = auth.uid())
  ) from cs_properties where owner_id = auth.uid();
$$;
grant execute on function cs_landlord_stats, cs_renew_listing, cs_record_view to authenticated;

-- Stage 3: admin tooling and the public landlord submission page.

alter table cs_reports add column if not exists resolution_note text check (char_length(resolution_note) <= 1000);
alter table cs_reports add column if not exists resolved_by uuid references cs_profiles(id);

-- Leads from the public web form. Never shown publicly. Written only by the
-- submit-listing edge function (service role); readable only by admins.
create table cs_landlord_submissions (
  id uuid primary key default gen_random_uuid(),
  name text not null check (char_length(name) between 2 and 100),
  phone text not null check (phone ~ '^\+?[0-9 ]{7,16}$'),
  school_or_area text not null check (char_length(school_or_area) between 2 and 150),
  room_type text not null check (room_type in ('single_room','shared_room','self_contain','apartment','hostel')),
  rent_ngn integer check (rent_ngn > 0 and rent_ngn < 100000000),
  description text check (char_length(description) <= 2000),
  consent boolean not null check (consent),
  ip_hash text,
  status text not null default 'new' check (status in ('new','contacted','converted','dismissed')),
  created_at timestamptz not null default now()
);
create index on cs_landlord_submissions (ip_hash, created_at);
create index on cs_landlord_submissions (status, created_at);
alter table cs_landlord_submissions enable row level security;
create policy leads_admin_read on cs_landlord_submissions for select using (cs_is_admin());
-- No insert/update/delete policies: clients cannot write to this table at all.

create or replace function cs_admin_stats() returns json
language plpgsql security definer set search_path = public as $$
begin
  if not cs_is_admin() then raise exception 'forbidden'; end if;
  return json_build_object(
    'pending_listings', (select count(*) from cs_properties where moderation_status = 'pending'),
    'live_listings', (select count(*) from cs_properties where moderation_status = 'approved' and availability_status = 'available' and (expires_at is null or expires_at > now())),
    'total_listings', (select count(*) from cs_properties),
    'open_reports', (select count(*) from cs_reports where status in ('open','reviewing')),
    'pending_verifications', (select count(*) from cs_verification_submissions where status = 'pending'),
    'new_leads', (select count(*) from cs_landlord_submissions where status = 'new'),
    'users', (select count(*) from cs_profiles));
end $$;

create or replace function cs_admin_resolve_report(p_report_id uuid, p_status text, p_note text) returns void
language plpgsql security definer set search_path = public as $$
begin
  if not cs_is_admin() then raise exception 'forbidden'; end if;
  if p_status not in ('reviewing','actioned','dismissed') then raise exception 'invalid status'; end if;
  update cs_reports set status = p_status::cs_report_status, resolution_note = left(p_note, 1000), resolved_by = auth.uid() where id = p_report_id;
  insert into cs_audit_events (actor_id, action, target_type, target_id, details)
  values (auth.uid(), 'resolve_report', 'report', p_report_id, jsonb_build_object('status', p_status, 'note', p_note));
end $$;

create or replace function cs_admin_set_lead_status(p_id uuid, p_status text) returns void
language plpgsql security definer set search_path = public as $$
begin
  if not cs_is_admin() then raise exception 'forbidden'; end if;
  if p_status not in ('contacted','converted','dismissed') then raise exception 'invalid status'; end if;
  update cs_landlord_submissions set status = p_status where id = p_id;
  insert into cs_audit_events (actor_id, action, target_type, target_id, details)
  values (auth.uid(), 'set_lead_status', 'submission', p_id, jsonb_build_object('status', p_status));
end $$;

revoke all on function cs_admin_stats, cs_admin_resolve_report, cs_admin_set_lead_status from public, anon;
grant execute on function cs_admin_stats, cs_admin_resolve_report, cs_admin_set_lead_status to authenticated;

-- Profile screen: phone number and a name length limit. Safe to run more than once.
alter table cs_profiles add column if not exists phone text;
alter table cs_profiles drop constraint if exists cs_profiles_phone_check;
alter table cs_profiles add constraint cs_profiles_phone_check
  check (phone is null or phone ~ '^\+?[0-9 ]{7,16}$');
alter table cs_profiles drop constraint if exists cs_profiles_name_len;
alter table cs_profiles add constraint cs_profiles_name_len
  check (full_name is null or char_length(full_name) <= 100);
-- Existing RLS already lets a person update only their own row, and the
-- cs_guard_profile_update trigger keeps role and suspension admin-only.

-- Richer property details, categorised facilities, school types, filterable facilities.
-- Safe to run more than once.

-- Schools -------------------------------------------------------------------
alter table cs_universities add column if not exists kind text not null default 'university';
alter table cs_universities drop constraint if exists cs_universities_kind_check;
alter table cs_universities add constraint cs_universities_kind_check
  check (kind in ('university','polytechnic','college_of_education','other'));
create index if not exists cs_universities_state_idx on cs_universities (state);

-- Property details ----------------------------------------------------------
alter table cs_properties
  add column if not exists school_other text,
  add column if not exists landmark text,
  add column if not exists bedrooms smallint not null default 1,
  add column if not exists bathrooms smallint not null default 1,
  add column if not exists bathroom_type text not null default 'private',
  add column if not exists kitchen_type text not null default 'shared',
  add column if not exists furnishing text not null default 'unfurnished',
  add column if not exists gender_preference text not null default 'any',
  add column if not exists max_occupants smallint not null default 1,
  add column if not exists available_from date,
  add column if not exists lease_months smallint,
  add column if not exists allows_instalments boolean not null default false,
  add column if not exists caution_fee_ngn integer,
  add column if not exists service_charge_ngn integer,
  add column if not exists landlord_lives_on_site boolean not null default false,
  add column if not exists visitors_allowed boolean not null default true,
  add column if not exists pets_allowed boolean not null default false,
  add column if not exists house_rules text,
  add column if not exists amenity_codes text[] not null default '{}';

alter table cs_properties drop constraint if exists cs_properties_details_check;
alter table cs_properties add constraint cs_properties_details_check check (
  (school_other is null or char_length(school_other) <= 150)
  and (landmark is null or char_length(landmark) <= 200)
  and bedrooms between 0 and 20 and bathrooms between 0 and 20
  and bathroom_type in ('private','shared')
  and kitchen_type in ('private','shared','none')
  and furnishing in ('unfurnished','semi_furnished','furnished')
  and gender_preference in ('any','male_only','female_only')
  and max_occupants between 1 and 30
  and (lease_months is null or lease_months between 1 and 60)
  and (caution_fee_ngn is null or (caution_fee_ngn >= 0 and caution_fee_ngn < 100000000))
  and (service_charge_ngn is null or (service_charge_ngn >= 0 and service_charge_ngn < 100000000))
  and (house_rules is null or char_length(house_rules) <= 1000)
);
create index if not exists cs_properties_amenity_codes_idx on cs_properties using gin (amenity_codes);
create index if not exists cs_properties_filters_idx on cs_properties (furnishing, gender_preference, bedrooms);

-- Facilities ----------------------------------------------------------------
alter table cs_amenities add column if not exists category text not null default 'comfort';
update cs_amenities set category = 'utilities' where code in ('water','electricity');
update cs_amenities set category = 'security' where code in ('cctv');
update cs_amenities set category = 'convenience' where code in ('parking','kitchen','laundry');
update cs_amenities set category = 'comfort' where code in ('wifi','ac');
insert into cs_amenities (id, code, label, category) values
 (9,'borehole','Borehole water','utilities'),
 (10,'prepaid_meter','Prepaid meter','utilities'),
 (11,'generator','Generator or inverter','utilities'),
 (12,'solar','Solar power','utilities'),
 (13,'fan','Ceiling fan','comfort'),
 (14,'wardrobe','Wardrobe','comfort'),
 (15,'bed','Bed and mattress','comfort'),
 (16,'fridge','Fridge','comfort'),
 (17,'tv','TV or DStv','comfort'),
 (18,'gas_cooker','Gas cooker','comfort'),
 (19,'tiled','Tiled floors','comfort'),
 (20,'pop_ceiling','POP ceiling','comfort'),
 (28,'water_heater','Water heater','comfort'),
 (21,'security_guard','Security guard','security'),
 (22,'gated','Gated compound','security'),
 (23,'fenced','Fenced','security'),
 (24,'burglar_proof','Burglar-proof doors and windows','security'),
 (25,'study_area','Study area','convenience'),
 (26,'balcony','Balcony','convenience'),
 (27,'cleaning','Cleaning service','convenience'),
 (29,'tarred_road','Tarred road access','convenience'),
 (30,'near_transport','Close to transport','convenience'),
 (31,'near_shops','Close to shops','convenience')
on conflict (id) do update set code = excluded.code, label = excluded.label, category = excluded.category;

-- Keep cs_properties.amenity_codes in step with cs_property_amenities (for fast filtering).
create or replace function cs_sync_amenity_codes() returns trigger
language plpgsql security definer set search_path = public as $$
declare pid uuid := coalesce(new.property_id, old.property_id);
begin
  perform set_config('campusstay.bypass', '1', true);
  update cs_properties set amenity_codes = coalesce((
    select array_agg(a.code order by a.code)
      from cs_property_amenities pa join cs_amenities a on a.id = pa.amenity_id
     where pa.property_id = pid), '{}')
   where id = pid;
  return null;
end $$;
drop trigger if exists cs_trg_sync_amenities on cs_property_amenities;
create trigger cs_trg_sync_amenities after insert or delete on cs_property_amenities
  for each row execute function cs_sync_amenity_codes();

-- Backfill for listings created before this migration.
select set_config('campusstay.bypass', '1', false);
update cs_properties p set amenity_codes = coalesce((
  select array_agg(a.code order by a.code)
    from cs_property_amenities pa join cs_amenities a on a.id = pa.amenity_id
   where pa.property_id = p.id), '{}');
select set_config('campusstay.bypass', '', false);

-- Guard: any change to listing substance sends an approved listing back to review.
create or replace function cs_guard_property() returns trigger
language plpgsql security definer set search_path = public as $$
declare
  bypass boolean := coalesce(current_setting('campusstay.bypass', true), '') = '1';
  ignore_cols text[] := array['moderation_status','availability_status','verification_level','expires_at',
    'views_count','moderation_note','updated_at','created_at','amenity_codes','owner_id'];
begin
  if tg_op = 'INSERT' then
    if not cs_is_admin() then
      new.moderation_status := 'draft';
      new.verification_level := 'unverified';
      new.expires_at := null;
      new.views_count := 0;
      new.moderation_note := null;
      new.amenity_codes := '{}';
    end if;
    return new;
  end if;

  new.owner_id := old.owner_id;
  new.updated_at := now();
  if bypass or cs_is_admin() then
    return new;
  end if;

  new.verification_level := old.verification_level;
  new.expires_at := old.expires_at;
  new.views_count := old.views_count;
  new.moderation_note := old.moderation_note;
  new.amenity_codes := old.amenity_codes;

  if new.moderation_status is distinct from old.moderation_status then
    if not (new.moderation_status = 'pending' and old.moderation_status in ('draft','needs_changes','rejected')) then
      new.moderation_status := old.moderation_status;
    end if;
  end if;

  if old.moderation_status = 'approved' and new.moderation_status = 'approved'
     and (to_jsonb(new) - ignore_cols) is distinct from (to_jsonb(old) - ignore_cols) then
    new.moderation_status := 'pending';
  end if;
  return new;
end $$;

-- Nigerian higher institutions (universities, polytechnics, colleges of education).
-- Built from general knowledge: spot-check it, and add or correct schools with SQL as needed.
-- Safe to run more than once.
insert into cs_universities (name, short_name, city, state, kind) values
  ('University of Ibadan','UI','Ibadan','Oyo','university'),
  ('University of Lagos','UNILAG','Lagos','Lagos','university'),
  ('University of Nigeria, Nsukka','UNN','Nsukka','Enugu','university'),
  ('Obafemi Awolowo University','OAU','Ile-Ife','Osun','university'),
  ('Ahmadu Bello University','ABU','Zaria','Kaduna','university'),
  ('University of Benin','UNIBEN','Benin City','Edo','university'),
  ('University of Ilorin','UNILORIN','Ilorin','Kwara','university'),
  ('University of Jos','UNIJOS','Jos','Plateau','university'),
  ('University of Calabar','UNICAL','Calabar','Cross River','university'),
  ('University of Port Harcourt','UNIPORT','Port Harcourt','Rivers','university'),
  ('University of Maiduguri','UNIMAID','Maiduguri','Borno','university'),
  ('Bayero University Kano','BUK','Kano','Kano','university'),
  ('Usmanu Danfodiyo University','UDUS','Sokoto','Sokoto','university'),
  ('University of Uyo','UNIUYO','Uyo','Akwa Ibom','university'),
  ('University of Abuja','UNIABUJA','Gwagwalada','FCT','university'),
  ('Federal University of Technology, Akure','FUTA','Akure','Ondo','university'),
  ('Federal University of Technology, Minna','FUTMINNA','Minna','Niger','university'),
  ('Federal University of Technology, Owerri','FUTO','Owerri','Imo','university'),
  ('Federal University of Agriculture, Abeokuta','FUNAAB','Abeokuta','Ogun','university'),
  ('Michael Okpara University of Agriculture, Umudike','MOUAU','Umudike','Abia','university'),
  ('Modibbo Adama University','MAU','Yola','Adamawa','university'),
  ('Abubakar Tafawa Balewa University','ATBU','Bauchi','Bauchi','university'),
  ('Nnamdi Azikiwe University','UNIZIK','Awka','Anambra','university'),
  ('Federal University Oye-Ekiti','FUOYE','Oye-Ekiti','Ekiti','university'),
  ('Federal University Lafia','FULAFIA','Lafia','Nasarawa','university'),
  ('Federal University Lokoja','FULOKOJA','Lokoja','Kogi','university'),
  ('Federal University Wukari','FUWUKARI','Wukari','Taraba','university'),
  ('Federal University Dutse','FUD','Dutse','Jigawa','university'),
  ('Federal University Dutsin-Ma','FUDMA','Dutsin-Ma','Katsina','university'),
  ('Federal University Gusau','FUGUS','Gusau','Zamfara','university'),
  ('Federal University Kashere','FUKASHERE','Kashere','Gombe','university'),
  ('Federal University Birnin Kebbi','FUBK','Birnin Kebbi','Kebbi','university'),
  ('Federal University Gashua','FUGASHUA','Gashua','Yobe','university'),
  ('Federal University Otuoke','FUOTUOKE','Otuoke','Bayelsa','university'),
  ('Alex Ekwueme Federal University, Ndufu-Alike','AE-FUNAI','Ikwo','Ebonyi','university'),
  ('Federal University of Petroleum Resources','FUPRE','Effurun','Delta','university'),
  ('Federal University of Agriculture, Makurdi','FUAM','Makurdi','Benue','university'),
  ('Federal University of Health Sciences, Otukpo','FUHSO','Otukpo','Benue','university'),
  ('Federal University of Health Sciences, Ila-Orangun','FUHSI','Ila-Orangun','Osun','university'),
  ('Federal University of Technology, Ikot Abasi','FUTIA','Ikot Abasi','Akwa Ibom','university'),
  ('Federal University of Agriculture and Development Studies, Iragbiji','FUADSI','Iragbiji','Osun','university'),
  ('Federal University of Environment and Technology, Ogoni','FUETO','Ogoni','Rivers','university'),
  ('Federal University of Applied Sciences, Kachia','FUASK','Kachia','Kaduna','university'),
  ('Federal University of Technology, Babura','FUTB','Babura','Jigawa','university'),
  ('Federal University of Transportation, Daura','FUTD','Daura','Katsina','university'),
  ('Nigerian Defence Academy','NDA','Kaduna','Kaduna','university'),
  ('Nigerian Army University, Biu','NAUB','Biu','Borno','university'),
  ('National Open University of Nigeria','NOUN','Abuja','FCT','university'),
  ('Nigerian Police Academy','POLAC','Wudil','Kano','university'),
  ('Adeyemi Federal University of Education','AFUED','Ondo','Ondo','university'),
  ('Alvan Ikoku University of Education','AIUE','Owerri','Imo','university'),
  ('Lagos State University','LASU','Ojo','Lagos','university'),
  ('Lagos State University of Science and Technology','LASUSTECH','Ikorodu','Lagos','university'),
  ('Lagos State University of Education','LASUED','Ijanikin','Lagos','university'),
  ('Ekiti State University','EKSU','Ado-Ekiti','Ekiti','university'),
  ('Bamidele Olumilua University of Education, Science and Technology','BOUESTI','Ikere-Ekiti','Ekiti','university'),
  ('Ambrose Alli University','AAU','Ekpoma','Edo','university'),
  ('Edo State University','EDOUNI','Uzairue','Edo','university'),
  ('Rivers State University','RSU','Port Harcourt','Rivers','university'),
  ('Ignatius Ajuru University of Education','IAUE','Port Harcourt','Rivers','university'),
  ('Delta State University','DELSU','Abraka','Delta','university'),
  ('Delta State University of Science and Technology','DSUST','Ozoro','Delta','university'),
  ('University of Delta','UNIDEL','Agbor','Delta','university'),
  ('Imo State University','IMSU','Owerri','Imo','university'),
  ('Enugu State University of Science and Technology','ESUT','Enugu','Enugu','university'),
  ('Abia State University','ABSU','Uturu','Abia','university'),
  ('Ebonyi State University','EBSU','Abakaliki','Ebonyi','university'),
  ('Chukwuemeka Odumegwu Ojukwu University','COOU','Uli','Anambra','university'),
  ('Olabisi Onabanjo University','OOU','Ago-Iwoye','Ogun','university'),
  ('Moshood Abiola University of Science and Technology','MAUSTECH','Abeokuta','Ogun','university'),
  ('Tai Solarin University of Education','TASUED','Ijagun','Ogun','university'),
  ('Adekunle Ajasin University','AAUA','Akungba-Akoko','Ondo','university'),
  ('Olusegun Agagu University of Science and Technology','OAUSTECH','Okitipupa','Ondo','university'),
  ('University of Medical Sciences','UNIMED','Ondo','Ondo','university'),
  ('Osun State University','UNIOSUN','Osogbo','Osun','university'),
  ('Ladoke Akintola University of Technology','LAUTECH','Ogbomoso','Oyo','university'),
  ('Emmanuel Alayande University of Education','EAUED','Oyo','Oyo','university'),
  ('Technical University, Ibadan','TECHIBA','Ibadan','Oyo','university'),
  ('Niger Delta University','NDU','Yenagoa','Bayelsa','university'),
  ('University of Africa, Toru-Orua','UAT','Toru-Orua','Bayelsa','university'),
  ('Akwa Ibom State University','AKSU','Ikot Akpaden','Akwa Ibom','university'),
  ('Cross River University of Technology','CRUTECH','Calabar','Cross River','university'),
  ('Benue State University','BSU','Makurdi','Benue','university'),
  ('Plateau State University','PLASU','Bokkos','Plateau','university'),
  ('Prince Abubakar Audu University','PAAU','Anyigba','Kogi','university'),
  ('Kwara State University','KWASU','Malete','Kwara','university'),
  ('Ahman Pategi University','APU','Patigi','Kwara','university'),
  ('Kaduna State University','KASU','Kaduna','Kaduna','university'),
  ('Kano University of Science and Technology','KUST','Wudil','Kano','university'),
  ('Yusuf Maitama Sule University','YUMSUK','Kano','Kano','university'),
  ('Sokoto State University','SSU','Sokoto','Sokoto','university'),
  ('Gombe State University','GSU','Gombe','Gombe','university'),
  ('Taraba State University','TSU','Jalingo','Taraba','university'),
  ('Adamawa State University','ADSU','Mubi','Adamawa','university'),
  ('Bauchi State University','BASUG','Gadau','Bauchi','university'),
  ('Borno State University','BOSU','Maiduguri','Borno','university'),
  ('Yobe State University','YSU','Damaturu','Yobe','university'),
  ('Sule Lamido University','SLU','Kafin Hausa','Jigawa','university'),
  ('Umaru Musa Yar''adua University','UMYU','Katsina','Katsina','university'),
  ('Kebbi State University of Science and Technology','KSUSTA','Aliero','Kebbi','university'),
  ('Nasarawa State University','NSUK','Keffi','Nasarawa','university'),
  ('Ibrahim Badamasi Babangida University','IBBU','Lapai','Niger','university'),
  ('Covenant University','CU','Ota','Ogun','university'),
  ('Babcock University','BU','Ilishan-Remo','Ogun','university'),
  ('Afe Babalola University','ABUAD','Ado-Ekiti','Ekiti','university'),
  ('Landmark University','LMU','Omu-Aran','Kwara','university'),
  ('Bowen University','BOWEN','Iwo','Osun','university'),
  ('Redeemer''s University','RUN','Ede','Osun','university'),
  ('Pan-Atlantic University','PAU','Lagos','Lagos','university'),
  ('American University of Nigeria','AUN','Yola','Adamawa','university'),
  ('Bells University of Technology','BELLSTECH','Ota','Ogun','university'),
  ('Crawford University','CRAWFORD','Igbesa','Ogun','university'),
  ('Crescent University','CRESCENT','Abeokuta','Ogun','university'),
  ('Caleb University','CALEB','Imota','Lagos','university'),
  ('Lead City University','LCU','Ibadan','Oyo','university'),
  ('Ajayi Crowther University','ACU','Oyo','Oyo','university'),
  ('Adeleke University','ADELEKE','Ede','Osun','university'),
  ('Achievers University','ACHIEVERS','Owo','Ondo','university'),
  ('Elizade University','ELIZADE','Ilara-Mokin','Ondo','university'),
  ('Joseph Ayo Babalola University','JABU','Ikeji-Arakeji','Osun','university'),
  ('Oduduwa University','ODU','Ipetumodu','Osun','university'),
  ('Fountain University','FUO','Osogbo','Osun','university'),
  ('Kola Daisi University','KDU','Ibadan','Oyo','university'),
  ('Mountain Top University','MTU','Prayer City','Ogun','university'),
  ('McPherson University','MCU','Ajebo','Ogun','university'),
  ('Chrisland University','CHRISLAND','Abeokuta','Ogun','university'),
  ('Hallmark University','HALLMARK','Ijebu-Itele','Ogun','university'),
  ('Christopher University','CHRISTOPHER','Mowe','Ogun','university'),
  ('Wesley University','WESLEY','Ondo','Ondo','university'),
  ('Southwestern University, Nigeria','SWU','Okun-Owa','Ogun','university'),
  ('Anchor University','AUL','Ayobo','Lagos','university'),
  ('Augustine University','AUI','Ilara-Epe','Lagos','university'),
  ('Trinity University','TRINITY','Yaba','Lagos','university'),
  ('Eko University of Medicine and Health Sciences','EKOUNIMED','Ijanikin','Lagos','university'),
  ('Atiba University','ATIBA','Oyo','Oyo','university'),
  ('Dominion University','DOMINION','Ibadan','Oyo','university'),
  ('Dominican University Ibadan','DUI','Ibadan','Oyo','university'),
  ('Precious Cornerstone University','PCU','Ibadan','Oyo','university'),
  ('Thomas Adewumi University','TAU','Oko','Kwara','university'),
  ('Al-Hikmah University','AHU','Ilorin','Kwara','university'),
  ('Summit University','SUMMIT','Offa','Kwara','university'),
  ('Ojaja University','OJAJA','Ilorin','Kwara','university'),
  ('Kings University','KINGS','Odeomu','Osun','university'),
  ('Westland University','WESTLAND','Iwo','Osun','university'),
  ('Venite University','VENITE','Iloro-Ekiti','Ekiti','university'),
  ('Nile University of Nigeria','NILE','Abuja','FCT','university'),
  ('Baze University','BAZE','Abuja','FCT','university'),
  ('Veritas University','VERITAS','Abuja','FCT','university'),
  ('Cosmopolitan University','COSMOPOLITAN','Abuja','FCT','university'),
  ('African University of Science and Technology','AUST','Abuja','FCT','university'),
  ('Philomath University','PHILOMATH','Kuje','FCT','university'),
  ('Bingham University','BINGHAM','Karu','Nasarawa','university'),
  ('Madonna University','MADONNA','Okija','Anambra','university'),
  ('Godfrey Okoye University','GOU','Enugu','Enugu','university'),
  ('Paul University','PAULUNI','Awka','Anambra','university'),
  ('Tansian University','TANSIAN','Umunya','Anambra','university'),
  ('Igbinedion University','IUO','Okada','Edo','university'),
  ('Benson Idahosa University','BIU','Benin City','Edo','university'),
  ('Wellspring University','WELLSPRING','Benin City','Edo','university'),
  ('Samuel Adegboyega University','SAU','Ogwa','Edo','university'),
  ('Mudiame University','MUDIAME','Irrua','Edo','university'),
  ('Western Delta University','WDU','Oghara','Delta','university'),
  ('Novena University','NOVENA','Ogume','Delta','university'),
  ('Southern Delta University','SDU','Ozoro','Delta','university'),
  ('Edwin Clark University','ECU','Kiagbodo','Delta','university'),
  ('Margaret Lawrence University','MLU','Umunya','Delta','university'),
  ('Admiralty University of Nigeria','ADUN','Ibusa','Delta','university'),
  ('Obong University','OBONG','Obong Ntak','Akwa Ibom','university'),
  ('Topfaith University','TOPFAITH','Mkpatak','Akwa Ibom','university'),
  ('Ritman University','RITMAN','Ikot Ekpene','Akwa Ibom','university'),
  ('Arthur Jarvis University','AJU','Akpabuyo','Cross River','university'),
  ('Clifford University','CLIFFORD','Owerrinta','Abia','university'),
  ('Rhema University','RHEMA','Aba','Abia','university'),
  ('Gregory University','GREGORY','Uturu','Abia','university'),
  ('Spiritan University','SPIRITAN','Nneochi','Abia','university'),
  ('Lux Mundi University','LUXMUNDI','Umuahia','Abia','university'),
  ('Evangel University','EVANGEL','Akaeze','Ebonyi','university'),
  ('Hezekiah University','HEZEKIAH','Umudi','Imo','university'),
  ('Eastern Palm University','EPU','Ogboko','Imo','university'),
  ('Coal City University','CCU','Enugu','Enugu','university'),
  ('Caritas University','CARITAS','Amorji-Nike','Enugu','university'),
  ('Renaissance University','RENAISSANCE','Ugbawka','Enugu','university'),
  ('Skyline University Nigeria','SKYLINE','Kano','Kano','university'),
  ('Maryam Abacha American University of Nigeria','MAAUN','Kano','Kano','university'),
  ('Khadija University','KHADIJA','Majia','Kano','university'),
  ('Greenfield University','GREENFIELD','Kasarami','Kaduna','university'),
  ('Karl-Kumm University','KARLKUMM','Vom','Plateau','university'),
  ('Pamo University of Medical Sciences','PUMS','Port Harcourt','Rivers','university'),
  ('Yaba College of Technology','YABATECH','Yaba','Lagos','polytechnic'),
  ('Lagos State Polytechnic','LASPOTECH','Ikorodu','Lagos','polytechnic'),
  ('Lagos City Polytechnic','LCP','Ikeja','Lagos','polytechnic'),
  ('Federal Polytechnic Ado-Ekiti','FEDPOLYADO','Ado-Ekiti','Ekiti','polytechnic'),
  ('Federal Polytechnic Ilaro','FEDPOLYILARO','Ilaro','Ogun','polytechnic'),
  ('Federal Polytechnic Ede','FEDPOLYEDE','Ede','Osun','polytechnic'),
  ('Federal Polytechnic Ayede','FPA','Ayede','Oyo','polytechnic'),
  ('Federal Polytechnic Ile-Oluji','FEPOLILE','Ile-Oluji','Ondo','polytechnic'),
  ('Federal Polytechnic Offa','OFFAPOLY','Offa','Kwara','polytechnic'),
  ('Federal Polytechnic Idah','FPI','Idah','Kogi','polytechnic'),
  ('Federal Polytechnic Bida','FEDPOLYBIDA','Bida','Niger','polytechnic'),
  ('Federal Polytechnic Nekede','FEDPONEK','Owerri','Imo','polytechnic'),
  ('Federal Polytechnic Oko','FEDPOLYOKO','Oko','Anambra','polytechnic'),
  ('Federal Polytechnic Ngodo-Isuochi','FPNI','Ngodo-Isuochi','Abia','polytechnic'),
  ('Akanu Ibiam Federal Polytechnic','AIFPU','Unwana','Ebonyi','polytechnic'),
  ('Federal Polytechnic Auchi','AUCHIPOLY','Auchi','Edo','polytechnic'),
  ('Federal Polytechnic Orogun','FEDPOLYOROGUN','Orogun','Delta','polytechnic'),
  ('Federal Polytechnic Ekowe','FPE','Ekowe','Bayelsa','polytechnic'),
  ('Federal Polytechnic Ukana','FPU','Ukana','Akwa Ibom','polytechnic'),
  ('Federal Polytechnic Ugep','FEDPOLYUGEP','Ugep','Cross River','polytechnic'),
  ('Federal Polytechnic Wannune','FPW','Wannune','Benue','polytechnic'),
  ('Federal Polytechnic Nasarawa','FEDPONAS','Nasarawa','Nasarawa','polytechnic'),
  ('Federal Polytechnic Nyak Shendam','FPNS','Shendam','Plateau','polytechnic'),
  ('Kaduna Polytechnic','KADPOLY','Kaduna','Kaduna','polytechnic'),
  ('Nuhu Bamalli Polytechnic','NUBAPOLY','Zaria','Kaduna','polytechnic'),
  ('Federal Polytechnic Bauchi','FEDPOLYBAUCHI','Bauchi','Bauchi','polytechnic'),
  ('Federal Polytechnic Damaturu','FEDPOLYDAM','Damaturu','Yobe','polytechnic'),
  ('Federal Polytechnic Mubi','FEDPOLYMUBI','Mubi','Adamawa','polytechnic'),
  ('Federal Polytechnic Bali','FPB','Bali','Taraba','polytechnic'),
  ('Federal Polytechnic Kaltungo','FEDPOLYKALTUNGO','Kaltungo','Gombe','polytechnic'),
  ('Federal Polytechnic Monguno','FPM','Monguno','Borno','polytechnic'),
  ('Federal Polytechnic Daura','FPD','Daura','Katsina','polytechnic'),
  ('Federal Polytechnic Kaura Namoda','FEDPOLYNAM','Kaura Namoda','Zamfara','polytechnic'),
  ('Hussaini Adamu Federal Polytechnic','HAFEDPOLY','Kazaure','Jigawa','polytechnic'),
  ('Waziri Umaru Federal Polytechnic','WUFPBK','Birnin Kebbi','Kebbi','polytechnic'),
  ('The Polytechnic, Ibadan','IBADANPOLY','Ibadan','Oyo','polytechnic'),
  ('Ibarapa Polytechnic','IBARAPOLY','Eruwa','Oyo','polytechnic'),
  ('Moshood Abiola Polytechnic','MAPOLY','Abeokuta','Ogun','polytechnic'),
  ('Abraham Adesanya Polytechnic','AAPOLY','Ijebu-Igbo','Ogun','polytechnic'),
  ('Gateway Polytechnic','GATEWAYPOLY','Saapade','Ogun','polytechnic'),
  ('Osun State Polytechnic','OSPOLY','Iree','Osun','polytechnic'),
  ('The Polytechnic, Ile-Ife','POLYIFE','Ile-Ife','Osun','polytechnic'),
  ('Rufus Giwa Polytechnic','RUGIPO','Owo','Ondo','polytechnic'),
  ('Kwara State Polytechnic','KWARAPOLY','Ilorin','Kwara','polytechnic'),
  ('Kogi State Polytechnic','KOGIPOLY','Lokoja','Kogi','polytechnic'),
  ('Niger State Polytechnic','NIGERPOLY','Zungeru','Niger','polytechnic'),
  ('Plateau State Polytechnic','PLAPOLY','Barkin Ladi','Plateau','polytechnic'),
  ('Kano State Polytechnic','KANOPOLY','Kano','Kano','polytechnic'),
  ('Delta State Polytechnic, Ozoro','DSPZ','Ozoro','Delta','polytechnic'),
  ('Delta State Polytechnic, Ogwashi-Uku','DELTAPOLY','Ogwashi-Uku','Delta','polytechnic'),
  ('Akwa Ibom State Polytechnic','AKSPOLY','Ikot Osurua','Akwa Ibom','polytechnic'),
  ('Kenule Beeson Saro-Wiwa Polytechnic','KENPOLY','Bori','Rivers','polytechnic'),
  ('Institute of Management and Technology','IMT','Enugu','Enugu','polytechnic'),
  ('Abia State Polytechnic','ABIAPOLY','Aba','Abia','polytechnic'),
  ('Imo State Polytechnic','IMOPOLY','Umuagwo','Imo','polytechnic'),
  ('Anambra State Polytechnic','ANAMPOLY','Mgbakwu','Anambra','polytechnic'),
  ('Benue State Polytechnic','BENPOLY','Ugbokolo','Benue','polytechnic'),
  ('Abubakar Tatari Ali Polytechnic','ATAP','Bauchi','Bauchi','polytechnic'),
  ('Adamawa State Polytechnic','ADAMAWAPOLY','Yola','Adamawa','polytechnic'),
  ('Gombe State Polytechnic','GOMBEPOLY','Bajoga','Gombe','polytechnic'),
  ('Mai Idris Alooma Polytechnic','MIAPOLY','Geidam','Yobe','polytechnic'),
  ('Ramat Polytechnic','RAMATPOLY','Maiduguri','Borno','polytechnic'),
  ('Hassan Usman Katsina Polytechnic','HUKPOLY','Katsina','Katsina','polytechnic'),
  ('Umaru Ali Shinkafi Polytechnic','UASPOLY','Sokoto','Sokoto','polytechnic'),
  ('Abdu Gusau Polytechnic','AGPOLY','Talata Mafara','Zamfara','polytechnic'),
  ('Taraba State Polytechnic','TARABAPOLY','Suntai','Taraba','polytechnic'),
  ('Federal College of Education (Technical), Akoka','FCETAKOKA','Akoka','Lagos','college_of_education'),
  ('Adeniran Ogunsanya College of Education','AOCOED','Ijanikin','Lagos','college_of_education'),
  ('Michael Otedola College of Primary Education','MOCPED','Noforija','Lagos','college_of_education'),
  ('Federal College of Education, Abeokuta','FCEABEOKUTA','Abeokuta','Ogun','college_of_education'),
  ('Federal College of Education, Iwo','FCEIWO','Iwo','Osun','college_of_education'),
  ('Federal College of Education (Special), Oyo','FCEOYO','Oyo','Oyo','college_of_education'),
  ('Federal College of Education, Zaria','FCEZARIA','Zaria','Kaduna','college_of_education'),
  ('Federal College of Education, Kano','FCEKANO','Kano','Kano','college_of_education'),
  ('Federal College of Education, Katsina','FCEKATSINA','Katsina','Katsina','college_of_education'),
  ('Federal College of Education, Kontagora','FCEKONTAGORA','Kontagora','Niger','college_of_education'),
  ('Federal College of Education, Okene','FCEOKENE','Okene','Kogi','college_of_education'),
  ('Federal College of Education, Pankshin','FCEPANKSHIN','Pankshin','Plateau','college_of_education'),
  ('Federal College of Education (Technical), Gombe','FCETGOMBE','Gombe','Gombe','college_of_education'),
  ('Federal College of Education, Yola','FCEYOLA','Yola','Adamawa','college_of_education'),
  ('Federal College of Education, Obudu','FCEOBUDU','Obudu','Cross River','college_of_education'),
  ('Federal College of Education, Eha-Amufu','FCEEHA','Eha-Amufu','Enugu','college_of_education'),
  ('Kwara State College of Education, Oro','KWARACOEORO','Oro','Kwara','college_of_education'),
  ('Kwara State College of Education, Ilorin','KWARACOE','Ilorin','Kwara','college_of_education')
on conflict (name) do update set short_name = excluded.short_name, city = excluded.city, state = excluded.state, kind = excluded.kind;

-- Map pins with private exact location, and landlord phone visibility. Safe to run more than once.

-- Landlord chooses who can see their phone number --------------------------------
alter table cs_profiles add column if not exists phone_visibility text not null default 'hidden';
alter table cs_profiles drop constraint if exists cs_profiles_phone_vis_check;
alter table cs_profiles add constraint cs_profiles_phone_vis_check
  check (phone_visibility in ('hidden','after_enquiry','public'));

-- Public approximate position (a ~500 m area), maintained by a trigger -----------
alter table cs_properties add column if not exists approx_lat double precision;
alter table cs_properties add column if not exists approx_lng double precision;
alter table cs_properties drop constraint if exists cs_properties_approx_check;
alter table cs_properties add constraint cs_properties_approx_check check (
  (approx_lat is null and approx_lng is null)
  or (approx_lat between 3.5 and 14.0 and approx_lng between 2.0 and 15.5));
create index if not exists cs_properties_geo_idx on cs_properties (approx_lat, approx_lng);

-- Exact position and address: owner, admins, and students with a CONFIRMED viewing --
create table if not exists cs_property_locations (
  property_id uuid primary key references cs_properties(id) on delete cascade,
  lat double precision not null check (lat between 3.5 and 14.0),
  lng double precision not null check (lng between 2.0 and 15.5),
  address_line text check (char_length(address_line) <= 200),
  updated_at timestamptz not null default now()
);
alter table cs_property_locations enable row level security;
drop policy if exists cs_loc_owner on cs_property_locations;
create policy cs_loc_owner on cs_property_locations for all
  using (exists (select 1 from cs_properties p where p.id = property_id and p.owner_id = auth.uid()))
  with check (exists (select 1 from cs_properties p where p.id = property_id and p.owner_id = auth.uid()));
drop policy if exists cs_loc_admin on cs_property_locations;
create policy cs_loc_admin on cs_property_locations for select using (cs_is_admin());
drop policy if exists cs_loc_viewer on cs_property_locations;
create policy cs_loc_viewer on cs_property_locations for select using (exists (
  select 1 from cs_viewing_requests v
   where v.property_id = cs_property_locations.property_id and v.student_id = auth.uid() and v.status = 'confirmed'));

create or replace function cs_sync_approx_location() returns trigger
language plpgsql security definer set search_path = public as $$
declare
  pid uuid := coalesce(new.property_id, old.property_id);
  v_lat double precision; v_lng double precision; v_old_lat double precision; v_status text;
begin
  perform set_config('campusstay.bypass', '1', true);
  select approx_lat, moderation_status::text into v_old_lat, v_status from cs_properties where id = pid;
  if tg_op = 'DELETE' then
    update cs_properties set approx_lat = null, approx_lng = null where id = pid;
    return null;
  end if;
  -- Snap to a ~550 m grid, then nudge by a stable per-listing offset so the exact spot cannot be guessed.
  v_lat := round(new.lat / 0.005) * 0.005 + ((abs(('x' || substr(md5(pid::text), 1, 6))::bit(24)::int) % 61) - 30) * 0.00005;
  v_lng := round(new.lng / 0.005) * 0.005 + ((abs(('x' || substr(md5(pid::text), 7, 6))::bit(24)::int) % 61) - 30) * 0.00005;
  update cs_properties set approx_lat = v_lat, approx_lng = v_lng,
         -- moving an approved listing somewhere else sends it back for review
         moderation_status = case when v_status = 'approved' and v_old_lat is not null
                                   and abs(v_old_lat - v_lat) > 0.02 then 'pending'::cs_moderation_status else moderation_status end
   where id = pid;
  return null;
end $$;
drop trigger if exists cs_trg_sync_location on cs_property_locations;
create trigger cs_trg_sync_location after insert or update or delete on cs_property_locations
  for each row execute function cs_sync_approx_location();

-- Guard: approximate position can only be set by the trigger above.
create or replace function cs_guard_property() returns trigger
language plpgsql security definer set search_path = public as $$
declare
  bypass boolean := coalesce(current_setting('campusstay.bypass', true), '') = '1';
  ignore_cols text[] := array['moderation_status','availability_status','verification_level','expires_at',
    'views_count','moderation_note','updated_at','created_at','amenity_codes','owner_id','approx_lat','approx_lng'];
begin
  if tg_op = 'INSERT' then
    if not cs_is_admin() then
      new.moderation_status := 'draft';
      new.verification_level := 'unverified';
      new.expires_at := null;
      new.views_count := 0;
      new.moderation_note := null;
      new.amenity_codes := '{}';
      new.approx_lat := null;
      new.approx_lng := null;
    end if;
    return new;
  end if;

  new.owner_id := old.owner_id;
  new.updated_at := now();
  if bypass or cs_is_admin() then
    return new;
  end if;

  new.verification_level := old.verification_level;
  new.expires_at := old.expires_at;
  new.views_count := old.views_count;
  new.moderation_note := old.moderation_note;
  new.amenity_codes := old.amenity_codes;
  new.approx_lat := old.approx_lat;
  new.approx_lng := old.approx_lng;

  if new.moderation_status is distinct from old.moderation_status then
    if not (new.moderation_status = 'pending' and old.moderation_status in ('draft','needs_changes','rejected')) then
      new.moderation_status := old.moderation_status;
    end if;
  end if;

  if old.moderation_status = 'approved' and new.moderation_status = 'approved'
     and (to_jsonb(new) - ignore_cols) is distinct from (to_jsonb(old) - ignore_cols) then
    new.moderation_status := 'pending';
  end if;
  return new;
end $$;

-- Landlord phone: the server decides, the app never receives a number it may not show ---
create table if not exists cs_contact_reveals (
  id bigint generated always as identity primary key,
  user_id uuid not null references cs_profiles(id) on delete cascade,
  property_id uuid not null references cs_properties(id) on delete cascade,
  created_at timestamptz not null default now()
);
create index if not exists cs_contact_reveals_user_idx on cs_contact_reveals (user_id, created_at);
alter table cs_contact_reveals enable row level security; -- no policies: only the functions below touch it

-- Returns: signin | none | hidden | locked | available   (never the number itself)
create or replace function cs_contact_status(p_property_id uuid) returns text
language plpgsql stable security definer set search_path = public as $$
declare v_owner uuid; v_phone text; v_vis text;
begin
  if auth.uid() is null then return 'signin'; end if;
  select owner_id into v_owner from cs_properties
   where id = p_property_id and moderation_status = 'approved' and availability_status = 'available'
     and (expires_at is null or expires_at > now());
  if v_owner is null or v_owner = auth.uid() then return 'none'; end if;
  select phone, phone_visibility into v_phone, v_vis from cs_profiles where id = v_owner and not is_suspended;
  if v_phone is null or v_vis = 'hidden' then return 'hidden'; end if;
  if exists (select 1 from cs_blocks b where (b.blocker_id = v_owner and b.blocked_id = auth.uid())
                                          or (b.blocker_id = auth.uid() and b.blocked_id = v_owner)) then
    return 'hidden';
  end if;
  if v_vis = 'public' then return 'available'; end if;
  if exists (select 1 from cs_conversations c where c.property_id = p_property_id and c.student_id = auth.uid())
     or exists (select 1 from cs_viewing_requests v where v.property_id = p_property_id and v.student_id = auth.uid() and v.status = 'confirmed') then
    return 'available';
  end if;
  return 'locked';
end $$;

create or replace function cs_reveal_contact(p_property_id uuid) returns text
language plpgsql volatile security definer set search_path = public as $$
declare v_phone text;
begin
  if cs_contact_status(p_property_id) <> 'available' then raise exception 'not allowed'; end if;
  if not cs_is_active_user() then raise exception 'account suspended'; end if;
  if (select count(*) from cs_contact_reveals where user_id = auth.uid() and created_at > now() - interval '1 hour') >= 20 then
    raise exception 'rate limit: too many requests';
  end if;
  select pr.phone into v_phone from cs_properties p join cs_profiles pr on pr.id = p.owner_id where p.id = p_property_id;
  insert into cs_contact_reveals (user_id, property_id) values (auth.uid(), p_property_id);
  return v_phone;
end $$;

revoke all on function cs_contact_status, cs_reveal_contact from public, anon;
grant execute on function cs_contact_status, cs_reveal_contact to authenticated;

