# Análisis espacial — EX-2026-06193195

**Inmueble:** Las Compuertas, Luján de Cuyo, Mendoza
**Objeto:** verificación de la factibilidad de agua potable informada por AySAM
**Base:** servidor PostGIS/PostgreSQL institucional — esquema `produccion`
**Fecha de proceso:** 2026-09-10

> **Estado:** el control geométrico de la parcela (§A.1) está **verificado**. Las
> filas marcadas `PENDIENTE` requieren ejecutar `consultas_trias.sql` contra la
> base de producción: el entorno donde se preparó este análisis no tiene ruta de
> red hacia el servidor (red interna DIRCAS). Ver §E.

---

## A) Tabla resumen

| # | Concepto | Valor | Origen |
|---|---|---|---|
| 1 | **Superficie de la parcela** | **83.550,09 m² (8,3550 ha)** — perímetro 1.572,35 m, 7 vértices, polígono válido | Vértices del plano de mensura, POSGAR 98 faja 2 (EPSG:22172) |
| 2 | Diferencia vs. superficie de mensura (83.549 m²) | **+1,09 m² (0,0013 %)** — dentro de tolerancia de redondeo | Cálculo propio |
| 3 | Red AySAM más cercana — identificador | `PENDIENTE` | `redes_aysam_agua_20260907` |
| 4 | Red AySAM más cercana — diámetro nominal | `PENDIENTE` | ídem |
| 5 | Red AySAM más cercana — material | `PENDIENTE` | ídem |
| 6 | Red AySAM más cercana — **distancia (línea recta)** | `PENDIENTE` m | ídem, `ST_Distance` |
| 7 | Tramo más próximo con DN ≥ 90 — distancia | `PENDIENTE` m | ídem, `ST_ShortestLine` |
| 8 | Cambios respecto de la versión 2026-05-27 | `PENDIENTE` | `redes_aysam_agua_20260527` |
| 9 | **Superposición con `areas_dircas`** | `PENDIENTE` (sí/no — cuál) | `areas_dircas`, radio 3.000 m |
| 10 | Superficie superpuesta | `PENDIENTE` m² (`PENDIENTE` % de la parcela) | `ST_Intersection` |
| 11 | **Operadores DIRCAS en el entorno** (radio 1.500 m) | `PENDIENTE` | `redes` ⋈ `operadores` |

**Referencia declarada por la Operadora:** AySAM informa red DN 90 a **267 m al sur**,
medidos por Calle Pública (traza vial).

---

## B) Textos para el informe

Completar los campos entre corchetes con los valores de §A una vez ejecutadas las consultas.

**B.1 — Cotejo con la red de AySAM**

> Superpuesto el inmueble con la capa de redes de agua de AySAM actualizada al
> 07/09/2026, la red más próxima se ubica a **[X]** m del límite del inmueble, con
> diámetro **[Y]** y material **[Z]**. Esto **[coincide / no coincide]** con lo
> indicado por la Operadora en su informe, que consigna una cañería DN 90 a 267 m
> al sur del inmueble por Calle Pública.

**B.2 — Cotejo con áreas de operadores registrados**

> Del análisis de superposición con la capa de áreas de operadores registrados en
> esta Dirección (`areas_dircas`), surge que el inmueble **[no se superpone / se
> superpone]** con áreas de operadores registrados en DIRCAS **[; el área
> involucrada corresponde a (denominación del operador), con una superficie
> superpuesta de (S) m², equivalente al (P) % de la parcela]**.

**B.3 — Conclusión sobre la operadora del entorno**

> En virtud de lo expuesto, se concluye que la prestación del servicio de agua
> potable en el entorno del inmueble se encuentra a cargo de **[AySAM S.A. / (el
> operador DIRCAS identificado)]**, no registrándose en la base de datos de esta
> Dirección **[otros operadores / operadores]** con infraestructura de red en un
> radio de 1.500 m. En consecuencia, la factibilidad deberá tramitarse ante
> **[dicha operadora]**.

---

## C) Nota aclaratoria sobre la métrica de distancia

La distancia obtenida por vía geoespacial (`ST_Distance` / `ST_ShortestLine`) es la
**mínima en línea recta** entre el límite del inmueble y el eje de la cañería. Los
**267 m informados por AySAM** corresponden, en cambio, al **desarrollo por traza
vial** —recorrido real de la futura cañería de extensión por Calle Pública—.

Por construcción, la distancia en línea recta es **siempre menor o igual** a la
medida por traza vial. El criterio de compatibilidad es, entonces:

