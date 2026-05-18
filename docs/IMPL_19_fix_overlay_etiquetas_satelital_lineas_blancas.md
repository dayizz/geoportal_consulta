# IMPL_19 fix overlay etiquetas satelital lineas blancas

Estado: Completado
Fecha: 2026-05-18
Rama: main

## 1. Objetivo
Eliminar lineas blancas y etiquetas de lugares incorrectas que aparecian sobre el mapa satelital.

## 2. Diagnostico / contexto actual
La capa satelital usaba un overlay adicional de etiquetas transparentes (light_only_labels), que en la practica dibujaba trazos blancos y rotulos inconsistentes para calles, avenidas y lugares.

## 3. Fases

### Fase 1: Quitar overlay de etiquetas en satelital
- Descripcion: remover TileLayer adicional aplicado solo cuando la base era satelital.
- Archivos afectados: lib/features/mapa/mapa_screen.dart
- Codigo clave: eliminacion del bloque TileLayer con url de light_only_labels.
- Tiempo estimado: 5 min
- Riesgo: Bajo

### Fase 2: Validacion
- Descripcion: compilar web para confirmar integridad del cambio.
- Archivos afectados: build/web (generado)
- Comando: flutter build web
- Tiempo estimado: 10 min
- Riesgo: Bajo

## 4. Resumen de esfuerzo

| Fase | Tiempo | Riesgo |
|---|---:|---|
| Quitar overlay etiquetas | 5 min | Bajo |
| Validacion build | 10 min | Bajo |
| Total | 15 min | Bajo |

## 5. Criterio de exito
- No aparecen lineas blancas sobre la vista satelital.
- No aparecen etiquetas inconsistentes de calles/lugares en satelital.
- Build web exitoso.

## 6. Resultado / evidencia
- Cambio aplicado en lib/features/mapa/mapa_screen.dart
- Build web completado sin errores

## 7. Proximo paso
Publicar en main y validar visualmente en GitHub Pages con recarga forzada del navegador.
