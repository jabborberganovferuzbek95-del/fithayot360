import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../api_client.dart';
import '../app_state.dart';
import '../ui.dart';

ApiClient _api(BuildContext c) => c.read<AppState>().api;

/// Qadamlarni qo'lda kiritish (ilova sensor yoki GPS ishlatmaydi)
Future<bool> editSteps(BuildContext context, int current) async {
  final ctrl = TextEditingController(text: current > 0 ? '$current' : '');
  final ok = await showDialog<bool>(
    context: context,
    builder: (ctx) => AlertDialog(
      title: const Text("Bugungi qadamlar"),
      content: Column(mainAxisSize: MainAxisSize.min, children: [
        const Text("Telefon yoki soatingizdagi qadam sonini kiriting. Ilova qadamni avtomatik sanamaydi."),
        const SizedBox(height: 12),
        TextField(controller: ctrl, keyboardType: TextInputType.number, autofocus: true, decoration: const InputDecoration(labelText: "Qadamlar soni")),
      ]),
      actions: [
        TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text("Bekor qilish")),
        FilledButton(style: FilledButton.styleFrom(minimumSize: const Size(80, 40)), onPressed: () => Navigator.pop(ctx, true), child: const Text("Saqlash")),
      ],
    ),
  );
  if (ok != true) return false;
  final n = int.tryParse(ctrl.text.trim());
  if (n == null || n < 0 || n > 200000) {
    toast(context, "Qadam soni 0 dan 200 000 gacha bo'lsin");
    return false;
  }
  try {
    await _api(context).put('/steps/${isoDate(DateTime.now())}', body: {'steps': n});
    return true;
  } on ApiException catch (e) {
    toast(context, e.message);
    return false;
  }
}

// ======================= SUV =======================
class WaterScreen extends StatelessWidget {
  const WaterScreen({super.key});
  @override
  Widget build(BuildContext context) => DefaultTabController(
        length: 3,
        child: Scaffold(
          backgroundColor: Colors.transparent,
          appBar: AppBar(title: const Text("Suv"), bottom: const TabBar(tabs: [Tab(text: "Bugun"), Tab(text: "Hafta"), Tab(text: "Oy")])),
          body: const ScreenBackground(
            imageName: 'wellness_bg.jpg',
            child: TabBarView(children: [_WaterToday(), _WaterRange(days: 7), _WaterRange(days: 30)]),
          ),
        ),
      );
}

class _WaterToday extends StatefulWidget {
  const _WaterToday();
  @override
  State<_WaterToday> createState() => _WaterTodayState();
}

class _WaterTodayState extends State<_WaterToday> {
  int _epoch = 0;
  bool _busy = false;

  Future<void> _run(Future<void> Function() f) async {
    if (_busy) return;
    setState(() => _busy = true);
    try {
      await f();
    } on ApiException catch (e) {
      if (mounted) toast(context, e.message);
    }
    if (mounted) setState(() { _busy = false; _epoch++; });
  }

  Future<void> _add(int ml) => _run(() => _api(context).post('/water', body: {'amount_ml': ml}, headers: {'Idempotency-Key': newKey()}));
  Future<void> _remove(int id) => _run(() => _api(context).delete('/water/$id'));

