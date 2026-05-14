import 'package:flutter/material.dart';
import '../providers/locale_provider.dart';
import '../lang/translations.dart';

class LanguageSelector extends StatelessWidget {
  const LanguageSelector({super.key});

  final List<Map<String, String>> languages = const [
    {'code': 'en', 'name': 'English', 'native': 'English'},
    {'code': 'ar', 'name': 'Arabic', 'native': 'العربية'},
    {'code': 'fr', 'name': 'French', 'native': 'Français'},
    {'code': 'es', 'name': 'Spanish', 'native': 'Español'},
    {'code': 'tr', 'name': 'Turkish', 'native': 'Türkçe'},
    {'code': 'ur', 'name': 'Urdu', 'native': 'اردو'},
    {'code': 'hi', 'name': 'Hindi', 'native': 'हिन्दी'},
    {'code': 'bn', 'name': 'Bengali', 'native': 'বাংলা'},
    {'code': 'ru', 'name': 'Russian', 'native': 'Русский'},
    {'code': 'zh', 'name': 'Chinese', 'native': '中文'},
  ];

  void _showLanguageSheet(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (_) => SafeArea(
        child: Container(
          constraints: BoxConstraints(
            maxHeight: MediaQuery.of(context).size.height * 0.7,
          ),
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
              Flexible(
                child: ListView.builder(
                  shrinkWrap: true,
                  itemCount: languages.length,
                  itemBuilder: (context, index) {
                    final lang = languages[index];
                    final isSelected =
                        localeNotifier.value.languageCode == lang['code'];
                    return ListTile(
                      leading: Text(
                        lang['native']!,
                        style: const TextStyle(fontSize: 16),
                      ),
                      title: Text(lang['name']!),
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
                  },
                ),
              ),
              const SizedBox(height: 16),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return ListTile(
      leading: const Icon(Icons.language),
      title: Text(t('language')),
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          ValueListenableBuilder<Locale>(
            valueListenable: localeNotifier,
            builder: (_, locale, __) {
              final current = languages.firstWhere(
                (l) => l['code'] == locale.languageCode,
                orElse: () => languages.first,
              );
              return Text(
                current['native']!,
                style: TextStyle(
                  color: Theme.of(context).colorScheme.primary,
                  fontWeight: FontWeight.bold,
                ),
              );
            },
          ),
          const Icon(Icons.chevron_right),
        ],
      ),
      onTap: () => _showLanguageSheet(context),
    );
  }
}
