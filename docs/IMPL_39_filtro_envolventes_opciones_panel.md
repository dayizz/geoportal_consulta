# IMPL_39 - Filtro de envolventes en opciones del panel

- Estado: Completado
- Fecha: 2026-05-26
- Rama: main

## 1. Objetivo
Hacer que la informacion detectada de las envolventes aparezca en las opciones del panel de filtros avanzados y que pueda aplicarse al filtrado del mapa.

## 2. Diagnostico / contexto actual
Las envolventes se excluian al construir la lista `importedOperative`, por lo que sus metadatos no aparecian en las opciones del panel.
Adicionalmente, no existia un selector dedicado para el campo `ENVOLVENTE`.

## 3. Fases
### Fase 1: Incorporar metadatos de envolventes en opciones
- Descripcion: Incluir features de envolventes en el conteo de `Tipo de proyecto` y construir conteo especifico para `ENVOLVENTE`.
- Archivos afectados:
  - `lib/features/mapa/mapa_screen.dart`
- Codigo clave:
  - `importedWithEnvolventes`
  - `envolventeCounts`
  - `_getEnvolventeFromFeature(...)`
- Tiempo estimado: 20 min
- Riesgo: Bajo

### Fase 2: Agregar seccion de filtro Envolventes
- Descripcion: Crear seccion `Envolventes` dentro del panel avanzado con chips seleccionables.
- Archivos afectados:
  - `lib/features/mapa/mapa_screen.dart`
- Codigo clave:
  - `_selectedEnvolventes`
  - `_countSectionMulti(title: 'Envolventes', ...)`
- Tiempo estimado: 15 min
- Riesgo: Bajo

### Fase 3: Aplicar filtro real al mapa
- Descripcion: Conectar la seleccion de envolventes con `_applyAllImportedFilters`.
- Archivos afectados:
  - `lib/features/mapa/mapa_screen.dart`
- Codigo clave:
  - filtro sobre `envolventes` y `nonEnvolventes` usando `_selectedEnvolventes`
- Tiempo estimado: 15 min
- Riesgo: Bajo

## 4. Resumen de esfuerzo
| Fase | Tiempo estimado | Riesgo |
|---|---:|---|
| Fase 1 | 20 min | Bajo |
| Fase 2 | 15 min | Bajo |
| Fase 3 | 15 min | Bajo |
| **Total** | **50 min** | **Bajo** |

## 5. Criterio de exito
- La informacion detectada de envolventes aparece en las opciones del panel.
- Existe filtro especifico para `ENVOLVENTE`.
- Al seleccionar el filtro, el mapa aplica el criterio correspondiente.

## 6. Resultado / evidencia
Resultado:
- Agregada seccion `Envolventes` al panel de filtros avanzados.
- Incluidos metadatos de envolventes en `Tipo de proyecto`.
- Filtro de envolventes conectado al render de features importadas.

## 7. Proximo paso
- Si aparecen mas atributos en futuros GeoJSON de envolventes, extender la misma estrategia para exponerlos como secciones adicionales del panel.
