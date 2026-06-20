-- ============================================================
--  Expenses app — Supabase setup
--  Paste this whole file into the Supabase SQL Editor and Run.
--  Safe to run once on a fresh project.
-- ============================================================

-- ---------- Tables ----------
create table if not exists public.folders (
  id          uuid primary key default gen_random_uuid(),
  user_id     uuid not null default auth.uid() references auth.users(id) on delete cascade,
  name        text not null,
  created_at  timestamptz not null default now()
);

create table if not exists public.expenses (
  id            uuid primary key default gen_random_uuid(),
  folder_id     uuid not null references public.folders(id) on delete cascade,
  user_id       uuid not null default auth.uid() references auth.users(id) on delete cascade,
  merchant      text,
  amount        numeric(12,2),
  date          date,
  category      text,
  note          text,
  receipt_paths text[] not null default '{}',  -- storage paths for this expense's receipt pages
  created_at    timestamptz not null default now()
);

create index if not exists expenses_folder_idx on public.expenses(folder_id);

-- ---------- Row-Level Security: each user sees only their own rows ----------
alter table public.folders  enable row level security;
alter table public.expenses enable row level security;

drop policy if exists "own folders"  on public.folders;
create policy "own folders" on public.folders
  for all using (user_id = auth.uid()) with check (user_id = auth.uid());

drop policy if exists "own expenses" on public.expenses;
create policy "own expenses" on public.expenses
  for all using (user_id = auth.uid()) with check (user_id = auth.uid());

-- ---------- Private storage bucket for receipt images/PDF pages ----------
insert into storage.buckets (id, name, public)
values ('receipts', 'receipts', false)
on conflict (id) do nothing;

-- Files are stored under  <user_id>/<expense_id>/<n>.jpg
-- so the first path segment must equal the logged-in user's id.
drop policy if exists "receipts read"   on storage.objects;
drop policy if exists "receipts write"  on storage.objects;
drop policy if exists "receipts modify" on storage.objects;
drop policy if exists "receipts delete" on storage.objects;

create policy "receipts read" on storage.objects
  for select using (
    bucket_id = 'receipts' and (storage.foldername(name))[1] = auth.uid()::text
  );

create policy "receipts write" on storage.objects
  for insert with check (
    bucket_id = 'receipts' and (storage.foldername(name))[1] = auth.uid()::text
  );

create policy "receipts modify" on storage.objects
  for update using (
    bucket_id = 'receipts' and (storage.foldername(name))[1] = auth.uid()::text
  );

create policy "receipts delete" on storage.objects
  for delete using (
    bucket_id = 'receipts' and (storage.foldername(name))[1] = auth.uid()::text
  );
