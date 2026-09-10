-- =====================================================================
-- EX-2026-06193195 -- Factibilidad de agua potable
-- Inmueble en Las Compuertas, Lujan de Cuyo -- Analisis espacial DIRCAS
-- Esquema: produccion.  SOLO LECTURA: sin DDL ni DML, parcela via CTE.
--
-- SQL puro, sin meta-comandos de psql: sirve por los tres caminos.
--   a) psql   (desde la LAN de Irrigacion)
--        psql -P pager=off -f consultas_trias.sql > resultados_crudos.txt
--        con PGHOST / PGPORT / PGDATABASE / PGUSER / PGPASSWORD exportadas
--   b) QGIS -> Administrador de Bases de Datos -> Ventana SQL
--        pegar y ejecutar cada sentencia por separado
--   c) servidor MCP dircas_postgis, una sentencia por llamada
--        todos los prefijos usados (SET / WITH / SELECT) pasan la lista blanca
--
-- Nota para el camino (c): el MCP ya abre la conexion con
-- set_session(readonly=True), por lo que el SET de la linea siguiente es
-- redundante ahi -- y ademas puede no persistir entre llamadas si el
-- servidor no reutiliza la conexion. Es necesario en (a) y (b).
-- =====================================================================
--
-- ---------------------------------------------------------------------
-- REVISION 2026-09-10 -- campos reales relevados contra produccion
-- ---------------------------------------------------------------------
-- La version original de este script tanteaba varios nombres posibles
-- para diametro y material sin certeza de cual era el real, y suponia la
-- existencia de una tabla "operadores". Ejecutado el Paso 1 contra la
-- base, los nombres verdaderos son:
--
--   redes_aysam_agua_*   diametro -> a_diam_nom   (numeric)
--                        material -> a_material   (varchar)
--                        estado   -> a_estado     (varchar)
--                        funcion  -> funcion      (varchar)
--                        id estable entre versiones -> mslink
--
--   produccion.operadores NO EXISTE. La nomenclatura real es
--   produccion.operador_redes_dircas (id_operador, operador, op,
--   n_depto, operador_id), y las tablas hermanas
--   diametro_redes_dircas / material_redes_dircas /
--   estado_redes_dircas / clasificacion_areas_dircas /
--   jerarquia_areas_dircas / tipo_area_dircas / servicio_redes_areas.
--
--   produccion.redes y produccion.areas_dircas NO guardan el operador
--   como texto sino como clave foranea entera (id_op). El filtro por
--   texto del Paso 6b original (atrib::text !~* 'aysam') no discriminaba
--   nada: se reemplazo por JOIN contra la nomenclatura.
--
-- Se agregaron ademas cuatro consultas que la version original no tenia
-- y que resultaron necesarias (2b, 3c, 3d, 5b, 6c) -- ver los
-- encabezados de cada una.
--
-- IMPORTANTE (hallazgo metodologico): el campo funcion distingue
--   'TRAMOS ACUEDUCTO TRANSP'  acueductos de transporte, NO conectables
--                              para un servicio domiciliario
--   'TRAMOS DISTRIBUCION'      red distribuidora, la que si admite
--                              conexion  (el valor real lleva tilde en
--                              la O; se compara con ILIKE '...CI%' para
--                              mantener este archivo en ASCII puro y no
--                              depender de la codificacion del cliente)
-- Sin ese filtro, el tramo "mas cercano" que devuelve el analisis es un
-- acueducto DN 350 en estado malo, que no sirve para la factibilidad.
-- Filtrar SIEMPRE por funcion en analisis de factibilidad.
--
-- Salidas de la corrida del 2026-09-10: resultados_crudos.txt
-- Informe con los valores ya volcados:  resultados_trias.md
-- ---------------------------------------------------------------------

SET default_transaction_read_only = on;

-- ---------------------------------------------------------------------
-- PASO 1 - Estructura de las tablas (sin columnas de geometria)
-- ---------------------------------------------------------------------
-- === 1a. Tablas presentes en el esquema produccion ===
SELECT table_name
FROM information_schema.tables
WHERE table_schema = 'produccion'
  AND table_name IN ('redes_aysam_agua_20260907','redes_aysam_agua_20260527',
                     'areas_dircas','redes','operador_redes_dircas')
