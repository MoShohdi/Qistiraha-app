-- ============================================================================
-- Qistiraha — Stage 4: claim + decline RLS
--
-- Run in the Supabase SQL Editor. Idempotent — safe to re-run.
--
-- The claim/decline flow is a plain-RLS handshake on public.installments:
--   * CLAIM   — a consumer UPDATEs an unclaimed pending row, setting
--               consumer_id = auth.uid() and status = 'active'.
--   * DECLINE — a consumer DELETEs an unclaimed pending row so abandoned
--               drafts don't pile up.
-- Both are gated to rows that are still `pending_scan` with no consumer yet.
-- ============================================================================

-- CLAIM (already shipped in installments_schema.sql; re-stated here so this
-- file is self-contained). USING restricts which rows can be targeted (only an
-- unclaimed, still-pending row); WITH CHECK restricts the result (the consumer
-- may only set THEMSELVES as consumer and flip status to 'active').
drop policy if exists "installments: consumer claims pending" on public.installments;
create policy "installments: consumer claims pending"
  on public.installments for update
  to authenticated
  using (status = 'pending_scan' and consumer_id is null)
  with check (consumer_id = auth.uid() and status = 'active');

-- DECLINE — let an authenticated user delete a still-unclaimed pending row.
-- Same permissiveness (and same privacy tradeoff) as the "select pending" and
-- "claim pending" policies: ids are unguessable uuids, and only rows that
-- nobody has claimed yet can be removed. An already-claimed/active row is
-- untouched (consumer_id is no longer null), so this can never delete a live
-- plan — only an abandoned draft.
drop policy if exists "installments: decline pending" on public.installments;
create policy "installments: decline pending"
  on public.installments for delete
  to authenticated
  using (status = 'pending_scan' and consumer_id is null);
