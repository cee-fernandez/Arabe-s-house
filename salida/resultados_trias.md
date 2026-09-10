# Análisis espacial — EX-2026-06193195

**Inmueble:** Las Compuertas, Luján de Cuyo, Mendoza
**Objeto:** verificación de la factibilidad de agua potable informada por AySAM
**Base:** servidor PostGIS/PostgreSQL institucional — esquema `produccion`
**Fecha de proceso:** 2026-09-10

> **Estado:** **completo**. Las consultas de `consultas_trias.sql` se ejecutaron
> contra la base de producción a través del servidor MCP `dircas_postgis` (sólo
> lectura) el 2026-09-10. Salidas crudas en
> [`resultados_crudos.txt`](./resultados_crudos.txt).
>
> **Ajustes al script.** El Paso 1 reveló que los nombres de campo tanteados no
> existen: el diámetro de AySAM es `a_diam_nom` y el material `a_material` (no
> `diametro`/`dn`/`material`); y la tabla `produccion.operadores` no existe —la
> nomenclatura real es `produccion.operador_redes_dircas`—. La tabla
> `produccion.redes` no tiene el operador como texto sino como clave foránea
> entera (`id_op`), por lo que el filtro por texto del Paso 6b no discriminaba
> nada y se reemplazó por `JOIN` contra las tablas de nomenclatura. El detalle
> de los ajustes está al inicio de `resultados_crudos.txt`.

---

## A) Tabla resumen

| # | Concepto | Valor | Origen |
|---|---|---|---|
| 1 | **Superficie de la parcela** | **83.550,09 m² (8,3550 ha)** — perímetro 1.572,35 m, 7 vértices, polígono válido | Vértices del plano de mensura, POSGAR 98 faja 2 (EPSG:22172) — **confirmado en base** |
| 2 | Diferencia vs. superficie de mensura (83.549 m²) | **+1,09 m² (0,0013 %)** — dentro de tolerancia de redondeo | Cálculo propio, replicado con `ST_Area` |
| 3 | Red AySAM más cercana — identificador | **`mslink` 223774** (`ogc_fid` 32285) — pero es un **acueducto de transporte**, no red distribuidora. Primera red **distribuidora**: **`mslink` 1569 y 1568** (`ogc_fid` 29504 / 30160) | `redes_aysam_agua_20260907` |
| 4 | Red AySAM más cercana — diámetro nominal | **DN 350 mm** (acueducto) — **DN 90 mm** (primera distribuidora) | ídem, campo `a_diam_nom` |
| 5 | Red AySAM más cercana — material y estado | **Hierro fundido, estado declarado "MALO"** (acueducto) — **PVC K10, estado "BUENO"** (distribuidora DN 90) | ídem, campos `a_material` / `a_estado` |
| 6 | Red AySAM más cercana — **distancia (línea recta)** | **20,45 m** al acueducto DN 350 (azimut 334,8° → NO, desde el vértice oeste) — **67,36 m** a la distribuidora DN 90 (azimut **180,4° → franco sur**, desde el límite sur) | ídem, `ST_Distance` / `ST_Azimuth` |
| 7 | Tramo más próximo con DN ≥ 90 — distancia | **20,45 m** sin filtrar por función; **67,36 m** exigiendo `funcion = 'TRAMOS DISTRIBUCIÓN'` (el tramo efectivamente conectable) | ídem, `ST_ShortestLine` |
| 8 | Cambios respecto de la versión 2026-05-27 | **Ninguno relevante.** Ambas versiones devuelven los **mismos 53 tramos** en 1.000 m, con **idénticas** distancias (20,45 / 28,55 / 31,70 / 32,98 / 33,32 / 63,81 / 67,36 / 67,36 / 67,45 / 70,34 m), diámetros, materiales, estados y el mismo `mslink`. Sólo cambian: las claves subrogadas `ogc_fid`/`fid` (se renumeran en cada recarga — **no usar para comparar versiones**), el agregado de la columna `a_longitud`, la normalización del campo `funcion` (se quitó el relleno de espacios) y el tipo geométrico declarado (`LINESTRING` → `MULTILINESTRING`) | `redes_aysam_agua_20260527` vs. `_20260907` |
| 9 | **Superposición con `areas_dircas`** | **Sí**, con un **único** polígono: `gid` 212, `zona_id` 224 — operador **AYSAM SAPEM** (`id_operador` 149), clasificación `AGUA_POTABLE`, jerarquía `OPERADOR`, tipo `AREA y SERVICIO`. **No hay superposición con áreas de operadores distintos de AySAM** | `areas_dircas`, radio 3.000 m |
| 10 | Superficie superpuesta | **6.386,12 m² (7,64 % de la parcela)** — franja angosta de ~13,4 m de ancho medio sobre el borde norte/noroeste, a lo largo de 477,15 m de los 725,39 m de desarrollo E-O. Ver la salvedad en §B.2 | `ST_Intersection` |
| 11 | **Operadores DIRCAS en el entorno** (radio 1.500 m) | **Ninguno** — cero tramos de red de operadores registrados en DIRCAS. Ampliado el radio a 3.000 m, el único es **MUNICIPALIDAD DE LUJÁN (Agua)** con 9 tramos a **2.853,31 m** | `redes` ⋈ `operador_redes_dircas` |
| 12 | Área de operador no-AySAM más próxima | **MUNICIPALIDAD DE LUJÁN (Agua)** a **1.777,82 m**, sin superposición | `areas_dircas` |
| 13 | Control de georreferenciación *(agregado)* | **Superado** — centroide en **lon −68,962706 / lat −33,023739** (EPSG:4326), que cae en Las Compuertas, Luján de Cuyo | `ST_Transform(geom, 4326)` |

