import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../api_client.dart';
import '../app_state.dart';
import '../ui.dart';
import 'nutrition_screens.dart';
import 'programs_screens.dart';

ApiClient _api(BuildContext c) => c.read<AppState>().api;

IconData _insightIcon(String k) => switch (k) {
      'water' => Icons.water_drop,
      'steps' => Icons.directions_walk,
      'workout' => Icons.fitness_center,
      'sleep' => Icons.bedtime,
      'streak' => Icons.local_fire_department,
      'stats' => Icons.insights,
      'profile' => Icons.person_outline,
      'premium' => Icons.workspace_premium,
      _ => Icons.notifications_none,
    };
Color _insightColor(String k) => switch (k) {
      'water' => Colors.lightBlue,
      'steps' => Colors.green,
      'workout' => Colors.red,
      'sleep' => Colors.deepPurple,
      'streak' => Colors.orange,
      'stats' => Colors.teal,
      'premium' => Colors.amber,
      _ => Colors.blueGrey,
    };

/// Bildirishnomalar: ma'lumotlaringizdan hisoblangan maslahatlar va tizim xabarlari
class NotificationsScreen extends StatelessWidget {
  const NotificationsScreen({super.key});
  @override
  Widget build(BuildContext context) => DefaultTabController(
        length: 3,
        child: Scaffold(
          appBar: AppBar(title: const Text("Bildirishnomalar"), bottom: const TabBar(tabs: [Tab(text: "Barchasi"), Tab(text: "Tizim"), Tab(text: "Maslahatlar")])),
          body: Loader<List<Map<String, dynamic>>>(
            load: () => _api(context).getList('/insights'),
            builder: (context, all, reload) {
              Widget list(String? kind) {
                final items = all.where((i) => kind == null || i['kind'] == kind).toList();
                return RefreshIndicator(
                  onRefresh: reload,
                  child: items.isEmpty
                      ? ListView(children: const [Padding(padding: EdgeInsets.all(48), child: Center(child: Text("Hozircha yangi bildirishnoma yo'q")))])
                      : ListView(padding: const EdgeInsets.all(16), children: [
                          for (final i in items)
                            AppCard(child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                              Container(padding: const EdgeInsets.all(10), decoration: BoxDecoration(color: _insightColor(i['icon'] as String).withAlpha(38), borderRadius: BorderRadius.circular(12)), child: Icon(_insightIcon(i['icon'] as String), color: _insightColor(i['icon'] as String))),
                              const SizedBox(width: 14),
                              Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text(i['title'] as String, style: const TextStyle(fontWeight: FontWeight.bold)), const SizedBox(height: 2), Text(i['body'] as String, style: const TextStyle(fontSize: 13))])),
                            ])),
                          const Text("Bular ilova ichidagi maslahatlar: ma'lumotlaringizdan hisoblanadi. Telefon eslatmalari (push) keyingi versiyada.", style: TextStyle(fontSize: 12, color: Colors.grey)),
                        ]),
                );
              }

              return TabBarView(children: [list(null), list('system'), list('tip')]);
            },
          ),
        ),
      );
}

/// Yutuqlar (ma'lumotlardan avtomatik hisoblanadi)
class AchievementsScreen extends StatelessWidget {
  const AchievementsScreen({super.key});
  @override
  Widget build(BuildContext context) => Scaffold(
        appBar: AppBar(title: const Text("Yutuqlar")),
        body: Loader<Map<String, dynamic>>(
          load: () => _api(context).getMap('/me/summary'),
          builder: (context, s, reload) {
            final ach = (s['achievements'] as List).map((e) => Map<String, dynamic>.from(e)).toList();
            final earned = ach.where((a) => a['earned'] == true).length;
            return RefreshIndicator(
              onRefresh: reload,
              child: ListView(padding: const EdgeInsets.all(16), children: [
                Row(children: [
                  StatTile("Seanslar", '${s['sessions_total']}', icon: Icons.fitness_center),
                  StatTile("Faol vaqt", fmtMinutes(s['minutes_total'] as int), icon: Icons.timer),
                  StatTile("Seriya", '${s['streak']} kun', icon: Icons.local_fire_department, color: Colors.orange),
                ]),
                const SizedBox(height: 8),
                Text("Yutuqlar: $earned / ${ach.length}", style: Theme.of(context).textTheme.titleMedium),
                const SizedBox(height: 6),
                for (final a in ach)
                  AppCard(
                    child: Row(children: [
                      CircleAvatar(backgroundColor: a['earned'] == true ? Colors.amber.withAlpha(50) : Colors.grey.withAlpha(38), child: Icon(Icons.emoji_events_rounded, color: a['earned'] == true ? Colors.amber.shade700 : Colors.grey)),
                      const SizedBox(width: 14),
                      Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text(a['title'] as String, style: const TextStyle(fontWeight: FontWeight.bold)), Text(a['description'] as String, style: const TextStyle(fontSize: 12, color: Colors.grey))])),
                      if (a['earned'] == true) const Icon(Icons.check_circle, color: kGreen),
                    ]),
                  ),
              ]),
            );
          },
        ),
      );
}

