import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../api_client.dart';
import '../app_state.dart';
import '../models.dart';
import '../ui.dart';
import 'assistant_screens.dart';
import 'wellness_screens.dart';

ApiClient _api(BuildContext c) => c.read<AppState>().api;

// ======================= Profil formasi (sozlamalar uchun) =======================
class ProfileForm extends StatefulWidget {
  const ProfileForm({super.key, required this.initial, required this.buttonLabel, this.onSaved});
  final Map<String, dynamic> initial;
  final String buttonLabel;
  final VoidCallback? onSaved;
  @override
  State<ProfileForm> createState() => _ProfileFormState();
}

class _ProfileFormState extends State<ProfileForm> {
  String? _goal, _level, _loc, _activity;
  double _minutes = 30;
  bool _busy = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _goal = widget.initial['goal'];
    _level = widget.initial['experience_level'];
    _loc = widget.initial['preferred_location'];
    _activity = widget.initial['activity_level'];
    _minutes = ((widget.initial['daily_minutes'] ?? 30) as int).clamp(5, 120).toDouble();
  }

  Widget _drop(String label, Map<String, String> items, String? value, ValueChanged<String?> onChanged) => Padding(
        padding: const EdgeInsets.only(bottom: 14),
        child: DropdownButtonFormField<String>(
          initialValue: value,
          decoration: InputDecoration(labelText: label),
          items: [for (final e in items.entries) DropdownMenuItem(value: e.key, child: Text(e.value))],
          onChanged: onChanged,
        ),
      );

  Future<void> _save() async {
    if (_goal == null || _level == null || _loc == null) return setState(() => _error = "Maqsad, daraja va joyni tanlang");
    setState(() { _busy = true; _error = null; });
    try {
      await context.read<AppState>().updateMe({
        'goal': _goal, 'experience_level': _level, 'preferred_location': _loc, 'daily_minutes': _minutes.round(),
        if (_activity != null) 'activity_level': _activity,
      });
      if (mounted) {
        toast(context, "Profil saqlandi");
        widget.onSaved?.call();
      }
    } on ApiException catch (e) {
      if (mounted) setState(() => _error = e.message);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) => Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        _drop("Maqsad", goalLabels, _goal, (v) => setState(() => _goal = v)),
        _drop("Tajriba darajasi", levelLabels, _level, (v) => setState(() => _level = v)),
        _drop("Qayerda mashq qilasiz", locationLabels, _loc, (v) => setState(() => _loc = v)),
        _drop("Faollik darajasi", activityLabels, _activity, (v) => setState(() => _activity = v)),
        Text("Kuniga mavjud vaqt: ${_minutes.round()} daqiqa"),
        Slider(value: _minutes, min: 5, max: 120, divisions: 23, label: '${_minutes.round()}', onChanged: (v) => setState(() => _minutes = v)),
        if (_error != null) Padding(padding: const EdgeInsets.only(bottom: 8), child: Text(_error!, style: TextStyle(color: Theme.of(context).colorScheme.error))),
        FilledButton(onPressed: _busy ? null : _save, child: Text(widget.buttonLabel)),
      ]);
}

// ======================= Birinchi sozlash: 2 qadam =======================
class ProfileSetupScreen extends StatefulWidget {
  const ProfileSetupScreen({super.key});
  @override
  State<ProfileSetupScreen> createState() => _ProfileSetupScreenState();
}

class _ProfileSetupScreenState extends State<ProfileSetupScreen> {
  int _step = 0;
  String? _goal;
  String _loc = 'mixed';
  String _level = 'beginner';
  String _activity = 'moderate';
  double _minutes = 30;
  bool _busy = false;
  String? _error;

  static const _goalDetails = {
    'weight_loss': (
      title: "Vazn tashlash",
      sub: "Yog'larni eritish va yengillik",
      icon: Icons.monitor_weight_outlined,
      color: Color(0xFF10B981),
    ),
    'muscle_gain': (
      title: "Mushak massasini oshirish",
      sub: "Kuch yig'ish va tana shaklini rivojlantirish",
      icon: Icons.fitness_center_rounded,
      color: Color(0xFF6366F1),
    ),
    'stay_fit': (
      title: "Formani saqlash",
      sub: "Doimiy tonus va umumiy baquvvatlik",
      icon: Icons.accessibility_new_rounded,
      color: Color(0xFF0EA5E9),
    ),
    'healthy_lifestyle': (
      title: "Sog'lom turmush tarzi",
      sub: "To'g'ri odatlar, uyqu va ichki uyg'unlik",
      icon: Icons.spa_rounded,
      color: Color(0xFF14B8A6),
    ),
    'reduce_stress': (
      title: "Stressni kamaytirish",
      sub: "Tinchlanish, yengil harakat va meditatsiya",
      icon: Icons.self_improvement_rounded,
      color: Color(0xFF8B5CF6),
    ),
    'more_energy': (
      title: "Ko'proq energiyaga ega bo'lish",
      sub: "Kun davomida yuqori faollik va tetiklik",
      icon: Icons.bolt_rounded,
      color: Color(0xFFF59E0B),
    ),
  };

