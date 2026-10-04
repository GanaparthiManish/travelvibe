import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'main.dart';
import 'services/wishlist_service.dart';

// ──────────────────────────────────────────
// Color Tokens (matching HTML CSS vars)
// ──────────────────────────────────────────
const Color kInk = Color(0xFF222222);
const Color kInkSoft = Color(0xFF6B6B6B);
const Color kLine = Color(0xFFEBEBEB);
const Color kAccent = Color(0xFFE8483A);
const Color kWhite = Color(0xFFFFFFFF);
const Color kPaper = Color(0xFFFAFAFA);
const Color kGreen = Color(0xFF1E8E5A);
const Color kGrayBg = Color(0xFFF0F0F0);
const Color kScreenBg = Color(0xFFEFEFEF);

// Real-time Dark Mode Helper Functions
bool isDarkMode(BuildContext context) {
  return themeNotifier.value == ThemeMode.dark || Theme.of(context).brightness == Brightness.dark;
}

Color appBgColor(BuildContext context) => isDarkMode(context) ? const Color(0xFF121212) : kWhite;
Color appPaperColor(BuildContext context) => isDarkMode(context) ? const Color(0xFF1E1E1E) : kPaper;
Color appInkColor(BuildContext context) => isDarkMode(context) ? const Color(0xFFF3F4F6) : kInk;
Color appInkSoftColor(BuildContext context) => isDarkMode(context) ? const Color(0xFF9CA3AF) : kInkSoft;
Color appLineColor(BuildContext context) => isDarkMode(context) ? const Color(0xFF2D2D2D) : kLine;

// Real-Time Language Notifier
final ValueNotifier<String> languageNotifier = ValueNotifier<String>('English (US)');

// Real-Time Wishlist Notifier
final ValueNotifier<Set<String>> wishlistNotifier = ValueNotifier<Set<String>>({});

