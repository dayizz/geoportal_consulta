import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';

import 'auth_provider.dart';

class LoginScreen extends ConsumerStatefulWidget {
  const LoginScreen({super.key});

  @override
  ConsumerState<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends ConsumerState<LoginScreen> {
  final _usuarioAccesoCtrl = TextEditingController();
  final _claveAccesoCtrl = TextEditingController();
  final _emailCtrl = TextEditingController();
  final _passwordCtrl = TextEditingController();
  bool _obscureAccess = true;
  bool _obscure = true;
  String? _error;
  bool _loading = false;

  static const _usuarioAccesoPermitido = 'ATTRAPI';
  static const _claveAccesoPermitida = 'Trenes2026!';
  static const _emailPermitido = 'admin@sao.mx';

  @override
  void dispose() {
    _usuarioAccesoCtrl.dispose();
    _claveAccesoCtrl.dispose();
    _emailCtrl.dispose();
    _passwordCtrl.dispose();
    super.dispose();
  }

  Future<void> _acceder() async {
    setState(() {
      _error = null;
      _loading = true;
    });

    await Future.delayed(const Duration(milliseconds: 300));

    final usuarioAcceso = _usuarioAccesoCtrl.text.trim();
    final claveAcceso = _claveAccesoCtrl.text;
    final email = _emailCtrl.text.trim().toLowerCase();
    final password = _passwordCtrl.text.trim();
    final proyecto = extraerProyecto(password);

    if (usuarioAcceso != _usuarioAccesoPermitido ||
        claveAcceso != _claveAccesoPermitida) {
      setState(() {
        _error = 'Usuario o contraseña de acceso inválidos.';
        _loading = false;
      });
      return;
    }

    if (email != _emailPermitido) {
      setState(() {
        _error = 'Correo no autorizado.';
        _loading = false;
      });
      return;
    }

    if (proyecto != null) {
      ref.read(proyectoActivoProvider.notifier).state = proyecto;
      if (mounted) context.go('/mapa');
    } else {
      setState(() {
        _error = 'Contraseña incorrecta. Verifica tus credenciales.';
        _loading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;
    final isWide = size.width > 800;

    return Scaffold(
      body: Row(
        children: [
          // Panel izquierdo informativo (solo en pantallas anchas)
          if (isWide)
            Expanded(
              child: Container(
                decoration: const BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [Color(0xFF1B4332), Color(0xFF2D6A4F)],
                  ),
                ),
                child: Padding(
                  padding: const EdgeInsets.all(48),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Icon(Icons.map_rounded, color: Colors.white, size: 64),
                      const SizedBox(height: 24),
                      Text(
                        'Geoportal de\nConsulta',
                        style: GoogleFonts.inter(
                          color: Colors.white,
                          fontSize: 40,
                          fontWeight: FontWeight.w700,
                          height: 1.2,
                        ),
                      ),
                      const SizedBox(height: 16),
                      Text(
                        'Visualización de predios por proyecto.\nAccede con tu correo y contraseña.',
                        style: GoogleFonts.inter(
                          color: Colors.white.withOpacity(0.8),
                          fontSize: 16,
                          height: 1.5,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),

          // Panel de login
          Expanded(
            child: Center(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(32),
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 400),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      if (!isWide) ...[
                        const Icon(
                          Icons.map_rounded,
                          size: 64,
                          color: Color(0xFF1B4332),
                        ),
                        const SizedBox(height: 16),
                        Text(
                          'Geoportal de Consulta',
                          textAlign: TextAlign.center,
                          style: GoogleFonts.inter(
                            fontSize: 28,
                            fontWeight: FontWeight.w700,
                            color: const Color(0xFF1B4332),
                          ),
                        ),
                        const SizedBox(height: 8),
                      ],
                      Text(
                        'Ingresa tus credenciales de acceso',
                        style: GoogleFonts.inter(
                          fontSize: 16,
                          color: Colors.grey[600],
                        ),
                        textAlign: isWide ? TextAlign.left : TextAlign.center,
                      ),
                      const SizedBox(height: 32),

                      TextFormField(
                        controller: _usuarioAccesoCtrl,
                        decoration: InputDecoration(
                          labelText: 'Usuario de acceso',
                          prefixIcon: const Icon(Icons.person_outline),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                        onFieldSubmitted: (_) => _acceder(),
                      ),
                      const SizedBox(height: 16),

                      TextFormField(
                        controller: _claveAccesoCtrl,
                        obscureText: _obscureAccess,
                        decoration: InputDecoration(
                          labelText: 'Contraseña de acceso',
                          prefixIcon: const Icon(Icons.shield_outlined),
                          suffixIcon: IconButton(
                            icon: Icon(
                              _obscureAccess
                                  ? Icons.visibility_off
                                  : Icons.visibility,
                            ),
                            onPressed: () =>
                                setState(() => _obscureAccess = !_obscureAccess),
                          ),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                        onFieldSubmitted: (_) => _acceder(),
                      ),
                      const SizedBox(height: 16),

                      // Campo de correo
                      TextFormField(
                        controller: _emailCtrl,
                        keyboardType: TextInputType.emailAddress,
                        decoration: InputDecoration(
                          labelText: 'Correo electrónico',
                          prefixIcon: const Icon(Icons.email_outlined),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                        onFieldSubmitted: (_) => _acceder(),
                      ),
                      const SizedBox(height: 16),

                      // Campo de contraseña
                      TextFormField(
                        controller: _passwordCtrl,
                        obscureText: _obscure,
                        decoration: InputDecoration(
                          labelText: 'Contraseña del proyecto',
                          prefixIcon: const Icon(Icons.lock_outline),
                          suffixIcon: IconButton(
                            icon: Icon(
                              _obscure ? Icons.visibility_off : Icons.visibility,
                            ),
                            onPressed: () =>
                                setState(() => _obscure = !_obscure),
                          ),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                          errorText: _error,
                        ),
                        onFieldSubmitted: (_) => _acceder(),
                      ),
                      const SizedBox(height: 20),

                      // Botón de acceso
                      SizedBox(
                        height: 52,
                        child: ElevatedButton(
                          onPressed: _loading ? null : _acceder,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFF1B4332),
                            foregroundColor: Colors.white,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ),
                          child: _loading
                              ? const SizedBox(
                                  height: 20,
                                  width: 20,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                    color: Colors.white,
                                  ),
                                )
                              : Text(
                                  'Acceder al mapa',
                                  style: GoogleFonts.inter(
                                    fontSize: 16,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
