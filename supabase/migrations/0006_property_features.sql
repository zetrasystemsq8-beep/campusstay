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
