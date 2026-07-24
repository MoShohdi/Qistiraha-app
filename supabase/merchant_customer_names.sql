-- ============================================================================
-- Qistiraha — merchant sees the buyer's NAME ONLY, and only after the claim
--
-- Run in the Supabase SQL Editor. Idempotent — safe to re-run.
--
-- Problem: the merchant needs to show who claimed each installment, but RLS on
-- public.profiles ("read own profile") forbids them from reading a consumer's
-- row — and we do NOT want to expose income, salary day, or anything else.
--
-- Solution: a SECURITY DEFINER function that returns *only* (installment_id,
-- name), and only for rows where the CALLER is the merchant AND the installment
-- is already 'active' (i.e. the consumer has accepted/claimed it). Because it's
-- SECURITY DEFINER it may read profiles, but it deliberately selects a single
-- column and filters on `auth.uid()` (which, inside a definer function, is
-- still the CALLER's id from their JWT — not the function owner). So a merchant
-- can never see the name of a consumer on someone else's installment, nor on a
-- still-unclaimed pending_scan row, nor any other profile field.
-- ============================================================================

create or replace function public.merchant_customer_names()
returns table (installment_id uuid, customer_name text)
language sql
security definer
set search_path = public
as $$
  select i.id, p.full_name
  from public.installments i
  join public.profiles p on p.id = i.consumer_id
  where i.merchant_id = auth.uid()
    and i.status = 'active'
    and i.consumer_id is not null;
$$;

-- Lock down execution: no anon, only signed-in users (whose auth.uid() the
-- function keys off).
revoke all on function public.merchant_customer_names() from public;
grant execute on function public.merchant_customer_names() to authenticated;
