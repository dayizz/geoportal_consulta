# IMPL_25_mejoras_filtros_geojson_dinamico_y_fichas

- Estado: Completado
- Fecha: 2026-05-25
- Rama: main

## 1. Objetivo
Implementar mejoras de robustez del geoportal para soportar cambios continuos de archivos GeoJSON, mejorar visualizacion por estatus, evitar superposiciones por duplicidad y estandarizar contenido de fichas de informacion.

## 2. Diagnostico / contexto actual
Se detectaron problemas funcionales en la capa de importacion/render de GeoJSON:
- Dependencia de nombres fijos de archivos GeoJSON.
- Visualizacion no diferenciada para estatus NEGOCIACION.
- Posibles superposiciones por geometrias duplicadas.
- Fichas con campos incompletos o condicionales.
- Flujo de publicacion bloqueado por rebase pendiente y conflictos.

## 3. Fases

### Fase 1: Carga dinamica de GeoJSON
- Descripcion: se cambio la carga de assets para detectar todos los .geojson presentes en assets/data desde AssetManifest.json.
- Archivos afectados: lib/features/mapa/predios_provider.dart
- Codigo clave: importedGeoJsonPrediosProvider
- Tiempo estimado: 20 min
- Riesgo: Medio

### Fase 2: Coloreo por estatus NEGOCIACION
- Descripcion: se agrego regla de color amarillo para features con estatus NEGOCIACION en render de poligonos importados.
- Archivos afectados: lib/features/mapa/mapa_screen.dart
- Codigo clave: fillColor para importedPolygons
- Tiempo estimado: 10 min
- Riesgo: Bajo

### Fase 3: Deteccion de duplicados por geometria
- Descripcion: se implemento deduplicacion de features por hash de geometria para evitar superposicion visual.
- Archivos afectados: lib/features/mapa/mapa_screen.dart
- Codigo clave: _applyAllImportedFilters
- Tiempo estimado: 15 min
- Riesgo: Medio

### Fase 4: Fichas completas con campos obligatorios
- Descripcion: se ajusto la ficha de detalle para mostrar siempre todos los campos requeridos, dejando vacio cuando no haya valor.
- Archivos afectados: lib/features/mapa/mapa_screen.dart
- Codigo clave: _buildDetailPanelForImportedFeature
- Tiempo estimado: 20 min
- Riesgo: Bajo

### Fase 5: Publicacion y normalizacion de historial
- Descripcion: se resolvio rebase con conflictos en pubspec.yaml y predios_provider.dart, se completo push a main.
- Archivos afectados: pubspec.yaml, lib/features/mapa/predios_provider.dart
- Codigo clave: rebase/continue + push
- Tiempo estimado: 20 min
- Riesgo: Medio

## 4. Resumen de esfuerzo

| Fase | Tiempo | Riesgo |
|---|---:|---|
| Carga dinamica de GeoJSON | 20 min | Medio |
| Coloreo NEGOCIACION | 10 min | Bajo |
| Deduplicacion geometrica | 15 min | Medio |
| Fichas completas | 20 min | Bajo |
| Publicacion y rebase | 20 min | Medio |
| Total | 85 min | Medio |

## 5. Criterio de exito
- El sistema carga cualquier archivo .geojson agregado en assets/data sin depender del nombre.
- Features con estatus NEGOCIACION se muestran en amarillo.
- No se dibujan poligonos duplicados por geometria.
- La ficha muestra: PROYECTO, CLAVE, SEGMENTO, ESTATUS, KM INICIO, KM FIN, KM LINEALES, COP, IDENTIFICACION, LEVANTAMIENTO, NEGOCIACION, OBSERVACIONES.
- Los cambios quedan publicados en main con push exitoso.

## 6. Resultado / evidencia
- Rebase completado exitosamente y rama actualizada.
- Push exitoso a origin/main: 03595cb..cb61769.
- Archivo de documentacion agregado en docs/.

## 7. Proximo paso
- Verificar en GitHub Actions la corrida del workflow de deploy asociada al commit cb61769.
- Validar en produccion que los filtros y fichas reflejan las reglas nuevas.
