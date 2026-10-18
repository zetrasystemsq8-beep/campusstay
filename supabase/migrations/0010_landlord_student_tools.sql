-- Spaces left, listing stats, reply speed, saved searches. Safe to run more than once.

-- Spaces left (hostels, flats with several rooms) -------------------------------------
alter table cs_properties add column if not exists spaces_available smallint;
alter table cs_properties drop constraint if exists cs_properties_spaces_check;
alter table cs_properties add constraint cs_properties_spaces_check check (spaces_available is null or spaces_available between 0 and 500);

create or replace function cs_spaces_full() returns trigger language plpgsql as $$
begin
  if new.spaces_available is not null and new.spaces_available = 0 and new.availability_status = 'available' then
    new.availability_status := 'rented';
  end if;
  return new;
end $$;
drop trigger if exists trg_spaces_full on cs_properties;
create trigger trg_spaces_full before insert or update on cs_properties
  for each row execute function cs_spaces_full();

-- When a listing was approved, for "new matches" in saved searches ----------------------
alter table cs_properties add column if not exists approved_at timestamptz;
-- Backfill with the guard switched off, otherwise it would send approved listings back to review.
select set_config('campusstay.bypass', '1', false);
update cs_properties set approved_at = coalesce(approved_at, updated_at) where moderation_status = 'approved' and approved_at is null;
select set_config('campusstay.bypass', '', false);
create index if not exists cs_properties_approved_idx on cs_properties (approved_at);

create or replace function cs_admin_moderate_listing(p_property_id uuid, p_decision text, p_note text) returns void
language plpgsql security definer set search_path = public as $$
begin
  if not cs_is_admin() then raise exception 'forbidden'; end if;
  if p_decision not in ('approved','rejected','needs_changes') then raise exception 'bad decision'; end if;
  update cs_properties set moderation_status = p_decision::cs_moderation_status,
         moderation_note = left(p_note, 1000),
         expires_at = case when p_decision = 'approved' then now() + interval '60 days' else expires_at end,
         approved_at = case when p_decision = 'approved' then coalesce(approved_at, now()) else approved_at end
   where id = p_property_id;
  insert into cs_audit_events (actor_id, action, target_type, target_id, details)
  values (auth.uid(), 'moderate_listing', 'property', p_property_id, jsonb_build_object('decision', p_decision, 'note', p_note));
end $$;

-- Guard: spaces_available is a landlord's day-to-day number, so changing it never triggers re-review.
create or replace function cs_guard_property() returns trigger
language plpgsql security definer set search_path = public as $$
declare
  bypass boolean := coalesce(current_setting('campusstay.bypass', true), '') = '1';
  ignore_cols text[] := array['moderation_status','availability_status','verification_level','expires_at',
    'views_count','moderation_note','updated_at','created_at','amenity_codes','owner_id','approx_lat','approx_lng',
    'spaces_available','approved_at'];
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
      new.approved_at := null;
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
  new.approved_at := old.approved_at;

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

-- Listing statistics for the owner only ---------------------------------------------------
create or replace function cs_listing_stats() returns table (property_id uuid, views int, saves int, enquiries int, viewings int)
language sql stable security definer set search_path = public as $$
  select p.id,
         p.views_count,
         (select count(*) from cs_favourites f where f.property_id = p.id)::int,
         (select count(*) from cs_conversations c where c.property_id = p.id)::int,
         (select count(*) from cs_viewing_requests v where v.property_id = p.id)::int
    from cs_properties p
   where p.owner_id = auth.uid();
$$;

-- How fast this landlord usually replies. Only a rough bucket, and only after 3 replied conversations.
create or replace function cs_reply_speed(p_property_id uuid) returns text
language plpgsql stable security definer set search_path = public as $$
declare v_owner uuid; v_n int; v_med double precision;
begin
  if auth.uid() is null then return 'unknown'; end if;
  select owner_id into v_owner from cs_properties where id = p_property_id and moderation_status = 'approved';
  if v_owner is null then return 'unknown'; end if;
  with convs as (
    select (select min(m.created_at) from cs_messages m where m.conversation_id = c.id and m.sender_id = c.student_id) as first_student,
           (select min(m.created_at) from cs_messages m where m.conversation_id = c.id and m.sender_id = c.landlord_id) as first_reply
      from cs_conversations c
     where c.landlord_id = v_owner and c.created_at > now() - interval '90 days')
  select count(*), percentile_cont(0.5) within group (order by extract(epoch from (first_reply - first_student)))
    into v_n, v_med
    from convs where first_reply is not null and first_student is not null and first_reply >= first_student;
  if v_n < 3 then return 'unknown'; end if;
  return case when v_med <= 3600 then 'within_hour' when v_med <= 21600 then 'within_hours'
              when v_med <= 86400 then 'within_day' else 'slow' end;
end $$;

-- Saved searches -------------------------------------------------------------------------
create table if not exists cs_saved_searches (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references cs_profiles(id) on delete cascade,
  name text not null check (char_length(name) between 1 and 60),
  filter jsonb not null default '{}',
  last_seen_at timestamptz not null default now(),
  created_at timestamptz not null default now()
);
create index if not exists cs_saved_searches_user_idx on cs_saved_searches (user_id, created_at);
alter table cs_saved_searches enable row level security;
drop policy if exists cs_saved_searches_own on cs_saved_searches;
create policy cs_saved_searches_own on cs_saved_searches for all
  using (user_id = auth.uid())
  with check (user_id = auth.uid() and (select count(*) from cs_saved_searches s where s.user_id = auth.uid()) < 10);

revoke all on function cs_listing_stats, cs_reply_speed from public, anon;
grant execute on function cs_listing_stats, cs_reply_speed to authenticated;