class _Msg {
  _Msg(this.mine, this.text, [this.action]);
  final bool mine;
  final String text;
  final Map<String, dynamic>? action;
}

/// Maslahatchi: qoidalarga asoslangan javoblar (sun'iy intellekt EMAS)
class CoachScreen extends StatefulWidget {
  const CoachScreen({super.key});
  @override
  State<CoachScreen> createState() => _CoachScreenState();
}

class _CoachScreenState extends State<CoachScreen> {
  final _scroll = ScrollController();
  final _msgs = <_Msg>[_Msg(false, "Salom! Men ilovadagi ma'lumotlaringiz asosida qisqa maslahat beraman. Quyidagi savollardan birini tanlang.")];
  bool _busy = false;

  static const _topics = [("Bugun nima qilay?", 'today'), ("Mashq tavsiya qil", 'workout'), ("Ovqat tavsiya qil", 'meal'), ("Holatim qanday?", 'status')];

  Future<void> _ask(String label, String topic) async {
    if (_busy) return;
    setState(() { _busy = true; _msgs.add(_Msg(true, label)); });
    try {
      final r = await _api(context).getMap('/coach/ask', query: {'topic': topic});
      setState(() => _msgs.add(_Msg(false, r['text'] as String, r['action'] == null ? null : Map<String, dynamic>.from(r['action']))));
    } on ApiException catch (e) {
      setState(() => _msgs.add(_Msg(false, e.message)));
    }
    setState(() => _busy = false);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scroll.hasClients) _scroll.animateTo(_scroll.position.maxScrollExtent, duration: const Duration(milliseconds: 250), curve: Curves.easeOut);
    });
  }

  Future<void> _open(Map<String, dynamic> action) async {
    if (action['type'] == 'program') {
      Navigator.push(context, MaterialPageRoute(builder: (_) => ProgramDetailScreen(programId: action['id'] as int)));
    } else {
      try {
        final r = await _api(context).getMap('/recipes/${action['id']}');
        if (mounted) Navigator.push(context, MaterialPageRoute(builder: (_) => RecipeDetailScreen(recipe: r)));
      } on ApiException catch (e) {
        toast(context, e.message);
      }
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
        appBar: AppBar(title: const Text("Maslahatchi")),
        body: Column(children: [
          Padding(padding: const EdgeInsets.fromLTRB(16, 8, 16, 0), child: SafetyBanner(text: "Maslahatchi qoidalarga asoslangan va faqat sizning ma'lumotlaringizdan foydalanadi. Bu sun'iy intellekt emas va tibbiy tavsiya bermaydi.")),
          Expanded(
            child: ListView(controller: _scroll, padding: const EdgeInsets.all(16), children: [
              for (final m in _msgs)
                Align(
                  alignment: m.mine ? Alignment.centerRight : Alignment.centerLeft,
                  child: Container(
                    constraints: BoxConstraints(maxWidth: MediaQuery.of(context).size.width * 0.8),
                    margin: const EdgeInsets.only(bottom: 10),
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(color: m.mine ? kGreen : cardBg(context), borderRadius: BorderRadius.circular(16), boxShadow: const [BoxShadow(color: Color(0x12000000), blurRadius: 6)]),
                    child: Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisSize: MainAxisSize.min, children: [
                      Text(m.text, style: TextStyle(color: m.mine ? Colors.white : null)),
                      if (m.action != null)
                        Padding(padding: const EdgeInsets.only(top: 8), child: FilledButton.tonal(style: FilledButton.styleFrom(minimumSize: const Size(120, 38)), onPressed: () => _open(m.action!), child: Text(m.action!['type'] == 'program' ? "Dasturni ochish" : "Retseptni ochish"))),
                    ]),
                  ),
                ),
              if (_busy) const Padding(padding: EdgeInsets.all(8), child: Align(alignment: Alignment.centerLeft, child: SizedBox(width: 22, height: 22, child: CircularProgressIndicator(strokeWidth: 2)))),
            ]),
          ),
          SafeArea(
            child: SizedBox(
              height: 56,
              child: ListView(scrollDirection: Axis.horizontal, padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8), children: [
                for (final t in _topics) Padding(padding: const EdgeInsets.only(right: 8), child: ActionChip(label: Text(t.$1), onPressed: _busy ? null : () => _ask(t.$1, t.$2))),
              ]),
            ),
          ),
        ]),
      );
}
