import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../api_client.dart';
import '../app_state.dart';
import '../models.dart';
import '../ui.dart';
import 'catalog_screens.dart';
import 'session_screens.dart';

/// Mashqni sanaga mos faol rejaga qo'shadi; reja bo'lmasa o'sha hafta uchun avtomatik yaratadi.
Future<void> addExerciseToPlan(ApiClient api, Exercise ex, DateTime date, int minutes) async {
  final plans = (await api.get('/plans') as List).map((e) => Plan.fromJson(Map<String, dynamic>.from(e))).toList();
  Plan? target;
  for (final p in plans) {
    if (p.status == 'active' && p.covers(date)) {
      target = p;
      break;
    }
  }
  int planId;
  if (target != null) {
    planId = target.id;
  } else {
    final monday = mondayOf(date);
    final created = await api.post(
      '/plans',
      body: {
        'title': "Haftalik reja",
        'starts_on': isoDate(monday),
        'ends_on': isoDate(monday.add(const Duration(days: 6))),
      },
    );
    planId = created['id'];
  }
  await api.post(
    '/plans/$planId/items',
    body: {
      'exercise_id': ex.id,
      'planned_date': isoDate(date),
      'planned_minutes': minutes,
    },
  );
}

class _WeekData {
  _WeekData(this.plans);
  final List<Plan> plans; // elementlari bilan
  List<PlanItem> itemsOn(DateTime d) => [for (final p in plans) for (final i in p.items) if (sameDay(i.date, d)) i];
  Plan? planOf(PlanItem item) => plans.cast<Plan?>().firstWhere((p) => p!.items.any((i) => i.id == item.id), orElse: () => null);
}

/// S10 Reja / kalendar (S11: reja yaratish va mashq qo'shish/olib tashlash shu yerda)
class PlannerScreen extends StatefulWidget {
  const PlannerScreen({super.key});
  @override
  State<PlannerScreen> createState() => _PlannerScreenState();
}

class _PlannerScreenState extends State<PlannerScreen> {
  DateTime _monday = mondayOf(DateTime.now());
  int _epoch = 0; // Loader'ni qayta qurish uchun

  Future<_WeekData> _load() async {
    final api = context.read<AppState>().api;
    final brief = (await api.get('/plans') as List).map((e) => Plan.fromJson(Map<String, dynamic>.from(e))).toList();
    final end = _monday.add(const Duration(days: 6));
    final overlapping = brief.where((p) => p.status == 'active' && !p.endsOn.isBefore(_monday) && !p.startsOn.isAfter(end));
    final full = await Future.wait(overlapping.map((p) async => Plan.fromJson(Map<String, dynamic>.from(await api.get('/plans/${p.id}')))));
    return _WeekData(full);
  }

  void _refresh() => setState(() => _epoch++);

