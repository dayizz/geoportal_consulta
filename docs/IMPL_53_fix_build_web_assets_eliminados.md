# IMPL 53 - Fix build web por assets eliminados

- Estado: Completado
- Fecha: 2026-07-09
- Rama: main

## 1. Objetivo
Corregir el fallo de compilacion web causado por referencias a archivos GeoJSON eliminados durante la limpieza de datos importados.

## 2. Diagnostico / contexto actual
El pipeline de GitHub Actions fallo en el paso de `flutter build web` con el error:
`No file or variants found for asset: assets/data/municipios.geojson`.

Causa raiz:
- En `pubspec.yaml` seguian declarados assets `.geojson` que ya no existen en `assets/data/`.
- Flutter valida que cada asset declarado exista fisicamente al compilar.

## 3. Fases
### Fase 1 - Reproduccion del error
- Descripcion: ejecucion local de `flutter build web` para confirmar el error exacto.
- Archivos afectados: ninguno (diagnostico).
- Codigo clave: salida de compilacion con fallo de bundling de assets.
- Tiempo estimado: 10 min.
- Riesgo: bajo.

### Fase 2 - Ajuste de declaracion de assets
- Descripcion: limpieza de lista de assets en `pubspec.yaml` para evitar referencias rotas.
- Archivos afectados: `pubspec.yaml`.
- Codigo clave: reemplazo de entradas `.geojson` eliminadas por `assets/data/manifest.json`.
- Tiempo estimado: 10 min.
- Riesgo: medio (si algun flujo dependia de carga local por asset, requerira carga remota o regeneracion de archivos).

### Fase 3 - Validacion
- Descripcion: nueva compilacion con `flutter build web`.
- Archivos afectados: ninguno (validacion).
- Codigo clave: build exitoso `Built build/web`.
- Tiempo estimado: 10 min.
- Riesgo: bajo.

## 4. Resumen de esfuerzo
| Fase | Tiempo estimado | Riesgo |
|---|---:|---|
| Reproduccion | 10 min | Bajo |
| Ajuste pubspec | 10 min | Medio |
| Validacion build | 10 min | Bajo |
| **Total** | **30 min** | **Bajo-Medio** |

## 5. Criterio de exito
- `flutter build web` finaliza sin errores.
- No existen referencias en `pubspec.yaml` a archivos inexistentes.

## 6. Resultado / evidencia
Resultado obtenido:
- Build web exitoso en local.
- Error de assets inexistentes resuelto.

Evidencia clave:
- Mensaje final de compilacion: `Built build/web`.

## 7. Proximo paso
- Verificar en CI que el workflow de GitHub Actions pase en `main` con este ajuste.
