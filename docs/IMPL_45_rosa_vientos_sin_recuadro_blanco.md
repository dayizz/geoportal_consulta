# IMPL_45 - Rosa de vientos sin recuadro blanco

- Estado: Completado
- Fecha: 2026-05-26
- Rama: main

## 1. Objetivo
Mantener el estilo de rosa de vientos tipo estrella alargada, eliminando el recuadro blanco de fondo.

## 2. Diagnostico / contexto actual
La rosa se renderizaba dentro de un `Container` con fondo blanco semitransparente, borde redondeado y sombra, lo que generaba un bloque visual no deseado sobre el mapa.

## 3. Fases
### Fase 1: Eliminar fondo de contenedor
- Descripcion: Reemplazar el `Container` de la rosa por `SizedBox` y conservar un `Padding` interno, sin `decoration` de fondo/sombra.
- Archivos afectados:
  - `lib/features/mapa/mapa_screen.dart`
- Codigo clave:
  - `_buildCompassRose()`
- Tiempo estimado: 10 min
- Riesgo: Bajo

## 4. Resumen de esfuerzo
| Fase | Tiempo estimado | Riesgo |
|---|---:|---|
| Fase 1 | 10 min | Bajo |
| **Total** | **10 min** | **Bajo** |

## 5. Criterio de exito
- La rosa mantiene el estilo estrella alargada.
- No existe recuadro blanco ni sombra detras de la rosa.

## 6. Resultado / evidencia
Resultado:
- Rosa de vientos renderizada sin contenedor visual de fondo.
- Se conserva legibilidad y distribucion de cardinales.

## 7. Proximo paso
- Ajustar color/contraste de letras cardinales segun fondo satelital si se requiere mayor legibilidad.
