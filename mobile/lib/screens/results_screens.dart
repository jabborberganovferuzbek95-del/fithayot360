import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../app_state.dart';
import '../models.dart';
import '../ui.dart';

/// S16 Tarix + S17 Progress
class ResultsScreen extends StatelessWidget {
  const ResultsScreen({super.key});
  @override
  Widget build(BuildContext context) => DefaultTabController(
        length: 2,
        child: Scaffold(
          appBar: AppBar(title: const Text("Natijalar"), bottom: const TabBar(tabs: [Tab(text: "Progress"), Tab(text: "Tarix")])),
          body: const TabBarView(children: [ProgressView(), HistoryView()]),
        ),
      );
}

class ProgressView extends StatefulWidget {
  const ProgressView({super.key});
  @override
  State<ProgressView> createState() => _ProgressViewState();
}

class _ProgressViewState extends State<ProgressView> {
  DateTime _monday = mondayOf(DateTime.now());

  @override
  Widget build(BuildContext context) => Column(children: [
        Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
          IconButton(icon: const Icon(Icons.chevron_left), onPressed: () => setState(() => _monday = _monday.subtract(const Duration(days: 7)))),
          Text("${fmtDate(_monday)} – ${fmtDate(_monday.add(const Duration(days: 6)))}", style: Theme.of(context).textTheme.titleMedium),
          IconButton(icon: const Icon(Icons.chevron_right), onPressed: _monday.isBefore(mondayOf(DateTime.now())) ? () => setState(() => _monday = _monday.add(const Duration(days: 7))) : null),
        ]),
        Expanded(
          child: Loader<Weekly>(
            key: ValueKey(_monday),
            load: () async => Weekly.fromJson(Map<String, dynamic>.from(await context.read<AppState>().api.get('/progress/weekly', query: {'week_start': isoDate(_monday)}))),
            builder: (context, w, reload) {
              final maxMin = w.days.map((d) => d.minutes).fold<int>(0, (a, b) => a > b ? a : b);
              return RefreshIndicator(
                onRefresh: reload,
                child: ListView(padding: const EdgeInsets.all(16), children: [
                  Row(children: [StatTile("Jami faol vaqt", fmtMinutes(w.totalMinutes), icon: Icons.timer), StatTile("Seanslar", '${w.totalSessions}', icon: Icons.fitness_center), StatTile("Reja bajarilishi", w.rateLabel, icon: Icons.task_alt)]),
                  if (w.rate == null) const Padding(padding: EdgeInsets.symmetric(vertical: 4), child: Text("Bu hafta uchun reja belgilanmagan (N/A).", style: TextStyle(fontSize: 12, color: Colors.grey))),
                  if (w.planned > 0) Text("Reja: ${w.completed} / ${w.planned} band bajarilgan", style: const TextStyle(fontSize: 12, color: Colors.grey)),
                  const SizedBox(height: 16),
                  Text("Kunlar bo'yicha (daqiqa)", style: Theme.of(context).textTheme.titleMedium),
                  const SizedBox(height: 8),
                  SizedBox(
                    height: 150,
                    child: Row(crossAxisAlignment: CrossAxisAlignment.end, children: [
                      for (final d in w.days)
                        Expanded(
                          child: Column(mainAxisAlignment: MainAxisAlignment.end, children: [
                            Text('${d.minutes}', style: const TextStyle(fontSize: 11)),
                            const SizedBox(height: 2),
                            Container(margin: const EdgeInsets.symmetric(horizontal: 6), height: maxMin == 0 ? 2 : 100 * d.minutes / maxMin + 2, decoration: BoxDecoration(color: Theme.of(context).colorScheme.primary, borderRadius: BorderRadius.circular(4))),
                            const SizedBox(height: 4),
                            Text(weekdaysShort[d.date.weekday - 1], style: TextStyle(fontSize: 12, fontWeight: sameDay(d.date, DateTime.now()) ? FontWeight.bold : null)),
                          ]),
                        ),
                    ]),
                  ),
                  const SizedBox(height: 16),
                  Text("Yo'nalishlar bo'yicha", style: Theme.of(context).textTheme.titleMedium),
                  for (final m in ['home', 'gym', 'active'])
                    ListTile(leading: ModuleBadge(m), title: Text(modeLabels[m]!), trailing: Text(fmtMinutes(w.byModule[m] ?? 0), style: const TextStyle(fontWeight: FontWeight.bold))),
                  const SizedBox(height: 8),
                  const Text("Ko'rsatkichlar faqat siz kiritgan qaydlardan hisoblanadi; ular tibbiy xulosa emas.", style: TextStyle(fontSize: 12, color: Colors.grey)),
                ]),
              );
            },
          ),
        ),
      ]);
}

