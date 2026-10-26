import 'dart:async';
import 'dart:math';

import 'package:flutter/material.dart';

import 'api_client.dart';

// ---------- Mavzu ----------
const kGreen = Color(0xFF16803C);
const kGreenDark = Color(0xFF0B3D20);
const kMint = Color(0xFF6EE787);

ThemeData buildTheme([Brightness b = Brightness.light]) => ThemeData(
      useMaterial3: true,
      colorScheme: ColorScheme.fromSeed(seedColor: kGreen, brightness: b),
      scaffoldBackgroundColor: b == Brightness.dark ? const Color(0xFF0F1512) : const Color(0xFFF5F7F5),
      filledButtonTheme: FilledButtonThemeData(style: FilledButton.styleFrom(minimumSize: const Size.fromHeight(52))),
      outlinedButtonTheme: OutlinedButtonThemeData(style: OutlinedButton.styleFrom(minimumSize: const Size.fromHeight(52))),
    );

Color moduleColor(String m) => switch (m) { 'home' => Colors.indigo, 'gym' => Colors.deepOrange, _ => Colors.teal };
IconData moduleIcon(String m) => switch (m) { 'home' => Icons.home_rounded, 'gym' => Icons.fitness_center, _ => Icons.directions_walk };

// ---------- Sana/vaqt ----------
const weekdays = ["Dushanba", "Seshanba", "Chorshanba", "Payshanba", "Juma", "Shanba", "Yakshanba"];
const weekdaysShort = ["Du", "Se", "Ch", "Pa", "Ju", "Sh", "Ya"];
String two(int n) => n.toString().padLeft(2, '0');
String fmtDate(DateTime d) => '${two(d.day)}.${two(d.month)}.${d.year}';
String fmtTime(DateTime d) => '${two(d.hour)}:${two(d.minute)}';
String isoDate(DateTime d) => '${d.year}-${two(d.month)}-${two(d.day)}';
DateTime dateOnly(DateTime d) => DateTime(d.year, d.month, d.day);
DateTime mondayOf(DateTime d) => dateOnly(d).subtract(Duration(days: d.weekday - 1));
bool sameDay(DateTime a, DateTime b) => a.year == b.year && a.month == b.month && a.day == b.day;
String fmtMinutes(int m) => m < 60 ? '$m daq' : '${m ~/ 60} s ${two(m % 60)} daq';

String newKey() {
  final r = Random.secure();
  return List.generate(24, (_) => r.nextInt(16).toRadixString(16)).join();
}

String errMsg(Object e) => e is ApiException ? e.message : "Kutilmagan xatolik yuz berdi";

void toast(BuildContext c, String m) =>
    ScaffoldMessenger.of(c)..hideCurrentSnackBar()..showSnackBar(SnackBar(content: Text(m)));

Future<bool> confirm(BuildContext c, String title, String body, {String ok = "Ha"}) async =>
    (await showDialog<bool>(
      context: c,
      builder: (_) => AlertDialog(
        title: Text(title),
        content: Text(body),
        actions: [
          TextButton(onPressed: () => Navigator.pop(c, false), child: const Text("Bekor qilish")),
          FilledButton(
              style: FilledButton.styleFrom(minimumSize: const Size(80, 40)),
              onPressed: () => Navigator.pop(c, true),
              child: Text(ok)),
        ],
      ),
    )) ??
    false;

// ---------- Umumiy vidjetlar ----------
class ErrorView extends StatelessWidget {
  const ErrorView(this.message, {super.key, this.onRetry});
  final String message;
  final VoidCallback? onRetry;
  @override
  Widget build(BuildContext context) => Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            const Icon(Icons.cloud_off, size: 48),
            const SizedBox(height: 12),
            Text(message, textAlign: TextAlign.center),
            if (onRetry != null) ...[
              const SizedBox(height: 16),
              OutlinedButton(style: OutlinedButton.styleFrom(minimumSize: const Size(160, 44)), onPressed: onRetry, child: const Text("Qayta urinish")),
            ],
          ]),
        ),
      );
}

/// Future yuklaydi, yuklanish/xato/tayyor holatlarini ko'rsatadi va pull-to-refresh uchun reload beradi.
class Loader<T> extends StatefulWidget {
  const Loader({super.key, required this.load, required this.builder});
  final Future<T> Function() load;
  final Widget Function(BuildContext context, T data, Future<void> Function() reload) builder;
  @override
  State<Loader<T>> createState() => _LoaderState<T>();
}

class _LoaderState<T> extends State<Loader<T>> {
  late Future<T> _f = widget.load();

  Future<void> _reload() {
    final f = widget.load();
    setState(() => _f = f);
    return f.then((_) {}, onError: (_) {});
  }

