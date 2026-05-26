# IMPL_33 - Fix conteo de estaciones en filtros avanzados

- Estado: Completado
- Fecha: 2026-05-26
- Rama: main

## 1. Objetivo
Corregir el panel de filtros avanzados para que detecte y muestre correctamente la cantidad de estaciones disponibles, y evitar que el filtro "Solo Estaciones" dependa de una detección fragil por nombre exacto de archivo.

## 2. Diagnostico / contexto actual
El conteo de estaciones mostraba `0` aunque existian estaciones en el dataset.

Causa raiz encontrada:
- En el panel de filtros se construia `importedOperative` excluyendo estaciones (`!f.esEstacion`) y luego el conteo se calculaba sobre esa misma lista, por lo que siempre daba 0.
- La bandera `esEstacion` se detectaba solo con `sourceAsset.contains('estaciones_y_edificios')`, lo cual es sensible a variaciones de naming.
- Los predios de capa base con metadato de estacion (por tipo/clasificacion) no se contemplaban en `Solo Estaciones` porque `_applyAllFilters` devolvia lista vacia cuando el switch estaba activo.

## 3. Fases
### Fase 1: Correccion de conteo en panel
- Descripcion: Cambiar el origen del conteo para incluir features de estaciones no envolventes.
- Archivos afectados:
  - `lib/features/mapa/mapa_screen.dart`
- Codigo clave:
  - `estacionesCount = importedFeatures.where((f) => !f.esEnvolvente && f.esEstacion).length;`
- Tiempo estimado: 15 min
- Riesgo: Bajo

### Fase 2: Robustecer deteccion de estaciones
- Descripcion: Incorporar heuristica de deteccion por nombre de fuente y por propiedades del feature (ej. `ESTRUCTURA`).
- Archivos afectados:
  - `lib/features/mapa/predios_provider.dart`
  - `lib/features/mapa/mapa_screen.dart`
- Codigo clave:
  - `_normalizeForMatch(...)`
  - `_isStationFeature(...)`
  - `_isPredioStation(...)`
  - Uso de `_isStationFeature` al crear `GeoJsonPredioFeature`.
  - Fallback en UI para conteo y filtrado de estaciones cuando `esEstacion` venga incompleto.
- Tiempo estimado: 25 min
- Riesgo: Bajo-Medio

### Fase 3: Validacion tecnica
- Descripcion: Verificar que no existan errores en los archivos modificados.
- Archivos afectados:
  - `lib/features/mapa/mapa_screen.dart`
  - `lib/features/mapa/predios_provider.dart`
- Codigo clave: Revision por analisis de errores del editor.
- Tiempo estimado: 10 min
- Riesgo: Bajo

## 4. Resumen de esfuerzo
| Fase | Tiempo estimado | Riesgo |
|---|---:|---|
| Fase 1 | 15 min | Bajo |
| Fase 2 | 25 min | Bajo-Medio |
| Fase 3 | 10 min | Bajo |
| **Total** | **50 min** | **Bajo-Medio** |

## 5. Criterio de exito
- El texto "X estaciones disponibles" muestra un valor mayor a 0 cuando hay estaciones en los assets.
- El switch "Solo Estaciones" muestra en mapa solo estaciones (mas envolventes visibles) de forma consistente.
- No se introducen errores de compilacion en los archivos tocados.

## 6. Resultado / evidencia
Resultado:
- Corregido el conteo de estaciones en el panel de filtros avanzados.
- Mejorada la deteccion de estaciones para soportar variaciones en nombre de archivo y propiedades.
- Agregado fallback de deteccion en pantalla para evitar `0` incorrecto en el contador del modal.
- Incluidos predios tipo estacion en cuantificacion y resultado del filtro `Solo Estaciones`.
- Corregido el contador inferior del panel (antes `predios visibles`) para incluir tambien features importadas no envolventes y evitar `0` engañoso.
- Verificacion sin errores en:
  - `lib/features/mapa/mapa_screen.dart`
  - `lib/features/mapa/predios_provider.dart`

## 7. Proximo paso
- Validar manualmente en UI:
  1. Abrir filtros avanzados.
  2. Confirmar conteo de estaciones > 0.
  3. Activar "Solo Estaciones" y verificar render esperado en mapa.
