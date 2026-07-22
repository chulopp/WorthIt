-- Migration: 20260722_add_pgvector_substitutions.sql
-- Purpose: Enable pgvector, add embedding column to products table, create index, and add RPC match_products_by_embedding function.

-- 1. Enable pgvector extension
CREATE EXTENSION IF NOT EXISTS vector;

-- 2. Add embedding column to products table (384 dimensions for sentence-transformers paraphrase-multilingual-MiniLM-L12-v2)
ALTER TABLE products ADD COLUMN IF NOT EXISTS embedding vector(384);

-- 3. Create HNSW index for fast similarity search
CREATE INDEX IF NOT EXISTS idx_products_embedding ON products USING hnsw (embedding vector_cosine_ops);

-- 4. RPC stored function for cosine similarity search
CREATE OR REPLACE FUNCTION match_products_by_embedding (
  query_embedding vector(384),
  match_threshold float,
  match_count int,
  filter_category text DEFAULT NULL,
  exclude_id uuid DEFAULT NULL
)
RETURNS TABLE (
  id uuid,
  name text,
  brand text,
  category text,
  base_weight_gram numeric,
  unit_label text,
  image_url text,
  similarity float
)
LANGUAGE plpgsql
AS $$
BEGIN
  RETURN QUERY
  SELECT
    p.id,
    p.name,
    p.brand,
    p.category,
    p.base_weight_gram,
    p.unit_label,
    p.image_url,
    (1 - (p.embedding <=> query_embedding))::float AS similarity
  FROM products p
  WHERE p.embedding IS NOT NULL
    AND (exclude_id IS NULL OR p.id != exclude_id)
    AND (filter_category IS NULL OR p.category = filter_category)
    AND (1 - (p.embedding <=> query_embedding)) >= match_threshold
  ORDER BY p.embedding <=> query_embedding
  LIMIT match_count;
END;
$$;
