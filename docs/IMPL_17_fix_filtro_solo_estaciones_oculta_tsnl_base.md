# IMPL_17 Fix filtro Solo Estaciones: ocultar capa base TSNL

Estado: Completado
Fecha: 2026-05-18
Rama: main

## 1. Objetivo
Corregir que, al activar el filtro "Solo Estaciones", se sigan mostrando predios de TSNL_16_17.geojson desde la capa base.

## 2. Diagnóstico / contexto actual
El mapa renderiza dos fuentes principales:
- Capa base de predios (`List<Predio>`) cargada desde TSNL_16_17.geojson
- Capa importada (`List<GeoJsonPredioFeature>`) con lógica de `esEstacion`

Aunque la capa importada sí filtraba por estaciones, la capa base seguía pasando por `_applyAllFilters()` sin condición de `_filterSoloEstaciones`, dejando visibles polígonos de TSNL_16_17 cuando el usuario esperaba ver solo estaciones (más envolventes).

## 3. Fases

### Fase 1: Ajuste de filtro base
- Descripción: introducir retorno temprano en `_applyAllFilters` cuando `Solo Estaciones` está activo
- Archivos afectados: `lib/features/mapa/mapa_screen.dart`
- Código clave:

```dart
List<Predio> _applyAllFilters(List<Predio> predios) {
  // "Solo Estaciones" aplica a capas importadas; ocultar capa base de predios.
  if (_filterSoloEstaciones) return const [];
  ...
}
```

- Tiempo estimado: 5 min
- Riesgo: Bajo

### Fase 2: Validación técnica
- Descripción: compilar proyecto web para validar ausencia de errores
- Archivos afectados: `build/web` (generado)
- Comando: `flutter build web`
- Tiempo estimado: 10 min
- Riesgo: Bajo

## 4. Resumen de esfuerzo

| Fase | Tiempo | Riesgo |
|---|---:|---|
| Ajuste de filtro base | 5 min | Bajo |
| Validación build web | 10 min | Bajo |
| Total | 15 min | Bajo |

## 5. Criterio de éxito
- Con "Solo Estaciones" activo, la capa base TSNL_16_17 no se dibuja
- Se mantienen visibles solo estaciones importadas (y envolventes, según IMPL_16)
- Build web sin errores

## 6. Resultado / evidencia
- Archivo modificado: `lib/features/mapa/mapa_screen.dart`
- Cambio aplicado: early return en `_applyAllFilters`
- Validación: `flutter build web` exitoso

## 7. Próximo paso
Publicar en `main` y validar en GitHub Pages con recarga forzada del navegador (Ctrl+F5).
