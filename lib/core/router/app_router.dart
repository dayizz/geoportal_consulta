import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../features/auth/auth_provider.dart';
import '../../features/auth/login_screen.dart';
import '../../features/mapa/mapa_screen.dart';

final appRouterProvider = Provider<GoRouter>((ref) {
  final estaAutenticado = ref.watch(estaAutenticadoProvider);

  return GoRouter(
    initialLocation: '/login',
    redirect: (context, state) {
      final enLogin = state.uri.path == '/login';
      if (!estaAutenticado && !enLogin) return '/login';
      if (estaAutenticado && enLogin) return '/mapa';
      return null;
    },
    routes: [
      GoRoute(
        path: '/login',
        builder: (_, __) => const LoginScreen(),
      ),
      GoRoute(
        path: '/mapa',
        builder: (_, __) => const MapaConsultaScreen(),
      ),
    ],
  );
});
