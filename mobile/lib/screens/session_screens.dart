import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../api_client.dart';
import '../app_state.dart';
import '../models.dart';
import '../ui.dart';
import 'catalog_screens.dart';

/// S12: seansni boshlaydi (yoki mavjud tugallanmagan seansni davom ettiradi) va S13 ekranini ochadi.
Future<void> startSession(BuildContext context, String mode, {Plan? plan, PlanItem? item}) async {
  final api = context.read<AppState>().api;
  try {
    final open = await api.get('/sessions', query: {'status': 'in_progress', 'mode': mode, 'limit': 1}) as List;
    int id;
    if (open.isNotEmpty) {
      id = open.first['id'];
      if (context.mounted) {
        toast(context, "Tugallanmagan ${modeLabels[mode]} seansi davom ettirildi");
      }
    } else {
      final s = await api.post('/sessions', body: {'mode': mode, if (plan != null) 'plan_id': plan.id});
      id = s['id'];
    }
    if (context.mounted) {
      await Navigator.push(context, MaterialPageRoute(builder: (_) => SessionScreen(sessionId: id, focus: item)));
    }
  } on ApiException catch (e) {
    if (context.mounted) toast(context, e.message);
  }
}

class _SessionData {
  _SessionData(this.session, this.planned);
  final Session session;
  final List<PlanItem> planned;
}

/// S13 Seans davomida qayd
class SessionScreen extends StatefulWidget {
  const SessionScreen({super.key, required this.sessionId, this.focus});
  final int sessionId;
  final PlanItem? focus;
  @override
  State<SessionScreen> createState() => _SessionScreenState();
}

class _SessionScreenState extends State<SessionScreen> {
  int _epoch = 0;
  DateTime? _started;

  Future<_SessionData> _load() async {
    final api = context.read<AppState>().api;
    final s = Session.fromJson(Map<String, dynamic>.from(await api.get('/sessions/${widget.sessionId}')));
    var planned = <PlanItem>[];
    if (s.planId != null) {
      final plan = Plan.fromJson(Map<String, dynamic>.from(await api.get('/plans/${s.planId}')));
      planned = plan.items.where((i) => i.exercise.mode == s.mode && !i.isCompleted && (sameDay(i.date, DateTime.now()) || i.id == widget.focus?.id)).toList();
    }
    return _SessionData(s, planned);
  }

