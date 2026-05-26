# IMPL_32_manifest_geojson_web_compatible

- Estado: Completado
- Fecha: 2026-05-25
- Rama: main

## 1. Objetivo
Hacer que la carga dinamica de GeoJSON funcione correctamente en Flutter Web y GitHub Pages, sin depender de `AssetManifest.json`.

## 2. Diagnostico / contexto actual
La implementacion usaba `rootBundle.loadString('AssetManifest.json')`, pero en el build web de Flutter no existe ese archivo. En su lugar se genera `assets/AssetManifest.bin` y `assets/AssetManifest.bin.json`, este ultimo en formato binario serializado/base64 no apto para usarlo directamente como lista de assets.

Consecuencia:
- Los providers dinamicos podian devolver listas vacias en produccion.
- Algunos GeoJSON no aparecian aunque existieran en el repositorio y el deploy hubiera sido exitoso.

## 3. Fases
### Fase 1: Diagnostico del build web
- Descripcion: se verifico que `build/web` no contenia `AssetManifest.json` y que `AssetManifest.bin.json` no era una lista JSON simple.
- Archivos afectados: build/web/assets/
- Codigo clave: N/A
- Tiempo estimado: 10 min
- Riesgo: Bajo

### Fase 2: Manifiesto propio de GeoJSON
- Descripcion: se creo `assets/data/manifest.json` como fuente explicita y web-compatible para listar todos los GeoJSON.
- Archivos afectados: assets/data/manifest.json
- Codigo clave: lista de `assets/data/*.geojson`
- Tiempo estimado: 10 min
- Riesgo: Bajo

### Fase 3: Providers usando el manifiesto propio
- Descripcion: se actualizo `predios_provider.dart` para usar `assets/data/manifest.json` tanto en la capa base de predios como en la capa importada.
- Archivos afectados: lib/features/mapa/predios_provider.dart
- Codigo clave: _loadGeoJsonAssetManifest
- Tiempo estimado: 20 min
- Riesgo: Medio

### Fase 4: Automatizacion en workflow
- Descripcion: se agrego un paso en GitHub Actions para regenerar `assets/data/manifest.json` antes del build y copiarlo al artifact final.
- Archivos afectados: .github/workflows/deploy_github_pages.yml
- Codigo clave: script Python en workflow
- Tiempo estimado: 15 min
- Riesgo: Bajo

## 4. Resumen de esfuerzo
| Fase | Tiempo | Riesgo |
|---|---:|---|
| Diagnostico build web | 10 min | Bajo |
| Manifiesto propio | 10 min | Bajo |
| Ajuste de providers | 20 min | Medio |
| Automatizacion workflow | 15 min | Bajo |
| Total | 55 min | Medio |

## 5. Criterio de exito
- La carga de GeoJSON funciona en web sin depender de `AssetManifest.json`.
- Nuevos archivos `.geojson` agregados a `assets/data/` se incluyen automaticamente en deploy.
- El mapa puede renderizar todos los datasets listados en `assets/data/manifest.json`.

## 6. Resultado / evidencia
- `assets/data/manifest.json` agregado.
- `predios_provider.dart` usa el manifiesto propio.
- Workflow genera y copia el manifiesto automaticamente.

## 7. Proximo paso
- Ejecutar build web, publicar commit y validar en produccion que todos los GeoJSON aparecen en el mapa.
