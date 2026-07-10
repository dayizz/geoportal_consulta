# IMPL 54 - Fix workflow por copia de GeoJSON inexistentes

- Estado: Completado
- Fecha: 2026-07-09
- Rama: main

## 1. Objetivo
Corregir el fallo de GitHub Actions en el paso de despliegue web que intentaba copiar archivos `.geojson` eliminados al directorio de salida.

## 2. Diagnostico / contexto actual
El workflow `Deploy Flutter Web to GitHub Pages` fallaba aunque `flutter build web` compilaba correctamente en local.

Causa raiz:
- El workflow seguia ejecutando `cp assets/data/*.geojson build/web/assets/data/`.
- Tras la limpieza del repositorio, ya no existen archivos `.geojson` en `assets/data/`.
- El shell expandia el glob a una ruta inexistente y abortaba el job con error.

## 3. Fases
### Fase 1 - Identificacion del fallo
- Descripcion: revision del run fallido en GitHub Actions y del YAML del workflow.
- Archivos afectados: `.github/workflows/deploy_github_pages.yml`.
- Codigo clave: paso `Copiar archivos GeoJSON a build web`.
- Tiempo estimado: 15 min.
- Riesgo: bajo.

### Fase 2 - Ajuste del workflow
- Descripcion: eliminacion del paso de copia de GeoJSON inexistentes.
- Archivos afectados: `.github/workflows/deploy_github_pages.yml`.
- Codigo clave: se conserva la generacion de `manifest.json` y el build de Flutter, pero se elimina la copia manual de `.geojson`.
- Tiempo estimado: 10 min.
- Riesgo: bajo.

### Fase 3 - Validacion local
- Descripcion: ejecucion de `flutter build web --no-wasm-dry-run` para confirmar que el cambio no rompe la compilacion.
- Archivos afectados: ninguno (validacion).
- Codigo clave: build exitoso `Built build/web`.
- Tiempo estimado: 10 min.
- Riesgo: bajo.

## 4. Resumen de esfuerzo
| Fase | Tiempo estimado | Riesgo |
|---|---:|---|
| Identificacion | 15 min | Bajo |
| Ajuste workflow | 10 min | Bajo |
| Validacion | 10 min | Bajo |
| **Total** | **35 min** | **Bajo** |

## 5. Criterio de exito
- El workflow ya no intenta copiar archivos `.geojson` inexistentes.
- `flutter build web` sigue completando con exito.
- GitHub Actions puede continuar hasta el paso de upload/deploy sin fallar por falta de assets.

## 6. Resultado / evidencia
Resultado obtenido:
- Se elimino el paso de copia manual de GeoJSON en el workflow.
- El build web local siguio pasando.

Evidencia clave:
- Mensaje final de compilacion: `Built build/web`.

## 7. Proximo paso
- Reejecutar el workflow en `main` para verificar que el run ya completa sin error de copia de assets.