  Future<void> _custom() async {
    final c = TextEditingController();
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text("Boshqa miqdor"),
        content: TextField(controller: c, autofocus: true, keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: "Millilitr (50–2000)")),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text("Bekor qilish")),
          FilledButton(style: FilledButton.styleFrom(minimumSize: const Size(80, 40)), onPressed: () => Navigator.pop(ctx, true), child: const Text("Qo'shish")),
        ],
      ),
    );
    final ml = int.tryParse(c.text.trim());
    if (ok == true) {
      if (ml == null || ml < 50 || ml > 2000) return toast(context, "Miqdor 50 dan 2000 ml gacha bo'lsin");
      await _add(ml);
    }
  }

  @override
  Widget build(BuildContext context) => Loader<Map<String, dynamic>>(
          key: ValueKey(_epoch),
          load: () => _api(context).getMap('/water'),
          builder: (context, d, reload) {
            final total = d['total_ml'] as int, goal = d['goal_ml'] as int;
            final entries = (d['entries'] as List).map((e) => Map<String, dynamic>.from(e)).toList();
            final glasses = (goal / 250).ceil().clamp(1, 16);
            return ListView(padding: const EdgeInsets.all(16), children: [
              Center(
                child: RingProgress(
                  value: goal == 0 ? 0 : total / goal,
                  size: 210,
                  stroke: 14,
                  color: Colors.lightBlue,
                  trackColor: Colors.lightBlue.shade50,
                  child: Column(mainAxisSize: MainAxisSize.min, children: [
                    const Icon(Icons.water_drop, color: Colors.lightBlue, size: 36),
                    Text('${fmtL(total)} L', style: const TextStyle(fontSize: 34, fontWeight: FontWeight.bold)),
                    Text('/ ${fmtL(goal)} L', style: const TextStyle(color: Colors.grey)),
                  ]),
                ),
              ),
              const SizedBox(height: 16),
              Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                IconButton.outlined(onPressed: _busy || entries.isEmpty ? null : () => _remove(entries.last['id'] as int), icon: const Icon(Icons.remove)),
                const SizedBox(width: 16),
                FilledButton.icon(style: FilledButton.styleFrom(minimumSize: const Size(150, 48)), onPressed: _busy ? null : () => _add(250), icon: const Icon(Icons.add), label: const Text("1 stakan (250 ml)")),
              ]),
              const SizedBox(height: 12),
              Wrap(alignment: WrapAlignment.center, spacing: 8, children: [
                for (final ml in [150, 330, 500])
                  ActionChip(label: Text('+$ml ml'), onPressed: _busy ? null : () => _add(ml)),
                ActionChip(label: const Text("Boshqa..."), onPressed: _busy ? null : _custom),
              ]),
              const SizedBox(height: 16),
              Wrap(alignment: WrapAlignment.center, spacing: 6, runSpacing: 6, children: [
                for (var i = 0; i < glasses; i++) Icon(Icons.local_drink, size: 30, color: (i + 1) * 250 <= total ? Colors.lightBlue : Colors.grey.shade300),
              ]),
              const SizedBox(height: 20),
              Text("Bugungi qaydlar", style: Theme.of(context).textTheme.titleMedium),
              if (entries.isEmpty) const Padding(padding: EdgeInsets.all(16), child: Text("Hali suv qayd qilinmagan")),
              for (final e in entries.reversed)
                ListTile(
                  leading: const Icon(Icons.water_drop_outlined, color: Colors.lightBlue),
                  title: Text('${e['amount_ml']} ml'),
                  subtitle: Text(fmtTime(DateTime.parse(e['logged_at']).toLocal())),
                  trailing: IconButton(icon: const Icon(Icons.delete_outline), onPressed: _busy ? null : () => _remove(e['id'] as int)),
                ),
              const SizedBox(height: 8),
              const Text("Suv maqsadi sizning shaxsiy belgilagan maqsadingiz, tibbiy tavsiya emas. Maqsadni Profil → Maqsadlarim bo'limida o'zgartirasiz.", style: TextStyle(fontSize: 12, color: Colors.grey)),
            ]);
          },
      );
}

