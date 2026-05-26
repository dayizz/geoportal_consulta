# IMPL_50 - Etiquetas de clave en predios con toggle ON/OFF

- Estado: Completado
- Fecha: 2026-05-26
- Rama: main

## 1. Objetivo
Mostrar una etiqueta de texto (sin recuadro) con la clave correspondiente sobre cada predio visible en mapa, con opacidad del 60%, y agregar un control de encendido/apagado.

## 2. Diagnostico / contexto actual
El mapa no mostraba etiquetas de clave sobre los predios, lo que dificultaba identificar rápidamente cada polígono sin abrir la ficha.

## 3. Fases
### Fase 1: Estado y boton de control
- Descripcion: agregar estado local para habilitar/deshabilitar etiquetas y un botón `Etiquetas ON/OFF` en la barra superior.
- Archivos afectados:
  - `lib/features/mapa/mapa_screen.dart`
- Codigo clave:
  - `_showPredioLabels`
  - botón `OutlinedButton.icon` en `_buildTopBar(...)`
- Tiempo estimado: 10 min
- Riesgo: Bajo

### Fase 2: Render de etiquetas de texto
- Descripcion: crear capa de `MarkerLayer` con etiquetas de texto sobre centroides de predios base y features importados no envolventes.
- Archivos afectados:
  - `lib/features/mapa/mapa_screen.dart`
- Codigo clave:
  - `predioLabels`
  - `_buildPlainTextLabelMarker(...)`
  - inserción de `MarkerLayer(markers: predioLabels)`
- Tiempo estimado: 20 min
- Riesgo: Bajo

## 4. Resumen de esfuerzo
| Fase | Tiempo estimado | Riesgo |
|---|---:|---|
| Fase 1 | 10 min | Bajo |
| Fase 2 | 20 min | Bajo |
| **Total** | **30 min** | **Bajo** |

## 5. Criterio de exito
- Existe botón para activar/desactivar etiquetas de clave.
- Al activar, cada predio visible muestra su clave como texto sin contenedor.
- La opacidad de texto es 60%.

## 6. Resultado / evidencia
Resultado:
- Etiquetas de clave visibles sobre predios con opacidad `0.6`.
- Toggle funcional `Etiquetas ON/OFF` en top bar.

## 7. Proximo paso
- Ajustar tamaño de fuente o regla por zoom en caso de saturación visual en vistas con mucha densidad de polígonos.