  Future<void> _log(Session s, Exercise ex, {int? planItemId}) async {
    final nextSet = s.logs.where((l) => l.exercise.id == ex.id).length + 1;
    final ok = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _LogSheet(session: s, exercise: ex, nextSet: nextSet, planItemId: planItemId),
    );
    if (ok == true) setState(() => _epoch++);
  }

  Future<void> _add(Session s) async {
    final ex = await pickExercise(context, mode: s.mode);
    if (ex != null) await _log(s, ex);
  }

  Future<void> _deleteLog(Session s, LogEntry l) async {
    try {
      await context.read<AppState>().api.delete('/sessions/${s.id}/logs/${l.id}');
      setState(() => _epoch++);
    } on ApiException catch (e) {
      if (mounted) toast(context, e.message);
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Material(
      child: Loader<_SessionData>(
        key: ValueKey(_epoch),
        load: _load,
        builder: (context, d, reload) {
          final s = d.session;
          _started = s.startedAt;
          final byExercise = <int, List<LogEntry>>{};
          for (final l in s.logs) {
            byExercise.putIfAbsent(l.exercise.id, () => []).add(l);
          }

          return Scaffold(
            backgroundColor: isDark ? const Color(0xFF0F1512) : const Color(0xFFF7FAF8),
            appBar: AppBar(
              title: Text(
                "${modeLabels[s.mode]} seansi",
                style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 18),
              ),
              elevation: 0,
              backgroundColor: isDark ? const Color(0xFF141C17) : Colors.white,
              actions: [
                Container(
                  margin: const EdgeInsets.only(right: 16),
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                  decoration: BoxDecoration(
                    color: kGreen.withAlpha(isDark ? 45 : 25),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.timer_outlined, size: 16, color: kGreen),
                      const SizedBox(width: 6),
                      Elapsed(_started!),
                    ],
                  ),
                ),
              ],
            ),
            floatingActionButton: FloatingActionButton.extended(
              backgroundColor: kGreen,
              foregroundColor: Colors.white,
              elevation: 4,
              onPressed: () => _add(s),
              icon: const Icon(Icons.add_rounded, size: 22),
              label: const Text("Mashq qo'shish", style: TextStyle(fontWeight: FontWeight.bold)),
            ),
            body: ListView(
              padding: const EdgeInsets.fromLTRB(16, 14, 16, 110),
              children: [
                // Rejadagi mashqlar
                if (d.planned.isNotEmpty) ...[
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text(
                        "Rejadagi mashqlar",
                        style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
                      ),
                      Text(
                        "${d.planned.length} ta mashq",
                        style: TextStyle(fontSize: 12, color: isDark ? Colors.grey.shade400 : Colors.grey.shade600),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  for (final it in d.planned) ...[
                    Container(
                      margin: const EdgeInsets.only(bottom: 10),
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: isDark ? const Color(0xFF161F1A) : Colors.white,
                        borderRadius: BorderRadius.circular(18),
                        border: Border.all(
                          color: s.logs.any((l) => l.planItemId == it.id)
                              ? Colors.green.withAlpha(100)
                              : (isDark ? Colors.white10 : Colors.black.withAlpha(10)),
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withAlpha(isDark ? 15 : 5),
                            blurRadius: 8,
                            offset: const Offset(0, 2),
                          ),
                        ],
                      ),
                      child: Row(
                        children: [
                          ModuleBadge(it.exercise.mode),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  it.exercise.title,
                                  style: TextStyle(
                                    fontWeight: FontWeight.w700,
                                    fontSize: 14.5,
                                    color: isDark ? Colors.white : Colors.black87,
                                  ),
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  s.logs.any((l) => l.planItemId == it.id)
                                      ? "Qayd etildi · Yana yondashuv qo'shish mumkin"
                                      : "${it.minutes} daqiqa rejalashtirilgan",
                                  style: TextStyle(
                                    fontSize: 11.5,
                                    color: s.logs.any((l) => l.planItemId == it.id)
                                        ? Colors.green
                                        : (isDark ? Colors.grey.shade400 : Colors.grey.shade600),
                                  ),
                                ),
                              ],
                            ),
                          ),
                          IconButton(
                            tooltip: "Qanday bajariladi (GIF)",
                            icon: const Icon(Icons.play_circle_fill_rounded, color: kGreen),
                            onPressed: () => Navigator.push(
                              context,
                              MaterialPageRoute(builder: (_) => ExerciseDetailScreen(exercise: it.exercise)),
                            ),
                          ),
                          FilledButton.tonal(
                            style: FilledButton.styleFrom(
                              backgroundColor: kGreen.withAlpha(isDark ? 45 : 30),
                              foregroundColor: kGreen,
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                            ),
                            onPressed: () => _log(s, it.exercise, planItemId: it.id),
                            child: const Text("Qayd etish", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                          ),
                        ],
                      ),
                    ),
                  ],
                  const SizedBox(height: 14),
                ],

                // Bajarilgan qaydlar sarlavhasi
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text(
                      "Bajarilgan qaydlar",
                      style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
                    ),
                    if (s.logs.isNotEmpty)
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                        decoration: BoxDecoration(
                          color: kGreen.withAlpha(isDark ? 40 : 25),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(
                          "${s.logs.length} ta yondashuv",
                          style: const TextStyle(color: kGreen, fontWeight: FontWeight.w700, fontSize: 11),
                        ),
                      ),
                  ],
                ),
                const SizedBox(height: 10),

                if (s.logs.isEmpty)
                  Container(
                    padding: const EdgeInsets.symmetric(vertical: 36, horizontal: 20),
                    decoration: BoxDecoration(
                      color: isDark ? const Color(0xFF161F1A) : Colors.white,
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(color: isDark ? Colors.white10 : Colors.black.withAlpha(10)),
                    ),
                    child: Column(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(14),
                          decoration: BoxDecoration(
                            color: isDark ? Colors.white10 : Colors.black.withAlpha(10),
                            shape: BoxShape.circle,
                          ),
                          child: Icon(Icons.fitness_center_rounded, size: 32, color: isDark ? Colors.grey.shade400 : Colors.grey.shade600),
                        ),
                        const SizedBox(height: 12),
                        const Text(
                          "Hozircha hech qanday qayd yo'q",
                          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          "Rejadagi mashqni bosing yoki pastdagi \"Mashq qo'shish\" tugmasidan foydalaning.",
                          textAlign: TextAlign.center,
                          style: TextStyle(fontSize: 12.5, color: isDark ? Colors.grey.shade400 : Colors.grey.shade600),
                        ),
                      ],
                    ),
                  )
                else
                  for (final entry in byExercise.entries)
                    Container(
                      margin: const EdgeInsets.only(bottom: 12),
                      decoration: BoxDecoration(
                        color: isDark ? const Color(0xFF161F1A) : Colors.white,
                        borderRadius: BorderRadius.circular(18),
                        border: Border.all(color: isDark ? Colors.white10 : Colors.black.withAlpha(10)),
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
                          Padding(
                            padding: const EdgeInsets.fromLTRB(14, 12, 14, 8),
                            child: Row(
                              children: [
                                ModuleBadge(entry.value.first.exercise.mode),
                                const SizedBox(width: 10),
                                Expanded(
                                  child: Text(
                                    entry.value.first.exercise.title,
                                    style: TextStyle(
                                      fontWeight: FontWeight.w800,
                                      fontSize: 15,
                                      color: isDark ? Colors.white : Colors.black87,
                                    ),
                                  ),
                                ),
                                IconButton(
                                  tooltip: "Yondashuv qo'shish",
                                  icon: const Icon(Icons.add_circle_outline_rounded, color: kGreen),
                                  onPressed: () => _log(s, entry.value.first.exercise),
                                ),
                              ],
                            ),
                          ),
                          const Divider(height: 1),
                          for (final l in entry.value)
                            Padding(
                              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                              child: Row(
                                children: [
                                  Container(
                                    padding: const EdgeInsets.all(4),
                                    decoration: BoxDecoration(
                                      color: Colors.green.withAlpha(isDark ? 40 : 25),
                                      shape: BoxShape.circle,
                                    ),
                                    child: const Icon(Icons.check, size: 14, color: Colors.green),
                                  ),
                                  const SizedBox(width: 12),
                                  Expanded(
                                    child: Text(
                                      l.summary,
                                      style: TextStyle(
                                        fontSize: 13.5,
                                        fontWeight: FontWeight.w500,
                                        color: isDark ? Colors.grey.shade300 : Colors.grey.shade800,
                                      ),
                                    ),
                                  ),
                                  IconButton(
                                    icon: const Icon(Icons.delete_outline_rounded, size: 18, color: Colors.redAccent),
                                    onPressed: () => _deleteLog(s, l),
                                  ),
                                ],
                              ),
                            ),
                        ],
                      ),
                    ),

                const SizedBox(height: 20),

                // Seansni yakunlash tugmasi
                FilledButton.icon(
                  icon: const Icon(Icons.flag_rounded),
                  label: const Text(
                    "Seansni yakunlash",
                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                  ),
                  style: FilledButton.styleFrom(
                    backgroundColor: kGreen,
                    minimumSize: const Size.fromHeight(54),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                    elevation: 3,
                  ),
                  onPressed: () async {
                    final done = await Navigator.push<bool>(
                      context,
                      MaterialPageRoute(builder: (_) => FinishScreen(sessionId: s.id)),
                    );
                    if (done == true && mounted) Navigator.pop(context);
                  },
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}

