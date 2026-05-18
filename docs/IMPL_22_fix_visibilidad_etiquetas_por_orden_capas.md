# IMPL_22 fix visibilidad de etiquetas por orden de capas

Estado: Completado
Fecha: 2026-05-18
Rama: main

## 1. Objetivo
Corregir que las etiquetas no se visualicen en capa satelital, aun cuando los tiles de referencia se cargan correctamente.

## 2. Diagnostico / contexto actual
Se verifico que los endpoints de etiquetas ArcGIS responden correctamente (`HTTP 200`, `image/png`), por lo que el problema no era de red ni URL.

Causa raiz:
- Las capas de etiquetas se renderizaban antes de capas vectoriales (poligonos/polilineas/markers).
- Las capas vectoriales posteriores tapaban visualmente las etiquetas, dando la impresion de que no existian.

## 3. Fases

### Fase 1: Reordenamiento del stack de capas
- Descripcion: mover TileLayer de etiquetas satelitales al final del arreglo `children` de `FlutterMap`.
- Archivo afectado: `lib/features/mapa/mapa_screen.dart`
- Codigo clave:

```dart
if (_baseLayer == _BaseLayer.satelital)
  TileLayer(urlTemplate: '...World_Transportation...'),
if (_baseLayer == _BaseLayer.satelital)
  TileLayer(urlTemplate: '...World_Boundaries_and_Places...'),
```

Ubicacion nueva: despues de capas vectoriales y antes del pin seleccionado.

- Tiempo estimado: 10 min
- Riesgo: Bajo

### Fase 2: Validacion
- Descripcion: compilar web para verificar integridad.
- Comando: `flutter build web`
- Resultado: exitoso
- Tiempo estimado: 10 min
- Riesgo: Bajo

## 4. Resumen de esfuerzo

| Fase | Tiempo | Riesgo |
|---|---:|---|
| Reordenar capas | 10 min | Bajo |
| Build y validacion | 10 min | Bajo |
| Total | 20 min | Bajo |

## 5. Criterio de exito
- Etiquetas visibles en modo satelital.
- Sin perdida de capas vectoriales.
- Build web sin errores.

## 6. Resultado / evidencia
- Archivo modificado: `lib/features/mapa/mapa_screen.dart`
- Build: exitoso
- Endpoints etiquetas: confirmados con HTTP 200

## 7. Proximo paso
Publicar y validar en GitHub Pages con recarga forzada (Ctrl+F5). Si la densidad de etiquetas es excesiva, incorporar toggle de visibilidad de etiquetas.