**Referencia declarada por la Operadora:** AySAM informa red DN 90 a **267 m al sur**,
medidos por Calle Pública (traza vial).

> **Siglas y campos usados en esta tabla**
> — **DN** (*diámetro nominal*): designación normalizada del diámetro de una
> cañería, en milímetros; se usa porque es el dato que identifica capacidad de
> conducción y compatibilidad de piezas, y es el que consigna la Operadora.
> — **PVC K10**: policloruro de vinilo, clase K10 (presión nominal 10 bar).
> — **SAPEM**: Sociedad Anónima con Participación Estatal Mayoritaria, forma
> jurídica de AySAM.
> — **`mslink`**: identificador de origen del sistema de AySAM (heredado de
> MicroStation). Es **estable entre versiones** de la capa, a diferencia de
> `ogc_fid`/`fid`, que son claves subrogadas que se renumeran en cada carga.
> — **EPSG:22172 / EPSG:22182**: códigos del registro EPSG para POSGAR 98 faja 2
> y POSGAR 94 faja 2 respectivamente; se usan porque son los sistemas
> proyectados en metros del catastro provincial, lo que permite medir
> superficies y distancias directamente.
> — **`funcion`**: campo de la capa de AySAM que distingue `TRAMOS ACUEDUCTO
> TRANSP` (acueductos de transporte, no conectables a un servicio domiciliario)
> de `TRAMOS DISTRIBUCIÓN` (red distribuidora, la que sí admite conexión). Esta
> distinción resultó decisiva y **no estaba prevista en el script original**.

---

## B) Textos para el informe

**B.1 — Cotejo con la red de AySAM**

