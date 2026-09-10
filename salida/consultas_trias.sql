-- =====================================================================
-- EX-2026-06193195 -- Factibilidad de agua potable
-- Inmueble en Las Compuertas, Lujan de Cuyo -- Analisis espacial DIRCAS
-- Base: PostGIS institucional (definir via PGHOST/PGDATABASE/PGUSER)  esquema: produccion
-- SOLO LECTURA. Sin DDL ni DML. Todo resuelto con CTE.
-- Ejecutar:  psql -h "$PGHOST" -U "$PGUSER" -d "$PGDATABASE" \
--                 -f consultas_trias.sql > resultados_crudos.txt
-- =====================================================================

SET default_transaction_read_only = on;

\pset pager off
\pset border 2
\timing off

-- ---------------------------------------------------------------------
-- PASO 1 - Estructura de las tablas (sin columnas de geometria)
-- ---------------------------------------------------------------------
\echo '=== 1a. Tablas presentes en el esquema produccion ==='
SELECT table_name
FROM information_schema.tables
WHERE table_schema = 'produccion'
  AND table_name IN ('redes_aysam_agua_20260907','redes_aysam_agua_20260527',
                     'areas_dircas','redes','operadores')
ORDER BY table_name;

\echo '=== 1b. Columnas (excluidas geometry/geography) ==='
SELECT table_name, ordinal_position AS pos, column_name, data_type
FROM information_schema.columns
WHERE table_schema = 'produccion'
  AND table_name IN ('redes_aysam_agua_20260907','redes_aysam_agua_20260527',
                     'areas_dircas','redes','operadores')
  AND udt_name NOT IN ('geometry','geography')
ORDER BY table_name, ordinal_position;

\echo '=== 1c. Columnas de geometria declaradas (nombre y SRID reales) ==='
SELECT f_table_name, f_geometry_column, srid, type
FROM geometry_columns
WHERE f_table_schema = 'produccion'
  AND f_table_name IN ('redes_aysam_agua_20260907','redes_aysam_agua_20260527',
                       'areas_dircas','redes','operadores','pozos_dircas')
ORDER BY f_table_name;

-- ---------------------------------------------------------------------
-- PASO 2 - Control de la parcela (esperado ~ 83.549 m2)
-- ---------------------------------------------------------------------
\echo '=== 2. Control de superficie de la parcela ==='
WITH parcela AS (
  SELECT ST_Transform(
           ST_GeomFromText(
             'POLYGON((2503071.03 6346510.82,2503536.52 6346720.59,'
             '2503621.25 6346661.76,2503668.68 6346675.42,'
             '2503796.42 6346558.78,2503777.12 6346553.54,'
             '2503674.45 6346506.70,2503071.03 6346510.82))', 22172),
           22182) AS geom
)
SELECT round(ST_Area(geom)::numeric, 2)      AS area_m2,
       round((ST_Area(geom)/10000)::numeric, 4) AS area_ha,
       round(ST_Perimeter(geom)::numeric, 2)  AS perimetro_m,
       ST_IsValid(geom)                       AS valida,
       ST_NPoints(geom)                       AS n_vertices,
       ST_AsText(ST_Centroid(geom))           AS centroide_22182,
       round((ST_Area(geom) - 83549)::numeric, 2) AS dif_vs_esperado_m2
FROM parcela;

-- ---------------------------------------------------------------------
-- PASO 3 - Red AySAM agua VIGENTE (20260907): 10 tramos mas cercanos <=1000 m
--   Los atributos se devuelven completos como JSON, asi la consulta no
--   depende de los nombres exactos de columnas.
-- ---------------------------------------------------------------------
\echo '=== 3a. AySAM 20260907 - 10 tramos mas proximos (radio 1000 m) ==='
WITH parcela AS (
  SELECT ST_Transform(ST_GeomFromText(
           'POLYGON((2503071.03 6346510.82,2503536.52 6346720.59,'
           '2503621.25 6346661.76,2503668.68 6346675.42,'
           '2503796.42 6346558.78,2503777.12 6346553.54,'
           '2503674.45 6346506.70,2503071.03 6346510.82))', 22172), 22182) AS geom
), cerca AS (
  SELECT r.geom AS gr,
         (to_jsonb(r) - 'geom') AS atrib,
         ST_Distance(r.geom, p.geom) AS dist
  FROM produccion.redes_aysam_agua_20260907 r, parcela p
  WHERE ST_DWithin(r.geom, p.geom, 1000)
)
SELECT round(dist::numeric, 2) AS dist_m,
       -- diametro: se prueban los nombres de campo habituales
       NULLIF(regexp_replace(COALESCE(atrib->>'diametro', atrib->>'diam',
              atrib->>'dn', atrib->>'diametro_mm', atrib->>'diametro_nominal',
              atrib->>'dn_mm', ''), '[^0-9.]', '', 'g'), '')::numeric AS dn_mm,
       COALESCE(atrib->>'material', atrib->>'mat', atrib->>'material_ca') AS material,
       atrib AS atributos_completos
