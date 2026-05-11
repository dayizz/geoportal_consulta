# IMPL_03_importacion_geolocalizacion_geojson_tsnl131617

- Estado: Implementado
- Fecha: 11-05-2026
- Rama: N/A (workspace sin repositorio git inicializado)

## 1. Objetivo
Importar el archivo TSNL-131617.geojson al proyecto y usarlo para geolocalizar predios en el mapa cuando el backend local no responda.

## 2. Diagnostico / contexto actual
El mapa dependia de backend local en puerto 8000 para cargar predios. Si el backend no estaba disponible, no habia datos para ubicar ni dibujar predios.

## 3. Fases
### Fase 1: Importacion del archivo al proyecto
- Descripcion: Copia del archivo externo al directorio de assets de la app.
- Archivos afectados: assets/data/TSNL-131617.geojson
- Codigo clave: registro como asset Flutter
- Tiempo estimado: 5 min
- Riesgo: Bajo

### Fase 2: Registro en pubspec
- Descripcion: Inclusión del archivo GeoJSON en la lista de assets.
- Archivos afectados: pubspec.yaml
- Codigo clave: assets/data/TSNL-131617.geojson
- Tiempo estimado: 5 min
- Riesgo: Bajo

### Fase 3: Fallback de datos y geolocalizacion
- Descripcion: Parseo del FeatureCollection y mapeo a Predio para usarlo cuando falle backend.
- Archivos afectados: lib/features/mapa/predios_provider.dart
- Codigo clave: _loadPrediosFromAssetGeoJson y fallback en prediosConsultaProvider
- Tiempo estimado: 20 min
- Riesgo: Medio

### Fase 4: Validacion en ejecucion
- Descripcion: flutter pub get y hot restart para aplicar asset nuevo en runtime.
- Archivos afectados: n/a
- Codigo clave: pub get + restart
- Tiempo estimado: 5 min
- Riesgo: Bajo

## 4. Resumen de esfuerzo
| Fase | Tiempo | Riesgo |
|---|---:|---|
| Fase 1 | 5 min | Bajo |
| Fase 2 | 5 min | Bajo |
| Fase 3 | 20 min | Medio |
| Fase 4 | 5 min | Bajo |
| Total | 35 min | Medio |

## 5. Criterio de exito
- El archivo TSNL-131617.geojson queda integrado como asset.
- En ausencia de backend, el mapa obtiene predios desde el GeoJSON importado.
- Las geometrías del GeoJSON se usan para ubicar/dibujar predios en el mapa.

## 6. Resultado / evidencia
- Archivo importado en assets/data.
- Asset agregado en pubspec y dependencias resueltas.
- Fallback de provider implementado y reinicio aplicado sin errores de compilacion.
- Ajuste adicional: si no hay coincidencias por proyecto activo, se usa el dataset completo del GeoJSON para evitar mapa vacio.

## 7. Proximo paso
Iniciar sesion con proyecto TSNL para visualizar inmediatamente los predios importados del GeoJSON en el mapa.