ORDER BY table_name;

-- === 1b. Columnas (excluidas geometry/geography) ===
SELECT table_name, ordinal_position AS pos, column_name, data_type
FROM information_schema.columns
WHERE table_schema = 'produccion'
  AND table_name IN ('redes_aysam_agua_20260907','redes_aysam_agua_20260527',
                     'areas_dircas','redes','operador_redes_dircas')
  AND udt_name NOT IN ('geometry','geography')
ORDER BY table_name, ordinal_position;

-- === 1c. Columnas de geometria declaradas (nombre y SRID reales) ===
SELECT f_table_name, f_geometry_column, srid, type
FROM geometry_columns
WHERE f_table_schema = 'produccion'
  AND f_table_name IN ('redes_aysam_agua_20260907','redes_aysam_agua_20260527',
                       'areas_dircas','redes','pozos_dircas')
ORDER BY f_table_name;

-- === 1d. Tablas de nomenclatura disponibles ===
--     (AGREGADA en la revision: las capas DIRCAS usan FK enteras y sin
--      estas tablas no se puede resolver el nombre del operador)
SELECT table_schema, table_name
FROM information_schema.tables
WHERE table_schema = 'produccion'
  AND table_name IN ('operador_redes_dircas','operador_redes',
                     'diametro_redes_dircas','diametro_redes',
                     'material_redes_dircas','material_redes','material_red',
                     'estado_redes_dircas','estado_redes',
                     'clasificacion_areas_dircas','jerarquia_areas_dircas',
                     'tipo_area_dircas','servicio_redes_areas')
ORDER BY table_name;

-- === 1e. Columnas de las tablas de nomenclatura (para armar los JOIN) ===
SELECT table_name, ordinal_position AS pos, column_name, data_type
FROM information_schema.columns
WHERE table_schema = 'produccion'
  AND table_name IN ('operador_redes_dircas','diametro_redes_dircas',
                     'material_redes_dircas','estado_redes_dircas',
                     'clasificacion_areas_dircas','jerarquia_areas_dircas',
                     'tipo_area_dircas','servicio_redes_areas')
  AND udt_name NOT IN ('geometry','geography')
ORDER BY table_name, ordinal_position;

-- ---------------------------------------------------------------------
-- PASO 2 - Control de la parcela (esperado ~ 83.549 m2)
-- ---------------------------------------------------------------------
-- === 2a. Control de superficie de la parcela ===
--     Corrida 2026-09-10: 83.550,09 m2 -- dif +1,09 m2 (0,0013 %). OK.
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

-- === 2b. Control de georreferenciacion (centroide en EPSG:4326) ===
--     AGREGADA en la revision. Toda conclusion sobre distancias depende
--     de que el poligono este bien ubicado: este control lo verifica de
--     forma independiente. Corrida 2026-09-10: lon -68,962706 /
--     lat -33,023739, que cae en Las Compuertas, Lujan de Cuyo. OK.
WITH parcela AS (
  SELECT ST_Transform(ST_GeomFromText(
           'POLYGON((2503071.03 6346510.82,2503536.52 6346720.59,'
           '2503621.25 6346661.76,2503668.68 6346675.42,'
           '2503796.42 6346558.78,2503777.12 6346553.54,'
           '2503674.45 6346506.70,2503071.03 6346510.82))', 22172), 22182) AS geom
)
SELECT ST_AsText(ST_Centroid(ST_Transform(geom, 4326)))              AS centroide_wgs84,
       round(ST_X(ST_Centroid(ST_Transform(geom, 4326)))::numeric, 6) AS lon,
       round(ST_Y(ST_Centroid(ST_Transform(geom, 4326)))::numeric, 6) AS lat
FROM parcela;