// Multi-language dictionary
String tr(String key) {
  final lang = languageNotifier.value;
  
  const Map<String, Map<String, String>> dict = {
    'home': {
      'English (US)': 'Home',
      'Hindi (हिंदी)': 'होम',
      'Bengali (বাংলা)': 'হোম',
      'Tamil (தமிழ்)': 'முகப்பு',
      'Telugu (తెలుగు)': 'హోమ్',
      'Spanish (Español)': 'Inicio',
    },
    'search': {
      'English (US)': 'Search',
      'Hindi (हिंदी)': 'खोजें',
      'Bengali (বাংলা)': 'সন্ধান',
      'Tamil (தமிழ்)': 'தேடல்',
      'Telugu (తెలుగు)': 'శోధన',
      'Spanish (Español)': 'Buscar',
    },
    'shop': {
      'English (US)': 'Shop',
      'Hindi (हिंदी)': 'शॉप',
      'Bengali (বাংলা)': 'শপ',
      'Tamil (தமிழ்)': 'கடை',
      'Telugu (తెలుగు)': 'షాప్',
      'Spanish (Español)': 'Tienda',
    },
    'trips': {
      'English (US)': 'Trips',
      'Hindi (हिंदी)': 'यात्राएं',
      'Bengali (বাংলা)': 'ভ্রমণ',
      'Tamil (தமிழ்)': 'பயணங்கள்',
      'Telugu (తెలుగు)': 'ప్రయాణాలు',
      'Spanish (Español)': 'Viajes',
    },
    'profile': {
      'English (US)': 'Profile',
      'Hindi (हिंदी)': 'प्रोफ़ाइल',
      'Bengali (বাংলা)': 'প্রোফাইল',
      'Tamil (தமிழ்)': 'சுயவிவரம்',
      'Telugu (తెలుగు)': 'ప్రొఫైల్',
      'Spanish (Español)': 'Perfil',
    },
    'good_morning': {
      'English (US)': 'Good morning 👋',
      'Hindi (हिंदी)': 'शुभ प्रभात 👋',
      'Bengali (বাংলা)': 'সুপ্রভাত 👋',
      'Tamil (தமிழ்)': 'காலை வணக்கம் 👋',
      'Telugu (తెలుగు)': 'శుభోదయం 👋',
      'Spanish (Español)': 'Buenos días 👋',
    },
    'search_placeholder': {
      'English (US)': 'Where to next? Search Munnar, Ladakh...',
      'Hindi (हिंदी)': 'अगली यात्रा कहाँ? मुन्नार, लद्दाख खोजें...',
      'Bengali (বাংলা)': 'পরবর্তী গন্তব্য কোথায়? মুন্নার, লাদাখ খুঁজুন...',
      'Tamil (தமிழ்)': 'அடுத்த பயணம் எங்கே? மூணார், லடாக் தேடவும்...',
      'Telugu (తెలుగు)': 'తరువాతి ప్రయాణం ఎక్కడికి? మున్నార్, లడఖ్ శోధించండి...',
      'Spanish (Español)': '¿A dónde viajar ahora? Buscar Munnar...',
    },
    'featured_destinations': {
      'English (US)': 'Featured destinations',
      'Hindi (हिंदी)': 'प्रमुख गंतव्य',
      'Bengali (বাংলা)': 'সেরা গন্তব্যসমূহ',
      'Tamil (தமிழ்)': 'சிறப்பு இடங்கள்',
      'Telugu (తెలుగు)': 'ప్రధాన ప్రాంతాలు',
      'Spanish (Español)': 'Destinos destacados',
    },
    'top_rated_agents': {
      'English (US)': 'Top rated local agents',
      'Hindi (हिंदी)': 'शीर्ष मूल्यांकित स्थानीय एजेंट',
      'Bengali (বাংলা)': 'সেরা স্থানীয় গাইড',
      'Tamil (தமிழ்)': 'முன்னணி உள்ளூர் வழிகாட்டிகள்',
      'Telugu (తెలుగు)': 'టాప్ రేటెడ్ లోకల్ గైడ్లు',
      'Spanish (Español)': 'Guías locales destacados',
    },
    'my_wishlist': {
      'English (US)': 'My Wishlist',
      'Hindi (हिंदी)': 'मेरी विशलिस्ट',
      'Bengali (বাংলা)': 'আমার পছন্দের তালিকা',
      'Tamil (தமிழ்)': 'என் விருப்பப்பட்டியல்',
      'Telugu (తెలుగు)': 'నా విష్‌లిస్ట్',
      'Spanish (Español)': 'Mi lista de deseos',
    },
    'app_settings': {
      'English (US)': 'App Settings',
      'Hindi (हिंदी)': 'ऐप सेटिंग्स',
      'Bengali (বাংলা)': 'অ্যাপ সেটিংস',
      'Tamil (தமிழ்)': 'செயலி அமைப்புகள்',
      'Telugu (తెలుగు)': 'యాప్ సెట్టింగ్‌లు',
      'Spanish (Español)': 'Ajustes de la aplicación',
    },
    'help_support': {
      'English (US)': 'Help & Support',
      'Hindi (हिंदी)': 'सहायता और समर्थन',
      'Bengali (বাংলা)': 'সাহায্য ও সহায়তা',
      'Tamil (தமிழ்)': 'உதவி & ஆதரவு',
      'Telugu (తెలుగు)': 'సహాయం & మద్దతు',
      'Spanish (Español)': 'Ayuda y soporte',
    },
    'dark_mode': {
      'English (US)': 'Dark Theme',
      'Hindi (हिंदी)': 'डार्क थीम',
      'Bengali (বাংলা)': 'ডার্ক থিম',
      'Tamil (தமிழ்)': 'இருண்ட ገ தோற்றம்',
      'Telugu (తెలుగు)': 'డార్క్ థీమ్',
      'Spanish (Español)': 'Modo oscuro',
    },
    'display_language': {
      'English (US)': 'Display Language',
      'Hindi (हिंदी)': 'प्रदर्शन भाषा',
      'Bengali (বাংলা)': 'প্রদর্শন भाषा',
      'Tamil (தமிழ்)': 'காட்சி மொழி',
      'Telugu (తెలుగు)': 'డిస్ప్లే భాష',
      'Spanish (Español)': 'Idioma de la app',
    },
    'profile_account': {
      'English (US)': 'Profile & Account',
      'Hindi (हिंदी)': 'प्रोफ़ाइल और खाता',
      'Bengali (বাংলা)': 'প্রোফাইল এবং অ্যাকাউন্ট',
      'Tamil (தமிழ்)': 'சுயவிவரம் & கணக்கு',
      'Telugu (తెలుగు)': 'ప్రొఫైల్ & ఖాతా',
      'Spanish (Español)': 'Perfil y cuenta',
    },
    'total_trips': {
      'English (US)': 'TOTAL TRIPS',
      'Hindi (हिंदी)': 'कुल यात्राएं',
      'Bengali (বাংলা)': 'মোট ভ্রমণ',
      'Tamil (தமிழ்)': 'மொத்த பயணங்கள்',
      'Telugu (తెలుగు)': 'మొత్తం ప్రయాణాలు',
      'Spanish (Español)': 'VIAJES TOTALES',
    },
    'countries': {
      'English (US)': 'COUNTRIES',
      'Hindi (हिंदी)': 'देश',
      'Bengali (বাংলা)': 'দেশসমূহ',
      'Tamil (தமிழ்)': 'நாடுகள்',
      'Telugu (తెలుగు)': 'దేశాలు',
      'Spanish (Español)': 'PAÍSES',
    },
    'reviews': {
      'English (US)': 'REVIEWS',
      'Hindi (हिंदी)': 'समीक्षाएं',
      'Bengali (বাংলা)': 'পর্যালোচনা',
      'Tamil (தமிழ்)': 'மதிப்புரைகள்',
      'Telugu (తెలుగు)': 'సమీక్షలు',
      'Spanish (Español)': 'RESEÑAS',
    },
    'account_settings': {
      'English (US)': 'Account Settings',
      'Hindi (हिंदी)': 'खाता सेटिंग्स',
      'Bengali (বাংলা)': 'অ্যাকাউন্ট সেটিংস',
      'Tamil (தமிழ்)': 'கணக்கு அமைப்புகள்',
      'Telugu (తెలుగు)': 'ఖాతా సెట్టింగ్‌లు',
      'Spanish (Español)': 'Ajustes de cuenta',
    },
    'my_orders': {
      'English (US)': 'My Orders',
      'Hindi (हिंदी)': 'मेरे ऑर्डर',
      'Bengali (বাংলা)': 'আমার অর্ডার',
      'Tamil (தமிழ்)': 'என் ஆர்டர்கள்',
      'Telugu (తెలుగు)': 'నా ఆర్డర్‌లు',
      'Spanish (Español)': 'Mis pedidos',
    },
    'saved_addresses': {
      'English (US)': 'Saved Delivery Addresses',
      'Hindi (हिंदी)': 'सहेजे गए डिलीवरी पते',
      'Bengali (বাংলা)': 'সংরক্ষিত ঠিকানা',
      'Tamil (தமிழ்)': 'சேமிக்கப்பட்ட முகவரிகள்',
      'Telugu (తెలుగు)': 'సేవ్ చేసిన చిరునామాలు',
      'Spanish (Español)': 'Direcciones guardadas',
    },
    'realtime_notifications': {
      'English (US)': 'Notifications',
      'Hindi (हिंदी)': 'सूचनाएं',
      'Bengali (বাংলা)': 'বিজ্ঞপ্তি',
      'Tamil (தமிழ்)': 'அறிவிப்புகள்',
      'Telugu (తెలుగు)': 'నోటిఫికేషన్లు',
      'Spanish (Español)': 'Notificaciones',
    },
    'notifications': {
      'English (US)': 'Notifications',
      'Hindi (हिंदी)': 'सूचनाएं',
      'Bengali (বাংলা)': 'বিজ্ঞপ্তি',
      'Tamil (தமிழ்)': 'அறிவிப்புகள்',
      'Telugu (తెలుగు)': 'నోటిఫికేషన్లు',
      'Spanish (Español)': 'Notificaciones',
    },
    'push_notifications': {
      'English (US)': 'Push Notifications',
      'Hindi (हिंदी)': 'पुश नोटिफिकेशन',
      'Bengali (বাংলা)': 'বিজ্ঞপ্তি',
      'Tamil (தமிழ்)': 'புஷ் அறிவிப்புகள்',
      'Telugu (తెలుగు)': 'పుష్ నోటిఫికేషన్లు',
      'Spanish (Español)': 'Notificaciones push',
    },
    'location_services': {
      'English (US)': 'Location Services',
      'Hindi (हिंदी)': 'स्थान सेवाएं',
      'Bengali (বাংলা)': 'অবস্থান পরিষেবা',
      'Tamil (தமிழ்)': 'இருப்பிட சேவைகள்',
      'Telugu (తెలుగు)': 'లొకేషన్ సేవలు',
      'Spanish (Español)': 'Servicios de ubicación',
    },
    'email_summaries': {
      'English (US)': 'Email Summaries',
      'Hindi (हिंदी)': 'ईमेल सारांश',
      'Bengali (বাংলা)': 'ইমেল সারসংক্ষেপ',
      'Tamil (தமிழ்)': 'மின்னஞ்சல் சுருக்கங்கள்',
      'Telugu (తెలుగు)': 'ఈమెయిల్ సారాంశాలు',
      'Spanish (Español)': 'Resúmenes por correo',
    },
    'sign_out': {
      'English (US)': 'Sign Out',
      'Hindi (हिंदी)': 'साइन आउट',
      'Bengali (বাংলা)': 'সাইন আউট',
      'Tamil (தமிழ்)': 'வெளியேறு',
      'Telugu (తెలుగు)': 'సైన్ అవుట్',
      'Spanish (Español)': 'Cerrar sesión',
    },
    'this_season_places': {
      'English (US)': 'This Season Places to Visit',
      'Hindi (हिंदी)': 'इस मौसम के देखने योग्य स्थान',
      'Bengali (বাংলা)': 'এই মৌসুমে ভ্রমণের স্থান',
      'Tamil (தமிழ்)': 'இந்த பருவத்தில் பார்க்க வேண்டிய இடங்கள்',
      'Telugu (తెలుగు)': 'ఈ సీజన్‌లో దర్శనీయ ప్రాంతాలు',
      'Spanish (Español)': 'Lugares para visitar esta temporada',
    },
    'ideal_season': {
      'English (US)': 'Ideal Season',
      'Hindi (हिंदी)': 'आदर्श मौसम',
      'Bengali (বাংলা)': 'উপযুক্ত সময়',
      'Tamil (தமிழ்)': 'சிறந்த பருவம்',
      'Telugu (తెలుగు)': 'అనుకూల సమయం',
      'Spanish (Español)': 'Temporada ideal',
    },
    'best_season': {
      'English (US)': 'Best Season',
      'Hindi (हिंदी)': 'सर्वश्रेष्ठ मौसम',
      'Bengali (বাংলা)': 'সেরা সময়',
      'Tamil (தமிழ்)': 'சிறந்த பருவம்',
      'Telugu (తెలుగు)': 'ఉత్తమ సమయం',
      'Spanish (Español)': 'Mejor época',
    },
    'flat_discount_banner': {
      'English (US)': 'Get 25% OFF Your First Local Guide!',
      'Hindi (हिंदी)': 'अपने पहले स्थानीय गाइड पर 25% छूट पाएं!',
      'Bengali (বাংলা)': 'আপনার প্রথম গাইড বুকিংয়ে ২৫% ছাড়!',
      'Tamil (தமிழ்)': 'உங்கள் முதல் வழிகாட்டிக்கு 25% தள்ளுபடி!',
      'Telugu (తెలుగు)': 'మీ మొదటి స్థానిక గైడ్‌పై 25% తగ్గింపు పొందండి!',
      'Spanish (Español)': '¡25% de descuento en tu primer guía local!',
    },
    'book_guide_now': {
      'English (US)': 'Book Guide Now →',
      'Hindi (हिंदी)': 'अभी गाइड बुक करें →',
      'Bengali (বাংলা)': 'এখনই গাইড বুক করুন →',
      'Tamil (தமிழ்)': 'இப்போதே முன்பதிவு செய்க →',
      'Telugu (తెలుగు)': 'ఇప్పుడే గైడ్‌ను బుక్ చేయండి →',
      'Spanish (Español)': 'Reservar guía ahora →',
    },
    'gear_store_banner': {
      'English (US)': 'Essential Trekking & Outdoor Gear',
      'Hindi (हिंदी)': 'आवश्यक ट्रेकिंग और आउटडोर गियर',
      'Bengali (বাংলা)': 'প্রয়োজনীয় ট্র্যাকিং সরঞ্জাম',
      'Tamil (தமிழ்)': 'அத்தியாவசிய ட்ரெக்கிங் கருவிகள்',
      'Telugu (తెలుగు)': 'అవసరమైన ట్రెక్కింగ్ & అవుట్‌డోర్ గేర్',
      'Spanish (Español)': 'Equipo esencial de trekking',
    },
    'explore_shop': {
      'English (US)': 'Explore Shop →',
      'Hindi (हिंदी)': 'दुकान देखें →',
      'Bengali (বাংলা)': 'শপ দেখুন →',
      'Tamil (தமிழ்)': 'கடையைப் பார்க்க →',
      'Telugu (తెలుగు)': 'షాప్‌ను చూడండి →',
      'Spanish (Español)': 'Explorar tienda →',
    },
    'all': {
      'English (US)': 'All',
      'Hindi (हिंदी)': 'सभी',
      'Bengali (বাংলা)': 'সব',
      'Tamil (தமிழ்)': 'அனைத்தும்',
      'Telugu (తెలుగు)': 'అన్నీ',
      'Spanish (Español)': 'Todos',
    },
    'beach': {
      'English (US)': 'Beach',
      'Hindi (हिंदी)': 'बीच',
      'Bengali (বাংলা)': 'সৈকত',
      'Tamil (தமிழ்)': 'கடற்கரை',
      'Telugu (తెలుగు)': 'బీచ్',
      'Spanish (Español)': 'Playa',
    },
    'hills': {
      'English (US)': 'Hills',
      'Hindi (हिंदी)': 'पहाड़',
      'Bengali (বাংলা)': 'পাহাড়',
      'Tamil (தமிழ்)': 'மலைகள்',
      'Telugu (తెలుగు)': 'కొండలు',
      'Spanish (Español)': 'Colinas',
    },
    'honeymoon': {
      'English (US)': 'Honeymoon',
      'Hindi (हिंदी)': 'हनीमून',
      'Bengali (বাংলা)': 'হনিমুন',
      'Tamil (தமிழ்)': 'தேனிலவு',
      'Telugu (తెలుగు)': 'హనీమూన్',
      'Spanish (Español)': 'Luna de miel',
    },
    'adventure': {
      'English (US)': 'Adventure',
      'Hindi (हिंदी)': 'साहस',
      'Bengali (বাংলা)': 'অ্যাডভেঞ্চার',
      'Tamil (தமிழ்)': 'சாகசம்',
      'Telugu (తెలుగు)': 'సాహసం',
      'Spanish (Español)': 'Aventura',
    },
    'culture': {
      'English (US)': 'Culture',
      'Hindi (हिंदी)': 'संस्कृति',
      'Bengali (বাংলা)': 'সংস্কৃতি',
      'Tamil (தமிழ்)': 'கலாச்சாரம்',
      'Telugu (తెలుగు)': 'సంస్కృతి',
      'Spanish (Español)': 'Cultura',
    },
    'discover_search': {
      'English (US)': 'Discover & Search',
      'Hindi (हिंदी)': 'खोजें और जानें',
      'Bengali (বাংলা)': 'আবিষ্কার ও অনুসন্ধান',
      'Tamil (தமிழ்)': 'கண்டறிந்து தேடுக',
      'Telugu (తెలుగు)': 'కనుగొనండి & శోధించండి',
      'Spanish (Español)': 'Descubrir y buscar',
    },
    'top_rated': {
      'English (US)': 'Top Rated',
      'Hindi (हिंदी)': 'शीर्ष मूल्यांकित',
      'Bengali (বাংলা)': 'সেরা রেটিং',
      'Tamil (தமிழ்)': 'சிறந்த மதிப்பிடப்பட்டது',
      'Telugu (తెలుగు)': 'టాప్ రేటెడ్',
      'Spanish (Español)': 'Mejor valorados',
    },
    'featured': {
      'English (US)': 'Featured',
      'Hindi (हिंदी)': 'विशेष',
      'Bengali (বাংলা)': 'বিশেষ',
      'Tamil (தமிழ்)': 'சிறப்பு',
      'Telugu (తెలుగు)': 'ప్రధానమైనవి',
      'Spanish (Español)': 'Destacados',
    },
    'trending': {
      'English (US)': 'Trending',
      'Hindi (हिंदी)': 'ट्रेंडिंग',
      'Bengali (বাংলা)': 'ট্রেন্ডিং',
      'Tamil (தமிழ்)': 'பிரபலமானவை',
      'Telugu (తెలుగు)': 'ట్రెండింగ్',
      'Spanish (Español)': 'Tendencias',
    },
    'shopping_cart': {
      'English (US)': 'Shopping Cart',
      'Hindi (हिंदी)': 'शॉपिंग कार्ट',
      'Bengali (বাংলা)': 'শপিং কার্ট',
      'Tamil (தமிழ்)': 'ஷாப்பிங் கார்ட்',
      'Telugu (తెలుగు)': 'షాపింగ్ కార్ట్',
      'Spanish (Español)': 'Carrito de compras',
    },
    'delivery_address': {
      'English (US)': 'Delivery Address',
      'Hindi (हिंदी)': 'डिलीवरी का पता',
      'Bengali (বাংলা)': 'ডেলিভারি ঠিকানা',
      'Tamil (தமிழ்)': 'டெலிவரி முகவரி',
      'Telugu (తెలుగు)': 'డెలివరీ చిరునామా',
      'Spanish (Español)': 'Dirección de entrega',
    },
    'house_flat': {
      'English (US)': 'House / Flat / Building No.',
      'Hindi (हिंदी)': 'मकान / फ्लैट नंबर',
      'Bengali (বাংলা)': 'বাড়ি / ফ্ল্যাট নম্বর',
      'Tamil (தமிழ்)': 'வீடு / பிளாட் எண்',
      'Telugu (తెలుగు)': 'ఇంటి / ఫ్లాట్ సంఖ్య',
      'Spanish (Español)': 'Casa / Piso / Edificio',
    },
    'street_area': {
      'English (US)': 'Street / Area / Landmark',
      'Hindi (हिंदी)': 'सड़क / क्षेत्र / लैंडमार्क',
      'Bengali (বাংলা)': 'রাস্তা / এলাকা / ল্যান্ডমার্ক',
      'Tamil (தமிழ்)': 'தெரு / பகுதி',
      'Telugu (తెలుగు)': 'వీధి / ప్రాంతం / ల్యాండ్‌మార్క్',
      'Spanish (Español)': 'Calle / Zona / Referencia',
    },
    'city': {
      'English (US)': 'City',
      'Hindi (हिंदी)': 'शहर',
      'Bengali (বাংলা)': 'শহর',
      'Tamil (தமிழ்)': 'நகரம்',
      'Telugu (తెలుగు)': 'నగరం',
      'Spanish (Español)': 'Ciudad',
    },
    'pincode': {
      'English (US)': 'Pincode',
      'Hindi (हिंदी)': 'पिनकोड',
      'Bengali (বাংলা)': 'পিনকোড',
      'Tamil (தமிழ்)': 'பின்கோடு',
      'Telugu (తెలుగు)': 'పిన్‌కోడ్',
      'Spanish (Español)': 'Código postal',
    },
    'mobile_number': {
      'English (US)': 'Mobile Number for delivery updates',
      'Hindi (हिंदी)': 'डिलीवरी अपडेट के लिए मोबाइल नंबर',
      'Bengali (বাংলা)': 'ডেলিভারি আপডেটের জন্য মোবাইল নম্বর',
      'Tamil (தமிழ்)': 'டெலிவரி புதுப்பிப்புகளுக்கான கைபேசி எண்',
      'Telugu (తెలుగు)': 'డెలివరీ నవీకరణల కోసం మొబైల్ సంఖ్య',
      'Spanish (Español)': 'Teléfono móvil',
    },
    'save_address_btn': {
      'English (US)': 'Save Address to Profile',
      'Hindi (हिंदी)': 'पता प्रोफ़ाइल में सहेजें',
      'Bengali (বাংলা)': 'প্রোফাইলে ঠিকানা সংরক্ষণ করুন',
      'Tamil (தமிழ்)': 'முகவரியைச் சேமிக்கவும்',
      'Telugu (తెలుగు)': 'చిరునామాను సేవ్‌ చేయండి',
      'Spanish (Español)': 'Guardar dirección en perfil',
    },
    'place_order': {
      'English (US)': 'Place Order',
      'Hindi (हिंदी)': 'ऑर्डर दें',
      'Bengali (বাংলা)': 'অর্ডার দিন',
      'Tamil (தமிழ்)': 'ஆர்டர் செய்க',
      'Telugu (తెలుగు)': 'ఆర్డర్ చేయండి',
      'Spanish (Español)': 'Realizar pedido',
    },
    'items_subtotal': {
      'English (US)': 'Items Subtotal',
      'Hindi (हिंदी)': 'आइटम उप-योग',
      'Bengali (বাংলা)': 'আইটেম সাবটোটাল',
      'Tamil (தமிழ்)': 'பொருட்களின் விபரம்',
      'Telugu (తెలుగు)': 'వస్తువుల సబ్‌టోటల్',
      'Spanish (Español)': 'Subtotal de artículos',
    },
    'delivery_charge': {
      'English (US)': 'Delivery Charge',
      'Hindi (हिंदी)': 'डिलीवरी शुल्क',
      'Bengali (বাংলা)': 'ডেলিভারি চার্জ',
      'Tamil (தமிழ்)': 'டெலிவரி கட்டணம்',
      'Telugu (తెలుగు)': 'డెలివరీ ఛార్జ్',
      'Spanish (Español)': 'Gasto de envío',
    },
    'total_amount': {
      'English (US)': 'Total Amount',
      'Hindi (हिंदी)': 'कुल राशि',
      'Bengali (বাংলা)': 'মোট পরিমাণ',
      'Tamil (தமிழ்)': 'மொத்த தொகை',
      'Telugu (తెలుగు)': 'మొత్తం సొమ్ము',
      'Spanish (Español)': 'Monto total',
    },
    'select_saved_address': {
      'English (US)': 'Select Saved Address',
      'Hindi (हिंदी)': 'सहेजा गया पता चुनें',
      'Bengali (বাংলা)': 'সংরক্ষিত ঠিকানা নির্বাচন করুন',
      'Tamil (தமிழ்)': 'சேமிக்கப்பட்ட முகவரியைத் தேர்ந்தெடுக்கவும்',
      'Telugu (తెలుగు)': 'సేవ్ చేసిన చిరునామాను ఎంచుకోండి',
      'Spanish (Español)': 'Seleccionar dirección guardada',
    },
  };

  return dict[key]?[lang] ?? dict[key]?['English (US)'] ?? key;
}

