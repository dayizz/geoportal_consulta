# IMPL_35 - Persistencia de toggle de agrupacion

- Estado: Completado
- Fecha: 2026-05-26
- Rama: main

## 1. Objetivo
Persistir el estado del boton de Agrupacion ON/OFF para que se mantenga despues de recargar la aplicacion.

## 2. Diagnostico / contexto actual
El toggle de agrupacion existia en barra superior, pero al recargar la app siempre regresaba al valor por defecto.

## 3. Fases
### Fase 1: Dependencia de persistencia
- Descripcion: Agregar `shared_preferences` para guardar preferencias locales.
- Archivos afectados:
  - `pubspec.yaml`
- Codigo clave:
  - `shared_preferences: ^2.3.2`
- Tiempo estimado: 5 min
- Riesgo: Bajo

### Fase 2: Carga inicial del estado
- Descripcion: Leer la preferencia guardada al iniciar la pantalla del mapa.
- Archivos afectados:
  - `lib/features/mapa/mapa_screen.dart`
- Codigo clave:
  - `_groupingEnabledPrefKey`
  - `_loadGroupingPreference()`
  - llamada en `initState()`
- Tiempo estimado: 15 min
- Riesgo: Bajo

### Fase 3: Guardado al cambiar toggle
- Descripcion: Guardar automaticamente el valor cada vez que el usuario alterna ON/OFF.
- Archivos afectados:
  - `lib/features/mapa/mapa_screen.dart`
- Codigo clave:
  - `_setGroupingEnabled(bool value)`
  - uso en `onPressed` del boton de agrupacion.
- Tiempo estimado: 10 min
- Riesgo: Bajo

## 4. Resumen de esfuerzo
| Fase | Tiempo estimado | Riesgo |
|---|---:|---|
| Fase 1 | 5 min | Bajo |
| Fase 2 | 15 min | Bajo |
| Fase 3 | 10 min | Bajo |
| **Total** | **30 min** | **Bajo** |

## 5. Criterio de exito
- El estado de Agrupacion ON/OFF se conserva despues de recargar la app.
- El comportamiento visual del mapa coincide con el estado restaurado.

## 6. Resultado / evidencia
Resultado:
- Estado de agrupacion persistido con `shared_preferences`.
- Se restaura automaticamente en `initState`.
- El boton en barra superior actualiza UI y almacena preferencia en cada cambio.

## 7. Proximo paso
- Opcional: persistir tambien otras preferencias visuales (modo de color, capa base, filtros recurrentes) para homogeneizar experiencia.
