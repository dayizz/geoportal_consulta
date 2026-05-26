# IMPL_49 - Ficha cabecera con clave y sin texto Feature GeoJSON

- Estado: Completado
- Fecha: 2026-05-26
- Rama: main

## 1. Objetivo
Ajustar la cabecera de la ficha de información para:
- Mostrar la clave detectada en propiedades como identificador principal.
- Eliminar el texto "Feature GeoJSON".

## 2. Diagnostico / contexto actual
La cabecera mostraba un rótulo genérico ("Feature GeoJSON") y en la línea principal un identificador que no siempre priorizaba la clave de negocio esperada por usuario.

## 3. Fases
### Fase 1: Ajuste de cabecera de ficha
- Descripcion: usar `_getClaveFromFeature(props)` como valor principal de cabecera, con fallback a `feature.id` si no hay clave.
- Archivos afectados:
  - `lib/features/mapa/mapa_screen.dart`
- Codigo clave:
  - `_buildDetailPanelForImportedFeature(...)`
- Tiempo estimado: 10 min
- Riesgo: Bajo

## 4. Resumen de esfuerzo
| Fase | Tiempo estimado | Riesgo |
|---|---:|---|
| Fase 1 | 10 min | Bajo |
| **Total** | **10 min** | **Bajo** |

## 5. Criterio de exito
- La cabecera ya no muestra "Feature GeoJSON".
- El texto principal de cabecera muestra la clave detectada cuando existe.

## 6. Resultado / evidencia
Resultado:
- Cabecera simplificada y centrada en la clave del polígono.

## 7. Proximo paso
- Verificar visualmente en un par de polígonos sin `CLAVE` para confirmar fallback correcto a `feature.id`.
