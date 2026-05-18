# IMPL_09 Carga y render de GeoJSON Segmentos/Estaciones 1805

- Estado: Implementado
- Fecha: 2026-05-18
- Rama: main

## 1. Objetivo

Cargar al portal y renderizar en mapa tres archivos GeoJSON nuevos:
- SEGMENTO13_TSNL_1805.geojson
- segmento_18.geojson
- ESTACIONES_Y_EDIFICIOS_AUXILIARES_TSNL_1805.geojson

## 2. Diagnostico / contexto actual

El portal ya consumia capas GeoJSON desde assets y renderizaba geometrias en el mapa por medio de importedGeoJsonPrediosProvider.

Antes de este cambio, solo se mezclaban estas fuentes:
- TSNL_16_17.geojson
- ENVOLVENTES_P_TSNL.geojson
- ENVOLVENTES_L_TSNL.geojson

## 3. Fases

### Fase 1: Incorporacion de archivos al workspace

- Descripcion: Se copiaron los tres archivos desde Downloads hacia assets/data.
- Archivos afectados:
  - assets/data/SEGMENTO13_TSNL_1805.geojson
  - assets/data/segmento_18.geojson
  - assets/data/ESTACIONES_Y_EDIFICIOS_AUXILIARES_TSNL_1805.geojson
- Codigo clave: N/A (operacion de archivos)
- Tiempo estimado: 5 min
- Riesgo: Bajo (solo alta de archivos)

### Fase 2: Registro de assets en Flutter

- Descripcion: Se agregaron los 3 GeoJSON nuevos a pubspec.yaml para que queden incluidos en el bundle web.
- Archivos afectados:
  - pubspec.yaml
- Codigo clave:
  - assets/data/SEGMENTO13_TSNL_1805.geojson
  - assets/data/segmento_18.geojson
  - assets/data/ESTACIONES_Y_EDIFICIOS_AUXILIARES_TSNL_1805.geojson
- Tiempo estimado: 5 min
- Riesgo: Bajo (declarativo)

### Fase 3: Carga y merge en provider de capas importadas

- Descripcion: Se actualizo importedGeoJsonPrediosProvider para incluir las tres nuevas rutas dentro de la mezcla de features renderizadas.
- Archivos afectados:
  - lib/features/mapa/predios_provider.dart
- Codigo clave:
  - Lista importAssets con 6 archivos
  - Iteracion para agregar features de cada asset en mergedFeatures
- Tiempo estimado: 10 min
- Riesgo: Bajo (se conserva estructura existente de parseo)

## 4. Resumen de esfuerzo

| Fase | Tiempo estimado | Riesgo |
|---|---:|---|
| Fase 1 | 5 min | Bajo |
| Fase 2 | 5 min | Bajo |
| Fase 3 | 10 min | Bajo |
| Total | 20 min | Bajo |

## 5. Criterio de exito

- Los 3 archivos nuevos existen en assets/data.
- pubspec.yaml los declara en flutter/assets.
- importedGeoJsonPrediosProvider los lee y los integra en mergedFeatures.
- El mapa renderiza sus geometrias junto con las capas existentes.

## 6. Resultado / evidencia

- Archivos copiados correctamente a assets/data.
- Verificacion de geometria por archivo:
  - SEGMENTO13_TSNL_1805.geojson: 531 MultiPolygon
  - segmento_18.geojson: 154 MultiPolygon
  - ESTACIONES_Y_EDIFICIOS_AUXILIARES_TSNL_1805.geojson: 74 MultiPolygon
- Cambios aplicados en pubspec.yaml y lib/features/mapa/predios_provider.dart.

## 7. Proximo paso

Ejecutar en entorno local (flutter run -d chrome) para validar visualmente densidad, performance y estilo de color de las nuevas capas en distintos niveles de zoom.
