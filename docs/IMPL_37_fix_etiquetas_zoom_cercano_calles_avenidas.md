# IMPL_37 - Fix etiquetas en zoom cercano (calles y avenidas)

- Estado: Completado
- Fecha: 2026-05-26
- Rama: main

## 1. Objetivo
Corregir la desaparicion de etiquetas de ubicacion (calles/avenidas) al acercar el zoom del mapa.

## 2. Diagnostico / contexto actual
Las capas de etiquetas estaban acotadas al rango 15-17 y, en zoom mas cercano, se quedaban sin capas activas equivalentes de vias/lugares.
Adicionalmente, para servicios de referencia ArcGIS en zoom alto, sin `maxNativeZoom` se solicitan niveles no nativos que pueden devolver vacio.

## 3. Fases
### Fase 1: Ajuste de rango de visibilidad de etiquetas
- Descripcion: Extender visualizacion de calles y lugares hasta zoom 23.
- Archivos afectados:
  - `lib/features/mapa/mapa_screen.dart`
- Codigo clave:
  - `showStreetLabels = _currentZoom >= 15 && _currentZoom <= 23`
  - `showNeighborhoodLabels = _currentZoom >= 15 && _currentZoom <= 23`
- Tiempo estimado: 10 min
- Riesgo: Bajo

### Fase 2: Control de nivel nativo de teselas de referencia
- Descripcion: Definir `maxNativeZoom: 17` para capas de referencias de vias/lugares y permitir escalado estable en zoom cercano.
- Archivos afectados:
  - `lib/features/mapa/mapa_screen.dart`
- Codigo clave:
  - `TileLayer(World_Transportation)` con `maxNativeZoom: 17`
  - `TileLayer(World_Boundaries_and_Places)` con `maxNativeZoom: 17`
- Tiempo estimado: 15 min
- Riesgo: Bajo

### Fase 3: Limpieza de capa redundante en detalle extremo
- Descripcion: Eliminar capa duplicada de transporte en 18-23 para evitar peticiones repetidas y comportamiento inconsistente.
- Archivos afectados:
  - `lib/features/mapa/mapa_screen.dart`
- Codigo clave:
  - Eliminacion de bloque `showExtremeDetailLabels` redundante.
- Tiempo estimado: 10 min
- Riesgo: Bajo

## 4. Resumen de esfuerzo
| Fase | Tiempo estimado | Riesgo |
|---|---:|---|
| Fase 1 | 10 min | Bajo |
| Fase 2 | 15 min | Bajo |
| Fase 3 | 10 min | Bajo |
| **Total** | **35 min** | **Bajo** |

## 5. Criterio de exito
- En zoom cercano, permanecen visibles etiquetas de vias y ubicacion.
- No se pierde rotulacion al pasar de zoom 17 a niveles superiores.

## 6. Resultado / evidencia
Resultado:
- Etiquetas de calles/avenidas configuradas para mantenerse en zoom 15-23.
- Capa de referencia estabilizada con `maxNativeZoom` para evitar vacios en niveles altos.
- Eliminada duplicidad de capa extrema.

## 7. Proximo paso
- Validar visualmente en ambos fondos (estandar/satelital) en zoom 15-20 para confirmar densidad y legibilidad de rotulos.
