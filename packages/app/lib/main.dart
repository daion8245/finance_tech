import 'package:core_api/core_api.dart';
import 'package:core_family/core_family.dart';
import 'package:core_shell/core_shell.dart';
import 'package:core_ui/core_ui.dart';
import 'package:flutter/material.dart';

import 'app.dart';
import 'shell/feedback_service.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  registerFontLicenses();
  final config = ApiConfig.fromEnvironment();
  final repository = ApiFamilyRepository(FingerBellApi(config));
  final family = FamilyCubit(repository)..start();
  runApp(
    FingerBellApp(
      family: family,
      shell: ShellCubit(),
      feedback: DeviceFeedback(),
      serverAddress: config.toString(),
    ),
  );
}