// Gradient presets matching HTML photo classes
const List<Color> gP1 = [Color(0xFF3A5A40), Color(0xFF588157), Color(0xFFA3B18A)];
const List<Color> gP2 = [Color(0xFF1D3557), Color(0xFF457B9D), Color(0xFFA8DADC)];
const List<Color> gP3 = [Color(0xFF6D4C41), Color(0xFFA1887F), Color(0xFFD7CCC8)];
const List<Color> gP4 = [Color(0xFF7209B7), Color(0xFFB5179E), Color(0xFFF72585)];
const List<Color> gP5 = [Color(0xFF0A4A4A), Color(0xFF2A9D8F), Color(0xFFE9C46A)];

// ──────────────────────────────────────────
// Dynamic Text Styles & Helpers
// ──────────────────────────────────────────
TextStyle kLcTitle = GoogleFonts.plusJakartaSans(fontSize: 12, fontWeight: FontWeight.w700);
TextStyle kLcMeta = GoogleFonts.plusJakartaSans(fontSize: 10.5, fontWeight: FontWeight.w500);
TextStyle kSectionH = GoogleFonts.plusJakartaSans(fontSize: 13, fontWeight: FontWeight.w800);
TextStyle kAppBarTitle = GoogleFonts.plusJakartaSans(fontSize: 15, fontWeight: FontWeight.w800);
TextStyle kChipText = GoogleFonts.plusJakartaSans(fontSize: 10.5, fontWeight: FontWeight.w700);
TextStyle kStatLabel = GoogleFonts.plusJakartaSans(fontSize: 10, fontWeight: FontWeight.w700, letterSpacing: 0.5);
TextStyle kStatVal = GoogleFonts.plusJakartaSans(fontSize: 19, fontWeight: FontWeight.w800);
TextStyle kBtnText = GoogleFonts.plusJakartaSans(fontSize: 13, fontWeight: FontWeight.w700, color: kWhite);
TextStyle kFieldHint = GoogleFonts.plusJakartaSans(fontSize: 12.5, fontWeight: FontWeight.w500, color: Color(0xFFA3A3A3));

