import 'dart:async';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../api_client.dart';
import '../app_state.dart';
import '../models.dart';
import '../ui.dart';
import 'session_screens.dart';

ApiClient _api(BuildContext c) => c.read<AppState>().api;

Color kindColor(String kind) => switch (kind) {
      'strength' => Colors.deepOrange,
      'cardio' => Colors.red,
      'stretch' => Colors.teal,
      _ => Colors.indigo,
    };
IconData kindIcon(String kind) => switch (kind) {
      'strength' => Icons.fitness_center,
      'cardio' => Icons.directions_run,
      'stretch' => Icons.self_improvement,
      _ => Icons.accessibility_new,
    };

String targetText(Map<String, dynamic> item) =>
    item['seconds'] != null ? (item['seconds'] as int >= 90 ? '${(item['seconds'] as int) ~/ 60} daqiqa' : '${item['seconds']} soniya') : '${item['reps']} takror';

/// Mashqlar -> Dasturlar yorlig'i
class ProgramsTab extends StatefulWidget {
  const ProgramsTab({super.key});
  @override
  State<ProgramsTab> createState() => _ProgramsTabState();
}

class _ProgramsTabState extends State<ProgramsTab> with AutomaticKeepAliveClientMixin {
  String _filter = 'all';
  @override
  bool get wantKeepAlive => true;

  static const _chips = {'all': "Barchasi", 'home': "Uyda", 'gym': "Zalda", 'cardio': "Kardio", 'stretch': "Cho'zilish"};

  bool _match(Map<String, dynamic> p) => switch (_filter) {
        'home' || 'gym' => p['mode'] == _filter,
        'cardio' || 'stretch' => p['kind'] == _filter,
        _ => true,
      };

  @override
  Widget build(BuildContext context) {
    super.build(context);
    return Loader<List<Map<String, dynamic>>>(
      load: () => _api(context).getList('/programs'),
      builder: (context, all, reload) {
        final list = all.where(_match).toList();
        return Column(children: [
          SizedBox(
            height: 52,
            child: ListView(scrollDirection: Axis.horizontal, padding: const EdgeInsets.fromLTRB(12, 8, 12, 4), children: [
              for (final e in _chips.entries)
                Padding(padding: const EdgeInsets.only(right: 6), child: ChoiceChip(label: Text(e.value), selected: _filter == e.key, onSelected: (_) => setState(() => _filter = e.key))),
            ]),
          ),
          Expanded(
            child: RefreshIndicator(
              onRefresh: reload,
              child: list.isEmpty
                  ? ListView(children: const [Padding(padding: EdgeInsets.all(40), child: Center(child: Text("Bu toifada dastur yo'q")))])
                  : ListView(padding: const EdgeInsets.all(12), children: [
                      for (final p in list)
                        Padding(
                          padding: const EdgeInsets.only(bottom: 12),
                          child: GestureDetector(
                            onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => ProgramDetailScreen(programId: p['id'] as int))),
                            child: HeroBox(
                              color: kindColor(p['kind'] as String),
                              icon: kindIcon(p['kind'] as String),
                              imageUrl: p['image_url'] as String?,
                              height: 140,
                              child: Row(crossAxisAlignment: CrossAxisAlignment.end, children: [
                                Expanded(child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
                                  Text(p['title'] as String, style: const TextStyle(color: Colors.white, fontSize: 19, fontWeight: FontWeight.bold)),
                                  Text('${p['duration_min']} daqiqa · ${modeLabels[p['mode']] == 'Home' ? 'Uyda' : 'Zalda'} · ${levelLabels[p['difficulty']]}', style: const TextStyle(color: Colors.white70, fontSize: 12)),
                                ])),
                                const CircleAvatar(backgroundColor: Colors.white, child: Icon(Icons.play_arrow, color: Colors.black)),
                              ]),
                            ),
                          ),
                        ),
                    ]),
            ),
          ),
        ]);
      },
    );
  }
}

