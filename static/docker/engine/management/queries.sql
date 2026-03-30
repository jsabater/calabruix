-- queries.sql
-- Consultes per generar activitat al servidor PostgreSQL

-- Consulta simple: llistat d'estudiants
SELECT * FROM student ORDER BY name;

-- Consulta amb agregació
SELECT COUNT(*) AS total_cities FROM city;

-- Cerca de les 3 ciutats més properes a Madrid (40.4168, -3.7038)
SELECT name,
       ST_Distance(
         location,
         ST_SetSRID(ST_MakePoint(-3.7038, 40.4168), 4326)
       ) AS distance
FROM city
ORDER BY distance
LIMIT 3;

-- Cerca de les 3 ciutats més properes a París (48.8566, 2.3522)
SELECT name,
       ST_Distance(
         location,
         ST_SetSRID(ST_MakePoint(2.3522, 48.8566), 4326)
       ) AS distance
FROM city
ORDER BY distance
LIMIT 3;

-- Calcular la distància entre totes les parelles de ciutats
SELECT c1.name AS city1,
       c2.name AS city2,
       ST_Distance(c1.location, c2.location) AS distance
FROM city c1
CROSS JOIN city c2
WHERE c1.id < c2.id
ORDER BY distance;

-- Cercar ciutats dins d'un radi de 3 graus des de Palma (39.5697, 2.6502)
SELECT name,
       ST_Distance(
         location,
         ST_SetSRID(ST_MakePoint(2.6502, 39.5697), 4326)
       ) AS distance
FROM city
WHERE ST_DWithin(
  location,
  ST_SetSRID(ST_MakePoint(2.6502, 39.5697), 4326),
  3
)
ORDER BY distance;

-- Consulta amb subconsulta: estudiants i recompte total
SELECT name,
       (SELECT COUNT(*) FROM student) AS total_students
FROM student;

-- Múltiples JOINs simulats amb CROSS JOIN per generar càrrega
SELECT s.name AS student,
       c.name AS city
FROM student s
CROSS JOIN city c
ORDER BY s.name, c.name;