  static const _locationOptions = [
    (key: 'home', label: "Uyda", sub: "Gilamcha & tana vazni", icon: Icons.home_rounded),
    (key: 'gym', label: "Sport zali", sub: "Trenajyor va og'irliklar", icon: Icons.fitness_center_rounded),
    (key: 'outdoor', label: "Ochiq havoda", sub: "Yugurish & turniklar", icon: Icons.park_rounded),
    (key: 'mixed', label: "Aralash", sub: "Uy va zal navbatma-navbat", icon: Icons.shuffle_rounded),
  ];

  static const _levelOptions = [
    (key: 'beginner', label: "Boshlang'ich", icon: Icons.spa_outlined, hint: "Yangi boshlovchilar"),
    (key: 'intermediate', label: "O'rta", icon: Icons.trending_up_rounded, hint: "Tajribasi borlar"),
    (key: 'advanced', label: "Tajribali", icon: Icons.whatshot_rounded, hint: "Yuqori yuklama"),
  ];

  static const _activityOptions = [
    (key: 'sedentary', label: "Kam harakat", sub: "Asosan o'tirib ishlash yoki o'qish", icon: Icons.chair_outlined),
    (key: 'moderate', label: "O'rtacha", sub: "Haftasiga 2-3 marta mashq yoki muntazam piyoda yurish", icon: Icons.directions_walk_rounded),
    (key: 'active', label: "Faol", sub: "Haftasiga 4+ marta jismoniy mashg'ulot yoki faol mehnat", icon: Icons.directions_run_rounded),
  ];

