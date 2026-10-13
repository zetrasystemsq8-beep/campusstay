-- Stage 2: landlord support + fixes to Stage 1 guards.

alter table properties add column if not exists moderation_note text check (char_length(moderation_note) <= 1000);

-- FIX: security-definer functions (renew, record_view, verification trigger) must be able to
-- change guarded columns. They set a transaction-local flag; clients cannot set it
-- because the guard only trusts it inside the same transaction as those functions.
create or replace function guard_property() returns trigger
language plpgsql security definer set search_path = public as $$
declare bypass boolean := coalesce(current_setting('campusstay.bypass', true), '') = '1';
begin
  if tg_op = 'INSERT' then
    if not is_admin() then
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
  if bypass or is_admin() then
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

create or replace function renew_listing(p_property_id uuid) returns void
language plpgsql security definer set search_path = public as $$
begin
  perform set_config('campusstay.bypass', '1', true);
  update properties set expires_at = now() + interval '60 days'
   where id = p_property_id and owner_id = auth.uid() and moderation_status = 'approved';
  if not found then raise exception 'not allowed'; end if;
end $$;

create or replace function record_view(p_property_id uuid) returns void
language plpgsql security definer set search_path = public as $$
begin
  perform set_config('campusstay.bypass', '1', true);
  update properties set views_count = views_count + 1
   where id = p_property_id and moderation_status = 'approved'
     and owner_id is distinct from auth.uid();
end $$;

create or replace function admin_moderate_listing(p_property_id uuid, p_decision text, p_note text) returns void
language plpgsql security definer set search_path = public as $$
begin
  if not is_admin() then raise exception 'forbidden'; end if;
  if p_decision not in ('approved','rejected','needs_changes') then raise exception 'bad decision'; end if;
  update properties set moderation_status = p_decision::moderation_status,
         moderation_note = left(p_note, 1000),
         expires_at = case when p_decision = 'approved' then now() + interval '60 days' else expires_at end
   where id = p_property_id;
  insert into audit_events (actor_id, action, target_type, target_id, details)
  values (auth.uid(), 'moderate_listing', 'property', p_property_id, jsonb_build_object('decision', p_decision, 'note', p_note));
end $$;

-- Uploading evidence marks the listing "pending review" (never "verified").
create or replace function on_verification_submitted() returns trigger
language plpgsql security definer set search_path = public as $$
begin
  if new.property_id is not null then
    perform set_config('campusstay.bypass', '1', true);
    update properties set verification_level = 'pending'
     where id = new.property_id and owner_id = new.user_id and verification_level = 'unverified';
  end if;
  return new;
end $$;
drop trigger if exists trg_verification_submitted on verification_submissions;
create trigger trg_verification_submitted after insert on verification_submissions
  for each row execute function on_verification_submitted();

-- Evidence may only be attached to the submitter's own property.
drop policy if exists vs_insert on verification_submissions;
create policy vs_insert on verification_submissions for insert with check (
  user_id = auth.uid() and status = 'pending'
  and (property_id is null or exists (select 1 from properties p where p.id = property_id and p.owner_id = auth.uid()))
);

create or replace function landlord_stats() returns json
language sql stable security invoker set search_path = public as $$
  select json_build_object(
    'total', count(*),
    'active', count(*) filter (where moderation_status = 'approved' and availability_status = 'available'
                                 and (expires_at is null or expires_at > now())),
    'pending', count(*) filter (where moderation_status = 'pending'),
    'views', coalesce(sum(views_count), 0),
    'enquiries', (select count(*) from conversations c where c.landlord_id = auth.uid())
  ) from properties where owner_id = auth.uid();
$$;
grant execute on function landlord_stats, renew_listing, record_view to authenticated;
