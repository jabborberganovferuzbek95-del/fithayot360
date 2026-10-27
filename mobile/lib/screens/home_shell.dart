import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../app_state.dart';
import '../models.dart';
import '../ui.dart';
import 'active_screen.dart';
import 'assistant_screens.dart';
import 'catalog_screens.dart';
import 'meditation_screens.dart';
import 'nutrition_screens.dart';
import 'planner_screens.dart';
import 'profile_screens.dart';
import 'session_screens.dart';
import 'stats_screen.dart';
import 'wellness_screens.dart';

/// Pastki navigatsiya: Bosh sahifa, Mashqlar, Ovqatlanish, Statistika, Profil
class MainShell extends StatefulWidget {
  const MainShell({super.key});
  @override
  State<MainShell> createState() => _MainShellState();
}

class _MainShellState extends State<MainShell> {
  int _i = 0;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final pages = <Widget>[
      DashboardScreen(onTab: (i) => setState(() => _i = i)),
      const CatalogScreen(),
      const NutritionScreen(),
      const StatsScreen(),
      const ProfileScreen(),
    ];

    return Scaffold(
      body: pages[_i],
      bottomNavigationBar: Container(
        decoration: BoxDecoration(
          border: Border(
            top: BorderSide(
              color: isDark ? Colors.white10 : Colors.black.withAlpha(12),
              width: 0.8,
            ),
          ),
        ),
        child: NavigationBar(
          selectedIndex: _i,
          onDestinationSelected: (v) => setState(() => _i = v),
          elevation: 0,
          backgroundColor: isDark ? const Color(0xFF141C17) : Colors.white,
          indicatorColor: kGreen.withAlpha(isDark ? 55 : 35),
          destinations: const [
            NavigationDestination(
              icon: Icon(Icons.home_outlined),
              selectedIcon: Icon(Icons.home_rounded, color: kGreen),
              label: "Bosh sahifa",
            ),
            NavigationDestination(
              icon: Icon(Icons.fitness_center_outlined),
              selectedIcon: Icon(Icons.fitness_center_rounded, color: kGreen),
              label: "Mashqlar",
            ),
            NavigationDestination(
              icon: Icon(Icons.restaurant_outlined),
              selectedIcon: Icon(Icons.restaurant_rounded, color: kGreen),
              label: "Ovqatlanish",
            ),
            NavigationDestination(
              icon: Icon(Icons.insert_chart_outlined_rounded),
              selectedIcon: Icon(Icons.leaderboard_rounded, color: kGreen),
              label: "Statistika",
            ),
            NavigationDestination(
              icon: Icon(Icons.person_outline_rounded),
              selectedIcon: Icon(Icons.person_rounded, color: kGreen),
              label: "Profil",
            ),
          ],
        ),
      ),
    );
  }
}

class _Dash {
  _Dash(this.t, this.today);
  final Map<String, dynamic> t;
  final List<(Plan, PlanItem)> today;
}

String _monthName(int m) => switch (m) {
      1 => "yanvar",
      2 => "fevral",
      3 => "mart",
      4 => "aprel",
      5 => "may",
      6 => "iyun",
      7 => "iyul",
      8 => "avgust",
      9 => "sentyabr",
      10 => "oktyabr",
      11 => "noyabr",
      12 => "dekabr",
      _ => "",
    };

/// Bosh sahifa: qadam kartasi, bo'limlar, bugungi reja
class DashboardScreen extends StatefulWidget {
  const DashboardScreen({super.key, required this.onTab});
  final void Function(int) onTab;
  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  Future<_Dash> _load() async {
    final api = context.read<AppState>().api;
    final results = await Future.wait([api.getMap('/dashboard/today'), api.get('/plans')]);
    final now = DateTime.now();
    final plans = (results[1] as List)
        .map((e) => Plan.fromJson(Map<String, dynamic>.from(e)))
        .where((p) => p.status == 'active' && p.covers(now));
    final full = await Future.wait(plans.map((p) async => Plan.fromJson(Map<String, dynamic>.from(await api.get('/plans/${p.id}')))));
    return _Dash(results[0] as Map<String, dynamic>, [for (final p in full) for (final i in p.items) if (sameDay(i.date, now)) (p, i)]);
  }

