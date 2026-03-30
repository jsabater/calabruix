-- student.sql
-- Taula d'estudiants amb assignació a una ciutat

CREATE TABLE IF NOT EXISTS student (
  id SERIAL PRIMARY KEY,
  name VARCHAR(50) NOT NULL,
  city_id INT REFERENCES city(id)
);

INSERT INTO student (id, name, city_id)
VALUES
  (1, 'Alice', 4),      -- Palma
  (2, 'Bob', 1),        -- Barcelona
  (3, 'Charlie', 4),    -- Palma
  (4, 'David', 2),      -- València
  (5, 'Elisabeth', 1),  -- Barcelona
  (6, 'Ferdinand', 3),  -- Sevilla
  (7, 'Enola', 7)       -- Eivissa
ON CONFLICT (id) DO NOTHING;

