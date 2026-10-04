import 'package:flutter/foundation.dart';

class TranslationService {
  static final TranslationService instance = TranslationService._internal();
  TranslationService._internal();

  static const Map<String, String> languageNames = {
    'en': 'English',
    'hi': 'Hindi',
    'ml': 'Malayalam',
    'ta': 'Tamil',
    'te': 'Telugu',
    'kn': 'Kannada',
    'bn': 'Bengali',
    'mr': 'Marathi',
    'fr': 'French',
    'de': 'German',
    'es': 'Spanish',
  };

  /// Pre-built dictionary mappings for instant realistic demo translations
  static const Map<String, Map<String, String>> _phraseDictionary = {
    'hi': {
      'where is the meeting point?': 'बैठक का स्थान कहाँ है?',
      'hi! are you available for a tour?': 'नमस्ते! क्या आप दौरे के लिए उपलब्ध हैं?',
      'what time does the tour start?': 'दौरा किस समय शुरू होता है?',
      'please share the total estimated cost': 'कृपया कुल अनुमानित लागत साझा करें',
      'sounds great! i am interested.': 'बहुत बढ़िया! मुझे दिलचस्पी है।',
      'hello': 'नमस्ते',
      'thank you': 'धन्यवाद',
      'see you soon': 'जल्द मिलते हैं',
    },
    'ml': {
      'where is the meeting point?': 'മീറ്റിംഗ് പോയിന്റ് എവിടെയാണ്?',
      'hi! are you available for a tour?': 'ഹായ്! ടൂറിനായി ലഭ്യമാണോ?',
      'what time does the tour start?': 'ടൂർ ഏതു സമയത്താണ് ആരംഭിക്കുന്നത്?',
      'please share the total estimated cost': 'ദയവായി ആകെ കണക്കാക്കിയ തുക പങ്കിടുക',
      'sounds great! i am interested.': 'വളരെ നല്ലത്! എനിക്ക് താല്പര്യമുണ്ട്.',
      'hello': 'ഹലോ / നമസ്കാരം',
      'thank you': 'നന്ദി',
      'see you soon': 'പിന്നെ കാണാം',
    },
    'ta': {
      'where is the meeting point?': 'சந்திப்பு இடம் எங்கே?',
      'hi! are you available for a tour?': 'ஹாய்! சுற்றுலாவுக்கு கிடைக்கிறீர்களா?',
      'what time does the tour start?': 'சுற்றுலா எத்தனை மணிக்கு தொடங்குகிறது?',
      'please share the total estimated cost': 'மொத்த மதிப்பிடப்பட்ட தொகையைப் பகிரவும்',
      'sounds great! i am interested.': 'மிக நன்று! எனக்கு ஆர்வமுள்ளது.',
      'hello': 'வணக்கம்',
      'thank you': 'நன்றி',
    },
    'es': {
      'where is the meeting point?': '¿Dónde está el punto de encuentro?',
      'hi! are you available for a tour?': '¡Hola! ¿Estás disponible para un recorrido?',
      'what time does the tour start?': '¿A qué hora empieza el recorrido?',
      'please share the total estimated cost': 'Por favor comparta el costo total estimado',
      'sounds great! i am interested.': '¡Suena genial! Estoy interesado.',
      'hello': 'Hola',
      'thank you': 'Gracias',
    },
    'fr': {
      'where is the meeting point?': 'Où est le point de rendez-vous ?',
      'hi! are you available for a tour?': 'Salut ! Es-tu disponible pour une visite ?',
      'what time does the tour start?': 'À quelle heure commence la visite ?',
      'please share the total estimated cost': 'Veuillez partager le coût total estimé',
      'sounds great! i am interested.': 'Ça a l\'air super ! Je suis intéressé.',
      'hello': 'Bonjour',
      'thank you': 'Merci',
    },
  };

  /// Translate a message content into a target language code
  Future<String> translateText(String text, String targetLang) async {
    final clean = text.trim().toLowerCase();
    if (targetLang == 'en' || clean.isEmpty) return text;

    // Check pre-built phrase dictionary for exact matches
    if (_phraseDictionary.containsKey(targetLang) && _phraseDictionary[targetLang]!.containsKey(clean)) {
      return _phraseDictionary[targetLang]![clean]!;
    }

    // Dynamic mock translation fallback for demo text
    final prefix = _getLangPrefix(targetLang);
    return '$prefix $text';
  }

  /// Generate translations payload map for all common target languages
  Future<Map<String, String>> generateTranslationsMap(String originalText) async {
    final Map<String, String> result = {};
    for (final lang in languageNames.keys) {
      result[lang] = await translateText(originalText, lang);
    }
    return result;
  }

  String _getLangPrefix(String code) {
    switch (code) {
      case 'hi':
        return '[अनुवाद]';
      case 'ml':
        return '[തർജ്ജമ]';
      case 'ta':
        return '[மொழிபெயர்ப்பு]';
      case 'te':
        return '[అనువాదం]';
      case 'kn':
        return '[ಅನುವಾದ]';
      case 'bn':
        return '[অনুবাদ]';
      case 'mr':
        return '[भाषांतर]';
      case 'fr':
        return '[Traduction]';
      case 'de':
        return '[Übersetzung]';
      case 'es':
        return '[Traducción]';
      default:
        return '[Translated]';
    }
  }
}