  @override
  Widget build(BuildContext context) => FutureBuilder<T>(
        future: _f,
        builder: (c, snap) {
          if (snap.hasData) return widget.builder(c, snap.data as T, _reload);
          if (snap.hasError) return ErrorView(errMsg(snap.error!), onRetry: _reload);
          return const Center(child: CircularProgressIndicator());
        },
      );
}

class SafetyBanner extends StatelessWidget {
  const SafetyBanner({super.key, this.text});
  final String? text;
  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(color: Colors.amber.shade50, borderRadius: BorderRadius.circular(12), border: Border.all(color: Colors.amber.shade300)),
        child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Icon(Icons.health_and_safety_outlined, color: Colors.amber.shade800),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              text ??
                  "FitHayot 360 tibbiy maslahat bermaydi. Og'riq, bosh aylanishi yoki nafas qisilishi sezsangiz mashqni to'xtating. "
                      "Jarohat, surunkali kasallik yoki homiladorlik bo'lsa, boshlashdan oldin shifokor yoki malakali mutaxassis bilan maslahatlashing.",
              style: const TextStyle(fontSize: 12.5, color: Colors.black87),
            ),
          ),
        ]),
      );
}

class StatTile extends StatelessWidget {
  const StatTile(this.label, this.value, {super.key, this.icon, this.color});
  final String label, value;
  final IconData? icon;
  final Color? color;
  @override
  Widget build(BuildContext context) => Expanded(
        child: Card(
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 8),
            child: Column(children: [
              if (icon != null) Icon(icon, color: color ?? Theme.of(context).colorScheme.primary),
              const SizedBox(height: 4),
              Text(value, style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold)),
              Text(label, textAlign: TextAlign.center, style: const TextStyle(fontSize: 12)),
            ]),
          ),
        ),
      );
}

class ModuleBadge extends StatelessWidget {
  const ModuleBadge(this.module, {super.key});
  final String module;
  @override
  Widget build(BuildContext context) => CircleAvatar(
        backgroundColor: moduleColor(module).withAlpha(38),
        child: Icon(moduleIcon(module), color: moduleColor(module)),
      );
}

class Elapsed extends StatefulWidget {
  const Elapsed(this.start, {super.key});
  final DateTime start;
  @override
  State<Elapsed> createState() => _ElapsedState();
}

class _ElapsedState extends State<Elapsed> {
  Timer? _t;
  @override
  void initState() {
    super.initState();
    _t = Timer.periodic(const Duration(seconds: 1), (_) => mounted ? setState(() {}) : null);
  }

  @override
  void dispose() {
    _t?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final d = DateTime.now().difference(widget.start);
    final s = d.isNegative ? 0 : d.inSeconds;
    return Text('${two(s ~/ 3600)}:${two(s % 3600 ~/ 60)}:${two(s % 60)}', style: const TextStyle(fontFeatures: [FontFeature.tabularFigures()]));
  }
}


// ---------- Yangi dizayn komponentlari ----------
String fmtInt(int n) => n.toString().replaceAllMapped(RegExp(r'\B(?=(\d{3})+(?!\d))'), (m) => ' ');
String fmtSleep(int min) => '${min ~/ 60} s ${two(min % 60)} d';
String fmtL(int ml) {
  final v = ml / 1000;
  return v == v.roundToDouble() ? v.toStringAsFixed(0) : v.toString();
}

extension ApiJson on ApiClient {
  Future<Map<String, dynamic>> getMap(String path, {Map<String, dynamic>? query}) async =>
      Map<String, dynamic>.from(await get(path, query: query));
  Future<List<Map<String, dynamic>>> getList(String path, {Map<String, dynamic>? query}) async =>
      ((await get(path, query: query)) as List).map((e) => Map<String, dynamic>.from(e)).toList();
}

class AppCard extends StatelessWidget {
  const AppCard({super.key, required this.child, this.padding = const EdgeInsets.all(16), this.color, this.onTap});
  final Widget child;
  final EdgeInsets padding;
  final Color? color;
  final VoidCallback? onTap;
  @override
  Widget build(BuildContext context) => Container(
        margin: const EdgeInsets.only(bottom: 12),
        decoration: BoxDecoration(
          color: color ?? cardBg(context),
          borderRadius: BorderRadius.circular(18),
          boxShadow: const [BoxShadow(color: Color(0x12000000), blurRadius: 10, offset: Offset(0, 3))],
        ),
        child: Material(
          color: Colors.transparent,
          child: InkWell(borderRadius: BorderRadius.circular(18), onTap: onTap, child: Padding(padding: padding, child: child)),
        ),
      );
}