  Future<void> _go(Widget page, Future<void> Function() reload) async {
    await Navigator.push(context, MaterialPageRoute(builder: (_) => page));
    await reload();
  }

  Future<void> _start(String mode, Future<void> Function() reload, {Plan? plan, PlanItem? item}) async {
    await startSession(context, mode, plan: plan, item: item);
    await reload();
  }

  Widget _dayStrip(bool isDark) {
    final now = DateTime.now();
    final mon = mondayOf(now);

    return Container(
      padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 4),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF161F1A) : Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: isDark ? Colors.white10 : Colors.black.withAlpha(12),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withAlpha(isDark ? 25 : 8),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        children: [
          for (var i = 0; i < 7; i++) ...[
            Builder(builder: (context) {
              final dayDate = mon.add(Duration(days: i));
              final isToday = sameDay(dayDate, now);

              return Expanded(
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  padding: const EdgeInsets.symmetric(vertical: 8),
                  decoration: BoxDecoration(
                    color: isToday ? kGreen : Colors.transparent,
                    borderRadius: BorderRadius.circular(14),
                    boxShadow: isToday
                        ? [
                            BoxShadow(
                              color: kGreen.withAlpha(100),
                              blurRadius: 8,
                              offset: const Offset(0, 3),
                            ),
                          ]
                        : null,
                  ),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        weekdaysShort[i],
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: isToday ? FontWeight.bold : FontWeight.w500,
                          color: isToday
                              ? Colors.white
                              : (isDark ? Colors.grey.shade400 : Colors.grey.shade600),
                        ),
                      ),
                      const SizedBox(height: 5),
                      Text(
                        '${dayDate.day}',
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: isToday ? FontWeight.w800 : FontWeight.w600,
                          color: isToday
                              ? Colors.white
                              : (isDark ? Colors.white : Colors.black87),
                        ),
                      ),
                      if (isToday) ...[
                        const SizedBox(height: 4),
                        Container(
                          width: 4,
                          height: 4,
                          decoration: const BoxDecoration(
                            color: Colors.white,
                            shape: BoxShape.circle,
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              );
            }),
          ],
        ],
      ),
    );
  }

  Widget _statFrosted(IconData icon, String value, String label) => Container(
        margin: const EdgeInsets.only(bottom: 8),
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
        decoration: BoxDecoration(
          color: Colors.white.withAlpha(22),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Colors.white.withAlpha(30)),
        ),
        child: Row(
          children: [
            Icon(icon, color: kMint, size: 18),
            const SizedBox(width: 8),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    value,
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                      fontSize: 13,
                    ),
                  ),
                  Text(
                    label,
                    style: TextStyle(
                      color: Colors.white.withAlpha(180),
                      fontSize: 10.5,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      );

  Widget _tileCard(
    BuildContext context,
    String title,
    String sub,
    IconData icon,
    Color color,
    VoidCallback onTap,
    bool isDark,
  ) {
    return InkWell(
      borderRadius: BorderRadius.circular(20),
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: isDark ? const Color(0xFF17201B) : Colors.white,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: isDark ? Colors.white10 : Colors.black.withAlpha(10),
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withAlpha(isDark ? 20 : 6),
              blurRadius: 10,
              offset: const Offset(0, 3),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: color.withAlpha(isDark ? 45 : 30),
                borderRadius: BorderRadius.circular(14),
              ),
              child: Icon(icon, color: color, size: 22),
            ),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontWeight: FontWeight.w700,
                    fontSize: 13.5,
                    color: isDark ? Colors.white : Colors.black87,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  sub,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w500,
                    color: isDark ? Colors.grey.shade400 : Colors.grey.shade600,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _trainingModeCard({
    required String title,
    required String sub,
    required IconData icon,
    required Color color,
    required VoidCallback onTap,
    required bool isDark,
  }) {
    return Expanded(
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 8),
          decoration: BoxDecoration(
            color: color.withAlpha(isDark ? 30 : 20),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: color.withAlpha(isDark ? 60 : 45)),
          ),
          child: Column(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: color.withAlpha(isDark ? 55 : 35),
                  shape: BoxShape.circle,
                ),
                child: Icon(icon, color: color, size: 22),
              ),
              const SizedBox(height: 8),
              Text(
                title,
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 13.5,
                  color: isDark ? Colors.white : Colors.black87,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                sub,
                style: TextStyle(
                  fontSize: 10,
                  color: isDark ? Colors.grey.shade400 : Colors.grey.shade600,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final app = context.watch<AppState>();
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final email = app.me?.email ?? '';
    final fullName = app.me?.fullName;
    final name = (fullName ?? '').trim().isNotEmpty ? fullName!.trim() : email.split('@').first;
    final now = DateTime.now();

    return Scaffold(
      backgroundColor: Colors.transparent,
      body: ScreenBackground(
        imageName: 'dashboard_bg.jpg',
        child: SafeArea(
          child: Loader<_Dash>(
          load: _load,
          builder: (context, d, reload) {
            final t = d.t;
            final goals = Map<String, dynamic>.from(t['goals']);
            final steps = t['steps'] as int;
            final stepGoal = goals['steps'] as int;
            final water = t['water_ml'] as int;
            final sleep = t['sleep_min'] as int;
            final meditation = t['meditation_min'] as int;
            final stepProgress = stepGoal > 0 ? (steps / stepGoal).clamp(0.0, 1.0) : 0.0;
            final stepPercent = (stepProgress * 100).round();

            return RefreshIndicator(
              onRefresh: reload,
              color: kGreen,
              child: ListView(
                padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
                children: [
                  // Header: Salomlashish & profile/action buttons
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(2.5),
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          border: Border.all(color: kGreen, width: 2),
                        ),
                        child: CircleAvatar(
                          radius: 22,
                          backgroundColor: kGreen,
                          child: Text(
                            name.isEmpty ? '?' : name[0].toUpperCase(),
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              "Salom, $name! 👋",
                              style: const TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.w800,
                                letterSpacing: -0.3,
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              "${weekdays[now.weekday - 1]}, ${now.day}-${_monthName(now.month)}",
                              style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w500,
                                color: isDark ? Colors.grey.shade400 : Colors.grey.shade600,
                              ),
                            ),
                          ],
                        ),
                      ),
                      // AI Maslahatchi
                      IconButton(
                        tooltip: "FitMaslahatchi",
                        style: IconButton.styleFrom(
                          backgroundColor: isDark ? const Color(0xFF1B2420) : Colors.white,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        ),
                        icon: const Icon(Icons.chat_bubble_outline_rounded, size: 20),
                        onPressed: () => _go(const CoachScreen(), reload),
                      ),
                      const SizedBox(width: 6),
                      // Bildirishnomalar
                      IconButton(
                        tooltip: "Bildirishnomalar",
                        style: IconButton.styleFrom(
                          backgroundColor: isDark ? const Color(0xFF1B2420) : Colors.white,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        ),
                        icon: const Icon(Icons.notifications_none_rounded, size: 20),
                        onPressed: () => _go(const NotificationsScreen(), reload),
                      ),
                    ],
                  ),

                  const SizedBox(height: 16),

                  // Haftalik kalendar tasmasi
                  _dayStrip(isDark),

                  const SizedBox(height: 18),

                  // Asosiy Qadam & Faollik kartasi
                  GestureDetector(
                    onTap: () async {
                      if (await editSteps(context, steps)) {
                        await reload();
                      }
                    },
                    child: Container(
                      padding: const EdgeInsets.all(20),
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(26),
                        gradient: const LinearGradient(
                          colors: [Color(0xFF16803C), Color(0xFF09361B)],
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: kGreen.withAlpha(70),
                            blurRadius: 18,
                            offset: const Offset(0, 6),
                          ),
                        ],
                      ),
                      child: Column(
                        children: [
                          Row(
                            children: [
                              // Doira ko'rsatkichi (RingProgress)
                              RingProgress(
                                value: stepProgress,
                                size: 125,
                                stroke: 10,
                                color: kMint,
                                trackColor: Colors.white.withAlpha(45),
                                child: Column(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Text(
                                      fmtInt(steps),
                                      style: const TextStyle(
                                        color: Colors.white,
                                        fontSize: 22,
                                        fontWeight: FontWeight.w800,
                                      ),
                                    ),
                                    const Text(
                                      "qadam",
                                      style: TextStyle(
                                        color: Colors.white70,
                                        fontSize: 11.5,
                                        fontWeight: FontWeight.w500,
                                      ),
                                    ),
                                    const SizedBox(height: 2),
                                    Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                      decoration: BoxDecoration(
                                        color: kMint.withAlpha(50),
                                        borderRadius: BorderRadius.circular(8),
                                      ),
                                      child: Text(
                                        "$stepPercent%",
                                        style: const TextStyle(
                                          color: kMint,
                                          fontSize: 10,
                                          fontWeight: FontWeight.w700,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              const SizedBox(width: 18),
                              // 3 ta ko'rsatkich
                              Expanded(
                                child: Column(
                                  children: [
                                    _statFrosted(
                                      Icons.timer_rounded,
                                      '${t['active_minutes']} daqiqa',
                                      "Faol mashq vaqti",
                                    ),
                                    _statFrosted(
                                      Icons.local_fire_department_rounded,
                                      '${fmtInt(t['calories_in'] as int)} kkal',
                                      "Iste'mol qilingan",
                                    ),
                                    _statFrosted(
                                      Icons.bedtime_rounded,
                                      sleep > 0 ? fmtSleep(sleep) : "—",
                                      "Tungi uyqu",
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 14),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                            decoration: BoxDecoration(
                              color: Colors.black.withAlpha(40),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Text(
                                  "Maqsad: ${fmtInt(stepGoal)} qadam",
                                  style: const TextStyle(color: Colors.white70, fontSize: 12),
                                ),
                                const Row(
                                  children: [
                                    Text(
                                      "Kiritish",
                                      style: TextStyle(
                                        color: kMint,
                                        fontSize: 12,
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                    SizedBox(width: 4),
                                    Icon(Icons.edit_outlined, color: kMint, size: 14),
                                  ],
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),

                  const SizedBox(height: 22),

                  // Tezkor mashq boshlash
                  const Text(
                    "Mashg'ulotni boshlash",
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      _trainingModeCard(
                        title: "Home",
                        sub: "Uy mashqlari",
                        icon: Icons.home_rounded,
                        color: Colors.indigo,
                        onTap: () => _start('home', reload),
                        isDark: isDark,
                      ),
                      const SizedBox(width: 10),
                      _trainingModeCard(
                        title: "Gym",
                        sub: "Zal dasturlari",
                        icon: Icons.fitness_center_rounded,
                        color: Colors.deepOrange,
                        onTap: () => _start('gym', reload),
                        isDark: isDark,
                      ),
                      const SizedBox(width: 10),
                      _trainingModeCard(
                        title: "Faollik",
                        sub: "Yurish & yugurish",
                        icon: Icons.directions_walk_rounded,
                        color: Colors.teal,
                        onTap: () => _go(const ActiveScreen(), reload),
                        isDark: isDark,
                      ),
                    ],
                  ),

                  const SizedBox(height: 22),

                  // Kunlik salomatlik modullari (6 ta blok)
                  const Text(
                    "Kunlik kuzatuv",
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
                  ),
                  const SizedBox(height: 12),
                  GridView.count(
                    crossAxisCount: 3,
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    mainAxisSpacing: 10,
                    crossAxisSpacing: 10,
                    childAspectRatio: 0.95,
                    children: [
                      _tileCard(
                        context,
                        "Mashqlar",
                        "Katalog",
                        Icons.fitness_center_rounded,
                        Colors.redAccent,
                        () => widget.onTab(1),
                        isDark,
                      ),
                      _tileCard(
                        context,
                        "Ovqatlanish",
                        '${t['calories_in']}/${fmtInt(goals['calories'] as int)} kkal',
                        Icons.restaurant_rounded,
                        Colors.green,
                        () => widget.onTab(2),
                        isDark,
                      ),
                      _tileCard(
                        context,
                        "Suv",
                        '${fmtL(water)}/${fmtL(goals['water_ml'] as int)} L',
                        Icons.water_drop_rounded,
                        Colors.blue,
                        () => _go(const WaterScreen(), reload),
                        isDark,
                      ),
                      _tileCard(
                        context,
                        "Uyqu",
                        sleep > 0 ? fmtSleep(sleep) : "Qayd yo'q",
                        Icons.bedtime_rounded,
                        Colors.purple,
                        () => _go(const SleepScreen(), reload),
                        isDark,
                      ),
                      _tileCard(
                        context,
                        "Meditatsiya",
                        meditation > 0 ? '$meditation daq' : "Tinchlaning",
                        Icons.self_improvement_rounded,
                        Colors.pinkAccent,
                        () => _go(const MeditationScreen(), reload),
                        isDark,
                      ),
                      _tileCard(
                        context,
                        "Odatlar",
                        '${t['habits_done']}/${(t['habits'] as List).length} bajarildi',
                        Icons.checklist_rounded,
                        Colors.orange,
                        () => _go(const HabitsScreen(), reload),
                        isDark,
                      ),
                    ],
                  ),

                  const SizedBox(height: 22),

                  // Bugungi reja bo'limi
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text(
                        "Bugungi reja",
                        style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
                      ),
                      TextButton.icon(
                        onPressed: () => _go(const PlannerScreen(), reload),
                        icon: const Icon(Icons.calendar_month_outlined, size: 16, color: kGreen),
                        label: const Text(
                          "Haftalik reja",
                          style: TextStyle(color: kGreen, fontWeight: FontWeight.w600, fontSize: 13),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),

                  if (d.today.isEmpty)
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: isDark ? const Color(0xFF161F1A) : Colors.white,
                        borderRadius: BorderRadius.circular(18),
                        border: Border.all(
                          color: isDark ? Colors.white10 : Colors.black.withAlpha(10),
                        ),
                      ),
                      child: Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(10),
                            decoration: BoxDecoration(
                              color: kGreen.withAlpha(isDark ? 40 : 25),
                              borderRadius: BorderRadius.circular(14),
                            ),
                            child: const Icon(Icons.event_note_rounded, color: kGreen, size: 24),
                          ),
                          const SizedBox(width: 14),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Text(
                                  "Bugun uchun reja yo'q",
                                  style: TextStyle(fontWeight: FontWeight.w700, fontSize: 14),
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  "Mashqlar bo'limidan rejangizga mashq qo'shing yoki Home/Gym ni boshlang.",
                                  style: TextStyle(
                                    fontSize: 12,
                                    color: isDark ? Colors.grey.shade400 : Colors.grey.shade600,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    )
                  else
                    for (final (plan, item) in d.today)
                      Container(
                        margin: const EdgeInsets.only(bottom: 10),
                        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                        decoration: BoxDecoration(
                          color: isDark ? const Color(0xFF161F1A) : Colors.white,
                          borderRadius: BorderRadius.circular(18),
                          border: Border.all(
                            color: item.isCompleted
                                ? Colors.green.withAlpha(100)
                                : (isDark ? Colors.white10 : Colors.black.withAlpha(10)),
                          ),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withAlpha(isDark ? 20 : 6),
                              blurRadius: 8,
                              offset: const Offset(0, 2),
                            ),
                          ],
                        ),
                        child: Row(
                          children: [
                            item.isCompleted
                                ? Container(
                                    padding: const EdgeInsets.all(6),
                                    decoration: BoxDecoration(
                                      color: Colors.green.withAlpha(30),
                                      shape: BoxShape.circle,
                                    ),
                                    child: const Icon(Icons.check_circle_rounded, color: Colors.green, size: 26),
                                  )
                                : ModuleBadge(item.exercise.mode),
                            const SizedBox(width: 14),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    item.exercise.title,
                                    style: TextStyle(
                                      fontWeight: FontWeight.w700,
                                      fontSize: 14.5,
                                      decoration: item.isCompleted ? TextDecoration.lineThrough : null,
                                      color: isDark ? Colors.white : Colors.black87,
                                    ),
                                  ),
                                  const SizedBox(height: 3),
                                  Text(
                                    '${modeLabels[item.exercise.mode]} · ${item.minutes} daqiqa',
                                    style: TextStyle(
                                      fontSize: 12,
                                      color: isDark ? Colors.grey.shade400 : Colors.grey.shade600,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            if (!item.isCompleted)
                              IconButton(
                                icon: const Icon(Icons.play_circle_fill_rounded, size: 36, color: kGreen),
                                onPressed: () => _start(item.exercise.mode, reload, plan: plan, item: item),
                              ),
                          ],
                        ),
                      ),

                  const SizedBox(height: 16),
                  const SafetyBanner(),
                  const SizedBox(height: 12),
                ],
              ),
            );
          },
        ),
      ),
    ),
  );
  }
}
