import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../api_client.dart';
import '../app_state.dart';
import '../models.dart';
import '../ui.dart';
import 'active_screen.dart';
import 'planner_screens.dart';
import 'programs_screens.dart';

const _diffLabels = {'beginner': "Boshlang'ich", 'intermediate': "O'rta", 'advanced': "Tajribali"};

Color _difficultyColor(String diff) => switch (diff) {
      'beginner' => const Color(0xFF10B981),
      'intermediate' => const Color(0xFFF59E0B),
      'advanced' => const Color(0xFFEF4444),
      _ => Colors.teal,
    };

/// S07/S08 Mashqlar katalogi: Dasturlar, Home, Gym va Faollik yorliqlari
class CatalogScreen extends StatelessWidget {
  const CatalogScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return DefaultTabController(
      length: 4,
      child: Scaffold(
        backgroundColor: Colors.transparent,
        appBar: AppBar(
          elevation: 0,
          backgroundColor: isDark ? const Color(0xFF141C17).withAlpha(220) : Colors.white.withAlpha(220),
          title: const Text(
            "Mashqlar",
            style: TextStyle(fontWeight: FontWeight.w800, fontSize: 20),
          ),
          actions: [
            IconButton(
              tooltip: "Haftalik reja",
              style: IconButton.styleFrom(
                backgroundColor: isDark ? const Color(0xFF1D2621) : const Color(0xFFF0F4F1),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
              icon: const Icon(Icons.calendar_month_rounded, size: 20, color: kGreen),
              onPressed: () => Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const PlannerScreen()),
              ),
            ),
            const SizedBox(width: 12),
          ],
          bottom: TabBar(
            isScrollable: false,
            indicatorColor: kGreen,
            indicatorWeight: 3,
            labelColor: kGreen,
            unselectedLabelColor: isDark ? Colors.grey.shade400 : Colors.grey.shade600,
            labelStyle: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13.5),
            unselectedLabelStyle: const TextStyle(fontWeight: FontWeight.w500, fontSize: 13),
            tabs: const [
              Tab(text: "Dasturlar"),
              Tab(text: "Uyda"),
              Tab(text: "Zalda"),
              Tab(text: "Faollik"),
            ],
          ),
        ),
        body: const ScreenBackground(
          imageName: 'workout_bg.jpg',
          child: TabBarView(
            children: [
              ProgramsTab(),
              ExerciseList(mode: 'home'),
              ExerciseList(mode: 'gym'),
              ActiveScreen(embedded: true),
            ],
          ),
        ),
      ),
    );
  }
}

class ExerciseList extends StatefulWidget {
  const ExerciseList({super.key, required this.mode, this.onPick});
  final String mode;
  final void Function(Exercise)? onPick; // tanlash rejimi (picker)

  @override
  State<ExerciseList> createState() => _ExerciseListState();
}

class _ExerciseListState extends State<ExerciseList> with AutomaticKeepAliveClientMixin {
  final TextEditingController _searchCtrl = TextEditingController();
  String _q = '';
  String? _difficulty, _equipment;

