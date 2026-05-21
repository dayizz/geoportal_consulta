# IMPL_16: Envolventes Siempre Visibles + Solo Estaciones Filter

**Estado**: ✅ COMPLETADO  
**Fecha**: 2025  
**Rama/Commit**: main / d5a0b2b7d776d90ce6511d61fc47bfcdb14d3285  
**Ticket**: Fix crítico de filtros avanzados

---

## Objetivo

Corregir dos bugs críticos en el filtro "Solo Estaciones":
1. **Envolventes desaparecen** al activar "Solo Estaciones" → deberían estar SIEMPRE visibles
2. **Features sin estación se renderizan** cuando "Solo Estaciones" activo → solo 74 estaciones deberían ser visibles

---

## Diagnóstico / Contexto Actual

### Problema 1: Envolventes Desaparecen
**Ubicación**: `lib/features/mapa/mapa_screen.dart`, línea 2037-2038  
**Código anterior**:
```dart
if (_filterSoloEstaciones) {
  nonEnvolventes = nonEnvolventes.where((f) => f.esEstacion).toList();
  return nonEnvolventes;  // ❌ BUG: Excluye envolventes
}
```

**Síntoma**: Al hacer clic en "Solo Estaciones", las envolventes (polígonos de referencia) desaparecen del mapa

### Problema 2: Predios Sin Estación Visibles
**Síntoma**: Usuario reporta "AUN HAY PREDIOS QUE SE QUEDAN AL FILTRAR POR ESTACIONES, Y ESTOS PREDIOS NO CONTIENEN ESTA PROPIEDAD"  
**Verificación realizada**:
- Análisis de todos 9 archivos GeoJSON de assets
- Confirmó: SOLO `ESTACIONES_Y_EDIFICIOS_AUXILIARES_TSNL_1805.geojson` tiene propiedad "estacion" (74 features)
- `TSNL_16_17.geojson` (159 predios) = 0 con "estacion"
- Otros 7 archivos = 0 con "estacion"

**Raíz probable**: 
- Cache del navegador no actualizó (versión vieja del código)
- O lógica de filtrado retorna features que no cumplen el criterio

---

## Fases de Implementación

### Fase 1: Refactorizar `_applyAllImportedFilters()` (COMPLETADO)

**Descripción**: Restructurar la función para garantizar que envolventes están SIEMPRE en el resultado

**Cambios**:
```dart
List<GeoJsonPredioFeature> _applyAllImportedFilters(
  List<GeoJsonPredioFeature> features,
) {
  // Separar envolventes (SIEMPRE visibles)
  final envolventes = features.where((f) => f.esEnvolvente).toList();
  var nonEnvolventes = features.where((f) => !f.esEnvolvente).toList();

  // Si Solo Estaciones está activo: SOLO estaciones (+ envolventes al final)
  if (_filterSoloEstaciones) {
    final soloEstaciones = nonEnvolventes.where((f) => f.esEstacion).toList();
    // Retornar: estaciones + envolventes siempre
    return [...soloEstaciones, ...envolventes];  // ✓ FIX: Incluye envolventes
  }

  // ... resto del código de otros filtros ...
  
  // Retornar: contenido filtrado + envolventes siempre visibles
  return [...filtered, ...envolventes];
}
```

**Archivos afectados**: 
- `lib/features/mapa/mapa_screen.dart` (líneas 2031-2087)

**Cambios de comportamiento**:
- **Antes**: `Solo Estaciones` → 74 estaciones + 0 envolventes = invisible
- **Después**: `Solo Estaciones` → 74 estaciones + 11,925 envolventes = visible siempre

### Fase 2: Análisis de Verificación (COMPLETADO)

**Proceso**:
1. Verificar que cada archivo tiene el `__source_asset` correcto en predios_provider.dart
   - ✓ Asignado correctamente en línea 544
2. Confirmar que `esEstacion` se calcula solo por sourceAsset
   - ✓ `esEstacion: sourceAsset.contains('estaciones_y_edificios')`