-- ---------------------------------------------------------------------
-- PASO 3 - Red AySAM agua VIGENTE (20260907): 10 tramos mas cercanos <=1000 m
--   Se conserva to_jsonb(r) - 'geom' en la ultima columna para no perder
--   ningun atributo, pero el diametro y el material ya se leen de los
--   campos reales (a_diam_nom / a_material).
-- ---------------------------------------------------------------------
-- === 3a. AySAM 20260907 - 10 tramos mas proximos (radio 1000 m) ===
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
SELECT round(dist::numeric, 2)              AS dist_m,
       (atrib->>'a_diam_nom')::numeric      AS dn_mm,
       atrib->>'a_material'                 AS material,
       atrib->>'a_estado'                   AS estado,
       btrim(atrib->>'funcion')             AS funcion,
       (atrib->>'mslink')::numeric          AS mslink,
       atrib                                AS atributos_completos
FROM cerca
ORDER BY dist
LIMIT 10;

-- === 3b. AySAM 20260907 - tramo mas proximo con DN >= 90 (SIN filtrar
--         por funcion): linea de distancia ===
--     ATENCION: esta consulta devuelve un ACUEDUCTO DE TRANSPORTE
--     (DN 350, estado malo, a 20,45 m), que NO es conectable para un
--     servicio domiciliario. Se conserva a titulo de control, pero para
--     la factibilidad hay que usar la 3c.
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
)
SELECT round(dist::numeric, 2)                        AS dist_m,
       (atrib->>'a_diam_nom')::numeric                AS dn_mm,
       atrib->>'a_material'                           AS material,
       atrib->>'a_estado'                             AS estado,
       btrim(atrib->>'funcion')                       AS funcion,
       (atrib->>'mslink')::numeric                    AS mslink,
       ST_AsText(ST_ShortestLine(gp, gr))             AS linea_distancia_22182,
       ST_AsText(ST_ClosestPoint(gp, gr))             AS punto_parcela_mas_proximo,
       ST_AsText(ST_ClosestPoint(gr, gp))             AS punto_red_mas_proximo,
       round(degrees(ST_Azimuth(ST_ClosestPoint(gp,gr), ST_ClosestPoint(gr,gp)))::numeric,1)
                                                      AS azimut_grados,
       atrib                                          AS atributos_completos
FROM cerca
WHERE (atrib->>'a_diam_nom')::numeric >= 90
ORDER BY dist
LIMIT 1;

-- === 3c. AySAM 20260907 - tramo DISTRIBUIDOR mas proximo con DN >= 90 ===
--     AGREGADA en la revision. ESTA es la consulta que corresponde para
--     una factibilidad: el tramo efectivamente conectable.
--     Corrida 2026-09-10: 67,36 m, DN 90, PVC K10, estado BUENO,
--     azimut 180,4 grados (franco sur), mslink 1568 / 1569.
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
)
SELECT round(dist::numeric, 2)                        AS dist_m,
       (atrib->>'a_diam_nom')::numeric                AS dn_mm,
       atrib->>'a_material'                           AS material,
       atrib->>'a_estado'                             AS estado,
       (atrib->>'mslink')::numeric                    AS mslink,
       round(degrees(ST_Azimuth(ST_ClosestPoint(gp,gr), ST_ClosestPoint(gr,gp)))::numeric,1)
                                                      AS azimut_grados,
       ST_AsText(ST_ClosestPoint(gr, gp))             AS punto_red_mas_proximo,
       ST_AsText(ST_ShortestLine(gp, gr))             AS linea_distancia_22182
FROM cerca
WHERE (atrib->>'a_diam_nom')::numeric >= 90
  AND btrim(atrib->>'funcion') ILIKE 'TRAMOS DISTRIBUCI%'
ORDER BY dist
LIMIT 5;

