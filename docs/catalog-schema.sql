-- Canonical catalog: sports-today-device-feed's val-scoped SQLite.
-- Explicit migration, never executed as a module import or per-request initializer.
-- Existing assignment slugs and normalized Game.sport values remain unchanged.
PRAGMA foreign_keys = ON;
BEGIN IMMEDIATE;

CREATE TABLE IF NOT EXISTS catalog_competitions (
  code TEXT PRIMARY KEY NOT NULL CHECK (length(trim(code)) > 0),
  display_name TEXT NOT NULL CHECK (length(trim(display_name)) > 0),
  adapter TEXT NOT NULL CHECK (adapter IN ('sleeper', 'fiba')),
  provider_competition_key TEXT NOT NULL CHECK (length(trim(provider_competition_key)) > 0),
  display_order INTEGER NOT NULL CHECK (typeof(display_order) = 'integer' AND display_order >= 0),
  emoji TEXT NOT NULL DEFAULT '',
  coverage_note TEXT NOT NULL,
  UNIQUE (adapter, provider_competition_key)
);

-- A row is a selectable team within one competition, not a global franchise.
-- The stable slug is the identifier already stored in assignment settings.
CREATE TABLE IF NOT EXISTS catalog_teams (
  slug TEXT PRIMARY KEY NOT NULL CHECK (
    length(slug) > 0 AND slug = lower(slug)
    AND slug NOT GLOB '*[^a-z0-9-]*'
  ),
  competition_code TEXT NOT NULL REFERENCES catalog_competitions(code) ON DELETE RESTRICT,
  display_name TEXT NOT NULL CHECK (length(trim(display_name)) > 0),
  provider_team_code TEXT NOT NULL CHECK (length(trim(provider_team_code)) > 0),
  display_order INTEGER NOT NULL CHECK (typeof(display_order) = 'integer' AND display_order >= 0),
  UNIQUE (competition_code, provider_team_code)
);

CREATE INDEX IF NOT EXISTS ix_catalog_teams_display
  ON catalog_teams(competition_code, display_order, slug);

-- Repeatable seed: only missing primary keys are inserted. Operator edits survive.
-- Other constraint violations still fail; do not use broad INSERT OR IGNORE.
INSERT INTO catalog_competitions
  (code, display_name, adapter, provider_competition_key, display_order, emoji, coverage_note)
VALUES
  ('nfl', 'NFL', 'sleeper', 'nfl', 0, '🏈', 'All 32 NFL teams in the existing catalog.'),
  ('cfb', 'CFB', 'sleeper', 'cfb', 1, '🏈', 'Curated selection: USC Trojans and UCLA Bruins; not a complete college football roster.'),
  ('wnba', 'WNBA', 'sleeper', 'wnba', 2, '🏀', 'All 15 teams in the existing 2026 catalog.'),
  ('nba', 'NBA', 'sleeper', 'nba', 3, '🏀', 'Curated selection: Lakers and Warriors; not a complete NBA roster.'),
  ('fiba', 'FIBA', 'fiba', 'fiba', 4, '🏀', '2026 FIBA Women''s Basketball World Cup group-stage roster only. ESPN''s fiba bucket can change tournament and gender between cycles; revalidate before reuse.')
ON CONFLICT(code) DO NOTHING;

INSERT INTO catalog_teams
  (slug, competition_code, display_name, provider_team_code, display_order)
