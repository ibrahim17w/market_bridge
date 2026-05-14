import 'package:flutter/material.dart';
import '../providers/locale_provider.dart';
import '../lang/translations.dart';

class LanguageIconButton extends StatelessWidget {
  const LanguageIconButton({super.key});

  final List<Map<String, String>> languages = const [
    {'code': 'en', 'native': 'English'},
    {'code': 'ar', 'native': 'العربية'},
    {'code': 'fr', 'native': 'Français'},
    {'code': 'es', 'native': 'Español'},
    {'code': 'tr', 'native': 'Türkçe'},
    {'code': 'ur', 'native': 'اردو'},
    {'code': 'hi', 'native': 'हिन्दी'},
    {'code': 'bn', 'native': 'বাংলা'},
    {'code': 'ru', 'native': 'Русский'},
    {'code': 'zh', 'native': '中文'},
  ];

  @override
  Widget build(BuildContext context) {
    return IconButton(
      icon: const Icon(Icons.language),
      tooltip: t('language'),
      onPressed: () {
        showModalBottomSheet(
          context: context,
          shape: const RoundedRectangleBorder(
            borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
          ),
          builder: (_) => SafeArea(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Padding(
                  padding: const EdgeInsets.all(16),
                  child: Text(
                    t('language'),
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                const Divider(height: 1),
                ...languages.map((lang) {
                  final isSelected =
                      localeNotifier.value.languageCode == lang['code'];
                  return ListTile(
                    leading: Text(
                      lang['native']!,
                      style: const TextStyle(fontSize: 16),
                    ),
                    trailing: isSelected
                        ? Icon(
                            Icons.check,
                            color: Theme.of(context).colorScheme.primary,
                          )
                        : null,
                    onTap: () {
                      localeNotifier.value = Locale(lang['code']!);
                      Navigator.pop(context);
                    },
                  );
                }),
                const SizedBox(height: 16),
              ],
            ),
          ),
        );
      },
    );
  }
}
