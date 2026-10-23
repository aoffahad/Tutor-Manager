import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../auth/auth_repository.dart';
import '../../features/auth/login_screen.dart';
import '../../features/dashboard/dashboard_screen.dart';
import '../../features/students/add_student_screen.dart';
import '../../features/students/students_screen.dart';
import '../../features/dues/dues_screen.dart';
import '../../features/received/received_screen.dart';
import '../../data/models/student.dart';
import 'app_shell.dart';

final appRouterProvider = Provider<GoRouter>((ref) {
  final refresh = _RouterRefresh();
  ref.listen(authStateProvider, (_, _) => refresh.notify());

  final router = GoRouter(
    initialLocation: '/home',
    refreshListenable: refresh,
    redirect: (context, state) {
      final auth = ref.read(authStateProvider);
      if (auth.isLoading) {
        return state.matchedLocation == '/loading' ? null : '/loading';
      }

      final signedIn = auth is AsyncData<AuthUser?> && auth.value != null;
      final onLogin = state.matchedLocation == '/login';
      final onLoading = state.matchedLocation == '/loading';
      if (!signedIn && !onLogin) return '/login';
      if (signedIn && (onLogin || onLoading)) return '/home';
      return null;
    },
    routes: [
      GoRoute(
        path: '/loading',
        builder: (context, state) => const _AuthLoadingScreen(),
      ),
      GoRoute(path: '/login', builder: (context, state) => const LoginScreen()),
      StatefulShellRoute.indexedStack(
        builder: (context, state, navigationShell) =>
            AppShell(navigationShell: navigationShell),
        branches: [
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: '/home',
                builder: (context, state) => const DashboardScreen(),
              ),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: '/students',
                builder: (context, state) => StudentsScreen(
                  initialFilter: state.uri.queryParameters['filter'] ?? 'all',
                ),
              ),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: '/add',
                builder: (context, state) => AddStudentScreen(
                  student: state.extra is Student
                      ? state.extra as Student
                      : null,
                ),
              ),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: '/dues',
                builder: (context, state) => const DuesScreen(),
              ),
            ],
          ),
        ],
      ),
      GoRoute(
        path: '/received',
        builder: (context, state) => const ReceivedScreen(),
      ),
    ],
  );

  ref.onDispose(() {
    router.dispose();
    refresh.dispose();
  });
  return router;
});

class _RouterRefresh extends ChangeNotifier {
  void notify() => notifyListeners();
}

class _AuthLoadingScreen extends StatelessWidget {
  const _AuthLoadingScreen();

  @override
  Widget build(BuildContext context) =>
      const Scaffold(body: Center(child: CircularProgressIndicator()));
}
