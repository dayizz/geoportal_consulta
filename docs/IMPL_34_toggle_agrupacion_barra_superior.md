# IMPL_34 - Toggle de agrupacion en barra superior

- Estado: Completado
- Fecha: 2026-05-26
- Rama: main

## 1. Objetivo
Agregar un boton en la barra superior para activar y desactivar la funcion de agrupacion (clusters) en el mapa, sin afectar los filtros existentes.

## 2. Diagnostico / contexto actual
La agrupacion se aplicaba automaticamente por zoom y no existia control explicito en UI para el usuario.

## 3. Fases
### Fase 1: Estado de control de agrupacion
- Descripcion: Crear bandera de estado para habilitar/deshabilitar agrupacion.
- Archivos afectados:
  - `lib/features/mapa/mapa_screen.dart`
- Codigo clave:
  - `bool _groupingEnabled = true;`
- Tiempo estimado: 10 min
- Riesgo: Bajo

### Fase 2: Integracion del toggle en barra superior
- Descripcion: Agregar boton en top bar para alternar Agrupacion ON/OFF.
- Archivos afectados:
  - `lib/features/mapa/mapa_screen.dart`
- Codigo clave:
  - `OutlinedButton.icon(...)` con cambio de icono/estilo segun estado.
- Tiempo estimado: 20 min
- Riesgo: Bajo

### Fase 3: Aplicacion del estado al render de clusters
- Descripcion: Condicionar agrupacion de predios e importados al estado del toggle.
- Archivos afectados:
  - `lib/features/mapa/mapa_screen.dart`
- Codigo clave:
  - `if (_groupingEnabled && bucketSize > 0) ...`
  - `shouldDrawImportedGroups() => _groupingEnabled && bucketSize > 0 && _currentZoom < 10`
- Tiempo estimado: 15 min
- Riesgo: Bajo

## 4. Resumen de esfuerzo
| Fase | Tiempo estimado | Riesgo |
|---|---:|---|
| Fase 1 | 10 min | Bajo |
| Fase 2 | 20 min | Bajo |
| Fase 3 | 15 min | Bajo |
| **Total** | **45 min** | **Bajo** |

## 5. Criterio de exito
- El usuario puede activar/desactivar agrupacion desde la barra superior.
- Con OFF no se renderizan clusters de agrupacion.
- Con ON se mantiene el comportamiento previo por zoom.

## 6. Resultado / evidencia
Resultado:
- Se agrego boton `Agrupacion ON/OFF` en barra superior.
- Se conecto el estado del boton con la logica de agrupacion de predios e importados.
- Se mantiene compatibilidad con filtros avanzados y render existente.

## 7. Proximo paso
- Validar UX en zoom bajo/alto para confirmar que el comportamiento ON/OFF es el esperado para el equipo operativo.