// ──────────────────────────────────────────
// Helper Widgets
// ──────────────────────────────────────────

/// Pill chip matching .chip / .chip.active
Widget ttChip(
  String label, {
  BuildContext? context,
  bool active = false,
  VoidCallback? onTap,
}) {
  return Builder(
    builder: (ctx) {
      final activeBg = isDarkMode(ctx) ? kAccent : kInk;
      const activeFg = kWhite;
      final inactiveBg = appPaperColor(ctx);
      final inactiveFg = appInkSoftColor(ctx);
      final borderColor = active ? activeBg : appLineColor(ctx);

      return GestureDetector(
        onTap: onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          decoration: BoxDecoration(
            color: active ? activeBg : inactiveBg,
            border: Border.all(color: borderColor, width: 1.5),
            borderRadius: BorderRadius.circular(20),
          ),
          child: Text(
            label,
            style: kChipText.copyWith(color: active ? activeFg : inactiveFg),
          ),
        ),
      );
    },
  );
}

/// Badge pill matching .badge.pending / .confirmed / .cancelled
Widget ttBadge(
  String label, {
  BuildContext? context,
}) {
  final ctx = context;
  Color bg;
  Color fg;
  final dark = ctx != null ? isDarkMode(ctx) : false;
  switch (label.toLowerCase()) {
    case 'confirmed':
      bg = dark ? const Color(0xFF064E3B) : const Color(0xFFE7F7EF);
      fg = dark ? const Color(0xFF6EE7B7) : kGreen;
      break;
    case 'pending':
      bg = dark ? const Color(0xFF78350F) : const Color(0xFFFFF4E5);
      fg = dark ? const Color(0xFFFDE68A) : const Color(0xFFB45309);
      break;
    case 'cancelled':
      bg = dark ? const Color(0xFF7F1D1D) : const Color(0xFFFDE8E8);
      fg = dark ? const Color(0xFFFCA5A5) : const Color(0xFFC0392B);
      break;
    default:
      bg = ctx != null ? appPaperColor(ctx) : kGrayBg;
      fg = ctx != null ? appInkSoftColor(ctx) : kInkSoft;
  }
  return Container(
    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
    decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(12)),
    child: Text(label,
        style: GoogleFonts.plusJakartaSans(
            fontSize: 9.5, fontWeight: FontWeight.w800, color: fg)),
  );
}

