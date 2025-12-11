-- Migration: Add balance_paise to credits table
-- Version: 1.0.4
-- Supports both page-based and cash-based credits

-- Add balance_paise column for cash-like credits (refunds, promotions)
ALTER TABLE credits ADD COLUMN IF NOT EXISTS balance_paise INTEGER DEFAULT 0;

-- Add updated_at column for tracking credit usage
ALTER TABLE credits ADD COLUMN IF NOT EXISTS updated_at TIMESTAMPTZ DEFAULT NOW();

-- Migrate existing page-based credits to paise (using default pricing)
-- This converts existing credits: pages_bw * 300 paise + pages_color * 1000 paise
UPDATE credits
SET balance_paise = COALESCE(
  (pages_bw - COALESCE(pages_bw_used, 0)) * 300 +
  (pages_color - COALESCE(pages_color_used, 0)) * 1000,
  0
)
WHERE balance_paise = 0 OR balance_paise IS NULL;

-- Add comment for documentation
COMMENT ON COLUMN credits.balance_paise IS 'Remaining credit balance in paise. Can be from page credits (converted) or cash credits (refunds/promos).';
