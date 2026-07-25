-- ============================================================================
-- Qistiraha — Stage 5.1: guarantee the merchant can SELECT their installments
--
-- Run in the Supabase SQL Editor. Idempotent — safe to re-run.
--
-- Symptom this fixes: the merchant dashboard shows zero installments / zero
-- revenue even though rows exist. The realtime `.stream()` a merchant listens
-- to does an RLS-gated SELECT for its initial snapshot, so if no SELECT policy
-- grants `merchant_id = auth.uid()`, the merchant simply sees nothing.
--
-- This re-states the canonical SELECT policy from installments_schema.sql so
-- running this file alone is enough to restore merchant visibility. A merchant
-- sees rows they issued; a consumer sees rows they claimed; and any signed-in
-- user may read a still-`pending_scan` row (needed to preview a claim link).
-- ============================================================================

drop policy if exists "installments: select own or unclaimed" on public.installments;
create policy "installments: select own or unclaimed"
  on public.installments for select
  to authenticated
  using (
    merchant_id = auth.uid()
    or consumer_id = auth.uid()
    or status = 'pending_scan'
  );

-- Make sure the table is actually readable by signed-in users at all (RLS still
-- gates every row; this is just the table-level grant).
grant select on public.installments to authenticated;
