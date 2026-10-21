import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

class AppLanguage {
  const AppLanguage(this.code, this.name, this.values);
  final String code;
  final String name;
  final Map<String, String> values;
}

class TranslationCatalog {
  const TranslationCatalog(this.languages);
  final List<AppLanguage> languages;

  static Future<TranslationCatalog> load() async {
    final manifest = jsonDecode(
      await rootBundle.loadString('assets/l10n/languages.json'),
    ) as List;
    final languages = <AppLanguage>[];
    for (final entry in manifest.cast<Map<String, dynamic>>()) {
      final code = entry['code'] as String;
      if (!RegExp(r'^[a-z]{2,3}(?:_[A-Z]{2})?$').hasMatch(code)) {
        throw FormatException('Invalid language code: $code');
      }
      final values = (jsonDecode(
        await rootBundle.loadString('assets/l10n/$code.json'),
      ) as Map<String, dynamic>).cast<String, String>();
      languages.add(
        AppLanguage(code, entry['name'] as String, Map.unmodifiable(values)),
      );
    }
    if (languages.map((l) => l.code).toSet().length != languages.length ||
        !languages.any((l) => l.code == 'en') ||
        !languages.any((l) => l.code == 'ru')) {
      throw const FormatException(
        'The catalog needs unique languages including en and ru',
      );
    }
    final english = languages.singleWhere((l) => l.code == 'en').values;
    Set<String> parameters(String value) =>
        RegExp(r'\{([a-zA-Z]+)\}').allMatches(value).map((m) => m[1]!).toSet();
    for (final language in languages) {
      if (language.values.keys
              .toSet()
              .difference(english.keys.toSet())
              .isNotEmpty ||
          english.keys
              .toSet()
              .difference(language.values.keys.toSet())
              .isNotEmpty) {
        throw FormatException('Translation keys differ for ${language.code}');
      }
      for (final key in english.keys) {
        final expected = parameters(english[key]!);
        final actual = parameters(language.values[key]!);
        if (expected.difference(actual).isNotEmpty ||
            actual.difference(expected).isNotEmpty) {
          throw FormatException(
            'Translation parameters differ for ${language.code}: $key',
          );
        }
      }
    }
    return TranslationCatalog(List.unmodifiable(languages));
  }
}

class AppStrings extends InheritedWidget {
  const AppStrings({
    super.key,
    required this.language,
    required this.catalog,
    required this.changeLanguage,
    required super.child,
  });

  final AppLanguage language;
  final TranslationCatalog catalog;
  final ValueChanged<String> changeLanguage;

  static AppStrings of(BuildContext context) =>
      context.dependOnInheritedWidgetOfExactType<AppStrings>()!;

  String text(String key, [Map<String, Object> values = const {}]) {
    var value = language.values[key] ?? key;
    for (final entry in values.entries) {
      value = value.replaceAll('{${entry.key}}', entry.value.toString());
    }
    return value;
  }

  @override
  bool updateShouldNotify(AppStrings oldWidget) =>
      language.code != oldWidget.language.code;
}
