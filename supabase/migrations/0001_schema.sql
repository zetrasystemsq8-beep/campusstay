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
