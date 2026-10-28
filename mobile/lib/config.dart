/// API manzili. Emulyator uchun standart 10.0.2.2 (host kompyuter localhost'i).
/// Haqiqiy qurilmada:  flutter run --dart-define=API_BASE_URL=http://192.168.x.x:8000
/// Productionda faqat HTTPS (NFR-05).
const String kApiBaseUrl = String.fromEnvironment('API_BASE_URL', defaultValue: 'https://fithayot360-api.onrender.com');

/// Serverdagi statik media (fon rasmlari, mashq GIF'lari). To'liq URL bo'lsa o'zgartirilmaydi.
String mediaUrl(String path) {
  if (path.startsWith('http')) return path;
  final base = kApiBaseUrl.endsWith('/') ? kApiBaseUrl.substring(0, kApiBaseUrl.length - 1) : kApiBaseUrl;
  return '$base/${path.startsWith('/') ? path.substring(1) : path}';
}
