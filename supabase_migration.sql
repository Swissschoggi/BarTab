-- =============================================================
-- BarTab — consolidated Supabase migration
-- Run in Supabase SQL editor (idempotent: uses IF NOT EXISTS / OR REPLACE)
-- =============================================================

-- ─────────────────────────────────────────────────────────────
-- 1. Alter bar_ratings.ambience from smallint → text (multi-select)
-- ─────────────────────────────────────────────────────────────
-- The old schema stored ambience as a single smallint (1–5).
-- The app now stores a comma-separated list of AmbienceStyle raw values.
DO $$
BEGIN
    IF EXISTS (
        SELECT 1 FROM information_schema.columns
        WHERE table_name = 'bar_ratings' AND column_name = 'ambience'
        AND data_type = 'smallint'
    ) THEN
        -- Migrate existing single values to comma-separated strings
        ALTER TABLE bar_ratings
            ALTER COLUMN ambience TYPE text
            USING CASE ambience
                WHEN 1 THEN 'cozy'
                WHEN 2 THEN 'modern'
                WHEN 3 THEN 'elegant'
                WHEN 4 THEN 'casual'
                WHEN 5 THEN 'lively'
                ELSE NULL
            END;
        ALTER TABLE bar_ratings DROP CONSTRAINT IF EXISTS bar_ratings_ambience_check;
    END IF;
END $$;

-- ─────────────────────────────────────────────────────────────
-- 2. Content reports table
-- ─────────────────────────────────────────────────────────────
CREATE TABLE IF NOT EXISTS content_reports (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    target_id TEXT NOT NULL,
    target_type TEXT NOT NULL CHECK (target_type IN ('bar', 'price')),
    target_label TEXT NOT NULL DEFAULT '',
    reason TEXT NOT NULL,
    reported_by UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
    reported_by_name TEXT NOT NULL DEFAULT '',
    reported_at TIMESTAMPTZ NOT NULL DEFAULT now(),
    is_reviewed BOOLEAN NOT NULL DEFAULT false,
    reviewed_at TIMESTAMPTZ
);

-- ─────────────────────────────────────────────────────────────
-- 3. Content reports RLS
-- ─────────────────────────────────────────────────────────────
ALTER TABLE content_reports ENABLE ROW LEVEL SECURITY;

CREATE POLICY "Authenticated users can read all reports"
    ON content_reports FOR SELECT
    USING (auth.role() = 'authenticated');

CREATE POLICY "Authenticated users can insert reports"
    ON content_reports FOR INSERT
    WITH CHECK (auth.uid() = reported_by);

CREATE POLICY "Admins can update reports"
    ON content_reports FOR UPDATE
    USING (
        EXISTS (
            SELECT 1 FROM profiles
            WHERE profiles.id = auth.uid() AND profiles.is_admin = true
        )
    );

CREATE POLICY "Admins can delete reports"
    ON content_reports FOR DELETE
    USING (
        EXISTS (
            SELECT 1 FROM profiles
            WHERE profiles.id = auth.uid() AND profiles.is_admin = true
        )
    );

