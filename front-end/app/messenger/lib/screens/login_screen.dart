import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../state/session_controller.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final GlobalKey<FormState> _formKey = GlobalKey<FormState>();
  final TextEditingController _tokenController = TextEditingController();
  final TextEditingController _usernameController = TextEditingController();
  final TextEditingController _displayNameController = TextEditingController();
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _avatarUrlController = TextEditingController();

  @override
  void dispose() {
    _tokenController.dispose();
    _usernameController.dispose();
    _displayNameController.dispose();
    _emailController.dispose();
    _avatarUrlController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Scaffold(
      body: Stack(
        children: <Widget>[
          const _LoginBackdrop(),
          SafeArea(
            child: Center(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(24),
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 560),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: <Widget>[
                      _HeroHeader(colorScheme: colorScheme),
                      const SizedBox(height: 22),
                      _LoginCard(
                        formKey: _formKey,
                        tokenController: _tokenController,
                        usernameController: _usernameController,
                        displayNameController: _displayNameController,
                        emailController: _emailController,
                        avatarUrlController: _avatarUrlController,
                        onSubmit: _submit,
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

  Future<void> _submit() async {
    final formState = _formKey.currentState;
    if (formState == null || !formState.validate()) {
      return;
    }

    FocusScope.of(context).unfocus();

    final controller = context.read<SessionController>();
    final success = await controller.signIn(
      idToken: _tokenController.text.trim(),
      username: _trimmedOrNull(_usernameController.text),
      displayName: _trimmedOrNull(_displayNameController.text),
      email: _trimmedOrNull(_emailController.text),
      avatarUrl: _trimmedOrNull(_avatarUrlController.text),
    );

    if (!mounted) {
      return;
    }

    if (!success) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(controller.errorMessage ?? 'Unable to sign in.'),
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  String? _trimmedOrNull(String value) {
    final trimmed = value.trim();
    return trimmed.isEmpty ? null : trimmed;
  }
}

class _HeroHeader extends StatelessWidget {
  const _HeroHeader({required this.colorScheme});

  final ColorScheme colorScheme;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: <Widget>[
        Container(
          width: 88,
          height: 88,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            gradient: const LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: <Color>[Color(0xFF0ED1C6), Color(0xFFFFB84D)],
            ),
            boxShadow: <BoxShadow>[
              BoxShadow(
                color: const Color(0xFF0ED1C6).withValues(alpha: 0.3),
                blurRadius: 24,
                spreadRadius: 2,
              ),
            ],
          ),
          child: const Icon(Icons.chat_bubble_rounded, color: Colors.black, size: 40),
        ),
        const SizedBox(height: 18),
        Text(
          'Nirdist Messenger',
          textAlign: TextAlign.center,
          style: Theme.of(context).textTheme.headlineLarge,
        ),
        const SizedBox(height: 10),
        Text(
          'A secure, Android-first social messenger with Firebase OTP, accepted-friend chat gating, and live room sync.',
          textAlign: TextAlign.center,
          style: Theme.of(context).textTheme.bodyMedium,
        ),
        const SizedBox(height: 14),
        Wrap(
          alignment: WrapAlignment.center,
          spacing: 8,
          runSpacing: 8,
          children: <Widget>[
            _StatusChip(label: 'Secure storage', color: colorScheme.primary),
            _StatusChip(label: 'Firebase exchange', color: colorScheme.secondary),
            _StatusChip(label: 'Backend ready', color: colorScheme.tertiary),
          ],
        ),
      ],
    );
  }
}

class _LoginBackdrop extends StatelessWidget {
  const _LoginBackdrop();

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: <Color>[
            Color(0xFF071018),
            Color(0xFF08151F),
            Color(0xFF0A1218),
          ],
        ),
      ),
      child: Stack(
        children: <Widget>[
          Positioned(
            top: -80,
            left: -60,
            child: _GlowBlob(color: const Color(0xFF0ED1C6).withValues(alpha: 0.16), size: 200),
          ),
          Positioned(
            top: 80,
            right: -70,
            child: _GlowBlob(color: const Color(0xFFFFB84D).withValues(alpha: 0.12), size: 180),
          ),
          Positioned(
            bottom: -70,
            left: 30,
            child: _GlowBlob(color: const Color(0xFF95F0D1).withValues(alpha: 0.09), size: 180),
          ),
        ],
      ),
    );
  }
}