-- === 3d. AySAM 20260907 - geometria de los distribuidores DN >= 90 <300 m ===
--     AGREGADA en la revision. Permite ver si la red proxima es un
--     troncal recto de calle o una red interna en zigzag, dato necesario
--     para interpretar la distancia por traza vial que informa la
--     Operadora frente a la distancia en linea recta.
--     Corrida 2026-09-10: rumbos dispares (90 / 317 / 55 / 48 grados) y
--     tramos de 4 a 105 m -> red interna de barrio, no troncal.
WITH parcela AS (
  SELECT ST_Transform(ST_GeomFromText(
           'POLYGON((2503071.03 6346510.82,2503536.52 6346720.59,'
           '2503621.25 6346661.76,2503668.68 6346675.42,'
           '2503796.42 6346558.78,2503777.12 6346553.54,'
           '2503674.45 6346506.70,2503071.03 6346510.82))', 22172), 22182) AS geom
)
SELECT r.mslink,
       r.a_diam_nom                                   AS dn_mm,
       r.a_material                                   AS material,
       r.a_longitud                                   AS longitud_declarada_m,
       btrim(r.funcion)                               AS funcion,
       round(ST_Distance(r.geom, p.geom)::numeric, 2)  AS dist_m,
       round(ST_Length(r.geom)::numeric, 2)            AS largo_calculado_m,
       round(degrees(ST_Azimuth(ST_StartPoint(ST_GeometryN(r.geom,1)),
                                ST_EndPoint(ST_GeometryN(r.geom,1))))::numeric,1)
                                                       AS rumbo_tramo,
       ST_AsText(ST_GeometryN(r.geom,1))               AS geometria
FROM produccion.redes_aysam_agua_20260907 r, parcela p
WHERE ST_DWithin(r.geom, p.geom, 300)
  AND r.a_diam_nom >= 90
  AND btrim(r.funcion) ILIKE 'TRAMOS DISTRIBUCI%'
ORDER BY dist_m
LIMIT 8;

-- ---------------------------------------------------------------------
-- PASO 4 - Red AySAM agua ANTERIOR (20260527): mismo analisis
--   OJO: esta version NO tiene la columna a_longitud, y el campo funcion
--   viene con relleno de espacios a la derecha (de ahi el btrim).
-- ---------------------------------------------------------------------
-- === 4a. AySAM 20260527 - 10 tramos mas proximos (radio 1000 m) ===
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
SELECT round(dist::numeric, 2)              AS dist_m,
       (atrib->>'a_diam_nom')::numeric      AS dn_mm,
       atrib->>'a_material'                 AS material,
       atrib->>'a_estado'                   AS estado,
       btrim(atrib->>'funcion')             AS funcion,
       (atrib->>'mslink')::numeric          AS mslink,
       atrib                                AS atributos_completos
FROM cerca
ORDER BY dist
LIMIT 10;

-- === 4b. Comparacion entre versiones (minimos por DN, radio 1000 m) ===
--     El identificador que se compara es mslink, NO ogc_fid ni fid:
--     esas dos son claves subrogadas y se renumeran en cada recarga de
--     la capa (el mismo tramo paso de ogc_fid 45769 a 32285).
--     Se agrega la columna dist_min_dn90_distrib, que es la unica
--     comparable con el dato que informa la Operadora.
--     Corrida 2026-09-10: ambas versiones identicas (53 tramos,
--     20,45 / 20,45 / 67,36 m, mslink 223774). Sin cambios relevantes.
WITH parcela AS (
  SELECT ST_Transform(ST_GeomFromText(
           'POLYGON((2503071.03 6346510.82,2503536.52 6346720.59,'
           '2503621.25 6346661.76,2503668.68 6346675.42,'
           '2503796.42 6346558.78,2503777.12 6346553.54,'
           '2503674.45 6346506.70,2503071.03 6346510.82))', 22172), 22182) AS geom
), v_new AS (
  SELECT '20260907' AS version,
         r.a_diam_nom::numeric        AS dn,
         r.mslink::numeric            AS mslink,
         btrim(r.funcion)             AS funcion,
         ST_Distance(r.geom, p.geom)  AS dist
  FROM produccion.redes_aysam_agua_20260907 r, parcela p
  WHERE ST_DWithin(r.geom, p.geom, 1000)
), v_old AS (
  SELECT '20260527' AS version,
         r.a_diam_nom::numeric        AS dn,
         r.mslink::numeric            AS mslink,
         btrim(r.funcion)             AS funcion,
         ST_Distance(r.geom, p.geom)  AS dist
  FROM produccion.redes_aysam_agua_20260527 r, parcela p
  WHERE ST_DWithin(r.geom, p.geom, 1000)
), u AS (
  SELECT * FROM v_new UNION ALL SELECT * FROM v_old
), resumen AS (
  SELECT version,
         count(*)                          AS tramos_en_1000m,
         min(dist)                         AS dist_min,
         min(dist) FILTER (WHERE dn >= 90) AS dist_min_dn90,
         min(dist) FILTER (WHERE dn >= 90
                             AND funcion ILIKE 'TRAMOS DISTRIBUCI%')
                                           AS dist_min_dn90_distrib
  FROM u GROUP BY version
), mas_cercano AS (
  SELECT DISTINCT ON (version) version, dn, mslink, dist
  FROM u ORDER BY version, dist
)
SELECT r.version,
       r.tramos_en_1000m,
       round(r.dist_min::numeric, 2)               AS dist_min_m,
       round(r.dist_min_dn90::numeric, 2)          AS dist_min_dn90_m,
       round(r.dist_min_dn90_distrib::numeric, 2)  AS dist_min_dn90_distrib_m,
       m.dn                                        AS dn_del_mas_cercano,
       m.mslink                                    AS mslink_del_mas_cercano
