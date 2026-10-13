import 'package:flutter/material.dart';

import '../screens/dashboard_screen.dart';
import '../screens/home_screen.dart';
import '../screens/monitoring_screen.dart';
import '../screens/summary_screen.dart';

class AppRoutes {
  static const home = '/';
  static const monitoring = '/monitoring';
  static const dashboard = '/dashboard';
  static const summary = '/summary';

  static Route<dynamic> onGenerateRoute(RouteSettings settings) {
    return MaterialPageRoute(
      settings: settings,
      builder: (_) {
        switch (settings.name) {
          case monitoring:
            final args = settings.arguments;
            final routeArgs = args is Map ? args : null;
            return MonitoringScreen(
              initialClassName: routeArgs?['className'] as String?,
              initialClassTime: routeArgs?['classTime'] as String?,
            );
          case dashboard:
            final args = settings.arguments;
            final routeArgs = args is Map ? args : null;
            final fromMonitoring = routeArgs?['fromMonitoring'] == true ||
                routeArgs?['fromMonitoring'] == 'true';
            return DashboardScreen(fromMonitoring: fromMonitoring);
          case summary:
            return const SummaryScreen();
          case home:
          default:
            return const HomeScreen();
        }
      },
    );
  }
}
