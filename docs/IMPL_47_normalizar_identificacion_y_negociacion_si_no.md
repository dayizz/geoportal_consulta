# IMPL_47 - Normalizar identificacion y negociacion a Si/No

- Estado: Completado
- Fecha: 2026-05-26
- Rama: main

## 1. Objetivo
Normalizar los valores de Identificación y Negociación para que la ficha y la lógica interna trabajen con `Sí/No` en lugar de `true/false`.

## 2. Diagnostico / contexto actual
Algunos GeoJSON traían estas banderas como booleanos, otras como texto, y en ciertos casos con variantes como `si`, `sí`, `true`, `false`, `1` o `0`.

Esto podía producir inconsistencia visual en la ficha y en la interpretación de datos de gestión.

## 3. Fases
### Fase 1: Normalizacion de banderas
- Descripcion: Convertir cualquier variante booleana a `Sí/No` en la lectura de propiedades y mantener la lógica interna compatible con texto y booleanos.
- Archivos afectados:
  - `lib/features/mapa/mapa_screen.dart`
- Codigo clave:
  - `_normalizeYesNoValue(...)`
  - `_readFeatureFlagValue(...)`
  - `_isValueTrue(...)`
- Tiempo estimado: 20 min
- Riesgo: Bajo

## 4. Resumen de esfuerzo
| Fase | Tiempo estimado | Riesgo |
|---|---:|---|
| Fase 1 | 20 min | Bajo |
| **Total** | **20 min** | **Bajo** |

## 5. Criterio de exito
- La ficha muestra `Sí` o `No` para Identificación y Negociación.
- La lógica de checklist sigue funcionando con valores booleanos o textuales.
- No aparecen errores de análisis.

## 6. Resultado / evidencia
Resultado:
- Las banderas se normalizan a formato legible para el usuario.
- Se preserva compatibilidad con datos heterogéneos.

## 7. Proximo paso
- Si aparecen nuevos campos con el mismo problema, reutilizar el mismo normalizador para no duplicar lógica.