class _WaterRange extends StatelessWidget {
  const _WaterRange({required this.days});
  final int days;
  @override
  Widget build(BuildContext context) => Loader<List<Map<String, dynamic>>>(
        load: () async {
          final api = _api(context);
          final r = await Future.wait([api.getMap('/stats', query: {'days': days}), api.getMap('/goals')]);
          final stats = r[0];
          final goal = r[1]['water_goal_ml'] as int;
          return [
            {'goal': goal, 'avg': (stats['averages'] as Map)['water_ml']},
            ...(stats['days'] as List).map((e) => Map<String, dynamic>.from(e)),
          ];
        },
        builder: (context, rows, reload) {
          final goal = rows.first['goal'] as int, avg = rows.first['avg'] as int;
          final data = rows.skip(1).toList();
          final reached = data.where((d) => (d['water_ml'] as int) >= goal).length;
          return RefreshIndicator(
            onRefresh: reload,
            child: ListView(padding: const EdgeInsets.all(16), children: [
              Row(children: [
                StatTile("O'rtacha", '${fmtL(avg)} L', icon: Icons.water_drop, color: Colors.lightBlue),
                StatTile("Maqsadga yetgan", '$reached / ${data.length}', icon: Icons.flag, color: Colors.lightBlue),
              ]),
              AppCard(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text("Kunlik suv (maqsad: ${fmtL(goal)} L)", style: const TextStyle(fontSize: 12, color: Colors.grey)),
                const SizedBox(height: 10),
                MiniBars(values: [for (final d in data) (d['water_ml'] as int).toDouble()], color: Colors.lightBlue, height: 110),
                if (days == 7) ...[
                  const SizedBox(height: 6),
                  Row(children: [for (final d in data) Expanded(child: Text(weekdaysShort[DateTime.parse(d['date'] as String).weekday - 1], textAlign: TextAlign.center, style: const TextStyle(fontSize: 11)))]),
                ],
              ])),
            ]),
          );
        },
      );
}

// ======================= UYQU =======================
class SleepScreen extends StatelessWidget {
  const SleepScreen({super.key});
  @override
  Widget build(BuildContext context) => DefaultTabController(
        length: 3,
        child: Scaffold(
          backgroundColor: Colors.transparent,
          appBar: AppBar(title: const Text("Uyqu"), bottom: const TabBar(tabs: [Tab(text: "Kuzatuv"), Tab(text: "Maslahatlar"), Tab(text: "Tarix")])),
          body: const ScreenBackground(
            imageName: 'wellness_bg.jpg',
            child: TabBarView(children: [_SleepTrack(), _SleepTips(), _SleepHistory()]),
          ),
        ),
      );
}

class _SleepTrack extends StatefulWidget {
  const _SleepTrack();
  @override
  State<_SleepTrack> createState() => _SleepTrackState();
}

class _SleepTrackState extends State<_SleepTrack> {
  int _epoch = 0;
  double _hours = 7.5;
  int? _quality;
  bool _yesterday = false, _busy = false;

  Future<void> _save() async {
    final day = DateTime.now().subtract(Duration(days: _yesterday ? 1 : 0));
    setState(() => _busy = true);
    try {
      await _api(context).put('/sleep/${isoDate(day)}', body: {'duration_min': (_hours * 60).round(), if (_quality != null) 'quality': _quality});
      if (mounted) toast(context, "Uyqu saqlandi");
    } on ApiException catch (e) {
      if (mounted) toast(context, e.message);
    }
    if (mounted) setState(() { _busy = false; _epoch++; });
  }

