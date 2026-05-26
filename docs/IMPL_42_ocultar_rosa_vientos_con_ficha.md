# IMPL_42 - Ocultar rosa de los vientos al abrir ficha

- Estado: Completado
- Fecha: 2026-05-26
- Rama: main

## 1. Objetivo
Mejorar la legibilidad del mapa ocultando la rosa de los vientos cuando una ficha lateral (predio o feature importado) este abierta.

## 2. Diagnostico / contexto actual
La rosa de los vientos permanecia visible aun con la ficha lateral desplegada, compitiendo visualmente con elementos de interaccion y detalle.

## 3. Fases
### Fase 1: Condicionar render de rosa de los vientos
- Descripcion: Mostrar la rosa solo cuando no exista ninguna ficha abierta.
- Archivos afectados:
  - `lib/features/mapa/mapa_screen.dart`
- Codigo clave:
  - `if (_selectedImportedFeature == null && _selectedPredio == null)`
- Tiempo estimado: 10 min
- Riesgo: Bajo

## 4. Resumen de esfuerzo
| Fase | Tiempo estimado | Riesgo |
|---|---:|---|
| Fase 1 | 10 min | Bajo |
| **Total** | **10 min** | **Bajo** |

## 5. Criterio de exito
- Con ficha cerrada: rosa de los vientos visible.
- Con ficha abierta: rosa de los vientos oculta.

## 6. Resultado / evidencia
Resultado:
- Rosa de los vientos ahora se oculta automaticamente al abrir cualquier ficha lateral.
- Comportamiento visual mas limpio durante consulta de detalle.

## 7. Proximo paso
- Opcional: agregar preferencia de usuario para fijar visibilidad de rosa independientemente del estado de ficha.
