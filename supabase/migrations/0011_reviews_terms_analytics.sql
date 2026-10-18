-- Terms acceptance, verified-viewer reviews, admin analytics. Safe to run more than once.

-- Terms acceptance is recorded at sign-up -------------------------------------------------
alter table cs_profiles add column if not exists terms_version text;
alter table cs_profiles add column if not exists terms_accepted_at timestamptz;

create or replace function cs_handle_new_user() returns trigger
language plpgsql security definer set search_path = public as $$
begin
  insert into cs_profiles (id, role, full_name, terms_version, terms_accepted_at)
  values (new.id,
    case new.raw_user_meta_data->>'role' when 'landlord' then 'landlord'::cs_user_role
                                         when 'agent' then 'agent'::cs_user_role
                                         else 'student'::cs_user_role end,
    left(coalesce(new.raw_user_meta_data->>'full_name',''), 100),
    left(new.raw_user_meta_data->>'terms_version', 20),
    case when new.raw_user_meta_data->>'terms_version' is not null then now() end);
  return new;
end $$;

-- Reviews: only students whose viewing was confirmed (and has happened) can review ---------
create table if not exists cs_reviews (
  id uuid primary key default gen_random_uuid(),
  property_id uuid not null references cs_properties(id) on delete cascade,
  student_id uuid not null references cs_profiles(id) on delete cascade,
  rating smallint not null check (rating between 1 and 5),
  comment text check (char_length(comment) <= 1000),
  reply text check (char_length(reply) <= 1000),
  replied_at timestamptz,
  created_at timestamptz not null default now(),
  unique (property_id, student_id)
);
create index if not exists cs_reviews_property_idx on cs_reviews (property_id, created_at desc);
alter table cs_reviews enable row level security;
drop policy if exists cs_reviews_admin_read on cs_reviews;
create policy cs_reviews_admin_read on cs_reviews for select using (cs_is_admin());
-- No other policies: everything goes through the functions below, which check the rules.

create or replace function cs_can_review(p_property_id uuid) returns text
language plpgsql stable security definer set search_path = public as $$
declare v_owner uuid;
begin
  if auth.uid() is null then return 'signin'; end if;
  select owner_id into v_owner from cs_properties where id = p_property_id;
  if v_owner is null then return 'no'; end if;
  if v_owner = auth.uid() then return 'own'; end if;
  if not exists (select 1 from cs_viewing_requests v where v.property_id = p_property_id and v.student_id = auth.uid()
                  and v.status = 'confirmed' and v.preferred_at < now()) then return 'no'; end if;
  if exists (select 1 from cs_reviews r where r.property_id = p_property_id and r.student_id = auth.uid()) then return 'edit'; end if;
  return 'yes';
end $$;

create or replace function cs_submit_review(p_property_id uuid, p_rating int, p_comment text) returns void
language plpgsql security definer set search_path = public as $$
begin
  if cs_can_review(p_property_id) not in ('yes','edit') then raise exception 'not allowed'; end if;
  if not cs_is_active_user() then raise exception 'account suspended'; end if;
  if p_rating is null or p_rating not between 1 and 5 then raise exception 'invalid rating'; end if;
  if char_length(coalesce(p_comment, '')) > 1000 then raise exception 'invalid rating comment'; end if;
  insert into cs_reviews (property_id, student_id, rating, comment)
  values (p_property_id, auth.uid(), p_rating, nullif(trim(p_comment), ''))
  on conflict (property_id, student_id)
  do update set rating = excluded.rating, comment = excluded.comment, created_at = now();
end $$;

create or replace function cs_review_summary(p_property_id uuid) returns json
language sql stable security definer set search_path = public as $$
  select json_build_object('avg', coalesce(round(avg(r.rating)::numeric, 1), 0), 'count', count(*))
    from cs_reviews r join cs_properties p on p.id = r.property_id
   where r.property_id = p_property_id and (p.moderation_status = 'approved' or p.owner_id = auth.uid() or cs_is_admin());
