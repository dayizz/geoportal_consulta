# IMPL_41 - Mejoras de estaciones, duplicados, ficha y rosa de los vientos

- Estado: Completado
- Fecha: 2026-05-26
- Rama: main

## 1. Objetivo
Aplicar mejoras visuales y funcionales en el mapa:
- Relleno de estaciones por estatus.
- Ajuste de texto en simbologia de estacion.
- Deduplicacion de poligonos para evitar tonos de relleno mas fuertes por superposicion.
- Mejorar seleccion de ficha en poligonos importados.
- Agregar rosa de los vientos con los 4 puntos cardinales.

## 2. Diagnostico / contexto actual
Se detectaron inconsistencias visuales y de interaccion:
- Estaciones con solo borde y sin relleno por estatus.
- Leyenda con texto extenso para estacion.
- Posible superposicion de poligonos duplicados provocando rellenos mas intensos.
- Algunos poligonos no abrían ficha por exclusion en el hit-test.
- Falta de referencia cardinal en el mapa.

## 3. Fases
### Fase 1: Relleno de estaciones por estatus
- Descripcion: Mantener borde amarillo de estacion, pero usar relleno por estatus como el resto de features.
- Archivos afectados:
  - `lib/features/mapa/mapa_screen.dart`
- Codigo clave:
  - `polygonColor = fillColor.withOpacity(uniformFillOpacity)` para estaciones y no estaciones.
- Tiempo estimado: 15 min
- Riesgo: Bajo

### Fase 2: Uniformidad visual y deduplicacion de poligonos
- Descripcion: Definir opacidad uniforme de relleno y omitir geometrías duplicadas detectadas.
- Archivos afectados:
  - `lib/features/mapa/mapa_screen.dart`
- Codigo clave:
  - `uniformFillOpacity = 0.24`
  - `renderedPredioPolygonKeys`, `renderedImportedPolygonKeys`
  - `_polygonGeometryKey(...)`
  - exclusion de predios cuando la misma geometria ya existe en importados.
- Tiempo estimado: 25 min
- Riesgo: Medio

### Fase 3: Seleccion de ficha en poligonos importados
- Descripcion: Incluir todo `filteredImportedGeoJson` en hit-test de tap (incluye envolventes).
- Archivos afectados:
  - `lib/features/mapa/mapa_screen.dart`
- Codigo clave:
  - `_findImportedFeatureAtPoint(point, filteredImportedGeoJson)`
- Tiempo estimado: 10 min
- Riesgo: Bajo

### Fase 4: Simbologia y rosa de los vientos
- Descripcion: Simplificar texto de estacion en leyenda y agregar rosa de los vientos con N,S,E,W.
- Archivos afectados:
  - `lib/features/mapa/mapa_screen.dart`
- Codigo clave:
  - texto `Estación`
  - widget `_buildCompassRose()` y posicionamiento en mapa.
- Tiempo estimado: 15 min
- Riesgo: Bajo

## 4. Resumen de esfuerzo
| Fase | Tiempo estimado | Riesgo |
|---|---:|---|
| Fase 1 | 15 min | Bajo |
| Fase 2 | 25 min | Medio |
| Fase 3 | 10 min | Bajo |
| Fase 4 | 15 min | Bajo |
| **Total** | **65 min** | **Bajo-Medio** |

## 5. Criterio de exito
- Estaciones se ven con borde amarillo y relleno acorde al estatus.
- Leyenda muestra `Estación` de forma simplificada.
- No se observan dobles rellenos por duplicidad evidente de poligonos.
- Poligonos importados (incluyendo envolventes) abren ficha al seleccionar.
- Rosa de los vientos visible con los 4 cardinales.

## 6. Resultado / evidencia
Resultado:
- Ajustado render de estaciones y opacidades.
- Implementada deduplicacion basica de geometria en render.
- Corregido hit-test para ficha en importados.
- Agregada rosa de los vientos y simplificada etiqueta de leyenda.

## 7. Proximo paso
- Validar en datos reales si existe algun caso de geometria casi-duplicada no exacta; de ser necesario, aplicar deduplicacion topologica con tolerancia.