FROM resumen r JOIN mas_cercano m USING (version)
ORDER BY r.version DESC;

-- ---------------------------------------------------------------------
-- PASO 5 - areas_dircas en radio 3000 m + superposicion con la parcela
--   Los atributos son claves foraneas enteras: se resuelven por JOIN
--   contra las tablas de nomenclatura relevadas en 1d/1e.
-- ---------------------------------------------------------------------
-- === 5a. areas_dircas - poligonos en radio 3000 m ===
--     Corrida 2026-09-10: superpone un solo poligono, gid 212, operador
--     AYSAM SAPEM, 6.386,12 m2 (7,64 % de la parcela). Ninguna
--     superposicion con operadores distintos de AySAM.
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
       op.operador,
       cl.clasificacion,
       je.jerarquia,
       ti.tipo,
       se.servicio,
       (to_jsonb(a) - 'geom')                                            AS atributos_completos
FROM produccion.areas_dircas a
JOIN parcela p ON ST_DWithin(a.geom, p.geom, 3000)
LEFT JOIN produccion.operador_redes_dircas      op ON op.id_operador = a.id_op
LEFT JOIN produccion.clasificacion_areas_dircas cl ON cl.id_clasi    = a.id_clasi
LEFT JOIN produccion.jerarquia_areas_dircas     je ON je.id_jer      = a.id_jer
LEFT JOIN produccion.tipo_area_dircas           ti ON ti.id_tipo     = a.id_tipo
LEFT JOIN produccion.servicio_redes_areas       se ON se.id_servicio = a.id_servicio
ORDER BY dist_m, sup_superpuesta_m2 DESC;

