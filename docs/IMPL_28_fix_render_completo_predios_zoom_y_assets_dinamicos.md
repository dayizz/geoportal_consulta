# IMPL_28_fix_render_completo_predios_zoom_y_assets_dinamicos

- Estado: Completado
- Fecha: 2026-05-25
- Rama: main

## 1. Objetivo
Corregir la perdida visual de predios/envolvente en el mapa al alejar zoom y asegurar la carga/render de todos los GeoJSON operativos, incluyendo TSN_ACT_SEG_16_17.geojson.

## 2. Diagnostico / contexto actual
Se reportaron dos sintomas:
- Algunos poligonos se cortan o desaparecen al alejar.
- No se estaban mostrando todos los predios esperados.

Causas detectadas:
- Simplificacion geometrica agresiva en poligonos para niveles bajos de zoom.
- Falta de inclusion del archivo TSN_ACT_SEG_16_17.geojson en assets del proyecto.
- Registro de assets por nombres fijos, poco robusto ante altas/bajas de archivos.

## 3. Fases
### Fase 1: Integracion de archivo faltante
- Descripcion: se agrego TSN_ACT_SEG_16_17.geojson al directorio assets/data del proyecto.
- Archivos afectados: assets/data/TSN_ACT_SEG_16_17.geojson
- Codigo clave: N/A
- Tiempo estimado: 5 min
- Riesgo: Bajo

### Fase 2: Assets dinamicos por carpeta
- Descripcion: se reemplazo lista fija de assets por carga de carpeta completa assets/data/ en Flutter.
- Archivos afectados: pubspec.yaml
- Codigo clave: flutter.assets -> assets/data/
- Tiempo estimado: 10 min
- Riesgo: Bajo

### Fase 3: Simplificacion conservadora de poligonos
- Descripcion: se ajusto _simplifyGeometryForZoom para usar stride menos agresivo en poligonos y evitar recortes visuales.
- Archivos afectados: lib/features/mapa/mapa_screen.dart
- Codigo clave: _simplifyGeometryForZoom
- Tiempo estimado: 15 min
- Riesgo: Medio

### Fase 4: Render de features completas en modo normal
- Descripcion: se elimino exclusion por defecto de estaciones en modo normal para no ocultar features cargadas.
- Archivos afectados: lib/features/mapa/mapa_screen.dart
- Codigo clave: _applyAllImportedFilters
- Tiempo estimado: 10 min
- Riesgo: Medio

## 4. Resumen de esfuerzo
| Fase | Tiempo | Riesgo |
|---|---:|---|
| Integracion archivo faltante | 5 min | Bajo |
| Assets dinamicos por carpeta | 10 min | Bajo |
| Simplificacion conservadora | 15 min | Medio |
| Render completo modo normal | 10 min | Medio |
| Total | 40 min | Medio |

## 5. Criterio de exito
- Los predios y envolvente no desaparecen/cortan al alejar en condiciones normales.
- Se renderizan features de todos los archivos GeoJSON presentes en assets/data.
- Se incluye TSN_ACT_SEG_16_17.geojson en la carga/render.

## 6. Resultado / evidencia
- Cambios aplicados en pubspec.yaml y mapa_screen.dart.
- Integracion de TSN_ACT_SEG_16_17.geojson en assets/data.
- Build web local exitoso.

## 7. Proximo paso
- Verificar workflow de GitHub Actions del commit publicado.
- Validar visualmente en produccion con recarga forzada.
