CREATE EXTENSION IF NOT EXISTS postgis;
CREATE TABLE IF NOT EXISTS city (
  id SERIAL PRIMARY KEY,
  name TEXT NOT NULL,
  location GEOMETRY(POINT, 4326) NOT NULL
);
INSERT INTO city (name, location)
VALUES
  ('Barcelona', ST_GeomFromText('POINT(2.17340 41.38879)', 4326)),
  ('València', ST_GeomFromText('POINT(-0.37739 39.46975)', 4326)),
  ('Sevilla', ST_GeomFromText('POINT(-5.98376 37.38296)', 4326)),
  ('Palma', ST_GeomFromText('POINT(2.65024 39.56975)', 4326)),
  ('Maó', ST_GeomFromText('POINT(1.49675 39.65029)', 4326)),
  ('Ciutadella', ST_GeomFromText('POINT(4.00649 39.99439)', 4326)),
  ('Eivissa', ST_GeomFromText('POINT(1.44216 38.90629)', 4326))
ON CONFLICT (id) DO UPDATE SET name = EXCLUDED.name;
