import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'data/app_database.dart';
import 'screens/home_shell.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final db = AppDatabase();
  await db.init();
  runApp(ShifaPharmacyApp(db: db));
}

class ShifaPharmacyApp extends StatelessWidget {
  final AppDatabase db;
  const ShifaPharmacyApp({super.key, required this.db});

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: db,
      builder: (context, _) {
        return MaterialApp(
          title: 'نظام شفاء لإدارة الصيدليات',
          debugShowCheckedModeBanner: false,
          locale: const Locale('ar', 'SA'),
          supportedLocales: const [Locale('ar', 'SA')],
          localizationsDelegates: const [
            GlobalMaterialLocalizations.delegate,
            GlobalWidgetsLocalizations.delegate,
            GlobalCupertinoLocalizations.delegate,
          ],
          theme: ThemeData(
            useMaterial3: true,
            colorScheme: ColorScheme.fromSeed(seedColor: const Color(0xFF0F766E)),
            scaffoldBackgroundColor: const Color(0xFFF1F5F9),
          ),
          home: HomeShell(db: db),
        );
      },
    );
  }
}