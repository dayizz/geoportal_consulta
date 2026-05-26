# IMPL_44 - Ficha enriquecida y rosa de vientos estrella alargada

- Estado: Completado
- Fecha: 2026-05-26
- Rama: main

## 1. Objetivo
Corregir dos puntos funcionales y visuales:
- Recuperar prioridad de la ficha enriquecida (GeoJSON importado con KM y campos adicionales).
- Redisenar la rosa de los vientos a una estrella tradicional alargada.

## 2. Diagnostico / contexto actual
Tras ajustes previos de seleccion por traslape, la prioridad de clic habia pasado a predio base, mostrando en varios casos una ficha percibida como version anterior.
Adicionalmente, la rosa de los vientos se mostraba con una estrella simple, no alargada.

## 3. Fases
### Fase 1: Prioridad de ficha enriquecida
- Descripcion: Al detectar traslape, priorizar `tappedImported` sobre `tappedPredio`.
- Archivos afectados:
  - `lib/features/mapa/mapa_screen.dart`
- Codigo clave:
  - `onTap`: prioridad a `_selectedImportedFeature` cuando existe.
- Tiempo estimado: 10 min
- Riesgo: Bajo

### Fase 2: Rosa de vientos en estrella alargada
- Descripcion: Sustituir composicion simple por estrella de 8 puntas con jerarquia de puntas (N/S largas, E/O medias, diagonales cortas).
- Archivos afectados:
  - `lib/features/mapa/mapa_screen.dart`
- Codigo clave:
  - `_buildCompassRose()` con helper `spike(...)` y rotaciones.
- Tiempo estimado: 20 min
- Riesgo: Bajo

## 4. Resumen de esfuerzo
| Fase | Tiempo estimado | Riesgo |
|---|---:|---|
| Fase 1 | 10 min | Bajo |
| Fase 2 | 20 min | Bajo |
| **Total** | **30 min** | **Bajo** |

## 5. Criterio de exito
- En traslape, se visualiza la ficha importada con campos de KM y metadatos enriquecidos.
- La rosa de los vientos se observa como estrella tradicional alargada con cardinales.

## 6. Resultado / evidencia
Resultado:
- Restituida prioridad de ficha enriquecida en seleccion de mapa.
- Reemplazada rosa por estrella alargada de ocho puntas.

## 7. Proximo paso
- Ajustar fino de tamano/contraste de puntas segun fondo satelital para mejorar legibilidad en pantallas pequenas.
