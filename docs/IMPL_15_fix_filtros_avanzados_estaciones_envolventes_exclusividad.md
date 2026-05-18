# IMPL_15 Fix Filtros Avanzados: Estaciones, Envolventes, Exclusividad

Estado: Completado
Fecha: 2026-05-18
Rama: main
Commit: 407272ebaa9b07cc88dd57b16dd54c0e6aba55f9

## 1. Objetivo
Corregir 3 problemas en la función "Filtros avanzados":
1. Falsos positivos en detección de estaciones (polígonos no estaciones marcados como tales)
2. Envolventes desaparecían al aplicar filtros de contexto (municipio/estado)
3. Permitía seleccionar múltiples filtros simultáneamente; hacerlos mutuamente excluyentes

## 2. Diagnóstico / contexto actual
- Detección de estaciones buscaba "estacion" o "estación" en CUALQUIER propiedad/clave → falsos positivos en otros archivos
- Lógica de filtrado de importados excluía envolventes cuando municipio/estado estaban activos
- UI permitía N filtros activos; se necesita UNO a la vez en cada categoría (Estatus/Segmento/Municipio/Estado)

## 3. Fases

### Fase 1: Detección robusta de estaciones
- Descripción: limitar detección a archivo específico ESTACIONES_Y_EDIFICIOS_AUXILIARES_TSNL_1805.geojson
- Archivos afectados: `lib/features/mapa/predios_provider.dart` (línea 578)
- Código clave:
  ```dart
  final hasEstacionProp = sourceAsset.contains('estaciones_y_edificios');
  ```
- Tiempo estimado: 5 min
- Riesgo: Bajo

### Fase 2: Envolventes siempre visibles
- Descripción: refactorizar _applyAllImportedFilters para separar envolventes (siempre + contenido filtrado), excepto con "Solo Estaciones"
- Archivos afectados: `lib/features/mapa/mapa_screen.dart`
- Código clave:
  - Separar envolventes al inicio de filtrado
  - Retornar `[...filtered, ...envolventes]` (excepto cuando Solo Estaciones)
- Tiempo estimado: 10 min
- Riesgo: Bajo

### Fase 3: Filtros mutuamente excluyentes
- Descripción: actualizar callbacks de chips (Estatus/Segmento/Municipio/Estado) para limpiar otros filtros de contexto
- Archivos afectados: `lib/features/mapa/mapa_screen.dart`
- Código clave: al seleccionar uno, asignar `_LiberacionFilter.todos`, `_segmentoQuery = ''`, etc.
- Tiempo estimado: 10 min
- Riesgo: Bajo

### Fase 4: Compilación y validación
- Descripción: compilar Flutter Web y verificar sin errores
- Archivos afectados: `build/web/` (generado)
- Comando: `flutter build web`
- Tiempo estimado: 20 min
- Riesgo: Bajo

## 4. Resumen de esfuerzo

| Fase | Tiempo | Riesgo |
|---|---:|---|
| Detección robusta de estaciones | 5 min | Bajo |
| Envolventes siempre visibles | 10 min | Bajo |
| Filtros mutuamente excluyentes | 10 min | Bajo |
| Compilación y validación | 20 min | Bajo |
| Total | 45 min | Bajo |

## 5. Criterio de éxito
- Al activar "Solo Estaciones": solo 74 features visibles (ESTACIONES_Y_EDIFICIOS_AUXILIARES)
- Envolventes no desaparecen al seleccionar Municipio/Estado (sí desaparecen con "Solo Estaciones")
- Al tocar Estatus → se limpian Segmento/Municipio/Estado automáticamente
- Compilación sin errores

## 6. Resultado / evidencia
- Detección de estaciones ahora usa sourceAsset.contains('estaciones_y_edificios')
- _applyAllImportedFilters refactorizado para mantener envolventes en lista separada
- Callbacks de filtros actualizados para exclusividad (seleccionar uno limpia otros)
- Build web completado sin errores
- Commit: 407272ebaa9b07cc88dd57b16dd54c0e6aba55f9

## 7. Próximo paso
GitHub Actions desplegará cambios en https://dayizz.github.io/geoportal_consulta/ (2-3 minutos).
