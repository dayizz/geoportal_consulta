import 'package:flutter_riverpod/flutter_riverpod.dart';

const accesoUsuario = String.fromEnvironment('GEOPORTAL_CONSULTA_USER');
const accesoContrasena = String.fromEnvironment('GEOPORTAL_CONSULTA_PASSWORD');

bool get authConfigCompleta =>
  accesoUsuario.trim().isNotEmpty && accesoContrasena.isNotEmpty;

/// Estado de autenticación de la sesión actual.
final sesionActivaProvider = StateProvider<bool>((ref) => false);

/// Estado de autenticación
final estaAutenticadoProvider = Provider<bool>((ref) {
  return ref.watch(sesionActivaProvider);
});
