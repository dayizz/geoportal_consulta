# IMPL_23 LOD de etiquetas + plan de teselas estaticas

Estado: Completado
Fecha: 2026-05-18
Rama: main

## 1. Objetivo
Atender dos frentes:
1) Mejorar visibilidad/rendimiento de etiquetas en satelital con LOD estricto.
2) Definir implementacion operativa para eliminar parcheado con piramide de teselas estaticas (MapProxy/CDN).

## 2. Diagnostico / contexto actual
- El frontend ya consume teselas raster de ArcGIS, pero el parcheado perceptual aparece cuando hay latencia de red + redibujado de capas.
- Etiquetas detalladas pueden saturar render en zoom no adecuado.
- Se requiere separar niveles de detalle de etiquetas por zoom.

## 3. Fases

### Fase 1: LOD estricto de etiquetas en frontend
- Descripcion: activar etiquetas por umbral de zoom.
- Archivo afectado: `lib/features/mapa/mapa_screen.dart`
- Codigo clave:

```dart
final showPlaceLabels = _baseLayer == _BaseLayer.satelital && _currentZoom >= 9;
final showStreetLabels = _baseLayer == _BaseLayer.satelital && _currentZoom >= 14;
```

Render:
- `World_Boundaries_and_Places` solo cuando `showPlaceLabels`.
- `World_Transportation` solo cuando `showStreetLabels`.

- Tiempo estimado: 10 min
- Riesgo: Bajo

### Fase 2: Validacion build
- Comando: `flutter build web`
- Resultado: exitoso
- Tiempo estimado: 10 min
- Riesgo: Bajo

### Fase 3: Plan ejecutable de teselas estaticas (infra)
- Descripcion: mover mapa base y referencias a cache edge para entregar teselas en milisegundos.
- Alcance: infraestructura (no bloquea frontend actual).

#### Arquitectura recomendada
1. Origen: servicio de teselas raster (ArcGIS/WMTS interno)
2. Proxy/cache: MapProxy o GeoWebCache
3. CDN: Cloudflare con cache agresivo por URL de tile
4. Frontend: apuntar `urlTemplate` al dominio cacheado (ej. `https://tiles.tudominio.com/{layer}/{z}/{y}/{x}.png`)

#### Configuracion minima (MapProxy)
- Cache por capa y por nivel z 0..18
- `meta_size` 4x4 para reducir seams
- `cache.lock_dir` para concurrencia
- seed inicial por AOI y zooms principales (8..16)

#### Politica CDN sugerida
- Cache-Control: `public, max-age=31536000, immutable`
- Query string deshabilitado para cache key (si no se usa)
- Brotli/Gzip para metadatos

#### Monitoreo
- hit ratio CDN > 90%
- p95 tile latency < 120ms
- tasa de tiles vacios/error < 1%

### Fase 4: Line Merging en backend (PostGIS)
- Descripcion: unificar microsegmentos para reducir calculo de etiquetas por entidad.
- SQL de referencia:

```sql
-- Unir segmentos por nombre normalizado
CREATE MATERIALIZED VIEW vias_merge AS
SELECT
  lower(trim(nombre_via)) AS via_key,
  ST_LineMerge(ST_Union(geom)) AS geom
FROM vias_raw
WHERE nombre_via IS NOT NULL
GROUP BY lower(trim(nombre_via));

CREATE INDEX vias_merge_gix ON vias_merge USING GIST (geom);
```

- Resultado esperado: menos colisiones y menos trabajo de etiquetado.

## 4. Resumen de esfuerzo

| Fase | Tiempo | Riesgo |
|---|---:|---|
| LOD etiquetas frontend | 10 min | Bajo |
| Build validacion | 10 min | Bajo |
| Plan teselas estaticas | 20 min | Bajo |
| Line merge SQL | 10 min | Medio |
| Total | 50 min | Bajo-Medio |

## 5. Criterio de exito
- Etiquetas detalladas solo en zoom alto (>=14).
- Menor carga visual y menor costo de render en zoom bajo.
- Build web sin errores.
- Plan de infra definido para eliminar parcheado por latencia de tiles.

## 6. Resultado / evidencia
- Cambio aplicado en `lib/features/mapa/mapa_screen.dart`
- Build web exitoso.
- Estrategia de teselas estaticas documentada.

## 7. Proximo paso
1. Publicar este cambio en `main`.
2. Implementar entorno MapProxy/CDN y cambiar `urlTemplate` a dominio cacheado.
3. Ejecutar pipeline PostGIS (line merge) para capas de vias con etiquetado.
