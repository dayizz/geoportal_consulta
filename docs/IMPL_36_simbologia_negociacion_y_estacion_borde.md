# IMPL_36 - Simbologia de negociacion y estacion con borde

- Estado: Completado
- Fecha: 2026-05-26
- Rama: main

## 1. Objetivo
Actualizar la simbologia del mapa para:
- Mostrar negociacion en color amarillo.
- Mostrar estacion como poligono de borde amarillo sin relleno.

## 2. Diagnostico / contexto actual
La simbologia no incluia de forma explicita el color amarillo para negociacion en la leyenda y las estaciones se pintaban con relleno, lo que dificultaba su diferenciacion visual.

## 3. Fases
### Fase 1: Ajuste de color de negociacion
- Descripcion: Cambiar color de negociacion a amarillo en estado de predios.
- Archivos afectados:
  - `lib/features/mapa/mapa_screen.dart`
- Codigo clave:
  - `_colorEstado(...)` con `0xFFFFEB3B` para negociacion.
- Tiempo estimado: 10 min
- Riesgo: Bajo

### Fase 2: Estaciones con borde sin relleno
- Descripcion: Renderizar estaciones con relleno transparente y borde amarillo.
- Archivos afectados:
  - `lib/features/mapa/mapa_screen.dart`
- Codigo clave:
  - `polygonColor = isStation ? Colors.transparent : ...`
  - `borderColor` amarillo para estaciones.
- Tiempo estimado: 20 min
- Riesgo: Bajo

### Fase 3: Actualizacion de leyenda
- Descripcion: Agregar item de negociacion (amarillo) y simbolo de estacion solo borde.
- Archivos afectados:
  - `lib/features/mapa/mapa_screen.dart`
- Codigo clave:
  - item `('Negociación', Color(0xFFFFEB3B))`
  - item `Estación (solo borde)` con contenedor transparente y borde amarillo.
- Tiempo estimado: 10 min
- Riesgo: Bajo

## 4. Resumen de esfuerzo
| Fase | Tiempo estimado | Riesgo |
|---|---:|---|
| Fase 1 | 10 min | Bajo |
| Fase 2 | 20 min | Bajo |
| Fase 3 | 10 min | Bajo |
| **Total** | **40 min** | **Bajo** |

## 5. Criterio de exito
- La leyenda muestra negociacion en amarillo.
- La leyenda muestra estacion como simbolo de solo borde amarillo.
- En el mapa, las estaciones se renderizan sin relleno y con borde amarillo.

## 6. Resultado / evidencia
Resultado:
- Simbologia de negociacion actualizada a amarillo.
- Estaciones renderizadas con borde amarillo y relleno transparente.
- Leyenda actualizada con ambos elementos.

## 7. Proximo paso
- Validar contraste visual en fondos satelital y estandar, y ajustar grosor de borde si se requiere mayor legibilidad.
