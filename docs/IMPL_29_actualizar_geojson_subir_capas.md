# IMPL_29_actualizar_geojson_subir_capas

- Estado: Completado
- Fecha: 2026-05-25
- Rama: main

## 1. Objetivo
Actualizar en el repositorio los GeoJSON operativos indicados por el usuario para que el geoportal renderice las capas recientes de predios, estaciones y envolvente.

## 2. Diagnostico / contexto actual
El proyecto ya cargaba `assets/data/` de forma dinamica, pero los archivos dentro de esa carpeta debian reemplazarse por las versiones nuevas entregadas desde ATTRAPI.

## 3. Fases
### Fase 1: Identificacion de archivos origen
- Descripcion: se verifico la existencia de los archivos fuente en la carpeta externa de ATTRAPI.
- Archivos afectados: N/A
- Codigo clave: N/A
- Tiempo estimado: 5 min
- Riesgo: Bajo

### Fase 2: Sustitucion de capas GeoJSON
- Descripcion: se copiaron al proyecto las nuevas versiones de `TSN_SEG_13.geojson`, `TSN_SEG_18.geojson`, `ESTACIONES_Y_EDIFICIOS_AUXILIARES_TSNL_1805.geojson` y `ENVOLVENTE_COMPLETA.geojson`.
- Archivos afectados: assets/data/*.geojson
- Codigo clave: cp directo desde ATTRAPI a assets/data
- Tiempo estimado: 10 min
- Riesgo: Bajo

### Fase 3: Validacion de build
- Descripcion: se ejecuto `flutter build web` para confirmar que el cambio de assets no rompio la compilacion.
- Archivos afectados: N/A
- Codigo clave: N/A
- Tiempo estimado: 15 min
- Riesgo: Bajo

## 4. Resumen de esfuerzo
| Fase | Tiempo | Riesgo |
|---|---:|---|
| Identificacion archivos | 5 min | Bajo |
| Sustitucion de capas | 10 min | Bajo |
| Validacion build | 15 min | Bajo |
| Total | 30 min | Bajo |

## 5. Criterio de exito
- Los cuatro GeoJSON solicitados se encuentran actualizados en `assets/data/`.
- `flutter build web` termina con exito.
- El workflow puede desplegar las capas nuevas sin cambios adicionales de codigo.

## 6. Resultado / evidencia
- Archivos copiados desde ATTRAPI al proyecto.
- Build web exitoso.

## 7. Proximo paso
- Publicar el commit con los GeoJSON actualizados y validar en GitHub Actions el nuevo deploy.
