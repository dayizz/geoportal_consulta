# IMPL_08: Remover conteos de predios y GeoJSON del panel superior

**Estado**: ✅ Completado  
**Fecha**: 2025-01-09  
**Rama**: main  
**Commit**: 2872c22

---

## Objetivo

Limpiar la interfaz de usuario del panel superior removiendo dos contadores innecesarios:
1. Conteo de predios ("X predios")
2. Conteo de caracteres GeoJSON ("GeoJSON: Y")

---

## Diagnóstico / Contexto Actual

El panel superior de la aplicación mostraba:
- Título "Geoportal de Consulta"
- Badge con proyecto actual
- **Badge con conteo dinámico de predios filtrados**
- **Condicional badge con conteo de features GeoJSON importadas**
- Toggle de modo de color
- Botón de recarga

Estos contadores no agregaban valor funcional y hacían la interfaz más ruidosa visualmente.

---

## Fases

### Fase 1: Remover parámetro de función
- **Descripción**: Eliminar `int importedGeoJsonCount` del parámetro de `_buildTopBar()`
- **Archivos**: `lib/features/mapa/mapa_screen.dart`
- **Código clave**:
  ```dart
  // ANTES:
  Widget _buildTopBar(
    String proyecto,
    List<Predio> predios,
    List<MunicipioLimite> municipios,
    int importedGeoJsonCount,  // ← REMOVIDO
  ) {

  // DESPUÉS:
  Widget _buildTopBar(
    String proyecto,
    List<Predio> predios,
    List<MunicipioLimite> municipios,
  ) {
  ```
- **Tiempo estimado**: 2 min
- **Riesgo**: Bajo (cambio mecánico)

### Fase 2: Remover widget GeoJSON count
- **Descripción**: Eliminar bloque `if (importedGeoJsonCount > 0)` que renderiza badge de conteo GeoJSON
- **Archivos**: `lib/features/mapa/mapa_screen.dart` (líneas ~710-730)
- **Código removido**: 
  ```dart
  if (false) ...[  // Disabled - removed predio count
    const SizedBox(width: 8),
    Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: const Color(0xFFD32F2F).withOpacity(0.25),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(...),
      ),
      child: Text('GeoJSON: $importedGeoJsonCount', ...),
    ),
  ],
  ```
- **Tiempo estimado**: 2 min
- **Riesgo**: Bajo

### Fase 3: Actualizar sitio de llamada
- **Descripción**: Remover parámetro `importedGeoJsonAsync.valueOrNull?.length ?? 0` de la llamada a `_buildTopBar()`
- **Archivos**: `lib/features/mapa/mapa_screen.dart` (líneas ~160-170)
- **Código actualizado**:
  ```dart
  // ANTES:
  _buildTopBar(
    proyecto,
    prediosAsync.valueOrNull ?? [],
    municipiosAsync.valueOrNull ?? const [],
    importedGeoJsonAsync.valueOrNull?.length ?? 0,  // ← REMOVIDO
  ),

  // DESPUÉS:
  _buildTopBar(
    proyecto,
    prediosAsync.valueOrNull ?? [],
    municipiosAsync.valueOrNull ?? const [],
  ),
  ```
- **Tiempo estimado**: 1 min
- **Riesgo**: Bajo

### Fase 4: Compilar y desplegar
- **Descripción**: Compilar Flutter web y desplegar automáticamente vía GitHub Actions
- **Comando**: 
  ```bash
  flutter build web --base-href /geoportal_consulta/ --release
  git add -A
  git commit -m "ui: eliminar conteo de predios y geojson del panel superior"
  git push origin main
  ```
- **Tiempo estimado**: 30 seg compilación local + 5-10 min GitHub Actions
- **Riesgo**: Bajo (GitHub Actions ya estable en 19 runs)

---

## Resumen de Esfuerzo

| Actividad | Tiempo | Complejidad | Completado |
|-----------|--------|-------------|-----------|
| Remover parámetro función | 2 min | Bajo | ✅ |
| Remover widget GeoJSON | 2 min | Bajo | ✅ |
| Actualizar call site | 1 min | Bajo | ✅ |
| Compilar web | 20 seg | Bajo | ✅ |
| Desplegar (Push + Actions) | ~8 min | Bajo | ✅ |
| **TOTAL** | **~13 min** | **Bajo** | **✅** |

---

## Criterio de Éxito

✅ Código compila sin errores  
✅ No hay referencias a `importedGeoJsonCount` en codebase  
✅ Panel superior renderiza sin los dos badges de conteo  
✅ GitHub Actions ejecuta exitosamente (Run #20+)  
✅ Sitio en GitHub Pages refleja cambios  

---

## Resultado / Evidencia

**Commit**: `2872c22` - "ui: eliminar conteo de predios y geojson del panel superior"

**Cambios realizados**:
- Función `_buildTopBar()` redefinida sin parámetro `importedGeoJsonCount`
- Bloque `if (importedGeoJsonCount > 0)` completamente removido (~20 líneas)
- Call site actualizado sin parámetro extra
- Build completó exitosamente: `✓ Built build/web`
- Push a main completado: `c92e941..2872c22  main -> main`

**Validaciones**:
- `grep_search` confirma cero referencias a `importedGeoJsonCount`
- `get_errors` en mapa_screen.dart: "No errors found"

---

## Próximo Paso

Verificar que GitHub Pages refleja cambios (sin contadores en panel superior) una vez que GitHub Actions Run #20 complete. El despliegue debería estar disponible en ~5 min desde el push.

---

## Notas Técnicas

- **No se removieron**: Funcionalidad de filtros, providers, rendimiento, rendering de capas
- **Solo modificado**: Renderización del panel superior (UI layer)
- **Compatibilidad**: Sin cambios en API Riverpod, sin cambios en modelos de datos
- **Performance**: Ligera mejora potencial (menos re-renders de widgets que dependían de importedGeoJsonCount)
