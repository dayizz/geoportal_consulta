# IMPL_46 - Seleccion tolerante y ficha con propiedades flexibles

- Estado: Completado
- Fecha: 2026-05-26
- Rama: main

## 1. Objetivo
Corregir dos fallos de experiencia en la capa de geometrías:
- Algunos polígonos no se dejaban seleccionar con precisión táctil normal.
- La ficha de información dejaba campos vacíos aunque el GeoJSON sí contenía datos equivalentes.

## 2. Diagnostico / contexto actual
El hit-test dependía únicamente de que el punto tocado quedara dentro del polígono exacto. En polígonos pequeños, angostos o con bordes difíciles, el usuario percibía que no eran seleccionables.

La ficha de información estaba leyendo varias propiedades con claves demasiado exactas. Cuando el GeoJSON traía variantes de nombre, mayúsculas distintas o separadores diferentes, el panel mostraba campos vacíos.

## 3. Fases
### Fase 1: Seleccion tolerante por proximidad
- Descripcion: Mantener el hit-test exacto y agregar un fallback por cercanía al centroide cuando el toque cae muy cerca del polígono.
- Archivos afectados:
  - `lib/features/mapa/mapa_screen.dart`
- Codigo clave:
  - `_findPredioAtPoint(...)`
  - `_findImportedFeatureAtPoint(...)`
  - `_tapSelectionTolerance()`
- Tiempo estimado: 20 min
- Riesgo: Medio

### Fase 2: Lectura flexible de propiedades
- Descripcion: Crear un extractor de propiedades que soporte claves exactas, mayúsculas/minúsculas y grupos de fragmentos, para rellenar la ficha aunque el nombre del campo cambie.
- Archivos afectados:
  - `lib/features/mapa/mapa_screen.dart`
- Codigo clave:
  - `_readFeatureProperty(...)`
  - `_readFeatureFlagValue(...)`
  - `_getClaveFromFeature(...)`
  - `_getEstatusFromFeature(...)`
  - `_getSegmentoFromFeature(...)`
  - `_getKmInicioFromFeature(...)`
  - `_getKmFinFromFeature(...)`
  - `_getTipoPropiedadFromFeature(...)`
- Tiempo estimado: 30 min
- Riesgo: Medio

## 4. Resumen de esfuerzo
| Fase | Tiempo estimado | Riesgo |
|---|---:|---|
| Fase 1 | 20 min | Medio |
| Fase 2 | 30 min | Medio |
| **Total** | **50 min** | **Medio** |

## 5. Criterio de exito
- Los polígonos pequeños o de geometría angosta responden al tap con mayor consistencia.
- La ficha muestra valores cuando el dato existe bajo variantes razonables de nombre de propiedad.
- No se rompen los campos ya funcionando con claves exactas.

## 6. Resultado / evidencia
Resultado:
- Se amplió el criterio de selección sin eliminar el hit-test exacto.
- Se rellenan campos de la ficha usando claves flexibles y derivados funcionales.

## 7. Proximo paso
- Probar en datos reales si existen otras variantes de claves no cubiertas y agregar alias adicionales solo si aparecen casos concretos.
