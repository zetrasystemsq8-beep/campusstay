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
   `update profiles set role = 'admin' where id = '<your user id>';` (the app can never grant admin).

Android platform files are generated in CI by `flutter create`, so they are not in the repo.
Without the two secrets the app builds in **development mode** with fictional sample listings.

## Environment variables (no values committed)
| Name | Where | Purpose |
|---|---|---|
| SUPABASE_URL | GitHub secret / --dart-define | Project URL |
| SUPABASE_ANON_KEY | GitHub secret / --dart-define | Anon (publishable) key |
Never put the service-role key or database password in the app or repo.

## Status
Implemented (written, unverified): splash, role choice, sign up/in/reset, student home, explore with filters and pagination,
saved listings, property detail with gallery, message landlord, request viewing, report listing, messages thread, profile/logout,
design tokens and reusable widgets, full schema with RLS, triggers, storage policies, admin RPCs with audit log, unit tests, CI.

Not implemented: landlord dashboard, add-property flow, photo upload UI, verification upload UI, admin screens/web console,
public landlord submission web page, edit/pause/renew UI (renew RPC exists), ads, push notifications, blocking UI,
university picker, real photography (listings without photos show an honest "No photo uploaded" state).

## Must be verified manually
- `flutter analyze` / `flutter test` / APK build in CI (not run yet).
- Every RLS policy against a live Supabase project, using two student accounts, a landlord and an admin.
- Signup role assignment, `start_enquiry` rate limit, storage policies, email confirmation flow.
- Appearance against the reference on a real device.
