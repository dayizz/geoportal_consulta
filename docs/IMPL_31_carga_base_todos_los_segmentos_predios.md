# IMPL_31_carga_base_todos_los_segmentos_predios

- Estado: Completado
- Fecha: 2026-05-25
- Rama: main

## 1. Objetivo
Asegurar que la capa base de predios cargue todos los GeoJSON de segmentos disponibles en `assets/data/`, y no solo un archivo fijo.

## 2. Diagnostico / contexto actual
La vista principal de predios seguia dependiendo de `TSN_SEG_16_17.geojson` como unica fuente base.
Esto podia dejar fuera predios de otros archivos como `TSN_SEG_13.geojson`, `TSN_SEG_18.geojson` y `TSN_ACT_SEG_16_17.geojson`.

## 3. Fases
### Fase 1: Identificacion de fuente unica incorrecta
- Descripcion: se detecto que `_loadPrediosFromAssetGeoJson()` hacia `loadString` solo de `assets/data/TSN_SEG_16_17.geojson`.
- Archivos afectados: lib/features/mapa/predios_provider.dart
- Codigo clave: _loadPrediosFromAssetGeoJson
- Tiempo estimado: 10 min
- Riesgo: Bajo

### Fase 2: Carga dinamica de segmentos
- Descripcion: se actualizo la carga para leer `AssetManifest.json`, seleccionar todos los GeoJSON de predios y excluir municipios, envolvente y estaciones.
- Archivos afectados: lib/features/mapa/predios_provider.dart
- Codigo clave: predioAssets desde AssetManifest
- Tiempo estimado: 20 min
- Riesgo: Medio

### Fase 3: Consolidacion en una sola lista de predios
- Descripcion: se unificaron todas las features de segmentos en `allPredios` con normalizacion de propiedades y deteccion de municipio/estado.
- Archivos afectados: lib/features/mapa/predios_provider.dart
- Codigo clave: bucle sobre predioAssets y features
- Tiempo estimado: 15 min
- Riesgo: Medio

## 4. Resumen de esfuerzo
| Fase | Tiempo | Riesgo |
|---|---:|---|
| Identificacion de fuente unica | 10 min | Bajo |
| Carga dinamica de segmentos | 20 min | Medio |
| Consolidacion de predios | 15 min | Medio |
| Total | 45 min | Medio |

## 5. Criterio de exito
- La capa base de predios incluye todos los segmentos operativos presentes en `assets/data/`.
- Los predios ya no dependen de un unico archivo fijo.

## 6. Resultado / evidencia
- Correccion aplicada en `lib/features/mapa/predios_provider.dart`.
- La capa base ahora consolida multiples GeoJSON de segmentos.

## 7. Proximo paso
- Ejecutar build web, publicar commit y validar en produccion que aparecen todos los predios esperados.
