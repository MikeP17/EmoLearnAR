import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'core/app_theme.dart';
import 'routes/app_routes.dart';
import 'services/monitoring_provider.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const EmoLearnARApp());
}

class EmoLearnARApp extends StatelessWidget {
  const EmoLearnARApp({super.key});

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider(
      create: (_) => MonitoringProvider()..loadHistory(),
      child: MaterialApp(
        debugShowCheckedModeBanner: false,
        title: 'EmoLearnAR',
        theme: AppTheme.light,
        initialRoute: AppRoutes.home,
        onGenerateRoute: AppRoutes.onGenerateRoute,
      ),
    );
  }
}
