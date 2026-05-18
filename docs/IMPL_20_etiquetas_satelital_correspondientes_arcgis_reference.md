# IMPL_20 Etiquetas satelital correspondientes con ArcGIS Reference

Estado: Completado
Fecha: 2026-05-18
Rama: main

## 1. Objetivo
Mantener etiquetas de lugares en el mapa satelital, pero solo con rotulos correspondientes al basemap y sin lineas blancas/etiquetas inconsistentes.

## 2. Diagnostico / contexto actual
La solucion anterior removio completamente etiquetas para evitar nombres no correspondientes. Sin embargo, se requiere conservar etiquetas validas.

La causa del problema era mezclar:
- Imagen satelital de ArcGIS (`World_Imagery`)
- Etiquetas de otro proveedor (Carto `light_only_labels`)

Esa combinacion puede provocar desalineacion visual y nombres que no corresponden al mismo set cartografico.

## 3. Fases

### Fase 1: Restituir etiquetas con proveedor compatible
- Descripcion: agregar overlay de etiquetas del mismo ecosistema ArcGIS para que coincida con la capa satelital.
- Archivo afectado: `lib/features/mapa/mapa_screen.dart`
- Codigo clave:

```dart
if (_baseLayer == _BaseLayer.satelital)
  TileLayer(
    urlTemplate:
      'https://services.arcgisonline.com/ArcGIS/rest/services/Reference/World_Boundaries_and_Places/MapServer/tile/{z}/{y}/{x}',
    userAgentPackageName: 'mx.sao.geoportal_consulta',
    maxZoom: 19,
  ),
```

- Tiempo estimado: 5 min
- Riesgo: Bajo

### Fase 2: Validacion de compilacion
- Descripcion: verificar que el proyecto web compile sin errores.
- Comando: `flutter build web`
- Resultado: exitoso
- Tiempo estimado: 10 min
- Riesgo: Bajo

## 4. Resumen de esfuerzo

| Fase | Tiempo | Riesgo |
|---|---:|---|
| Reintroducir etiquetas compatibles | 5 min | Bajo |
| Build y validacion | 10 min | Bajo |
| Total | 15 min | Bajo |

## 5. Criterio de exito
- En capa satelital se muestran etiquetas de lugares/municipios.
- No aparecen lineas blancas de overlay anterior.
- Mejor correspondencia visual entre imagen y rotulos.
- Build web exitoso.

## 6. Resultado / evidencia
- Cambio aplicado en `lib/features/mapa/mapa_screen.dart`
- Build web completado sin errores.

## 7. Proximo paso
Desplegar en `main` y validar en GitHub Pages con recarga forzada (Ctrl+F5). Si algun rotulo local sigue sin corresponder, evaluar cambiar a una referencia regional mas especifica o agregar un switch para alternar etiquetas.
