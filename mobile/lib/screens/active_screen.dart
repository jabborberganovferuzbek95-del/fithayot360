import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../api_client.dart';
import '../app_state.dart';
import '../models.dart';
import '../ui.dart';

class _ActiveData {
  _ActiveData(this.types, this.recent);
  final List<ActivityType> types;
  final List<Activity> recent;
}

/// S14 Active faollik qo'shish (qo'lda kiritish; GPS/qadam avtomatik olinmaydi)
class ActiveScreen extends StatefulWidget {
  const ActiveScreen({super.key, this.embedded = false});
  final bool embedded;
  @override
  State<ActiveScreen> createState() => _ActiveScreenState();
}

class _ActiveScreenState extends State<ActiveScreen> {
  int _epoch = 0;
  int? _typeId;
  final _minutes = TextEditingController();
  final _km = TextEditingController();
  final _note = TextEditingController();
  DateTime _day = dateOnly(DateTime.now());
  String _key = newKey();
  bool _busy = false;
  String? _error;

  @override
  void dispose() {
    _minutes.dispose();
    _km.dispose();
    _note.dispose();
    super.dispose();
  }

  Future<_ActiveData> _load() async {
    final api = context.read<AppState>().api;
    final r = await Future.wait([
      api.get('/activity-types'),
      api.get('/activities', query: {'limit': 20}),
    ]);
    return _ActiveData(
      (r[0] as List).map((e) => ActivityType.fromJson(Map<String, dynamic>.from(e))).toList(),
      (r[1] as List).map((e) => Activity.fromJson(Map<String, dynamic>.from(e))).toList(),
    );
  }