FROM cerca
ORDER BY dist
LIMIT 10;

\echo '=== 3b. AySAM 20260907 - tramo mas proximo con DN >= 90: linea de distancia ==='
WITH parcela AS (
  SELECT ST_Transform(ST_GeomFromText(
           'POLYGON((2503071.03 6346510.82,2503536.52 6346720.59,'
           '2503621.25 6346661.76,2503668.68 6346675.42,'
           '2503796.42 6346558.78,2503777.12 6346553.54,'
           '2503674.45 6346506.70,2503071.03 6346510.82))', 22172), 22182) AS geom
), cerca AS (
  SELECT r.geom AS gr, (to_jsonb(r) - 'geom') AS atrib,
         ST_Distance(r.geom, p.geom) AS dist, p.geom AS gp
  FROM produccion.redes_aysam_agua_20260907 r, parcela p
  WHERE ST_DWithin(r.geom, p.geom, 1000)
), conx AS (
  SELECT *, NULLIF(regexp_replace(COALESCE(atrib->>'diametro', atrib->>'diam',
              atrib->>'dn', atrib->>'diametro_mm', atrib->>'diametro_nominal',
              atrib->>'dn_mm', ''), '[^0-9.]', '', 'g'), '')::numeric AS dn
  FROM cerca
)
SELECT round(dist::numeric, 2) AS dist_m,
       dn AS dn_mm,
       COALESCE(atrib->>'material', atrib->>'mat') AS material,
       ST_AsText(ST_ShortestLine(gp, gr))            AS linea_distancia_22182,
       ST_AsText(ST_ClosestPoint(gp, gr))            AS punto_parcela_mas_proximo,
       ST_AsText(ST_ClosestPoint(gr, gp))            AS punto_red_mas_proximo,
       round(degrees(ST_Azimuth(ST_ClosestPoint(gp,gr), ST_ClosestPoint(gr,gp)))::numeric,1)
                                                     AS azimut_grados,
       atrib AS atributos_completos
FROM conx
WHERE dn >= 90
ORDER BY dist
LIMIT 1;

-- ---------------------------------------------------------------------
-- PASO 4 - Red AySAM agua ANTERIOR (20260527): mismo analisis
-- ---------------------------------------------------------------------
\echo '=== 4a. AySAM 20260527 - 10 tramos mas proximos (radio 1000 m) ==='
WITH parcela AS (
  SELECT ST_Transform(ST_GeomFromText(
           'POLYGON((2503071.03 6346510.82,2503536.52 6346720.59,'
           '2503621.25 6346661.76,2503668.68 6346675.42,'
           '2503796.42 6346558.78,2503777.12 6346553.54,'
           '2503674.45 6346506.70,2503071.03 6346510.82))', 22172), 22182) AS geom
), cerca AS (
  SELECT r.geom AS gr, (to_jsonb(r) - 'geom') AS atrib,
         ST_Distance(r.geom, p.geom) AS dist
  FROM produccion.redes_aysam_agua_20260527 r, parcela p
  WHERE ST_DWithin(r.geom, p.geom, 1000)
)
SELECT round(dist::numeric, 2) AS dist_m,
       NULLIF(regexp_replace(COALESCE(atrib->>'diametro', atrib->>'diam',
              atrib->>'dn', atrib->>'diametro_mm', atrib->>'diametro_nominal',
              atrib->>'dn_mm', ''), '[^0-9.]', '', 'g'), '')::numeric AS dn_mm,
       COALESCE(atrib->>'material', atrib->>'mat') AS material,
       atrib AS atributos_completos
FROM cerca
ORDER BY dist
LIMIT 10;

