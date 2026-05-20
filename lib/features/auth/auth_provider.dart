import 'package:flutter_riverpod/flutter_riverpod.dart';

const accesoUsuario = 'ATTRAPI';
const accesoContrasena = 'Trenes2026!';

/// Estado de autenticación de la sesión actual.
final sesionActivaProvider = StateProvider<bool>((ref) => false);

/// Estado de autenticación
final estaAutenticadoProvider = Provider<bool>((ref) {
  return ref.watch(sesionActivaProvider);
});
