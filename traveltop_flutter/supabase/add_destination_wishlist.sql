-- Add destination_id and product_id to wishlists table
ALTER TABLE wishlists ADD COLUMN IF NOT EXISTS destination_id TEXT;
ALTER TABLE wishlists ADD COLUMN IF NOT EXISTS product_id TEXT;