class _LogSheet extends StatefulWidget {
  const _LogSheet({required this.session, required this.exercise, required this.nextSet, this.planItemId});
  final Session session;
  final Exercise exercise;
  final int nextSet;
  final int? planItemId;
  @override
  State<_LogSheet> createState() => _LogSheetState();
}

class _LogSheetState extends State<_LogSheet> {
  late final _set = TextEditingController(text: '${widget.nextSet}');
  final _reps = TextEditingController(), _weight = TextEditingController(), _secs = TextEditingController();
  final _key = newKey(); // takror bosishdan himoya (Idempotency-Key)
  bool _busy = false;
  String? _error;

  @override
  void dispose() {
    _set.dispose();
    _reps.dispose();
    _weight.dispose();
    _secs.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final set = int.tryParse(_set.text);
    final reps = _reps.text.trim().isEmpty ? null : int.tryParse(_reps.text);
    final secs = _secs.text.trim().isEmpty ? null : int.tryParse(_secs.text);
    final weight = _weight.text.trim().isEmpty ? null : double.tryParse(_weight.text.replaceAll(',', '.'));
    if (set == null || set < 1) return setState(() => _error = "Yondashuv raqami 1 yoki undan katta bo'lsin");
    if (reps == null && secs == null) return setState(() => _error = "Takror yoki vaqt (soniya) kiriting");
    if ((reps != null && reps < 1) || (secs != null && secs < 1)) return setState(() => _error = "Qiymatlar 0 dan katta bo'lishi kerak");
    if (_weight.text.trim().isNotEmpty && (weight == null || weight < 0)) return setState(() => _error = "Vazn manfiy bo'lmasin");
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await context.read<AppState>().api.post(
        '/sessions/${widget.session.id}/logs',
        headers: {'Idempotency-Key': _key},
        body: {
          'exercise_id': widget.exercise.id,
          'set_no': set,
          'reps': reps,
          'duration_seconds': secs,
          if (weight != null) 'weight_kg': weight,
          if (widget.planItemId != null) 'plan_item_id': widget.planItemId,
        },
      );
      if (mounted) Navigator.pop(context, true);
    } on ApiException catch (e) {
      if (mounted) {
        setState(() {
          _error = e.message;
          _busy = false;
        });
      }
    }
  }

  Widget _inputField(TextEditingController c, String label, {bool decimal = false}) => Expanded(
        child: TextField(
          controller: c,
          keyboardType: TextInputType.numberWithOptions(decimal: decimal),
          decoration: InputDecoration(
            labelText: label,
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(14)),
            contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          ),
        ),
      );

  @override
  Widget build(BuildContext context) {
    final gym = widget.session.mode == 'gym';
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Container(
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF161F1A) : Colors.white,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
      ),
      padding: EdgeInsets.fromLTRB(20, 20, 20, 24 + MediaQuery.of(context).viewInsets.bottom),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Center(
            child: Container(
              width: 38,
              height: 4,
              decoration: BoxDecoration(
                color: Colors.grey.shade400,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
          const SizedBox(height: 16),
          Text(
            widget.exercise.title,
            style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 4),
          Text(
            gym ? "Yondashuv, takror va vazn (ixtiyoriy)" : "Takror yoki davomiylik (soniya)",
            style: TextStyle(
              fontSize: 12.5,
              color: isDark ? Colors.grey.shade400 : Colors.grey.shade600,
            ),
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              _inputField(_set, "Yondashuv №"),
              const SizedBox(width: 10),
              _inputField(_reps, "Takror soni"),
            ],
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              if (gym) ...[
                _inputField(_weight, "Vazn (kg)", decimal: true),
                const SizedBox(width: 10),
              ],
              _inputField(_secs, "Vaqt (soniya)"),
            ],
          ),
          // Tezkor takror tugmalari
          const SizedBox(height: 12),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [8, 10, 12, 15].map((r) {
              return InkWell(
                onTap: () => _reps.text = '$r',
                borderRadius: BorderRadius.circular(8),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                  decoration: BoxDecoration(
                    color: isDark ? Colors.white10 : Colors.black.withAlpha(8),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text("$r ta", style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600)),
                ),
              );
            }).toList(),
          ),
          if (_error != null)
            Padding(
              padding: const EdgeInsets.only(top: 10),
              child: Text(
                _error!,
                style: const TextStyle(color: Colors.redAccent, fontSize: 12.5),
              ),
            ),
          const SizedBox(height: 20),
          FilledButton(
            onPressed: _busy ? null : _save,
            style: FilledButton.styleFrom(
              backgroundColor: kGreen,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
              minimumSize: const Size.fromHeight(50),
            ),
            child: _busy
                ? const SizedBox(width: 22, height: 22, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                : const Text("Yondashuvni saqlash", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
          ),
        ],
      ),
    );
  }
}

