-- ============================================================================
-- Qistiraha — schema expansion for the dashboard cutover (Option A)
--
-- Run in the Supabase SQL Editor AFTER supabase/installments_schema.sql.
-- Adds the fields the Affordability Engine, payment timelines, charts, and
-- frequency logic need to run entirely off the live stream.
--
-- DELIBERATELY OMITTED: any late-fee / penalty / acceleration columns.
-- Qistiraha no longer tracks or charges late fees, so there is nothing here
-- for `late_fee_rate`, `grace_days`, `penalty_amount`, etc.
--
-- Every statement is idempotent (`add column if not exists`), safe to re-run.
-- ============================================================================

-- ---------------------------------------------------------------------------
-- installments — richer plan shape
-- ---------------------------------------------------------------------------
alter table public.installments
  -- The per-PERIOD payment chunk (e.g. one quarter's amount for a quarterly
  -- plan), mirroring the app's existing `monthlyPayment` field semantics.
  add column if not exists monthly_payment  numeric(12, 2) not null default 0,

  -- 'Monthly' | 'Quarterly' | 'Semi-Annually' | 'Annually'. Drives every
  -- period calc (totalPayments, timeline node count, cadence labels).
  add column if not exists payment_frequency text not null default 'Monthly'
    check (payment_frequency in ('Monthly','Quarterly','Semi-Annually','Annually')),

  -- Progress is tracked in whole calendar MONTHS (period counts are derived:
  -- paid_months / monthsPerPayment), matching the existing timeline math.
  add column if not exists total_months     integer not null default 0,
  add column if not exists paid_months      integer not null default 0,

  -- Next payment due date; timelines step backward/forward from this.
  add column if not exists due_date         date,

  add column if not exists down_payment     numeric(12, 2) not null default 0,
  add column if not exists interest_rate    numeric(6, 3)  not null default 0,

  add column if not exists category         text,
  add column if not exists provider         text,           -- lender/BNPL/bank
  add column if not exists merchant_name    text,           -- storefront label
  add column if not exists is_long_term     boolean not null default false,

  -- Ordered list of actual amounts paid, one entry per completed period —
  -- powers the payment-history timeline. jsonb array of numbers.
  add column if not exists past_payments    jsonb not null default '[]'::jsonb,

  -- Exact moment of the most recent payment — anchors "paid this billing
  -- cycle" so the Safe-to-Spend calc is immune to the due-date roll-forward.
  add column if not exists last_paid_at     timestamptz;

-- Backfill total_months from the original `months` column for any rows that
-- predate this migration (the two are the same quantity).
update public.installments
  set total_months = months
  where total_months = 0 and months is not null and months > 0;

-- ---------------------------------------------------------------------------
-- profiles — income the Affordability Engine needs (was Hive-only before)
-- ---------------------------------------------------------------------------
alter table public.profiles
  add column if not exists monthly_income numeric(12, 2) not null default 0,
  add column if not exists salary_day     integer not null default 1
    check (salary_day between 1 and 28);
