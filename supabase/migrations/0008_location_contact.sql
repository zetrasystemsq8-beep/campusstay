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
