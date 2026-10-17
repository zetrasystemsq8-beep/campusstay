-- Getting to school (walking time and typical fares) and how bills are paid. Safe to run more than once.
alter table cs_properties
  add column if not exists walk_minutes smallint,
  add column if not exists bike_fare_ngn integer,
  add column if not exists keke_fare_ngn integer,
  add column if not exists bus_fare_ngn integer,
  add column if not exists electricity_billing text,
  add column if not exists water_billing text;

alter table cs_properties drop constraint if exists cs_properties_transport_check;
alter table cs_properties add constraint cs_properties_transport_check check (
  (walk_minutes is null or walk_minutes between 1 and 240)
  and (bike_fare_ngn is null or bike_fare_ngn between 0 and 100000)
  and (keke_fare_ngn is null or keke_fare_ngn between 0 and 100000)
  and (bus_fare_ngn is null or bus_fare_ngn between 0 and 100000)
  and (electricity_billing is null or electricity_billing in ('prepaid','shared','included'))
  and (water_billing is null or water_billing in ('included','separate'))
);
create index if not exists cs_properties_walk_idx on cs_properties (walk_minutes);
-- The guard trigger already treats these as listing substance: changing them on an approved listing sends it back to review.
