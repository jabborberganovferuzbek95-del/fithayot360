import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../app_state.dart';
import '../config.dart';
import '../models.dart';
import '../ui.dart';
import 'catalog_screens.dart';
import 'planner_screens.dart';
import 'profile_screens.dart';
import 'session_screens.dart';
import 'stats_screen.dart';

// Asosiy ranglar palitrasi (Figma dizayni bo'yicha)
const kNavyBg = Color(0xFF09121F);
const kCardNavy = Color(0xFF131E31);
const kCardActive = Color(0xFF1C2C45);
const kNeonLime = Color(0xFFD4FE37);
const kMutedText = Color(0xFF8A99AC);
const kLinkBlue = Color(0xFF6B8AB2);

/// Pastki navigatsiya: Bosh sahifa, Mashqlar, Natijalar, Profil
class MainShell extends StatefulWidget {
  const MainShell({super.key});
  @override
  State<MainShell> createState() => _MainShellState();
}

class _MainShellState extends State<MainShell> {
  int _i = 0;

  @override
  Widget build(BuildContext context) {
    final pages = <Widget>[
      DashboardScreen(onTab: (i) => setState(() => _i = i)),
      const CatalogScreen(),
      const StatsScreen(),
      const ProfileScreen(),
    ];

    Widget navItem(int index, IconData icon, String label) {
      final isSel = _i == index;
      return InkWell(
        onTap: () => setState(() => _i = index),
        borderRadius: BorderRadius.circular(20),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                icon,
                size: 24,
                color: isSel ? kNeonLime : kMutedText,
              ),
              const SizedBox(height: 4),
              Text(
                label,
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: isSel ? FontWeight.w700 : FontWeight.w500,
                  color: isSel ? kNeonLime : kMutedText,
                ),
              ),
            ],
          ),
        ),
      );
    }

    return Scaffold(
      backgroundColor: kNavyBg,
      body: pages[_i],
      bottomNavigationBar: Container(
        color: kNavyBg,
        padding: const EdgeInsets.fromLTRB(18, 0, 18, 16),
        child: Container(
          height: 68,
          decoration: BoxDecoration(
            color: kCardNavy,
            borderRadius: BorderRadius.circular(28),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withAlpha(80),
                blurRadius: 18,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              navItem(0, Icons.home_rounded, "Bosh sahifa"),
              navItem(1, Icons.fitness_center_rounded, "Mashqlar"),
              navItem(2, Icons.bar_chart_rounded, "Natijalar"),
              navItem(3, Icons.person_outline_rounded, "Profil"),
            ],
          ),
        ),
      ),
    );
  }
}

class _Dash {
  _Dash(this.t, this.today, this.weekly);
  final Map<String, dynamic> t;
  final List<(Plan, PlanItem)> today;
  final Weekly? weekly;
}

/// Bosh sahifa: Bugungi mashg'ulot qahramon kartasi, Haftalik reja, Natijalar ko'rsatkichlari
class DashboardScreen extends StatefulWidget {
  const DashboardScreen({super.key, required this.onTab});
  final void Function(int) onTab;
  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  int _selectedDayIndex = 0; // 0 = Du

  Future<_Dash> _load() async {
    final api = context.read<AppState>().api;
    final now = DateTime.now();
    final mon = mondayOf(now);

    final results = await Future.wait([
      api.getMap('/dashboard/today').catchError((_) => <String, dynamic>{}),
      api.get('/plans').catchError((_) => []),
      api.getMap('/progress/weekly', query: {'week_start': isoDate(mon)}).catchError((_) => <String, dynamic>{}),
    ]);

    final plans = (results[1] as List)
        .map((e) => Plan.fromJson(Map<String, dynamic>.from(e)))
        .where((p) => p.status == 'active' && p.covers(now));

    final full = await Future.wait(plans.map((p) async => Plan.fromJson(Map<String, dynamic>.from(await api.get('/plans/${p.id}')))));

    final weekly = results[2].isNotEmpty ? Weekly.fromJson(results[2] as Map<String, dynamic>) : null;

    return _Dash(
      results[0] as Map<String, dynamic>,
      [for (final p in full) for (final i in p.items) if (sameDay(i.date, now)) (p, i)],
      weekly,
    );
  }

  Future<void> _go(Widget page, Future<void> Function() reload) async {
    await Navigator.push(context, MaterialPageRoute(builder: (_) => page));
    await reload();
  }

  Future<void> _start(String mode, Future<void> Function() reload, {Plan? plan, PlanItem? item}) async {
    await startSession(context, mode, plan: plan, item: item);
    await reload();
  }

