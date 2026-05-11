import 'package:flutter_riverpod/flutter_riverpod.dart';

// Mapa de contraseñas → proyecto
const Map<String, String> proyectoPasswords = {
  'TQI123': 'TQI',
  'TSNL123': 'TSNL',
  'TQM123': 'TQM',
  'TAP123': 'TAP',
};

String? extraerProyecto(String password) => proyectoPasswords[password];

/// Proyecto activo en la sesión actual (null = no autenticado)
final proyectoActivoProvider = StateProvider<String?>((ref) => null);

/// Estado de autenticación
final estaAutenticadoProvider = Provider<bool>((ref) {
  return ref.watch(proyectoActivoProvider) != null;
});
