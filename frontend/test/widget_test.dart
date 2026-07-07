import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:meryas/main.dart';
import 'package:meryas/providers/auth_provider.dart';
import 'package:meryas/providers/locale_provider.dart';
import 'package:meryas/screens/auth/login_screen.dart';
import 'package:provider/provider.dart';

void main() {
  testWidgets('App starts without crashing', (WidgetTester tester) async {
    await tester.pumpWidget(const MeryasApp());
    expect(find.byType(MeryasApp), findsOneWidget);
  });

  testWidgets('Language button switches from French to Arabic', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(
      MultiProvider(
        providers: [
          ChangeNotifierProvider(create: (_) => LocaleProvider()),
          ChangeNotifierProvider(create: (_) => AuthProvider()),
        ],
        child: Consumer<LocaleProvider>(
          builder: (context, localeProvider, _) => MaterialApp(
            locale: localeProvider.locale,
            supportedLocales: const [Locale('fr'), Locale('ar')],
            localizationsDelegates: const [
              GlobalMaterialLocalizations.delegate,
              GlobalWidgetsLocalizations.delegate,
              GlobalCupertinoLocalizations.delegate,
            ],
            home: const LoginScreen(),
          ),
        ),
      ),
    );

    expect(find.text('Connexion'), findsOneWidget);
    await tester.tap(find.text('AR'));
    await tester.pumpAndSettle();

    expect(find.text('تسجيل الدخول'), findsOneWidget);
    expect(
      Directionality.of(tester.element(find.text('تسجيل الدخول'))),
      TextDirection.rtl,
    );
  });
}
