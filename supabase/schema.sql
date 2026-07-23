-- ============================================================================
-- Qistiraha — Supabase auth bridge: public.profiles + auto-provisioning
--
-- Run once in the Supabase SQL Editor (Dashboard → SQL Editor → New query).
-- Every statement is idempotent (safe to re-run in full if you need to
-- re-apply this file after a dashboard change).
--
-- Design notes:
--   * `role` is deliberately nullable. Google supplies no notion of
--     "consumer vs merchant", so no role is ever guessed at signup time —
--     the app always resolves it post-auth via an in-app Role Picker
--     (see AuthService.resolveDestination / completeRole in the Flutter
--     app). A null role is the signal the app uses to show that picker.
--   * There is no INSERT policy: the only path that creates a row is the
--     SECURITY DEFINER trigger below, running as the table owner. There is
--     no DELETE policy either: rows are removed solely via the
--     ON DELETE CASCADE from auth.users (i.e. when the auth user is
--     deleted), never directly by a client.
-- ============================================================================

create table if not exists public.profiles (
  id         uuid primary key references auth.users (id) on delete cascade,
  email      text,
  full_name  text,
  avatar_url text,
  role       text check (role in ('consumer', 'merchant')),
  created_at timestamptz not null default now()
);

alter table public.profiles enable row level security;

drop policy if exists "read own profile" on public.profiles;
create policy "read own profile"
  on public.profiles for select
  using (auth.uid() = id);

drop policy if exists "update own profile" on public.profiles;
create policy "update own profile"
  on public.profiles for update
  using (auth.uid() = id)
  with check (auth.uid() = id);

-- ----------------------------------------------------------------------------
-- Auto-provisioning: one profiles row per new auth.users row.
--
-- SECURITY DEFINER is required because this trigger fires as the internal
-- `supabase_auth_admin` role during signup, which has no grant on
-- `public.profiles` — DEFINER makes it run as the function's owner instead,
-- whose grants do allow the insert. `set search_path = public` pins the
-- schema resolution so a DEFINER function can't be tricked by a caller-
-- controlled search_path into resolving `profiles` to some other object
-- (the classic SECURITY DEFINER search-path-hijack vector).
-- ----------------------------------------------------------------------------
create or replace function public.handle_new_user()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
begin
  insert into public.profiles (id, email, full_name, avatar_url)
  values (
    new.id,
    new.email,
    new.raw_user_meta_data ->> 'full_name',   -- Google sets this; email
                                               -- signup passes it via
                                               -- `data: {'full_name': ...}`
    new.raw_user_meta_data ->> 'avatar_url'   -- Google only; null for email
  )
  on conflict (id) do nothing;                -- idempotent: safe on retries
  return new;
end;
$$;

drop trigger if exists on_auth_user_created on auth.users;
create trigger on_auth_user_created
  after insert on auth.users
  for each row execute function public.handle_new_user();