- **Compatible** si `d_recta ≤ 267 m`. En trazados urbanos regulares la relación
  traza/recta suele ubicarse entre **1,1 y 1,4**, por lo que un valor de
  `d_recta` en el orden de **190 a 265 m** confirma el dato de la Operadora.
- **A revisar** si `d_recta` resulta **mayor a 267 m**: ello indicaría una
  inconsistencia —desactualización de la capa, error de georreferenciación del
  inmueble, o que la Operadora midió contra otro tramo de red—.
- **A revisar** también si `d_recta` es **muy inferior** (p. ej. < 150 m): sugeriría
  la existencia de un tramo más próximo no considerado en el informe de AySAM.

**Resultado del cotejo:** `PENDIENTE` — completar con el valor de §A.6/§A.7.

---

## D) Consultas SQL utilizadas

Script completo y ejecutable: [`consultas_trias.sql`](./consultas_trias.sql)

Todas las consultas son de **sólo lectura**: la sesión abre con
`SET default_transaction_read_only = on;` y la parcela se materializa mediante CTE
(`WITH parcela AS (...)`), sin crear tablas ni tablas temporales.

Los atributos se devuelven como `to_jsonb(t) - 'geom'` para no depender de los
nombres exactos de las columnas, que se relevan en el Paso 1.

```sql
-- Definición de la parcela, común a todas las consultas
-- (vértices del plano de mensura en POSGAR 98 faja 2, transformados a 22182)
WITH parcela AS (
  SELECT ST_Transform(
           ST_GeomFromText(
             'POLYGON((2503071.03 6346510.82,2503536.52 6346720.59,'
             '2503621.25 6346661.76,2503668.68 6346675.42,'
             '2503796.42 6346558.78,2503777.12 6346553.54,'
             '2503674.45 6346506.70,2503071.03 6346510.82))', 22172),
           22182) AS geom
)

-- Paso 2 — control de superficie
SELECT round(ST_Area(geom)::numeric, 2) AS area_m2,
       round(ST_Perimeter(geom)::numeric, 2) AS perimetro_m,
       ST_IsValid(geom) AS valida
FROM parcela;

-- Paso 3a — AySAM vigente: 10 tramos más próximos en radio 1.000 m
SELECT round(ST_Distance(r.geom, p.geom)::numeric, 2) AS dist_m,
       (to_jsonb(r) - 'geom') AS atributos
FROM produccion.redes_aysam_agua_20260907 r, parcela p
WHERE ST_DWithin(r.geom, p.geom, 1000)
ORDER BY dist_m
LIMIT 10;

-- Paso 3b — tramo más próximo con DN >= 90: línea de distancia y punto de contacto
SELECT round(ST_Distance(r.geom, p.geom)::numeric, 2) AS dist_m,
       ST_AsText(ST_ShortestLine(p.geom, r.geom))     AS linea_distancia,
       ST_AsText(ST_ClosestPoint(p.geom, r.geom))     AS punto_parcela,
       ST_AsText(ST_ClosestPoint(r.geom, p.geom))     AS punto_red
FROM produccion.redes_aysam_agua_20260907 r, parcela p
WHERE ST_DWithin(r.geom, p.geom, 1000)
  AND (to_jsonb(r)->>'diametro')::numeric >= 90   -- ajustar al campo real
ORDER BY dist_m
LIMIT 1;

-- Paso 4 — ídem sobre redes_aysam_agua_20260527, y comparación entre versiones

-- Paso 5 — areas_dircas en radio 3.000 m y superficie superpuesta
SELECT round(ST_Distance(a.geom, p.geom)::numeric, 2) AS dist_m,
       ST_Intersects(a.geom, p.geom)                  AS superpone,
       round(COALESCE(ST_Area(ST_Intersection(a.geom, p.geom)), 0)::numeric, 2)
                                                      AS sup_superpuesta_m2,
       (to_jsonb(a) - 'geom')                         AS atributos
FROM produccion.areas_dircas a, parcela p
WHERE ST_DWithin(a.geom, p.geom, 3000)
ORDER BY dist_m;

-- Paso 6 — redes de operadores no AySAM en radio 1.500 m
SELECT round(ST_Distance(r.geom, p.geom)::numeric, 2) AS dist_m,
       (to_jsonb(r) - 'geom')                         AS atributos
FROM produccion.redes r, parcela p
WHERE ST_DWithin(r.geom, p.geom, 1500)
  AND (to_jsonb(r) - 'geom')::text !~* 'aysam|obras\s*sanitarias'
ORDER BY dist_m;
```

### Paso 7 (opcional) — exportación a GeoPackage para QGIS