-- === 5b. Extension de la interseccion con el area que superpone ===
--     AGREGADA en la revision. Un porcentaje de superposicion no dice si
--     se trata de una inclusion sustantiva o de una franja de
--     digitalizacion sobre el limite. Esta consulta lo caracteriza.
--     Corrida 2026-09-10: la interseccion se extiende 477,15 m E-O sobre
--     los 725,39 m de la parcela pero suma 6.386,12 m2 -> ancho medio de
--     unos 13,4 m: franja angosta sobre el borde norte/noroeste.
--     Ajustar el gid del area segun lo que devuelva la 5a.
WITH parcela AS (
  SELECT ST_Transform(ST_GeomFromText(
           'POLYGON((2503071.03 6346510.82,2503536.52 6346720.59,'
           '2503621.25 6346661.76,2503668.68 6346675.42,'
           '2503796.42 6346558.78,2503777.12 6346553.54,'
           '2503674.45 6346506.70,2503071.03 6346510.82))', 22172), 22182) AS geom
), inter AS (
  SELECT a.gid, ST_Intersection(a.geom, p.geom) AS gi, p.geom AS gp
  FROM produccion.areas_dircas a, parcela p
  WHERE ST_Intersects(a.geom, p.geom)
)
SELECT gid,
       round(ST_Area(gi)::numeric, 2)   AS sup_intersec_m2,
       round(ST_XMin(gi)::numeric, 2)   AS x_min_int,
       round(ST_XMax(gi)::numeric, 2)   AS x_max_int,
       round(ST_XMin(gp)::numeric, 2)   AS x_min_parcela,
       round(ST_XMax(gp)::numeric, 2)   AS x_max_parcela,
       round(ST_YMin(gi)::numeric, 2)   AS y_min_int,
       round(ST_YMax(gi)::numeric, 2)   AS y_max_int,
       round((ST_XMax(gi) - ST_XMin(gi))::numeric, 2)                       AS ancho_e_o_int_m,
       round((ST_Area(gi) / NULLIF(ST_XMax(gi) - ST_XMin(gi),0))::numeric,2) AS ancho_medio_n_s_m
FROM inter
ORDER BY sup_intersec_m2 DESC;

-- === 5c. Superposicion real o desfase de digitalizacion? ===
--     AGREGADA en la revision del 2026-09-10 (segunda pasada).
--     La 5b da la forma de la franja, pero no alcanza para decidir si el
--     area realmente incluye parte del inmueble o si el poligono de area
--     esta corrido. La prueba decisiva es el PARALELISMO: si el limite de
--     la parcela y el borde del area son paralelos dentro de fracciones de
--     grado y el offset perpendicular se mantiene constante, entonces es la
--     misma linea capturada dos veces, no dos limites independientes.
--
--     Ojo con el bounding box: si el limite corre en diagonal, dividir la
--     superficie por la extension E-O subestima el largo y sobreestima el
--     ancho. Usar 2*A/P (ancho medio, independiente de la orientacion),
--     4*pi*A/P^2 (compacidad) y la erosion por buffer negativo.
--     En PostGIS >= 3.1 el ancho maximo sale directo con
--     ST_MaximumInscribedCircle; este servidor corre 3.0.0 y no la tiene.
--
--     Corrida 2026-09-10 sobre el area gid 212:
--       ancho medio 12,22 m / compacidad 0,0734 / subsiste a -6 m y
--       desaparece a -10 m / azimut parcela 65,742 vs area 65,603
--       -> desvio 0,138 grados sobre 510,57 m
--       offset perpendicular 13,96 m (oeste) - 12,80 (medio) - 12,19 (este)
--     Conclusion: DESFASE DE DIGITALIZACION de unos 13 m. El inmueble linda
--     con el limite del area, no esta comprendido en ella.
--
--     Los dos vertices del limite norte de la parcela y los dos extremos
--     del segmento de borde del area se leen de la 5b / del WKT de la
--     interseccion; se cargan aca como literales para poder medir.
WITH lim_parcela AS (
  SELECT ST_SetSRID(ST_MakeLine(
           ST_MakePoint(2503071.02999998, 6346510.81998035),
           ST_MakePoint(2503536.51999998, 6346720.58998035)), 22182) AS g
), lim_area AS (
  SELECT ST_SetSRID(ST_MakeLine(
           ST_MakePoint(2503080.06959584, 6346500.18433231),
           ST_MakePoint(2503712.12702083, 6346786.85642798)), 22182) AS g
), parcela AS (
  SELECT ST_Transform(ST_GeomFromText(
           'POLYGON((2503071.03 6346510.82,2503536.52 6346720.59,'
           '2503621.25 6346661.76,2503668.68 6346675.42,'
           '2503796.42 6346558.78,2503777.12 6346553.54,'
           '2503674.45 6346506.70,2503071.03 6346510.82))', 22172), 22182) AS geom
), inter AS (
  SELECT ST_Intersection(a.geom, pa.geom) AS gi
  FROM produccion.areas_dircas a, parcela pa
  WHERE a.gid = 212
)
SELECT ST_NPoints(i.gi)                                           AS vertices_franja,
       round(ST_Area(i.gi)::numeric, 2)                            AS area_m2,
       round((ST_Area(i.gi)/(ST_Perimeter(i.gi)/2))::numeric, 2)   AS ancho_medio_m,
       round((4*pi()*ST_Area(i.gi)/power(ST_Perimeter(i.gi),2))::numeric, 4)
                                                                   AS compacidad,
       round(ST_Area(ST_Buffer(i.gi,-6))::numeric, 1)              AS subsiste_a_6m,
       round(ST_Area(ST_Buffer(i.gi,-10))::numeric, 1)             AS subsiste_a_10m,
       round(degrees(ST_Azimuth(ST_StartPoint(p.g), ST_EndPoint(p.g)))::numeric, 3)
                                                                   AS azimut_parcela,
       round(degrees(ST_Azimuth(ST_StartPoint(l.g), ST_EndPoint(l.g)))::numeric, 3)
                                                                   AS azimut_area,
       round(abs(degrees(ST_Azimuth(ST_StartPoint(p.g), ST_EndPoint(p.g)))
               - degrees(ST_Azimuth(ST_StartPoint(l.g), ST_EndPoint(l.g))))::numeric, 3)
                                                                   AS desvio_grados,
       round(ST_Length(p.g)::numeric, 2)                           AS largo_limite_m,
       round(ST_Distance(ST_StartPoint(p.g), l.g)::numeric, 2)     AS offset_oeste_m,
       round(ST_Distance(ST_LineInterpolatePoint(p.g,0.5), l.g)::numeric, 2)
                                                                   AS offset_medio_m,
       round(ST_Distance(ST_EndPoint(p.g), l.g)::numeric, 2)       AS offset_este_m
