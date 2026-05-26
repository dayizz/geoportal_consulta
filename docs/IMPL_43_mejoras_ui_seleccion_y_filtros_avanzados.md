# IMPL_43 - Mejoras de UI, seleccion y filtros avanzados

- Estado: Completado
- Fecha: 2026-05-26
- Rama: main

## 1. Objetivo
Implementar mejoras solicitadas en mapa y panel:
- Redisenar boton "Ir a GeoJSON" a icono unico con tooltip "Centrar".
- Cambiar rosa de los vientos a formato estrella.
- Mejorar seleccion de predios cuando existe traslape.
- Incrementar tamano de icono y titulo "Geoportal de Consulta" en barra superior.
- Corregir filtros avanzados para que se apliquen de forma efectiva en predios e importados.

## 2. Diagnostico / contexto actual
Se detectaron cinco puntos de mejora:
- Boton de centrado con texto extenso.
- Rosa de los vientos no acorde al estilo solicitado.
- Predios no seleccionables en traslapes con capas importadas.
- Encabezado superior con jerarquia visual limitada.
- Filtros avanzados parcialmente aplicados (varios criterios solo contaban opciones pero no filtraban resultados).

## 3. Fases
### Fase 1: Rediseno de boton de centrado
- Descripcion: Convertir "Ir a GeoJSON" a boton de icono unico y tooltip "Centrar".
- Archivos afectados:
  - `lib/features/mapa/mapa_screen.dart`
- Codigo clave:
  - `_buildFocusGeoJsonButton(...)` con `Tooltip(message: 'Centrar')`.
- Tiempo estimado: 10 min
- Riesgo: Bajo

### Fase 2: Rosa de los vientos en estrella
- Descripcion: Reemplazar ejes simples por icono estrella con marca norte y cardinales.
- Archivos afectados:
  - `lib/features/mapa/mapa_screen.dart`
- Codigo clave:
  - `_buildCompassRose()` con `Icons.star` y cardinales N/S/E/O.
- Tiempo estimado: 10 min
- Riesgo: Bajo

### Fase 3: Seleccion de predios en traslape
- Descripcion: Priorizar predio en tap cuando coincide con feature importado.
- Archivos afectados:
  - `lib/features/mapa/mapa_screen.dart`
- Codigo clave:
  - `onTap` en `MapOptions`: prioridad `tappedPredio`.
- Tiempo estimado: 10 min
- Riesgo: Bajo

### Fase 4: Jerarquia visual en barra superior
- Descripcion: Aumentar tamano de icono y titulo principal.
- Archivos afectados:
  - `lib/features/mapa/mapa_screen.dart`
- Codigo clave:
  - icono `Icons.map_rounded` 24 -> 28
  - titulo 16 -> 18
- Tiempo estimado: 5 min
- Riesgo: Bajo

### Fase 5: Correccion de filtros avanzados
- Descripcion: Aplicar en runtime los filtros que solo contaban opciones, pero no filtraban resultados.
- Archivos afectados:
  - `lib/features/mapa/mapa_screen.dart`
- Codigo clave:
  - `_applyAllFilters(...)`: agrega filtros de `Ejidos` y `Clasificación`.
  - `_applyAllImportedFilters(...)`: agrega filtros de `Tipo de proyecto`, `Ejidos` y `Clasificación`.
- Tiempo estimado: 20 min
- Riesgo: Medio

## 4. Resumen de esfuerzo
| Fase | Tiempo estimado | Riesgo |
|---|---:|---|
| Fase 1 | 10 min | Bajo |
| Fase 2 | 10 min | Bajo |
| Fase 3 | 10 min | Bajo |
| Fase 4 | 5 min | Bajo |
| Fase 5 | 20 min | Medio |
| **Total** | **55 min** | **Bajo-Medio** |

## 5. Criterio de exito
- Boton de centrado visible como icono unico con tooltip "Centrar".
- Rosa de los vientos en estilo estrella y cardinales visibles.
- Predios seleccionables en zonas de traslape.
- Encabezado superior con mayor legibilidad (icono/titulo mas grandes).
- Filtros avanzados aplicando resultados de forma consistente en capas base e importadas.

## 6. Resultado / evidencia
Resultado:
- UI de centrado simplificada y mas limpia.
- Rosa de los vientos actualizada a formato estrella.
- Mejorada seleccion de predios en interaccion por clic.
- Ajustada jerarquia visual del titulo principal.
- Filtros avanzados ahora operan sobre criterios clave en ambas fuentes de datos.

## 7. Proximo paso
- Ejecutar validacion funcional guiada (checklist de filtros por criterio) para confirmar paridad exacta entre conteos y resultados visibles en mapa.