  Future<void> _finish() async {
    if (_goal == null) {
      setState(() => _step = 0);
      return;
    }
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await context.read<AppState>().updateMe({
        'goal': _goal,
        'experience_level': _level,
        'preferred_location': _loc,
        'daily_minutes': _minutes.round(),
        'activity_level': _activity,
      });
    } on ApiException catch (e) {
      if (mounted) setState(() => _error = e.message);
    } catch (_) {
      if (mounted) setState(() => _error = "Tarmoqda xatolik yuz berdi. Qayta urinib ko'ring.");
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Widget _buildStep0GoalSelection(bool isDark) {
    return ListView(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
      children: [
        // Badge
        Row(
          children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
              decoration: BoxDecoration(
                color: kGreen.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: kGreen.withValues(alpha: 0.25)),
              ),
              child: const Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.auto_awesome, color: kGreen, size: 14),
                  SizedBox(width: 6),
                  Text(
                    "SHAXSIY REJA",
                    style: TextStyle(
                      color: kGreen,
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 0.5,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        const Text(
          "Asosiy maqsadingiz nima?",
          style: TextStyle(
            fontSize: 26,
            fontWeight: FontWeight.w800,
            letterSpacing: -0.5,
            height: 1.2,
          ),
        ),
        const SizedBox(height: 6),
        Text(
          "Sizga mos shaxsiy mashq va salomatlik rejasini shakllantirish uchun tanlang.",
          style: TextStyle(
            fontSize: 14,
            color: isDark ? Colors.grey.shade400 : Colors.grey.shade600,
            height: 1.4,
          ),
        ),
        const SizedBox(height: 20),

        // Goals List
        for (final g in setupGoals) ...[
          Builder(builder: (context) {
            final info = _goalDetails[g];
            final title = info?.title ?? goalLabels[g] ?? g;
            final sub = info?.sub ?? "FitHayot shaxsiy tavsiyasi";
            final icon = info?.icon ?? goalIcon(g);
            final color = info?.color ?? kGreen;
            final isSelected = _goal == g;

            return Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 220),
                curve: Curves.easeOutCubic,
                decoration: BoxDecoration(
                  color: isSelected
                      ? (isDark ? color.withValues(alpha: 0.16) : color.withValues(alpha: 0.08))
                      : (isDark ? const Color(0xFF1B2420) : Colors.white),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(
                    color: isSelected ? color : (isDark ? Colors.white12 : Colors.grey.shade200),
                    width: isSelected ? 2.2 : 1,
                  ),
                  boxShadow: [
                    if (isSelected)
                      BoxShadow(
                        color: color.withValues(alpha: 0.2),
                        blurRadius: 16,
                        offset: const Offset(0, 4),
                      )
                    else
                      BoxShadow(
                        color: Colors.black.withValues(alpha: isDark ? 0.2 : 0.03),
                        blurRadius: 8,
                        offset: const Offset(0, 2),
                      ),
                  ],
                ),
                child: Material(
                  color: Colors.transparent,
                  child: InkWell(
                    borderRadius: BorderRadius.circular(20),
                    onTap: () {
                      setState(() {
                        _goal = g;
                        _error = null;
                      });
                    },
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                      child: Row(
                        children: [
                          // Icon container
                          Container(
                            width: 50,
                            height: 50,
                            decoration: BoxDecoration(
                              color: isSelected
                                  ? color
                                  : (isDark ? Colors.white.withValues(alpha: 0.06) : color.withValues(alpha: 0.12)),
                              borderRadius: BorderRadius.circular(15),
                            ),
                            child: Icon(
                              icon,
                              color: isSelected ? Colors.white : color,
                              size: 26,
                            ),
                          ),
                          const SizedBox(width: 14),
                          // Title & description
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  title,
                                  style: TextStyle(
                                    fontSize: 16,
                                    fontWeight: isSelected ? FontWeight.w700 : FontWeight.w600,
                                    color: isDark ? Colors.white : Colors.black87,
                                  ),
                                ),
                                const SizedBox(height: 3),
                                Text(
                                  sub,
                                  style: TextStyle(
                                    fontSize: 12.5,
                                    color: isDark ? Colors.grey.shade400 : Colors.grey.shade600,
                                    height: 1.25,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(width: 8),
                          // Radio check circle
                          AnimatedContainer(
                            duration: const Duration(milliseconds: 200),
                            width: 24,
                            height: 24,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              color: isSelected ? color : Colors.transparent,
                              border: Border.all(
                                color: isSelected ? color : Colors.grey.shade400,
                                width: 2,
                              ),
                            ),
                            child: isSelected
                                ? const Icon(Icons.check, size: 16, color: Colors.white)
                                : null,
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            );
          }),
        ],
        const SizedBox(height: 80),
      ],
    );
  }

  Widget _buildStep1Preferences(bool isDark) {
    return ListView(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
      children: [
        // Badge
        Row(
          children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
              decoration: BoxDecoration(
                color: const Color(0xFF6366F1).withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: const Color(0xFF6366F1).withValues(alpha: 0.25)),
              ),
              child: const Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.tune_rounded, color: Color(0xFF6366F1), size: 14),
                  SizedBox(width: 6),
                  Text(
                    "SHAXSIY SOZLAMALAR",
                    style: TextStyle(
                      color: Color(0xFF6366F1),
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 0.5,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        const Text(
          "Mashg'ulot parametrlari",
          style: TextStyle(
            fontSize: 26,
            fontWeight: FontWeight.w800,
            letterSpacing: -0.5,
            height: 1.2,
          ),
        ),
        const SizedBox(height: 6),
        Text(
          "Dasturingizni imkoniyatlaringiz va jadvalingizga to'liq moslashtiramiz.",
          style: TextStyle(
            fontSize: 14,
            color: isDark ? Colors.grey.shade400 : Colors.grey.shade600,
            height: 1.4,
          ),
        ),
        const SizedBox(height: 24),

        // Section 1: Qayerda mashq qilasiz?
        Row(
          children: [
            Container(
              padding: const EdgeInsets.all(6),
              decoration: BoxDecoration(
                color: kGreen.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Icon(Icons.place_outlined, color: kGreen, size: 18),
            ),
            const SizedBox(width: 10),
            const Text(
              "Qayerda mashq qilasiz?",
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
            ),
          ],
        ),
        const SizedBox(height: 12),
        GridView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 2,
            crossAxisSpacing: 10,
            mainAxisSpacing: 10,
            childAspectRatio: 1.35,
          ),
          itemCount: _locationOptions.length,
          itemBuilder: (context, i) {
            final item = _locationOptions[i];
            final isSel = _loc == item.key;
            return InkWell(
              onTap: () => setState(() => _loc = item.key),
              borderRadius: BorderRadius.circular(16),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: isSel
                      ? (isDark ? kGreen.withValues(alpha: 0.2) : kGreen.withValues(alpha: 0.08))
                      : (isDark ? const Color(0xFF1B2420) : Colors.white),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(
                    color: isSel ? kGreen : (isDark ? Colors.white12 : Colors.grey.shade200),
                    width: isSel ? 2 : 1,
                  ),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Icon(item.icon, color: isSel ? kGreen : Colors.grey.shade500, size: 24),
                        if (isSel)
                          const Icon(Icons.check_circle, color: kGreen, size: 18),
                      ],
                    ),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          item.label,
                          style: TextStyle(
                            fontSize: 15,
                            fontWeight: isSel ? FontWeight.w700 : FontWeight.w600,
                            color: isDark ? Colors.white : Colors.black87,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          item.sub,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontSize: 11,
                            color: isDark ? Colors.grey.shade400 : Colors.grey.shade600,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            );
          },
        ),

        const SizedBox(height: 24),

        // Section 2: Tajriba darajasi
        Row(
          children: [
            Container(
              padding: const EdgeInsets.all(6),
              decoration: BoxDecoration(
                color: Colors.blue.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Icon(Icons.fitness_center_outlined, color: Colors.blue, size: 18),
            ),
            const SizedBox(width: 10),
            const Text(
              "Tajriba darajangiz",
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
            ),
          ],
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            for (final lvl in _levelOptions) ...[
              Expanded(
                child: InkWell(
                  onTap: () => setState(() => _level = lvl.key),
                  borderRadius: BorderRadius.circular(16),
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 200),
                    padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 8),
                    decoration: BoxDecoration(
                      color: _level == lvl.key
                          ? (isDark ? kGreen.withValues(alpha: 0.2) : kGreen.withValues(alpha: 0.08))
                          : (isDark ? const Color(0xFF1B2420) : Colors.white),
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(
                        color: _level == lvl.key ? kGreen : (isDark ? Colors.white12 : Colors.grey.shade200),
                        width: _level == lvl.key ? 2 : 1,
                      ),
                    ),
                    child: Column(
                      children: [
                        Icon(lvl.icon, color: _level == lvl.key ? kGreen : Colors.grey.shade500, size: 22),
                        const SizedBox(height: 6),
                        Text(
                          lvl.label,
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: _level == lvl.key ? FontWeight.w700 : FontWeight.w600,
                            color: isDark ? Colors.white : Colors.black87,
                          ),
                          textAlign: TextAlign.center,
                        ),
                        const SizedBox(height: 2),
                        Text(
                          lvl.hint,
                          style: TextStyle(
                            fontSize: 10.5,
                            color: isDark ? Colors.grey.shade400 : Colors.grey.shade600,
                          ),
                          textAlign: TextAlign.center,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              if (lvl != _levelOptions.last) const SizedBox(width: 8),
            ],
          ],
        ),

        const SizedBox(height: 24),

        // Section 3: Faollik darajasi
        Row(
          children: [
            Container(
              padding: const EdgeInsets.all(6),
              decoration: BoxDecoration(
                color: Colors.orange.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Icon(Icons.bolt_outlined, color: Colors.orange, size: 18),
            ),
            const SizedBox(width: 10),
            const Text(
              "Kunlik faollik darajasi",
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
            ),
          ],
        ),
        const SizedBox(height: 12),
        for (final act in _activityOptions) ...[
          Padding(
            padding: const EdgeInsets.only(bottom: 10),
            child: InkWell(
              onTap: () => setState(() => _activity = act.key),
              borderRadius: BorderRadius.circular(16),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                decoration: BoxDecoration(
                  color: _activity == act.key
                      ? (isDark ? kGreen.withValues(alpha: 0.2) : kGreen.withValues(alpha: 0.08))
                      : (isDark ? const Color(0xFF1B2420) : Colors.white),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(
                    color: _activity == act.key ? kGreen : (isDark ? Colors.white12 : Colors.grey.shade200),
                    width: _activity == act.key ? 2 : 1,
                  ),
                ),
                child: Row(
                  children: [
                    Container(
                      width: 40,
                      height: 40,
                      decoration: BoxDecoration(
                        color: _activity == act.key
                            ? kGreen.withValues(alpha: 0.15)
                            : (isDark ? Colors.white10 : Colors.grey.shade100),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Icon(act.icon, color: _activity == act.key ? kGreen : Colors.grey.shade600, size: 22),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            act.label,
                            style: TextStyle(
                              fontSize: 15,
                              fontWeight: _activity == act.key ? FontWeight.w700 : FontWeight.w600,
                              color: isDark ? Colors.white : Colors.black87,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            act.sub,
                            style: TextStyle(
                              fontSize: 12,
                              color: isDark ? Colors.grey.shade400 : Colors.grey.shade600,
                            ),
                          ),
                        ],
                      ),
                    ),
                    if (_activity == act.key)
                      const Icon(Icons.check_circle, color: kGreen, size: 20),
                  ],
                ),
              ),
            ),
          ),
        ],

        const SizedBox(height: 20),

        // Section 4: Kuniga mavjud vaqt
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: isDark ? const Color(0xFF1B2420) : Colors.white,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: isDark ? Colors.white12 : Colors.grey.shade200),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Row(
                    children: [
                      Icon(Icons.schedule_rounded, color: kGreen, size: 20),
                      SizedBox(width: 8),
                      Text(
                        "Kuniga mashg'ulot vaqti",
                        style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700),
                      ),
                    ],
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: kGreen.withValues(alpha: 0.14),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Text(
                      "${_minutes.round()} daqiqa",
                      style: const TextStyle(
                        color: kGreen,
                        fontWeight: FontWeight.w800,
                        fontSize: 14,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              SliderTheme(
                data: SliderTheme.of(context).copyWith(
                  activeTrackColor: kGreen,
                  inactiveTrackColor: isDark ? Colors.white12 : Colors.grey.shade200,
                  thumbColor: kGreen,
                  trackHeight: 6,
                  overlayColor: kGreen.withValues(alpha: 0.2),
                ),
                child: Slider(
                  value: _minutes,
                  min: 10,
                  max: 90,
                  divisions: 16,
                  onChanged: (v) => setState(() => _minutes = v),
                ),
              ),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [15, 30, 45, 60].map((mins) {
                  final isCurrent = _minutes.round() == mins;
                  return InkWell(
                    onTap: () => setState(() => _minutes = mins.toDouble()),
                    borderRadius: BorderRadius.circular(10),
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                      decoration: BoxDecoration(
                        color: isCurrent
                            ? kGreen
                            : (isDark ? Colors.white.withValues(alpha: 0.06) : Colors.grey.shade100),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Text(
                        "$mins daq",
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: isCurrent ? FontWeight.w700 : FontWeight.w500,
                          color: isCurrent ? Colors.white : (isDark ? Colors.white70 : Colors.black87),
                        ),
                      ),
                    ),
                  );
                }).toList(),
              ),
            ],
          ),
        ),

        const SizedBox(height: 16),
        const SafetyBanner(),
        if (_error != null)
          Padding(
            padding: const EdgeInsets.only(top: 12),
            child: Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.red.shade50,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.red.shade200),
              ),
              child: Row(
                children: [
                  Icon(Icons.error_outline, color: Colors.red.shade700, size: 20),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      _error!,
                      style: TextStyle(color: Colors.red.shade900, fontSize: 13),
                    ),
                  ),
                ],
              ),
            ),
          ),
        const SizedBox(height: 80),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: isDark ? const Color(0xFF0F1512) : const Color(0xFFF7FAF8),
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: _step == 1
            ? IconButton(
                icon: const Icon(Icons.arrow_back_ios_new_rounded, size: 20),
                onPressed: () => setState(() => _step = 0),
              )
            : null,
        title: Row(
          children: [
            for (var i = 0; i < 2; i++)
              Expanded(
                child: Container(
                  margin: EdgeInsets.only(right: i == 0 ? 8 : 0),
                  height: 6,
                  decoration: BoxDecoration(
                    color: i <= _step ? kGreen : (isDark ? Colors.white12 : Colors.grey.shade300),
                    borderRadius: BorderRadius.circular(3),
                  ),
                ),
              ),
          ],
        ),
        actions: [
          TextButton.icon(
            onPressed: () => Navigator.pop(context),
            icon: const Icon(Icons.close, size: 18, color: Colors.grey),
            label: const Text("Yopish", style: TextStyle(color: Colors.grey, fontSize: 13)),
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: SafeArea(
        child: Stack(
          children: [
            Positioned.fill(
              child: AnimatedSwitcher(
                duration: const Duration(milliseconds: 250),
                transitionBuilder: (child, anim) => FadeTransition(
                  opacity: anim,
                  child: child,
                ),
                child: _step == 0
                    ? KeyedSubtree(
                        key: const ValueKey("step_0"),
                        child: _buildStep0GoalSelection(isDark),
                      )
                    : KeyedSubtree(
                        key: const ValueKey("step_1"),
                        child: _buildStep1Preferences(isDark),
                      ),
              ),
            ),

            // Pinned Bottom Action Button
            Positioned(
              left: 0,
              right: 0,
              bottom: 0,
              child: Container(
                padding: const EdgeInsets.fromLTRB(20, 12, 20, 16),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [
                      (isDark ? const Color(0xFF0F1512) : const Color(0xFFF7FAF8)).withValues(alpha: 0.0),
                      (isDark ? const Color(0xFF0F1512) : const Color(0xFFF7FAF8)).withValues(alpha: 0.92),
                      (isDark ? const Color(0xFF0F1512) : const Color(0xFFF7FAF8)),
                    ],
                  ),
                ),
                child: SizedBox(
                  height: 54,
                  child: ElevatedButton(
                    onPressed: _busy || (_step == 0 && _goal == null)
                        ? null
                        : () {
                            if (_step == 0) {
                              setState(() => _step = 1);
                            } else {
                              _finish();
                            }
                          },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: kGreen,
                      foregroundColor: Colors.white,
                      disabledBackgroundColor: isDark ? Colors.white12 : Colors.grey.shade300,
                      disabledForegroundColor: Colors.grey.shade500,
                      elevation: _step == 0 && _goal == null ? 0 : 3,
                      shadowColor: kGreen.withValues(alpha: 0.4),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                    ),
                    child: _busy
                        ? const SizedBox(
                            width: 24,
                            height: 24,
                            child: CircularProgressIndicator(strokeWidth: 2.5, color: Colors.white),
                          )
                        : Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Text(
                                _step == 0 ? "Davom etish" : "FitHayotni boshlash",
                                style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                              ),
                              const SizedBox(width: 8),
                              Icon(
                                _step == 0 ? Icons.arrow_forward_rounded : Icons.rocket_launch_rounded,
                                size: 18,
                              ),
                            ],
                          ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ======================= Mening profilim (tab) =======================
class ProfileScreen extends StatelessWidget {
  const ProfileScreen({super.key});

  Widget _menuTile({
    required BuildContext context,
    required IconData icon,
    required Color color,
    required String title,
    required String sub,
    required Widget page,
    required bool isDark,
  }) =>
      Container(
        margin: const EdgeInsets.only(bottom: 10),
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
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            borderRadius: BorderRadius.circular(18),
            onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => page)),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
              child: Row(
                children: [
                  Container(
                    width: 44,
                    height: 44,
                    decoration: BoxDecoration(
                      color: color.withAlpha(isDark ? 45 : 30),
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: Icon(icon, color: color, size: 22),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          title,
                          style: TextStyle(
                            fontWeight: FontWeight.w700,
                            fontSize: 14.5,
                            color: isDark ? Colors.white : Colors.black87,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          sub,
                          style: TextStyle(
                            fontSize: 12,
                            color: isDark ? Colors.grey.shade400 : Colors.grey.shade600,
                          ),
                        ),
                      ],
                    ),
                  ),
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

  Widget _statCard({
    required String title,
    required String value,
    required IconData icon,
    required Color color,
    required bool isDark,
  }) =>
      Expanded(
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
                  fontSize: 17,
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

  @override
  Widget build(BuildContext context) {
    final me = context.watch<AppState>().me!;
    final name = (me.fullName ?? '').trim().isNotEmpty ? me.fullName! : me.email.split('@').first;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final goalName = goalLabels[me.profile['goal']] ?? "Sog'lom hayot yo'lida";

    return Scaffold(
      backgroundColor: Colors.transparent,
      appBar: AppBar(
        title: const Text(
          "Mening profilim",
          style: TextStyle(fontWeight: FontWeight.w800, fontSize: 20),
        ),
        elevation: 0,
        backgroundColor: isDark ? const Color(0xFF141C17).withAlpha(220) : Colors.white.withAlpha(220),
        actions: [
          IconButton(
            tooltip: "Sozlamalar",
            style: IconButton.styleFrom(
              backgroundColor: isDark ? const Color(0xFF1D2621) : const Color(0xFFF0F4F1),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
            icon: const Icon(Icons.settings_outlined, size: 20),
            onPressed: () => Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const SettingsScreen()),
            ),
          ),
          const SizedBox(width: 12),
        ],
      ),
      body: ScreenBackground(
        imageName: 'profile_bg.jpg',
        child: Loader<Map<String, dynamic>>(
        load: () => _api(context).getMap('/me/summary'),
        builder: (context, s, reload) => RefreshIndicator(
          onRefresh: reload,
          color: kGreen,
          child: ListView(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            children: [
              // User Profil Kartasi
              Container(
                padding: const EdgeInsets.all(18),
                decoration: BoxDecoration(
                  color: isDark ? const Color(0xFF161F1A) : Colors.white,
                  borderRadius: BorderRadius.circular(22),
                  border: Border.all(color: isDark ? Colors.white10 : Colors.black.withAlpha(10)),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withAlpha(isDark ? 20 : 6),
                      blurRadius: 10,
                      offset: const Offset(0, 3),
                    ),
                  ],
                ),
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(3),
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        border: Border.all(color: kGreen, width: 2.5),
                      ),
                      child: CircleAvatar(
                        radius: 30,
                        backgroundColor: kGreen,
                        child: Text(
                          name.isEmpty ? '?' : name[0].toUpperCase(),
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 24,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            name,
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.w800,
                              color: isDark ? Colors.white : Colors.black87,
                            ),
                          ),
                          const SizedBox(height: 3),
                          Text(
                            me.email,
                            style: TextStyle(
                              fontSize: 12,
                              color: isDark ? Colors.grey.shade400 : Colors.grey.shade600,
                            ),
                          ),
                          const SizedBox(height: 6),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                            decoration: BoxDecoration(
                              color: kGreen.withAlpha(isDark ? 40 : 25),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                const Icon(Icons.flag_rounded, size: 12, color: kGreen),
                                const SizedBox(width: 4),
                                Text(
                                  goalName,
                                  style: const TextStyle(
                                    fontSize: 11,
                                    fontWeight: FontWeight.w700,
                                    color: kGreen,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 16),

              // Faollik statistika ko'rsatkichlari (3 ta blok)
              Row(
                children: [
                  _statCard(
                    title: "Seanslar",
                    value: '${s['sessions_total']}',
                    icon: Icons.fitness_center_rounded,
                    color: Colors.indigo,
                    isDark: isDark,
                  ),
                  const SizedBox(width: 10),
                  _statCard(
                    title: "Faol kun (30 kun)",
                    value: '${s['active_days_30']}',
                    icon: Icons.calendar_month_rounded,
                    color: Colors.teal,
                    isDark: isDark,
                  ),
                  const SizedBox(width: 10),
                  _statCard(
                    title: "Ketma-ketlik",
                    value: '${s['streak']} kun',
                    icon: Icons.local_fire_department_rounded,
                    color: Colors.orange,
                    isDark: isDark,
                  ),
                ],
              ),

              const SizedBox(height: 18),

              // Bo'limlar menyusi
              _menuTile(
                context: context,
                icon: Icons.flag_rounded,
                color: kGreen,
                title: "Maqsadlarim",
                sub: "Qadam, suv, uyqu, mashq, kaloriya",
                page: const GoalsScreen(),
                isDark: isDark,
              ),
              _menuTile(
                context: context,
                icon: Icons.emoji_events_rounded,
                color: Colors.amber.shade700,
                title: "Yutuqlar va medallar",
                sub: "Natijalar, seriyalar va mukofotlar",
                page: const AchievementsScreen(),
                isDark: isDark,
              ),
              _menuTile(
                context: context,
                icon: Icons.notifications_none_rounded,
                color: Colors.blue,
                title: "Bildirishnomalar",
                sub: "Maslahatlar va tizim eslatmalari",
                page: const NotificationsScreen(),
                isDark: isDark,
              ),
              _menuTile(
                context: context,
                icon: Icons.chat_bubble_outline_rounded,
                color: Colors.teal,
                title: "FitMaslahatchi",
                sub: "Qoidalar asosidagi maslahatlar",
                page: const CoachScreen(),
                isDark: isDark,
              ),
              _menuTile(
                context: context,
                icon: Icons.workspace_premium_rounded,
                color: Colors.amber,
                title: "FitHayot Premium",
                sub: "Tez orada kutilayotgan imkoniyatlar",
                page: const PremiumScreen(),
                isDark: isDark,
              ),
              _menuTile(
                context: context,
                icon: Icons.settings_rounded,
                color: Colors.blueGrey,
                title: "Sozlamalar",
                sub: "Profil, mavzu, maxfiylik va yordam",
                page: const SettingsScreen(),
                isDark: isDark,
              ),

              const SizedBox(height: 16),
            ],
          ),
        ),
      ),
    ),
  );
  }
}

// ======================= Sozlamalar =======================
class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key});

  Widget _item(BuildContext context, IconData icon, String title, Widget page) => ListTile(
        leading: Icon(icon),
        title: Text(title),
        trailing: const Icon(Icons.chevron_right),
        onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => page)),
      );

  @override
  Widget build(BuildContext context) {
    final app = context.watch<AppState>();
    return Scaffold(
      appBar: AppBar(title: const Text("Sozlamalar")),
      body: ListView(children: [
        _item(context, Icons.person_outline, "Profil ma'lumotlari", const EditProfileScreen()),
        _item(context, Icons.flag_outlined, "Maqsadlar", const GoalsScreen()),
        const SwitchListTile(secondary: Icon(Icons.notifications_none), title: Text("Bildirishnomalar"), subtitle: Text("Telefon eslatmalari keyingi versiyada"), value: false, onChanged: null),
        ListTile(
          leading: const Icon(Icons.language),
          title: const Text("Ilova tili"),
          trailing: DropdownButton<String>(
            value: 'uz',
            items: const [DropdownMenuItem(value: 'uz', child: Text("O'zbekcha")), DropdownMenuItem(value: 'ru', child: Text("Русский (tez orada)")), DropdownMenuItem(value: 'en', child: Text("English (tez orada)"))],
            onChanged: (v) { if (v != 'uz') toast(context, "Bu til keyingi versiyada qo'shiladi"); },
          ),
        ),
        ListTile(
          leading: const Icon(Icons.dark_mode_outlined),
          title: const Text("Mavzu"),
          trailing: DropdownButton<ThemeMode>(
            value: app.themeMode,
            items: const [DropdownMenuItem(value: ThemeMode.system, child: Text("Tizim")), DropdownMenuItem(value: ThemeMode.light, child: Text("Yorug'")), DropdownMenuItem(value: ThemeMode.dark, child: Text("Qorong'i"))],
            onChanged: (v) { if (v != null) app.setThemeMode(v); },
          ),
        ),
        _item(context, Icons.privacy_tip_outlined, "Maxfiylik va xavfsizlik", const PrivacyScreen()),
        _item(context, Icons.help_outline, "Yordam va qo'llab-quvvatlash", const HelpScreen()),
        ListTile(
          leading: const Icon(Icons.info_outline),
          title: const Text("Ilova haqida"),
          trailing: const Icon(Icons.chevron_right),
          onTap: () => showAboutDialog(
            context: context,
            applicationName: "FitHayot 360",
            applicationVersion: "3.0.0",
            children: const [Text("Home, Gym va Active mashg'ulotlari, ovqatlanish, suv, uyqu, meditatsiya va odatlarni bitta hisobda yuritish. Ilova tibbiy maslahat bermaydi va sun'iy intellekt ishlatmaydi. 18 yosh va undan kattalar uchun.")],
          ),
        ),
        ListTile(
          leading: const Icon(Icons.refresh, color: kMint),
          title: const Text("Ma'lumotlarni yangilash"),
          onTap: () async {
            await app.init();
            if (context.mounted) toast(context, "Ma'lumotlar yangilandi");
          },
        ),
      ]),
    );
  }
}

