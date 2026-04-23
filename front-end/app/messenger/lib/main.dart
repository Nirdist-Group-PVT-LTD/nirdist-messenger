import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'app/nirdist_app.dart';
import 'services/auth_api_client.dart';
import 'services/secure_session_store.dart';
import 'state/session_controller.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  final sessionController = SessionController(
    authApiClient: AuthApiClient(),
    secureSessionStore: SecureSessionStore(),
  );
  await sessionController.bootstrap();

  runApp(
    ChangeNotifierProvider.value(
      value: sessionController,
      child: const NirdistApp(),
    ),
  );
}