> Superpuesto el inmueble con la capa de redes de agua de AySAM actualizada al
> 07/09/2026, la infraestructura más próxima se ubica a **20,45 m** del límite
> oeste del inmueble y corresponde a un **acueducto de transporte de DN 350 mm en
> hierro fundido, con estado declarado "malo"** (identificador de origen `mslink`
> 223774), no apto para conexión domiciliaria. La **red distribuidora** más
> próxima se sitúa a **67,36 m** del límite sur del inmueble —azimut 180,4°, es
> decir **franco sur**—, con **diámetro nominal DN 90 mm, material PVC K10 y
> estado declarado "bueno"** (`mslink` 1569 y 1568).
>
> Ello **coincide parcialmente** con lo indicado por la Operadora en su informe,
> que consigna una cañería DN 90 a 267 m al sur del inmueble por Calle Pública:
> **coinciden** el diámetro (DN 90), el carácter distribuidor del tramo y la
> orientación (sur); **no coincide la distancia**, ya que la separación en línea
> recta medida sobre la capa vigente es de 67,36 m contra los 267 m informados.
> Cabe señalar que ambas magnitudes no son directamente comparables —una es
> distancia mínima en línea recta y la otra desarrollo por traza vial—, extremo
> que se analiza en el apartado siguiente.
>
> El cotejo con la versión anterior de la capa (27/05/2026) **no arroja
> diferencias**: ambas versiones devuelven los mismos 53 tramos en un radio de
> 1.000 m, con idénticas distancias, diámetros, materiales y estados, y el mismo
> identificador de origen `mslink`. Las únicas variaciones son de estructura de
> la tabla —renumeración de las claves subrogadas `ogc_fid`/`fid`, agregado de la
> columna `a_longitud`, normalización del campo `funcion` y cambio del tipo
> geométrico declarado—, sin incidencia sobre el resultado del análisis. En
> consecuencia, **la discrepancia de distancia no obedece a una actualización de
> la cartografía de la Operadora**.

**B.2 — Cotejo con áreas de operadores registrados**

> Del análisis de superposición con la capa de áreas de operadores registrados en
> esta Dirección (`areas_dircas`), surge que el inmueble **se superpone** con un
> único polígono —`gid` 212, `zona_id` 224—, cuyo **operador registrado es AYSAM
> SAPEM** (`id_operador` 149), con clasificación `AGUA_POTABLE` y jerarquía
> `OPERADOR`. La superficie superpuesta es de **6.386,12 m², equivalente al
> 7,64 % de la parcela**. **No se registra superposición alguna con áreas de
> operadores distintos de AySAM**: la más próxima de ellas corresponde a
> MUNICIPALIDAD DE LUJÁN (Agua), a 1.777,82 m del inmueble.
>
> *Salvedad sobre el 7,64 %.* La intersección se extiende 477,15 m en dirección
> este-oeste —sobre los 725,39 m de desarrollo de la parcela— y suma sólo
> 6.386,12 m², lo que arroja un **ancho medio del orden de 13,4 m**. Se trata,
> por tanto, de una **franja angosta sobre el borde norte/noroeste**, compatible
> con que el límite del polígono de área de AySAM corra prácticamente sobre el
> límite norte de la parcela con un desfase de digitalización de pocos metros, y
> **no** con una inclusión sustantiva del inmueble dentro del área registrada. Se
> recomienda confirmarlo visualmente en QGIS antes de asignarle efecto jurídico
> al porcentaje.

**B.3 — Conclusión sobre la operadora del entorno**

> En virtud de lo expuesto, se concluye que la prestación del servicio de agua
> potable en el entorno del inmueble se encuentra a cargo de **AySAM S.A. (AYSAM
> SAPEM)**, no registrándose en la base de datos de esta Dirección **operadores**
> con infraestructura de red en un radio de 1.500 m —radio que se amplió a
> 3.000 m con idéntico resultado: el único operador registrado en DIRCAS con red
> en ese entorno es MUNICIPALIDAD DE LUJÁN (Agua), a 2.853,31 m del inmueble—. En
> consecuencia, la factibilidad deberá tramitarse ante **dicha operadora**.

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

**Resultado del cotejo:** el caso cae en el **tercer supuesto — "A REVISAR" por
distancia recta muy inferior**.