class EditProfileScreen extends StatefulWidget {
  const EditProfileScreen({super.key});
  @override
  State<EditProfileScreen> createState() => _EditProfileScreenState();
}

class _EditProfileScreenState extends State<EditProfileScreen> {
  late final _name = TextEditingController(text: context.read<AppState>().me?.fullName ?? '');
  bool _busy = false;

  Future<void> _saveName() async {
    if (_name.text.trim().isEmpty) return toast(context, "Ismni kiriting");
    setState(() => _busy = true);
    try {
      await context.read<AppState>().updateMe({'full_name': _name.text.trim()});
      if (mounted) toast(context, "Ism saqlandi");
    } on ApiException catch (e) {
      if (mounted) toast(context, e.message);
    }
    if (mounted) setState(() => _busy = false);
  }

  @override
  Widget build(BuildContext context) {
    final me = context.watch<AppState>().me!;
    return Scaffold(
      appBar: AppBar(title: const Text("Profil ma'lumotlari")),
      body: ListView(padding: const EdgeInsets.all(16), children: [
        TextField(controller: _name, textCapitalization: TextCapitalization.words, decoration: InputDecoration(labelText: "Ism va familiya", suffixIcon: IconButton(icon: const Icon(Icons.check), onPressed: _busy ? null : _saveName))),
        const SizedBox(height: 8),
        Text(me.email, style: const TextStyle(color: Colors.grey)),
        const SizedBox(height: 20),
        ProfileForm(initial: me.profile, buttonLabel: "Saqlash"),
      ]),
    );
  }
}

