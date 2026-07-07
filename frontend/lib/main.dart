import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:provider/provider.dart';
import 'providers/auth_provider.dart';
import 'providers/game_provider.dart';
import 'providers/locale_provider.dart';
import 'providers/room_provider.dart';
import 'screens/auth/login_screen.dart';
import 'screens/lobby/lobby_screen.dart';
import 'theme/app_theme.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  // Portrait locked globally; GameScreen unlocks rotation in its own initState.
  await SystemChrome.setPreferredOrientations([DeviceOrientation.portraitUp]);
  final initialLocale = await LocaleProvider.loadSavedLocale();
  runApp(MeryasApp(initialLocale: initialLocale));
}

class MeryasApp extends StatelessWidget {
  const MeryasApp({super.key, this.initialLocale = const Locale('fr')});

  final Locale initialLocale;

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider(
          create: (_) => LocaleProvider(initialLocale: initialLocale),
        ),
        ChangeNotifierProvider(create: (_) => AuthProvider()),
        ChangeNotifierProvider(create: (_) => RoomProvider()),
        ChangeNotifierProvider(create: (_) => GameProvider()),
      ],
      child: Consumer<LocaleProvider>(
        builder: (context, localeProv, child) => MaterialApp(
          title: 'Meryas',
          theme: AppTheme.dark,
          debugShowCheckedModeBanner: false,
          locale: localeProv.locale,
          supportedLocales: const [Locale('fr'), Locale('ar')],
          localizationsDelegates: const [
            GlobalMaterialLocalizations.delegate,
            GlobalWidgetsLocalizations.delegate,
            GlobalCupertinoLocalizations.delegate,
          ],
          home: const _Root(),
        ),
      ),
    );
  }
}

class _Root extends StatefulWidget {
  const _Root();

  @override
  State<_Root> createState() => _RootState();
}

class _RootState extends State<_Root> {
  bool _initialized = false;

  @override
  void initState() {
    super.initState();
    _init();
  }

  Future<void> _init() async {
    await context.read<AuthProvider>().tryAutoLogin();
    setState(() => _initialized = true);
  }

  @override
  Widget build(BuildContext context) {
    if (!_initialized) {
      return const Scaffold(
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.style, size: 64, color: AppTheme.gold),
              SizedBox(height: 16),
              CircularProgressIndicator(color: AppTheme.gold),
            ],
          ),
        ),
      );
    }

    final auth = context.watch<AuthProvider>();
    if (auth.isAuthenticated) {
      return const LobbyScreen();
    }
    return const LoginScreen();
  }
}
