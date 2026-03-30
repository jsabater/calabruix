CREATE TABLE IF NOT EXISTS student (id SERIAL PRIMARY KEY, name VARCHAR(50));
INSERT INTO student (id, name)
VALUES (1, 'Alice'), (2, 'Bob'), (3, 'Charlie'), (4, 'David'), (5, 'Elisabeth'), (6, 'Ferdinand')
ON CONFLICT (id) DO NOTHING;