\echo '=== 4b. Comparacion entre versiones (minimos por DN, radio 1000 m) ==='
WITH parcela AS (
  SELECT ST_Transform(ST_GeomFromText(
           'POLYGON((2503071.03 6346510.82,2503536.52 6346720.59,'
           '2503621.25 6346661.76,2503668.68 6346675.42,'
           '2503796.42 6346558.78,2503777.12 6346553.54,'
           '2503674.45 6346506.70,2503071.03 6346510.82))', 22172), 22182) AS geom
), v_new AS (
  SELECT '20260907' AS version,
         NULLIF(regexp_replace(COALESCE((to_jsonb(r)->>'diametro'),(to_jsonb(r)->>'diam'),
                (to_jsonb(r)->>'dn'),(to_jsonb(r)->>'diametro_mm'),''),'[^0-9.]','','g'),'')::numeric AS dn,
         ST_Distance(r.geom, p.geom) AS dist
  FROM produccion.redes_aysam_agua_20260907 r, parcela p
  WHERE ST_DWithin(r.geom, p.geom, 1000)
), v_old AS (
  SELECT '20260527' AS version,
         NULLIF(regexp_replace(COALESCE((to_jsonb(r)->>'diametro'),(to_jsonb(r)->>'diam'),
                (to_jsonb(r)->>'dn'),(to_jsonb(r)->>'diametro_mm'),''),'[^0-9.]','','g'),'')::numeric AS dn,
         ST_Distance(r.geom, p.geom) AS dist
  FROM produccion.redes_aysam_agua_20260527 r, parcela p
  WHERE ST_DWithin(r.geom, p.geom, 1000)
), u AS (
  SELECT * FROM v_new UNION ALL SELECT * FROM v_old
), resumen AS (
  SELECT version,
         count(*)                             AS tramos_en_1000m,
         min(dist)                            AS dist_min,
         min(dist) FILTER (WHERE dn >= 90)    AS dist_min_dn90
  FROM u GROUP BY version
), mas_cercano AS (
  SELECT DISTINCT ON (version) version, dn, dist
  FROM u ORDER BY version, dist
)
SELECT r.version,
       r.tramos_en_1000m,
       round(r.dist_min::numeric, 2)      AS dist_min_m,
       round(r.dist_min_dn90::numeric, 2) AS dist_min_dn90_m,
       m.dn                               AS dn_del_mas_cercano
FROM resumen r JOIN mas_cercano m USING (version)
ORDER BY r.version DESC;

-- ---------------------------------------------------------------------
-- PASO 5 - areas_dircas en radio 3000 m + superposicion con la parcela
-- ---------------------------------------------------------------------
\echo '=== 5. areas_dircas - poligonos en radio 3000 m ==='
WITH parcela AS (
  SELECT ST_Transform(ST_GeomFromText(
           'POLYGON((2503071.03 6346510.82,2503536.52 6346720.59,'
           '2503621.25 6346661.76,2503668.68 6346675.42,'
           '2503796.42 6346558.78,2503777.12 6346553.54,'
           '2503674.45 6346506.70,2503071.03 6346510.82))', 22172), 22182) AS geom
)
SELECT round(ST_Distance(a.geom, p.geom)::numeric, 2)                   AS dist_m,
       ST_Intersects(a.geom, p.geom)                                     AS superpone,
       round(COALESCE(ST_Area(ST_Intersection(a.geom, p.geom)),0)::numeric, 2)
                                                                         AS sup_superpuesta_m2,
       round((COALESCE(ST_Area(ST_Intersection(a.geom, p.geom)),0)
              / NULLIF(ST_Area(p.geom),0) * 100)::numeric, 2)            AS pct_de_la_parcela,
       round(ST_Area(a.geom)::numeric, 2)                                AS area_poligono_m2,
       (to_jsonb(a) - 'geom')                                            AS atributos_completos
FROM produccion.areas_dircas a, parcela p
WHERE ST_DWithin(a.geom, p.geom, 3000)
ORDER BY dist_m, sup_superpuesta_m2 DESC;

-- ---------------------------------------------------------------------
-- PASO 6 - redes de operadores NO AySAM en radio 1500 m
--   6a: contenido de 'operadores' (para identificar la FK del join)
--   6b: redes proximas con todos sus atributos
-- ---------------------------------------------------------------------
\echo '=== 6a. Tabla operadores (listado completo) ==='
SELECT (to_jsonb(o) - 'geom') AS operador
FROM produccion.operadores o
ORDER BY 1;

\echo '=== 6b. redes - tramos en radio 1500 m (excluye AySAM por texto) ==='
WITH parcela AS (
  SELECT ST_Transform(ST_GeomFromText(
           'POLYGON((2503071.03 6346510.82,2503536.52 6346720.59,'
           '2503621.25 6346661.76,2503668.68 6346675.42,'
           '2503796.42 6346558.78,2503777.12 6346553.54,'
           '2503674.45 6346506.70,2503071.03 6346510.82))', 22172), 22182) AS geom
), cerca AS (
  SELECT (to_jsonb(r) - 'geom') AS atrib,
         ST_Distance(r.geom, p.geom) AS dist
  FROM produccion.redes r, parcela p
  WHERE ST_DWithin(r.geom, p.geom, 1500)
)
SELECT round(dist::numeric, 2) AS dist_m,
       atrib AS atributos_completos
FROM cerca
WHERE atrib::text !~* 'aysam|obras\s*sanitarias'
ORDER BY dist
LIMIT 50;
