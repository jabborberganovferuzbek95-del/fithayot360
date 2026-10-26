import 'dart:async';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../api_client.dart';
import '../app_state.dart';
import '../ui.dart';

ApiClient _api(BuildContext c) => c.read<AppState>().api;

const _catLabels = {'stress': "Stress", 'focus': "Diqqat", 'sleep': "Uyqu", 'motivation': "Motivatsiya"};
const _catColors = {'stress': Colors.teal, 'focus': Colors.indigo, 'sleep': Colors.deepPurple, 'motivation': Colors.orange};

class MeditationScreen extends StatefulWidget {
  const MeditationScreen({super.key});
  @override
  State<MeditationScreen> createState() => _MeditationScreenState();
}

class _MeditationScreenState extends State<MeditationScreen> {
  String? _cat;
  int _epoch = 0;

  @override
  Widget build(BuildContext context) => Scaffold(
        appBar: AppBar(title: const Text("Meditatsiya")),
        body: Loader<List<Map<String, dynamic>>>(
          key: ValueKey(_epoch),
          load: () => _api(context).getList('/meditations'),
          builder: (context, all, reload) {
            final list = all.where((m) => _cat == null || m['category'] == _cat).toList();
            return ListView(padding: const EdgeInsets.all(16), children: [
              SizedBox(
                height: 48,
                child: ListView(scrollDirection: Axis.horizontal, children: [
                  Padding(padding: const EdgeInsets.only(right: 6), child: ChoiceChip(label: const Text("Barchasi"), selected: _cat == null, onSelected: (_) => setState(() => _cat = null))),
                  for (final e in _catLabels.entries)
                    Padding(padding: const EdgeInsets.only(right: 6), child: ChoiceChip(label: Text(e.value), selected: _cat == e.key, onSelected: (_) => setState(() => _cat = e.key))),
                ]),
              ),
              if (_cat == null && list.isNotEmpty)
                Padding(
                  padding: const EdgeInsets.only(top: 4, bottom: 12),
                  child: GestureDetector(
                    onTap: () async {
                      await Navigator.push(context, MaterialPageRoute(builder: (_) => MeditationPlayer(item: list.first)));
                      setState(() => _epoch++);
                    },
                    child: HeroBox(
                      color: Colors.teal, icon: Icons.self_improvement, height: 170,
                      child: Row(crossAxisAlignment: CrossAxisAlignment.end, children: [
                        Expanded(child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
                          Text(list.first['title'] as String, style: const TextStyle(color: Colors.white, fontSize: 22, fontWeight: FontWeight.bold)),
                          Text('${list.first['duration_min']} daqiqa · ${_catLabels[list.first['category']]}', style: const TextStyle(color: Colors.white70)),
                        ])),
                        const CircleAvatar(backgroundColor: kMint, child: Icon(Icons.play_arrow, color: Colors.black)),
                      ]),
                    ),
                  ),
                ),
              Padding(padding: const EdgeInsets.only(top: 4, bottom: 6), child: Text("Tavsiya etilganlar", style: Theme.of(context).textTheme.titleMedium)),
              for (final m in list.skip(_cat == null && list.isNotEmpty ? 1 : 0))
                AppCard(
                  onTap: () async {
                    await Navigator.push(context, MaterialPageRoute(builder: (_) => MeditationPlayer(item: m)));
                    setState(() => _epoch++);
                  },
                  child: Row(children: [
                    Container(
                      width: 56, height: 56,
                      decoration: BoxDecoration(color: (_catColors[m['category']] ?? Colors.teal).withAlpha(38), borderRadius: BorderRadius.circular(14)),
                      child: Icon(Icons.self_improvement, color: _catColors[m['category']] ?? Colors.teal, size: 30),
                    ),
                    const SizedBox(width: 14),
                    Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      Text(m['title'] as String, style: const TextStyle(fontWeight: FontWeight.w600)),
                      Text('${_catLabels[m['category']]} · ${m['duration_min']} daqiqa', style: const TextStyle(fontSize: 12, color: Colors.grey)),
                      const SizedBox(height: 2),
                      Text(m['description'] as String, style: const TextStyle(fontSize: 12)),
                    ])),
                    const Icon(Icons.play_circle_fill, color: kGreen, size: 32),
                  ]),
                ),
              const Text("Bu matnli yo'riqnomali nafas va diqqat mashqlari. Ular davolash emas. Yomon his qilsangiz, to'xtating.", style: TextStyle(fontSize: 12, color: Colors.grey)),
            ]);
          },
        ),
      );
}