class HistoryView extends StatefulWidget {
  const HistoryView({super.key});
  @override
  State<HistoryView> createState() => _HistoryViewState();
}

class _HistoryViewState extends State<HistoryView> {
  String? _module;

  Future<void> _details(HistoryItem h) async {
    if (h.kind != 'session') {
      return showDialog(context: context, builder: (_) => AlertDialog(title: Text(h.title), content: Text("${fmtDate(h.occurredAt)} ${fmtTime(h.occurredAt)}\n${h.minutes} daqiqa${h.distanceKm != null ? '\n${h.distanceKm} km' : ''}${h.detail != null ? '\n\n${h.detail}' : ''}")));
    }
    try {
      final s = Session.fromJson(Map<String, dynamic>.from(await context.read<AppState>().api.get('/sessions/${h.id}')));
      if (!mounted) return;
      showModalBottomSheet(
        context: context,
        isScrollControlled: true,
        builder: (_) => DraggableScrollableSheet(
          expand: false,
          builder: (_, sc) => ListView(controller: sc, padding: const EdgeInsets.all(16), children: [
            Text("${modeLabels[s.mode]} · ${fmtDate(s.startedAt)} ${fmtTime(s.startedAt)}", style: Theme.of(context).textTheme.titleMedium),
            Text("Davomiyligi: ${fmtMinutes(s.durationMinutes ?? 0)}"),
            if (s.notes != null) Padding(padding: const EdgeInsets.only(top: 8), child: Text("Qayd: ${s.notes}")),
            const Divider(),
            for (final l in s.logs) ListTile(dense: true, title: Text(l.exercise.title), subtitle: Text(l.summary)),
          ]),
        ),
      );
    } catch (e) {
      toast(context, errMsg(e));
    }
  }

  @override
  Widget build(BuildContext context) => Column(children: [
        SizedBox(
          height: 52,
          child: ListView(scrollDirection: Axis.horizontal, padding: const EdgeInsets.all(8), children: [
            Padding(padding: const EdgeInsets.only(right: 6), child: ChoiceChip(label: const Text("Hammasi"), selected: _module == null, onSelected: (_) => setState(() => _module = null))),
            for (final m in ['home', 'gym', 'active']) Padding(padding: const EdgeInsets.only(right: 6), child: ChoiceChip(label: Text(modeLabels[m]!), selected: _module == m, onSelected: (_) => setState(() => _module = m))),
          ]),
        ),
        Expanded(
          child: Loader<List<HistoryItem>>(
            key: ValueKey(_module),
            load: () async => (await context.read<AppState>().api.get('/history', query: {'module': _module, 'limit': 100}) as List).map((e) => HistoryItem.fromJson(Map<String, dynamic>.from(e))).toList(),
            builder: (context, items, reload) => RefreshIndicator(
              onRefresh: reload,
              child: items.isEmpty
                  ? ListView(children: const [Padding(padding: EdgeInsets.all(40), child: Center(child: Text("Tarix hozircha bo'sh")))])
                  : ListView.separated(
                      itemCount: items.length,
                      separatorBuilder: (_, __) => const Divider(height: 1),
                      itemBuilder: (_, i) {
                        final h = items[i];
                        return ListTile(
                          leading: ModuleBadge(h.module),
                          title: Text(h.title),
                          subtitle: Text("${fmtDate(h.occurredAt)} ${fmtTime(h.occurredAt)}${h.detail != null ? '\n${h.detail}' : ''}"),
                          isThreeLine: h.detail != null,
                          trailing: Text(h.minutes == null ? '' : fmtMinutes(h.minutes!)),
                          onTap: () => _details(h),
                        );
                      },
                    ),
            ),
          ),
        ),
      ]);
}