class PrivacyScreen extends StatelessWidget {
  const PrivacyScreen({super.key});

  Future<void> _export(BuildContext context) async {
    try {
      final s = await _api(context).getMap('/me/export');
      await showDialog(
        context: context,
        builder: (_) => AlertDialog(
          title: const Text("Ma'lumotlaringiz tayyor"),
          content: Text("Hisobingizda: ${(s['sessions'] as List).length} ta seans, ${(s['activities'] as List).length} ta faollik, ${(s['plans'] as List).length} ta reja.\n\nTo'liq JSON fayl yuborish keyingi versiyada qo'shiladi (hozircha /me/export API orqali olinadi)."),
          actions: [TextButton(onPressed: () => Navigator.pop(context), child: const Text("Yopish"))],
        ),
      );
    } catch (e) {
      toast(context, errMsg(e));
    }
  }

  Future<void> _delete(BuildContext context) async {
    final pass = TextEditingController();
    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text("Hisobni o'chirish"),
        content: Column(mainAxisSize: MainAxisSize.min, children: [
          const Text("Barcha rejalar, seanslar, suv, uyqu, ovqat va boshqa qaydlar qaytarib bo'lmas tarzda o'chiriladi. Tasdiqlash uchun parolingizni kiriting."),
          const SizedBox(height: 12),
          TextField(controller: pass, obscureText: true, decoration: const InputDecoration(labelText: "Parol")),
        ]),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text("Bekor qilish")),
          TextButton(onPressed: () => Navigator.pop(context, true), child: const Text("O'chirish", style: TextStyle(color: Colors.red))),
        ],
      ),
    );
    if (ok != true) return;
    try {
      final app = context.read<AppState>();
      await app.api.delete('/me', body: {'password': pass.text});
      await app.logout();
    } catch (e) {
      toast(context, errMsg(e));
    }
  }

  Future<void> _clearActivityData(BuildContext context) async {
    final ok = await confirm(
      context,
      "Faollik tarixini tozalash",
      "Barcha mashg'ulotlar seanslari, qadamlar, suv, uyqu va odatlar tarixi tozalanadi. Mashqlar katalogi va hisobingiz saqlanib qoladi. Davom etasizmi?",
      ok: "Tozalash",
    );
    if (!ok) return;
    try {
      final app = context.read<AppState>();
      await app.api.post('/admin/clear-user-data');
      if (context.mounted) {
        toast(context, "Barcha faolliklar va mashg'ulotlar tarixi tozalandi!");
      }
    } catch (e) {
      if (context.mounted) toast(context, errMsg(e));
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
        appBar: AppBar(title: const Text("Maxfiylik va xavfsizlik")),
        body: ListView(padding: const EdgeInsets.all(16), children: [
          const AppCard(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text("Qanday ma'lumotlar saqlanadi", style: TextStyle(fontWeight: FontWeight.bold)),
            SizedBox(height: 6),
            Text("Email va ism, maqsad va sozlamalar, siz kiritgan mashq, faollik, suv, uyqu, qadam, ovqat va meditatsiya qaydlari. Parol shifrlangan holda (bcrypt) saqlanadi."),
            SizedBox(height: 10),
            Text("Nimalar so'ralmaydi", style: TextStyle(fontWeight: FontWeight.bold)),
            SizedBox(height: 6),
            Text("Vazn, bo'y, yosh, kasalliklar, joylashuv (GPS) va kontaktlar. Ma'lumotlar reklama uchun sotilmaydi."),
          ])),
          ListTile(leading: const Icon(Icons.download_outlined), title: const Text("Ma'lumotlarimni eksport qilish"), onTap: () => _export(context)),
          ListTile(leading: const Icon(Icons.cleaning_services_outlined, color: Colors.orange), title: const Text("Faollik tarixini tozalash"), subtitle: const Text("Seanslar, qadam, suv, odat va uyqu qaydlarini tozalash"), onTap: () => _clearActivityData(context)),
          ListTile(leading: const Icon(Icons.delete_outline, color: Colors.red), title: const Text("Hisobni o'chirish", style: TextStyle(color: Colors.red)), onTap: () => _delete(context)),
        ]),
      );
}

