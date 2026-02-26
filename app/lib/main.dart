import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'src/screens/menu_screen.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);
  await SystemChrome.setPreferredOrientations([
    DeviceOrientation.landscapeLeft,
    DeviceOrientation.landscapeRight,
  ]);

  runApp(const InfectionZoneApp());
}

class InfectionZoneApp extends StatelessWidget {
  const InfectionZoneApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'Infection Zone',
      theme: ThemeData(
        brightness: Brightness.dark,
        scaffoldBackgroundColor: const Color(0xFF0A0E14),
        colorScheme: const ColorScheme.dark(
          primary: Color(0xFFE23A3A),
          secondary: Color(0xFFFFB000),
          surface: Color(0xFF121C28),
        ),
      ),
      home: const MenuScreen(),
    );
  }
}
