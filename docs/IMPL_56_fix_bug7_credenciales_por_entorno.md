# IMPL_56: Correccion Bug 7 - Credenciales por Entorno

**Estado:** Completado  
**Fecha:** 2026-07-10  
**Rama:** main

## Objetivo

Eliminar credenciales hardcodeadas del cliente y mover la autenticacion a variables de entorno para evitar exposicion de secretos en codigo fuente y binarios.

## Diagnostico / contexto actual

El archivo de autenticacion tenia usuario y contrasena en constantes compiladas en la app. Esto permitia exfiltracion de secretos desde repositorio, historial de git y build artifacts.

## Fases

### Fase 1: Remover hardcode de credenciales
- Descripcion: Reemplazar constantes literales por `String.fromEnvironment`.
- Archivos afectados: `lib/features/auth/auth_provider.dart`
- Codigo clave:
  - `GEOPORTAL_CONSULTA_USER`
  - `GEOPORTAL_CONSULTA_PASSWORD`
  - `authConfigCompleta`
- Tiempo estimado: 5 min
- Riesgo: Bajo

### Fase 2: Validacion defensiva de configuracion
- Descripcion: Bloquear login con mensaje claro cuando faltan variables de entorno.
- Archivos afectados: `lib/features/auth/login_screen.dart`
- Codigo clave:
  - Validacion previa en `_acceder()` con `authConfigCompleta`
  - Mensaje de error explicito para despliegues mal configurados
- Tiempo estimado: 5 min
- Riesgo: Bajo

## Resumen de esfuerzo

| Componente | Archivo | Cambio | Complejidad |
|---|---|---|---|
| Auth config | lib/features/auth/auth_provider.dart | Secretos -> entorno | Baja |
| Login guard | lib/features/auth/login_screen.dart | Validacion de config | Baja |

## Criterio de exito

- No existen credenciales literales en auth provider.
- El login funciona con `--dart-define` correctos.
- La app muestra error explicito cuando faltan variables.
- Sin errores de compilacion en archivos modificados.

## Resultado / evidencia

- Credenciales hardcodeadas eliminadas de auth provider.
- Agregada validacion `authConfigCompleta` en flujo de login.
- Validacion estatica: sin errores en `auth_provider.dart` y `login_screen.dart`.

## Proximo paso

Ejecutar y desplegar usando variables de entorno:

```bash
flutter run \
  --dart-define=GEOPORTAL_CONSULTA_USER=<usuario> \
  --dart-define=GEOPORTAL_CONSULTA_PASSWORD=<contrasena>
```

Para build web:

```bash
flutter build web \
  --dart-define=GEOPORTAL_CONSULTA_USER=<usuario> \
  --dart-define=GEOPORTAL_CONSULTA_PASSWORD=<contrasena>
```
