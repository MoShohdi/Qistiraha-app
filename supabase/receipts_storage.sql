-- ============================================================================
-- Qistiraha — receipt/warranty images via Supabase Storage
--
-- Run in the Supabase SQL Editor. Idempotent — safe to re-run.
--
-- Files are stored at path `<auth.uid>/<installment_id>.jpg`, so the first
-- path segment is the owner's uid — that's what the write policies check.
-- The bucket is public, so the stored `receipt_image_url` is viewable on any
-- device without a signed URL.
-- ============================================================================

-- 1. The bucket ------------------------------------------------------------
insert into storage.buckets (id, name, public)
values ('receipts', 'receipts', true)
on conflict (id) do nothing;

-- 2. Storage RLS (on storage.objects) -------------------------------------
-- Read: bucket is public, but grant authenticated select too for the app.
drop policy if exists "receipts: read" on storage.objects;
create policy "receipts: read"
  on storage.objects for select
  to authenticated
  using (bucket_id = 'receipts');

-- Write/replace/delete: only within your own `<uid>/…` folder.
drop policy if exists "receipts: insert own" on storage.objects;
create policy "receipts: insert own"
  on storage.objects for insert
  to authenticated
  with check (
    bucket_id = 'receipts'
    and (storage.foldername(name))[1] = auth.uid()::text
  );

drop policy if exists "receipts: update own" on storage.objects;
create policy "receipts: update own"
  on storage.objects for update
  to authenticated
  using (
    bucket_id = 'receipts'
    and (storage.foldername(name))[1] = auth.uid()::text
  );

drop policy if exists "receipts: delete own" on storage.objects;
create policy "receipts: delete own"
  on storage.objects for delete
  to authenticated
  using (
    bucket_id = 'receipts'
    and (storage.foldername(name))[1] = auth.uid()::text
  );

-- 3. The column ------------------------------------------------------------
alter table public.installments
  add column if not exists receipt_image_url text;