/// Primary button matching .btn-primary
Widget ttPrimaryBtn(String label, {VoidCallback? onTap}) {
  return GestureDetector(
    onTap: onTap,
    child: Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(vertical: 13),
      decoration: BoxDecoration(
        color: kAccent,
        borderRadius: BorderRadius.circular(10),
        boxShadow: [
          BoxShadow(
              color: kAccent.withAlpha(77),
              blurRadius: 14,
              offset: const Offset(0, 4))
        ],
      ),
      child: Center(child: Text(label, style: kBtnText)),
    ),
  );
}

/// Outline button matching .btn-outline
Widget ttOutlineBtn(
  String label, {
  VoidCallback? onTap,
  Color? color,
  BuildContext? context,
}) {
  final ctx = context;
  final fgColor = color ?? (ctx != null ? appInkColor(ctx) : kInk);
  return GestureDetector(
    onTap: onTap,
    child: Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(vertical: 13),
      decoration: BoxDecoration(
        border: Border.all(color: fgColor, width: 1.5),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Center(
          child: Text(label,
              style: kBtnText.copyWith(color: fgColor))),
    ),
  );
}

/// Gradient thumb matching .thumb (64×52)
Widget ttThumb(List<Color> colors, {double w = 64, double h = 52, double radius = 10}) {
  return Container(
    width: w,
    height: h,
    decoration: BoxDecoration(
      borderRadius: BorderRadius.circular(radius),
      gradient: LinearGradient(
          colors: colors,
          begin: Alignment.topLeft,
          end: Alignment.bottomRight),
    ),
  );
}