-- ─────────────────────────────────────────────────────────────
-- 4. RLS for existing tables (enable if not already)
-- ─────────────────────────────────────────────────────────────
DO $$
BEGIN
    -- bars
    IF NOT EXISTS (SELECT 1 FROM pg_policies WHERE tablename = 'bars' AND policyname = 'Authenticated users can read bars') THEN
        ALTER TABLE bars ENABLE ROW LEVEL SECURITY;
        CREATE POLICY "Authenticated users can read bars"
            ON bars FOR SELECT USING (auth.role() = 'authenticated');
        CREATE POLICY "Authenticated users can insert bars"
            ON bars FOR INSERT WITH CHECK (auth.uid() = created_by);
        CREATE POLICY "Owner can update own bars"
            ON bars FOR UPDATE USING (auth.uid() = created_by);
        CREATE POLICY "Owner or admin can delete bars"
            ON bars FOR DELETE USING (
                auth.uid() = created_by OR
                EXISTS (SELECT 1 FROM profiles WHERE profiles.id = auth.uid() AND profiles.is_admin = true)
            );
    END IF;

    -- prices
    IF NOT EXISTS (SELECT 1 FROM pg_policies WHERE tablename = 'prices' AND policyname = 'Authenticated users can read prices') THEN
        ALTER TABLE prices ENABLE ROW LEVEL SECURITY;
        CREATE POLICY "Authenticated users can read prices"
            ON prices FOR SELECT USING (auth.role() = 'authenticated');
        CREATE POLICY "Authenticated users can insert prices"
            ON prices FOR INSERT WITH CHECK (auth.uid() = reported_by);
        CREATE POLICY "Owner can update own prices"
            ON prices FOR UPDATE USING (auth.uid() = reported_by);
        CREATE POLICY "Owner or admin can delete prices"
            ON prices FOR DELETE USING (
                auth.uid() = reported_by OR
                EXISTS (SELECT 1 FROM profiles WHERE profiles.id = auth.uid() AND profiles.is_admin = true)
            );
    END IF;

    -- bar_ratings
    IF NOT EXISTS (SELECT 1 FROM pg_policies WHERE tablename = 'bar_ratings' AND policyname = 'Authenticated users can read bar ratings') THEN
        ALTER TABLE bar_ratings ENABLE ROW LEVEL SECURITY;
        CREATE POLICY "Authenticated users can read bar ratings"
            ON bar_ratings FOR SELECT USING (auth.role() = 'authenticated');
        CREATE POLICY "Authenticated users can insert bar ratings"
            ON bar_ratings FOR INSERT WITH CHECK (auth.uid() = rated_by);
        CREATE POLICY "Owner can update own bar ratings"
            ON bar_ratings FOR UPDATE USING (auth.uid() = rated_by);
        CREATE POLICY "Owner can delete own bar ratings"
            ON bar_ratings FOR DELETE USING (auth.uid() = rated_by);
    END IF;

    -- drink_ratings
    IF NOT EXISTS (SELECT 1 FROM pg_policies WHERE tablename = 'drink_ratings' AND policyname = 'Authenticated users can read drink ratings') THEN
        ALTER TABLE drink_ratings ENABLE ROW LEVEL SECURITY;
        CREATE POLICY "Authenticated users can read drink ratings"
            ON drink_ratings FOR SELECT USING (auth.role() = 'authenticated');
        CREATE POLICY "Authenticated users can insert drink ratings"
            ON drink_ratings FOR INSERT WITH CHECK (auth.uid() = rated_by);
        CREATE POLICY "Owner can update own drink ratings"
            ON drink_ratings FOR UPDATE USING (auth.uid() = rated_by);
        CREATE POLICY "Owner can delete own drink ratings"
            ON drink_ratings FOR DELETE USING (auth.uid() = rated_by);
    END IF;

    -- drink_brands
    IF NOT EXISTS (SELECT 1 FROM pg_policies WHERE tablename = 'drink_brands' AND policyname = 'Authenticated users can read drink brands') THEN
        ALTER TABLE drink_brands ENABLE ROW LEVEL SECURITY;
        CREATE POLICY "Authenticated users can read drink brands"
            ON drink_brands FOR SELECT USING (auth.role() = 'authenticated');
        CREATE POLICY "Authenticated users can insert drink brands"
            ON drink_brands FOR INSERT WITH CHECK (true);
    END IF;

    -- brand_requests
    IF NOT EXISTS (SELECT 1 FROM pg_policies WHERE tablename = 'brand_requests' AND policyname = 'Authenticated users can read brand requests') THEN
        ALTER TABLE brand_requests ENABLE ROW LEVEL SECURITY;
        CREATE POLICY "Authenticated users can read brand requests"
            ON brand_requests FOR SELECT USING (auth.role() = 'authenticated');
        CREATE POLICY "Authenticated users can insert brand requests"
            ON brand_requests FOR INSERT WITH CHECK (auth.uid() = requested_by);
    END IF;

    -- profiles
    IF NOT EXISTS (SELECT 1 FROM pg_policies WHERE tablename = 'profiles' AND policyname = 'Authenticated users can read profiles') THEN
        ALTER TABLE profiles ENABLE ROW LEVEL SECURITY;
        CREATE POLICY "Authenticated users can read profiles"
            ON profiles FOR SELECT USING (auth.role() = 'authenticated');
        CREATE POLICY "Owner can update own profile"
            ON profiles FOR UPDATE USING (auth.uid() = id);
        CREATE POLICY "System can insert profiles"
            ON profiles FOR INSERT WITH CHECK (true);
    END IF;
