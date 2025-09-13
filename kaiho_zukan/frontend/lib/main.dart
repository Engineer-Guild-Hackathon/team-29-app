import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:flutter/foundation.dart' show kReleaseMode;
import 'screens/login_register.dart';
import 'package:google_fonts/google_fonts.dart';
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
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.teal),
        textTheme: GoogleFonts.notoSansJpTextTheme(),
      ),
      home: const LoginRegisterScreen(),
    );
  }
}
