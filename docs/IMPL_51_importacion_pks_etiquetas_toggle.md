# IMPL_51 - Importacion de PKs.geojson con etiquetas y toggle

- Estado: Completado
- Fecha: 2026-05-26
- Rama: main

## 1. Objetivo
Importar un archivo GeoJSON de puntos PK en el mapa, mostrar su etiqueta de texto georreferenciada y agregar botón de encendido/apagado para su visibilidad.

## 2. Diagnostico / contexto actual
El portal renderizaba principalmente polígonos y líneas de predios, pero no tenía una capa dedicada para puntos PK con etiquetas.
Si se mezclaban estos puntos en el provider general de predios, se podían contaminar filtros y conteos.

## 3. Fases
### Fase 1: Incorporacion del archivo PKs
- Descripcion: se copió `pks.geojson` al directorio de assets del proyecto.
- Archivos afectados:
  - `assets/data/pks.geojson`
- Codigo clave: N/A
- Tiempo estimado: 5 min
- Riesgo: Bajo

### Fase 2: Provider dedicado para puntos PK
- Descripcion: se creó un modelo `PkGeoPoint` y un provider `pksGeoJsonProvider` para cargar puntos `Point` y extraer propiedad `PKs/pk`.
- Archivos afectados:
  - `lib/features/mapa/predios_provider.dart`
- Codigo clave:
  - `class PkGeoPoint`
  - `final pksGeoJsonProvider`
- Tiempo estimado: 20 min
- Riesgo: Bajo

### Fase 3: Render y toggle ON/OFF en UI
- Descripcion: se agregó estado `_showPkLabels`, botón `PKs ON/OFF` en barra superior y capa `MarkerLayer` con etiquetas de texto sin recuadro sobre coordenadas de cada punto.
- Archivos afectados:
  - `lib/features/mapa/mapa_screen.dart`
- Codigo clave:
  - `_showPkLabels`
  - `_buildPkLabelMarker(...)`
  - `MarkerLayer(markers: pkLabels)`
- Tiempo estimado: 25 min
- Riesgo: Bajo

## 4. Resumen de esfuerzo
| Fase | Tiempo estimado | Riesgo |
|---|---:|---|
| Fase 1 | 5 min | Bajo |
| Fase 2 | 20 min | Bajo |
| Fase 3 | 25 min | Bajo |
| **Total** | **50 min** | **Bajo** |

## 5. Criterio de exito
- El archivo `pks.geojson` se carga correctamente en app.
- Cada punto muestra etiqueta de PK sobre su georreferencia.
- Existe botón para encender/apagar la capa de etiquetas PK.

## 6. Resultado / evidencia
Resultado:
- Capa de PKs integrada sin afectar filtros/conteos de predios.
- Toggle funcional en top bar: `PKs ON/OFF`.
- Etiquetas renderizadas como texto sin contenedor.

## 7. Proximo paso
- Ajustar tamaño/visibilidad de etiqueta por nivel de zoom si se requiere reducir saturación en escalas amplias.