END $$;

-- ─────────────────────────────────────────────────────────────
-- 4b. Auto-create profile row on signup
-- ─────────────────────────────────────────────────────────────
CREATE OR REPLACE FUNCTION handle_new_user()
RETURNS trigger AS $$
BEGIN
    INSERT INTO public.profiles (id, display_name)
    VALUES (
        NEW.id,
        COALESCE(NEW.raw_user_meta_data ->> 'username', split_part(NEW.email, '@', 1))
    )
    ON CONFLICT (id) DO NOTHING;
    RETURN NEW;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

DROP TRIGGER IF EXISTS on_auth_user_created ON auth.users;
CREATE TRIGGER on_auth_user_created
    AFTER INSERT ON auth.users
    FOR EACH ROW
    EXECUTE FUNCTION handle_new_user();

-- ─────────────────────────────────────────────────────────────
-- 5. Indexes
-- ─────────────────────────────────────────────────────────────
CREATE INDEX IF NOT EXISTS idx_prices_bar_id ON prices(bar_id);
CREATE INDEX IF NOT EXISTS idx_prices_drink ON prices(drink);
CREATE INDEX IF NOT EXISTS idx_drink_ratings_bar_id ON drink_ratings(bar_id);
CREATE INDEX IF NOT EXISTS idx_drink_ratings_product ON drink_ratings(bar_id, drink, brand, size);
CREATE INDEX IF NOT EXISTS idx_bar_ratings_bar_id ON bar_ratings(bar_id);
CREATE INDEX IF NOT EXISTS idx_content_reports_target ON content_reports(target_id, target_type);
CREATE INDEX IF NOT EXISTS idx_bars_location ON bars(latitude, longitude);

-- ─────────────────────────────────────────────────────────────
-- 6. Views
-- ─────────────────────────────────────────────────────────────

-- Average quality per drink product at a bar
CREATE OR REPLACE VIEW drink_rating_averages AS
SELECT
    bar_id,
    drink,
    brand,
    size,
    ROUND(AVG(quality)::numeric, 1) AS average_quality,
    COUNT(*) AS rating_count
FROM drink_ratings
GROUP BY bar_id, drink, brand, size;

-- Public leaderboard (privacy-safe: username + level only)
CREATE OR REPLACE VIEW public_leaderboard AS
SELECT
    u.id AS user_id,
    COALESCE(
        (SELECT display_name FROM profiles WHERE profiles.id = u.id),
        'User ' || LEFT(u.id::text, 6)
    ) AS username,
    (
        (SELECT COUNT(*) FROM prices WHERE reported_by = u.id)
      + (SELECT COUNT(*) FROM bars WHERE created_by = u.id)
    ) AS contributions
FROM auth.users u
HAVING (
    (SELECT COUNT(*) FROM prices WHERE reported_by = u.id)
  + (SELECT COUNT(*) FROM bars WHERE created_by = u.id)
) > 0
ORDER BY contributions DESC;