FROM inter i, lim_parcela p, lim_area l;

-- === 5d. Rasgo material que podria justificar un limite real ===
--     AGREGADA en la revision. Si hubiera un cauce de riego en esa posicion,
--     el limite del area podria ser real y no un corrimiento.
--     OJO: red_de_riego tiene geometrias con coordenadas NaN, que hacen
--     fallar to_jsonb con "Token nan is invalid". De ahi el filtro por
--     ST_IsValid / NOT ST_IsEmpty y el select de columnas explicitas.
--     Corrida 2026-09-10: 0 filas -- ningun cauce en 400 m.
WITH centro AS (
  SELECT ST_Transform(ST_GeomFromText('POINT(2503300 6346610)', 22172), 22182) AS g
), parcela AS (
  SELECT ST_Transform(ST_GeomFromText(
           'POLYGON((2503071.03 6346510.82,2503536.52 6346720.59,'
           '2503621.25 6346661.76,2503668.68 6346675.42,'
           '2503796.42 6346558.78,2503777.12 6346553.54,'
           '2503674.45 6346506.70,2503071.03 6346510.82))', 22172), 22182) AS geom
), riego AS (
  SELECT r.gid, r.codcau, r.cauce, ST_Transform(r.geom, 22182) AS g
  FROM produccion.red_de_riego r, centro c
  WHERE ST_IsValid(r.geom) AND NOT ST_IsEmpty(r.geom)
    AND ST_Intersects(ST_Transform(r.geom, 22182), ST_Buffer(c.g, 400))
)
SELECT ri.gid, ri.codcau, ri.cauce,
       round(ST_Distance(ri.g, pa.geom)::numeric, 2) AS dist_a_parcela_m,
       round(degrees(ST_Azimuth(ST_StartPoint(ST_GeometryN(ri.g,1)),
                                ST_EndPoint(ST_GeometryN(ri.g,1))))::numeric, 2) AS azimut,
       round(ST_Length(ri.g)::numeric, 2) AS largo_m
FROM riego ri, parcela pa
ORDER BY dist_a_parcela_m
LIMIT 10;

