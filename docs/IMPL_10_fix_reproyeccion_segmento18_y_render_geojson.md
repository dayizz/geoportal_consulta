# IMPL_10 Fix reproyeccion segmento_18 y render GeoJSON

- Estado: Implementado
- Fecha: 2026-05-18
- Rama: main

## 1. Objetivo

Corregir la visualizacion de las nuevas capas GeoJSON, especialmente segmento_18.geojson, para que se rendericen correctamente en el mapa web publicado.

## 2. Diagnostico / contexto actual

Se detecto que:
- SEGMENTO13_TSNL_1805.geojson y ESTACIONES_Y_EDIFICIOS_AUXILIARES_TSNL_1805.geojson venian en CRS84 (WGS84).
- segmento_18.geojson venia en EPSG:6372 (coordenadas proyectadas), no aptas para render directo como lat/lon.

Esto provocaba geometria fuera de rango geodesico en el mapa y afectaba el enfoque/visualizacion de capas importadas.

## 3. Fases

### Fase 1: Diagnostico de CRS y geometria

- Descripcion: Se inspeccionaron CRS y coordenadas de los 3 archivos.
- Archivos afectados:
  - assets/data/SEGMENTO13_TSNL_1805.geojson
  - assets/data/segmento_18.geojson
  - assets/data/ESTACIONES_Y_EDIFICIOS_AUXILIARES_TSNL_1805.geojson
- Codigo clave: validacion de CRS y primer punto por archivo
- Tiempo estimado: 10 min
- Riesgo: Bajo

### Fase 2: Reproyeccion de segmento_18.geojson a WGS84

- Descripcion: Se reproyecto segmento_18.geojson desde EPSG:6372 a EPSG:4326 con ogr2ogr.
- Archivos afectados:
  - assets/data/segmento_18.geojson
  - assets/data/segmento_18.backup_epsg6372.geojson (respaldo local)
- Codigo clave:
  - ogr2ogr -s_srs EPSG:6372 -t_srs EPSG:4326
- Tiempo estimado: 15 min
- Riesgo: Medio-bajo (transformacion geoespacial controlada)

### Fase 3: Hardening en render de coordenadas

- Descripcion: Se reforzo el parser de coordenadas para descartar puntos fuera de rango geodesico y evitar rompimiento del render por archivos proyectados/corruptos.
- Archivos afectados:
  - lib/features/mapa/mapa_screen.dart
- Codigo clave:
  - filtro de longitud en [-180, 180]
  - filtro de latitud en [-90, 90]
- Tiempo estimado: 10 min
- Riesgo: Bajo

## 4. Resumen de esfuerzo

| Fase | Tiempo estimado | Riesgo |
|---|---:|---|
| Fase 1 | 10 min | Bajo |
| Fase 2 | 15 min | Medio-bajo |
| Fase 3 | 10 min | Bajo |
| Total | 35 min | Bajo |

## 5. Criterio de exito

- segmento_18.geojson queda en CRS84/EPSG:4326.
- El mapa no se rompe por coordenadas fuera de rango.
- Compilacion web exitosa.
- Capas nuevas visibles en el portal.

## 6. Resultado / evidencia

- Reproyeccion aplicada y verificada en assets/data/segmento_18.geojson.
- Endurecimiento de parser aplicado en lib/features/mapa/mapa_screen.dart.
- Build web exitoso posterior al cambio.

## 7. Proximo paso

Validar en produccion (GitHub Pages) el enfoque al mapa y la visualizacion conjunta de las capas nuevas en diferentes niveles de zoom.