  @override
  Widget build(BuildContext context) => Loader<List<Map<String, dynamic>>>(
          key: ValueKey(_epoch),
          load: () => _api(context).getList('/sleep'),
          builder: (context, rows, reload) {
            final byDate = {for (final r in rows) r['sleep_date'] as String: r['duration_min'] as int};
            final last7 = [for (var i = 6; i >= 0; i--) DateTime.now().subtract(Duration(days: i))];
            final vals = [for (final d in last7) (byDate[isoDate(d)] ?? 0).toDouble()];
            final recorded = vals.where((v) => v > 0).toList();
            final avg = recorded.isEmpty ? null : (recorded.reduce((a, b) => a + b) / recorded.length).round();
            return ListView(padding: const EdgeInsets.all(16), children: [
              Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(borderRadius: BorderRadius.circular(22), gradient: const LinearGradient(colors: [Color(0xFF1E1B4B), Color(0xFF4338CA)])),
                child: Column(children: [
                  const Icon(Icons.bedtime, color: Colors.white, size: 40),
                  const SizedBox(height: 8),
                  Text(fmtSleep((_hours * 60).round()), style: const TextStyle(color: Colors.white, fontSize: 32, fontWeight: FontWeight.bold)),
                  Text(_yesterday ? "Kecha tunda" : "Bugun ertalab uyg'ongan kunga", style: const TextStyle(color: Colors.white70)),
                  Slider(value: _hours, min: 2, max: 14, divisions: 48, activeColor: Colors.white, inactiveColor: Colors.white24, onChanged: (v) => setState(() => _hours = v)),
                ]),
              ),
              const SizedBox(height: 12),
              Wrap(spacing: 8, children: [
                ChoiceChip(label: const Text("Bugun"), selected: !_yesterday, onSelected: (_) => setState(() => _yesterday = false)),
                ChoiceChip(label: const Text("Kecha"), selected: _yesterday, onSelected: (_) => setState(() => _yesterday = true)),
              ]),
              const SizedBox(height: 8),
              const Text("Uyqu sifati (ixtiyoriy)"),
              Row(children: [
                for (var i = 1; i <= 5; i++)
                  IconButton(onPressed: () => setState(() => _quality = _quality == i ? null : i), icon: Icon((_quality ?? 0) >= i ? Icons.star : Icons.star_border, color: Colors.amber, size: 32)),
              ]),
              FilledButton(onPressed: _busy ? null : _save, child: const Text("Saqlash")),
              const SizedBox(height: 20),
              Text("Oxirgi 7 kun", style: Theme.of(context).textTheme.titleMedium),
              const SizedBox(height: 8),
              AppCard(child: Column(children: [
                MiniBars(values: vals, color: const Color(0xFF4338CA), height: 90),
                const SizedBox(height: 6),
                Row(children: [for (final d in last7) Expanded(child: Text(weekdaysShort[d.weekday - 1], textAlign: TextAlign.center, style: const TextStyle(fontSize: 11)))]),
                const SizedBox(height: 8),
                Text(avg == null ? "O'rtacha: N/A (qayd yo'q)" : "O'rtacha: ${fmtSleep(avg)}"),
              ])),
              const Text("Ilova uyqu kuzatuvchisi emas va uyqu muammolarini aniqlamaydi. Uzoq davom etuvchi uyqu muammolari bo'lsa, shifokorga murojaat qiling.", style: TextStyle(fontSize: 12, color: Colors.grey)),
            ]);
          },
      );
}


class _SleepTips extends StatelessWidget {
  const _SleepTips();
  static const _tips = [
    (Icons.schedule, "Rejim", "Iloji boricha har kuni bir xil vaqtda yoting va turing."),
    (Icons.phone_android, "Ekranlar", "Uxlashdan taxminan 1 soat oldin telefon va televizorni kamaytiring."),
    (Icons.dark_mode, "Xona", "Yotoqxonani qorong'i, sokin va salqin saqlang."),
    (Icons.local_cafe, "Kofein va ovqat", "Kechqurun kofein va og'ir ovqatdan ehtiyot bo'ling."),
    (Icons.wb_sunny, "Kun tartibi", "Kunduzi harakat qiling va ertalab tabiiy yorug'likka chiqing."),
    (Icons.self_improvement, "Tinchlanish", "Yotishdan oldin yengil nafas mashqi yoki kitob o'qish yordam beradi."),
  ];
  @override
  Widget build(BuildContext context) => ListView(padding: const EdgeInsets.all(16), children: [
        for (final t in _tips)
          AppCard(child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Container(padding: const EdgeInsets.all(10), decoration: BoxDecoration(color: Colors.indigo.withAlpha(30), borderRadius: BorderRadius.circular(12)), child: Icon(t.$1, color: Colors.indigo)),
            const SizedBox(width: 14),
            Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text(t.$2, style: const TextStyle(fontWeight: FontWeight.bold)), const SizedBox(height: 2), Text(t.$3)])),
          ])),
        const Text("Bu umumiy tavsiyalar. Uzoq davom etuvchi uyqu muammolari bo'lsa, shifokorga murojaat qiling.", style: TextStyle(fontSize: 12, color: Colors.grey)),
      ]);
}