-- ---------------------------------------------------------------------
-- PASO 6 - redes de operadores DIRCAS en radio 1500 m
--   6a: nomenclatura de operadores (para identificar la FK del join)
--   6b: redes proximas, con operador / diametro / material resueltos
--   6c: control con radio ampliado a 3000 m
--
--   produccion.redes NO tiene el nombre del operador como texto, sino
--   la FK entera id_op. El filtro por texto de la version original
--   (atrib::text !~* 'aysam') no excluia nada: la capa redes es la de
--   operadores DIRCAS y no contiene tramos de AySAM, que viven en las
--   capas redes_aysam_*.
-- ---------------------------------------------------------------------
-- === 6a. Nomenclatura de operadores (Lujan de Cuyo + AySAM) ===
--     La tabla tiene 163 filas: se acota a n_depto = '06' (Lujan de
--     Cuyo) mas AySAM, que son los relevantes para este expediente.
--     Quitar el WHERE para el listado completo.
SELECT id_operador, operador, op, n_depto, operador_id
FROM produccion.operador_redes_dircas
WHERE n_depto = '06' OR operador ILIKE '%aysam%'
ORDER BY operador;

-- === 6b. redes - tramos de operadores DIRCAS en radio 1500 m ===
--     Corrida 2026-09-10: 0 filas. Ningun operador DIRCAS con red en
--     1.500 m del inmueble.
WITH parcela AS (
  SELECT ST_Transform(ST_GeomFromText(
           'POLYGON((2503071.03 6346510.82,2503536.52 6346720.59,'
           '2503621.25 6346661.76,2503668.68 6346675.42,'
           '2503796.42 6346558.78,2503777.12 6346553.54,'
           '2503674.45 6346506.70,2503071.03 6346510.82))', 22172), 22182) AS geom
)
SELECT round(ST_Distance(r.geom, p.geom)::numeric, 2) AS dist_m,
       op.operador,
       di.diametro   AS dn_mm,
       ma.material,
       es.estado,
       se.servicio,
       r.long_m,
       r.n_depto,
       (to_jsonb(r) - 'geom')                         AS atributos_completos
FROM produccion.redes r
JOIN parcela p ON ST_DWithin(r.geom, p.geom, 1500)
LEFT JOIN produccion.operador_redes_dircas op ON op.id_operador = r.id_op
LEFT JOIN produccion.diametro_redes_dircas di ON di.id_diametro = r.id_diam
LEFT JOIN produccion.material_redes_dircas ma ON ma.id_material = r.id_mat
LEFT JOIN produccion.estado_redes_dircas   es ON es.id_estado   = r.id_estado
LEFT JOIN produccion.servicio_redes_areas  se ON se.id_servicio = r.id_servicio
ORDER BY dist_m
LIMIT 50;

-- === 6c. redes - resumen por operador con radio ampliado a 3000 m ===
--     AGREGADA en la revision. Si la 6b devuelve 0 filas hay que poder
--     afirmar cual es el operador DIRCAS mas proximo y a que distancia,
--     para sostener la conclusion del informe.
--     Corrida 2026-09-10: unico operador MUNICIPALIDAD DE LUJAN AGUA,
--     9 tramos, minimo 2.853,31 m.
WITH parcela AS (
  SELECT ST_Transform(ST_GeomFromText(
           'POLYGON((2503071.03 6346510.82,2503536.52 6346720.59,'
           '2503621.25 6346661.76,2503668.68 6346675.42,'
           '2503796.42 6346558.78,2503777.12 6346553.54,'
           '2503674.45 6346506.70,2503071.03 6346510.82))', 22172), 22182) AS geom
)
SELECT COALESCE(op.operador, '(sin operador asignado)')      AS operador,
       count(*)                                              AS tramos,
       round(min(ST_Distance(r.geom, p.geom))::numeric, 2)    AS dist_min_m,
       round(max(ST_Distance(r.geom, p.geom))::numeric, 2)    AS dist_max_m
FROM produccion.redes r
JOIN parcela p ON ST_DWithin(r.geom, p.geom, 3000)
LEFT JOIN produccion.operador_redes_dircas op ON op.id_operador = r.id_op
GROUP BY 1
ORDER BY dist_min_m;