$$;

-- Reviewers stay anonymous: no names, only "a student who viewed this place".
create or replace function cs_property_reviews(p_property_id uuid)
returns table (id uuid, rating int, comment text, created_at timestamptz, mine boolean, reply text, replied_at timestamptz)
language sql stable security definer set search_path = public as $$
  select r.id, r.rating::int, r.comment, r.created_at, (r.student_id = auth.uid()), r.reply, r.replied_at
    from cs_reviews r join cs_properties p on p.id = r.property_id
   where r.property_id = p_property_id and (p.moderation_status = 'approved' or p.owner_id = auth.uid() or cs_is_admin())
   order by r.created_at desc limit 50;
$$;

create or replace function cs_reply_to_review(p_review_id uuid, p_reply text) returns void
language plpgsql security definer set search_path = public as $$
begin
  update cs_reviews r
     set reply = nullif(left(trim(coalesce(p_reply, '')), 1000), ''),
         replied_at = case when nullif(trim(coalesce(p_reply, '')), '') is null then null else now() end
   where r.id = p_review_id and exists (select 1 from cs_properties p where p.id = r.property_id and p.owner_id = auth.uid());
  if not found then raise exception 'not allowed'; end if;
end $$;

create or replace function cs_admin_delete_review(p_review_id uuid, p_note text) returns void
language plpgsql security definer set search_path = public as $$
begin
  if not cs_is_admin() then raise exception 'forbidden'; end if;
  delete from cs_reviews where id = p_review_id;
  insert into cs_audit_events (actor_id, action, target_type, target_id, details)
  values (auth.uid(), 'delete_review', 'review', p_review_id, jsonb_build_object('note', p_note));
end $$;

-- Reviews can be reported like listings and people ---------------------------------------------
do $$
declare c text;
begin
  for c in select conname from pg_constraint where conrelid = 'cs_reports'::regclass and contype = 'c' and pg_get_constraintdef(oid) like '%target_type%'
  loop execute format('alter table cs_reports drop constraint %I', c); end loop;
end $$;
alter table cs_reports add constraint cs_reports_target_type_check check (target_type in ('property','user','message','review'));

-- Admin analytics -------------------------------------------------------------------------------
create or replace function cs_admin_breakdown() returns json
language plpgsql security definer set search_path = public as $$
begin
  if not cs_is_admin() then raise exception 'forbidden'; end if;
  return json_build_object(
    'by_state', (select coalesce(json_agg(t), '[]'::json) from (
        select u.state as label, count(*)::int as n from cs_properties p join cs_universities u on u.id = p.university_id
         where p.moderation_status = 'approved' group by u.state order by n desc limit 10) t),
    'by_school', (select coalesce(json_agg(t), '[]'::json) from (
        select u.short_name as label, count(*)::int as n from cs_properties p join cs_universities u on u.id = p.university_id
         where p.moderation_status = 'approved' group by u.short_name order by n desc limit 10) t),
    'users_by_role', (select coalesce(json_agg(t), '[]'::json) from (
        select role::text as label, count(*)::int as n from cs_profiles group by role order by n desc) t),
    'listings_by_status', (select coalesce(json_agg(t), '[]'::json) from (
        select moderation_status::text as label, count(*)::int as n from cs_properties group by moderation_status order by n desc) t),
    'report_reasons', (select coalesce(json_agg(t), '[]'::json) from (
        select reason as label, count(*)::int as n from cs_reports group by reason order by n desc limit 6) t));
end $$;

revoke all on function cs_can_review, cs_submit_review, cs_review_summary, cs_property_reviews, cs_reply_to_review, cs_admin_delete_review, cs_admin_breakdown from public, anon;
grant execute on function cs_can_review, cs_submit_review, cs_review_summary, cs_property_reviews, cs_reply_to_review, cs_admin_delete_review, cs_admin_breakdown to authenticated;
