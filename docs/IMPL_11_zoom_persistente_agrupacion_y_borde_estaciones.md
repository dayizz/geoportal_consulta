# IMPL_11 Zoom persistente, agrupacion y borde de estaciones

- Estado: Implementado
- Fecha: 2026-05-18
- Rama: main

## 1. Objetivo

Ajustar la visualizacion de capas GeoJSON importadas para lograr tres comportamientos:
- Mantener visible el trazo de las capas nuevas en zoom lejano.
- Agregar agrupacion de features importadas cuando el zoom es bajo.
- Pintar borde amarillo a poligonos cuya propiedad indique estacion, respetando el color de relleno segun estatus.

## 2. Diagnostico / contexto actual

La visualizacion importada estaba condicionada por zoom alto y no tenia una representacion agrupada equivalente a la usada para predios. Ademas, el estilo no diferenciaba visualmente las estaciones en el borde.

## 3. Fases

### Fase 1: Extension del modelo importado

- Descripcion: Se agrego una bandera esEstacion al modelo GeoJsonPredioFeature.
- Archivos afectados:
  - lib/features/mapa/predios_provider.dart
- Codigo clave:
  - deteccion de la palabra estacion/estacion con acento en propiedades
- Tiempo estimado: 10 min
- Riesgo: Bajo

### Fase 2: Persistencia visual en zoom lejano

- Descripcion: Se elimino la desaparicion de detalle importado por zoom, manteniendo el render de poligonos y lineas con opacidad/ancho ajustado segun nivel de zoom.
- Archivos afectados:
  - lib/features/mapa/mapa_screen.dart
- Codigo clave:
  - render continuo de importedPolygons e importedPolylines
  - ajuste dinamico de opacidad y grosor de borde
- Tiempo estimado: 15 min
- Riesgo: Bajo

### Fase 3: Agrupacion de GeoJSON importado

- Descripcion: Se agrego agrupacion por centroides para features importadas a zoom bajo, con marcador numerico y navegacion por tap.
- Archivos afectados:
  - lib/features/mapa/mapa_screen.dart
- Codigo clave:
  - importedBucketed
  - _putPointInCountBucket
  - _buildCountMarker
- Tiempo estimado: 15 min
- Riesgo: Bajo

### Fase 4: Estilo especial para estaciones

- Descripcion: Los poligonos detectados como estacion conservan relleno por estatus, pero su borde se pinta de amarillo.
- Archivos afectados:
  - lib/features/mapa/mapa_screen.dart
  - lib/features/mapa/predios_provider.dart
- Codigo clave:
  - borderColor = amarillo para esEstacion
- Tiempo estimado: 10 min
- Riesgo: Bajo

## 4. Resumen de esfuerzo

| Fase | Tiempo estimado | Riesgo |
|---|---:|---|
| Fase 1 | 10 min | Bajo |
| Fase 2 | 15 min | Bajo |
| Fase 3 | 15 min | Bajo |
| Fase 4 | 10 min | Bajo |
| Total | 50 min | Bajo |

## 5. Criterio de exito

- Las capas importadas siguen visibles en zoom lejano.
- Existen marcadores de agrupacion para GeoJSON importado a zoom bajo.
- Las estaciones muestran borde amarillo y relleno segun estatus.
- La compilacion web es exitosa.

## 6. Resultado / evidencia

- Render importado persistente implementado.
- Agrupacion importada implementada.
- Deteccion de estaciones y borde amarillo implementados.
- Build web exitoso posterior al ajuste.

## 7. Proximo paso

Publicar el ajuste y validar visualmente en GitHub Pages el comportamiento de agrupacion y persistencia del trazo en distintos niveles de zoom.
