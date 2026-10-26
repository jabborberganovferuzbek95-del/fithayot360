/// API manzili. Emulyator uchun standart 10.0.2.2 (host kompyuter localhost'i).
/// Haqiqiy qurilmada:  flutter run --dart-define=API_BASE_URL=http://192.168.x.x:8000
/// Productionda faqat HTTPS (NFR-05).
const String kApiBaseUrl = String.fromEnvironment('API_BASE_URL', defaultValue: 'https://fithayot360-api.onrender.com');
