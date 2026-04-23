import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../state/session_controller.dart';
import '../widgets/app_logo.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final GlobalKey<FormState> _formKey = GlobalKey<FormState>();
  final TextEditingController _phoneController = TextEditingController();
  final TextEditingController _usernameController = TextEditingController();
  final TextEditingController _displayNameController = TextEditingController();

  bool _isSigningIn = false;
  String? _statusMessage;
  String? _localErrorMessage;

  @override
  void dispose() {
    _phoneController.dispose();
    _usernameController.dispose();
    _displayNameController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isWide = MediaQuery.sizeOf(context).width >= 980;
    final loginContent = isWide
        ? Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.only(right: 18),
                  child: const _HeroPanel(),
                ),
              ),
              Expanded(
                child: _LoginCard(
                  formKey: _formKey,
                  phoneController: _phoneController,
                  usernameController: _usernameController,
                  displayNameController: _displayNameController,
                  isSigningIn: _isSigningIn,
                  statusMessage: _statusMessage,
                  localErrorMessage: _localErrorMessage,
                  onSignIn: _signIn,
                  validatePhoneNumber: _validatePhoneNumber,
                ),
              ),
            ],
          )
        : Column(
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              const _HeroPanel(),
              const SizedBox(height: 18),
              _LoginCard(
                formKey: _formKey,
                phoneController: _phoneController,
                usernameController: _usernameController,
                displayNameController: _displayNameController,
                isSigningIn: _isSigningIn,
                statusMessage: _statusMessage,
                localErrorMessage: _localErrorMessage,
                onSignIn: _signIn,
                validatePhoneNumber: _validatePhoneNumber,
              ),
            ],
          );

    return Scaffold(
      body: Stack(
        children: <Widget>[
          const _LoginBackdrop(),
          SafeArea(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(22),
              child: Center(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 1120),
                  child: loginContent,
                  ),
                ),
              ),
          ),
        ],
      ),
    );
  }

  Future<void> _signIn() async {
    if (!(_formKey.currentState?.validate() ?? false)) {
      return;
    }

    final phoneNumber = _normalizedPhoneNumber();
    final sessionController = context.read<SessionController>();
    sessionController.clearError();
    FocusScope.of(context).unfocus();

    setState(() {
      _isSigningIn = true;
      _localErrorMessage = null;
      _statusMessage = 'Signing you in with $phoneNumber...';
    });

    final success = await sessionController.signIn(
      phoneNumber: phoneNumber,
      username: _trimmedOrNull(_usernameController.text),
      displayName: _trimmedOrNull(_displayNameController.text),
    );

    if (!mounted) {
      return;
    }

    setState(() {
      _isSigningIn = false;
    });

    if (success) {
      return;
    }

    setState(() {
      _localErrorMessage = sessionController.errorMessage ?? 'Unable to sign in.';
      _statusMessage = null;
    });
  }

  String? _trimmedOrNull(String value) {
    final trimmed = value.trim();
    return trimmed.isEmpty ? null : trimmed;
  }

  String _normalizedPhoneNumber() {
    return _phoneController.text.trim().replaceAll(RegExp(r'[\s().-]'), '');
  }

  String? _validatePhoneNumber(String? value) {
    final trimmed = value?.trim() ?? '';
    if (trimmed.isEmpty) {
      return 'Phone number is required.';
    }

    final normalized = trimmed.replaceAll(RegExp(r'[\s().-]'), '');
    if (!RegExp(r'^\+?[0-9]{8,15}$').hasMatch(normalized)) {
      return 'Use an international phone number like +15550000000.';
    }

    return null;
  }

}

class _HeroPanel extends StatelessWidget {
  const _HeroPanel();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(30),
        color: const Color(0xFF121A24).withValues(alpha: 0.82),
        border: Border.all(color: Colors.white.withValues(alpha: 0.1)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          const AppLogo(size: 88, padding: 18),
          const SizedBox(height: 18),
          Text('Login with your phone', style: Theme.of(context).textTheme.headlineLarge),
          const SizedBox(height: 8),
          Text(
            'Verification is paused for now. Use your phone number to continue and the backend will create or load your account before issuing the JWT.',
            style: Theme.of(context).textTheme.bodyLarge,
          ),
          const SizedBox(height: 18),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: <Widget>[
              _StatusChip(label: 'No SMS', color: const Color(0xFFE4572E)),
              _StatusChip(label: 'JWT backend', color: const Color(0xFFFF9F1C)),
              _StatusChip(label: 'Temporary flow', color: const Color(0xFF38B6FF)),
            ],
          ),
          const SizedBox(height: 20),
          const _FeatureLine(icon: Icons.lock_clock_outlined, title: 'Secure session storage'),
          const SizedBox(height: 10),
          const _FeatureLine(icon: Icons.sms_failed_outlined, title: 'No verification step'),
          const SizedBox(height: 10),
          const _FeatureLine(icon: Icons.hub_outlined, title: 'Spring Boot creates or loads the account'),
        ],
      ),
    );
  }
}