/// Dastur tafsiloti (mashqlar ro'yxati + "Mashqni boshlash")
class ProgramDetailScreen extends StatelessWidget {
  const ProgramDetailScreen({super.key, required this.programId});
  final int programId;
  @override
  Widget build(BuildContext context) => Scaffold(
        appBar: AppBar(title: const Text("Mashq dasturi")),
        body: Loader<Map<String, dynamic>>(
          load: () => _api(context).getMap('/programs/$programId'),
          builder: (context, p, _) {
            final items = (p['items'] as List).map((e) => Map<String, dynamic>.from(e)).toList();
            final kind = p['kind'] as String;
            return Column(children: [
              Expanded(
                child: ListView(padding: const EdgeInsets.all(16), children: [
                  HeroBox(color: kindColor(kind), icon: kindIcon(kind), imageUrl: p['image_url'] as String?, height: 170),
                  const SizedBox(height: 14),
                  Text(p['title'] as String, style: Theme.of(context).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.bold)),
                  const SizedBox(height: 8),
                  Wrap(spacing: 8, runSpacing: 4, children: [
                    Chip(avatar: const Icon(Icons.timer, size: 18), label: Text('${p['duration_min']} daqiqa')),
                    Chip(avatar: const Icon(Icons.signal_cellular_alt, size: 18), label: Text(levelLabels[p['difficulty']] ?? '')),
                    Chip(avatar: Icon(p['mode'] == 'home' ? Icons.home_rounded : Icons.fitness_center, size: 18), label: Text(p['mode'] == 'home' ? "Uyda" : "Zalda")),
                  ]),
                  const SizedBox(height: 8),
                  Text(p['description'] as String),
                  const SizedBox(height: 16),
                  Text("Mashqlar (${items.length} ta)", style: Theme.of(context).textTheme.titleMedium),
                  const SizedBox(height: 6),
                  for (var i = 0; i < items.length; i++)
                    AppCard(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                      child: Row(children: [
                        CircleAvatar(radius: 15, backgroundColor: kindColor(kind).withAlpha(38), child: Text('${i + 1}', style: TextStyle(color: kindColor(kind), fontWeight: FontWeight.bold, fontSize: 13))),
                        const SizedBox(width: 12),
                        Expanded(child: Text((items[i]['exercise'] as Map)['title'] as String, style: const TextStyle(fontWeight: FontWeight.w600))),
                        Text(targetText(items[i]), style: const TextStyle(color: Colors.grey, fontSize: 12)),
                      ]),
                    ),
                  const SizedBox(height: 8),
                  const SafetyBanner(),
                ]),
              ),
              SafeArea(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
                  child: FilledButton.icon(
                    icon: const Icon(Icons.play_arrow),
                    label: const Text("Mashqni boshlash"),
                    onPressed: items.isEmpty ? null : () => Navigator.push(context, MaterialPageRoute(builder: (_) => ProgramPlayer(program: p))),
                  ),
                ),
              ),
            ]);
          },
        ),
      );
}

/// Dasturni bosqichma-bosqich bajarish: taymer, avtomatik qayd, yakunda seans yakuni
class ProgramPlayer extends StatefulWidget {
  const ProgramPlayer({super.key, required this.program});
  final Map<String, dynamic> program;
  @override
  State<ProgramPlayer> createState() => _ProgramPlayerState();
}

class _ProgramPlayerState extends State<ProgramPlayer> {
  late final List<Map<String, dynamic>> _items = (widget.program['items'] as List).map((e) => Map<String, dynamic>.from(e)).toList();
  final Map<int, int> _sets = {}; // mashq id -> necha marta qayd qilingan
  final Map<int, Map<String, dynamic>> _details = {};
  int? _sessionId;
  int _i = 0, _elapsed = 0;
  bool _running = false, _busy = false, _starting = true;
  String? _error;
  Timer? _t;