class _SleepHistory extends StatelessWidget {
  const _SleepHistory();
  @override
  Widget build(BuildContext context) => Loader<List<Map<String, dynamic>>>(
        load: () => _api(context).getList('/sleep', query: {'date_from': isoDate(DateTime.now().subtract(const Duration(days: 29))), 'date_to': isoDate(DateTime.now())}),
        builder: (context, rows, reload) => RefreshIndicator(
          onRefresh: reload,
          child: rows.isEmpty
              ? ListView(children: const [Padding(padding: EdgeInsets.all(40), child: Center(child: Text("Oxirgi 30 kunda uyqu qaydi yo'q")))])
              : ListView(padding: const EdgeInsets.all(16), children: [
                  for (final r in rows.reversed)
                    AppCard(
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                      child: Row(children: [
                        const Icon(Icons.bedtime, color: Colors.indigo),
                        const SizedBox(width: 12),
                        Expanded(child: Text(fmtDate(DateTime.parse(r['sleep_date'] as String)))),
                        Text(fmtSleep(r['duration_min'] as int), style: const TextStyle(fontWeight: FontWeight.bold)),
                        const SizedBox(width: 10),
                        if (r['quality'] != null) Row(children: [const Icon(Icons.star, color: Colors.amber, size: 18), Text('${r['quality']}')]),
                      ]),
                    ),
                ]),
        ),
      );
}

// ======================= ODATLAR =======================
const _quotes = [
  "Kichik odatlar — katta natijalarga olib keladi.",
  "Har kuni bir qadam — maqsadga bir qadam yaqin.",
  "Mukammallik emas, izchillik muhim.",
  "Bugungi harakat ertangi kayfiyatni belgilaydi.",
  "O'zingizni kecha bilan taqqoslang, boshqalar bilan emas.",
  "Boshlash — yarim g'alaba.",
  "Dam olish ham taraqqiyotning bir qismi.",
];

class _HData {
  _HData(this.today, this.stats, this.habits, this.checks);
  final Map<String, dynamic> today, stats;
  final List<Map<String, dynamic>> habits, checks;
}

class HabitsScreen extends StatefulWidget {
  const HabitsScreen({super.key});
  @override
  State<HabitsScreen> createState() => _HabitsScreenState();
}

class _HabitsScreenState extends State<HabitsScreen> {
  int _epoch = 0;

  Future<_HData> _load() async {
    final api = _api(context);
    final r = await Future.wait([api.getMap('/dashboard/today'), api.getMap('/stats', query: {'days': 7}), api.getList('/habits'), api.getList('/habit-checks')]);
    return _HData(r[0] as Map<String, dynamic>, r[1] as Map<String, dynamic>, r[2] as List<Map<String, dynamic>>, r[3] as List<Map<String, dynamic>>);
  }

  Future<void> _toggle(int id, bool done) async {
    try {
      await _api(context).put('/habits/$id/checks/${isoDate(DateTime.now())}', body: {'done': done});
      setState(() => _epoch++);
    } on ApiException catch (e) {
      toast(context, e.message);
    }
  }

