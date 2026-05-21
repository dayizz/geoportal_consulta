# IMPL_24 Filtros avanzados: Ejidos y multiselección

**Estado:** Completado  
**Fecha:** 2026-05-20  
**Rama:** main

## 1. Objetivo
Agregar la opción de filtrar por "Ejidos" en el panel de filtros avanzados y permitir selección múltiple en todos los filtros.

## 2. Diagnóstico / contexto actual
- El filtro de "Ejidos" no estaba disponible en el panel de filtros avanzados.
- Los filtros de proyecto, municipio, estado, estatus y segmento eran excluyentes (solo uno a la vez).

## 3. Fases
### Fase 1: Filtro de Ejidos siempre visible
- Descripción: Se agregó una sección de "Ejidos" en el panel de filtros avanzados, visible siempre que haya datos.
- Archivos afectados: `lib/features/mapa/mapa_screen.dart`
- Código clave: `_multiSelectCountSection` para ejidos.
- Tiempo estimado: 10 min
- Riesgo: Bajo

### Fase 2: Selección múltiple en todos los filtros
- Descripción: Se modificaron todos los filtros (proyecto, municipio, estado, estatus, segmento, ejidos) para permitir seleccionar más de una opción simultáneamente.
- Archivos afectados: `lib/features/mapa/mapa_screen.dart`
- Código clave: uso de listas para almacenar selecciones y lógica de filtrado múltiple.
- Tiempo estimado: 20 min
- Riesgo: Bajo

### Fase 3: Limpieza de filtros
- Descripción: El botón "Limpiar" ahora borra todas las selecciones múltiples.
- Archivos afectados: `lib/features/mapa/mapa_screen.dart`
- Tiempo estimado: 5 min
- Riesgo: Bajo

## 4. Resumen de esfuerzo
| Fase | Tiempo | Riesgo |
|---|---:|---|
| Filtro Ejidos | 10 min | Bajo |
| Multiselección | 20 min | Bajo |
| Limpieza | 5 min | Bajo |
| **Total** | **35 min** | **Bajo** |

## 5. Criterio de éxito
- El panel de filtros avanzados muestra siempre la sección de "Ejidos".
- Es posible seleccionar múltiples valores en todos los filtros.
- El filtrado en el mapa responde correctamente a la selección múltiple.
- El botón "Limpiar" borra todas las selecciones.

## 6. Resultado / evidencia
- UI de filtros avanzados con chips multiselección para todos los campos.
- Filtro de ejidos funcional y siempre visible.
- Sin errores de compilación.

## 7. Próximo paso
- Validar con usuarios finales y ajustar UX si es necesario.
