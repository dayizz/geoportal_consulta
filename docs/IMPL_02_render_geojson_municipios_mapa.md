# IMPL_02_render_geojson_municipios_mapa

- Estado: Implementado
- Fecha: 11-05-2026
- Rama: N/A (workspace sin repositorio git inicializado)

## 1. Objetivo
Asegurar que el GeoJSON de municipios importado se renderice en el mapa aunque no exista municipio seleccionado o no haya predios cargados.

## 2. Diagnostico / contexto actual
El mapa solo dibujaba limites municipales cuando se elegia un municipio en filtros avanzados.
Si no habia seleccion, la capa GeoJSON no se mostraba.
Adicionalmente, cuando predios estaba vacio, no habia enfoque inicial hacia los limites del GeoJSON.

## 3. Fases
### Fase 1: Analisis de condicion de dibujo
- Descripcion: Revision de _buildMap para ubicar la condicion que restringia el dibujo de municipios.
- Archivos afectados: lib/features/mapa/mapa_screen.dart
- Codigo clave: bloque condicionado por _selectedMunicipio
- Tiempo estimado: 10 min
- Riesgo: Bajo

### Fase 2: Render base permanente de limites
- Descripcion: Se agrego una capa base de polilineas para todos los municipios cargados desde provider.
- Archivos afectados: lib/features/mapa/mapa_screen.dart
- Codigo clave: municipalBasePolylines + PolylineLayer
- Tiempo estimado: 15 min
- Riesgo: Bajo

### Fase 3: Enfoque inicial con fallback a GeoJSON
- Descripcion: Se actualizo el enfoque inicial para usar limites municipales cuando no hay puntos de predios.
- Archivos afectados: lib/features/mapa/mapa_screen.dart
- Codigo clave: _ensureInitialFocus(predios, municipios), _collectMunicipioBoundaryPoints
- Tiempo estimado: 15 min
- Riesgo: Bajo

## 4. Resumen de esfuerzo
| Fase | Tiempo | Riesgo |
|---|---:|---|
| Fase 1 | 10 min | Bajo |
| Fase 2 | 15 min | Bajo |
| Fase 3 | 15 min | Bajo |
| Total | 40 min | Bajo |

## 5. Criterio de exito
- Los limites del GeoJSON se visualizan en mapa sin requerir seleccion de municipio.
- Si no hay predios, el mapa hace zoom/encuadre sobre limites municipales disponibles.

## 6. Resultado / evidencia
- Se implemento capa base de limites municipales para todos los features GeoJSON.
- Se mantiene resaltado especial del municipio seleccionado como comportamiento adicional.
- Se ejecuto hot reload exitoso y compilacion sin errores en el archivo modificado.

## 7. Proximo paso
Levantar backend local en puerto 8000 o usar Supabase configurado para eliminar errores de red de consola y mostrar predios reales junto con los limites municipales.