  Future<void> _add() async {
    final c = TextEditingController();
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text("Yangi odat"),
        content: TextField(controller: c, autofocus: true, maxLength: 100, decoration: const InputDecoration(labelText: "Masalan: Ertalab cho'zilish")),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text("Bekor qilish")),
          FilledButton(style: FilledButton.styleFrom(minimumSize: const Size(80, 40)), onPressed: () => Navigator.pop(ctx, true), child: const Text("Qo'shish")),
        ],
      ),
    );
    if (ok != true || c.text.trim().isEmpty) return;
    try {
      await _api(context).post('/habits', body: {'title': c.text.trim()});
      setState(() => _epoch++);
    } on ApiException catch (e) {
      toast(context, e.message);
    }
  }

  Future<void> _delete(int id) async {
    if (!await confirm(context, "Odatni o'chirish", "Bu odat va uning belgilari o'chiriladi.")) return;
    try {
      await _api(context).delete('/habits/$id');
      setState(() => _epoch++);
    } on ApiException catch (e) {
      toast(context, e.message);
    }
  }

  bool _autoDone(String key, Map<String, dynamic> row, Map<String, dynamic> g) => switch (key) {
        'steps' => (row['steps'] as int) >= (g['steps'] as int),
        'water' => (row['water_ml'] as int) >= (g['water_ml'] as int),
        'workout' => (row['active_minutes'] as int) >= (g['workout_min'] as int),
        'meditation' => (row['meditation_min'] as int) >= 10,
        _ => (row['sleep_min'] as int) >= (g['sleep_min'] as int),
      };

  @override
  Widget build(BuildContext context) => DefaultTabController(
        length: 3,
        child: Scaffold(
          appBar: AppBar(title: const Text("Odatlar"), bottom: const TabBar(tabs: [Tab(text: "Bugungi"), Tab(text: "Haftalik"), Tab(text: "Barcha")])),
          body: Loader<_HData>(
            key: ValueKey(_epoch),
            load: _load,
            builder: (context, d, reload) {
              final auto = (d.today['habits'] as List).map((e) => Map<String, dynamic>.from(e)).toList();
              final goals = Map<String, dynamic>.from(d.today['goals']);
              final rows = (d.stats['days'] as List).map((e) => Map<String, dynamic>.from(e)).toList();
              final todayIso = isoDate(DateTime.now());
              bool checked(int id, String day) => d.checks.any((c) => c['habit_id'] == id && c['day'] == day);
              final total = auto.length + d.habits.length;
              final done = auto.where((h) => h['done'] == true).length + d.habits.where((h) => checked(h['id'] as int, todayIso)).length;
              return TabBarView(children: [
                // ---- Bugungi ----
                RefreshIndicator(
                  onRefresh: reload,
                  child: ListView(padding: const EdgeInsets.all(16), children: [
                    AppCard(color: kGreen, child: Row(children: [
                      RingProgress(value: total == 0 ? 0 : done / total, size: 70, stroke: 8, color: kMint, child: Text('$done/$total', style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold))),
                      const SizedBox(width: 16),
                      const Expanded(child: Text("Asosiy odatlar siz kiritgan ma'lumotlardan avtomatik belgilanadi; shaxsiy odatlarni o'zingiz belgilaysiz.", style: TextStyle(color: Colors.white))),
                    ])),
                    for (final h in auto)
                      AppCard(padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12), child: Row(children: [
                        Icon(h['done'] == true ? Icons.check_circle : Icons.radio_button_unchecked, color: h['done'] == true ? kGreen : Colors.grey),
                        const SizedBox(width: 12),
                        Expanded(child: Text(h['title'] as String, style: TextStyle(decoration: h['done'] == true ? TextDecoration.lineThrough : null))),
                        const Text("avto", style: TextStyle(fontSize: 11, color: Colors.grey)),
                      ])),
                    for (final h in d.habits)
                      AppCard(padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4), child: Row(children: [
                        Checkbox(value: checked(h['id'] as int, todayIso), onChanged: (v) => _toggle(h['id'] as int, v ?? false)),
                        Expanded(child: Text(h['title'] as String)),
                      ])),
                    OutlinedButton.icon(onPressed: _add, icon: const Icon(Icons.add), label: const Text("Yangi odat qo'shish")),
                    const SizedBox(height: 12),
                    AppCard(color: kGreen.withAlpha(30), child: Row(children: [
                      const Icon(Icons.eco, color: kGreen, size: 32),
                      const SizedBox(width: 12),
                      Expanded(child: Text('"${_quotes[DateTime.now().weekday - 1]}"', style: const TextStyle(fontStyle: FontStyle.italic, fontWeight: FontWeight.w600))),
                    ])),
                  ]),
                ),
                // ---- Haftalik ----
                ListView(padding: const EdgeInsets.all(16), children: [
                  AppCard(child: Column(children: [
                    Row(children: [
                      const Expanded(flex: 4, child: SizedBox()),
                      for (final r in rows) Expanded(child: Text(weekdaysShort[DateTime.parse(r['date'] as String).weekday - 1], textAlign: TextAlign.center, style: const TextStyle(fontSize: 11, color: Colors.grey))),
                    ]),
                    const SizedBox(height: 6),
                    for (final h in auto)
                      Padding(padding: const EdgeInsets.symmetric(vertical: 6), child: Row(children: [
                        Expanded(flex: 4, child: Text(h['title'] as String, style: const TextStyle(fontSize: 12), maxLines: 2, overflow: TextOverflow.ellipsis)),
                        for (final r in rows) Expanded(child: Icon(_autoDone(h['key'] as String, r, goals) ? Icons.check_circle : Icons.circle_outlined, size: 20, color: _autoDone(h['key'] as String, r, goals) ? kGreen : Colors.grey.shade400)),
                      ])),
                    for (final h in d.habits)
                      Padding(padding: const EdgeInsets.symmetric(vertical: 6), child: Row(children: [
                        Expanded(flex: 4, child: Text(h['title'] as String, style: const TextStyle(fontSize: 12), maxLines: 2, overflow: TextOverflow.ellipsis)),
                        for (final r in rows) Expanded(child: Icon(checked(h['id'] as int, r['date'] as String) ? Icons.check_circle : Icons.circle_outlined, size: 20, color: checked(h['id'] as int, r['date'] as String) ? kGreen : Colors.grey.shade400)),
                      ])),
                  ])),
                  const Text("Oxirgi 7 kun. Shaxsiy odatlarni faqat bugungi kun uchun belgilash mumkin.", style: TextStyle(fontSize: 12, color: Colors.grey)),
                ]),
                // ---- Barcha ----
                ListView(padding: const EdgeInsets.all(16), children: [
                  Text("Shaxsiy odatlar", style: Theme.of(context).textTheme.titleMedium),
                  if (d.habits.isEmpty) const Padding(padding: EdgeInsets.all(16), child: Text("Hali shaxsiy odat qo'shilmagan")),
                  for (final h in d.habits)
                    AppCard(padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6), child: Row(children: [
                      Expanded(child: Text(h['title'] as String)),
                      IconButton(icon: const Icon(Icons.delete_outline), onPressed: () => _delete(h['id'] as int)),
                    ])),
                  OutlinedButton.icon(onPressed: _add, icon: const Icon(Icons.add), label: const Text("Yangi odat qo'shish")),
                  const SizedBox(height: 16),
                  Text("Avtomatik odatlar", style: Theme.of(context).textTheme.titleMedium),
                  for (final h in auto) ListTile(dense: true, leading: const Icon(Icons.bolt, color: kGreen), title: Text(h['title'] as String)),
                  const Text("Maqsadlar miqdorini Profil → Maqsadlarim bo'limida o'zgartirasiz.", style: TextStyle(fontSize: 12, color: Colors.grey)),
                ]),
              ]);
            },
          ),
        ),
      );
}

