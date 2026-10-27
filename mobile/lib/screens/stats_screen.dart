import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../app_state.dart';
import '../ui.dart';
import 'results_screens.dart';

/// Statistika: Umumiy (qadam, kaloriya, faol vaqt, suv, uyqu) + Progress + Tarix
class StatsScreen extends StatelessWidget {
  const StatsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return DefaultTabController(
      length: 3,
      child: Scaffold(
        backgroundColor: Colors.transparent,
        appBar: AppBar(
          title: const Text(
            "Statistika",
            style: TextStyle(fontWeight: FontWeight.w800, fontSize: 20),
          ),
          elevation: 0,
          backgroundColor: isDark ? const Color(0xFF141C17).withAlpha(220) : Colors.white.withAlpha(220),
          bottom: TabBar(
            indicatorColor: kGreen,
            indicatorWeight: 3,
            labelColor: kGreen,
            unselectedLabelColor: isDark ? Colors.grey.shade400 : Colors.grey.shade600,
            labelStyle: const TextStyle(fontWeight: FontWeight.w700, fontSize: 14),
            unselectedLabelStyle: const TextStyle(fontWeight: FontWeight.w500, fontSize: 13.5),
            tabs: const [
              Tab(text: "Umumiy"),
              Tab(text: "Progress"),
              Tab(text: "Tarix"),
            ],
          ),
        ),
        body: const ScreenBackground(
          imageName: 'wellness_bg.jpg',
          child: TabBarView(
            children: [
              StatsOverview(),
              ProgressView(),
              HistoryView(),
            ],
          ),
        ),
      ),
    );
  }
}

double _avgNonZero(List<int> v) {
  final nz = v.where((x) => x > 0).toList();
  return nz.isEmpty ? 0 : nz.reduce((a, b) => a + b) / nz.length;
}

class StatsOverview extends StatefulWidget {
  const StatsOverview({super.key});
  @override
  State<StatsOverview> createState() => _StatsOverviewState();
}

class _StatsOverviewState extends State<StatsOverview> {
  int _days = 7;

