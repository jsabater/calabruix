-- city.sql
-- Taula de ciutats amb coordenades PostGIS

CREATE EXTENSION IF NOT EXISTS postgis;

CREATE TABLE IF NOT EXISTS city (
  id SERIAL PRIMARY KEY,
  name TEXT NOT NULL,
  location GEOMETRY(POINT, 4326) NOT NULL
);

INSERT INTO city (id, name, location)
VALUES
  (1, 'Barcelona', ST_GeomFromText('POINT(2.17340 41.38879)', 4326)),
  (2, 'València', ST_GeomFromText('POINT(-0.37739 39.46975)', 4326)),
  (3, 'Sevilla', ST_GeomFromText('POINT(-5.98376 37.38296)', 4326)),
  (4, 'Palma', ST_GeomFromText('POINT(2.65024 39.56975)', 4326)),
  (5, 'Maó', ST_GeomFromText('POINT(4.26317 39.88960)', 4326)),
  (6, 'Ciutadella', ST_GeomFromText('POINT(3.83679 40.00084)', 4326)),
  (7, 'Eivissa', ST_GeomFromText('POINT(1.43296 38.90883)', 4326))
ON CONFLICT (id) DO UPDATE SET name = EXCLUDED.name;