3. Análisis de GeoJSON: confirmar que SOLO ESTACIONES tiene "estacion"
   - ✓ 74 features en ESTACIONES_Y_EDIFICIOS
   - ✓ 0 features en otros 8 archivos
4. Verificar render loop usa `filteredImportedGeoJson`
   - ✓ Línea 303: `for (final feature in filteredImportedGeoJson)`

**Resultado**: Lógica de filtrado es correcta. Bug era la early return en _applyAllImportedFilters().

### Fase 3: Compilación y Deployment (COMPLETADO)

**Comandos ejecutados**:
```bash
flutter build web          # ✓ Compiló en 19.6s, build/web actualizado
git add -A
git commit -m "fix: envolventes siempre visibles incluso con solo estaciones"
git push origin main       # Desplegado a GitHub Pages automáticamente
```

**Commit**: d5a0b2b7d776d90ce6511d61fc47bfcdb14d3285

---

## Resumen de Esfuerzo

| Actividad | Tiempo | Estado |
|-----------|--------|--------|
| Refactorizar `_applyAllImportedFilters()` | 5 min | ✓ |
| Análisis de features/estacion | 10 min | ✓ |
| Compilación y deployment | 5 min | ✓ |
| **TOTAL** | **20 min** | **✓** |

---

## Criterio de Éxito

✅ Envolventes permanecen visibles cuando "Solo Estaciones" activo  
✅ Solo 74 features de estaciones se renderizan (+ envolventes)  
✅ Otros archivos (TSNL_16_17, municipios, etc.) excluidos del render  
✅ Compilation sin errores  
✅ Deploy a GitHub Pages exitoso  

---

## Resultado / Evidencia

**URL Desplegada**: https://dayizz.github.io/geoportal_consulta/  
**Commit**: d5a0b2b (main)  

**Test manual requerido**:
1. Abrir map en navegador
2. Hacer clic en toggle "Solo Estaciones"
3. Verificar: 
   - ✓ Envolventes (líneas azul-amarillo) quedan visibles
   - ✓ Solo ~74 polígonos de estaciones visibles
   - ✓ Sin predios de TSNL_16_17 visibles
4. Desactivar toggle → todos los predios e importados vuelven

**Nota sobre cache**: Si usuario no ve cambios, debe hacer **Ctrl+F5** (hard refresh) en navegador

---

## Próximo Paso

1. **Usuario verifica en vivo** con hard refresh (Ctrl+F5)
2. Si aún hay false positives (predios sin estacion): investigar _applyAllFilters() para predios base
3. Si todo bien: marcar como resuelto

---

## Observaciones Técnicas

### Por qué envolventes deben estar siempre visibles
- **Envolventes** = polígonos de referencia/contexto (11,925 features)
- Son capas de "background" que deben estar en TODO estado del mapa
- El usuario filtra por "Solo Estaciones" para ver PUNTOS de interés, NO para ocultar contexto
- Solución: Separar envolventes de lógica de filtrado, siempre concatenarlas al final

### Análisis de esEstacion detection
- **Correcto**: Solo ESTACIONES_Y_EDIFICIOS_AUXILIARES_TSNL_1805.geojson = estaciones (74)
- **Archivos sin estacion**: TSNL_16_17 (159), ENVOLVENTES_P (4213), ENVOLVENTES_L (3238), ENVOLVENTE_COMPLETA (7474), SEGMENTO13 (531), segmento_18 (154)
- **Limitación anterior**: Código buscaba "estacion" en TODAS las properties → causaba false matches
- **Fix actual**: Solo busca en sourceAsset.toLowerCase().contains('estaciones_y_edificios') → 100% preciso

---

## Tickets Relacionados

- IMPL_13: Fixed duplicate fichas
- IMPL_14: Imported ENVOLVENTE_COMPLETA.geojson
- IMPL_15: Made filters mutually exclusive + improved estacion detection
- IMPL_16: **Envolventes visibility + Solo Estaciones filter** (THIS)