// ======================= MAQSADLAR =======================
class GoalsScreen extends StatelessWidget {
  const GoalsScreen({super.key});
  @override
  Widget build(BuildContext context) => Scaffold(
        appBar: AppBar(title: const Text("Maqsadlarim")),
        body: Loader<Map<String, dynamic>>(load: () => _api(context).getMap('/goals'), builder: (c, d, _) => _GoalsForm(initial: d)),
      );
}

class _GoalsForm extends StatefulWidget {
  const _GoalsForm({required this.initial});
  final Map<String, dynamic> initial;
  @override
  State<_GoalsForm> createState() => _GoalsFormState();
}

class _GoalsFormState extends State<_GoalsForm> {
  late double steps = _c('steps_goal', 2000, 30000), water = _c('water_goal_ml', 1000, 5000), sleep = _c('sleep_goal_min', 360, 600),
      workout = _c('workout_goal_min', 10, 120), kcal = _c('calorie_goal', 1200, 3500);
  bool _busy = false;

  double _c(String k, double lo, double hi) => ((widget.initial[k] as int).toDouble()).clamp(lo, hi).toDouble();

  Future<void> _save() async {
    setState(() => _busy = true);
    try {
      await _api(context).patch('/goals', body: {
        'steps_goal': steps.round(), 'water_goal_ml': water.round(), 'sleep_goal_min': sleep.round(),
        'workout_goal_min': workout.round(), 'calorie_goal': kcal.round(),
      });
      if (mounted) {
        toast(context, "Maqsadlar saqlandi");
        Navigator.pop(context);
      }
    } on ApiException catch (e) {
      if (mounted) { setState(() => _busy = false); toast(context, e.message); }
    }
  }

