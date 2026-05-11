# IMPL_01_fix_error_backend_8000_mapa

- Estado: Implementado
- Fecha: 11-05-2026
- Rama: N/A (workspace sin repositorio git inicializado)

## 1. Objetivo
Evitar que la pantalla de mapa falle cuando el backend local en puerto 8000 no esta disponible.

## 2. Diagnostico / contexto actual
La aplicacion web cargaba, pero al solicitar datos en los endpoints locales /predios y /municipios aparecia error de conexion rechazada (ERR_CONNECTION_REFUSED).

## 3. Fases
### Fase 1: Identificacion del origen del error
- Descripcion: Verificacion de logs de navegador y terminal para ubicar endpoint y proveedor implicado.
- Archivos afectados: lib/features/mapa/predios_provider.dart
- Codigo clave: _backendBaseUrl, prediosConsultaProvider
- Tiempo estimado: 10 min
- Riesgo: Bajo

### Fase 2: Hardening del proveedor de predios
- Descripcion: Envolver llamadas HTTP en try/catch con timeout y retorno seguro de lista vacia.
- Archivos afectados: lib/features/mapa/predios_provider.dart
- Codigo clave: prediosConsultaProvider con timeout de 3 segundos y fallback seguro
- Tiempo estimado: 15 min
- Riesgo: Bajo

### Fase 3: Validacion funcional
- Descripcion: Hot reload y verificacion sin errores de compilacion en archivo modificado.
- Archivos afectados: lib/features/mapa/predios_provider.dart
- Codigo clave: get_errors + recarga en ejecucion
- Tiempo estimado: 5 min
- Riesgo: Bajo

## 4. Resumen de esfuerzo
| Fase | Tiempo | Riesgo |
|---|---:|---|
| Fase 1 | 10 min | Bajo |
| Fase 2 | 15 min | Bajo |
| Fase 3 | 5 min | Bajo |
| Total | 30 min | Bajo |

## 5. Criterio de exito
- La vista no muestra excepcion por falla de backend local.
- El proveedor de predios responde de forma estable aunque el backend no este disponible.

## 6. Resultado / evidencia
- Se actualizo el proveedor de predios para no lanzar excepcion en caso de backend caido.
- Se aplico timeout para evitar espera indefinida de red.
- Verificacion de errores del archivo: sin errores.

## 7. Proximo paso
Levantar el backend local en puerto 8000 o configurar Supabase real para visualizar datos reales de predios en el mapa.
