# IMPL_48 - Ficha de segmento 18 con campos expandida

- Estado: Completado
- Fecha: 2026-05-26
- Rama: main

## 1. Objetivo
Corregir la ficha de información para que los polígonos del segmento 18 muestren sus propiedades reales y no se perciban como vacíos.

## 2. Diagnostico / contexto actual
El segmento 18 trae propiedades adicionales o más representativas que las que originalmente mostraba la ficha.
En varios polígonos del archivo `TSN_SEG_18.geojson`, campos como propietario, municipio, estado, estructura, tipo de propiedad, M2, anuencia y nuevo sí existen en los datos, pero no se visualizaban en la ficha.

## 3. Fases
### Fase 1: Expandir la ficha importada
- Descripcion: Agregar campos relevantes del segmento 18 a la ficha de `GeoJsonPredioFeature`.
- Archivos afectados:
  - `lib/features/mapa/mapa_screen.dart`
- Codigo clave:
  - `_buildDetailPanelForImportedFeature(...)`
- Tiempo estimado: 20 min
- Riesgo: Bajo

### Fase 2: Robustecer deteccion de propiedades
- Descripcion: Usar lookup flexible para soportar claves con espacios, puntos, acentos y variantes de nombre.
- Archivos afectados:
  - `lib/features/mapa/mapa_screen.dart`
- Codigo clave:
  - `_readFeatureProperty(...)`
  - `_readFeatureFlagValue(...)`
  - `_normalizeYesNoValue(...)`
- Tiempo estimado: 15 min
- Riesgo: Bajo

## 4. Resumen de esfuerzo
| Fase | Tiempo estimado | Riesgo |
|---|---:|---|
| Fase 1 | 20 min | Bajo |
| Fase 2 | 15 min | Bajo |
| **Total** | **35 min** | **Bajo** |

## 5. Criterio de exito
- La ficha del segmento 18 muestra datos cuando el GeoJSON sí los trae.
- Los campos de tipo bandera se presentan normalizados a `Sí/No`.
- El panel no depende de una sola clave exacta para leer propiedades.

## 6. Resultado / evidencia
Resultado:
- Se ampliaron los campos visibles para el segmento 18.
- Se reforzó la lectura de propiedades con alias flexibles.

## 7. Proximo paso
- Probar uno o dos polígonos concretos del segmento 18 en el mapa y verificar que la ficha ya muestre propietario, tipo de propiedad, M2 y banderas.
