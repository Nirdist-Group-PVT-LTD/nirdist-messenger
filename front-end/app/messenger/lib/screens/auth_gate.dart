import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../state/session_controller.dart';
import 'login_screen.dart';
import 'messenger_shell.dart';

class AuthGate extends StatelessWidget {
  const AuthGate({super.key});

  @override
  Widget build(BuildContext context) {
    return Consumer<SessionController>(
      builder: (context, controller, _) {
        if (controller.isBootstrapping) {
          return const _BootSplashScreen();
        }

        return AnimatedSwitcher(
          duration: const Duration(milliseconds: 260),
          switchInCurve: Curves.easeOutCubic,
          switchOutCurve: Curves.easeInCubic,
          child: controller.isAuthenticated
              ? MessengerShell(
                  key: const ValueKey<String>('home-shell'),
                  session: controller.session!,
                  apiBaseUrl: controller.apiBaseUrl,
                  onSignOut: controller.signOut,
                )
              : const LoginScreen(key: ValueKey<String>('login-screen')),
        );
      },
    );
  }
}

class _BootSplashScreen extends StatelessWidget {
  const _BootSplashScreen();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: <Color>[
              Color(0xFF09131B),
              Color(0xFF081720),
              Color(0xFF061016),
            ],
          ),
        ),
        child: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              Container(
                width: 88,
                height: 88,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: const LinearGradient(
                    colors: <Color>[Color(0xFF0ED1C6), Color(0xFFFFB84D)],
                  ),
                  boxShadow: <BoxShadow>[
                    BoxShadow(
                      color: const Color(0xFF0ED1C6).withValues(alpha: 0.35),
                      blurRadius: 28,
                      spreadRadius: 4,
                    ),
                  ],
                ),
                child: const Icon(Icons.chat_bubble_rounded, color: Colors.black, size: 38),
              ),
              const SizedBox(height: 24),
              Text(
                'Nirdist Messenger',
                style: Theme.of(context).textTheme.headlineMedium,
              ),
              const SizedBox(height: 10),
              Text(
                'Restoring your secure session...',
                style: Theme.of(context).textTheme.bodyMedium,
              ),
              const SizedBox(height: 24),
              const SizedBox(
                width: 28,
                height: 28,
                child: CircularProgressIndicator(strokeWidth: 2.6),
              ),
            ],
          ),
        ),
      ),
    );
  }
}