/// Round thumb matching .thumb-round (40×40)
Widget ttThumbRound(List<Color> colors, {double size = 40}) {
  return Container(
    width: size,
    height: size,
    decoration: BoxDecoration(
      borderRadius: BorderRadius.circular(10),
      gradient: LinearGradient(
          colors: colors,
          begin: Alignment.topLeft,
          end: Alignment.bottomRight),
    ),
  );
}

/// Section header
Widget ttSectionH(
  String title, {
  BuildContext? context,
}) {
  final ctx = context;
  return Padding(
    padding: const EdgeInsets.only(top: 14, bottom: 8),
    child: Text(title, style: kSectionH.copyWith(color: ctx != null ? appInkColor(ctx) : kInk)),
  );
}

/// Info card matching .info-card
Widget ttInfoCard({
  required Widget child,
  BuildContext? context,
}) {
  return Builder(
    builder: (ctx) {
      final bg = appPaperColor(ctx);
      final border = appLineColor(ctx);
      return Container(
        width: double.infinity,
        padding: const EdgeInsets.all(12),
        margin: const EdgeInsets.only(bottom: 10),
        decoration: BoxDecoration(
          color: bg,
          border: Border.all(color: border),
          borderRadius: BorderRadius.circular(12),
        ),
        child: child,
      );
    },
  );
}

