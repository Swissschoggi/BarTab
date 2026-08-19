-- BarTab schema for Supabase
-- Run this in the Supabase SQL editor (Dashboard -> SQL -> New query).
-- It creates the tables the app expects and seeds the demo content.

-- Demo user id used by the seed rows (matches nothing special; the app
-- trusts the user id sent by clients until Auth is wired in).
create extension if not exists "pgcrypto";

-- MARK: - Bars

create table if not exists public.bars (
    id uuid primary key default gen_random_uuid(),
    name text not null,
    address text not null,
    latitude double precision not null,
    longitude double precision not null,
    created_at timestamptz not null default now(),
    created_by uuid not null
);

create index if not exists idx_bars_name on public.bars (name);

-- MARK: - Prices

create table if not exists public.prices (
    id uuid primary key default gen_random_uuid(),
    bar_id uuid not null references public.bars (id) on delete cascade,
    drink text not null,
    brand text,
    size text not null,
    amount numeric(10, 2) not null check (amount >= 0),
    currency text not null default 'CHF',
    reported_at timestamptz not null default now(),
    reported_by uuid not null
);

create index if not exists idx_prices_bar on public.prices (bar_id);
create index if not exists idx_prices_drink on public.prices (drink, size);

-- MARK: - Row Level Security
--
-- Prototype policies: read/write for everyone. Tighten these once
-- Supabase Auth is wired into the app (see comments at the bottom).

alter table public.bars enable row level security;
alter table public.prices enable row level security;

create policy "bars are readable by everyone"
    on public.bars for select using (true);

create policy "anyone can insert bars"
    on public.bars for insert with check (true);

create policy "bars can be deleted"
    on public.bars for delete using (true);

create policy "prices are readable by everyone"
    on public.prices for select using (true);

create policy "anyone can insert prices"
    on public.prices for insert with check (true);

create policy "prices can be updated"
    on public.prices for update using (true) with check (true);

create policy "prices can be deleted"
    on public.prices for delete using (true);

-- MARK: - Seed data (optional)

insert into public.bars (id, name, address, latitude, longitude, created_by)
values
    ('11111111-1111-1111-1111-111111111111', 'Test Bar Zürich', 'Langstrasse 1, Zürich', 47.3779, 8.5332, '00000000-0000-0000-0000-000000000001'),
    ('22222222-2222-2222-2222-222222222222', 'Another Bar', 'Niederdorf 10, Zürich', 47.3745, 8.5430, '00000000-0000-0000-0000-000000000001')
on conflict (id) do nothing;

insert into public.prices (id, bar_id, drink, brand, size, amount, currency, reported_by)
values
    ('aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa', '11111111-1111-1111-1111-111111111111', 'beer', 'Feldschlösschen', 'fiveDeciliters', 6.50, 'CHF', '00000000-0000-0000-0000-000000000001'),
    ('bbbbbbbb-bbbb-bbbb-bbbb-bbbbbbbbbbbb', '11111111-1111-1111-1111-111111111111', 'wine', 'Féchy', 'oneDeciliter', 7.00, 'CHF', '00000000-0000-0000-0000-000000000001'),
    ('cccccccc-cccc-cccc-cccc-cccccccccccc', '22222222-2222-2222-2222-222222222222', 'cocktail', null, 'glass', 14.00, 'CHF', '00000000-0000-0000-0000-000000000001')
on conflict (id) do nothing;

-- MARK: - When you wire in Supabase Auth
--
-- 1. Delete the permissive delete/update policies above.
-- 2. Add a `public.profiles` table keyed to auth.users with a
--    display_name and is_admin flag.
-- 3. Replace the delete policies, e.g.:
--
--    create policy "own bars only"
--        on public.bars for delete
--        using (created_by = auth.uid());
--
--    create policy "own prices only"
--        on public.prices for delete
--        using (reported_by = auth.uid());
--
-- 4. Send the real auth.uid() from the client instead of trusting
--    the id that the app sends in the body.