VALUES
  ('dream', 'wnba', 'Dream', 'ATL', 0),
  ('sky', 'wnba', 'Sky', 'CHI', 1),
  ('sun', 'wnba', 'Sun', 'CON', 2),
  ('wings', 'wnba', 'Wings', 'DAL', 3),
  ('valkyries', 'wnba', 'Valkyries', 'GSV', 4),
  ('fever', 'wnba', 'Fever', 'IND', 5),
  ('sparks', 'wnba', 'Sparks', 'LAS', 6),
  ('aces', 'wnba', 'Aces', 'LVA', 7),
  ('lynx', 'wnba', 'Lynx', 'MIN', 8),
  ('liberty', 'wnba', 'Liberty', 'NYL', 9),
  ('fire', 'wnba', 'Fire', 'PDX', 10),
  ('mercury', 'wnba', 'Mercury', 'PHO', 11),
  ('storm', 'wnba', 'Storm', 'SEA', 12),
  ('tempo', 'wnba', 'Tempo', 'TOR', 13),
  ('mystics', 'wnba', 'Mystics', 'WAS', 14),
  ('cardinals', 'nfl', 'Cardinals', 'ARI', 0),
  ('falcons', 'nfl', 'Falcons', 'ATL', 1),
  ('ravens', 'nfl', 'Ravens', 'BAL', 2),
  ('bills', 'nfl', 'Bills', 'BUF', 3),
  ('panthers', 'nfl', 'Panthers', 'CAR', 4),
  ('bears', 'nfl', 'Bears', 'CHI', 5),
  ('bengals', 'nfl', 'Bengals', 'CIN', 6),
  ('browns', 'nfl', 'Browns', 'CLE', 7),
  ('cowboys', 'nfl', 'Cowboys', 'DAL', 8),
  ('broncos', 'nfl', 'Broncos', 'DEN', 9),
  ('lions', 'nfl', 'Lions', 'DET', 10),
  ('packers', 'nfl', 'Packers', 'GB', 11),
  ('texans', 'nfl', 'Texans', 'HOU', 12),
  ('colts', 'nfl', 'Colts', 'IND', 13),
  ('jaguars', 'nfl', 'Jaguars', 'JAX', 14),
  ('chiefs', 'nfl', 'Chiefs', 'KC', 15),
  ('chargers', 'nfl', 'Chargers', 'LAC', 16),
  ('rams', 'nfl', 'Rams', 'LAR', 17),
  ('raiders', 'nfl', 'Raiders', 'LV', 18),
  ('dolphins', 'nfl', 'Dolphins', 'MIA', 19),
  ('vikings', 'nfl', 'Vikings', 'MIN', 20),
  ('patriots', 'nfl', 'Patriots', 'NE', 21),
  ('saints', 'nfl', 'Saints', 'NO', 22),
  ('giants', 'nfl', 'Giants', 'NYG', 23),
  ('jets', 'nfl', 'Jets', 'NYJ', 24),
  ('eagles', 'nfl', 'Eagles', 'PHI', 25),
  ('steelers', 'nfl', 'Steelers', 'PIT', 26),
  ('seahawks', 'nfl', 'Seahawks', 'SEA', 27),
  ('49ers', 'nfl', '49ers', 'SF', 28),
  ('buccaneers', 'nfl', 'Buccaneers', 'TB', 29),
  ('titans', 'nfl', 'Titans', 'TEN', 30),
  ('commanders', 'nfl', 'Commanders', 'WAS', 31),
  ('trojans', 'cfb', 'Trojans', 'USC', 0),
  ('bruins', 'cfb', 'Bruins', 'UCLA', 1),
  ('lakers', 'nba', 'Lakers', 'LAL', 0),
  ('warriors', 'nba', 'Warriors', 'GSW', 1),
  ('australia', 'fiba', 'Australia', 'AUS', 0),
  ('belgium', 'fiba', 'Belgium', 'BEL', 1),
  ('china', 'fiba', 'China', 'CHN', 2),
  ('czechia', 'fiba', 'Czechia', 'CZE', 3),
  ('spain', 'fiba', 'Spain', 'ESP', 4),
  ('france', 'fiba', 'France', 'FRA', 5),
  ('germany', 'fiba', 'Germany', 'GER', 6),
  ('hungary', 'fiba', 'Hungary', 'HUN', 7),
  ('italy', 'fiba', 'Italy', 'ITA', 8),
  ('japan', 'fiba', 'Japan', 'JPN', 9),
  ('south-korea', 'fiba', 'South Korea', 'KOR', 10),
  ('mali', 'fiba', 'Mali', 'MLI', 11),
  ('nigeria', 'fiba', 'Nigeria', 'NGR', 12),
  ('puerto-rico', 'fiba', 'Puerto Rico', 'PUR', 13),
  ('turkey', 'fiba', 'Turkey', 'TUR', 14),
  ('united-states', 'fiba', 'United States', 'USA', 15)
ON CONFLICT(slug) DO NOTHING;

COMMIT;

