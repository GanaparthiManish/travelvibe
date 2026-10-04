import React, { createContext, useContext, useState, useEffect } from 'react';
import { supabase } from '../supabaseClient';

export const SUPPORTED_LANGUAGES = [
  { code: 'en', label: 'English', native: 'English' },
  { code: 'hi', label: 'Hindi', native: 'हिन्दी' },
  { code: 'ml', label: 'Malayalam', native: 'മലയാളം' },
  { code: 'ta', label: 'Tamil', native: 'தமிழ்' },
  { code: 'te', label: 'Telugu', native: 'తెలుగు' },
];

const TRANSLATIONS = {
  en: {
    // Navigation
    nav_home: 'Explore',
    nav_guides: 'Guides',
    nav_shop: 'Gear Shop',
    nav_wishlist: 'Saved',
    nav_trips: 'My Trips',
    nav_login: 'Log in',
    nav_signup: 'Sign up',
    nav_logout: 'Sign Out',
    nav_account: 'Account Settings',
    nav_console: 'Agent Console',
    nav_partner: 'Become a Guide Host',

    // Hero & Home
    hero_tag: 'Verified Local Guides Across India',
    hero_title: 'Experience India With Real Local Insiders',
    hero_subtitle: 'Hand-picked local experts who know every hidden trail, local food spot, and culture secret.',
    search_placeholder: 'Where do you want to go? (e.g. Munnar, Goa, Leh...)',
    search_btn: 'Search Guides',
    explore_categories: 'Explore by Category',
    top_guides: 'Top Rated Local Guides',
    view_all_guides: 'View All Verified Guides',
    rate_per_day: 'Rate per day',
    verified_guide: 'Verified Guide',
    check_availability: 'Check Availability',
    years_exp: 'yrs exp',

    // Agent Listing
    listing_title: 'Browse Local Travel Guides',
    listing_subtitle: 'Connect directly with experienced local experts across top destinations in India.',
    all_rates: 'All Daily Rates',
    low_rate: 'Under ₹1,500/day',
    mid_rate: '₹1,500 – ₹3,000/day',
    high_rate: 'Above ₹3,000/day',
    all_specializations: 'All Specializations',
    view_profile: 'View Profile',
    no_guides: 'No verified local guides match your search',

    // Agent Profile
    about_guide: 'About Guide',
    places_covered: 'Places Covered',
    languages_spoken: 'Languages Spoken',
    service_inclusions: 'Service Inclusions',
    specialization_tags: 'Guide Specialization Tags',
    book_now: 'Book Guide Now',
    reviews_title: 'Traveller Reviews',
    view_stories: 'Stories',

    // Booking Flow
    secure_booking: 'Secure Booking & Group Checkout',
    destination_circuit: 'Destination Circuit',
    num_travellers: 'Number of Travellers',
    trip_start_date: 'Trip Start Date',
    trip_end_date: 'Trip End Date',
    additional_guests: 'Additional Group Members',
    preferred_meeting_point: 'Preferred Meeting Point',
    trip_notes: 'Special Requests or Custom Itinerary Notes',
    optional_addons: 'Optional Trip Add-ons',
    apply_loyalty_reward: 'Apply Available Loyalty Reward',
    pricing_breakdown: 'Pricing Breakdown',
    base_guide_fee: 'Base Guide Fee',
    group_size_label: 'Group Size',
    addons_total: 'Add-ons Total',
    loyalty_reward_discount: 'Loyalty Reward Discount',
    estimated_total: 'Estimated Total',
    send_booking_request: 'Send Booking Request',

    // Profile & Settings
    account_settings_title: 'Account Settings',
    your_referral_code: 'Your Referral Code',
    share_code: 'Share Code',
    copy_code: 'Copy',
    copied: 'Copied!',
    my_loyalty_rewards: 'My Loyalty Rewards',
    full_name_label: 'Full Name',
    phone_label: 'Phone Number',
    emergency_contact: 'Emergency Contact',
    delivery_address: 'Home / Delivery Address',
    save_changes: 'Save Profile Changes',
    language_preference: 'Language Preference',
  },

  hi: {
    // Navigation
    nav_home: 'खोजें',
    nav_guides: 'स्थानीय गाइड',
    nav_shop: 'गियर शॉप',
    nav_wishlist: 'सहेजे गए',
    nav_trips: 'मेरी यात्राएं',
    nav_login: 'लॉग इन करें',
    nav_signup: 'साइन अप करें',
    nav_logout: 'साइन आउट',
    nav_account: 'खाता सेटिंग्स',
    nav_console: 'गाइड कंसोल',
    nav_partner: 'गाइड पार्टनर बनें',

    // Hero & Home
    hero_tag: 'भारत भर में सत्यापित स्थानीय गाइड',
    hero_title: 'असली स्थानीय गाइडों के साथ भारत घूमें',
    hero_subtitle: 'अनुभवी स्थानीय विशेषज्ञ जो हर छिपे हुए रास्ते, स्थानीय खान-पान और संस्कृति को जानते हैं।',
    search_placeholder: 'आप कहाँ जाना चाहते हैं? (उदा. मुन्नार, गोवा, लद्दाख...)',
    search_btn: 'गाइड खोजें',
    explore_categories: 'श्रेणी के अनुसार खोजें',
    top_guides: 'शीर्ष रेटेड स्थानीय गाइड',
    view_all_guides: 'सभी सत्यापित गाइड देखें',
    rate_per_day: 'प्रति दिन दर',
    verified_guide: 'सत्यापित गाइड',
    check_availability: 'उपलब्धता जांचें',
    years_exp: 'वर्ष का अनुभव',

    // Agent Listing
    listing_title: 'स्थानीय यात्रा गाइड खोजें',
    listing_subtitle: 'भारत के प्रमुख पर्यटन स्थलों पर अनुभवी स्थानीय विशेषज्ञों से सीधे जुड़ें।',
    all_rates: 'सभी दैनिक दरें',
    low_rate: '₹1,500/दिन से कम',
    mid_rate: '₹1,500 – ₹3,000/दिन',
    high_rate: '₹3,000/दिन से अधिक',
    all_specializations: 'सभी विशेषताएं',
    view_profile: 'प्रोफाइल देखें',
    no_guides: 'आपकी खोज से मेल खाने वाला कोई गाइड नहीं मिला',

    // Agent Profile
    about_guide: 'गाइड के बारे में',
    places_covered: 'कवर किए गए स्थान',
    languages_spoken: 'बोली जाने वाली भाषाएं',
    service_inclusions: 'शामिल सेवाएं',
    specialization_tags: 'गाइड विशेषज्ञता टैग',
    book_now: 'गाइड अभी बुक करें',
    reviews_title: 'यात्री समीक्षाएं',
    view_stories: 'स्टोरीज़',

    // Booking Flow
    secure_booking: 'सुरक्षित बुकिंग और ग्रुप चेकआउट',
    destination_circuit: 'गंतव्य स्थल',
    num_travellers: 'यात्रियों की संख्या',
    trip_start_date: 'यात्रा शुरू होने की तारीख',
    trip_end_date: 'यात्रा समाप्ति की तारीख',
    additional_guests: 'समूह के अन्य सदस्य',
    preferred_meeting_point: 'मिलने का पसंदीदा स्थान',
    trip_notes: 'विशेष अनुरोध या यात्रा नोट्स',
    optional_addons: 'वैकल्पिक अतिरिक्त सेवाएं',
    apply_loyalty_reward: 'उपलब्ध लॉयल्टी इनाम लागू करें',
    pricing_breakdown: 'मूल्य विवरण',
    base_guide_fee: 'गाइड शुल्क',
    group_size_label: 'समूह का आकार',
    addons_total: 'अतिरिक्त सेवाओं का कुल',
    loyalty_reward_discount: 'लॉयल्टी इनाम छूट',
    estimated_total: 'अनुमानित कुल',
    send_booking_request: 'बुकिंग अनुरोध भेजें',

    // Profile & Settings
    account_settings_title: 'खाता सेटिंग्स',
    your_referral_code: 'आपका रेफ़रल कोड',
    share_code: 'कोड साझा करें',
    copy_code: 'कॉपी करें',
    copied: 'कॉपी हो गया!',
    my_loyalty_rewards: 'मेरे लॉयल्टी पुरस्कार',
    full_name_label: 'पूरा नाम',
    phone_label: 'फ़ोन नंबर',
    emergency_contact: 'आपातकालीन संपर्क',
    delivery_address: 'घर का पता',
    save_changes: 'परिवर्तन सहेजें',
    language_preference: 'भाषा प्राथमिकता',
  },

  ml: {
    // Navigation
    nav_home: 'എക്സ്പ്ലോർ',
    nav_guides: 'ഗൈഡുകൾ',
    nav_shop: 'ഗിയർ ഷോപ്പ്',
    nav_wishlist: 'സേവ് ചെയ്തവ',
    nav_trips: 'എന്റെ യാത്രകൾ',
    nav_login: 'ലോഗിൻ',
    nav_signup: 'സൈൻ അപ്പ്',
    nav_logout: 'സൈൻ ഔട്ട്',
    nav_account: 'അക്കൗണ്ട് സെറ്റിംഗ്സ്',
    nav_console: 'ഗൈഡ് കൺസോൾ',
    nav_partner: 'ഗൈഡ് പങ്കാളിയാകൂ',

    // Hero & Home
    hero_tag: 'കേരളത്തിലും ഇന്ത്യയിലുമുള്ള അംഗീകൃത പ്രാദേശിക ഗൈഡുകൾ',
    hero_title: 'യഥാർത്ഥ പ്രാദേശിക ഗൈഡുകൾക്കൊപ്പം യാത്ര ചെയ്യാം',
    hero_subtitle: 'നാടൻ കാഴ്ചകളും ഭക്ഷണവും സംസ്കാരവും അടുത്തറിയാൻ വിശ്വസ്തരായ പ്രാദേശിക ഗൈഡുകൾ.',
    search_placeholder: 'എങ്ങോട്ടാണ് യാത്ര? (ഉദാ. മൂന്നാർ, ഗോവ, ലഡാക്ക്...)',
    search_btn: 'ഗൈഡുകളെ തിരയുക',
    explore_categories: 'വിഭാഗം തിരിച്ച് കാണുക',
    top_guides: 'മികച്ച റേറ്റിംഗുള്ള ഗൈഡുകൾ',
    view_all_guides: 'എല്ലാ ഗൈഡുകളെയും കാണുക',
    rate_per_day: 'പ്രതിദിന നിരക്ക്',
    verified_guide: 'വെരിഫൈഡ് ഗൈഡ്',
    check_availability: 'ലഭ്യത പരിശോധിക്കുക',
    years_exp: 'വർഷത്തെ പരിചയം',

    // Agent Listing
    listing_title: 'പ്രാദേശിക ടൂർ ഗൈഡുകളെ കണ്ടെത്തുക',
    listing_subtitle: 'മികച്ച യാത്രാ കേന്ദ്രങ്ങളിലെ പരിചയസമ്പന്നരായ ഗൈഡുകളുമായി നേരിട്ട് ബന്ധപ്പെടാം.',
    all_rates: 'എല്ലാ നിരക്കുകളും',
    low_rate: '₹1,500/ദിനത്തിൽ താഴെ',
    mid_rate: '₹1,500 – ₹3,000/ദിനം',
    high_rate: '₹3,000/ദിനത്തിൽ കൂടുതൽ',
    all_specializations: 'എല്ലാ പ്രത്യേകതകളും',
    view_profile: 'പ്രൊഫൈൽ കാണുക',
    no_guides: 'തിരച്ചിലിന് അനുയോജ്യമായ ഗൈഡുകൾ ലഭ്യമല്ല',

    // Agent Profile
    about_guide: 'ഗൈഡിനെക്കുറിച്ച്',
    places_covered: 'യാത്രാ സ്ഥലങ്ങൾ',
    languages_spoken: 'സംസാരിക്കുന്ന ഭാഷകൾ',
    service_inclusions: 'ലഭ്യമാകുന്ന സൗകര്യങ്ങൾ',
    specialization_tags: 'പ്രത്യേക വൈദഗ്ധ്യങ്ങൾ',
    book_now: 'ഗൈഡിനെ ബുക്ക് ചെയ്യുക',
    reviews_title: 'സഞ്ചാരികളുടെ അഭിപ്രായങ്ങൾ',
    view_stories: 'സ്റ്റോറികൾ',

    // Booking Flow
    secure_booking: 'സുരക്ഷിത ബുക്കിംഗും ഗ്രൂപ്പ് ചെക്ക്ഔട്ടും',
    destination_circuit: 'യാത്രാ കേന്ദ്രം',
    num_travellers: 'സഞ്ചാരികളുടെ എണ്ണം',
    trip_start_date: 'ആരംഭിക്കുന്ന തീയതി',
    trip_end_date: 'അവസാനിക്കുന്ന തീയതി',
    additional_guests: 'കൂടെയുള്ള മറ്റ് സഞ്ചാരികൾ',
    preferred_meeting_point: 'കണ്ടുമുട്ടേണ്ട സ്ഥലം',
    trip_notes: 'പ്രത്യേക നിർദ്ദേശങ്ങൾ / കുറിപ്പുകൾ',
    optional_addons: 'അധിക സേവനങ്ങൾ',
    apply_loyalty_reward: 'ലോയൽറ്റി റിവാർഡ് ഉപയോഗിക്കുക',
    pricing_breakdown: 'തുകയുടെ വിശദാംശങ്ങൾ',
    base_guide_fee: 'ഗൈഡ് ഫീസ്',
    group_size_label: 'ഗ്രൂപ്പ് വലുപ്പം',
    addons_total: 'അധിക സേവനങ്ങളുടെ തുക',
    loyalty_reward_discount: 'ലോയൽറ്റി കിഴിവ്',
    estimated_total: 'ആകെ തുക',
    send_booking_request: 'ബുക്കിംഗ് റിക്വസ്റ്റ് അയക്കുക',

    // Profile & Settings
    account_settings_title: 'അക്കൗണ്ട് സെറ്റിംഗ്സ്',
    your_referral_code: 'നിങ്ങളുടെ റഫറൽ കോഡ്',
    share_code: 'കോഡ് ഷെയർ ചെയ്യുക',
    copy_code: 'കോപ്പി ചെയ്യുക',
    copied: 'കോപ്പി ചെയ്തു!',
    my_loyalty_rewards: 'എന്റെ ലോയൽറ്റി റിവാർഡുകൾ',
    full_name_label: 'പൂർണ്ണ നാമം',
    phone_label: 'ഫോൺ നമ്പർ',
    emergency_contact: 'അടിയന്തര ഫോൺ നമ്പർ',
    delivery_address: 'വിലാസം',
    save_changes: 'മാറ്റങ്ങൾ സൂക്ഷിക്കുക',
    language_preference: 'ഭാഷ തിരഞ്ഞെടുക്കുക',
  },

  ta: {
    // Navigation
    nav_home: 'ஆராயுங்கள்',
    nav_guides: 'வழிகாட்டிகள்',
    nav_shop: 'கியர் கடை',
    nav_wishlist: 'விருப்பப்பட்டியல்',
    nav_trips: 'என் பயணங்கள்',
    nav_login: 'உள்நுழைக',
    nav_signup: 'பதிவு செய்க',
    nav_logout: 'வெளியேறு',
    nav_account: 'கணக்கு அமைப்புகள்',
    nav_console: 'வழிகாட்டி கன்சோல்',
    nav_partner: 'வழிகாட்டி பார்ட்னராகுங்கள்',

    // Hero & Home
    hero_tag: 'இந்தியா முழுவதும் சரிபார்க்கப்பட்ட வழிகாட்டிகள்',
    hero_title: 'உள்ளூர் வழிகாட்டிகளுடன் இந்தியாவை அனுபவியுங்கள்',
    hero_subtitle: 'மறைக்கப்பட்ட இடங்கள், உணவு மற்றும் பண்பாட்டை அறிந்த உள்ளூர் நிபுணர்கள்.',
    search_placeholder: 'நீங்கள் எங்கு செல்ல விரும்புகிறீர்கள்? (முன்னார், கோவா, லடாக்...)',
    search_btn: 'வழிகாட்டிகளைத் தேடுங்கள்',
    explore_categories: 'பிரிவுகளின்படி ஆராயுங்கள்',
    top_guides: 'சிறந்த வழிகாட்டிகள்',
    view_all_guides: 'அனைத்து வழிகாட்டிகளையும் காண்க',
    rate_per_day: 'நாள் ஒன்றுக்கு கட்டணம்',
    verified_guide: 'சரிபார்க்கப்பட்ட வழிகாட்டி',
    check_availability: 'இருப்பு சோதிக்கவும்',
    years_exp: 'வருட அனுபவம்',

    // Agent Listing
    listing_title: 'உள்ளூர் வழிகாட்டிகளைத் தேடுங்கள்',
    listing_subtitle: 'சிறந்த சுற்றுலா தளங்களில் உள்ள அனுபவம் வாய்ந்த வழிகாட்டிகளுடன் இணையுங்கள்.',
    all_rates: 'அனைத்து கட்டணங்களும்',
    low_rate: '₹1,500/நாளுக்கு கீழ்',
    mid_rate: '₹1,500 – ₹3,000/நாள்',
    high_rate: '₹3,000/நாளுக்கு மேல்',
    all_specializations: 'அனைத்து சிறப்புகள்',
    view_profile: 'சுயவிவரம் காண்க',
    no_guides: 'வழிகாட்டிகள் கிடைக்கவில்லை',

    // Agent Profile
    about_guide: 'வழிகாட்டி பற்றி',
    places_covered: 'சுற்றிப்பார்க்கும் இடங்கள்',
    languages_spoken: 'பேசும் மொழிகள்',
    service_inclusions: 'சேவை விவரங்கள்',
    specialization_tags: 'சிறப்பு குறிச்சொற்கள்',
    book_now: 'இப்போதே பதிவு செய்க',
    reviews_title: 'பயணிகள் விமர்சனங்கள்',
    view_stories: 'ஸ்டோரீஸ்',

    // Booking Flow
    secure_booking: 'பாதுகாப்பான முன்பதிவு',
    destination_circuit: 'பயண இடம்',
    num_travellers: 'பயணிகள் எண்ணிக்கை',
    trip_start_date: 'பயணம் தொடங்கும் தேதி',
    trip_end_date: 'பயணம் முடியும் தேதி',
    additional_guests: 'கூடுதல் பயணிகள் விவரம்',
    preferred_meeting_point: 'சந்திக்கும் இடம்',
    trip_notes: 'சிறப்பு கோரிக்கைகள்',
    optional_addons: 'கூடுதல் சேவைகள்',
    apply_loyalty_reward: 'லாயல்டி தள்ளுபடியைப் பயன்படுத்துங்கள்',
    pricing_breakdown: 'கட்டண விவரம்',
    base_guide_fee: 'வழிகாட்டி கட்டணம்',
    group_size_label: 'குழு அளவு',
    addons_total: 'கூடுதல் சேவைகள் மொத்தம்',
    loyalty_reward_discount: 'லாயல்டி தள்ளுபடி',
    estimated_total: 'மொத்த கட்டணம்',
    send_booking_request: 'முன்பதிவு கோரிக்கை அனுப்பு',

    // Profile & Settings
    account_settings_title: 'கணக்கு அமைப்புகள்',
    your_referral_code: 'உங்கள் பரிந்துரை குறியீடு',
    share_code: 'பகிர்',
    copy_code: 'நகலெடு',
    copied: 'நகலெடுக்கப்பட்டது!',
    my_loyalty_rewards: 'என் லாயல்டி வெகுமதிகள்',
    full_name_label: 'முழு பெயர்',
    phone_label: 'தொலைபேசி எண்',
    emergency_contact: 'அவசர தொடர்பு எண்',
    delivery_address: 'முகவரி',
    save_changes: 'மாற்றங்களைச் சேமி',
    language_preference: 'மொழி தேர்வு',
  },

  te: {
    // Navigation
    nav_home: 'అన్వేషించండి',
    nav_guides: 'గైడ్లు',
    nav_shop: 'గేర్ షాప్',
    nav_wishlist: 'సేవ్ చేసినవి',
    nav_trips: 'నా ట్రిప్పులు',
    nav_login: 'లాగిన్',
    nav_signup: 'సైన్ అప్',
    nav_logout: 'లాగ్ అవుట్',
    nav_account: 'ఖాతా సెట్టింగ్‌లు',
    nav_console: 'గైడ్ కన్సోల్',
    nav_partner: 'గైడ్ పార్టనర్ అవ్వండి',

    // Hero & Home
    hero_tag: 'భారతదేశం అంతటా ధృవీకరించబడిన స్థానిక గైడ్లు',
    hero_title: 'నిజమైన లోకల్ గైడ్లతో భారతదేశాన్ని అన్వేషించండి',
    hero_subtitle: 'స్థానిక రహస్య ప్రదేశాలు, సంస్కృతి మరియు రుచులను తెలిసిన అనుభవజ్ఞులైన గైడ్లు.',
    search_placeholder: 'మీరు ఎక్కడికి వెళ్లాలనుకుంటున్నారు? (ఉదా. మున్నార్, గోవా, లడఖ్...)',
    search_btn: 'గైడ్లను శోధించండి',
    explore_categories: 'కేటగిరీల వారీగా చూడండి',
    top_guides: 'అత్యుత్తమ రేటింగ్ పొందిన గైడ్లు',
    view_all_guides: 'అన్ని గైడ్లను చూడండి',
    rate_per_day: 'రోజువారీ రుసుము',
    verified_guide: 'ధృవీకరించబడిన గైడ్',
    check_availability: 'లభ్యతను తనిఖీ చేయండి',
    years_exp: 'సంవత్సరాల అనుభవం',

    // Agent Listing
    listing_title: 'స్థానిక గైడ్లను బ్రౌజ్ చేయండి',
    listing_subtitle: 'భారతదేశంలోని అగ్ర గమ్యస్థానాలలో అనుభవజ్ఞులైన నిపుణులను కనుగొనండి.',
    all_rates: 'అన్ని రేట్లు',
    low_rate: '₹1,500/రోజు కంటే తక్కువ',
    mid_rate: '₹1,500 – ₹3,000/రోజు',
    high_rate: '₹3,000/రోజు కంటే ఎక్కువ',
    all_specializations: 'అన్ని నైపుణ్యాలు',
    view_profile: 'ప్రొఫైల్ చూడండి',
    no_guides: 'గైడ్లు కనుగొనబడలేదు',

    // Agent Profile
    about_guide: 'గైడ్ గురించి',
    places_covered: 'కవర్ చేసే ప్రదేశాలు',
    languages_spoken: 'మాట్లాడే భాషలు',
    service_inclusions: 'అందించే సేవలు',
    specialization_tags: 'ప్రత్యేక నైపుణ్యాలు',
    book_now: 'ఇప్పుడే బుక్ చేసుకోండి',
    reviews_title: 'ప్రయాణికుల సమీక్షలు',
    view_stories: 'స్టోరీలు',

    // Booking Flow
    secure_booking: 'సురక్షిత బుకింగ్ & చెక్అవుట్',
    destination_circuit: 'గమ్యస్థానం',
    num_travellers: 'ప్రయాణికుల సంఖ్య',
    trip_start_date: 'ప్రయాణ ప్రారంభ తేదీ',
    trip_end_date: 'ప్రయాణ ముగింపు తేదీ',
    additional_guests: 'ఇతర ప్రయాణికుల వివరాలు',
    preferred_meeting_point: 'కలుసుకునే స్థలం',
    trip_notes: 'ప్రత్యేక అభ్యర్థనలు / నోట్స్',
    optional_addons: 'అదనపు సేవలు',
    apply_loyalty_reward: 'లాయల్టీ రివార్డ్‌ను వర్తింపజేయండి',
    pricing_breakdown: 'ధరల వివరాలు',
    base_guide_fee: 'గైడ్ రుసుము',
    group_size_label: 'గ్రూప్ పరిమాణం',
    addons_total: 'అదనపు సేవల మొత్తం',
    loyalty_reward_discount: 'లాయల్టీ తగ్గింపు',
    estimated_total: 'మొత్తం ధర',
    send_booking_request: 'బుకింగ్ రిక్వెస్ట్ పంపండి',

    // Profile & Settings
    account_settings_title: 'ఖాతా సెట్టింగ్‌లు',
    your_referral_code: 'మీ రెఫరల్ కోడ్',
    share_code: 'కోడ్ షేర్ చేయండి',
    copy_code: 'కాపీ చేయండి',
    copied: 'కాపీ చేయబడింది!',
    my_loyalty_rewards: 'నా లాయల్టీ రివార్డులు',
    full_name_label: 'పూర్తి పేరు',
    phone_label: 'ఫోన్ నంబర్',
    emergency_contact: 'అత్యవసర సంప్రదింపు సంఖ్య',
    delivery_address: 'చిరునామా',
    save_changes: 'మార్పులను భద్రపరచండి',
    language_preference: 'భాష ఎంపిక',
  },
};

const LanguageContext = createContext(null);

export function LanguageProvider({ children }) {
  const [language, setLanguageState] = useState(() => {
    return localStorage.getItem('travelvibe_language') || 'en';
  });

  const setLanguage = async (code) => {
    if (!TRANSLATIONS[code]) return;
    setLanguageState(code);
    localStorage.setItem('travelvibe_language', code);

    // Also persist to Supabase profile if user is logged in
    try {
      const { data: { user } } = await supabase.auth.getUser();
      if (user?.id) {
        await supabase
          .from('profiles')
          .update({ preferred_language: code })
          .eq('id', user.id);
      }
    } catch (_) {}
  };

  // Translation helper function
  const t = (key, fallback = '') => {
    const langDict = TRANSLATIONS[language] || TRANSLATIONS.en;
    return langDict[key] || TRANSLATIONS.en[key] || fallback || key;
  };

  return (
    <LanguageContext.Provider value={{ language, setLanguage, t, supportedLanguages: SUPPORTED_LANGUAGES }}>
      {children}
    </LanguageContext.Provider>
  );
}

export function useLanguage() {
  const ctx = useContext(LanguageContext);
  if (!ctx) {
    throw new Error('useLanguage must be used within a LanguageProvider');
  }
  return ctx;
}
