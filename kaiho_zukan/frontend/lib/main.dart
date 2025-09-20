import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:flutter/foundation.dart' show kReleaseMode;
import 'screens/login_register.dart';
import 'package:google_fonts/google_fonts.dart';
import 'constants/app_colors.dart';
Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  try {
    // In release builds, prefer production env file; in dev, use .env
    if (kReleaseMode) {
      await dotenv.load(fileName: '.env.production');
    } else {
      await dotenv.load(fileName: '.env');
    }
  } catch (_) {}
  runApp(const MyApp());
}
class MyApp extends StatelessWidget {
  const MyApp({super.key});
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: '解法図鑑',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        useMaterial3: true,
        colorScheme: ColorScheme.fromSeed(
          seedColor: AppColors.primary,
          brightness: Brightness.light,
        ).copyWith(
          primary: AppColors.primary,
          secondary: AppColors.secondary,
          surface: AppColors.surface,
          background: AppColors.background,
          error: AppColors.danger,
          onPrimary: AppColors.background,
          onSecondary: AppColors.background,
          onSurface: Colors.black,
          onBackground: Colors.black,
          onError: AppColors.background,
        ),
        scaffoldBackgroundColor: AppColors.background,
        canvasColor: AppColors.primary_light,
        textTheme: GoogleFonts.notoSansJpTextTheme().apply(
          bodyColor: Colors.black,
          displayColor: Colors.black,
        ),
        appBarTheme: const AppBarTheme(
          backgroundColor: AppColors.primary,
          foregroundColor: AppColors.background,
        ),
        dividerColor: AppColors.border,
        dropdownMenuTheme: DropdownMenuThemeData(
          menuStyle: MenuStyle(
            backgroundColor: MaterialStatePropertyAll(AppColors.primary_light),
          ),
        ),
      ),
      home: const LoginRegisterScreen(),
    );
  }
}