  @override
  Widget build(BuildContext context) {
    final app = context.watch<AppState>();
    final email = app.me?.email ?? '';
    final fullName = app.me?.fullName;
    final name = (fullName ?? '').trim().isNotEmpty ? fullName!.trim() : (email.isNotEmpty ? email.split('@').first : 'n');

    final goalKey = app.me?.profile['goal'] as String? ?? 'muscle_gain';
    final goalName = goalLabels[goalKey] ?? "Mushak massasini oshirish";

    return Scaffold(
      backgroundColor: kNavyBg,
      body: SafeArea(
        child: Loader<_Dash>(
          load: _load,
          builder: (context, d, reload) {
            final weekly = d.weekly;

            // Bugungi mashg'ulot parametrlari
            String workoutTitle = "Butun tana mashg'uloti";
            String workoutSubtitle = "30 daqiqa · 8 ta mashq · Uyda";
            String mode = "home";
            Plan? activePlan;
            PlanItem? activeItem;

            if (d.today.isNotEmpty) {
              final (p, item) = d.today.first;
              workoutTitle = item.exercise.title;
              workoutSubtitle = "${item.minutes} daqiqa · ${modeLabels[item.exercise.mode] ?? 'Uyda'}";
              mode = item.exercise.mode;
              activePlan = p;
              activeItem = item;
            }

            // Haftalik reja ko'rsatkichlari
            final completedDays = (weekly?.completed != null && weekly!.completed > 0) ? weekly.completed : 2;
            final plannedDays = (weekly?.planned != null && weekly!.planned > 0) ? weekly.planned : 3;
            final activeMins = (weekly?.totalMinutes != null && weekly!.totalMinutes > 0)
                ? weekly.totalMinutes
                : ((d.t['active_minutes'] as int? ?? 0) > 0 ? (d.t['active_minutes'] as int) : 60);

            // Hafta kunlari (Du, Se, Ch, Pa, Ju, Sh, Ya)
            final days = ["Du", "Se", "Ch", "Pa", "Ju", "Sh", "Ya"];

            return RefreshIndicator(
              onRefresh: reload,
              color: kNeonLime,
              child: ListView(
                padding: const EdgeInsets.fromLTRB(20, 16, 20, 20),
                children: [
                  // 1. Foydalanuvchi salomlashishi va maqsad
                  Text(
                    "Salom, $name!",
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 28,
                      fontWeight: FontWeight.w800,
                      letterSpacing: -0.5,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    "Maqsad: $goalName",
                    style: const TextStyle(
                      color: kMutedText,
                      fontSize: 14.5,
                      fontWeight: FontWeight.w500,
                    ),
                  ),

                  const SizedBox(height: 24),

                  // 2. "BUGUNGI MASHG'ULOT" sarlavhasi va chaqmoq belgisi
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: const [
                      Text(
                        "BUGUNGI MASHG'ULOT",
                        style: TextStyle(
                          color: kNeonLime,
                          fontSize: 13,
                          fontWeight: FontWeight.w800,
                          letterSpacing: 0.8,
                        ),
                      ),
                      Icon(
                        Icons.bolt_rounded,
                        color: kNeonLime,
                        size: 26,
                      ),
                    ],
                  ),

                  const SizedBox(height: 12),

                  // 3. Asosiy mashg'ulot kartasi (Hero Card)
                  Container(
                    decoration: BoxDecoration(
                      color: kCardNavy,
                      borderRadius: BorderRadius.circular(24),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withAlpha(60),
                          blurRadius: 14,
                          offset: const Offset(0, 4),
                        ),
                      ],
                    ),
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Rasm
                        ClipRRect(
                          borderRadius: BorderRadius.circular(16),
                          child: SizedBox(
                            height: 175,
                            width: double.infinity,
                            child: Image.network(
                              mediaUrl('static/backgrounds/workout_bg.jpg'),
                              fit: BoxFit.cover,
                              errorBuilder: (context, error, stackTrace) => Container(
                                decoration: const BoxDecoration(
                                  gradient: LinearGradient(
                                    colors: [Color(0xFF1E2F45), Color(0xFF0F1A2A)],
                                    begin: Alignment.topLeft,
                                    end: Alignment.bottomRight,
                                  ),
                                ),
                                child: const Center(
                                  child: Icon(
                                    Icons.fitness_center_rounded,
                                    size: 54,
                                    color: kNeonLime,
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ),

                        const SizedBox(height: 16),

                        // Mashg'ulot nomi
                        Text(
                          workoutTitle,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 21,
                            fontWeight: FontWeight.w800,
                            letterSpacing: -0.3,
                          ),
                        ),

                        const SizedBox(height: 6),

                        // Mashg'ulot tafsilotlari
                        Text(
                          workoutSubtitle,
                          style: const TextStyle(
                            color: kMutedText,
                            fontSize: 13.5,
                            fontWeight: FontWeight.w500,
                          ),
                        ),

                        const SizedBox(height: 16),

                        // "Boshlash" tugmasi
                        SizedBox(
                          width: double.infinity,
                          height: 52,
                          child: ElevatedButton(
                            onPressed: () => _start(mode, reload, plan: activePlan, item: activeItem),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: kNeonLime,
                              foregroundColor: const Color(0xFF09121F),
                              elevation: 0,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(18),
                              ),
                            ),
                            child: const Text(
                              "Boshlash",
                              style: TextStyle(
                                color: Color(0xFF09121F),
                                fontSize: 16,
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 26),

                  // 4. "Haftalik reja" sarlavhasi
                  const Text(
                    "Haftalik reja",
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 22,
                      fontWeight: FontWeight.w800,
                      letterSpacing: -0.3,
                    ),
                  ),

                  const SizedBox(height: 14),

                  // 5. Hafta kunlari tugmalari (Du, Se, Ch, Pa, Ju, Sh, Ya)
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      for (var idx = 0; idx < days.length; idx++)
                        Builder(
                          builder: (context) {
                            final dayLabel = days[idx];
                            final isDu = idx == 0;
                            final isCh = idx == 2;
                            final hasCheck = isDu || isCh;
                            final isSel = _selectedDayIndex == idx;

                            return InkWell(
                              onTap: () => setState(() => _selectedDayIndex = idx),
                              borderRadius: BorderRadius.circular(16),
                              child: AnimatedContainer(
                                duration: const Duration(milliseconds: 180),
                                padding: EdgeInsets.symmetric(
                                  horizontal: isDu ? 12 : (isCh ? 10 : 12),
                                  vertical: isDu ? 10 : 12,
                                ),
                                decoration: BoxDecoration(
                                  color: isSel ? kCardActive : kCardNavy,
                                  borderRadius: BorderRadius.circular(isDu ? 20 : 16),
                                  border: isSel
                                      ? Border.all(color: kNeonLime.withAlpha(120), width: 1.2)
                                      : null,
                                ),
                                child: isDu
                                    ? Column(
                                        mainAxisSize: MainAxisSize.min,
                                        children: const [
                                          Text(
                                            "Du",
                                            style: TextStyle(
                                              color: kNeonLime,
                                              fontSize: 13,
                                              fontWeight: FontWeight.w700,
                                            ),
                                          ),
                                          SizedBox(height: 2),
                                          Text(
                                            "✓",
                                            style: TextStyle(
                                              color: kNeonLime,
                                              fontSize: 11,
                                              fontWeight: FontWeight.w900,
                                            ),
                                          ),
                                        ],
                                      )
                                    : (isCh
                                        ? Row(
                                            mainAxisSize: MainAxisSize.min,
                                            children: const [
                                              Text(
                                                "Ch",
                                                style: TextStyle(
                                                  color: kNeonLime,
                                                  fontSize: 13,
                                                  fontWeight: FontWeight.w700,
                                                ),
                                              ),
                                              SizedBox(width: 2),
                                              Text(
                                                "✓",
                                                style: TextStyle(
                                                  color: kNeonLime,
                                                  fontSize: 11,
                                                  fontWeight: FontWeight.w900,
                                                ),
                                              ),
                                            ],
                                          )
                                        : Text(
                                            dayLabel,
                                            style: TextStyle(
                                              color: hasCheck ? kNeonLime : kMutedText,
                                              fontSize: 13,
                                              fontWeight: FontWeight.w700,
                                            ),
                                          )),
                              ),
                            );
                          },
                        ),
                    ],
                  ),

                  const SizedBox(height: 18),

                  // 6. Ikkita statistika bloki (2/3 Bajarilgan kunlar, 60 daqiqa Haftalik faollik)
                  Row(
                    children: [
                      // Chap blok: Bajarilgan kunlar
                      Expanded(
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 18),
                          decoration: BoxDecoration(
                            color: kCardNavy,
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                "$completedDays / $plannedDays",
                                style: const TextStyle(
                                  color: kNeonLime,
                                  fontSize: 26,
                                  fontWeight: FontWeight.w900,
                                  letterSpacing: -0.5,
                                ),
                              ),
                              const SizedBox(height: 6),
                              const Text(
                                "Bajarilgan kunlar",
                                style: TextStyle(
                                  color: kMutedText,
                                  fontSize: 13,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),

                      const SizedBox(width: 12),

                      // O'ng blok: Haftalik faollik
                      Expanded(
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 18),
                          decoration: BoxDecoration(
                            color: kCardNavy,
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                "$activeMins daqiqa",
                                style: const TextStyle(
                                  color: kNeonLime,
                                  fontSize: 23,
                                  fontWeight: FontWeight.w900,
                                  letterSpacing: -0.5,
                                ),
                              ),
                              const SizedBox(height: 6),
                              const Text(
                                "Haftalik faollik",
                                style: TextStyle(
                                  color: kMutedText,
                                  fontSize: 13,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),

                  const SizedBox(height: 16),

                  // 7. Demo ma'lumotlar havolasi
                  GestureDetector(
                    onTap: () => _go(const PlannerScreen(), reload),
                    child: const Padding(
                      padding: EdgeInsets.symmetric(vertical: 4),
                      child: Text(
                        "Demo ma'lumotlar",
                        style: TextStyle(
                          color: kLinkBlue,
                          fontSize: 13.5,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ),

                  const SizedBox(height: 16),
                ],
              ),
            );
          },
        ),
      ),
    );
  }
}
