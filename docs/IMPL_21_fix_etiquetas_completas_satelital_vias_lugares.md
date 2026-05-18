# IMPL_21 fix etiquetas completas satelital vias y lugares

Estado: Completado
Fecha: 2026-05-18
Rama: main

## 1. Objetivo
Mostrar etiquetas completas en el mapa satelital: calles, avenidas, colonias, municipios, estados y lugares de ubicacion.

## 2. Diagnostico / contexto actual
La configuracion previa en satelital solo cargaba `World_Boundaries_and_Places`, que no cubre de forma completa etiquetas de vialidades.

Para obtener etiquetado integral en ArcGIS se requiere combinar capas de referencia:
- `World_Transportation` (vialidades)
- `World_Boundaries_and_Places` (toponimia de lugares/limites)

## 3. Fases

### Fase 1: Agregar stack completo de referencia ArcGIS
- Descripcion: en modo satelital agregar dos `TileLayer` de referencia, transporte y lugares.
- Archivos afectados: `lib/features/mapa/mapa_screen.dart`
- Codigo clave:

```dart
if (_baseLayer == _BaseLayer.satelital)
  TileLayer(
    urlTemplate:
      'https://services.arcgisonline.com/ArcGIS/rest/services/Reference/World_Transportation/MapServer/tile/{z}/{y}/{x}',
    userAgentPackageName: 'mx.sao.geoportal_consulta',
    maxZoom: 19,
  ),
if (_baseLayer == _BaseLayer.satelital)
  TileLayer(
    urlTemplate:
      'https://services.arcgisonline.com/ArcGIS/rest/services/Reference/World_Boundaries_and_Places/MapServer/tile/{z}/{y}/{x}',
    userAgentPackageName: 'mx.sao.geoportal_consulta',
    maxZoom: 19,
  ),
```

- Tiempo estimado: 10 min
- Riesgo: Bajo

### Fase 2: Validacion
- Descripcion: compilar para asegurar integridad del cambio.
- Comando: `flutter build web`
- Resultado: exitoso
- Tiempo estimado: 10 min
- Riesgo: Bajo

## 4. Resumen de esfuerzo

| Fase | Tiempo | Riesgo |
|---|---:|---|
| Stack de referencias ArcGIS | 10 min | Bajo |
| Build y validacion | 10 min | Bajo |
| Total | 20 min | Bajo |

## 5. Criterio de exito
- En satelital se observan mejor las etiquetas de calles/avenidas y lugares.
- Persisten etiquetas de municipios/estados/lugares.
- Build web sin errores.

## 6. Resultado / evidencia
- Cambio aplicado en `lib/features/mapa/mapa_screen.dart`
- Build web completado correctamente.

## 7. Proximo paso
Publicar en `main` y validar visualmente en GitHub Pages con recarga forzada (Ctrl+F5).
