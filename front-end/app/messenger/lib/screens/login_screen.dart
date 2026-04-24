import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../state/session_controller.dart';
import '../widgets/app_logo.dart';

enum _AuthMode { login, signup }

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final GlobalKey<FormState> _loginFormKey = GlobalKey<FormState>();
  final GlobalKey<FormState> _signupFormKey = GlobalKey<FormState>();

  final TextEditingController _loginPhoneController = TextEditingController();
  final TextEditingController _signupPhoneController = TextEditingController();
  final TextEditingController _usernameController = TextEditingController();
  final TextEditingController _displayNameController = TextEditingController();
  final TextEditingController _emailController = TextEditingController();

  _AuthMode _authMode = _AuthMode.login;
  bool _isSubmitting = false;
  String? _statusMessage;
  String? _localErrorMessage;

  @override
  void dispose() {
    _loginPhoneController.dispose();
    _signupPhoneController.dispose();
    _usernameController.dispose();
    _displayNameController.dispose();
    _emailController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isWide = MediaQuery.sizeOf(context).width >= 980;
    final authCard = _AuthCard(
      authMode: _authMode,
      loginFormKey: _loginFormKey,
      signupFormKey: _signupFormKey,
      loginPhoneController: _loginPhoneController,
      signupPhoneController: _signupPhoneController,
      usernameController: _usernameController,
      displayNameController: _displayNameController,
      emailController: _emailController,
      isSubmitting: _isSubmitting,
      statusMessage: _statusMessage,
      localErrorMessage: _localErrorMessage,
      onModeChanged: _handleModeChanged,
      onSubmit: _submit,
      validatePhoneNumber: _validatePhoneNumber,
      validateUsername: _validateUsername,
      validateDisplayName: _validateDisplayName,
      validateEmail: _validateEmail,
    );

    final content = isWide
        ? Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              const Expanded(
                child: Padding(
                  padding: EdgeInsets.only(right: 18),
                  child: _HeroPanel(),
                ),
              ),
              Expanded(child: authCard),
            ],
          )
        : Column(
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              const _HeroPanel(),
              const SizedBox(height: 18),
              authCard,
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
                  child: content,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _handleModeChanged(_AuthMode mode) {
    if (_authMode == mode) {
      return;
    }

    context.read<SessionController>().clearError();
    setState(() {
      _authMode = mode;
      _localErrorMessage = null;
      _statusMessage = null;
    });
  }

  Future<void> _submit() async {
    final activeForm = _authMode == _AuthMode.login ? _loginFormKey : _signupFormKey;
    if (!(activeForm.currentState?.validate() ?? false)) {
      return;
    }

    final sessionController = context.read<SessionController>();
    sessionController.clearError();
    FocusScope.of(context).unfocus();

    setState(() {
      _isSubmitting = true;
      _localErrorMessage = null;
      _statusMessage = _authMode == _AuthMode.login
          ? 'Checking your phone number and opening your account...'
          : 'Creating your profile and connecting to the messenger backend...';
    });

    final success = _authMode == _AuthMode.login
        ? await sessionController.signIn(
            phoneNumber: _normalizedPhoneNumber(_loginPhoneController.text),
          )
        : await sessionController.signUp(
            phoneNumber: _normalizedPhoneNumber(_signupPhoneController.text),
            username: _usernameController.text.trim(),
            displayName: _displayNameController.text.trim(),
            email: _trimmedOrNull(_emailController.text),
          );

    if (!mounted) {
      return;
    }

    setState(() {
      _isSubmitting = false;
    });

    if (success) {
      return;
    }

    setState(() {
      _localErrorMessage = sessionController.errorMessage ?? 'Unable to continue right now.';
      _statusMessage = null;
    });
  }

  String? _trimmedOrNull(String value) {
    final trimmed = value.trim();
    return trimmed.isEmpty ? null : trimmed;
  }

  String _normalizedPhoneNumber(String value) {
    return value.trim().replaceAll(RegExp(r'[\s().-]'), '');
  }

  String? _validatePhoneNumber(String? value) {
    final trimmed = value?.trim() ?? '';
    if (trimmed.isEmpty) {
      return 'Phone number is required.';
    }

    final normalized = _normalizedPhoneNumber(trimmed);
    if (!RegExp(r'^\+?[0-9]{8,15}$').hasMatch(normalized)) {
      return 'Use an international phone number like +15550000000.';
    }

    return null;
  }

  String? _validateUsername(String? value) {
    final trimmed = value?.trim() ?? '';
    if (trimmed.isEmpty) {
      return 'Username is required for signup.';
    }

    if (!RegExp(r'^[a-zA-Z0-9._-]{3,24}$').hasMatch(trimmed)) {
      return 'Use 3-24 letters, numbers, dots, dashes, or underscores.';
    }

    return null;
  }

  String? _validateDisplayName(String? value) {
    final trimmed = value?.trim() ?? '';
    if (trimmed.isEmpty) {
      return 'Display name is required for signup.';
    }

    if (trimmed.length < 2) {
      return 'Display name must be at least 2 characters.';
    }

    return null;
  }

  String? _validateEmail(String? value) {
    final trimmed = value?.trim() ?? '';
    if (trimmed.isEmpty) {
      return null;
    }

    if (!RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$').hasMatch(trimmed)) {
      return 'Enter a valid email address or leave it empty.';
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
          Text('Communication starts here', style: Theme.of(context).textTheme.headlineLarge),
          const SizedBox(height: 8),
          Text(
            'Log in with your phone number or create a new account. The app talks directly to your Spring Boot backend and stores the returned JWT securely for the messenger experience.',
            style: Theme.of(context).textTheme.bodyLarge,
          ),
          const SizedBox(height: 18),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: const <Widget>[
              _StatusChip(label: 'Phone auth', color: Color(0xFFE4572E)),
              _StatusChip(label: 'JWT session', color: Color(0xFFFF9F1C)),
              _StatusChip(label: 'Backend connected', color: Color(0xFF38B6FF)),
            ],
          ),
          const SizedBox(height: 20),
          const _FeatureLine(
            icon: Icons.person_add_alt_1_rounded,
            title: 'Signup sends username, display name, and optional email',
          ),
          const SizedBox(height: 10),
          const _FeatureLine(
            icon: Icons.login_rounded,
            title: 'Login keeps the flow fast with just the phone number',
          ),
          const SizedBox(height: 10),
          const _FeatureLine(
            icon: Icons.security_rounded,
            title: 'Session token is saved locally and reused on next launch',
          ),
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

class _AuthCard extends StatelessWidget {
  const _AuthCard({
    required this.authMode,
    required this.loginFormKey,
    required this.signupFormKey,
    required this.loginPhoneController,
    required this.signupPhoneController,
    required this.usernameController,
    required this.displayNameController,
    required this.emailController,
    required this.isSubmitting,
    required this.statusMessage,
    required this.localErrorMessage,
    required this.onModeChanged,
    required this.onSubmit,
    required this.validatePhoneNumber,
    required this.validateUsername,
    required this.validateDisplayName,
    required this.validateEmail,
  });

  final _AuthMode authMode;
  final GlobalKey<FormState> loginFormKey;
  final GlobalKey<FormState> signupFormKey;
  final TextEditingController loginPhoneController;
  final TextEditingController signupPhoneController;
  final TextEditingController usernameController;
  final TextEditingController displayNameController;
  final TextEditingController emailController;
  final bool isSubmitting;
  final String? statusMessage;
  final String? localErrorMessage;
  final ValueChanged<_AuthMode> onModeChanged;
  final Future<void> Function() onSubmit;
  final String? Function(String?) validatePhoneNumber;
  final String? Function(String?) validateUsername;
  final String? Function(String?) validateDisplayName;
  final String? Function(String?) validateEmail;

  @override
  Widget build(BuildContext context) {
    final controller = context.watch<SessionController>();
    final isBusy = isSubmitting || controller.isSubmitting;

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
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: <Widget>[
            Text(
              'Account access',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 6),
            Text(
              'New phone numbers are created automatically by the backend. Existing numbers open the same account and return your messenger JWT.',
              style: Theme.of(context).textTheme.bodySmall,
            ),
            const SizedBox(height: 18),
            SegmentedButton<_AuthMode>(
              segments: const <ButtonSegment<_AuthMode>>[
                ButtonSegment<_AuthMode>(
                  value: _AuthMode.login,
                  icon: Icon(Icons.login_rounded),
                  label: Text('Login'),
                ),
                ButtonSegment<_AuthMode>(
                  value: _AuthMode.signup,
                  icon: Icon(Icons.person_add_alt_1_rounded),
                  label: Text('Signup'),
                ),
              ],
              selected: <_AuthMode>{authMode},
              onSelectionChanged: (selection) => onModeChanged(selection.first),
            ),
            const SizedBox(height: 18),
            AnimatedSwitcher(
              duration: const Duration(milliseconds: 220),
              switchInCurve: Curves.easeOutCubic,
              switchOutCurve: Curves.easeInCubic,
              child: authMode == _AuthMode.login
                  ? _LoginForm(
                      key: const ValueKey<String>('login-form'),
                      formKey: loginFormKey,
                      phoneController: loginPhoneController,
                      validatePhoneNumber: validatePhoneNumber,
                    )
                  : _SignupForm(
                      key: const ValueKey<String>('signup-form'),
                      formKey: signupFormKey,
                      phoneController: signupPhoneController,
                      usernameController: usernameController,
                      displayNameController: displayNameController,
                      emailController: emailController,
                      validatePhoneNumber: validatePhoneNumber,
                      validateUsername: validateUsername,
                      validateDisplayName: validateDisplayName,
                      validateEmail: validateEmail,
                    ),
            ),
            const SizedBox(height: 18),
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
              onPressed: isBusy ? null : onSubmit,
              child: isBusy
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : Text(authMode == _AuthMode.login ? 'Login' : 'Create account'),
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
    );
  }
}

class _LoginForm extends StatelessWidget {
  const _LoginForm({
    super.key,
    required this.formKey,
    required this.phoneController,
    required this.validatePhoneNumber,
  });

  final GlobalKey<FormState> formKey;
  final TextEditingController phoneController;
  final String? Function(String?) validatePhoneNumber;

  @override
  Widget build(BuildContext context) {
    return Form(
      key: formKey,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          TextFormField(
            controller: phoneController,
            textInputAction: TextInputAction.done,
            keyboardType: TextInputType.phone,
            autofillHints: const <String>[AutofillHints.telephoneNumber],
            decoration: const InputDecoration(
              labelText: 'Phone number',
              hintText: '+15550000000',
            ),
            validator: validatePhoneNumber,
          ),
          const SizedBox(height: 12),
          Text(
            'Use the phone number already tied to your messenger profile. If the backend has never seen it before, it will create a new account.',
            style: Theme.of(context).textTheme.bodySmall,
          ),
        ],
      ),
    );
  }
}