`ogr2ogr` no está disponible en el entorno de proceso. Ejecutar desde un equipo con
GDAL instalado (o desde la consola OSGeo4W de QGIS):

```bash
mkdir -p ./salida

# Capa 1: parcela
ogr2ogr -f GPKG ./salida/trias.gpkg \
  PG:"host=$PGHOST port=$PGPORT dbname=$PGDATABASE user=$PGUSER" \
  -nln parcela -a_srs EPSG:22182 \
  -sql "SELECT ST_Transform(ST_GeomFromText('POLYGON((2503071.03 6346510.82,2503536.52 6346720.59,2503621.25 6346661.76,2503668.68 6346675.42,2503796.42 6346558.78,2503777.12 6346553.54,2503674.45 6346506.70,2503071.03 6346510.82))',22172),22182) AS geom"

# Capa 2: tramo de red más cercano  (ajustar el nombre del campo de diámetro)
ogr2ogr -f GPKG -update -append ./salida/trias.gpkg \
  PG:"host=$PGHOST port=$PGPORT dbname=$PGDATABASE user=$PGUSER" \
  -nln tramo_mas_cercano -a_srs EPSG:22182 \
  -sql "WITH parcela AS (SELECT ST_Transform(ST_GeomFromText('POLYGON((2503071.03 6346510.82,2503536.52 6346720.59,2503621.25 6346661.76,2503668.68 6346675.42,2503796.42 6346558.78,2503777.12 6346553.54,2503674.45 6346506.70,2503071.03 6346510.82))',22172),22182) AS geom) SELECT r.* FROM produccion.redes_aysam_agua_20260907 r, parcela p WHERE ST_DWithin(r.geom,p.geom,1000) ORDER BY ST_Distance(r.geom,p.geom) LIMIT 1"

# Capa 3: línea de distancia
ogr2ogr -f GPKG -update -append ./salida/trias.gpkg \
  PG:"host=$PGHOST port=$PGPORT dbname=$PGDATABASE user=$PGUSER" \
  -nln linea_distancia -a_srs EPSG:22182 \
  -sql "WITH parcela AS (SELECT ST_Transform(ST_GeomFromText('POLYGON((2503071.03 6346510.82,2503536.52 6346720.59,2503621.25 6346661.76,2503668.68 6346675.42,2503796.42 6346558.78,2503777.12 6346553.54,2503674.45 6346506.70,2503071.03 6346510.82))',22172),22182) AS geom) SELECT ST_ShortestLine(p.geom,r.geom) AS geom, ST_Distance(p.geom,r.geom) AS dist_m FROM produccion.redes_aysam_agua_20260907 r, parcela p WHERE ST_DWithin(r.geom,p.geom,1000) ORDER BY 2 LIMIT 1"
```

---

## E) Observaciones metodológicas

1. **Transformación de coordenadas.** EPSG:22172 (POSGAR 98 / Argentina 2) y
   EPSG:22182 (POSGAR 94 / Argentina 2) comparten los mismos parámetros de
   proyección —Transversa de Mercator, meridiano central 69° O, factor de escala 1,
   falso Este 2.500.000 m—. Sólo difiere el marco de referencia, con discrepancias
   del orden centimétrico. Por lo tanto, la superficie calculada es equivalente en
   ambos sistemas y el `ST_Transform` no introduce error apreciable en el cómputo
   del área ni en las distancias.

2. **Control de superficie.** Verificado por fórmula del área de Gauss (shoelace)
   sobre los vértices de mensura: **83.550,09 m²** contra los 83.549 m² del plano
   (Δ = 1,09 m²; 0,0013 %). El polígono es simple —no presenta auto-intersecciones—
   y cierra correctamente. **Control superado.**

3. **`pozos_dircas`.** Esta capa se almacena en EPSG:22172; de incorporarse al
   análisis, requiere `ST_Transform(geom, 22182)` para operar con el resto de las
   capas.

4. **Restricción de red.** El entorno de proceso no alcanza el servidor de base
   de datos (dirección de red privada, fuera del alcance del entorno). Las consultas de §D
   deben ejecutarse desde la red interna de DIRCAS, mediante el Administrador de
   Bases de Datos de QGIS o `psql`:

   ```bash
   psql -h "$PGHOST" -p "$PGPORT" -U "$PGUSER" -d "$PGDATABASE" \
        -f salida/consultas_trias.sql > salida/resultados_crudos.txt
   ```

5. **Sólo lectura.** El script no ejecuta `INSERT`, `UPDATE`, `DELETE`, `CREATE` ni
   `DROP`, y no crea tablas temporales.