/// Stat card matching .stat-card
Widget ttStatCard(
  String label,
  String value, {
  BuildContext? context,
}) {
  return Expanded(
    child: Builder(
      builder: (ctx) {
        return Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: appPaperColor(ctx),
            border: Border.all(color: appLineColor(ctx)),
            borderRadius: BorderRadius.circular(14),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label.toUpperCase(),
                style: kStatLabel.copyWith(color: appInkSoftColor(ctx)),
              ),
              const SizedBox(height: 4),
              Text(
                value,
                style: kStatVal.copyWith(color: appInkColor(ctx)),
              ),
            ],
          ),
        );
      },
    ),
  );
}

/// App bar matching .app-bar
Widget ttAppBar(BuildContext context, String title, {bool showBack = false}) {
  return Padding(
    padding: const EdgeInsets.fromLTRB(16, 16, 16, 10),
    child: Row(
      children: [
        if (showBack) ...[
          GestureDetector(
            onTap: () => Navigator.maybePop(context),
            child: Container(
              width: 32,
              height: 32,
              decoration: BoxDecoration(
                  shape: BoxShape.circle, color: appPaperColor(context)),
              child: Icon(Icons.arrow_back_ios_new_rounded,
                  size: 14, color: appInkColor(context)),
            ),
          ),
          const SizedBox(width: 12),
        ],
        Text(title, style: kAppBarTitle.copyWith(color: appInkColor(context))),
      ],
    ),
  );
}

/// List card row (divider at bottom)
Widget ttListCard({
  required Widget leading,
  required Widget middle,
  Widget? trailing,
  BuildContext? context,
}) {
  final ctx = context;
  return Container(
    padding: const EdgeInsets.symmetric(vertical: 10),
    decoration: BoxDecoration(
        border: Border(bottom: BorderSide(color: ctx != null ? appLineColor(ctx) : kLine, width: 1))),
    child: Row(
      children: [
        leading,
        const SizedBox(width: 10),
        Expanded(child: middle),
        if (trailing != null) ...[const SizedBox(width: 8), trailing],
      ],
    ),
  );
}

/// Field decoration matching .field
InputDecoration ttFieldDeco(
  String hint, {
  BuildContext? context,
}) {
  final ctx = context;
  return InputDecoration(
    hintText: hint,
    hintStyle: kFieldHint.copyWith(color: ctx != null ? appInkSoftColor(ctx) : const Color(0xFFA3A3A3)),
    filled: true,
    fillColor: ctx != null ? appPaperColor(ctx) : kPaper,
    border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(10),
        borderSide: BorderSide(color: ctx != null ? appLineColor(ctx) : kLine, width: 1.5)),
    enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(10),
        borderSide: BorderSide(color: ctx != null ? appLineColor(ctx) : kLine, width: 1.5)),
    focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(10),
        borderSide: BorderSide(color: ctx != null ? appInkColor(ctx) : kInk, width: 1.5)),
    contentPadding: const EdgeInsets.symmetric(horizontal: 13, vertical: 12),
  );
}

