# IMPL_27_fix_deduplicacion_predios_envolvente

- Estado: Completado
- Fecha: 2026-05-25
- Rama: main

## 1. Objetivo
Corregir la deduplicacion de features GeoJSON para evitar que desaparezcan predios o envolventes validos en el mapa.

## 2. Diagnostico / contexto actual
La deduplicacion se realizaba usando solo la geometria serializada (`jsonEncode(geometry)`).
Esto podia eliminar features validas de distintos datasets cuando compartian geometria identica, provocando que no se mostraran todos los predios y/o envolventes.

## 3. Fases
### Fase 1: Analisis de carga de assets
- Descripcion: validacion de que los GeoJSON existen y siguen registrados en assets.
- Archivos afectados: pubspec.yaml, assets/data/
- Codigo clave: importedGeoJsonPrediosProvider
- Tiempo estimado: 10 min
- Riesgo: Bajo

### Fase 2: Ajuste de deduplicacion
- Descripcion: se cambio el criterio de deduplicacion para usar `tipo + source_asset + geometria`.
- Archivos afectados: lib/features/mapa/mapa_screen.dart
- Codigo clave: _applyAllImportedFilters
- Tiempo estimado: 15 min
- Riesgo: Medio

### Fase 3: Validacion tecnica
- Descripcion: compilacion web para confirmar que la correccion no rompe build.
- Archivos afectados: N/A
- Codigo clave: N/A
- Tiempo estimado: 10 min
- Riesgo: Bajo

## 4. Resumen de esfuerzo
| Fase | Tiempo | Riesgo |
|---|---:|---|
| Analisis de assets | 10 min | Bajo |
| Ajuste de deduplicacion | 15 min | Medio |
| Validacion build | 10 min | Bajo |
| Total | 35 min | Medio |

## 5. Criterio de exito
- Predios y envolventes de distintos archivos no se eliminan entre si por compartir geometria.
- Solo se eliminan duplicados exactos dentro del mismo tipo/origen.

## 6. Resultado / evidencia
- Correccion aplicada en `lib/features/mapa/mapa_screen.dart`.
- Criterio de deduplicacion robustecido con clave compuesta.

## 7. Proximo paso
- Publicar cambios y validar en ambiente desplegado que se visualizan todos los predios y la envolvente.