/// S15 Seans yakuni
class FinishScreen extends StatefulWidget {
  const FinishScreen({super.key, required this.sessionId});
  final int sessionId;
  @override
  State<FinishScreen> createState() => _FinishScreenState();
}

class _FinishScreenState extends State<FinishScreen> {
  final _notes = TextEditingController();
  bool _busy = false;

  @override
  void dispose() {
    _notes.dispose();
    super.dispose();
  }

  Future<void> _end(String status) async {
    setState(() => _busy = true);
    try {
      await context.read<AppState>().api.patch(
        '/sessions/${widget.sessionId}',
        body: {'status': status, if (_notes.text.trim().isNotEmpty) 'notes': _notes.text.trim()},
      );
      if (!mounted) return;
      toast(
        context,
        status == 'completed' ? "Mashg'ulot saqlandi. Barakalla! 🎉" : "Seans to'xtatildi",
      );
      Navigator.pop(context, true);
    } on ApiException catch (e) {
      if (mounted) {
        setState(() => _busy = false);
        toast(context, e.message);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: isDark ? const Color(0xFF0F1512) : const Color(0xFFF7FAF8),
      appBar: AppBar(
        title: const Text("Seans yakuni"),
        elevation: 0,
        backgroundColor: Colors.transparent,
      ),
      body: Loader<Session>(
        load: () async => Session.fromJson(Map<String, dynamic>.from(await context.read<AppState>().api.get('/sessions/${widget.sessionId}'))),
        builder: (context, s, _) {
          final exercises = {for (final l in s.logs) l.exercise.title}.length;
          final mins = DateTime.now().difference(s.startedAt).inMinutes;

          return ListView(
            padding: const EdgeInsets.all(18),
            children: [
              // Tabrik / Natija Header
              Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(22),
                  gradient: const LinearGradient(
                    colors: [Color(0xFF16803C), Color(0xFF0A4020)],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: kGreen.withAlpha(70),
                      blurRadius: 16,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: Column(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        color: Colors.white.withAlpha(35),
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(Icons.emoji_events_rounded, color: Colors.amber, size: 40),
                    ),
                    const SizedBox(height: 12),
                    const Text(
                      "Ajoyib mashg'ulot!",
                      style: TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.w800,
                        color: Colors.white,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      "Bugungi maqsadingizga yana bir qadam yaqinlashdingiz.",
                      textAlign: TextAlign.center,
                      style: TextStyle(fontSize: 13, color: Colors.white.withAlpha(200)),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 18),

              // 3 ta ko'rsatkich bloki
              Row(
                children: [
                  _statTile(
                    title: "Davomiylik",
                    value: fmtMinutes(mins),
                    icon: Icons.timer_outlined,
                    color: Colors.purple,
                    isDark: isDark,
                  ),
                  const SizedBox(width: 10),
                  _statTile(
                    title: "Mashqlar",
                    value: '$exercises ta',
                    icon: Icons.list_alt_rounded,
                    color: Colors.indigo,
                    isDark: isDark,
                  ),
                  const SizedBox(width: 10),
                  _statTile(
                    title: "Yondashuv",
                    value: '${s.logs.length} ta',
                    icon: Icons.repeat_rounded,
                    color: Colors.orange,
                    isDark: isDark,
                  ),
                ],
              ),

              const SizedBox(height: 20),

              // Qaydlar maydoni
              TextField(
                controller: _notes,
                maxLines: 3,
                maxLength: 1000,
                decoration: InputDecoration(
                  labelText: "Mashg'ulot bo'yicha qaydlaringiz (ixtiyoriy)",
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(16)),
                  filled: true,
                  fillColor: isDark ? const Color(0xFF161F1A) : Colors.white,
                ),
              ),

              const SizedBox(height: 12),

              if (s.logs.isEmpty)
                Container(
                  margin: const EdgeInsets.only(bottom: 14),
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.orange.withAlpha(25),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: Colors.orange.withAlpha(60)),
                  ),
                  child: const Row(
                    children: [
                      Icon(Icons.warning_amber_rounded, color: Colors.orange, size: 20),
                      SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          "Seansni saqlash uchun kamida 1 ta mashq qayd etilgan bo'lishi kerak.",
                          style: TextStyle(color: Colors.orange, fontSize: 12.5),
                        ),
                      ),
                    ],
                  ),
                ),

              // Saqlash va yakunlash
              FilledButton(
                onPressed: _busy || s.logs.isEmpty ? null : () => _end('completed'),
                style: FilledButton.styleFrom(
                  backgroundColor: kGreen,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                  minimumSize: const Size.fromHeight(52),
                ),
                child: _busy
                    ? const SizedBox(width: 22, height: 22, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                    : const Text(
                        "Saqlash va yakunlash",
                        style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                      ),
              ),

              const SizedBox(height: 10),

              OutlinedButton(
                onPressed: _busy
                    ? null
                    : () async {
                        if (await confirm(context, "Seansni to'xtatish", "Seans progressga qo'shilmaydi. Davom etasizmi?")) {
                          _end('interrupted');
                        }
                      },
                style: OutlinedButton.styleFrom(
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                  minimumSize: const Size.fromHeight(50),
                ),
                child: const Text("Saqlamasdan to'xtatish", style: TextStyle(color: Colors.grey)),
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _statTile({
    required String title,
    required String value,
    required IconData icon,
    required Color color,
    required bool isDark,
  }) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 8),
        decoration: BoxDecoration(
          color: isDark ? const Color(0xFF161F1A) : Colors.white,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: isDark ? Colors.white10 : Colors.black.withAlpha(10)),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withAlpha(isDark ? 15 : 5),
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Column(
          children: [
            Container(
              padding: const EdgeInsets.all(7),
              decoration: BoxDecoration(
                color: color.withAlpha(isDark ? 40 : 25),
                shape: BoxShape.circle,
              ),
              child: Icon(icon, color: color, size: 20),
            ),
            const SizedBox(height: 8),
            Text(
              value,
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w800,
                color: isDark ? Colors.white : Colors.black87,
              ),
            ),
            const SizedBox(height: 2),
            Text(
              title,
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 11,
                color: isDark ? Colors.grey.shade400 : Colors.grey.shade600,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
