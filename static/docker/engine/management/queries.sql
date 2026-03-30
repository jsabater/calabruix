-- queries.sql
-- Consultes per generar activitat al servidor PostgreSQL

-- Llistat d'estudiants amb la seva ciutat assignada
SELECT s.name AS student, c.name AS city
FROM student s
JOIN city c ON s.city_id = c.id
ORDER BY s.name;

-- Recompte d'estudiants per ciutat
SELECT c.name AS city, COUNT(s.id) AS total_students
FROM city c
LEFT JOIN student s ON c.id = s.city_id
GROUP BY c.id, c.name
ORDER BY total_students DESC;

-- Ciutats sense cap estudiant assignat
SELECT c.name AS city
FROM city c
LEFT JOIN student s ON c.id = s.city_id
WHERE s.id IS NULL;

-- Distància de cada estudiant a Madrid (40.4168, -3.7038)
SELECT s.name AS student,
       c.name AS city,
       ROUND(ST_Distance(
         c.location::geography,
         ST_SetSRID(ST_MakePoint(-3.7038, 40.4168), 4326)::geography
       ) / 1000) AS km_to_madrid
FROM student s
JOIN city c ON s.city_id = c.id
ORDER BY km_to_madrid;

-- Les 3 ciutats més properes a París (48.8566, 2.3522)
SELECT name,
       ROUND(ST_Distance(
         location::geography,
         ST_SetSRID(ST_MakePoint(2.3522, 48.8566), 4326)::geography
       ) / 1000) AS km_to_paris
FROM city
ORDER BY km_to_paris
LIMIT 3;

-- Distància entre totes les parelles de ciutats (en km)
SELECT c1.name AS city1,
       c2.name AS city2,
       ROUND(ST_Distance(c1.location::geography, c2.location::geography) / 1000) AS km
FROM city c1
CROSS JOIN city c2
WHERE c1.id < c2.id
ORDER BY km;

-- Estudiants a ciutats dins d'un radi de 300 km de Palma
SELECT s.name AS student,
       c.name AS city,
       ROUND(ST_Distance(
         c.location::geography,
         ST_SetSRID(ST_MakePoint(2.6502, 39.5697), 4326)::geography
       ) / 1000) AS km_to_palma
FROM student s
JOIN city c ON s.city_id = c.id
WHERE ST_DWithin(
  c.location::geography,
  ST_SetSRID(ST_MakePoint(2.6502, 39.5697), 4326)::geography,
  300000  -- 300 km en metres
)
ORDER BY km_to_palma;

-- Estadístiques agregades
SELECT 
  COUNT(DISTINCT s.id) AS total_students,
  COUNT(DISTINCT c.id) AS cities_with_students,
  (SELECT COUNT(*) FROM city) AS total_cities
FROM student s
JOIN city c ON s.city_id = c.id;