`d_recta` al tramo **DN 90 distribuidor** = **67,36 m** (§A.6/§A.7), contra los
267 m de traza vial informados. La relación **traza/recta resulta 3,96**, muy por
encima del rango 1,1–1,4 esperable en trazado urbano regular, y `d_recta` queda
holgadamente por debajo del umbral de 150 m fijado más arriba. Existe, por tanto,
**un tramo DN 90 distribuidor a 67 m del límite sur del inmueble que el informe de
la Operadora no parece haber considerado**. Si se tomara el tramo más próximo sin
distinguir por función, `d_recta` baja a 20,45 m —pero ese tramo es un acueducto
de transporte DN 350 en estado "malo", no conectable, por lo que no corresponde
usarlo para este cotejo.

**Hipótesis alternativas descartadas por control expreso**

| Hipótesis | Control realizado | Resultado |
|---|---|---|
| Error de georreferenciación del inmueble | Reproyección del centroide a EPSG:4326 (§A.13) | **Descartada** — cae en Las Compuertas |
| Error en la geometría de la parcela | `ST_Area` = 83.550,09 m² vs. 83.549 m² de mensura; `ST_IsValid` = verdadero (§A.1/§A.2) | **Descartada** — Δ 0,0013 % |
| Desactualización de la capa de AySAM | Cotejo `_20260527` vs. `_20260907` (§A.8) | **Descartada** — resultados idénticos |
| Otro operador con red más próxima | `redes` ⋈ `operador_redes_dircas`, radios 1.500 y 3.000 m (§A.11) | **Descartada** — ninguno a menos de 2.853 m |

**Interpretación más probable (extrapolación, no verificada en base)**

Las dos cifras pueden no ser contradictorias. La red DN 90 al sur **no es un
troncal recto de calle** sino una **red interna de barrio en zigzag**: los tramos
próximos (`mslink` 1565, 1568, 1569, 1570) tienen rumbos dispares —90°, 317°,
55°, 48°— y longitudes de 4 a 105 m. Un recorrido de extensión en "L" o en "U"
sobre esa traza —avanzar por la calle del barrio hasta una transversal, subir
hacia el inmueble y volver— puede totalizar 267 m aun cuando la separación en
línea recta sea de sólo 67 m. Una segunda explicación posible, no verificable
desde la base, es que el tramo a 67 m carezca de capacidad disponible o
corresponda a un consorcio cerrado, y que la Operadora haya medido contra un
tramo con capacidad situado más al sur.

**Recomendación.** Requerir a AySAM que precise el **punto de empalme concreto**
(nodo o identificador de tramo) y la **traza de la extensión proyectada**, a fin
de cotejar los 267 m tramo por tramo. La base de datos permite verificar la
existencia, el diámetro y la posición de las cañerías, pero no el recorrido
proyectado ni la capacidad hidráulica disponible.

**Estado de verificación de este apartado**

- **Confirmado en base:** distancias, azimuts, diámetros, materiales, estados,
  geometrías, identificadores `mslink`, superposición con `areas_dircas`,
  ausencia de operadores DIRCAS en 1.500 m, georreferenciación y superficie.
- **Extrapolado (razonamiento, no medición):** la interpretación del recorrido en
  "L"/"U" que explicaría los 267 m; el carácter de "franja de digitalización" del
  7,64 % de superposición.
- **No verificable con esta base:** la traza real de la extensión proyectada, la
  capacidad hidráulica disponible del tramo DN 90, y la titularidad efectiva del
  tramo a 67 m (consorcio cerrado o red pública).

---

## D) Consultas SQL utilizadas

Script completo y ejecutable: [`consultas_trias.sql`](./consultas_trias.sql)
Salidas crudas de la corrida del 2026-09-10: [`resultados_crudos.txt`](./resultados_crudos.txt)

Todas las consultas son de **sólo lectura**: la sesión abre con
`SET default_transaction_read_only = on;` y la parcela se materializa mediante CTE
(`WITH parcela AS (...)`), sin crear tablas ni tablas temporales.

