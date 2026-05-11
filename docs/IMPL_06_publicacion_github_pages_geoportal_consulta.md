# IMPL_06_publicacion_github_pages_geoportal_consulta

- Estado: Implementado
- Fecha: 11-05-2026
- Rama: main

## 1. Objetivo
Publicar el geoportal de consulta en GitHub Pages con despliegue automatico desde la rama main.

## 2. Diagnostico / contexto actual
El repositorio ya estaba disponible en GitHub, pero no existia una canalizacion CI/CD para construir Flutter Web y publicar artefactos en GitHub Pages.

## 3. Fases
### Fase 1: Definir workflow de Pages
- Descripcion: Se creo un workflow de GitHub Actions para compilar y desplegar el proyecto en GitHub Pages.
- Archivos afectados: .github/workflows/deploy_github_pages.yml
- Codigo clave: jobs.build y jobs.deploy
- Tiempo estimado: 15 min
- Riesgo: Bajo

### Fase 2: Configurar build Flutter para subruta de repositorio
- Descripcion: Se definio el build con `--base-href /geoportal_consulta/` para servir correctamente desde Pages bajo el nombre del repositorio.
- Archivos afectados: .github/workflows/deploy_github_pages.yml
- Codigo clave: flutter build web --release --base-href /geoportal_consulta/
- Tiempo estimado: 10 min
- Riesgo: Medio

### Fase 3: Preparar despliegue como artefacto Pages
- Descripcion: Se agregaron acciones oficiales para configurar Pages, subir artefacto y desplegar.
- Archivos afectados: .github/workflows/deploy_github_pages.yml
- Codigo clave: actions/configure-pages, actions/upload-pages-artifact, actions/deploy-pages
- Tiempo estimado: 10 min
- Riesgo: Bajo

## 4. Resumen de esfuerzo
| Fase | Tiempo | Riesgo |
|---|---:|---|
| Fase 1 | 15 min | Bajo |
| Fase 2 | 10 min | Medio |
| Fase 3 | 10 min | Bajo |
| Total | 35 min | Bajo-Medio |

## 5. Criterio de exito
- Cada push a main ejecuta build web de Flutter en GitHub Actions.
- El sitio se publica en GitHub Pages sin pasos manuales de carga de archivos.
- La app carga correctamente desde la ruta /geoportal_consulta/.

## 6. Resultado / evidencia
- Workflow creado en .github/workflows/deploy_github_pages.yml.
- Configuracion de base-href aplicada para compatibilidad con GitHub Pages de repositorio.

## 7. Proximo paso
Validar en GitHub la ejecucion del workflow y confirmar la URL publica final del sitio.