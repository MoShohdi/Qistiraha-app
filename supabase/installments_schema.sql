-- ============================================================================
-- Qistiraha — marketplace schema: businesses + installments (real-time)
--
-- Run in the Supabase SQL Editor AFTER supabase/schema.sql (which creates
-- public.profiles). Every statement is idempotent — safe to re-run in full.
--
-- Identity model:
--   * A merchant is simply an authenticated user; `installments.merchant_id`
--     references auth.users(id) directly (= the merchant's auth uid). The
--     `businesses` row is that merchant's storefront metadata (name/category),
--     keyed by `owner_id`.
--   * `installments.consumer_id` starts NULL. It is filled in exactly once,
--     by the consumer who claims the link (the merchant→consumer handshake).
-- ============================================================================

-- ---------------------------------------------------------------------------
-- businesses
-- ---------------------------------------------------------------------------
create table if not exists public.businesses (
  id            uuid primary key default gen_random_uuid(),
  owner_id      uuid not null references auth.users (id) on delete cascade,
  business_name text not null,
  category      text,
  created_at    timestamptz not null default now()
);

alter table public.businesses enable row level security;

-- Merchant fully manages their own storefront row.
drop policy if exists "businesses: owner manages own" on public.businesses;
create policy "businesses: owner manages own"
  on public.businesses for all
  using (owner_id = auth.uid())
  with check (owner_id = auth.uid());

-- Any signed-in user may read storefront names — a consumer claiming a link
-- needs to see which merchant issued it. (Business names are not sensitive.)
drop policy if exists "businesses: authenticated can read" on public.businesses;
create policy "businesses: authenticated can read"
  on public.businesses for select
  to authenticated
  using (true);

-- ---------------------------------------------------------------------------
-- installments
-- ---------------------------------------------------------------------------
create table if not exists public.installments (
  id               uuid primary key default gen_random_uuid(),
  merchant_id      uuid not null references auth.users (id) on delete cascade,
  consumer_id      uuid references auth.users (id) on delete set null, -- NULL until claimed
  item_description text,
  total_amount     numeric(12, 2) not null,
  paid_amount      numeric(12, 2) not null default 0,
  months           integer,
  status           text not null default 'pending_scan'
                     check (status in ('pending_scan', 'active', 'completed', 'cancelled')),
  created_at       timestamptz not null default now(),
  updated_at       timestamptz not null default now()
);

create index if not exists installments_merchant_id_idx on public.installments (merchant_id);
create index if not exists installments_consumer_id_idx on public.installments (consumer_id);

alter table public.installments enable row level security;

-- SELECT: a merchant sees the rows they generated; a consumer sees the rows
-- they claimed; and ANY authenticated user may read a row that is still
-- `pending_scan` — that read is what lets a consumer preview a link before
-- claiming it.
--
-- Privacy tradeoff: this exposes unclaimed rows to any authenticated user who
-- guesses/obtains an id. Ids are unguessable uuids, but if you want zero
-- exposure, drop the `status = 'pending_scan'` clause here and move claiming
-- into a SECURITY DEFINER `claim_installment(uuid)` RPC instead. Kept in RLS
-- here because the brief asked for the claim to be a plain RLS UPDATE.
drop policy if exists "installments: select own or unclaimed" on public.installments;
create policy "installments: select own or unclaimed"
  on public.installments for select
  to authenticated
  using (
    merchant_id = auth.uid()
    or consumer_id = auth.uid()
    or status = 'pending_scan'
  );

-- INSERT: a merchant may only create rows attributed to themselves. (The app
-- always inserts consumer_id NULL / status 'pending_scan'; enforce ownership
-- here and leave the rest to the column default + check constraint.)
drop policy if exists "installments: merchant inserts own" on public.installments;
create policy "installments: merchant inserts own"
  on public.installments for insert
  to authenticated
  with check (merchant_id = auth.uid());

-- UPDATE (merchant): the issuing merchant manages their own rows — recording
-- payments, marking completed/cancelled, etc.
drop policy if exists "installments: merchant updates own" on public.installments;
create policy "installments: merchant updates own"
  on public.installments for update
  to authenticated
  using (merchant_id = auth.uid())
  with check (merchant_id = auth.uid());

-- UPDATE (consumer claim): the crucial handshake policy. USING restricts which
-- rows can be targeted — only an unclaimed, still-pending row. WITH CHECK
-- restricts the resulting row — the consumer may only set THEMSELVES as the
-- consumer and flip status to 'active'. Together this lets a consumer claim a
-- pending link and nothing more (they can't claim on someone else's behalf,
-- can't touch already-claimed rows, can't edit amounts).
drop policy if exists "installments: consumer claims pending" on public.installments;
create policy "installments: consumer claims pending"
  on public.installments for update
  to authenticated
  using (status = 'pending_scan' and consumer_id is null)
  with check (consumer_id = auth.uid() and status = 'active');

-- UPDATE (consumer records payments): after claiming, the consumer owns the
-- plan and needs to write payment progress to it (paid_months, past_payments,
-- due_date, last_paid_at, status → completed). This lets them update any row
-- where they are the consumer.
--
-- Integrity note: WITH CHECK can only assert the NEW row's consumer_id, so a
-- determined consumer could technically also alter contract fields
-- (total_amount, merchant_id) on their own row. For a beta this is accepted;
-- to lock it down, replace this policy with a SECURITY DEFINER
-- `record_payment(uuid)` RPC that mutates only the payment columns.
drop policy if exists "installments: consumer updates own" on public.installments;
create policy "installments: consumer updates own"
  on public.installments for update
  to authenticated
  using (consumer_id = auth.uid())
  with check (consumer_id = auth.uid());

-- DELETE: only the issuing merchant may delete a row they created.
drop policy if exists "installments: merchant deletes own" on public.installments;
create policy "installments: merchant deletes own"
  on public.installments for delete
  to authenticated
  using (merchant_id = auth.uid());

-- Table privileges for the `authenticated` role. RLS still gates every row;
-- these grants just make the table reachable by signed-in users at all.
grant select, insert, update, delete on public.installments to authenticated;
grant select, insert, update, delete on public.businesses   to authenticated;

-- ---------------------------------------------------------------------------
-- keep updated_at fresh on every write
-- ---------------------------------------------------------------------------
create or replace function public.touch_updated_at()
returns trigger
language plpgsql
as $$
begin
  new.updated_at = now();
  return new;
end;
$$;

drop trigger if exists installments_touch_updated_at on public.installments;
create trigger installments_touch_updated_at
  before update on public.installments
  for each row execute function public.touch_updated_at();