  @override
  bool get wantKeepAlive => true;

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  Future<List<Exercise>> _load() async {
    final j = await context.read<AppState>().api.get('/exercises', query: {'mode': widget.mode, 'limit': 200}) as List;
    return j.map((e) => Exercise.fromJson(Map<String, dynamic>.from(e))).toList();
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Loader<List<Exercise>>(
      load: _load,
      builder: (context, all, reload) {
        final equipment = {for (final e in all) e.equipment}.toList()..sort();
        final list = all.where((e) {
          final matchQ = _q.isEmpty || e.title.toLowerCase().contains(_q.toLowerCase());
          final matchDiff = _difficulty == null || e.difficulty == _difficulty;
          final matchEq = _equipment == null || e.equipment == _equipment;
          return matchQ && matchDiff && matchEq;
        }).toList();

        return Column(
          children: [
            // Qidiruv paneli
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
              child: Container(
                decoration: BoxDecoration(
                  color: isDark ? const Color(0xFF1B2420) : Colors.white,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: isDark ? Colors.white10 : Colors.black.withAlpha(12)),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withAlpha(isDark ? 15 : 5),
                      blurRadius: 8,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                child: TextField(
                  controller: _searchCtrl,
                  decoration: InputDecoration(
                    prefixIcon: const Icon(Icons.search_rounded, color: kGreen, size: 22),
                    suffixIcon: _q.isNotEmpty
                        ? IconButton(
                            icon: const Icon(Icons.clear_rounded, size: 18),
                            onPressed: () {
                              _searchCtrl.clear();
                              setState(() => _q = '');
                            },
                          )
                        : null,
                    hintText: "Mashq nomi bo'yicha qidirish...",
                    hintStyle: TextStyle(
                      fontSize: 14,
                      color: isDark ? Colors.grey.shade500 : Colors.grey.shade400,
                    ),
                    border: InputBorder.none,
                    contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                  ),
                  onChanged: (v) => setState(() => _q = v.trim()),
                ),
              ),
            ),

            // Filtrlash chizig'i
            SizedBox(
              height: 44,
              child: ListView(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.symmetric(horizontal: 16),
                children: [
                  // Barchasi
                  Padding(
                    padding: const EdgeInsets.only(right: 6),
                    child: FilterChip(
                      label: const Text("Barchasi"),
                      selected: _difficulty == null && _equipment == null,
                      onSelected: (_) => setState(() {
                        _difficulty = null;
                        _equipment = null;
                      }),
                      selectedColor: kGreen.withAlpha(isDark ? 50 : 35),
                      checkmarkColor: kGreen,
                      labelStyle: TextStyle(
                        fontSize: 12,
                        fontWeight: (_difficulty == null && _equipment == null) ? FontWeight.bold : FontWeight.normal,
                        color: (_difficulty == null && _equipment == null) ? kGreen : null,
                      ),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                  ),
                  // Qiyinlik darajalari
                  for (final d in _diffLabels.entries)
                    Padding(
                      padding: const EdgeInsets.only(right: 6),
                      child: FilterChip(
                        label: Text(d.value),
                        selected: _difficulty == d.key,
                        onSelected: (s) => setState(() => _difficulty = s ? d.key : null),
                        selectedColor: _difficultyColor(d.key).withAlpha(isDark ? 50 : 35),
                        checkmarkColor: _difficultyColor(d.key),
                        labelStyle: TextStyle(
                          fontSize: 12,
                          fontWeight: _difficulty == d.key ? FontWeight.bold : FontWeight.normal,
                          color: _difficulty == d.key ? _difficultyColor(d.key) : null,
                        ),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                    ),
                  // Jihozlar
                  for (final e in equipment)
                    Padding(
                      padding: const EdgeInsets.only(right: 6),
                      child: FilterChip(
                        label: Text(equipmentLabel(e)),
                        selected: _equipment == e,
                        onSelected: (s) => setState(() => _equipment = s ? e : null),
                        selectedColor: kGreen.withAlpha(isDark ? 50 : 35),
                        checkmarkColor: kGreen,
                        labelStyle: TextStyle(
                          fontSize: 12,
                          fontWeight: _equipment == e ? FontWeight.bold : FontWeight.normal,
                          color: _equipment == e ? kGreen : null,
                        ),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                    ),
                ],
              ),
            ),

            const SizedBox(height: 6),

            // Topilganlar soni
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 4),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    "${list.length} ta mashq",
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: isDark ? Colors.grey.shade400 : Colors.grey.shade600,
                    ),
                  ),
                  if (_difficulty != null || _equipment != null || _q.isNotEmpty)
                    InkWell(
                      onTap: () => setState(() {
                        _searchCtrl.clear();
                        _q = '';
                        _difficulty = null;
                        _equipment = null;
                      }),
                      child: const Text(
                        "Filtrlarni tozalash",
                        style: TextStyle(fontSize: 12, color: kGreen, fontWeight: FontWeight.w600),
                      ),
                    ),
                ],
              ),
            ),

            const SizedBox(height: 4),

            // Mashqlar ro'yxati
            Expanded(
              child: RefreshIndicator(
                onRefresh: reload,
                color: kGreen,
                child: list.isEmpty
                    ? ListView(
                        children: [
                          Padding(
                            padding: const EdgeInsets.symmetric(vertical: 60, horizontal: 24),
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Container(
                                  padding: const EdgeInsets.all(18),
                                  decoration: BoxDecoration(
                                    color: (isDark ? Colors.white10 : Colors.black.withAlpha(10)),
                                    shape: BoxShape.circle,
                                  ),
                                  child: Icon(
                                    Icons.fitness_center_outlined,
                                    size: 40,
                                    color: isDark ? Colors.grey.shade400 : Colors.grey.shade600,
                                  ),
                                ),
                                const SizedBox(height: 16),
                                const Text(
                                  "Mos mashq topilmadi",
                                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                                ),
                                const SizedBox(height: 6),
                                Text(
                                  "Qidiruv so'zini yoki tanlangan filtrlarni o'zgartirib ko'ring.",
                                  textAlign: TextAlign.center,
                                  style: TextStyle(
                                    fontSize: 13,
                                    color: isDark ? Colors.grey.shade400 : Colors.grey.shade600,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      )
                    : ListView.builder(
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
                        itemCount: list.length,
                        itemBuilder: (context, i) {
                          final e = list[i];
                          final diffColor = _difficultyColor(e.difficulty);

                          return Container(
                            margin: const EdgeInsets.only(bottom: 10),
                            decoration: BoxDecoration(
                              color: isDark ? const Color(0xFF161F1A) : Colors.white,
                              borderRadius: BorderRadius.circular(18),
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
                            child: Material(
                              color: Colors.transparent,
                              child: InkWell(
                                borderRadius: BorderRadius.circular(18),
                                onTap: () => widget.onPick != null
                                    ? widget.onPick!(e)
                                    : Navigator.push(
                                        context,
                                        MaterialPageRoute(
                                          builder: (_) => ExerciseDetailScreen(exercise: e),
                                        ),
                                      ),
                                child: Padding(
                                  padding: const EdgeInsets.all(14),
                                  child: Row(
                                    children: [
                                      // Mode ikonkasi
                                      Container(
                                        width: 48,
                                        height: 48,
                                        decoration: BoxDecoration(
                                          color: moduleColor(e.mode).withAlpha(isDark ? 40 : 25),
                                          borderRadius: BorderRadius.circular(14),
                                        ),
                                        child: Icon(
                                          moduleIcon(e.mode),
                                          color: moduleColor(e.mode),
                                          size: 24,
                                        ),
                                      ),
                                      const SizedBox(width: 14),

                                      // Sarlavha & teglar
                                      Expanded(
                                        child: Column(
                                          crossAxisAlignment: CrossAxisAlignment.start,
                                          children: [
                                            Text(
                                              e.title,
                                              style: TextStyle(
                                                fontSize: 15,
                                                fontWeight: FontWeight.w700,
                                                color: isDark ? Colors.white : Colors.black87,
                                              ),
                                            ),
                                            const SizedBox(height: 6),
                                            Wrap(
                                              spacing: 6,
                                              runSpacing: 4,
                                              children: [
                                                // Daraja
                                                Container(
                                                  padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2.5),
                                                  decoration: BoxDecoration(
                                                    color: diffColor.withAlpha(isDark ? 35 : 20),
                                                    borderRadius: BorderRadius.circular(6),
                                                  ),
                                                  child: Text(
                                                    _diffLabels[e.difficulty] ?? e.difficulty,
                                                    style: TextStyle(
                                                      fontSize: 11,
                                                      fontWeight: FontWeight.w600,
                                                      color: diffColor,
                                                    ),
                                                  ),
                                                ),
                                                // Jihoz
                                                Container(
                                                  padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2.5),
                                                  decoration: BoxDecoration(
                                                    color: isDark ? Colors.white10 : Colors.black.withAlpha(12),
                                                    borderRadius: BorderRadius.circular(6),
                                                  ),
                                                  child: Text(
                                                    equipmentLabel(e.equipment),
                                                    style: TextStyle(
                                                      fontSize: 11,
                                                      color: isDark ? Colors.grey.shade400 : Colors.grey.shade600,
                                                    ),
                                                  ),
                                                ),
                                                // Vaqt hinti
                                                if (e.durationHint != null)
                                                  Container(
                                                    padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2.5),
                                                    decoration: BoxDecoration(
                                                      color: Colors.blue.withAlpha(isDark ? 35 : 20),
                                                      borderRadius: BorderRadius.circular(6),
                                                    ),
                                                    child: Text(
                                                      e.durationHint!,
                                                      style: const TextStyle(
                                                        fontSize: 11,
                                                        color: Colors.blue,
                                                        fontWeight: FontWeight.w500,
                                                      ),
                                                    ),
                                                  ),
                                              ],
                                            ),
                                          ],
                                        ),
                                      ),

                                      const SizedBox(width: 8),
                                      Icon(
                                        Icons.chevron_right_rounded,
                                        color: isDark ? Colors.grey.shade600 : Colors.grey.shade400,
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            ),
                          );
                        },
                      ),
              ),
            ),
          ],
        );
      },
    );
  }
}

/// S09 Mashq tafsiloti
class ExerciseDetailScreen extends StatelessWidget {
  const ExerciseDetailScreen({super.key, required this.exercise});
  final Exercise exercise;

  Future<void> _addToPlan(BuildContext context) async {
    DateTime date = dateOnly(DateTime.now());
    double minutes = 15;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    final ok = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      backgroundColor: isDark ? const Color(0xFF161F1A) : Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setS) => Padding(
          padding: EdgeInsets.fromLTRB(20, 20, 20, 24 + MediaQuery.of(ctx).viewInsets.bottom),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: Colors.grey.shade400,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              const Text(
                "Mashg'ulot rejasiga qo'shish",
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 16),

              // Sana tanlash kartasi
              InkWell(
                onTap: () async {
                  final d = await showDatePicker(
                    context: ctx,
                    initialDate: date,
                    firstDate: dateOnly(DateTime.now()),
                    lastDate: DateTime.now().add(const Duration(days: 90)),
                  );
                  if (d != null) setS(() => date = d);
                },
                borderRadius: BorderRadius.circular(14),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                  decoration: BoxDecoration(
                    color: isDark ? Colors.white.withAlpha(15) : const Color(0xFFF3F5F4),
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.event_rounded, color: kGreen),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          "${weekdays[date.weekday - 1]}, ${fmtDate(date)}",
                          style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14),
                        ),
                      ),
                      const Text(
                        "O'zgartirish",
                        style: TextStyle(color: kGreen, fontWeight: FontWeight.w600, fontSize: 13),
                      ),
                    ],
                  ),
                ),
              ),

              const SizedBox(height: 20),

              // Davomiylik
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text("Davomiyligi:", style: TextStyle(fontWeight: FontWeight.w600)),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: kGreen.withAlpha(isDark ? 40 : 25),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Text(
                      "${minutes.round()} daqiqa",
                      style: const TextStyle(color: kGreen, fontWeight: FontWeight.bold),
                    ),
                  ),
                ],
              ),
              SliderTheme(
                data: SliderTheme.of(ctx).copyWith(
                  activeTrackColor: kGreen,
                  thumbColor: kGreen,
                  trackHeight: 5,
                ),
                child: Slider(
                  value: minutes,
                  min: 5,
                  max: 90,
                  divisions: 17,
                  onChanged: (v) => setS(() => minutes = v),
                ),
              ),

              // Tezkor tugmalar
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [10, 15, 20, 30].map((m) {
                  final isCur = minutes.round() == m;
                  return InkWell(
                    onTap: () => setS(() => minutes = m.toDouble()),
                    borderRadius: BorderRadius.circular(10),
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                      decoration: BoxDecoration(
                        color: isCur ? kGreen : (isDark ? Colors.white10 : Colors.grey.shade100),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Text(
                        "$m daq",
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: isCur ? FontWeight.bold : FontWeight.normal,
                          color: isCur ? Colors.white : null,
                        ),
                      ),
                    ),
                  );
                }).toList(),
              ),

              const SizedBox(height: 24),
              FilledButton(
                onPressed: () => Navigator.pop(ctx, true),
                style: FilledButton.styleFrom(
                  backgroundColor: kGreen,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                  minimumSize: const Size.fromHeight(50),
                ),
                child: const Text("Rejaga kiritish", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
              ),
            ],
          ),
        ),
      ),
    );

    if (ok != true) return;
    try {
      await addExerciseToPlan(context.read<AppState>().api, exercise, date, minutes.round());
      if (context.mounted) {
        toast(context, "Rejaga qo'shildi: ${fmtDate(date)} (${minutes.round()} daq)");
      }
    } on ApiException catch (e) {
      if (context.mounted) toast(context, e.message);
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final diffColor = _difficultyColor(exercise.difficulty);

    return Scaffold(
      backgroundColor: isDark ? const Color(0xFF0F1512) : const Color(0xFFF7FAF8),
      appBar: AppBar(
        title: Text(exercise.title),
        elevation: 0,
        backgroundColor: Colors.transparent,
      ),
      body: ListView(
        padding: const EdgeInsets.all(18),
        children: [
          // Banner / Header Box
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  moduleColor(exercise.mode),
                  moduleColor(exercise.mode).withAlpha(180),
                ],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(22),
              boxShadow: [
                BoxShadow(
                  color: moduleColor(exercise.mode).withAlpha(80),
                  blurRadius: 16,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(
                        color: Colors.white.withAlpha(50),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Text(
                        modeLabels[exercise.mode] ?? exercise.mode,
                        style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 12),
                      ),
                    ),
                    Icon(moduleIcon(exercise.mode), color: Colors.white70, size: 28),
                  ],
                ),
                const SizedBox(height: 14),
                Text(
                  exercise.title,
                  style: const TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.w800,
                    color: Colors.white,
                    letterSpacing: -0.3,
                  ),
                ),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 8,
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                      decoration: BoxDecoration(
                        color: diffColor.withAlpha(140),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        _diffLabels[exercise.difficulty] ?? exercise.difficulty,
                        style: const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.w600),
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                      decoration: BoxDecoration(
                        color: Colors.black.withAlpha(50),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        equipmentLabel(exercise.equipment),
                        style: const TextStyle(color: Colors.white, fontSize: 11),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),

          const SizedBox(height: 20),

          // Qanday bajariladi
          Container(
            padding: const EdgeInsets.all(18),
            decoration: BoxDecoration(
              color: isDark ? const Color(0xFF161F1A) : Colors.white,
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: isDark ? Colors.white10 : Colors.black.withAlpha(10)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(6),
                      decoration: BoxDecoration(
                        color: kGreen.withAlpha(isDark ? 40 : 25),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: const Icon(Icons.info_outline_rounded, color: kGreen, size: 18),
                    ),
                    const SizedBox(width: 10),
                    const Text(
                      "Qanday bajariladi",
                      style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Text(
                  exercise.description,
                  style: TextStyle(
                    fontSize: 14,
                    height: 1.5,
                    color: isDark ? Colors.grey.shade300 : Colors.grey.shade800,
                  ),
                ),
                if (exercise.durationHint != null) ...[
                  const Divider(height: 28),
                  Row(
                    children: [
                      const Icon(Icons.timer_outlined, color: Colors.blue, size: 20),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          "Namunaviy hajm: ${exercise.durationHint!}",
                          style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13.5),
                        ),
                      ),
                    ],
                  ),
                ],
              ],
            ),
          ),

          const SizedBox(height: 16),

          // Xavfsizlik ko'rsatmasi
          SafetyBanner(text: exercise.safetyNote),

          const SizedBox(height: 24),

          // Rejaga qo'shish tugmasi
          FilledButton.icon(
            onPressed: () => _addToPlan(context),
            icon: const Icon(Icons.event_available_rounded),
            label: const Text(
              "Rejaga qo'shish",
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
            ),
            style: FilledButton.styleFrom(
              backgroundColor: kGreen,
              minimumSize: const Size.fromHeight(52),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            ),
          ),
          const SizedBox(height: 20),
        ],
      ),
    );
  }
}

/// Mashq tanlash oynasi (reja va seans uchun)
Future<Exercise?> pickExercise(BuildContext context, {required String mode}) => showModalBottomSheet<Exercise>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      backgroundColor: Theme.of(context).brightness == Brightness.dark ? const Color(0xFF141C17) : Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) => SizedBox(
        height: MediaQuery.of(ctx).size.height * 0.88,
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 8),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    "Mashq tanlang (${modeLabels[mode]})",
                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close_rounded),
                    onPressed: () => Navigator.pop(ctx),
                  ),
                ],
              ),
            ),
            Expanded(child: ExerciseList(mode: mode, onPick: (e) => Navigator.pop(ctx, e))),
          ],
        ),
      ),
    );
