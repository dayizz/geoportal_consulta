# IMPL_38 - Calibracion de densidad de etiquetas por zoom

- Estado: Completado
- Fecha: 2026-05-26
- Rama: main

## 1. Objetivo
Ajustar la densidad de etiquetas del mapa para reducir saturacion visual en zoom 15-16 y conservar mayor detalle a partir de zoom 17.

## 2. Diagnostico / contexto actual
Despues de extender la persistencia de etiquetas hasta zoom cercano, las capas de transporte y lugares quedaban activas al mismo tiempo desde zoom 15, generando mayor carga visual de la necesaria en acercamientos intermedios.

## 3. Fases
### Fase 1: Mantener vias en zoom cercano
- Descripcion: Conservar la capa de calles/avenidas en zoom 15-23.
- Archivos afectados:
  - `lib/features/mapa/mapa_screen.dart`
- Codigo clave:
  - `showStreetLabels = _currentZoom >= 15 && _currentZoom <= 23`
- Tiempo estimado: 5 min
- Riesgo: Bajo

### Fase 2: Retrasar nombres de lugares para reducir saturacion
- Descripcion: Activar la capa adicional de lugares/nombres a partir de zoom 17 en vez de 15.
- Archivos afectados:
  - `lib/features/mapa/mapa_screen.dart`
- Codigo clave:
  - `showNeighborhoodLabels = _currentZoom >= 17 && _currentZoom <= 23`
- Tiempo estimado: 10 min
- Riesgo: Bajo

## 4. Resumen de esfuerzo
| Fase | Tiempo estimado | Riesgo |
|---|---:|---|
| Fase 1 | 5 min | Bajo |
| Fase 2 | 10 min | Bajo |
| **Total** | **15 min** | **Bajo** |

## 5. Criterio de exito
- En zoom 15-16 se ven calles/avenidas sin saturacion excesiva de nombres adicionales.
- En zoom 17+ se recupera mayor detalle de rotulacion.

## 6. Resultado / evidencia
Resultado:
- Reducida la superposicion de capas de etiquetas en zoom intermedio.
- Conservada la visibilidad de vias en zoom cercano.
- Recuperado detalle progresivo a partir de zoom 17.

## 7. Proximo paso
- Si se requiere una calibracion mas fina, separar zoom 17-18 de 19-23 con servicios de referencia diferenciados o ajustes de opacidad por capa.