class _FeatureLine extends StatelessWidget {
  const _FeatureLine({required this.icon, required this.title});

  final IconData icon;
  final String title;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: <Widget>[
        Icon(icon, size: 20, color: const Color(0xFFFF9F1C)),
        const SizedBox(width: 10),
        Expanded(child: Text(title, style: Theme.of(context).textTheme.bodyMedium)),
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
            Color(0xFF0B0F14),
            Color(0xFF131A22),
            Color(0xFF0E141B),
          ],
        ),
      ),
      child: Stack(
        children: <Widget>[
          Positioned(
            top: -80,
            left: -60,
            child: _GlowBlob(color: const Color(0xFFE4572E).withValues(alpha: 0.2), size: 240),
          ),
          Positioned(
            top: 80,
            right: -70,
            child: _GlowBlob(color: const Color(0xFFFF9F1C).withValues(alpha: 0.16), size: 220),
          ),
          Positioned(
            bottom: -70,
            left: 30,
            child: _GlowBlob(color: const Color(0xFF38B6FF).withValues(alpha: 0.1), size: 200),
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
    required this.phoneController,
    required this.usernameController,
    required this.displayNameController,
    required this.isSigningIn,
    required this.statusMessage,
    required this.localErrorMessage,
    required this.onSignIn,
    required this.validatePhoneNumber,
  });

  final GlobalKey<FormState> formKey;
  final TextEditingController phoneController;
  final TextEditingController usernameController;
  final TextEditingController displayNameController;
  final bool isSigningIn;
  final String? statusMessage;
  final String? localErrorMessage;
  final Future<void> Function() onSignIn;
  final String? Function(String?) validatePhoneNumber;

  @override
  Widget build(BuildContext context) {
    final controller = context.watch<SessionController>();
    final isBusy = isSigningIn || controller.isSubmitting;

    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFF141B25).withValues(alpha: 0.94),
        borderRadius: BorderRadius.circular(28),
        border: Border.all(color: Colors.white.withValues(alpha: 0.11)),
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
                'Use your phone number',
                style: Theme.of(context).textTheme.titleMedium,
              ),
              const SizedBox(height: 6),
              Text(
                'Verification is off for now. Enter your phone number and the backend will create or load your account directly.',
                style: Theme.of(context).textTheme.bodySmall,
              ),
              const SizedBox(height: 18),
              TextFormField(
                controller: phoneController,
                textInputAction: TextInputAction.next,
                keyboardType: TextInputType.phone,
                autofillHints: const <String>[AutofillHints.telephoneNumber],
                decoration: const InputDecoration(
                  labelText: 'Phone number',
                  hintText: '+15550000000',
                ),
                validator: validatePhoneNumber,
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
                        hintText: 'optional for signup',
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: TextFormField(
                      controller: displayNameController,
                      textInputAction: TextInputAction.done,
                      decoration: const InputDecoration(
                        labelText: 'Display name',
                        hintText: 'optional for signup',
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 14),
              Text(
                'Optional profile details are used only if the backend creates a new account.',
                style: Theme.of(context).textTheme.bodySmall,
              ),
              const SizedBox(height: 20),
              if (statusMessage != null) ...<Widget>[
                Text(
                  statusMessage!,
                  style: Theme.of(context).textTheme.bodySmall,
                ),
                const SizedBox(height: 12),
              ],
              if (localErrorMessage != null) ...<Widget>[
                Text(
                  localErrorMessage!,
                  style: TextStyle(color: Theme.of(context).colorScheme.error),
                ),
                const SizedBox(height: 12),
              ],
              if (controller.errorMessage != null) ...<Widget>[
                Text(
                  controller.errorMessage!,
                  style: TextStyle(color: Theme.of(context).colorScheme.error),
                ),
                const SizedBox(height: 12),
              ],
              if (isBusy) ...<Widget>[
                const LinearProgressIndicator(minHeight: 2),
                const SizedBox(height: 12),
              ],
              FilledButton(
                onPressed: isBusy ? null : onSignIn,
                child: isBusy
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Text('Login'),
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