-- 003_categories.sql
-- Categories (fixed list), keyword dictionary and budget, plus seed rows.
-- Safe to re-run: IF NOT EXISTS and ON CONFLICT DO NOTHING.
-- Keywords are lowercase ASCII: the clean step must lowercase and fold umlauts (ae, oe, ue, ss).

BEGIN;

-- Fixed list. Nothing may invent a category that is not in this table.
CREATE TABLE IF NOT EXISTS ctl.category (
  category    text PRIMARY KEY,
  description text NOT NULL
);

-- Keyword dictionary: a cleaned item name that contains the keyword gets the category.
CREATE TABLE IF NOT EXISTS ctl.category_keyword (
  keyword  text PRIMARY KEY,
  category text NOT NULL REFERENCES ctl.category(category)
);

-- Monthly limit per owner. category = 'ALL' means all categories together.
CREATE TABLE IF NOT EXISTS ctl.budget (
  owner_id      text NOT NULL,
  category      text NOT NULL,
  monthly_limit numeric(10,2) NOT NULL CHECK (monthly_limit >= 0),
  currency      char(3) NOT NULL DEFAULT 'EUR',
  PRIMARY KEY (owner_id, category)
);

-- Seed: categories
INSERT INTO ctl.category (category, description) VALUES
  ('MEAT',             'Meat and sausage'),
  ('JUNKFOOD',         'Sweets, snacks, soft drinks, fast food'),
  ('VEGGY AND FRUIT',  'Vegetables and fruit'),
  ('SOAP AND SHAMPOO', 'Body care: soap, shampoo, toothpaste'),
  ('MEDICAMENTER',     'Medicine and pharmacy items'),
  ('LAUNDRY',          'Detergent and laundry items'),
  ('OTHER',            'Everything that fits no other category')
ON CONFLICT (category) DO NOTHING;

-- Seed: keyword dictionary (starter list, German receipt words)
INSERT INTO ctl.category_keyword (keyword, category) VALUES
  ('haehnchen', 'MEAT'), ('hackfleisch', 'MEAT'), ('rind', 'MEAT'), ('schwein', 'MEAT'),
  ('schnitzel', 'MEAT'), ('wurst', 'MEAT'), ('salami', 'MEAT'), ('schinken', 'MEAT'),
  ('pute', 'MEAT'), ('steak', 'MEAT'),

  ('chips', 'JUNKFOOD'), ('schoko', 'JUNKFOOD'), ('haribo', 'JUNKFOOD'), ('keks', 'JUNKFOOD'),
  ('cola', 'JUNKFOOD'), ('limo', 'JUNKFOOD'), ('pizza', 'JUNKFOOD'), ('pommes', 'JUNKFOOD'),
  ('bonbon', 'JUNKFOOD'), ('nutella', 'JUNKFOOD'),

  ('tomate', 'VEGGY AND FRUIT'), ('gurke', 'VEGGY AND FRUIT'), ('paprika', 'VEGGY AND FRUIT'),
  ('salat', 'VEGGY AND FRUIT'), ('zwiebel', 'VEGGY AND FRUIT'), ('kartoffel', 'VEGGY AND FRUIT'),
  ('moehre', 'VEGGY AND FRUIT'), ('apfel', 'VEGGY AND FRUIT'), ('banane', 'VEGGY AND FRUIT'),
  ('orange', 'VEGGY AND FRUIT'), ('zitrone', 'VEGGY AND FRUIT'), ('traube', 'VEGGY AND FRUIT'),
  ('beere', 'VEGGY AND FRUIT'), ('brokkoli', 'VEGGY AND FRUIT'), ('champignon', 'VEGGY AND FRUIT'),

  ('seife', 'SOAP AND SHAMPOO'), ('shampoo', 'SOAP AND SHAMPOO'), ('duschgel', 'SOAP AND SHAMPOO'),
  ('spuelung', 'SOAP AND SHAMPOO'), ('zahnpasta', 'SOAP AND SHAMPOO'), ('deo', 'SOAP AND SHAMPOO'),

  ('ibuprofen', 'MEDICAMENTER'), ('paracetamol', 'MEDICAMENTER'), ('aspirin', 'MEDICAMENTER'),
  ('nasenspray', 'MEDICAMENTER'), ('hustensaft', 'MEDICAMENTER'), ('pflaster', 'MEDICAMENTER'),

  ('waschmittel', 'LAUNDRY'), ('weichspueler', 'LAUNDRY'), ('persil', 'LAUNDRY'),
  ('ariel', 'LAUNDRY'), ('fleckenentferner', 'LAUNDRY')
ON CONFLICT (keyword) DO NOTHING;

-- Seed: budget (one overall limit)
INSERT INTO ctl.budget (owner_id, category, monthly_limit, currency) VALUES
  ('me', 'ALL', 1000.00, 'EUR')
ON CONFLICT (owner_id, category) DO NOTHING;

COMMIT;