class MeditationPlayer extends StatefulWidget {
  const MeditationPlayer({super.key, required this.item});
  final Map<String, dynamic> item;
  @override
  State<MeditationPlayer> createState() => _MeditationPlayerState();
}

class _MeditationPlayerState extends State<MeditationPlayer> with SingleTickerProviderStateMixin {
  late final AnimationController _breath = AnimationController(vsync: this, duration: const Duration(seconds: 4))..repeat(reverse: true);
  Timer? _t;
  int _elapsed = 0;
  bool _running = false, _saving = false;

  int get _total => (widget.item['duration_min'] as int) * 60;

  @override
  void dispose() {
    _t?.cancel();
    _breath.dispose();
    super.dispose();
  }

  void _toggle() {
    if (_running) {
      _t?.cancel();
      setState(() => _running = false);
      return;
    }
    _t = Timer.periodic(const Duration(seconds: 1), (_) {
      if (!mounted) return;
      setState(() => _elapsed++);
      if (_elapsed >= _total) _finish();
    });
    setState(() => _running = true);
  }

  Future<void> _finish() async {
    if (_saving) return;
    _saving = true;
    _t?.cancel();
    setState(() => _running = false);
    if (_elapsed < 30) {
      toast(context, "Juda qisqa (30 soniyadan kam), qayd qilinmadi");
      Navigator.pop(context);
      return;
    }
    final mins = (_elapsed / 60).round().clamp(1, 240);
    try {
      await _api(context).post('/meditation-logs', body: {'item_id': widget.item['id'], 'duration_min': mins});
      if (mounted) {
        toast(context, "Meditatsiya saqlandi: $mins daqiqa");
        Navigator.pop(context, true);
      }
    } on ApiException catch (e) {
      _saving = false;
      if (mounted) toast(context, e.message);
    }
  }

  @override
  Widget build(BuildContext context) {
    final int left = (_total - _elapsed).clamp(0, _total).toInt();
    final steps = (widget.item['guide'] as String).split('\n').where((s) => s.trim().isNotEmpty).toList();
    return Scaffold(
      appBar: AppBar(title: Text(widget.item['title'] as String)),
      body: ListView(padding: const EdgeInsets.all(20), children: [
        SizedBox(
          height: 220,
          child: AnimatedBuilder(
            animation: _breath,
            builder: (_, __) => Center(
              child: Container(
                width: 110 + 90 * _breath.value,
                height: 110 + 90 * _breath.value,
                decoration: BoxDecoration(shape: BoxShape.circle, color: kGreen.withValues(alpha: (0.15 + 0.2 * _breath.value).clamp(0.0, 1.0)), border: Border.all(color: kGreen, width: 2)),
                child: Center(child: Text(_breath.status == AnimationStatus.reverse ? "Chiqaring" : "Nafas oling", style: const TextStyle(color: kGreen, fontWeight: FontWeight.w600))),
              ),
            ),
          ),
        ),
        Center(child: Text('${two(left ~/ 60)}:${two(left % 60)}', style: const TextStyle(fontSize: 44, fontWeight: FontWeight.bold))),
        const SizedBox(height: 12),
        Row(children: [
          Expanded(child: FilledButton.icon(onPressed: _toggle, icon: Icon(_running ? Icons.pause : Icons.play_arrow), label: Text(_running ? "To'xtatish" : (_elapsed == 0 ? "Boshlash" : "Davom etish")))),
          const SizedBox(width: 10),
          Expanded(child: OutlinedButton(onPressed: _elapsed == 0 ? null : _finish, child: const Text("Yakunlash"))),
        ]),
        const SizedBox(height: 20),
        Text("Yo'riqnoma", style: Theme.of(context).textTheme.titleMedium),
        const SizedBox(height: 6),
        for (var i = 0; i < steps.length; i++)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 5),
            child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
              CircleAvatar(radius: 12, backgroundColor: kGreen, child: Text('${i + 1}', style: const TextStyle(color: Colors.white, fontSize: 12))),
              const SizedBox(width: 10),
              Expanded(child: Text(steps[i])),
            ]),
          ),
      ]),
    );
  }
}
