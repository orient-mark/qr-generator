import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';

import 'app_info.dart';
import 'localization/app_strings.dart';
import 'presentation/app_theme.dart';
import 'presentation/generator_page.dart';

export 'presentation/generator_page.dart' show GeneratorPage;

void main() => runApp(const OrientMarkQrApp());

class OrientMarkQrApp extends StatefulWidget {
  const OrientMarkQrApp({super.key});
  @override
  State<OrientMarkQrApp> createState() => _OrientMarkQrAppState();
}

class _OrientMarkQrAppState extends State<OrientMarkQrApp> {
  late final Future<TranslationCatalog> _catalog = TranslationCatalog.load();
  String _language = 'ru';

  @override
  Widget build(BuildContext context) => FutureBuilder<TranslationCatalog>(
    future: _catalog,
    builder: (context, snapshot) {
      final catalog = snapshot.data;
      if (catalog == null) {
        return MaterialApp(
          debugShowCheckedModeBanner: false,
          home: Scaffold(
            body: Center(
              child: snapshot.hasError
                  ? const Text(
                      'Cannot load translations / Не удалось загрузить переводы',
                    )
                  : const CircularProgressIndicator(),
            ),
          ),
        );
      }
      final language = catalog.languages.firstWhere((l) => l.code == _language);
      Locale localeFor(AppLanguage language) {
        final parts = language.code.split('_');
        return Locale(parts.first, parts.length > 1 ? parts.last : null);
      }

      return MaterialApp(
        title: appName,
        debugShowCheckedModeBanner: false,
        locale: localeFor(language),
        supportedLocales: catalog.languages.map(localeFor).toList(),
        localizationsDelegates: GlobalMaterialLocalizations.delegates,
        theme: createTheme(),
        builder: (context, child) => AppStrings(
          language: language,
          catalog: catalog,
          changeLanguage: (code) => setState(() => _language = code),
          child: child!,
        ),
        home: const GeneratorPage(),
      );
    },
  );
}