  Widget _row(String label, String value, double v, double lo, double hi, int div, ValueChanged<double> f) => Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [Expanded(child: Text(label)), Text(value, style: const TextStyle(fontWeight: FontWeight.bold))]),
        Slider(value: v, min: lo, max: hi, divisions: div, onChanged: f),
      ]);

  @override
  Widget build(BuildContext context) => ListView(padding: const EdgeInsets.all(16), children: [
        const Text("Bu maqsadlarni faqat o'zingiz belgilaysiz. Ular tibbiy tavsiya yoki norma emas."),
        const SizedBox(height: 12),
        _row("Qadam", fmtInt(steps.round()), steps, 2000, 30000, 56, (v) => setState(() => steps = v)),
        _row("Suv", '${fmtL(water.round())} L', water, 1000, 5000, 16, (v) => setState(() => water = v)),
        _row("Uyqu", fmtSleep(sleep.round()), sleep, 360, 600, 16, (v) => setState(() => sleep = v)),
        _row("Mashq / faol vaqt", '${workout.round()} daq', workout, 10, 120, 22, (v) => setState(() => workout = v)),
        _row("Ovqat kaloriyasi", '${fmtInt(kcal.round())} kkal', kcal, 1200, 3500, 46, (v) => setState(() => kcal = v)),
        const SizedBox(height: 12),
        FilledButton(onPressed: _busy ? null : _save, child: const Text("Saqlash")),
      ]);
}

// ======================= PREMIUM (to'lov yo'q) =======================
class PremiumScreen extends StatefulWidget {
  const PremiumScreen({super.key});
  @override
  State<PremiumScreen> createState() => _PremiumScreenState();
}

class _PremiumScreenState extends State<PremiumScreen> {
  int _epoch = 0;
  static const _plans = [
    "Qo'shimcha mashq dasturlari",
    "Shaxsiy ovqatlanish rejasi",
    "Batafsil statistika va eksport",
    "Reklamasiz ilova",
  ];

  @override
  Widget build(BuildContext context) => Scaffold(
        backgroundColor: kGreenDark,
        appBar: AppBar(backgroundColor: kGreenDark, foregroundColor: Colors.white),
        body: Loader<Map<String, dynamic>>(
          key: ValueKey(_epoch),
          load: () => _api(context).getMap('/premium/interest'),
          builder: (context, d, _) {
            final joined = d['interested'] == true;
            return ListView(padding: const EdgeInsets.all(24), children: [
              const Icon(Icons.workspace_premium, color: Colors.amber, size: 56),
              const SizedBox(height: 8),
              const Text("Premium", style: TextStyle(color: Colors.amber, fontSize: 16)),
              const SizedBox(height: 8),
              const Text("Yana ko'proq imkoniyatlar", style: TextStyle(color: Colors.white, fontSize: 30, fontWeight: FontWeight.bold)),
              const SizedBox(height: 8),
              const Text("Premium hali ishga tushmagan va to'lov qabul qilinmaydi. Quyidagilar rejada:", style: TextStyle(color: Colors.white70)),
              const SizedBox(height: 16),
              for (final p in _plans)
                Padding(padding: const EdgeInsets.symmetric(vertical: 6), child: Row(children: [const Icon(Icons.schedule, color: kMint), const SizedBox(width: 12), Expanded(child: Text(p, style: const TextStyle(color: Colors.white)))])),
              const SizedBox(height: 24),
              FilledButton(
                style: FilledButton.styleFrom(backgroundColor: kMint, foregroundColor: Colors.black),
                onPressed: joined
                    ? null
                    : () async {
                        try {
                          await _api(context).post('/premium/interest');
                          if (mounted) { toast(context, "Rahmat! Tayyor bo'lganda xabar beramiz"); setState(() => _epoch++); }
                        } on ApiException catch (e) {
                          toast(context, e.message);
                        }
                      },
                child: Text(joined ? "Ro'yxatga yozilgansiz ✓" : "Tayyor bo'lganda xabar bering"),
              ),
            ]);
          },
        ),
      );
}
