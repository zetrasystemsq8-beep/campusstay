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
