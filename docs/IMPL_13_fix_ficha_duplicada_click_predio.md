# IMPL_13 Fix Ficha Duplicada Click Predio

Estado: Completado
Fecha: 2026-05-18
Rama: main

## 1. Objetivo
Corregir la interacción de click sobre predios para evitar que se muestren dos fichas de información al mismo tiempo cuando existe traslape entre predio base e importación GeoJSON.

## 2. Diagnóstico / contexto actual
El flujo de selección permitía asignar de forma simultánea `_selectedPredio` y `_selectedImportedFeature` en ciertos clics. En la vista, ambos paneles de detalle se renderizaban, provocando duplicidad visual.

## 3. Fases

### Fase 1: Prioridad de selección en tap
- Descripción: ajustar lógica del `onTap` para que exista una sola selección activa.
- Archivos afectados: `lib/features/mapa/mapa_screen.dart`
- Código clave:
  - Si existe `tappedImported`, asignar `_selectedImportedFeature` y limpiar `_selectedPredio`.
  - Si no existe `tappedImported`, asignar `_selectedPredio` y limpiar `_selectedImportedFeature`.
- Tiempo estimado: 10 min
- Riesgo: Bajo

### Fase 2: Render exclusivo de panel de detalle
- Descripción: cambiar render condicional para mostrar solo un panel, priorizando la ficha más reciente implementada (GeoJSON importado).
- Archivos afectados: `lib/features/mapa/mapa_screen.dart`
- Código clave:
  - `if (_selectedImportedFeature != null) ... else if (_selectedPredio != null) ...`
- Tiempo estimado: 10 min
- Riesgo: Bajo

### Fase 3: Validación de compilación
- Descripción: compilar Flutter Web para verificar que no existan errores por la modificación.
- Archivos afectados: sin cambios adicionales
- Código clave: `flutter build web`
- Tiempo estimado: 5 min
- Riesgo: Bajo

## 4. Resumen de esfuerzo

| Fase | Tiempo | Riesgo |
|---|---:|---|
| Prioridad de selección en tap | 10 min | Bajo |
| Render exclusivo de panel | 10 min | Bajo |
| Validación compilación web | 5 min | Bajo |
| Total | 25 min | Bajo |

## 5. Criterio de éxito
- Al hacer click en un predio con traslape, solo aparece una ficha de información.
- La ficha visible corresponde a la última ficha incorporada en código (GeoJSON importado), cuando aplica.
- Compilación web exitosa.

## 6. Resultado / evidencia
- Implementación aplicada en `mapa_screen.dart`.
- Lógica de selección ahora garantiza exclusividad.
- Compilación ejecutada con éxito: `flutter build web`.

## 7. Próximo paso
Publicar cambios en remoto y validar en ambiente desplegado que no aparezca doble ficha en casos de traslape.