class RingProgress extends StatelessWidget {
  const RingProgress({super.key, required this.value, this.size = 120, this.stroke = 10, this.color = Colors.white, this.trackColor = const Color(0x33FFFFFF), this.child});
  final double value, size, stroke;
  final Color color, trackColor;
  final Widget? child;
  @override
  Widget build(BuildContext context) => SizedBox(
        width: size,
        height: size,
        child: CustomPaint(painter: _RingPainter(value.clamp(0.0, 1.0).toDouble(), stroke, color, trackColor), child: Center(child: child)),
      );
}

class _RingPainter extends CustomPainter {
  _RingPainter(this.value, this.stroke, this.color, this.track);
  final double value, stroke;
  final Color color, track;
  @override
  void paint(Canvas canvas, Size size) {
    final r = Rect.fromLTWH(stroke / 2, stroke / 2, size.width - stroke, size.height - stroke);
    canvas.drawArc(r, 0, 2 * pi, false, Paint()..style = PaintingStyle.stroke..strokeWidth = stroke..color = track);
    if (value > 0) {
      canvas.drawArc(r, -pi / 2, 2 * pi * value, false,
          Paint()..style = PaintingStyle.stroke..strokeWidth = stroke..strokeCap = StrokeCap.round..color = color);
    }
  }

  @override
  bool shouldRepaint(_RingPainter o) => o.value != value || o.color != color || o.stroke != stroke;
}

class MiniBars extends StatelessWidget {
  const MiniBars({super.key, required this.values, required this.color, this.height = 52});
  final List<double> values;
  final Color color;
  final double height;
  @override
  Widget build(BuildContext context) {
    final mx = values.fold<double>(0, (a, b) => b > a ? b : a);
    return SizedBox(
      height: height,
      child: Row(crossAxisAlignment: CrossAxisAlignment.end, children: [
        for (final v in values)
          Expanded(
            child: Padding(
              padding: EdgeInsets.symmetric(horizontal: values.length > 12 ? 0.5 : 2),
              child: Container(
                height: mx == 0 ? 3 : (height - 3) * v / mx + 3,
                decoration: BoxDecoration(color: v == 0 ? color.withAlpha(64) : color, borderRadius: BorderRadius.circular(2)),
              ),
            ),
          ),
      ]),
    );
  }
}

const mealTypeLabels = {'breakfast': "Nonushta", 'lunch': "Tushlik", 'dinner': "Kechki ovqat", 'snack': "Snek", 'detox': "Detoks"};
IconData mealIcon(String t) => switch (t) {
      'breakfast' => Icons.free_breakfast,
      'lunch' => Icons.lunch_dining,
      'dinner' => Icons.dinner_dining,
      'snack' => Icons.cookie,
      _ => Icons.eco,
    };
Color mealColor(String t) => switch (t) {
      'breakfast' => Colors.orange,
      'lunch' => Colors.green,
      'dinner' => Colors.deepPurple,
      'snack' => Colors.pink,
      _ => Colors.teal,
    };


Color cardBg(BuildContext c) => Theme.of(c).brightness == Brightness.dark ? const Color(0xFF1B2420) : Colors.white;

IconData goalIcon(String g) => switch (g) {
      'weight_loss' => Icons.monitor_weight_outlined,
      'muscle_gain' => Icons.fitness_center,
      'stay_fit' => Icons.straighten,
      'healthy_lifestyle' => Icons.spa,
      'reduce_stress' => Icons.self_improvement,
      'more_energy' => Icons.bolt,
      _ => Icons.flag_outlined,
    };

/// Gradient (va ixtiyoriy rasm URL) fonli karta sarlavhasi
class HeroBox extends StatelessWidget {
  const HeroBox({super.key, required this.color, required this.icon, this.imageUrl, this.height = 130, this.child, this.radius = 20});
  final Color color;
  final IconData icon;
  final String? imageUrl;
  final double height, radius;
  final Widget? child;
  @override
  Widget build(BuildContext context) => ClipRRect(
        borderRadius: BorderRadius.circular(radius),
        child: SizedBox(
          height: height,
          width: double.infinity,
          child: Stack(fit: StackFit.expand, children: [
            Container(decoration: BoxDecoration(gradient: LinearGradient(colors: [color.withAlpha(191), color], begin: Alignment.topLeft, end: Alignment.bottomRight))),
            Positioned(right: -10, top: -10, child: Icon(icon, size: height * 0.9, color: Colors.white.withAlpha(46))),
            if (imageUrl != null && imageUrl!.isNotEmpty) Image.network(imageUrl!, fit: BoxFit.cover, errorBuilder: (_, __, ___) => const SizedBox.shrink()),
            const DecoratedBox(decoration: BoxDecoration(gradient: LinearGradient(colors: [Colors.transparent, Color(0xAA000000)], begin: Alignment.topCenter, end: Alignment.bottomCenter))),
            if (child != null) Padding(padding: const EdgeInsets.all(14), child: Align(alignment: Alignment.bottomLeft, child: child)),
          ]),
        ),
      );
}
