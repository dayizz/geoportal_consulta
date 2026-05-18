# IMPL_18 Optimizacion render del mapa en zoom (lag y parches)

Estado: Completado
Fecha: 2026-05-18
Rama: main

## 1. Objetivo
Reducir el tiempo de generación del mapa al hacer zoom lejos/cerca y eliminar artefactos visuales tipo "parches" durante cambios de escala.

## 2. Diagnóstico / contexto actual
Se detectaron cuellos de botella en `mapa_screen.dart`:
- Re-procesamiento repetido de geometrías (Polygon/MultiPolygon/LineString) en cada rebuild.
- Render de geometrías densas (miles de vértices) incluso en zoom lejano.
- Rebuilds frecuentes por `onPositionChanged` en cambios pequeños de zoom.
- Merge de buckets con costo O(n^2) en escenarios con muchos clusters.

Estos cuatro puntos incrementaban tiempo de frame y provocaban parcheo visual al redibujar capas masivas durante zoom.

## 3. Fases

### Fase 1: Cache de geometrías
- Descripción: activar cache real de polígonos y polilíneas usando `GeometryCache` con llave por identidad de geometría.
- Archivo afectado: `lib/features/mapa/mapa_screen.dart`
- Código clave:
```dart
final geometryId = 'poly:${identityHashCode(geo)}';
return _geometryCache.getPolygons(geometryId, geo, (geometry) { ... });
```
- Riesgo: Bajo

### Fase 2: Simplificación por zoom (reducción de vértices)
- Descripción: introducir simplificación rápida por stride para disminuir vértices dibujados en zoom medio/lejos.
- Archivo afectado: `lib/features/mapa/mapa_screen.dart`
- Código clave:
```dart
final drawRing = _simplifyGeometryForZoom(ring, _currentZoom, isPolygon: true);
final drawLine = _simplifyGeometryForZoom(line, _currentZoom, isPolygon: false);
```
- Riesgo: Medio (se acepta menor detalle visual en zoom lejano a cambio de rendimiento)

### Fase 3: Menos rebuilds por zoom
- Descripción: actualizar estado de zoom por pasos discretos (0.5) en lugar de umbral fino.
- Archivo afectado: `lib/features/mapa/mapa_screen.dart`
- Código clave:
```dart
final nextStep = (nextZoom * 2).round();
if (nextStep != _zoomRenderStep) { setState(...); }
```
- Riesgo: Bajo

### Fase 4: Limitar merge caro de clusters
- Descripción: evitar `_mergeOverlappingBuckets` cuando hay demasiados buckets para prevenir costo cuadrático.
- Archivo afectado: `lib/features/mapa/mapa_screen.dart`
- Código clave:
```dart
if (buckets.length > 220) return buckets;
```
- Riesgo: Bajo

## 4. Resumen de esfuerzo

| Fase | Tiempo | Riesgo |
|---|---:|---|
| Cache de geometrías | 10 min | Bajo |
| Simplificación por zoom | 15 min | Medio |
| Menos rebuilds por zoom | 5 min | Bajo |
| Límite merge buckets | 5 min | Bajo |
| Validación build web | 10 min | Bajo |
| Total | 45 min | Bajo-Medio |

## 5. Criterio de éxito
- Zoom cercano/lejos más fluido, con menor tiempo de redibujo.
- Menos "parches" visuales durante el zoom.
- Build web exitoso sin errores de compilación.

## 6. Resultado / evidencia
- Archivo actualizado: `lib/features/mapa/mapa_screen.dart`
- Build validado:
  - `flutter build web` exitoso
- Impacto esperado:
  - Menor carga de CPU al renderizar geometría densa
  - Menor frecuencia de rebuild por zoom
  - Menor costo en cálculo de clusters

## 7. Próximo paso
Publicar y validar en GitHub Pages comparando fluidez:
1. Zoom out rápido a nivel lejano
2. Zoom in progresivo a nivel cercano
3. Verificar reducción de parches y latencia visual