  Future<void> _newPlan() async {
    final title = TextEditingController(text: "Haftalik reja");
    DateTime start = _monday;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => StatefulBuilder(
        builder: (ctx, setS) => AlertDialog(
          backgroundColor: isDark ? const Color(0xFF161F1A) : Colors.white,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(22)),
          title: const Text("Yangi haftalik reja", style: TextStyle(fontWeight: FontWeight.bold)),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: title,
                decoration: InputDecoration(
                  labelText: "Reja nomi",
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(14)),
                ),
              ),
              const SizedBox(height: 12),
              InkWell(
                onTap: () async {
                  final d = await showDatePicker(
                    context: ctx,
                    initialDate: start,
                    firstDate: DateTime.now().subtract(const Duration(days: 30)),
                    lastDate: DateTime.now().add(const Duration(days: 365)),
                  );
                  if (d != null) setS(() => start = mondayOf(d));
                },
                borderRadius: BorderRadius.circular(14),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                  decoration: BoxDecoration(
                    color: isDark ? Colors.white10 : Colors.black.withAlpha(8),
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.event_rounded, color: kGreen),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              "Boshlanish: ${fmtDate(start)}",
                              style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13.5),
                            ),
                            const Text(
                              "7 kunlik reja davri",
                              style: TextStyle(fontSize: 11, color: Colors.grey),
                            ),
                          ],
                        ),
                      ),
                      const Icon(Icons.edit_calendar_rounded, size: 20, color: kGreen),
                    ],
                  ),
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text("Bekor qilish"),
            ),
            FilledButton(
              style: FilledButton.styleFrom(
                backgroundColor: kGreen,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text("Yaratish", style: TextStyle(fontWeight: FontWeight.bold)),
            ),
          ],
        ),
      ),
    );
    if (ok != true || title.text.trim().isEmpty) return;
    try {
      await context.read<AppState>().api.post(
        '/plans',
        body: {
          'title': title.text.trim(),
          'starts_on': isoDate(start),
          'ends_on': isoDate(start.add(const Duration(days: 6))),
        },
      );
      setState(() {
        _monday = mondayOf(start);
        _epoch++;
      });
    } on ApiException catch (e) {
      if (mounted) toast(context, e.message);
    }
  }

  Future<void> _addTo(DateTime day) async {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final mode = await showModalBottomSheet<String>(
      context: context,
      backgroundColor: isDark ? const Color(0xFF161F1A) : Colors.white,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(22))),
      builder: (ctx) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 12),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Padding(
                padding: const EdgeInsets.all(12),
                child: Text(
                  "Mashq turini tanlang (${weekdays[day.weekday - 1]})",
                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                ),
              ),
              ListTile(
                leading: const ModuleBadge('home'),
                title: const Text("Home mashqlari (Uyda)", style: TextStyle(fontWeight: FontWeight.w600)),
                trailing: const Icon(Icons.chevron_right_rounded),
                onTap: () => Navigator.pop(ctx, 'home'),
              ),
              ListTile(
                leading: const ModuleBadge('gym'),
                title: const Text("Gym mashqlari (Sport zalida)", style: TextStyle(fontWeight: FontWeight.w600)),
                trailing: const Icon(Icons.chevron_right_rounded),
                onTap: () => Navigator.pop(ctx, 'gym'),
              ),
            ],
          ),
        ),
      ),
    );
    if (mode == null || !mounted) return;
    final ex = await pickExercise(context, mode: mode);
    if (ex == null || !mounted) return;
    try {
      await addExerciseToPlan(context.read<AppState>().api, ex, day, 15);
      _refresh();
    } on ApiException catch (e) {
      if (mounted) toast(context, e.message);
    }
  }

  Future<void> _removeItem(_WeekData data, PlanItem item) async {
    final plan = data.planOf(item);
    if (plan == null || !await confirm(context, "Olib tashlash", "\"${item.exercise.title}\" rejadan olib tashlansinmi?")) return;
    try {
      await context.read<AppState>().api.delete('/plans/${plan.id}/items/${item.id}');
      _refresh();
    } on ApiException catch (e) {
      if (mounted) toast(context, e.message);
    }
  }

  Future<void> _deletePlan(Plan p) async {
    if (!await confirm(context, "Rejani o'chirish", "\"${p.title}\" rejasi o'chiriladi. Bajarilgan mashg'ulotlar tarixi saqlanadi.")) return;
    try {
      await context.read<AppState>().api.delete('/plans/${p.id}');
      _refresh();
    } on ApiException catch (e) {
      if (mounted) toast(context, e.message);
    }
  }

  @override
  Widget build(BuildContext context) {
    final end = _monday.add(const Duration(days: 6));
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final isCurrentWeek = sameDay(_monday, mondayOf(DateTime.now()));

    return Scaffold(
      backgroundColor: isDark ? const Color(0xFF0F1512) : const Color(0xFFF7FAF8),
      appBar: AppBar(
        title: const Text(
          "Haftalik reja",
          style: TextStyle(fontWeight: FontWeight.w800, fontSize: 20),
        ),
        elevation: 0,
        backgroundColor: isDark ? const Color(0xFF141C17) : Colors.white,
      ),
      floatingActionButton: FloatingActionButton.extended(
        backgroundColor: kGreen,
        foregroundColor: Colors.white,
        elevation: 4,
        onPressed: _newPlan,
        icon: const Icon(Icons.add_rounded, size: 22),
        label: const Text("Yangi reja", style: TextStyle(fontWeight: FontWeight.bold)),
      ),
      body: Column(
        children: [
          // Hafta almashtirgich
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
            decoration: BoxDecoration(
              color: isDark ? const Color(0xFF141C17) : Colors.white,
              border: Border(
                bottom: BorderSide(
                  color: isDark ? Colors.white10 : Colors.black.withAlpha(10),
                  width: 0.8,
                ),
              ),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                IconButton(
                  style: IconButton.styleFrom(
                    backgroundColor: isDark ? const Color(0xFF1F2922) : const Color(0xFFF0F4F1),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                  ),
                  icon: const Icon(Icons.chevron_left_rounded, size: 22),
                  onPressed: () => setState(() => _monday = _monday.subtract(const Duration(days: 7))),
                ),
                Column(
                  children: [
                    Text(
                      "${fmtDate(_monday)} – ${fmtDate(end)}",
                      style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 15),
                    ),
                    if (isCurrentWeek)
                      Container(
                        margin: const EdgeInsets.only(top: 2),
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1.5),
                        decoration: BoxDecoration(
                          color: kGreen.withAlpha(isDark ? 40 : 25),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: const Text(
                          "Joriy hafta",
                          style: TextStyle(fontSize: 10.5, color: kGreen, fontWeight: FontWeight.bold),
                        ),
                      ),
                  ],
                ),
                IconButton(
                  style: IconButton.styleFrom(
                    backgroundColor: isDark ? const Color(0xFF1F2922) : const Color(0xFFF0F4F1),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                  ),
                  icon: const Icon(Icons.chevron_right_rounded, size: 22),
                  onPressed: () => setState(() => _monday = _monday.add(const Duration(days: 7))),
                ),
              ],
            ),
          ),

          // Rejalar va kunlar ro'yxati
          Expanded(
            child: Loader<_WeekData>(
              key: ValueKey('$_monday-$_epoch'),
              load: _load,
              builder: (context, data, reload) => RefreshIndicator(
                onRefresh: reload,
                color: kGreen,
                child: ListView(
                  padding: const EdgeInsets.fromLTRB(16, 12, 16, 95),
                  children: [
                    for (final p in data.plans)
                      Container(
                        margin: const EdgeInsets.only(bottom: 10),
                        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                        decoration: BoxDecoration(
                          color: isDark ? const Color(0xFF161F1A) : Colors.white,
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(color: isDark ? Colors.white10 : Colors.black.withAlpha(10)),
                        ),
                        child: Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.all(8),
                              decoration: BoxDecoration(
                                color: kGreen.withAlpha(isDark ? 40 : 25),
                                borderRadius: BorderRadius.circular(10),
                              ),
                              child: const Icon(Icons.assignment_outlined, color: kGreen, size: 20),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    p.title,
                                    style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 14),
                                  ),
                                  Text(
                                    "${fmtDate(p.startsOn)} – ${fmtDate(p.endsOn)}",
                                    style: TextStyle(fontSize: 11.5, color: isDark ? Colors.grey.shade400 : Colors.grey.shade600),
                                  ),
                                ],
                              ),
                            ),
                            IconButton(
                              icon: const Icon(Icons.delete_outline_rounded, size: 20, color: Colors.redAccent),
                              onPressed: () => _deletePlan(p),
                            ),
                          ],
                        ),
                      ),

                    if (data.plans.isEmpty)
                      Container(
                        margin: const EdgeInsets.only(bottom: 12),
                        padding: const EdgeInsets.all(14),
                        decoration: BoxDecoration(
                          color: isDark ? const Color(0xFF161F1A) : Colors.white,
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(color: isDark ? Colors.white10 : Colors.black.withAlpha(10)),
                        ),
                        child: Row(
                          children: [
                            const Icon(Icons.info_outline_rounded, color: kGreen, size: 22),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Text(
                                "Bu hafta uchun reja yo'q. Istalgan kunga mashq qo'shsangiz reja avtomatik yaratiladi.",
                                style: TextStyle(fontSize: 12.5, color: isDark ? Colors.grey.shade300 : Colors.grey.shade700),
                              ),
                            ),
                          ],
                        ),
                      ),

                    for (var i = 0; i < 7; i++)
                      _dayCard(context, data, _monday.add(Duration(days: i)), isDark),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _dayCard(BuildContext context, _WeekData data, DateTime day, bool isDark) {
    final items = data.itemsOn(day);
    final today = sameDay(day, DateTime.now());

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      decoration: BoxDecoration(
        color: today
            ? (isDark ? kGreen.withAlpha(35) : const Color(0xFFE8F5E9))
            : (isDark ? const Color(0xFF161F1A) : Colors.white),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: today ? kGreen : (isDark ? Colors.white10 : Colors.black.withAlpha(10)),
          width: today ? 1.8 : 1,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withAlpha(isDark ? 15 : 5),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Row(
                    children: [
                      Text(
                        "${weekdays[day.weekday - 1]}, ${two(day.day)}.${two(day.month)}",
                        style: TextStyle(
                          fontWeight: today ? FontWeight.w800 : FontWeight.w700,
                          fontSize: 14.5,
                          color: today ? (isDark ? Colors.white : kGreen) : (isDark ? Colors.white : Colors.black87),
                        ),
                      ),
                      if (today) ...[
                        const SizedBox(width: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                          decoration: BoxDecoration(
                            color: kGreen,
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: const Text(
                            "Bugun",
                            style: TextStyle(color: Colors.white, fontSize: 10.5, fontWeight: FontWeight.bold),
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
                IconButton(
                  visualDensity: VisualDensity.compact,
                  tooltip: "Mashq qo'shish",
                  icon: const Icon(Icons.add_circle_outline_rounded, color: kGreen, size: 22),
                  onPressed: () => _addTo(day),
                ),
              ],
            ),
            if (items.isEmpty)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 4),
                child: Text(
                  "Dam olish / Reja belgilanmagan",
                  style: TextStyle(
                    fontSize: 12,
                    color: isDark ? Colors.grey.shade500 : Colors.grey.shade500,
                    fontStyle: FontStyle.italic,
                  ),
                ),
              ),
            for (final it in items)
              Container(
                margin: const EdgeInsets.only(top: 8),
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                decoration: BoxDecoration(
                  color: isDark ? Colors.white.withAlpha(12) : const Color(0xFFF5F7F6),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Row(
                  children: [
                    it.isCompleted
                        ? const Icon(Icons.check_circle_rounded, color: Colors.green, size: 22)
                        : ModuleBadge(it.exercise.mode),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            it.exercise.title,
                            style: TextStyle(
                              fontWeight: FontWeight.w600,
                              fontSize: 13.5,
                              decoration: it.isCompleted ? TextDecoration.lineThrough : null,
                              color: isDark ? Colors.white : Colors.black87,
                            ),
                          ),
                          Text(
                            "${it.minutes} daqiqa",
                            style: TextStyle(fontSize: 11.5, color: isDark ? Colors.grey.shade400 : Colors.grey.shade600),
                          ),
                        ],
                      ),
                    ),
                    if (!it.isCompleted)
                      IconButton(
                        tooltip: "Boshlash",
                        icon: const Icon(Icons.play_circle_fill_rounded, color: kGreen, size: 26),
                        onPressed: () async {
                          await startSession(context, it.exercise.mode, plan: data.planOf(it), item: it);
                          _refresh();
                        },
                      ),
                    IconButton(
                      tooltip: "Olib tashlash",
                      icon: const Icon(Icons.close_rounded, size: 18, color: Colors.grey),
                      onPressed: () => _removeItem(data, it),
                    ),
                  ],
                ),
              ),
          ],
        ),
      ),
    );
  }
}