// ─────────────────────────────────────────────────────────────
// WishlistHeartButton — animated heart for cards
// Usage:
//   WishlistHeartButton.agent(agentId: id)
//   WishlistHeartButton.destination(destinationId: id)
// ─────────────────────────────────────────────────────────────

class WishlistHeartButton extends StatefulWidget {
  final String? agentId;
  final String? destinationId;
  final String? productId;
  final double size;

  const WishlistHeartButton.agent({super.key, required this.agentId, this.size = 20})
      : destinationId = null,
        productId = null;

  const WishlistHeartButton.destination({super.key, required this.destinationId, this.size = 20})
      : agentId = null,
        productId = null;

  const WishlistHeartButton.product({super.key, required this.productId, this.size = 20})
      : agentId = null,
        destinationId = null;

  @override
  State<WishlistHeartButton> createState() => _WishlistHeartButtonState();
}

class _WishlistHeartButtonState extends State<WishlistHeartButton>
    with SingleTickerProviderStateMixin {
  late AnimationController _anim;
  late Animation<double> _scale;
  bool _loading = false;

  @override
  void initState() {
    super.initState();
    _anim = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 300));
    _scale = TweenSequence([
      TweenSequenceItem(tween: Tween(begin: 1.0, end: 1.35), weight: 50),
      TweenSequenceItem(tween: Tween(begin: 1.35, end: 1.0), weight: 50),
    ]).animate(CurvedAnimation(parent: _anim, curve: Curves.easeOut));
  }

  @override
  void dispose() {
    _anim.dispose();
    super.dispose();
  }

  Future<void> _toggle() async {
    if (_loading) return;
    setState(() => _loading = true);
    _anim.forward(from: 0);
    try {
      if (widget.agentId != null) {
        await WishlistService.instance.toggleAgent(widget.agentId!);
      } else if (widget.destinationId != null) {
        await WishlistService.instance.toggleDestination(widget.destinationId!);
      } else if (widget.productId != null) {
        await WishlistService.instance.toggleProduct(widget.productId!);
      }
    } catch (e) {
      debugPrint('[WishlistHeartButton] toggle notice: $e');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: WishlistService.instance,
      builder: (_, __) {
        final bool isWished;
        if (widget.agentId != null) {
          isWished = WishlistService.instance.isAgentWished(widget.agentId!);
        } else if (widget.destinationId != null) {
          isWished = WishlistService.instance.isDestinationWished(widget.destinationId!);
        } else if (widget.productId != null) {
          isWished = WishlistService.instance.isProductWished(widget.productId!);
        } else {
          isWished = false;
        }

        return GestureDetector(
          onTap: _toggle,
          child: ScaleTransition(
            scale: _scale,
            child: Container(
              width: widget.size + 14,
              height: widget.size + 14,
              decoration: BoxDecoration(
                color: isWished
                    ? const Color(0xFFFF4B6E).withOpacity(0.12)
                    : Colors.white.withOpacity(0.85),
                shape: BoxShape.circle,
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.12),
                    blurRadius: 6,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: Icon(
                isWished ? Icons.favorite_rounded : Icons.favorite_border_rounded,
                size: widget.size,
                color: isWished ? const Color(0xFFFF4B6E) : kInkSoft,
              ),
            ),
          ),
        );
      },
    );
  }
}

// ─────────────────────────────────────────────────────────────
// TravelVibeBrandLogo — Reusable Brand Logo matching design image
// Red squircle compass icon + Orange "Travel" + Violet Italic "Vibe"
// ─────────────────────────────────────────────────────────────

class TravelVibeBrandLogo extends StatelessWidget {
  final double iconSize;
  final double fontSize;
  final bool showBadge;

  const TravelVibeBrandLogo({
    super.key,
    this.iconSize = 38,
    this.fontSize = 24,
    this.showBadge = true,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        if (showBadge) ...[
          Container(
            width: iconSize,
            height: iconSize,
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [Color(0xFFFF7300), Color(0xFF8B5CF6)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(iconSize * 0.28),
              boxShadow: const [
                BoxShadow(
                  color: Color(0x408B5CF6),
                  blurRadius: 8,
                  offset: Offset(0, 3),
                ),
              ],
            ),
            child: Center(
              child: Container(
                width: iconSize * 0.60,
                height: iconSize * 0.60,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  border: Border.all(color: Colors.white, width: iconSize * 0.05),
                ),
                child: Center(
                  child: Transform.rotate(
                    angle: -0.6,
                    child: Icon(
                      Icons.navigation_rounded,
                      color: Colors.white,
                      size: iconSize * 0.36,
                    ),
                  ),
                ),
              ),
            ),
          ),
          SizedBox(width: iconSize * 0.26),
        ],
        RichText(
          text: TextSpan(
            children: [
              TextSpan(
                text: 'Travel',
                style: GoogleFonts.plusJakartaSans(
                  fontSize: fontSize,
                  fontWeight: FontWeight.w900,
                  color: const Color(0xFFFF7300),
                  letterSpacing: -0.5,
                  height: 1,
                ),
              ),
              TextSpan(
                text: 'Vibe',
                style: GoogleFonts.plusJakartaSans(
                  fontSize: fontSize,
                  fontWeight: FontWeight.w900,
                  fontStyle: FontStyle.italic,
                  color: const Color(0xFF8B5CF6),
                  letterSpacing: -0.5,
                  height: 1,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

