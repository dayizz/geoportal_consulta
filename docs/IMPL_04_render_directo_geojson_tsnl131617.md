# IMPL_04_render_directo_geojson_tsnl131617

- Estado: Implementado
- Fecha: 11-05-2026
- Rama: N/A (workspace sin repositorio git inicializado)

## 1. Objetivo
Renderizar directamente en el mapa los poligonos del archivo TSNL-131617.geojson importado, sin depender del backend para visualizarlos.

## 2. Diagnostico / contexto actual
Aunque el archivo estaba importado, la visualizacion podia depender del flujo de predios o filtros de proyecto.
Se requeria una capa dedicada que leyera el GeoJSON y dibujara explicitamente sus poligonos.

## 3. Fases
### Fase 1: Provider dedicado de GeoJSON importado
- Descripcion: Crear un provider especifico para cargar y exponer features del archivo TSNL-131617.geojson.
- Archivos afectados: lib/features/mapa/predios_provider.dart
- Codigo clave: GeoJsonPredioFeature + importedGeoJsonPrediosProvider
- Tiempo estimado: 15 min
- Riesgo: Bajo

### Fase 2: Render directo de poligonos en mapa
- Descripcion: Integrar la nueva capa en MapaConsultaScreen para dibujar los poligonos importados.
- Archivos afectados: lib/features/mapa/mapa_screen.dart
- Codigo clave: importedPolygons + PolygonLayer
- Tiempo estimado: 20 min
- Riesgo: Medio

### Fase 3: Geolocalizacion inicial usando capa importada
- Descripcion: Ajustar enfoque inicial del mapa para usar poligonos importados cuando no existan puntos de predios.
- Archivos afectados: lib/features/mapa/mapa_screen.dart
- Codigo clave: _ensureInitialFocus con fallback _collectImportedGeoJsonPoints
- Tiempo estimado: 10 min
- Riesgo: Bajo

## 4. Resumen de esfuerzo
| Fase | Tiempo | Riesgo |
|---|---:|---|
| Fase 1 | 15 min | Bajo |
| Fase 2 | 20 min | Medio |
| Fase 3 | 10 min | Bajo |
| Total | 45 min | Medio |

## 5. Criterio de exito
- Los poligonos del archivo TSNL-131617.geojson se dibujan en el mapa como capa dedicada.
- El mapa puede encuadrar geograficamente esos poligonos al inicio si no hay predios backend.

## 6. Resultado / evidencia
- Provider dedicado de GeoJSON importado implementado.
- Capa PolygonLayer para features importados activa en pantalla de mapa.
- Hot restart realizado sin errores de compilacion.
- Ajuste adicional de geolocalizacion: cuando no hay predios backend, el mapa se centra automaticamente en el primer poligono del archivo importado para asegurar visibilidad inmediata.
- Ajuste adicional de datos: cuando backend o Supabase responden sin registros, prediosConsultaProvider usa como fallback el GeoJSON importado para evitar contador de predios en cero.
- Ajuste adicional de navegacion visual: autoenfoque al conjunto de centroides del GeoJSON importado y boton manual "Ir a GeoJSON" para recentrar en cualquier momento.

## 7. Proximo paso
Agregar control visual (switch o etiqueta) para activar/desactivar la capa importada y mostrar conteo de features cargados.