  Widget _metricCard({
    required BuildContext context,
    required String title,
    required String big,
    required String sub,
    required List<double> series,
    required Color color,
    required IconData icon,
    required bool isDark,
  }) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: isDark ? const Color(0xFF161F1A) : Colors.white,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: isDark ? Colors.white10 : Colors.black.withAlpha(10),
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withAlpha(isDark ? 15 : 5),
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  title,
                  style: TextStyle(
                    fontSize: 12.5,
                    fontWeight: FontWeight.w600,
                    color: isDark ? Colors.grey.shade400 : Colors.grey.shade600,
                  ),
                ),
                Container(
                  padding: const EdgeInsets.all(6),
                  decoration: BoxDecoration(
                    color: color.withAlpha(isDark ? 40 : 25),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Icon(icon, color: color, size: 16),
                ),
              ],
            ),
            const SizedBox(height: 6),
            Text(
              big,
              style: TextStyle(
                fontSize: 19,
                fontWeight: FontWeight.w800,
                color: isDark ? Colors.white : Colors.black87,
                letterSpacing: -0.3,
              ),
            ),
            const SizedBox(height: 2),
            Text(
              sub,
              style: TextStyle(
                fontSize: 11,
                color: isDark ? Colors.grey.shade400 : Colors.grey.shade600,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
            const SizedBox(height: 12),
            MiniBars(values: series, color: color, height: 44),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Column(
      children: [
        // Davr tanlash selectori (7 kun, 30 kun, 1 yil)
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 6),
          child: Container(
            padding: const EdgeInsets.all(4),
            decoration: BoxDecoration(
              color: isDark ? const Color(0xFF161F1A) : Colors.black.withAlpha(8),
              borderRadius: BorderRadius.circular(16),
            ),
            child: Row(
              children: [
                (days: 7, label: "7 kun"),
                (days: 30, label: "30 kun"),
                (days: 365, label: "1 yil"),
              ].map((item) {
                final isSel = _days == item.days;
                return Expanded(
                  child: InkWell(
                    onTap: () => setState(() => _days = item.days),
                    borderRadius: BorderRadius.circular(12),
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 180),
                      padding: const EdgeInsets.symmetric(vertical: 8),
                      decoration: BoxDecoration(
                        color: isSel
                            ? (isDark ? kGreen : Colors.white)
                            : Colors.transparent,
                        borderRadius: BorderRadius.circular(12),
                        boxShadow: isSel
                            ? [
                                BoxShadow(
                                  color: Colors.black.withAlpha(isDark ? 30 : 10),
                                  blurRadius: 4,
                                  offset: const Offset(0, 1),
                                ),
                              ]
                            : null,
                      ),
                      child: Text(
                        item.label,
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: isSel ? FontWeight.w700 : FontWeight.w500,
                          color: isSel
                              ? (isDark ? Colors.white : kGreen)
                              : (isDark ? Colors.grey.shade400 : Colors.grey.shade700),
                        ),
                      ),
                    ),
                  ),
                );
              }).toList(),
            ),
          ),
        ),

        Expanded(
          child: Loader<Map<String, dynamic>>(
            key: ValueKey(_days),
            load: () => context.read<AppState>().api.getMap('/stats', query: {'days': _days}),
            builder: (context, d, reload) {
              final rows = (d['days'] as List).map((e) => Map<String, dynamic>.from(e)).toList();

              List<double> s(String k) {
                if (_days != 365) return [for (final r in rows) (r[k] as int).toDouble()];
                final buckets = <String, List<int>>{};
                for (final r in rows) {
                  buckets.putIfAbsent((r['date'] as String).substring(0, 7), () => []).add(r[k] as int);
                }
                return [for (final v in buckets.values) k == 'sleep_min' ? _avgNonZero(v) : v.fold<int>(0, (a, b) => a + b).toDouble()];
              }

              final t = Map<String, dynamic>.from(d['totals']);
              final a = Map<String, dynamic>.from(d['averages']);
              final sleepAvg = a['sleep_min'] as int?;
              const per = "kuniga";

              return RefreshIndicator(
                onRefresh: reload,
                color: kGreen,
                child: ListView(
                  padding: const EdgeInsets.fromLTRB(16, 10, 16, 24),
                  children: [
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _metricCard(
                          context: context,
                          title: "Qadamlar",
                          big: fmtInt(t['steps'] as int),
                          sub: "o'rtacha ${fmtInt(a['steps'] as int)} $per",
                          series: s('steps'),
                          color: kGreen,
                          icon: Icons.directions_walk_rounded,
                          isDark: isDark,
                        ),
                        const SizedBox(width: 12),
                        _metricCard(
                          context: context,
                          title: "Ovqat kaloriyasi",
                          big: '${fmtInt(t['calories_in'] as int)} kkal',
                          sub: "o'rtacha ${fmtInt(a['calories_in'] as int)} $per",
                          series: s('calories_in'),
                          color: Colors.orange,
                          icon: Icons.restaurant_rounded,
                          isDark: isDark,
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _metricCard(
                          context: context,
                          title: "Faol vaqt",
                          big: fmtMinutes(t['active_minutes'] as int),
                          sub: "o'rtacha ${a['active_minutes']} daq $per",
                          series: s('active_minutes'),
                          color: Colors.purple,
                          icon: Icons.timer_rounded,
                          isDark: isDark,
                        ),
                        const SizedBox(width: 12),
                        _metricCard(
                          context: context,
                          title: "Suv",
                          big: '${fmtL(t['water_ml'] as int)} L',
                          sub: "o'rtacha ${fmtL(a['water_ml'] as int)} L $per",
                          series: s('water_ml'),
                          color: Colors.blue,
                          icon: Icons.water_drop_rounded,
                          isDark: isDark,
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _metricCard(
                          context: context,
                          title: "Uyqu",
                          big: sleepAvg == null ? "N/A" : fmtSleep(sleepAvg),
                          sub: sleepAvg == null ? "qayd yo'q" : "o'rtacha",
                          series: s('sleep_min'),
                          color: Colors.indigo,
                          icon: Icons.bedtime_rounded,
                          isDark: isDark,
                        ),
                        const SizedBox(width: 12),
                        _metricCard(
                          context: context,
                          title: "Meditatsiya",
                          big: fmtMinutes(t['meditation_min'] as int),
                          sub: "jami",
                          series: s('meditation_min'),
                          color: Colors.teal,
                          icon: Icons.self_improvement_rounded,
                          isDark: isDark,
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    Text(
                      "Ko'rsatkichlar faqat siz kiritgan ma'lumotlardan hisoblanadi. Yoqilgan kaloriya hisoblanmaydi va bu tibbiy xulosa emas.",
                      style: TextStyle(fontSize: 11.5, color: isDark ? Colors.grey.shade500 : Colors.grey.shade600),
                      textAlign: TextAlign.center,
                    ),
                  ],
                ),
              );
            },
          ),
        ),
      ],
    );
  }
}