class _GlowBlob extends StatelessWidget {
  const _GlowBlob({required this.color, required this.size});

  final Color color;
  final double size;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: color,
      ),
    );
  }
}

class _StatusChip extends StatelessWidget {
  const _StatusChip({required this.label, required this.color});

  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Chip(
      side: BorderSide(color: color.withValues(alpha: 0.25)),
      backgroundColor: color.withValues(alpha: 0.12),
      label: Text(label),
    );
  }
}

class _LoginCard extends StatelessWidget {
  const _LoginCard({
    required this.formKey,
    required this.tokenController,
    required this.usernameController,
    required this.displayNameController,
    required this.emailController,
    required this.avatarUrlController,
    required this.onSubmit,
  });

  final GlobalKey<FormState> formKey;
  final TextEditingController tokenController;
  final TextEditingController usernameController;
  final TextEditingController displayNameController;
  final TextEditingController emailController;
  final TextEditingController avatarUrlController;
  final Future<void> Function() onSubmit;

  @override
  Widget build(BuildContext context) {
    final controller = context.watch<SessionController>();

    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFF0D1720).withValues(alpha: 0.96),
        borderRadius: BorderRadius.circular(28),
        border: Border.all(color: Colors.white.withValues(alpha: 0.09)),
        boxShadow: <BoxShadow>[
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.3),
            blurRadius: 40,
            offset: const Offset(0, 24),
          ),
        ],
      ),
      child: Form(
        key: formKey,
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: <Widget>[
              Text(
                'Exchange a Firebase ID token for the app JWT.',
                style: Theme.of(context).textTheme.titleMedium,
              ),
              const SizedBox(height: 6),
              Text(
                'This form is wired to the Spring Boot backend. Set NIRDIST_API_BASE_URL if your API runs somewhere else.',
                style: Theme.of(context).textTheme.bodySmall,
              ),
              const SizedBox(height: 18),
              TextFormField(
                controller: tokenController,
                minLines: 3,
                maxLines: 5,
                textInputAction: TextInputAction.next,
                decoration: const InputDecoration(
                  labelText: 'Firebase ID token',
                  hintText: 'Paste the token from the Firebase phone auth flow',
                ),
                validator: (value) {
                  if (value == null || value.trim().isEmpty) {
                    return 'A Firebase ID token is required.';
                  }
                  if (value.trim().length < 16) {
                    return 'That token looks too short.';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 14),
              Row(
                children: <Widget>[
                  Expanded(
                    child: TextFormField(
                      controller: usernameController,
                      textInputAction: TextInputAction.next,
                      decoration: const InputDecoration(
                        labelText: 'Username',
                        hintText: 'optional',
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: TextFormField(
                      controller: displayNameController,
                      textInputAction: TextInputAction.next,
                      decoration: const InputDecoration(
                        labelText: 'Display name',
                        hintText: 'optional',
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 14),
              Row(
                children: <Widget>[
                  Expanded(
                    child: TextFormField(
                      controller: emailController,
                      keyboardType: TextInputType.emailAddress,
                      textInputAction: TextInputAction.next,
                      decoration: const InputDecoration(
                        labelText: 'Email',
                        hintText: 'optional',
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: TextFormField(
                      controller: avatarUrlController,
                      textInputAction: TextInputAction.done,
                      decoration: const InputDecoration(
                        labelText: 'Avatar URL',
                        hintText: 'optional',
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 20),
              if (controller.errorMessage != null) ...<Widget>[
                Text(
                  controller.errorMessage!,
                  style: TextStyle(color: Theme.of(context).colorScheme.error),
                ),
                const SizedBox(height: 12),
              ],
              FilledButton(
                onPressed: controller.isSubmitting ? null : onSubmit,
                child: controller.isSubmitting
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Text('Connect account'),
              ),
              const SizedBox(height: 10),
              Text(
                'Backend: ${controller.apiBaseUrl}',
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.bodySmall,
              ),
            ],
          ),
        ),
      ),
    );
  }
}