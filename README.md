# CampusStay (Stage 1)

Flutter + Supabase student-accommodation marketplace for Nigeria.
**Status: Stage 1 foundation. Nothing here has been compiled or run yet.** See "Status" below.

## Setup from Termux / GitHub
1. Create a new GitHub repo and extract this ZIP into it, then commit and push to `main`.
2. In Supabase, create a project. In the SQL editor run, in order:
   `supabase/migrations/0001_schema.sql`, `0002_storage.sql`, `supabase/seed.sql`.
3. In the GitHub repo: Settings > Secrets and variables > Actions, add
   `SUPABASE_URL` and `SUPABASE_ANON_KEY` (the anon/publishable key only).
4. Run the "Build Android APK" workflow. Download the `campusstay-apk` artifact.
5. To make an admin: sign up normally, then in the SQL editor run
   `update cs_profiles set role = 'admin' where id = '<your user id>';` (the app can never grant admin).

Android platform files are generated in CI by `flutter create`, so they are not in the repo.
Without the two secrets the app builds in **development mode** with fictional sample listings.

## Environment variables (no values committed)
| Name | Where | Purpose |
|---|---|---|
| SUPABASE_URL | GitHub secret / --dart-define | Project URL |
| SUPABASE_ANON_KEY | GitHub secret / --dart-define | Anon (publishable) key |
Never put the service-role key or database password in the app or repo.

## Status
Implemented in Stage 2 (written, unverified): landlord dashboard with stats and renewal reminders, 5-step add/edit property flow (details, photos, facilities, verification upload, review), listing management (pause, resume, mark rented, renew, delete), viewing requests, view counting, migration 0003 (fixes + landlord stats).

Stage 3 (written, unverified): admin console (review queue, approve/reject/request changes, reports with remove/suspend/dismiss,
verification document review with short-lived signed links, landlord leads, audit log), block and report a person from a chat,
typed error handling with specific friendly messages and timeouts everywhere, public landlord submission web page.

Property features update: schools (272 institutions in all 36 states and the FCT, with a searchable picker and "my school isn't listed"), a 7-step add-property flow with bedrooms, bathrooms, kitchen, furnishing, who it suits, availability, costs and instalments, house rules and 30 grouped facilities, and student filters for school, bedrooms, furnishing, gender and facilities. Run `0006_property_features.sql` then `0007_schools_nigeria.sql`. The school list was written from general knowledge, so spot-check it; fix or add schools with SQL on `cs_universities`.

All CampusStay database objects, buckets and functions are prefixed `cs_` / `cs-` so they can share a Supabase project with other apps. Run `supabase/all_in_one.sql` once (or the four migrations in order).

## Public landlord page
1. Deploy the edge function (paste `supabase/functions/cs-submit-listing/index.ts` into Supabase > Edge Functions, name it `cs-submit-listing`, turn OFF "Verify JWT"; or `supabase functions deploy cs-submit-listing --no-verify-jwt`).
   Optionally set a secret `IP_HASH_SALT` (any random text).
2. In the GitHub repo: Settings > Pages > Source: GitHub Actions. Push; the `Deploy landlord page` workflow publishes `web/landlord-submit` using your two existing secrets.
3. Share the Pages link on WhatsApp. Submissions arrive in the admin app under Leads. Nothing is ever published automatically.

## Errors and timeouts
All network calls go through `Net.run` (15 s, 60 s for uploads). Failures become typed errors (offline, timeout, invalid login, duplicate, forbidden, rate limited, blocked, file too large and more), each with its own wording. Unclassified errors are never hidden: they show a support reference, can be copied with details, and are logged with a stack trace.

Run the three older migrations in order too (0001, 0002).

Implemented in Stage 1 (written, unverified): splash, role choice, sign up/in/reset, student home, explore with filters and pagination,
saved listings, property detail with gallery, message landlord, request viewing, report listing, messages thread, profile/logout,
design tokens and reusable widgets, full schema with RLS, triggers, storage policies, admin RPCs with audit log, unit tests, CI.

Not implemented: scheduled expiry reminders (reminders show in-app only), push notifications, converting a lead into a listing automatically (admins call the landlord and help them sign up), account deletion, ads, push notifications, blocking UI,
university picker, real photography (listings without photos show an honest "No photo uploaded" state).

## Must be verified manually
- `flutter analyze` / `flutter test` / APK build in CI (not run yet).
- Every RLS policy against a live Supabase project, using two student accounts, a landlord and an admin.
- Signup role assignment, `start_enquiry` rate limit, storage policies, email confirmation flow.
- Appearance against the reference on a real device.
