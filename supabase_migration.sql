-- Supabase migration: Add drink_ratings table and optional price columns
-- Run this in your Supabase SQL editor

-- 1. Add style and serving columns to prices table (optional, backward-compatible)
ALTER TABLE prices ADD COLUMN IF NOT EXISTS style TEXT;
ALTER TABLE prices ADD COLUMN IF NOT EXISTS serving TEXT;

-- 2. Create drink_ratings table for per-product quality ratings
CREATE TABLE IF NOT EXISTS drink_ratings (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    bar_id UUID NOT NULL REFERENCES bars(id) ON DELETE CASCADE,
    drink TEXT NOT NULL,
    brand TEXT,
    size TEXT NOT NULL,
    quality INT NOT NULL CHECK (quality >= 1 AND quality <= 5),
    rated_by UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
    created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
    
    -- One rating per user per drink product per bar
    UNIQUE (bar_id, drink, brand, size, rated_by)
);

-- 3. Enable RLS on drink_ratings
ALTER TABLE drink_ratings ENABLE ROW LEVEL SECURITY;

-- 4. Allow authenticated users to read all drink ratings
CREATE POLICY "Anyone can read drink ratings"
    ON drink_ratings FOR SELECT
    USING (true);

-- 5. Allow authenticated users to insert their own drink ratings
CREATE POLICY "Users can insert their own drink ratings"
    ON drink_ratings FOR INSERT
    WITH CHECK (auth.uid() = rated_by);

-- 6. Allow authenticated users to update their own drink ratings
CREATE POLICY "Users can update their own drink ratings"
    ON drink_ratings FOR UPDATE
    USING (auth.uid() = rated_by);

-- 7. Allow users to delete their own drink ratings
CREATE POLICY "Users can delete their own drink ratings"
    ON drink_ratings FOR DELETE
    USING (auth.uid() = rated_by);

-- 8. Create index for fast lookups by bar
CREATE INDEX IF NOT EXISTS idx_drink_ratings_bar_id ON drink_ratings(bar_id);

-- 9. Create index for fast lookups by drink product
CREATE INDEX IF NOT EXISTS idx_drink_ratings_product ON drink_ratings(bar_id, drink, brand, size);

-- 10. Create view for drink ratings with averages
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
