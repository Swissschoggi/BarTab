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

-- MARK: - Profiles (Supabase Auth)
--
-- Every auth user gets a profile row (created by the trigger below)
-- so the app can check the `is_admin` flag after sign-in.

create table if not exists public.profiles (
    id uuid primary key references auth.users (id) on delete cascade,
    display_name text,
    is_admin boolean not null default false,
    created_at timestamptz not null default now()
);

alter table public.profiles enable row level security;

create policy "profiles are readable by everyone"
    on public.profiles for select using (true);

create or replace function public.handle_new_user()
returns trigger
language plpgsql
security definer set search_path = public
as $$
begin
    insert into public.profiles (id, display_name)
    values (
        new.id,
        coalesce(
            new.raw_user_meta_data ->> 'username',
            split_part(coalesce(new.email, ''), '@', 1)
        )
    )
    on conflict (id) do nothing;
    return new;
end;
$$;

drop trigger if exists on_auth_user_created on auth.users;
create trigger on_auth_user_created
    after insert on auth.users
    for each row execute function public.handle_new_user();

-- MARK: - Make an account an admin
--
-- 1. Find your auth user id:
--      select id, email from auth.users;
-- 2. Then flag yourself admin (run once):
--      update public.profiles set is_admin = true where id = '<your-user-uuid>';
--
-- The app re-fetches is_admin at every sign-in, so sign out and back
-- in (or relaunch) after making this change.

-- MARK: - Security notes
--
-- The bars/prices policies above are intentionally permissive so
-- everyone can read and add content, and admins can delete anything
-- (the app only shows delete UI to owners/admins). The app now sends
-- the real auth user id in created_by / reported_by, so tightening
-- is a one-step change:
--
--   drop policy "anyone can insert bars" on public.bars;
--   create policy "authenticated users can insert bars"
--       on public.bars for insert
--       with check (auth.uid() = created_by);
--
--   drop policy "bars can be deleted" on public.bars;
--   create policy "owners or admins can delete bars"
--       on public.bars for delete
--       using (created_by = auth.uid() or
--              exists (select 1 from public.profiles
--                      where id = auth.uid() and is_admin));
--
-- Apply the same idea to prices (reported_by / is_admin) and update
-- the individual price policies the same way.