  Map<String, dynamic> get _cur => _items[_i];
  int? get _target => _cur['seconds'] as int?;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _start());
  }

  @override
  void dispose() {
    _t?.cancel();
    super.dispose();
  }

  Future<void> _start() async {
    try {
      final api = _api(context);
      final mode = widget.program['mode'] as String;
      final open = await api.get('/sessions', query: {'status': 'in_progress', 'mode': mode, 'limit': 1}) as List;
      final id = open.isNotEmpty ? open.first['id'] as int : (await api.post('/sessions', body: {'mode': mode}))['id'] as int;
      if (!mounted) return;
      setState(() { _sessionId = id; _starting = false; });
      _loadDetail();
    } on ApiException catch (e) {
      if (mounted) setState(() { _error = e.message; _starting = false; });
    }
  }

  Future<void> _loadDetail() async {
    final exId = (_cur['exercise'] as Map)['id'] as int;
    if (_details.containsKey(exId)) return;
    try {
      final d = await _api(context).getMap('/exercises/$exId');
      if (mounted) setState(() => _details[exId] = d);
    } catch (_) {}
  }

  void _toggleTimer() {
    if (_running) {
      _t?.cancel();
      setState(() => _running = false);
      return;
    }
    _t = Timer.periodic(const Duration(seconds: 1), (_) {
      if (!mounted) return;
      setState(() => _elapsed++);
      if (_target != null && _elapsed >= _target!) {
        _t?.cancel();
        _complete();
      }
    });
    setState(() => _running = true);
  }

  Future<void> _complete({bool skip = false}) async {
    if (_busy) return;
    _t?.cancel();
    setState(() { _busy = true; _running = false; });
    try {
      if (!skip && _sessionId != null) {
        final exId = (_cur['exercise'] as Map)['id'] as int;
        final n = (_sets[exId] ?? 0) + 1;
        final secs = _target != null ? (_elapsed > 0 ? _elapsed.clamp(1, _target!).toInt() : _target!) : null;
        await _api(context).post('/sessions/$_sessionId/logs',
            headers: {'Idempotency-Key': newKey()},
            body: {'exercise_id': exId, 'set_no': n, if (secs != null) 'duration_seconds': secs else 'reps': _cur['reps']});
        _sets[exId] = n;
      }
      if (_i >= _items.length - 1) {
        if (!mounted) return;
        final done = await Navigator.push<bool>(context, MaterialPageRoute(builder: (_) => FinishScreen(sessionId: _sessionId!)));
        if (mounted) done == true ? Navigator.pop(context) : setState(() => _busy = false);
        return;
      }
      setState(() { _i++; _elapsed = 0; _busy = false; });
      _loadDetail();
    } on ApiException catch (e) {
      if (mounted) { setState(() => _busy = false); toast(context, e.message); }
    }
  }

  @override
  Widget build(BuildContext context) {
    final kind = widget.program['kind'] as String;
    if (_starting) return Scaffold(appBar: AppBar(), body: const Center(child: CircularProgressIndicator()));
    if (_error != null) return Scaffold(appBar: AppBar(), body: ErrorView(_error!, onRetry: () { setState(() { _error = null; _starting = true; }); _start(); }));
    final ex = Map<String, dynamic>.from(_cur['exercise']);
    final detail = _details[ex['id']];
    final timed = _target != null;
    final left = timed ? (_target! - _elapsed).clamp(0, _target!).toInt() : 0;
    return Scaffold(
      appBar: AppBar(title: Text(widget.program['title'] as String)),
      body: Column(children: [
        LinearProgressIndicator(value: _i / _items.length, minHeight: 6),
        Expanded(
          child: ListView(padding: const EdgeInsets.all(20), children: [
            Text('${_i + 1} / ${_items.length}', style: const TextStyle(color: Colors.grey)),
            const SizedBox(height: 6),
            Text(ex['title'] as String, style: Theme.of(context).textTheme.headlineMedium?.copyWith(fontWeight: FontWeight.bold)),
            const SizedBox(height: 16),
            Center(
              child: RingProgress(
                value: timed ? _elapsed / _target! : 0,
                size: 190,
                stroke: 12,
                color: kindColor(kind),
                trackColor: kindColor(kind).withAlpha(38),
                child: timed
                    ? Text('${two(left ~/ 60)}:${two(left % 60)}', style: const TextStyle(fontSize: 40, fontWeight: FontWeight.bold))
                    : Column(mainAxisSize: MainAxisSize.min, children: [Text('${_cur['reps']}', style: const TextStyle(fontSize: 52, fontWeight: FontWeight.bold)), const Text("takror")]),
              ),
            ),
            const SizedBox(height: 20),
            if (detail != null) ...[
              Text(detail['description'] as String),
              const SizedBox(height: 10),
              SafetyBanner(text: detail['safety_note'] as String),
            ],
          ]),
        ),
        SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
            child: Column(mainAxisSize: MainAxisSize.min, children: [
              if (timed)
                Row(children: [
                  Expanded(child: OutlinedButton.icon(onPressed: _busy ? null : _toggleTimer, icon: Icon(_running ? Icons.pause : Icons.play_arrow), label: Text(_running ? "To'xtatish" : (_elapsed == 0 ? "Boshlash" : "Davom etish")))),
                  const SizedBox(width: 10),
                  Expanded(child: FilledButton(onPressed: _busy ? null : () => _complete(), child: const Text("Bajarildi"))),
                ])
              else
                FilledButton(onPressed: _busy ? null : () => _complete(), child: const Text("Bajardim")),
              TextButton(onPressed: _busy ? null : () => _complete(skip: true), child: const Text("O'tkazib yuborish")),
            ]),
          ),
        ),
      ]),
    );
  }
}
