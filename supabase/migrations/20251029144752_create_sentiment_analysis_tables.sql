/*
  # Create Sentiment Analysis Platform Schema

  1. New Tables
    - `users`
      - `id` (uuid, primary key) - User identifier
      - `email` (text, unique) - User email
      - `created_at` (timestamptz) - Account creation timestamp
      - `subscription_tier` (text) - User subscription level (free, pro, enterprise)
      - `api_calls_remaining` (integer) - Remaining API calls for current period
    
    - `sentiment_analyses`
      - `id` (uuid, primary key) - Analysis identifier
      - `user_id` (uuid, foreign key) - Owner of the analysis
      - `text_content` (text) - Original text analyzed
      - `sentiment_score` (numeric) - Sentiment score (-1 to 1)
      - `sentiment_label` (text) - Sentiment classification (positive, negative, neutral)
      - `confidence` (numeric) - Confidence score (0 to 1)
      - `created_at` (timestamptz) - Analysis timestamp
      - `metadata` (jsonb) - Additional analysis data
    
    - `payments`
      - `id` (uuid, primary key) - Payment identifier
      - `user_id` (uuid, foreign key) - User who made payment
      - `amount` (numeric) - Payment amount
      - `currency` (text) - Payment currency
      - `status` (text) - Payment status (pending, completed, failed)
      - `stripe_payment_id` (text) - Stripe payment reference
      - `subscription_tier` (text) - Tier purchased
      - `created_at` (timestamptz) - Payment timestamp

  2. Security
    - Enable RLS on all tables
    - Users can only read/write their own data
    - Authenticated users only access
*/

-- Create users table
CREATE TABLE IF NOT EXISTS users (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  email text UNIQUE NOT NULL,
  created_at timestamptz DEFAULT now(),
  subscription_tier text DEFAULT 'free',
  api_calls_remaining integer DEFAULT 10
);

ALTER TABLE users ENABLE ROW LEVEL SECURITY;

CREATE POLICY "Users can view own profile"
  ON users FOR SELECT
  TO authenticated
  USING (auth.uid() = id);

CREATE POLICY "Users can update own profile"
  ON users FOR UPDATE
  TO authenticated
  USING (auth.uid() = id)
  WITH CHECK (auth.uid() = id);

-- Create sentiment_analyses table
CREATE TABLE IF NOT EXISTS sentiment_analyses (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id uuid REFERENCES users(id) ON DELETE CASCADE,
  text_content text NOT NULL,
  sentiment_score numeric NOT NULL,
  sentiment_label text NOT NULL,
  confidence numeric NOT NULL,
  created_at timestamptz DEFAULT now(),
  metadata jsonb DEFAULT '{}'::jsonb
);

ALTER TABLE sentiment_analyses ENABLE ROW LEVEL SECURITY;

CREATE POLICY "Users can view own analyses"
  ON sentiment_analyses FOR SELECT
  TO authenticated
  USING (auth.uid() = user_id);

CREATE POLICY "Users can create own analyses"
  ON sentiment_analyses FOR INSERT
  TO authenticated
  WITH CHECK (auth.uid() = user_id);

CREATE POLICY "Users can delete own analyses"
  ON sentiment_analyses FOR DELETE
  TO authenticated
  USING (auth.uid() = user_id);

-- Create payments table
CREATE TABLE IF NOT EXISTS payments (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id uuid REFERENCES users(id) ON DELETE CASCADE,
  amount numeric NOT NULL,
  currency text DEFAULT 'usd',
  status text DEFAULT 'pending',
  stripe_payment_id text,
  subscription_tier text NOT NULL,
  created_at timestamptz DEFAULT now()
);

ALTER TABLE payments ENABLE ROW LEVEL SECURITY;

CREATE POLICY "Users can view own payments"
  ON payments FOR SELECT
  TO authenticated
  USING (auth.uid() = user_id);

CREATE POLICY "Users can create own payments"
  ON payments FOR INSERT
  TO authenticated
  WITH CHECK (auth.uid() = user_id);

-- Create indexes for better performance
CREATE INDEX IF NOT EXISTS idx_sentiment_analyses_user_id ON sentiment_analyses(user_id);
CREATE INDEX IF NOT EXISTS idx_sentiment_analyses_created_at ON sentiment_analyses(created_at DESC);
CREATE INDEX IF NOT EXISTS idx_payments_user_id ON payments(user_id);
CREATE INDEX IF NOT EXISTS idx_payments_created_at ON payments(created_at DESC);