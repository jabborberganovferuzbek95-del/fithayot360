import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../api_client.dart';
import '../app_state.dart';
import '../ui.dart';

ApiClient _api(BuildContext c) => c.read<AppState>().api;

class _NutData {
  _NutData(this.recipes, this.meals, this.goal);
  final List<Map<String, dynamic>> recipes, meals;
  final int goal;
}

/// Ovqatlanish bo'limi: retseptlar + bugungi ovqat qaydi
class NutritionScreen extends StatefulWidget {
  const NutritionScreen({super.key});
  @override
  State<NutritionScreen> createState() => _NutritionScreenState();
}

class _NutritionScreenState extends State<NutritionScreen> {
  int _epoch = 0;
  String? _type;

  Future<_NutData> _load() async {
    final api = _api(context);
    final r = await Future.wait([
      api.getList('/recipes', query: {'limit': 100}),
      api.getList('/meals'),
      api.getMap('/goals'),
    ]);
    return _NutData(
      r[0] as List<Map<String, dynamic>>,
      r[1] as List<Map<String, dynamic>>,
      (r[2] as Map<String, dynamic>)['calorie_goal'] as int,
    );
  }

  Future<void> _delete(int id) async {
    try {
      await _api(context).delete('/meals/$id');
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
      appBar: AppBar(
        title: const Text(
          "Ovqatlanish",
          style: TextStyle(fontWeight: FontWeight.w800, fontSize: 20),
        ),
        elevation: 0,
        backgroundColor: isDark ? const Color(0xFF141C17) : Colors.white,
      ),
      floatingActionButton: FloatingActionButton.extended(
        backgroundColor: kGreen,
        foregroundColor: Colors.white,
        elevation: 4,
        icon: const Icon(Icons.add_rounded, size: 22),
        label: const Text("Ovqat qo'shish", style: TextStyle(fontWeight: FontWeight.bold)),
        onPressed: () async {
          if (await addCustomMeal(context)) setState(() => _epoch++);
        },
      ),
      body: Loader<_NutData>(
        key: ValueKey(_epoch),
        load: _load,
        builder: (context, d, reload) {
          final eaten = d.meals.fold<int>(0, (a, m) => a + (m['kcal'] as int));
          final list = d.recipes.where((r) => _type == null || r['meal_type'] == _type).toList();
          final progress = d.goal > 0 ? (eaten / d.goal).clamp(0.0, 1.0).toDouble() : 0.0;
          final remaining = d.goal - eaten;

          return RefreshIndicator(
            onRefresh: reload,
            color: kGreen,
            child: ListView(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 95),
              children: [
                // Kaloriya Hero Kartasi
                Container(
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(24),
                    gradient: const LinearGradient(
                      colors: [Color(0xFF16803C), Color(0xFF0B4623)],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: kGreen.withAlpha(65),
                        blurRadius: 16,
                        offset: const Offset(0, 5),
                      ),
                    ],
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Text(
                            "Bugungi kaloriya balansi",
                            style: TextStyle(color: Colors.white70, fontSize: 13, fontWeight: FontWeight.w500),
                          ),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                            decoration: BoxDecoration(
                              color: Colors.white.withAlpha(35),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Text(
                              remaining >= 0 ? "Qoldi: ${fmtInt(remaining)} kkal" : "Me'yordan oshdi",
                              style: const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.w700),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 10),
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.baseline,
                        textBaseline: TextBaseline.alphabetic,
                        children: [
                          Text(
                            fmtInt(eaten),
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 34,
                              fontWeight: FontWeight.w800,
                              letterSpacing: -0.5,
                            ),
                          ),
                          const SizedBox(width: 8),
                          Text(
                            "/ ${fmtInt(d.goal)} kkal",
                            style: TextStyle(
                              color: Colors.white.withAlpha(190),
                              fontSize: 16,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 14),
                      ClipRRect(
                        borderRadius: BorderRadius.circular(6),
                        child: LinearProgressIndicator(
                          value: progress,
                          backgroundColor: Colors.white.withAlpha(40),
                          color: remaining >= 0 ? kMint : Colors.orangeAccent,
                          minHeight: 8,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'Belgilangan kunlik me\'yor: ${fmtInt(d.goal)} kkal',
                        style: TextStyle(color: Colors.white.withAlpha(180), fontSize: 12),
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 20),

                // Bugungi kiritilgan ovqatlar
                if (d.meals.isNotEmpty) ...[
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text(
                        "Bugungi ovqatlar",
                        style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
                      ),
                      Text(
                        "${d.meals.length} ta qayd",
                        style: TextStyle(fontSize: 12, color: isDark ? Colors.grey.shade400 : Colors.grey.shade600),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  for (final m in d.meals)
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
                          Container(
                            padding: const EdgeInsets.all(8),
                            decoration: BoxDecoration(
                              color: mealColor(m['meal_type'] as String).withAlpha(isDark ? 40 : 25),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Icon(
                              mealIcon(m['meal_type'] as String),
                              color: mealColor(m['meal_type'] as String),
                              size: 20,
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  m['title'] as String,
                                  style: TextStyle(
                                    fontWeight: FontWeight.w700,
                                    fontSize: 14,
                                    color: isDark ? Colors.white : Colors.black87,
                                  ),
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  mealTypeLabels[m['meal_type']] ?? '',
                                  style: TextStyle(
                                    fontSize: 11.5,
                                    color: isDark ? Colors.grey.shade400 : Colors.grey.shade600,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                            decoration: BoxDecoration(
                              color: isDark ? Colors.white10 : Colors.black.withAlpha(8),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Text(
                              '${m['kcal']} kkal',
                              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                            ),
                          ),
                          const SizedBox(width: 4),
                          IconButton(
                            icon: const Icon(Icons.delete_outline_rounded, size: 20, color: Colors.redAccent),
                            onPressed: () => _delete(m['id'] as int),
                          ),
                        ],
                      ),
                    ),
                  const SizedBox(height: 14),
                ],

                // Retseptlar bo'limi
                const Text(
                  "Foydali retseptlar",
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
                ),
                const SizedBox(height: 10),

                // Retsept filtrlari
                SizedBox(
                  height: 42,
                  child: ListView(
                    scrollDirection: Axis.horizontal,
                    children: [
                      Padding(
                        padding: const EdgeInsets.only(right: 6),
                        child: FilterChip(
                          label: const Text("Hammasi"),
                          selected: _type == null,
                          onSelected: (_) => setState(() => _type = null),
                          selectedColor: kGreen.withAlpha(isDark ? 50 : 35),
                          checkmarkColor: kGreen,
                          labelStyle: TextStyle(
                            fontSize: 12,
                            fontWeight: _type == null ? FontWeight.bold : FontWeight.normal,
                            color: _type == null ? kGreen : null,
                          ),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        ),
                      ),
                      for (final e in mealTypeLabels.entries)
                        Padding(
                          padding: const EdgeInsets.only(right: 6),
                          child: FilterChip(
                            label: Text(e.value),
                            selected: _type == e.key,
                            onSelected: (_) => setState(() => _type = e.key),
                            selectedColor: mealColor(e.key).withAlpha(isDark ? 50 : 35),
                            checkmarkColor: mealColor(e.key),
                            labelStyle: TextStyle(
                              fontSize: 12,
                              fontWeight: _type == e.key ? FontWeight.bold : FontWeight.normal,
                              color: _type == e.key ? mealColor(e.key) : null,
                            ),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                          ),
                        ),
                    ],
                  ),
                ),

                const SizedBox(height: 10),

                if (list.isEmpty)
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 40),
                    child: Center(
                      child: Text(
                        "Bu toifada retsept mavjud emas",
                        style: TextStyle(color: isDark ? Colors.grey.shade400 : Colors.grey.shade600),
                      ),
                    ),
                  )
                else
                  for (final r in list) ...[
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
                          onTap: () async {
                            final added = await Navigator.push<bool>(
                              context,
                              MaterialPageRoute(builder: (_) => RecipeDetailScreen(recipe: r)),
                            );
                            if (added == true) setState(() => _epoch++);
                          },
                          child: Padding(
                            padding: const EdgeInsets.all(12),
                            child: Row(
                              children: [
                                Container(
                                  width: 54,
                                  height: 54,
                                  decoration: BoxDecoration(
                                    color: mealColor(r['meal_type'] as String).withAlpha(isDark ? 40 : 25),
                                    borderRadius: BorderRadius.circular(14),
                                  ),
                                  child: Icon(
                                    mealIcon(r['meal_type'] as String),
                                    color: mealColor(r['meal_type'] as String),
                                    size: 26,
                                  ),
                                ),
                                const SizedBox(width: 14),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        r['title'] as String,
                                        style: TextStyle(
                                          fontWeight: FontWeight.w700,
                                          fontSize: 14.5,
                                          color: isDark ? Colors.white : Colors.black87,
                                        ),
                                      ),
                                      const SizedBox(height: 4),
                                      Row(
                                        children: [
                                          Container(
                                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                            decoration: BoxDecoration(
                                              color: mealColor(r['meal_type'] as String).withAlpha(isDark ? 35 : 20),
                                              borderRadius: BorderRadius.circular(6),
                                            ),
                                            child: Text(
                                              mealTypeLabels[r['meal_type']] ?? '',
                                              style: TextStyle(
                                                fontSize: 11,
                                                fontWeight: FontWeight.w600,
                                                color: mealColor(r['meal_type'] as String),
                                              ),
                                            ),
                                          ),
                                          const SizedBox(width: 8),
                                          Text(
                                            '${r['kcal']} kkal · ${r['prep_minutes']} daq',
                                            style: TextStyle(
                                              fontSize: 12,
                                              color: isDark ? Colors.grey.shade400 : Colors.grey.shade600,
                                            ),
                                          ),
                                        ],
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
                    ),
                  ],

                const SizedBox(height: 12),
                Text(
                  "Kaloriya qiymatlari taxminiy hisoblangan. Ilova dietolog maslahatini almashtirmaydi.",
                  style: TextStyle(fontSize: 11.5, color: isDark ? Colors.grey.shade500 : Colors.grey.shade500),
                  textAlign: TextAlign.center,
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}

/// Retsept tafsiloti + bugungi ovqatga qo'shish
class RecipeDetailScreen extends StatelessWidget {
  const RecipeDetailScreen({super.key, required this.recipe});
  final Map<String, dynamic> recipe;

  Future<void> _add(BuildContext context) async {
    var type = recipe['meal_type'] == 'detox' ? 'snack' : recipe['meal_type'] as String;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    final chosen = await showModalBottomSheet<String>(
      context: context,
      backgroundColor: isDark ? const Color(0xFF161F1A) : Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setS) => Padding(
          padding: const EdgeInsets.all(22),
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
              const Text(
                "Qaysi mahal uchun qo'shasiz?",
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 16),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  for (final e in mealTypeLabels.entries.where((e) => e.key != 'detox'))
                    ChoiceChip(
                      label: Text(e.value),
                      selected: type == e.key,
                      onSelected: (_) => setS(() => type = e.key),
                      selectedColor: kGreen.withAlpha(isDark ? 50 : 35),
                      checkmarkColor: kGreen,
                      labelStyle: TextStyle(
                        fontWeight: type == e.key ? FontWeight.bold : FontWeight.normal,
                        color: type == e.key ? kGreen : null,
                      ),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                ],
              ),
              const SizedBox(height: 22),
              FilledButton(
                onPressed: () => Navigator.pop(ctx, type),
                style: FilledButton.styleFrom(
                  backgroundColor: kGreen,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                  minimumSize: const Size.fromHeight(50),
                ),
                child: const Text("Ovqatlar ro'yxatiga qo'shish", style: TextStyle(fontWeight: FontWeight.bold)),
              ),
            ],
          ),
        ),
      ),
    );

    if (chosen == null) return;
    try {
      await _api(context).post('/meals', body: {'recipe_id': recipe['id'], 'meal_type': chosen});
      if (context.mounted) {
        toast(context, "Bugungi ovqatlar ro'yxatiga qo'shildi");
        Navigator.pop(context, true);
      }
    } on ApiException catch (e) {
      if (context.mounted) toast(context, e.message);
    }
  }

  @override
  Widget build(BuildContext context) {
    final t = recipe['meal_type'] as String;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final ingredients = (recipe['ingredients'] as String).split('\n').where((s) => s.trim().isNotEmpty).toList();

    return Scaffold(
      backgroundColor: isDark ? const Color(0xFF0F1512) : const Color(0xFFF7FAF8),
      appBar: AppBar(
        title: Text(recipe['title'] as String),
        elevation: 0,
        backgroundColor: Colors.transparent,
      ),
      body: ListView(
        padding: const EdgeInsets.all(18),
        children: [
          // Banner
          Container(
            height: 140,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(22),
              gradient: LinearGradient(
                colors: [mealColor(t).withAlpha(180), mealColor(t)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              boxShadow: [
                BoxShadow(
                  color: mealColor(t).withAlpha(75),
                  blurRadius: 16,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: Center(
              child: Icon(mealIcon(t), color: Colors.white, size: 64),
            ),
          ),
          const SizedBox(height: 16),

          // Chips
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                decoration: BoxDecoration(
                  color: Colors.orange.withAlpha(isDark ? 35 : 20),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.local_fire_department_rounded, size: 16, color: Colors.orange),
                    const SizedBox(width: 4),
                    Text(
                      '${recipe['kcal']} kkal',
                      style: const TextStyle(color: Colors.orange, fontWeight: FontWeight.bold, fontSize: 12),
                    ),
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                decoration: BoxDecoration(
                  color: Colors.blue.withAlpha(isDark ? 35 : 20),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.timer_outlined, size: 16, color: Colors.blue),
                    const SizedBox(width: 4),
                    Text(
                      '${recipe['prep_minutes']} daqiqa',
                      style: const TextStyle(color: Colors.blue, fontWeight: FontWeight.bold, fontSize: 12),
                    ),
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                decoration: BoxDecoration(
                  color: mealColor(t).withAlpha(isDark ? 35 : 20),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Text(
                  mealTypeLabels[t] ?? '',
                  style: TextStyle(color: mealColor(t), fontWeight: FontWeight.bold, fontSize: 12),
                ),
              ),
            ],
          ),

          const SizedBox(height: 20),

          // Masalliqlar
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
                        color: Colors.green.withAlpha(isDark ? 40 : 25),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: const Icon(Icons.eco_rounded, color: Colors.green, size: 18),
                    ),
                    const SizedBox(width: 10),
                    const Text(
                      "Masalliqlar",
                      style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                for (final i in ingredients)
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 4),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text('🌱  ', style: TextStyle(fontSize: 12)),
                        Expanded(
                          child: Text(
                            i,
                            style: TextStyle(
                              fontSize: 13.5,
                              color: isDark ? Colors.grey.shade300 : Colors.grey.shade800,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
              ],
            ),
          ),

          const SizedBox(height: 16),

          // Tayyorlash usuli
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
                        color: Colors.orange.withAlpha(isDark ? 40 : 25),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: const Icon(Icons.restaurant_rounded, color: Colors.orange, size: 18),
                    ),
                    const SizedBox(width: 10),
                    const Text(
                      "Tayyorlash tartibi",
                      style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Text(
                  recipe['instructions'] as String,
                  style: TextStyle(
                    fontSize: 14,
                    height: 1.5,
                    color: isDark ? Colors.grey.shade300 : Colors.grey.shade800,
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(height: 24),

          FilledButton.icon(
            onPressed: () => _add(context),
            icon: const Icon(Icons.add_rounded),
            label: const Text(
              "Bugungi ovqatga qo'shish",
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

/// Retseptsiz o'z ovqatini qo'shish
Future<bool> addCustomMeal(BuildContext context) async {
  final title = TextEditingController();
  final kcal = TextEditingController();
  var type = 'lunch';
  final isDark = Theme.of(context).brightness == Brightness.dark;

  final ok = await showDialog<bool>(
    context: context,
    builder: (ctx) => StatefulBuilder(
      builder: (ctx, setS) => AlertDialog(
        backgroundColor: isDark ? const Color(0xFF161F1A) : Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(22)),
        title: const Text("Ovqat qo'shish", style: TextStyle(fontWeight: FontWeight.bold)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: title,
              decoration: InputDecoration(
                labelText: "Ovqat nomi",
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(14)),
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: kcal,
              keyboardType: TextInputType.number,
              decoration: InputDecoration(
                labelText: "Kaloriya miqdori (kkal)",
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(14)),
              ),
            ),
            const SizedBox(height: 12),
            DropdownButtonFormField<String>(
              initialValue: type,
              isExpanded: true,
              decoration: InputDecoration(
                labelText: "Qaysi mahal?",
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(14)),
              ),
              items: [
                for (final e in mealTypeLabels.entries.where((e) => e.key != 'detox'))
                  DropdownMenuItem(value: e.key, child: Text(e.value)),
              ],
              onChanged: (v) => setS(() => type = v ?? type),
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
              minimumSize: const Size(90, 42),
            ),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text("Qo'shish", style: TextStyle(fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    ),
  );

  if (ok != true) return false;
  final k = int.tryParse(kcal.text.trim());
  if (title.text.trim().isEmpty || k == null || k < 0 || k > 5000) {
    if (context.mounted) toast(context, "Nom va kaloriya (0–5000) to'g'ri kiritilsin");
    return false;
  }
  try {
    await _api(context).post('/meals', body: {'title': title.text.trim(), 'kcal': k, 'meal_type': type});
    return true;
  } on ApiException catch (e) {
    if (context.mounted) toast(context, e.message);
    return false;
  }
}
