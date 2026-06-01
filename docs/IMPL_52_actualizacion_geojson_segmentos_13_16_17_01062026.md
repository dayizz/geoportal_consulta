# IMPL_52_actualizacion_geojson_segmentos_13_16_17_01062026

- Estado: Completado
- Fecha: 2026-05-31
- Rama: main

## 1. Objetivo
Actualizar los archivos operativos de los segmentos 13, 16 y 17 del proyecto TSN con los insumos mas recientes entregados desde ATTRAPI, y dejarlos listos para publicacion en la pagina.

## 2. Diagnostico / contexto actual
La aplicacion consume capas GeoJSON desde `assets/data/` y actualmente incluye dos variantes para el bloque 16-17:
- `TSN_SEG_16_17.geojson`
- `TSN_ACT_SEG_16_17.geojson`

Para mantener consistencia de datos en el render y evitar mezclar versiones antiguas/nuevas, ambos archivos 16-17 debian sustituirse con la misma fuente actualizada.

## 3. Fases
### Fase 1: Verificacion de fuentes y destinos
- Descripcion: se verificaron archivos fuente en la ruta externa y archivos destino en el proyecto.
- Archivos afectados: N/A
- Codigo clave: N/A
- Tiempo estimado: 5 min
- Riesgo: Bajo

### Fase 2: Sustitucion de GeoJSON solicitados
- Descripcion: se copiaron los nuevos archivos a `assets/data/`, reemplazando las versiones previas.
- Archivos afectados:
  - `assets/data/TSN_SEG_13.geojson`
  - `assets/data/TSN_SEG_16_17.geojson`
  - `assets/data/TSN_ACT_SEG_16_17.geojson`
- Codigo clave: `cp` directo desde ruta ATTRAPI
- Tiempo estimado: 10 min
- Riesgo: Bajo

### Fase 3: Publicacion
- Descripcion: se prepara commit/push en `main` para disparar workflow de GitHub Pages.
- Archivos afectados: repositorio git
- Codigo clave: `git add`, `git commit`, `git push`
- Tiempo estimado: 10 min
- Riesgo: Medio (depende de ejecucion exitosa del workflow)

## 4. Resumen de esfuerzo
| Fase | Tiempo | Riesgo |
|---|---:|---|
| Verificacion de fuentes y destinos | 5 min | Bajo |
| Sustitucion de GeoJSON | 10 min | Bajo |
| Publicacion | 10 min | Medio |
| Total | 25 min | Bajo-Medio |

## 5. Criterio de exito
- Los segmentos 13, 16 y 17 quedan actualizados en `assets/data/`.
- El repositorio queda publicado en `main` con estos cambios.
- GitHub Actions ejecuta el deploy hacia GitHub Pages.

## 6. Resultado / evidencia
- Reemplazos aplicados:
  - `TSN_SEG_13.geojson` (nuevo)
  - `TSN_SEG_16_17.geojson` (nuevo desde `TSNL_1617_01062026.geojson`)
  - `TSN_ACT_SEG_16_17.geojson` (nuevo desde `TSNL_1617_01062026.geojson`)
- Verificacion de tamanos posterior a copia:
  - `TSN_SEG_13.geojson`: ~237 KB
  - `TSN_SEG_16_17.geojson`: ~153 KB
  - `TSN_ACT_SEG_16_17.geojson`: ~153 KB

## 7. Proximo paso
Validar en el portal publicado que las capas de segmentos 13, 16 y 17 correspondan a la version actualizada y que no existan duplicidades visuales inesperadas.
