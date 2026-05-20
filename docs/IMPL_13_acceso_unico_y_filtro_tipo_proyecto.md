# IMPL_13: Acceso único y filtro por tipo de proyecto

**Estado**: En progreso / pendiente de despliegue final  
**Fecha**: 2026-05-20  
**Rama**: main

## Objetivo

Unificar el acceso del geoportal en una sola credencial fija:
- Usuario: `ATTRAPI`
- Contraseña: `Trenes2026!`

Además, eliminar la variación de vista por contraseña, cargar todos los proyectos importados en una sola vista y agregar dentro de los filtros un criterio de "tipo de proyecto" para identificarlos.

## Diagnóstico / contexto actual

El flujo anterior usaba la contraseña para determinar el proyecto activo y limitar la carga de datos. Eso generaba una vista dependiente de la credencial y no permitía consultar todos los proyectos desde la misma sesión.

El requerimiento actual pide:
- Una sola pantalla de login.
- Una sola vista del geoportal.
- Carga de todos los proyectos importados.
- Filtro explícito por tipo de proyecto dentro del panel de filtros.

## Fases

### Fase 1: Unificar autenticación
- **Descripción**: Reemplazar el mapa de contraseñas por una sola pareja usuario/contraseña.
- **Archivos afectados**: `lib/features/auth/auth_provider.dart`, `lib/features/auth/login_screen.dart`
- **Código clave**: constantes `accesoUsuario` y `accesoContrasena`, estado `sesionActivaProvider`.
- **Tiempo estimado**: 10 min
- **Riesgo**: Bajo

### Fase 2: Eliminar selección de proyecto por credencial
- **Descripción**: Quitar la dependencia de `proyectoActivoProvider` para cargar datos.
- **Archivos afectados**: `lib/features/mapa/predios_provider.dart`, `lib/features/mapa/mapa_screen.dart`
- **Código clave**: carga completa desde backend / Supabase / GeoJSON sin `.eq('proyecto', ...)`.
- **Tiempo estimado**: 15 min
- **Riesgo**: Medio

### Fase 3: Agregar filtro de tipo de proyecto
- **Descripción**: Añadir chips de filtro para identificar proyectos por su código en el panel de filtros.
- **Archivos afectados**: `lib/features/mapa/mapa_screen.dart`
- **Código clave**: `_selectedTipoProyecto`, `_tipoProyectoLabel()`, `_countSection('Tipo de proyecto', ...)`.
- **Tiempo estimado**: 15 min
- **Riesgo**: Medio

### Fase 4: Validación y despliegue
- **Descripción**: Compilar web, validar errores y desplegar a GitHub Pages.
- **Archivos afectados**: todos los anteriores
- **Código clave**: `flutter build web --release --base-href /geoportal_consulta/`
- **Tiempo estimado**: 20 min
- **Riesgo**: Bajo

## Resumen de esfuerzo

| Actividad | Tiempo estimado | Riesgo | Estado |
|---|---:|---|---|
| Unificar autenticación | 10 min | Bajo | Hecho |
| Quitar proyecto por contraseña | 15 min | Medio | Hecho |
| Agregar filtro tipo proyecto | 15 min | Medio | Hecho |
| Validación y despliegue | 20 min | Bajo | Pendiente |

## Criterio de éxito

- El login solo pide usuario y contraseña fijos.
- La vista del mapa ya no cambia por proyecto según la contraseña.
- Todos los proyectos importados se cargan en una sola vista.
- El panel de filtros incluye un filtro por tipo de proyecto.
- La compilación Flutter web termina sin errores.

## Resultado / evidencia

- Se reemplazó el acceso por credenciales fijas.
- Se eliminó la carga filtrada por proyecto activo.
- Se agregó el filtro de tipo de proyecto dentro del panel avanzado.

## Próximo paso

Compilar, publicar y validar en producción que el login único y el filtro de tipo de proyecto funcionen correctamente.
