# BUG #7: Hardcoded Credentials in Public Application

**Severidad**: 🔴 CRÍTICA — Exposición de secretos  
**Archivo**: `geoportal_consulta/lib/features/auth/auth_provider.dart` líneas 3-4  
**Tipo**: Information disclosure / Secrets exposure  
**Impacto**: Credenciales públicamente accesibles en repositorio GitHub  

---

## Problema

Las credenciales de acceso están hardcodeadas en el código fuente de la aplicación pública:

```dart
// geoportal_consulta/lib/features/auth/auth_provider.dart
const accesoUsuario = 'ATTRAPI';
const accesoContrasena = 'Trenes2026!';
```

---

## Vulnerabilidades

### 1. **GitHub Repository Exposure**
- Código está en repositorio público
- Cualquiera puede clonar y obtener las credenciales
- Git history contiene todas las versiones (incluso si se borran después)
- Bots automáticos escanean repositorios buscando secretos

### 2. **Credential Hardcoding Anti-Pattern**
- Violación de OWASP Top 10 (Cryptographic Failures)
- No se puede cambiar credenciales sin redeploy
- Imposible tener diferentes credenciales por entorno

### 3. **Scope Incorrecto**
- Son `const` → compiladas directamente en binario
- Accesibles mediante decompilación de APK/app binaria
- Trazables en variables de la JVM

---

## Riesgo Actual

```
Atacante workflow:
1. Clone repo público:
   $ git clone https://github.com/dayizz/GEOPORTAL-DE-GESTION-.git

2. Busque "constante" en auth_provider.dart
   $ grep -r "const acces" *

3. Obtenga credenciales:
   usuario: ATTRAPI
   contraseña: Trenes2026!

4. Use las credenciales en:
   - app pública (si hay bypass de autenticación)
   - scripts de scraping
   - ataques de fuerza bruta a otros sistemas con mismo usuario
```

---

## Solución Recomendada

### Opción 1: Environment-Based Configuration (RECOMENDADO)
```dart
// No hardcoding. Cargar desde:
- flutter_dotenv (.env files, NO commited)
- CI/CD secrets
- Server-side configuration

// Código
class AuthConfig {
  static String get usuario => String.fromEnvironment('AUTH_USER', defaultValue: '');
  static String get contrasena => String.fromEnvironment('AUTH_PASS', defaultValue: '');
}
```

### Opción 2: Backend-Provided Credentials
```dart
// El backend devuelve token/sesión después de verificar cliente
// No enviar credenciales en cliente en absoluto
// Cliente solo envía: app_id + device_token
// Backend verifica y devuelve JWT temporario
```

### Opción 3: OAuth/SSO
```dart
// Usar Firebase Auth o similar
// No almacenar credenciales en cliente
// Usar tokens seguros
```

---

## Pasos Inmediatos de Remediation

1. **Revocar credenciales existentes**
   - Cambiar `ATTRAPI` / `Trenes2026!` en sistema
   - Si es cuenta en servicios externos, resetear password

2. **Limpiar Git History**
   ```bash
   # Requiere force push - cuidado!
   git-filter-branch --tree-filter 'sed -i "s/Trenes2026\!/REDACTED/g" *' -- --all
   git push origin main --force-with-lease
   ```

3. **Agregar .gitignore**
   ```
   # Secretos en git
   .env
   .env.local
   *.secret
   firebase_credentials.json
   ```

4. **Instalar secret scanning**
   - GitHub: Settings → Code security → Secret scanning
   - Pre-commit hooks: `git-secrets`, `detect-secrets`

---

## Status

🔴 **CRÍTICO — REQUERIDA ACCIÓN INMEDIATA**
1. Revocar credenciales
2. Cambiar a environment-based config
3. Limpiar history de Git
4. Notificar a administrador de infraestructura

---

## Nota de Seguridad

Si `ATTRAPI`/`Trenes2026!` se usa en múltiples sistemas:
- ✓ Cambiar en todos lados
- ✓ Auditar acceso histórico
- ✓ Investigar si fueron usadas por terceros

Si es apenas un usuario de prueba:
- ✓ Deshabilitar cuenta
- ✓ Cambiar a account de staging real

---

## Checklist de Remediación

- [ ] Revocar credenciales en sistema
- [ ] Cambiar código a environment variables
- [ ] Compilar y testear
- [ ] Push a nueva rama (sin secretos)
- [ ] Limpiar Git history
- [ ] Configurar GitHub secret scanning
- [ ] Agregar .gitignore
- [ ] Notificar equipo de seguridad
- [ ] Documentar credenciales en password manager (no en repo)