Los atributos se devuelven como `to_jsonb(t) - 'geom'` para no depender de los
nombres exactos de las columnas, que se relevan en el Paso 1.

> **Nota de la corrida.** Los nombres de campo tanteados en el script no
> coincidieron con los reales. Las consultas que se ejecutaron efectivamente usan
> `a_diam_nom` (diámetro) y `a_material` (material) para las capas de AySAM, y
> `JOIN` contra `operador_redes_dircas` / `diametro_redes_dircas` /
> `material_redes_dircas` / `estado_redes_dircas` / `servicio_redes_areas` para
> `redes` y `areas_dircas`. Ver el encabezado de `resultados_crudos.txt`.
>
> **`consultas_trias.sql` ya está corregido** con los campos reales y verificado
> contra la base: incorpora las consultas agregadas (2b, 3c, 3d, 5b, 6c) y deja
> anotado el valor obtenido en la corrida del 2026-09-10 junto a cada una, de
> modo que sirva como línea de base para futuros cotejos. Para el filtro por
> función se usa `btrim(funcion) ILIKE 'TRAMOS DISTRIBUCI%'` en lugar del literal
> acentuado, lo que mantiene el archivo en ASCII puro y lo hace independiente de
> la codificación del cliente; se comprobó que ese patrón captura los 46.438
> tramos de distribución de la capa y ninguno de las otras cinco funciones.

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
       r.a_diam_nom AS dn_mm, r.a_material, r.a_estado, btrim(r.funcion) AS funcion,
       r.mslink
FROM produccion.redes_aysam_agua_20260907 r, parcela p
WHERE ST_DWithin(r.geom, p.geom, 1000)
ORDER BY dist_m
LIMIT 10;

-- Paso 3c — tramo DISTRIBUIDOR más próximo con DN >= 90:
--           línea de distancia, puntos de contacto y azimut
SELECT round(ST_Distance(r.geom, p.geom)::numeric, 2)      AS dist_m,
       ST_AsText(ST_ShortestLine(p.geom, r.geom))          AS linea_distancia,
       ST_AsText(ST_ClosestPoint(p.geom, r.geom))          AS punto_parcela,
       ST_AsText(ST_ClosestPoint(r.geom, p.geom))          AS punto_red,
       round(degrees(ST_Azimuth(ST_ClosestPoint(p.geom,r.geom),
                                ST_ClosestPoint(r.geom,p.geom)))::numeric,1) AS azimut
FROM produccion.redes_aysam_agua_20260907 r, parcela p
WHERE ST_DWithin(r.geom, p.geom, 1000)
  AND r.a_diam_nom >= 90
  AND btrim(r.funcion) = 'TRAMOS DISTRIBUCIÓN'
ORDER BY dist_m
LIMIT 1;

-- Paso 4 — ídem sobre redes_aysam_agua_20260527, y comparación entre versiones
--          (usar mslink, NO ogc_fid/fid, que se renumeran en cada recarga)

-- Paso 5 — areas_dircas en radio 3.000 m, con nomenclatura resuelta
SELECT round(ST_Distance(a.geom, p.geom)::numeric, 2) AS dist_m,
       ST_Intersects(a.geom, p.geom)                  AS superpone,
       round(COALESCE(ST_Area(ST_Intersection(a.geom, p.geom)), 0)::numeric, 2)
                                                      AS sup_superpuesta_m2,
       op.operador, cl.clasificacion, je.jerarquia, ti.tipo, se.servicio
FROM produccion.areas_dircas a
JOIN parcela p ON ST_DWithin(a.geom, p.geom, 3000)
LEFT JOIN produccion.operador_redes_dircas      op ON op.id_operador = a.id_op
LEFT JOIN produccion.clasificacion_areas_dircas cl ON cl.id_clasi    = a.id_clasi
LEFT JOIN produccion.jerarquia_areas_dircas     je ON je.id_jer      = a.id_jer
LEFT JOIN produccion.tipo_area_dircas           ti ON ti.id_tipo     = a.id_tipo
LEFT JOIN produccion.servicio_redes_areas       se ON se.id_servicio = a.id_servicio
ORDER BY dist_m;