class _SignupForm extends StatelessWidget {
  const _SignupForm({
    super.key,
    required this.formKey,
    required this.phoneController,
    required this.usernameController,
    required this.displayNameController,
    required this.emailController,
    required this.validatePhoneNumber,
    required this.validateUsername,
    required this.validateDisplayName,
    required this.validateEmail,
  });

  final GlobalKey<FormState> formKey;
  final TextEditingController phoneController;
  final TextEditingController usernameController;
  final TextEditingController displayNameController;
  final TextEditingController emailController;
  final String? Function(String?) validatePhoneNumber;
  final String? Function(String?) validateUsername;
  final String? Function(String?) validateDisplayName;
  final String? Function(String?) validateEmail;

  @override
  Widget build(BuildContext context) {
    return Form(
      key: formKey,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
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
          TextFormField(
            controller: usernameController,
            textInputAction: TextInputAction.next,
            decoration: const InputDecoration(
              labelText: 'Username',
              hintText: 'abhi.chat',
            ),
            validator: validateUsername,
          ),
          const SizedBox(height: 14),
          TextFormField(
            controller: displayNameController,
            textInputAction: TextInputAction.next,
            decoration: const InputDecoration(
              labelText: 'Display name',
              hintText: 'Abhishek',
            ),
            validator: validateDisplayName,
          ),
          const SizedBox(height: 14),
          TextFormField(
            controller: emailController,
            textInputAction: TextInputAction.done,
            keyboardType: TextInputType.emailAddress,
            autofillHints: const <String>[AutofillHints.email],
            decoration: const InputDecoration(
              labelText: 'Email (optional)',
              hintText: 'name@example.com',
            ),
            validator: validateEmail,
          ),
          const SizedBox(height: 12),
          Text(
            'These details are sent to the backend when it creates your communication profile. If the phone number already exists, the backend will log you into that account instead.',
            style: Theme.of(context).textTheme.bodySmall,
          ),
        ],
      ),
    );
  }
}