  Future<void> _save(List<ActivityType> types) async {
    final mins = int.tryParse(_minutes.text.trim());
    final km = _km.text.trim().isEmpty ? null : double.tryParse(_km.text.replaceAll(',', '.'));
    if (_typeId == null) return setState(() => _error = "Faollik turini tanlang");
    if (mins == null || mins < 1 || mins > 1440) return setState(() => _error = "Davomiylik 1–1440 daqiqa oralig'ida bo'lsin");
    if (_km.text.trim().isNotEmpty && (km == null || km < 0)) return setState(() => _error = "Masofa manfiy bo'lmasin");
    final now = DateTime.now();
    final when = sameDay(_day, now) ? now : DateTime(_day.year, _day.month, _day.day, 12);
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await context.read<AppState>().api.post(
        '/activities',
        headers: {'Idempotency-Key': _key},
        body: {
          'activity_type_id': _typeId,
          'duration_minutes': mins,
          'distance_km': km,
          'note': _note.text.trim().isEmpty ? null : _note.text.trim(),
          'occurred_at': when.toUtc().toIso8601String(),
        },
      );
      _minutes.clear();
      _km.clear();
      _note.clear();
      _key = newKey();
      if (mounted) {
        toast(context, "Faollik saqlandi");
        setState(() {
          _epoch++;
          _busy = false;
        });
      }
    } on ApiException catch (e) {
      if (mounted) {
        setState(() {
          _error = e.message;
          _busy = false;
        });
      }
    }
  }

  Future<void> _delete(Activity a) async {
    if (!await confirm(context, "O'chirish", "\"${a.type.title}\" faollik qaydi o'chirilsinmi?")) return;
    try {
      await context.read<AppState>().api.delete('/activities/${a.id}');
      setState(() => _epoch++);
    } on ApiException catch (e) {
      if (mounted) toast(context, e.message);
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: isDark ? const Color(0xFF0F1512) : const Color(0xFFF7FAF8),
      appBar: widget.embedded
          ? null
          : AppBar(
              title: const Text(
                "Active faollik",
                style: TextStyle(fontWeight: FontWeight.w800, fontSize: 18),
              ),
              elevation: 0,
              backgroundColor: isDark ? const Color(0xFF141C17) : Colors.white,
            ),
      body: Loader<_ActiveData>(
        key: ValueKey(_epoch),
        load: _load,
        builder: (context, d, reload) => RefreshIndicator(
          onRefresh: reload,
          color: kGreen,
          child: ListView(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            children: [
              // Faollik qo'shish kartasi
              Container(
                padding: const EdgeInsets.all(18),
                decoration: BoxDecoration(
                  color: isDark ? const Color(0xFF161F1A) : Colors.white,
                  borderRadius: BorderRadius.circular(22),
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
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: Colors.teal.withAlpha(isDark ? 40 : 25),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: const Icon(Icons.directions_run_rounded, color: Colors.teal, size: 22),
                        ),
                        const SizedBox(width: 12),
                        const Text(
                          "Faollik qayd etish",
                          style: TextStyle(fontWeight: FontWeight.w700, fontSize: 16),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),

                    // Faollik turi
                    DropdownButtonFormField<int>(
                      initialValue: _typeId,
                      decoration: InputDecoration(
                        labelText: "Faollik turi (yurish, yugurish, velosiped...)",
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(14)),
                        contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                      ),
                      items: [
                        for (final t in d.types)
                          DropdownMenuItem(
                            value: t.id,
                            child: Text(t.title, style: const TextStyle(fontWeight: FontWeight.w500)),
                          ),
                      ],
                      onChanged: (v) => setState(() => _typeId = v),
                    ),

                    const SizedBox(height: 12),

                    // Vaqt va masofa
                    Row(
                      children: [
                        Expanded(
                          child: TextField(
                            controller: _minutes,
                            keyboardType: TextInputType.number,
                            decoration: InputDecoration(
                              labelText: "Vaqt (daqiqa)",
                              prefixIcon: const Icon(Icons.timer_outlined, size: 20),
                              border: OutlineInputBorder(borderRadius: BorderRadius.circular(14)),
                              contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                            ),
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: TextField(
                            controller: _km,
                            keyboardType: const TextInputType.numberWithOptions(decimal: true),
                            decoration: InputDecoration(
                              labelText: "Masofa, km (ixtiyoriy)",
                              prefixIcon: const Icon(Icons.straighten_rounded, size: 20),
                              border: OutlineInputBorder(borderRadius: BorderRadius.circular(14)),
                              contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                            ),
                          ),
                        ),
                      ],
                    ),

                    // Tezkor daqiqa tugmalari
                    const SizedBox(height: 10),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [15, 30, 45, 60].map((m) {
                        return InkWell(
                          onTap: () => _minutes.text = '$m',
                          borderRadius: BorderRadius.circular(8),
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
                            decoration: BoxDecoration(
                              color: isDark ? Colors.white10 : Colors.black.withAlpha(8),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Text("$m daq", style: const TextStyle(fontSize: 11.5, fontWeight: FontWeight.w600)),
                          ),
                        );
                      }).toList(),
                    ),

                    const SizedBox(height: 12),

                    TextField(
                      controller: _note,
                      maxLength: 500,
                      decoration: InputDecoration(
                        labelText: "Izoh (ixtiyoriy)",
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(14)),
                        contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                      ),
                    ),

                    // Sana tanlash chipslari
                    Wrap(
                      spacing: 8,
                      children: [
                        ChoiceChip(
                          label: const Text("Bugun"),
                          selected: sameDay(_day, DateTime.now()),
                          selectedColor: kGreen.withAlpha(isDark ? 45 : 30),
                          checkmarkColor: kGreen,
                          onSelected: (_) => setState(() => _day = dateOnly(DateTime.now())),
                        ),
                        ChoiceChip(
                          label: const Text("Kecha"),
                          selected: sameDay(_day, DateTime.now().subtract(const Duration(days: 1))),
                          selectedColor: kGreen.withAlpha(isDark ? 45 : 30),
                          checkmarkColor: kGreen,
                          onSelected: (_) => setState(() => _day = dateOnly(DateTime.now().subtract(const Duration(days: 1)))),
                        ),
                        ActionChip(
                          avatar: const Icon(Icons.event_rounded, size: 16, color: kGreen),
                          label: Text(fmtDate(_day)),
                          onPressed: () async {
                            final x = await showDatePicker(
                              context: context,
                              initialDate: _day,
                              firstDate: DateTime.now().subtract(const Duration(days: 365)),
                              lastDate: DateTime.now(),
                            );
                            if (x != null) setState(() => _day = x);
                          },
                        ),
                      ],
                    ),

                    if (_error != null)
                      Padding(
                        padding: const EdgeInsets.only(top: 10),
                        child: Text(
                          _error!,
                          style: const TextStyle(color: Colors.redAccent, fontSize: 12.5),
                        ),
                      ),

                    const SizedBox(height: 16),

                    FilledButton(
                      onPressed: _busy ? null : () => _save(d.types),
                      style: FilledButton.styleFrom(
                        backgroundColor: kGreen,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                        minimumSize: const Size.fromHeight(50),
                      ),
                      child: _busy
                          ? const SizedBox(width: 22, height: 22, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                          : const Text("Faollikni saqlash", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 20),

              // So'nggi faolliklar
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text(
                    "So'nggi faolliklar",
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
                  ),
                  if (d.recent.isNotEmpty)
                    Text(
                      "${d.recent.length} ta qayd",
                      style: TextStyle(fontSize: 12, color: isDark ? Colors.grey.shade400 : Colors.grey.shade600),
                    ),
                ],
              ),
              const SizedBox(height: 10),

              if (d.recent.isEmpty)
                Container(
                  padding: const EdgeInsets.symmetric(vertical: 36, horizontal: 20),
                  decoration: BoxDecoration(
                    color: isDark ? const Color(0xFF161F1A) : Colors.white,
                    borderRadius: BorderRadius.circular(18),
                    border: Border.all(color: isDark ? Colors.white10 : Colors.black.withAlpha(10)),
                  ),
                  child: Center(
                    child: Text(
                      "Hali faollik qaydlari kiritilmagan",
                      style: TextStyle(color: isDark ? Colors.grey.shade400 : Colors.grey.shade600),
                    ),
                  ),
                )
              else
                for (final a in d.recent)
                  Container(
                    margin: const EdgeInsets.only(bottom: 8),
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                    decoration: BoxDecoration(
                      color: isDark ? const Color(0xFF161F1A) : Colors.white,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: isDark ? Colors.white10 : Colors.black.withAlpha(10)),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withAlpha(isDark ? 15 : 5),
                          blurRadius: 6,
                          offset: const Offset(0, 2),
                        ),
                      ],
                    ),
                    child: Row(
                      children: [
                        const ModuleBadge('active'),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                "${a.type.title} · ${a.minutes} daqiqa${a.distanceKm != null ? ' · ${a.distanceKm} km' : ''}",
                                style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 14),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                "${fmtDate(a.occurredAt)} ${fmtTime(a.occurredAt)}${a.note != null ? ' · ${a.note}' : ''}",
                                style: TextStyle(
                                  fontSize: 11.5,
                                  color: isDark ? Colors.grey.shade400 : Colors.grey.shade600,
                                ),
                              ),
                            ],
                          ),
                        ),
                        IconButton(
                          icon: const Icon(Icons.delete_outline_rounded, size: 20, color: Colors.redAccent),
                          onPressed: () => _delete(a),
                        ),
                      ],
                    ),
                  ),

              const SizedBox(height: 16),
            ],
          ),
        ),
      ),
    );
  }
}