-- Paso 6 — redes de operadores DIRCAS en radio 1.500 m
--          (el operador es FK entera id_op, no texto: se resuelve por JOIN)
SELECT round(ST_Distance(r.geom, p.geom)::numeric, 2) AS dist_m,
       op.operador, di.diametro AS dn_mm, ma.material, es.estado, se.servicio,
       r.long_m
FROM produccion.redes r
JOIN parcela p ON ST_DWithin(r.geom, p.geom, 1500)
LEFT JOIN produccion.operador_redes_dircas op ON op.id_operador = r.id_op
LEFT JOIN produccion.diametro_redes_dircas di ON di.id_diametro = r.id_diam
LEFT JOIN produccion.material_redes_dircas ma ON ma.id_material = r.id_mat
LEFT JOIN produccion.estado_redes_dircas   es ON es.id_estado   = r.id_estado
LEFT JOIN produccion.servicio_redes_areas  se ON se.id_servicio = r.id_servicio
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

# Capa 2: tramo DISTRIBUIDOR DN>=90 más cercano (el conectable)
ogr2ogr -f GPKG -update -append ./salida/trias.gpkg \
  PG:"host=$PGHOST port=$PGPORT dbname=$PGDATABASE user=$PGUSER" \
  -nln tramo_mas_cercano -a_srs EPSG:22182 \
  -sql "WITH parcela AS (SELECT ST_Transform(ST_GeomFromText('POLYGON((2503071.03 6346510.82,2503536.52 6346720.59,2503621.25 6346661.76,2503668.68 6346675.42,2503796.42 6346558.78,2503777.12 6346553.54,2503674.45 6346506.70,2503071.03 6346510.82))',22172),22182) AS geom) SELECT r.* FROM produccion.redes_aysam_agua_20260907 r, parcela p WHERE ST_DWithin(r.geom,p.geom,1000) AND r.a_diam_nom >= 90 AND btrim(r.funcion) = 'TRAMOS DISTRIBUCIÓN' ORDER BY ST_Distance(r.geom,p.geom) LIMIT 1"

# Capa 3: línea de distancia
ogr2ogr -f GPKG -update -append ./salida/trias.gpkg \
  PG:"host=$PGHOST port=$PGPORT dbname=$PGDATABASE user=$PGUSER" \
  -nln linea_distancia -a_srs EPSG:22182 \
  -sql "WITH parcela AS (SELECT ST_Transform(ST_GeomFromText('POLYGON((2503071.03 6346510.82,2503536.52 6346720.59,2503621.25 6346661.76,2503668.68 6346675.42,2503796.42 6346558.78,2503777.12 6346553.54,2503674.45 6346506.70,2503071.03 6346510.82))',22172),22182) AS geom) SELECT ST_ShortestLine(p.geom,r.geom) AS geom, ST_Distance(p.geom,r.geom) AS dist_m FROM produccion.redes_aysam_agua_20260907 r, parcela p WHERE ST_DWithin(r.geom,p.geom,1000) AND r.a_diam_nom >= 90 AND btrim(r.funcion) = 'TRAMOS DISTRIBUCIÓN' ORDER BY 2 LIMIT 1"
