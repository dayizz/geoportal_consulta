# IMPL 55 - Conexion de geoportal_consulta a la base de geoportal-lddv

- Estado: Completado
- Fecha: 2026-07-10
- Rama: main

## 1. Objetivo
Hacer que `geoportal_consulta` consuma la base compartida de `geoportal-lddv` para mostrar predios desde el mismo origen de datos, sin depender de Supabase, del backend local de consulta ni de datos locales embebidos.

## 2. Diagnostico / contexto actual
Antes del cambio, `geoportal_consulta` cargaba predios desde un GeoJSON local y mantenia referencias heredadas a Supabase. Eso evitaba que la consulta reflejara la misma base que administra `geoportal-lddv`.

En la version actual, la consulta ya no tiene fallback local: si el backend de gestion no responde, la pantalla se queda sin datos en lugar de mezclar informacion interna con la vista publica.

`geoportal-lddv` ya expone los predios normalizados desde su backend FastAPI en `GET /api/v1/predios` y el catalogo de municipios en `GET /api/v1/municipios`, con campos compatibles para la visualizacion publica.

## 3. Fases
### Fase 1 - Identificacion del punto de integracion
- Descripcion: revision del provider de predios en consulta y del backend de LDDV para confirmar que el origen compartido era el endpoint REST de predios.
- Archivos afectados: `lib/features/mapa/predios_provider.dart`, `backend/app/main.py`.
- Codigo clave: `GET /api/v1/predios`, `GET /api/v1/municipios` y `Predio.fromMap(...)`.
- Tiempo estimado: 20 min.
- Riesgo: bajo.

### Fase 2 - Cambio de fuente de datos
- Descripcion: sustitucion del origen local por una llamada al backend de gestion, sin respaldo local.
- Archivos afectados: `lib/features/mapa/predios_provider.dart`.
- Codigo clave: intento de `http.get('$_backendBaseUrl/api/v1/predios')` y retorno de lista vacia si falla la conexion.
- Tiempo estimado: 35 min.
- Riesgo: medio.

### Fase 3 - Limpieza de arranque
- Descripcion: retiro de la inicializacion heredada de Supabase en el punto de entrada y actualizacion de comentarios desfasados.
- Archivos afectados: `lib/main.dart`, `lib/features/mapa/mapa_screen.dart`.
- Codigo clave: `runApp(const ProviderScope(...))` sin inicializacion externa.
- Tiempo estimado: 10 min.
- Riesgo: bajo.

### Fase 4 - Documentacion y validacion
- Descripcion: actualizacion de este documento e inspeccion puntual de errores en los archivos tocados.
- Archivos afectados: `docs/IMPL_55_conexion_geoportal_consulta_base_lddv.md`.
- Codigo clave: validacion sin errores en `predios_provider.dart`, `main.dart` y `mapa_screen.dart`.
- Tiempo estimado: 10 min.
- Riesgo: bajo.

## 4. Resumen de esfuerzo
| Fase | Tiempo estimado | Riesgo |
|---|---:|---|
| Identificacion | 20 min | Bajo |
| Cambio de fuente | 35 min | Medio |
| Limpieza de arranque | 10 min | Bajo |
| Documentacion / validacion | 10 min | Bajo |
| **Total** | **75 min** | **Bajo-Medio** |

## 5. Criterio de exito
- `geoportal_consulta` obtiene predios desde el backend de `geoportal-lddv` a traves de la API versionada.
- Si el backend no esta disponible, la vista no utiliza informacion local embebida.
- Ya no existe una dependencia funcional de Supabase en el flujo de consulta.

## 6. Resultado / evidencia
Resultado obtenido:
- El provider de predios consulta primero `GET /api/v1/predios` en la base compartida de gestion.
- Si la llamada falla, la vista no mezcla datos locales y devuelve vacio.
- Se elimino la inicializacion heredada de Supabase en el arranque.

Evidencia clave:
- Validacion sin errores en `lib/features/mapa/predios_provider.dart`.
- Validacion sin errores en `lib/main.dart`.
- Validacion sin errores en `lib/features/mapa/mapa_screen.dart`.

## 7. Proximo paso
- Levantar el backend de `geoportal-lddv` y abrir `geoportal_consulta` para verificar que el mapa muestre los predios reales de la base compartida.