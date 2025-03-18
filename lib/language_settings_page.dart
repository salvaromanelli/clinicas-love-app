import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'providers/language_provider.dart';
import 'i18n/app_localizations.dart';

class LanguageSettingsPage extends StatelessWidget {
  const LanguageSettingsPage({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final languageProvider = Provider.of<LanguageProvider>(context);
    final localizations = AppLocalizations.of(context);
    
    return Scaffold(
      appBar: AppBar(
        title: Text(localizations.get('language_settings')),
        backgroundColor: Theme.of(context).colorScheme.primary,
        foregroundColor: Colors.white,
      ),
      body: ListView(
        children: [
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: Text(
              localizations.get('select_language'),
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: Theme.of(context).colorScheme.primary,
              ),
            ),
          ),
          _buildLanguageOption(
            context, 
            'Español', 
            'es', 
            languageProvider,
            flagPath: 'assets/images/esp.png',
          ),
          _buildLanguageOption(
            context, 
            'English', 
            'en', 
            languageProvider,
            flagPath: 'assets/images/united-kingdom.png',
          ),
          _buildLanguageOption(
            context, 
            'Català', 
            'ca', 
            languageProvider,
            flagPath: 'assets/images/cat.png',
          ),
        ],
      ),
    );
  }
  
  Widget _buildLanguageOption(
    BuildContext context, 
    String name, 
    String code, 
    LanguageProvider provider, 
    {String? flagPath}
  ) {
    final isSelected = provider.currentLocale.languageCode == code;
    
    return ListTile(
      leading: flagPath != null 
          ? CircleAvatar(
              backgroundImage: AssetImage(flagPath),
            )
          : CircleAvatar(
              child: Text(code.toUpperCase()),
            ),
      title: Text(name),
      trailing: isSelected 
          ? Icon(
              Icons.check_circle, 
              color: Theme.of(context).colorScheme.primary,
            )
          : null,
      tileColor: isSelected ? Theme.of(context).colorScheme.primary.withOpacity(0.1) : null,
      onTap: () {
        provider.setLocale(Locale(code));
      },
    );
  }
}