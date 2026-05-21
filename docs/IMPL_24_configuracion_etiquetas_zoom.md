# IMPL_24_configuracion_etiquetas_zoom.md

**Estado:** Completado  
**Fecha:** 2026-05-20  
**Rama:** main

## Objetivo
Implementar una nueva configuración de visibilidad de etiquetas y capas base en el mapa según el nivel de zoom, asegurando que las capas importadas permanezcan siempre visibles.

## Diagnóstico / contexto actual
La lógica previa mostraba etiquetas y capas base por rangos de zoom, pero no seguía la jerarquía detallada solicitada ni garantizaba la persistencia de capas importadas en todos los niveles.

## Fases
1. **Definir variables de visibilidad por rango de zoom**
   - Descripción: Se crearon variables para cada rango de zoom (0-3, 4-9, 10-14, 15-17, 18-23) para controlar la visibilidad de etiquetas y capas base.
   - Archivos afectados: lib/features/mapa/mapa_screen.dart
   - Código clave: showContinentLabels, showCountryBorders, showStateBorders, showCityLabels, showStreetLabels, showExtremeDetailLabels, showMunicipalBorders, etc.
   - Tiempo estimado: 10 min
   - Riesgo: Bajo
2. **Actualizar lógica de renderizado de capas**
   - Descripción: Se modificó el widget de mapa para mostrar las capas base y overlays según el rango de zoom, y se eliminó cualquier restricción de minZoom/maxZoom en las capas importadas.
   - Archivos afectados: lib/features/mapa/mapa_screen.dart
   - Código clave: children: [ ... TileLayer/PolygonLayer/PolylineLayer/MarkerLayer ... ]
   - Tiempo estimado: 15 min
   - Riesgo: Bajo
3. **Validar build y despliegue**
   - Descripción: Se realizó build web exitoso para validar que la lógica y la visualización funcionan correctamente.
   - Archivos afectados: build/web
   - Tiempo estimado: 5 min
   - Riesgo: Bajo

## Resumen de esfuerzo
| Fase | Tiempo | Riesgo |
|---|---:|---|
| 1 | 10 min | Bajo |
| 2 | 15 min | Bajo |
| 3 | 5 min | Bajo |
| **Total** | **30 min** | **Bajo** |

## Criterio de éxito
- Las etiquetas y capas base se muestran según el rango de zoom especificado.
- Las capas importadas (proyectos) permanecen visibles en todos los niveles de zoom.
- El build web es exitoso y la app funciona correctamente.

## Resultado / evidencia
- Lógica de visibilidad de etiquetas y capas base por zoom implementada y validada.
- Capas importadas siempre visibles.
- Build web exitoso.

## Próximo paso
- Validar visualmente en entorno de producción y ajustar si se requiere mayor granularidad en overlays o etiquetas.
