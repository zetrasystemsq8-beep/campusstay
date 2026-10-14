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
