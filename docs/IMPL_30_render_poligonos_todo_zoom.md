# IMPL_30_render_poligonos_todo_zoom

- Estado: Completado
- Fecha: 2026-05-25
- Rama: main

## 1. Objetivo
Evitar que los predios base desaparezcan al alejar el zoom y garantizar que los poligonos se rendericen en todos los niveles de zoom.

## 2. Diagnostico / contexto actual
El mapa tenia una condicion que solo dibujaba poligonos base a partir de zoom 10.
Esto producia desaparicion total de capas al alejar, aunque los datos existieran correctamente.

## 3. Fases
### Fase 1: Identificacion de la condicion de ocultamiento
- Descripcion: se detecto `shouldDrawPolygons() => _currentZoom >= 10`.
- Archivos afectados: lib/features/mapa/mapa_screen.dart
- Codigo clave: shouldDrawPolygons
- Tiempo estimado: 5 min
- Riesgo: Bajo

### Fase 2: Render continuo de poligonos
- Descripcion: se elimino la condicion de zoom para que los poligonos base se dibujen siempre.
- Archivos afectados: lib/features/mapa/mapa_screen.dart
- Codigo clave: shouldDrawPolygons() => true
- Tiempo estimado: 10 min
- Riesgo: Medio

### Fase 3: Validacion de build
- Descripcion: se compila el proyecto para confirmar que la correccion no rompe el web build.
- Archivos afectados: N/A
- Codigo clave: N/A
- Tiempo estimado: 10 min
- Riesgo: Bajo

## 4. Resumen de esfuerzo
| Fase | Tiempo | Riesgo |
|---|---:|---|
| Identificacion | 5 min | Bajo |
| Render continuo | 10 min | Medio |
| Validacion build | 10 min | Bajo |
| Total | 25 min | Bajo |

## 5. Criterio de exito
- Los predios base ya no desaparecen al alejar zoom.
- El mapa mantiene visibles las capas poligonales en toda la navegacion.

## 6. Resultado / evidencia
- Cambio aplicado en `lib/features/mapa/mapa_screen.dart`.
- Build web pendiente de validar y publicar.

## 7. Proximo paso
- Ejecutar `flutter build web`, publicar commit y revisar el workflow de deploy.