```

---

## E) Observaciones metodológicas

1. **Transformación de coordenadas.** EPSG:22172 (POSGAR 98 / Argentina 2) y
   EPSG:22182 (POSGAR 94 / Argentina 2) comparten los mismos parámetros de
   proyección —Transversa de Mercator, meridiano central 69° O, factor de escala 1,
   falso Este 2.500.000 m—. Sólo difiere el marco de referencia, con discrepancias
   del orden centimétrico. Por lo tanto, la superficie calculada es equivalente en
   ambos sistemas y el `ST_Transform` no introduce error apreciable en el cómputo
   del área ni en las distancias. **Confirmado en la corrida:** `ST_Area` sobre la
   geometría transformada devolvió 83.550,09 m², idéntico al cálculo analítico.

2. **Control de superficie.** Verificado por fórmula del área de Gauss (shoelace)
   sobre los vértices de mensura: **83.550,09 m²** contra los 83.549 m² del plano
   (Δ = 1,09 m²; 0,0013 %). El polígono es simple —no presenta auto-intersecciones—
   y cierra correctamente. **Control superado**, replicado en base con `ST_Area` y
   `ST_IsValid`.

3. **Función de la cañería: el hallazgo metodológico de esta corrida.** El script
   original buscaba el tramo más próximo con `DN ≥ 90` sin distinguir la **función**
   de la cañería. Ese criterio devuelve un acueducto de transporte DN 350 a 20,45 m,
   que no es conectable para un servicio domiciliario y no es el tramo que
   corresponde cotejar con el informe de la Operadora. **Para futuros análisis de
   factibilidad, filtrar siempre por `btrim(funcion) = 'TRAMOS DISTRIBUCIÓN'`.**

4. **Identificador estable entre versiones.** Las claves `ogc_fid` y `fid` se
   renumeran en cada recarga de la capa: el mismo tramo pasó de `ogc_fid` 45769
   (versión 27/05) a 32285 (versión 07/09). **Usar `mslink`**, que es el
   identificador de origen del sistema de AySAM y se mantiene constante.

5. **Nomenclatura de las capas DIRCAS.** `redes` y `areas_dircas` guardan operador,
   material, diámetro, estado y servicio como **claves foráneas enteras**, no como
   texto. Cualquier filtro por nombre de operador debe hacerse por `JOIN` contra
   `operador_redes_dircas` (FK: `id_operador` ↔ `redes.id_op` / `areas_dircas.id_op`).
   La tabla `produccion.operadores` que suponía el script **no existe**.

6. **`pozos_dircas`.** Esta capa se almacena en EPSG:22172; de incorporarse al
   análisis, requiere `ST_Transform(geom, 22182)` para operar con el resto de las
   capas.

7. **Capas de cloaca disponibles.** El esquema `produccion` contiene además
   `redes_aysam_cloaca_20260527` y `redes_aysam_cloaca_20260907`. No se analizaron
   porque el expediente versa sobre factibilidad de **agua potable**; quedan
   disponibles si se requiriera el cotejo de saneamiento.

8. **Dónde ejecutar.** Las direcciones del servidor PostGIS y del MariaDB son
   privadas (RFC1918): se alcanzan únicamente desde la red del organismo. Esta
   corrida se hizo por la vía (c), desde un equipo dentro de la red. Las tres vías
   posibles —el script es SQL puro, sin meta-comandos de cliente—:

   ```bash
   # a) psql
   export PGHOST=... PGPORT=5432 PGDATABASE=... PGUSER=...
   psql -P pager=off -f salida/consultas_trias.sql > salida/resultados_crudos.txt
   ```

   b) **QGIS** → Administrador de Bases de Datos → Ventana SQL, ejecutando cada
   sentencia por separado.

   c) **Servidor MCP `dircas_postgis`** desde Claude Code en el equipo local, una
   sentencia por llamada. Todos los prefijos empleados (`SET`, `WITH`, `SELECT`)
   pasan la lista blanca del servidor. **Vía efectivamente utilizada el
   2026-09-10.**

9. **Sólo lectura.** No se ejecutó `INSERT`, `UPDATE`, `DELETE`, `CREATE` ni
   `DROP`, y no se creó ninguna tabla (tampoco temporal). Los parámetros de
   conexión —host, puerto, base, usuario y clave— no se registran en este
   repositorio, que es público.
