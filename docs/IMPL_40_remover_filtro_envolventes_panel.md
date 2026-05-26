# IMPL_40 - Remover filtro de envolventes del panel

- Estado: Completado
- Fecha: 2026-05-26
- Rama: main

## 1. Objetivo
Eliminar el filtro especifico de envolventes del panel de filtros avanzados para que las envolventes solo se rendericen en el mapa y no formen parte del filtrado directo.

## 2. Diagnostico / contexto actual
Se habia agregado una seccion `Envolventes` al panel con capacidad de seleccion y filtrado. Esto contradice el comportamiento esperado: las envolventes deben permanecer visibles/renderizadas, pero no ser filtrables como criterio independiente.

## 3. Fases
### Fase 1: Remover estado y activacion del filtro
- Descripcion: Eliminar estado `_selectedEnvolventes` y su participacion en el indicador de filtros activos.
- Archivos afectados:
  - `lib/features/mapa/mapa_screen.dart`
- Codigo clave:
  - eliminacion de `_selectedEnvolventes`
  - ajuste en etiqueta `Filtros avanzados *`
- Tiempo estimado: 10 min
- Riesgo: Bajo

### Fase 2: Remover UI de filtro de envolventes
- Descripcion: Quitar la seccion `Envolventes` del panel y su limpieza asociada.
- Archivos afectados:
  - `lib/features/mapa/mapa_screen.dart`
- Codigo clave:
  - eliminacion de `_countSectionMulti(title: 'Envolventes', ...)`
- Tiempo estimado: 10 min
- Riesgo: Bajo

### Fase 3: Remover logica de filtrado de envolventes
- Descripcion: Eliminar la condicion que filtraba `envolventes` y `nonEnvolventes` por seleccion de envolvente.
- Archivos afectados:
  - `lib/features/mapa/mapa_screen.dart`
- Codigo clave:
  - limpieza de bloque `_selectedEnvolventes.isNotEmpty`
- Tiempo estimado: 10 min
- Riesgo: Bajo

## 4. Resumen de esfuerzo
| Fase | Tiempo estimado | Riesgo |
|---|---:|---|
| Fase 1 | 10 min | Bajo |
| Fase 2 | 10 min | Bajo |
| Fase 3 | 10 min | Bajo |
| **Total** | **30 min** | **Bajo** |

## 5. Criterio de exito
- Las envolventes siguen renderizandose en el mapa.
- No existe filtro especifico de envolventes en el panel.
- El panel de filtros avanzados permanece consistente y sin errores.

## 6. Resultado / evidencia
Resultado:
- Eliminado el filtro de envolventes del panel.
- Eliminada la logica de filtrado asociada.
- Se mantiene el render permanente de envolventes en mapa.

## 7. Proximo paso
- Si se requiere exponer informacion de envolventes sin filtrarlas, mostrar sus metadatos como solo lectura en leyenda, ficha o resumen lateral, no como criterio de filtro.
