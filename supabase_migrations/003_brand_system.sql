-- BarTab: brand system migration
-- Run this in Supabase Dashboard -> SQL Editor.
-- Adds a shared brand catalog (`drink_brands`) and a review
-- queue for user-submitted brand suggestions (`brand_requests`).

-- 1. Brand catalog
create table if not exists public.drink_brands (
    id uuid primary key default gen_random_uuid(),
    drink text not null,
    name text not null,
    created_at timestamptz not null default now(),

    constraint drink_brands_drink_name_key unique (drink, name)
);

create index if not exists drink_brands_drink_idx
    on public.drink_brands (drink);

alter table public.drink_brands enable row level security;

create policy if not exists "drink_brands are readable by everyone"
    on public.drink_brands for select
    using (true);

-- Inserts only ever happen through the app's approval flow
-- (service-role-equivalent: any signed-in user, since approval is
-- gated client-side by isAdmin). Tighten this to a server-side
-- function/role if you want it enforced at the database level too.
create policy if not exists "signed in users can add approved brands"
    on public.drink_brands for insert
    with check (auth.uid() is not null);

-- Seed with the same defaults bundled in the app
-- (DrinkBrand.all in DrinkBrands.swift), so the server-side
-- catalog matches what ships in the app from day one.
insert into public.drink_brands (drink, name) values
    ('beer', 'Feldschlösschen'),
    ('beer', 'Calanda'),
    ('beer', 'Quöllfrisch'),
    ('beer', 'Cardinal'),
    ('beer', 'Appenzeller'),
    ('beer', 'Heineken'),
    ('beer', 'Corona'),
    ('beer', 'Guinness'),
    ('wine', 'Féchy'),
    ('wine', 'Epesses'),
    ('wine', 'Pinot Noir'),
    ('wine', 'Merlot'),
    ('wine', 'Chardonnay'),
    ('wine', 'Sauvignon Blanc'),
    ('cocktail', 'Mojito'),
    ('cocktail', 'Negroni'),
    ('cocktail', 'Old Fashioned'),
    ('cocktail', 'Margarita'),
    ('cocktail', 'Aperol Spritz'),
    ('cocktail', 'Gin Tonic'),
    ('cocktail', 'Moscow Mule'),
    ('cocktail', 'Espresso Martini'),
    ('shot', 'Jägermeister'),
    ('shot', 'Tequila'),
    ('shot', 'Vodka'),
    ('shot', 'Grappa'),
    ('shot', 'Underberg'),
    ('softDrink', 'Coca-Cola'),
    ('softDrink', 'Rivella'),
    ('softDrink', 'Red Bull'),
    ('softDrink', 'Fanta'),
    ('softDrink', 'Sprite'),
    ('softDrink', 'Ramseier'),
    ('coffee', 'Espresso'),
    ('coffee', 'Cappuccino'),
    ('coffee', 'Latte Macchiato'),
    ('coffee', 'Café Crème'),
    ('coffee', 'Ristretto')
on conflict (drink, name) do nothing;

-- 2. Brand requests (review queue)
create table if not exists public.brand_requests (
    id uuid primary key default gen_random_uuid(),
    drink text not null,
    name text not null,
    requested_by uuid not null references auth.users(id) on delete cascade,
    requested_by_name text not null,
    status text not null default 'pending'
        check (status in ('pending', 'approved', 'rejected')),
    created_at timestamptz not null default now()
);

create index if not exists brand_requests_status_idx
    on public.brand_requests (status);

alter table public.brand_requests enable row level security;

-- Readable by everyone so the app can locally dedupe "already
-- requested" — tighten to admin-only + own rows if you'd rather
-- requesters not see each other's suggestions.
create policy if not exists "brand_requests are readable by everyone"
    on public.brand_requests for select
    using (true);

create policy if not exists "users can submit their own brand request"
    on public.brand_requests for insert
    with check (auth.uid() = requested_by);

-- Status updates (approve/reject) are gated client-side by
-- isAdmin today, same as your existing report-review flow.
-- Tighten this with a role check once you have one in the DB.
create policy if not exists "signed in users can update brand request status"
    on public.brand_requests for update
    using (auth.uid() is not null)
    with check (auth.uid() is not null);