class HelpScreen extends StatelessWidget {
  const HelpScreen({super.key});
  static const _faq = [
    ("Qadamlar qanday hisoblanadi?", "Ilova qadamni avtomatik sanamaydi. Bosh sahifadagi kartani bosib, telefon yoki soatingizdagi sonni kiriting."),
    ("Kaloriya qiymatlari aniqmi?", "Retseptlardagi kaloriya taxminiy. Ilova yoqilgan kaloriyani hisoblamaydi va dietolog maslahatini almashtirmaydi."),
    ("Maslahatchi sun'iy intellektmi?", "Yo'q. U sizning ma'lumotlaringiz va oddiy qoidalar asosida tavsiya beradi."),
    ("Ma'lumotlarimni qanday o'chiraman?", "Sozlamalar → Maxfiylik va xavfsizlik → Hisobni o'chirish."),
    ("Ilova shifokor o'rnini bosadimi?", "Yo'q. Og'riq, bosh aylanishi yoki nafas qisilishi sezsangiz, mashqni to'xtating va shifokorga murojaat qiling."),
    ("Telefon eslatmalari bormi?", "Hozircha yo'q, keyingi versiyada rejalashtirilgan. Ilova ichidagi maslahatlar Bildirishnomalar bo'limida."),
  ];
  @override
  Widget build(BuildContext context) => Scaffold(
        appBar: AppBar(title: const Text("Yordam va qo'llab-quvvatlash")),
        body: ListView(padding: const EdgeInsets.all(16), children: [
          for (final q in _faq)
            AppCard(padding: EdgeInsets.zero, child: ExpansionTile(shape: const Border(), title: Text(q.$1, style: const TextStyle(fontWeight: FontWeight.w600)), childrenPadding: const EdgeInsets.fromLTRB(16, 0, 16, 14), expandedAlignment: Alignment.centerLeft, children: [Text(q.$2)])),
          const SizedBox(height: 8),
          const SafetyBanner(),
        ]),
      );
}
