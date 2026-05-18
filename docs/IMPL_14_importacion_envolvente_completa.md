# IMPL_14 Importación ENVOLVENTE_COMPLETA.geojson

Estado: Completado
Fecha: 2026-05-18
Rama: main

## 1. Objetivo
Importar el archivo GeoJSON `ENVOLVENTE_COMPLETA.geojson` (7.4 MB) desde `/Users/dayana/Documents/ATTRAPI/TSNL/` al geoportal para que se renderice junto con los demás datos de envolventes.

## 2. Diagnóstico / contexto actual
Existían dos archivos de envolventes parciales: `ENVOLVENTES_P_TSNL.geojson` (poligonales) y `ENVOLVENTES_L_TSNL.geojson` (lineales). Se requería integrar la envolvente completa para una visualización más completa.

## 3. Fases

### Fase 1: Copia del archivo GeoJSON
- Descripción: copiar `ENVOLVENTE_COMPLETA.geojson` a `assets/data/`.
- Archivos afectados: `/Users/dayana/Documents/geoportal_consulta/assets/data/ENVOLVENTE_COMPLETA.geojson`
- Comando: `cp /Users/dayana/Documents/ATTRAPI/TSNL/ENVOLVENTE_COMPLETA.geojson assets/data/`
- Tiempo estimado: 2 min
- Riesgo: Bajo

### Fase 2: Registro en provider
- Descripción: agregar la ruta del archivo a la lista de assets que carga el `importedGeoJsonPrediosProvider`.
- Archivos afectados: `lib/features/mapa/predios_provider.dart`
- Código clave:
  - Línea 553: se agregó `'assets/data/ENVOLVENTE_COMPLETA.geojson',` a la lista `importAssets`.
  - Detección automática: el sistema identifica como envolvente por el término "envolvente" en el nombre del archivo.
- Tiempo estimado: 10 min
- Riesgo: Bajo

### Fase 3: Compilación y despliegue
- Descripción: compilar con Flutter Web y publicar cambios en remoto.
- Archivos afectados: `build/web/` (generado)
- Comandos: `flutter build web`, `git add -A`, `git commit`, `git push origin main`
- Tiempo estimado: 5 min
- Riesgo: Bajo

## 4. Resumen de esfuerzo

| Fase | Tiempo | Riesgo |
|---|---:|---|
| Copia del archivo GeoJSON | 2 min | Bajo |
| Registro en provider | 10 min | Bajo |
| Compilación y despliegue | 5 min | Bajo |
| Total | 17 min | Bajo |

## 5. Criterio de éxito
- Archivo `ENVOLVENTE_COMPLETA.geojson` copiado a `assets/data/`.
- Ruta registrada en `importAssets` en `predios_provider.dart`.
- Compilación exitosa: `flutter build web`.
- Push exitoso a `main`: commit `86f0789a8f2a06eb64119d34069033125a98776e`.

## 6. Resultado / evidencia
- Archivo copiado: 7.4 MB en `assets/data/ENVOLVENTE_COMPLETA.geojson`.
- Provider actualizado con nueva ruta de asset.
- Build web completado sin errores.
- Commit publicado en main.

## 7. Próximo paso
GitHub Actions desplegará automáticamente los cambios. La envolvente completa estará visible en el geoportal en https://dayizz.github.io/geoportal_consulta/ dentro de minutos (después de que termine la workflow de GitHub Actions).
