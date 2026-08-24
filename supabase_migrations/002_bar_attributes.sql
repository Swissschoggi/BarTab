-- BarTab: bar attributes migration
-- Run this in Supabase Dashboard -> SQL Editor.
-- Adds smoking-friendly to `bars`, and a new `bar_ratings` table
-- for crowd-sourced ambience/wine ratings.
--
-- If you already ran an earlier version of this file that added a
-- `languages` column to `bars`, that field was a misunderstanding
-- (it's being replaced by real UI localization instead) — drop it:
--   alter table public.bars drop column if exists languages;

-- 1. New columns on bars
alter table public.bars
    add column if not exists smoking_friendly boolean not null default false;

-- 2. Bar ratings table (one row per bar/user pair; upserted on change)
create table if not exists public.bar_ratings (
    id uuid primary key default gen_random_uuid(),
    bar_id uuid not null references public.bars(id) on delete cascade,
    rated_by uuid not null references auth.users(id) on delete cascade,
    ambience smallint check (ambience between 1 and 5),
    wine_quality smallint check (wine_quality between 1 and 5),
    created_at timestamptz not null default now(),

    constraint bar_ratings_bar_id_rated_by_key unique (bar_id, rated_by),
    constraint bar_ratings_has_a_rating check (
        ambience is not null or wine_quality is not null
    )
);

create index if not exists bar_ratings_bar_id_idx
    on public.bar_ratings (bar_id);

-- 3. Row Level Security
alter table public.bar_ratings enable row level security;

-- Anyone signed in can read ratings (mirrors your existing `bars`/`prices` policies).
create policy if not exists "bar_ratings are readable by everyone"
    on public.bar_ratings for select
    using (true);

-- A user can only insert/update their own rating row.
create policy if not exists "users can upsert their own bar rating"
    on public.bar_ratings for insert
    with check (auth.uid() = rated_by);

create policy if not exists "users can update their own bar rating"
    on public.bar_ratings for update
    using (auth.uid() = rated_by)
    with check (auth.uid() = rated_by);

create policy if not exists "users can delete their own bar rating"
    on public.bar_ratings for delete
    using (auth.uid() = rated_by);
