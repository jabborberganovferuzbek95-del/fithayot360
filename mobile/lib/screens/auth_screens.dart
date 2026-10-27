import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../api_client.dart';
import '../app_state.dart';
import '../ui.dart';

/// S01 Splash
class SplashScreen extends StatelessWidget {
  const SplashScreen({super.key, this.error});
  final String? error;
  @override
  Widget build(BuildContext context) => Scaffold(
        backgroundColor: kGreenDark,
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(32),
            child: Column(mainAxisSize: MainAxisSize.min, children: [
              const Icon(Icons.favorite, size: 72, color: kMint),
              const SizedBox(height: 12),
              Text("FitHayot 360", style: Theme.of(context).textTheme.headlineMedium?.copyWith(fontWeight: FontWeight.bold, color: Colors.white)),
              const SizedBox(height: 24),
              if (error == null)
                const CircularProgressIndicator()
              else ...[
                Text(error!, textAlign: TextAlign.center, style: const TextStyle(color: Colors.white)),
                const SizedBox(height: 16),
                OutlinedButton(onPressed: () => context.read<AppState>().init(), child: const Text("Qayta urinish")),
              ],
            ]),
          ),
        ),
      );
}

/// S02 Onboarding: 3 sahifalik premium dizayn
class OnboardingScreen extends StatefulWidget {
  const OnboardingScreen({super.key});
  @override
  State<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends State<OnboardingScreen> with TickerProviderStateMixin {
  final _c = PageController();
  int _page = 0;

  late final AnimationController _fadeCtrl = AnimationController(vsync: this, duration: const Duration(milliseconds: 800))..forward();
  late final Animation<double> _fadeAnim = CurvedAnimation(parent: _fadeCtrl, curve: Curves.easeOut);

  late final AnimationController _pulseCtrl = AnimationController(vsync: this, duration: const Duration(milliseconds: 1800))
    ..repeat(reverse: true);
  late final Animation<double> _pulseAnim = Tween<double>(begin: 0.85, end: 1.0).animate(CurvedAnimation(parent: _pulseCtrl, curve: Curves.easeInOut));

  static const _pages = [
    // Sahifa 0: Hero
    (
      icon: Icons.eco,
      title: "Sog'lom\nHayot",
      subtitle: "Sog'lom tana, baxtli hayot!\nHar kuni yaxshiroq versiyangizga yaqinlashing.",
      btn: "Boshlash  →",
    ),
    // Sahifa 1: Imkoniyatlar
    (
      icon: Icons.self_improvement,
      title: "Sog'lom hayot uchun\nbarcha imkoniyatlar\nbitta ilovada",
      subtitle: "",
      btn: "Davom etish  →",
    ),
    // Sahifa 2: Yakuniy
    (
      icon: Icons.rocket_launch,
      title: "Hoziroq\nboshlang!",
      subtitle: "Hisobingizni yarating va sog'lom hayot sari birinchi qadamni tashlang.",
      btn: "Hisob yaratish",
    ),
  ];

  static const _features = [
    (Icons.fitness_center, "Mashqlar va trenirovkalar", "Uy, zal va faol mashg'ulotlar"),
    (Icons.restaurant_menu, "Ovqatlanish va ratsion", "Kaloriya va nutrient kuzatuvi"),
    (Icons.water_drop, "Suv va suyuqlik me'yori", "Kunlik suv ichish rejasi"),
    (Icons.bedtime, "Uyqu va dam olish", "Uyqu sifatini kuzatish"),
    (Icons.self_improvement, "Meditatsiya va nafas mashqlari", "Stressni kamaytirish"),
    (Icons.checklist, "Sog'lom odatlar", "Kunlik odat kuzatuvi"),
    (Icons.bar_chart, "Statistika va tahlil", "Batafsil hisobotlar"),
    (Icons.person_pin, "Shaxsiy tavsiyalar", "AI yordamchi maslahatlar"),
  ];

  Future<void> _create() async {
    final app = context.read<AppState>();
    await app.finishOnboarding();
    if (!mounted) return;
    app.navigatorKey.currentState?.push(MaterialPageRoute(builder: (_) => const RegisterScreen()));
  }

  void _next() {
    if (_page == _pages.length - 1) {
      _create();
    } else {
      _c.nextPage(duration: const Duration(milliseconds: 400), curve: Curves.easeInOut);
    }
  }

  @override
  void dispose() {
    _fadeCtrl.dispose();
    _pulseCtrl.dispose();
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: ScreenBackground(
        imageName: 'onboarding_bg.jpg',
        forceDark: true,
        child: SafeArea(
          child: FadeTransition(
            opacity: _fadeAnim,
            child: Column(children: [
              // Skip tugmasi
              Align(
                alignment: Alignment.topRight,
                child: Padding(
                  padding: const EdgeInsets.only(right: 8, top: 4),
                  child: TextButton(
                    onPressed: context.read<AppState>().finishOnboarding,
                    child: Text(_page < _pages.length - 1 ? "O'tkazish" : "", style: const TextStyle(color: Colors.white54, fontSize: 14)),
                  ),
                ),
              ),

              // PageView
              Expanded(
                child: PageView.builder(
                  controller: _c,
                  onPageChanged: (i) => setState(() => _page = i),
                  itemCount: _pages.length,
                  itemBuilder: (context, index) {
                    if (index == 0) return _buildHeroPage(context);
                    if (index == 1) return _buildFeaturesPage(context);
                    return _buildFinalPage(context);
                  },
                ),
              ),

              // Indikatorlar
              Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                  for (var i = 0; i < _pages.length; i++)
                    AnimatedContainer(
                      duration: const Duration(milliseconds: 300),
                      curve: Curves.easeInOut,
                      margin: const EdgeInsets.symmetric(horizontal: 4),
                      width: i == _page ? 28 : 8,
                      height: 8,
                      decoration: BoxDecoration(
                        color: i == _page ? kMint : Colors.white24,
                        borderRadius: BorderRadius.circular(4),
                        boxShadow: i == _page ? [BoxShadow(color: kMint.withValues(alpha: 0.4), blurRadius: 8, spreadRadius: 1)] : null,
                      ),
                    ),
                ]),
              ),

              // Asosiy tugma
              Padding(
                padding: const EdgeInsets.fromLTRB(24, 4, 24, 4),
                child: FilledButton(
                  style: FilledButton.styleFrom(
                    backgroundColor: kMint,
                    foregroundColor: kGreenDark,
                    minimumSize: const Size.fromHeight(56),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                    textStyle: const TextStyle(fontSize: 17, fontWeight: FontWeight.w700),
                    elevation: 4,
                    shadowColor: kMint.withValues(alpha: 0.3),
                  ),
                  onPressed: _next,
                  child: Text(_pages[_page].btn),
                ),
              ),

              // Kirish link
              Padding(
                padding: const EdgeInsets.only(bottom: 12, top: 4),
                child: TextButton(
                  onPressed: context.read<AppState>().finishOnboarding,
                  child: const Text.rich(TextSpan(
                    text: "Hisobingiz bormi? ",
                    style: TextStyle(color: Colors.white54, fontSize: 14),
                    children: [TextSpan(text: "Kirish", style: TextStyle(color: kMint, fontWeight: FontWeight.bold))],
                  )),
                ),
              ),
            ]),
          ),
        ),
      ),
    );
  }

  // ── Sahifa 1: Hero ──
  Widget _buildHeroPage(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 32),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Spacer(flex: 2),
          // Logotip
          ScaleTransition(
            scale: _pulseAnim,
            child: Container(
              width: 80,
              height: 80,
              decoration: BoxDecoration(
                gradient: const LinearGradient(colors: [kMint, Color(0xFF4ADE80)]),
                borderRadius: BorderRadius.circular(24),
                boxShadow: [BoxShadow(color: kMint.withValues(alpha: 0.35), blurRadius: 20, offset: const Offset(0, 8))],
              ),
              child: const Icon(Icons.eco, color: kGreenDark, size: 44),
            ),
          ),
          const SizedBox(height: 28),
          // Sarlavha
          const Text(
            "Sog'lom",
            style: TextStyle(color: Colors.white, fontSize: 52, fontWeight: FontWeight.w900, height: 1.05, letterSpacing: -1),
          ),
          ShaderMask(
            shaderCallback: (r) => const LinearGradient(colors: [kMint, Color(0xFF4ADE80), Color(0xFF86EFAC)]).createShader(r),
            child: const Text(
              "Hayot",
              style: TextStyle(color: Colors.white, fontSize: 52, fontWeight: FontWeight.w900, height: 1.05, letterSpacing: -1),
            ),
          ),
          const SizedBox(height: 20),
          const Text(
            "Sog'lom tana, baxtli hayot!\nHar kuni yaxshiroq versiyangizga yaqinlashing.",
            style: TextStyle(color: Colors.white70, fontSize: 16, height: 1.5),
          ),
          const Spacer(flex: 3),
        ],
      ),
    );
  }

  // ── Sahifa 2: Imkoniyatlar ──
  Widget _buildFeaturesPage(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.fromLTRB(24, 20, 24, 12),
      children: [
        const Icon(Icons.self_improvement, color: kMint, size: 56),
        const SizedBox(height: 12),
        const Text(
          "Sog'lom hayot uchun\nbarcha imkoniyatlar\nbitta ilovada",
          textAlign: TextAlign.center,
          style: TextStyle(color: Colors.white, fontSize: 22, fontWeight: FontWeight.w800, height: 1.3),
        ),
        const SizedBox(height: 24),
        for (var i = 0; i < _features.length; i++)
          TweenAnimationBuilder<double>(
            tween: Tween(begin: 0.0, end: _page == 1 ? 1.0 : 0.0),
            duration: Duration(milliseconds: 400 + i * 80),
            curve: Curves.easeOut,
            builder: (context, value, child) => Opacity(
              opacity: value,
              child: Transform.translate(offset: Offset(0, 20 * (1 - value)), child: child),
            ),
            child: _featureItem(_features[i]),
          ),
        const SizedBox(height: 16),
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.06),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: Colors.white.withValues(alpha: 0.1)),
          ),
          child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Icon(Icons.info_outline, color: Colors.white.withValues(alpha: 0.5), size: 18),
            const SizedBox(width: 8),
            const Expanded(
              child: Text(
                "Ilova 18 yosh va undan kattalar uchun. U tibbiy maslahat bermaydi; sog'liq savollari uchun shifokorga murojaat qiling.",
                style: TextStyle(color: Colors.white54, fontSize: 12, height: 1.4),
              ),
            ),
          ]),
        ),
      ],
    );
  }

  Widget _featureItem((IconData, String, String) f) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.07),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
      ),
      child: Row(children: [
        Container(
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            gradient: LinearGradient(colors: [kMint.withValues(alpha: 0.25), kMint.withValues(alpha: 0.1)]),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Icon(f.$1, color: kMint, size: 22),
        ),
        const SizedBox(width: 14),
        Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(f.$2, style: const TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.w600)),
            const SizedBox(height: 2),
            Text(f.$3, style: TextStyle(color: Colors.white.withValues(alpha: 0.5), fontSize: 12)),
          ]),
        ),
        Icon(Icons.chevron_right, color: Colors.white.withValues(alpha: 0.2), size: 20),
      ]),
    );
  }

  // ── Sahifa 3: Yakuniy ──
  Widget _buildFinalPage(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 32),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Spacer(flex: 2),
          // Animatsiyali raketa
          ScaleTransition(
            scale: _pulseAnim,
            child: Container(
              width: 100,
              height: 100,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: const LinearGradient(colors: [kMint, Color(0xFF4ADE80)]),
                boxShadow: [BoxShadow(color: kMint.withValues(alpha: 0.3), blurRadius: 30, spreadRadius: 5)],
              ),
              child: const Icon(Icons.rocket_launch, color: kGreenDark, size: 48),
            ),
          ),
          const SizedBox(height: 32),
          ShaderMask(
            shaderCallback: (r) => const LinearGradient(colors: [Colors.white, kMint]).createShader(r),
            child: const Text(
              "Hoziroq\nboshlang!",
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.white, fontSize: 40, fontWeight: FontWeight.w900, height: 1.1),
            ),
          ),
          const SizedBox(height: 16),
          const Text(
            "Hisobingizni yarating va sog'lom hayot sari\nbirinchi qadamni tashlang.",
            textAlign: TextAlign.center,
            style: TextStyle(color: Colors.white60, fontSize: 15, height: 1.5),
          ),
          const Spacer(flex: 3),
          // Xavfsizlik shartlari
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.06),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
              Icon(Icons.shield_outlined, color: kMint.withValues(alpha: 0.7), size: 18),
              const SizedBox(width: 8),
              const Text("Ma'lumotlaringiz xavfsiz saqlanadi", style: TextStyle(color: Colors.white54, fontSize: 13)),
            ]),
          ),
          const SizedBox(height: 16),
        ],
      ),
    );
  }
}

String? _emailRule(String? v) {
  final s = (v ?? '').trim();
  if (!RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$').hasMatch(s)) return "To'g'ri email kiriting";
  return null;
}

String? _passRule(String? v) {
  final s = v ?? '';
  if (s.length < 8) return "Parol kamida 8 belgi bo'lsin";
  if (!s.contains(RegExp(r'[A-Za-z]')) || !s.contains(RegExp(r'[0-9]'))) return "Parolda harf va raqam bo'lsin";
  return null;
}

/// S04 Kirish
class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});
  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> with SingleTickerProviderStateMixin {
  final _form = GlobalKey<FormState>();
  final _email = TextEditingController(), _pass = TextEditingController();
  bool _busy = false, _hide = true;
  String? _error;

  late final AnimationController _anim = AnimationController(vsync: this, duration: const Duration(milliseconds: 700))..forward();
  late final Animation<double> _fade = CurvedAnimation(parent: _anim, curve: Curves.easeOut);
  late final Animation<Offset> _slide = Tween<Offset>(begin: const Offset(0, 0.08), end: Offset.zero).animate(CurvedAnimation(parent: _anim, curve: Curves.easeOut));

  @override
  void dispose() { _anim.dispose(); _email.dispose(); _pass.dispose(); super.dispose(); }

  Future<void> _submit() async {
    if (!_form.currentState!.validate()) return;
    setState(() { _busy = true; _error = null; });
    try {
      await context.read<AppState>().login(_email.text.trim(), _pass.text);
    } on ApiException catch (e) {
      if (mounted) setState(() => _error = e.message);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  InputDecoration _inputDeco(String label, IconData icon, {Widget? suffix}) => InputDecoration(
    labelText: label,
    labelStyle: const TextStyle(color: Colors.white70),
    prefixIcon: Icon(icon, color: kMint),
    suffixIcon: suffix,
    filled: true,
    fillColor: Colors.white.withValues(alpha: 0.10),
    border: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: BorderSide(color: Colors.white.withValues(alpha: 0.2))),
    enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: BorderSide(color: Colors.white.withValues(alpha: 0.2))),
    focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: const BorderSide(color: kMint, width: 2)),
    contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
  );

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Scaffold(
      body: Stack(
        children: [
          // 1. Orqa fon surati (agar rasm bo'lmasa, silliq fitnes gradienti bilan himoyalangan)
          Positioned.fill(
            child: Image.asset(
              'assets/images/welcome_bg.jpg',
              fit: BoxFit.cover,
              errorBuilder: (context, error, stackTrace) => Container(
                decoration: const BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [Color(0xFF0B2516), Color(0xFF0F3B22), Color(0xFF071B10)],
                  ),
                ),
              ),
            ),
          ),

          // 2. Yozuvlar va tugmalar juda tiniq o'qilishi uchun qoraytiruvchi zamonaviy gradient qoplama
          Positioned.fill(
            child: Container(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    const Color(0xFF0B2516).withValues(alpha: 0.70),
                    Colors.black.withValues(alpha: 0.88),
                  ],
                ),
              ),
            ),
          ),

          // 3. Asosiy shakl va elementlar
          SafeArea(
            child: Center(
              child: SingleChildScrollView(
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
                child: FadeTransition(
                  opacity: _fade,
                  child: SlideTransition(
                    position: _slide,
                    child: Form(
                      key: _form,
                      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                        // Logotip
                        Center(
                          child: Container(
                            width: 72, height: 72,
                            decoration: BoxDecoration(
                              gradient: const LinearGradient(colors: [kMint, Color(0xFF4ADE80)]),
                              borderRadius: BorderRadius.circular(22),
                              boxShadow: [BoxShadow(color: kMint.withValues(alpha: 0.25), blurRadius: 16, offset: const Offset(0, 6))],
                            ),
                            child: const Icon(Icons.eco, color: kGreenDark, size: 38),
                          ),
                        ),
                        const SizedBox(height: 20),
                        Text(
                          "Xush kelibsiz!",
                          textAlign: TextAlign.center,
                          style: Theme.of(context).textTheme.headlineMedium?.copyWith(fontWeight: FontWeight.w800, color: Colors.white),
                        ),
                        const SizedBox(height: 6),
                        const Text(
                          "Hisobingizga kiring va davom eting",
                          textAlign: TextAlign.center,
                          style: TextStyle(color: Colors.white70, fontSize: 14),
                        ),
                        const SizedBox(height: 28),

                        // Social login
                        _SocialButton(icon: Icons.g_mobiledata, label: "Google orqali kirish", onTap: () {}),
                        const SizedBox(height: 10),
                        _SocialButton(icon: Icons.apple, label: "Apple orqali kirish", onTap: () {}),
                        const SizedBox(height: 20),

                        // Divider
                        Row(children: [
                          Expanded(child: Divider(color: Colors.white.withValues(alpha: 0.2))),
                          Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 16),
                            child: Text("yoki", style: TextStyle(color: Colors.white.withValues(alpha: 0.6), fontSize: 13)),
                          ),
                          Expanded(child: Divider(color: Colors.white.withValues(alpha: 0.2))),
                        ]),
                        const SizedBox(height: 20),

                        // Email
                        TextFormField(
                          controller: _email,
                          style: const TextStyle(color: Colors.white),
                          keyboardType: TextInputType.emailAddress,
                          autofillHints: const [AutofillHints.email],
                          decoration: _inputDeco("Email", Icons.mail_outline),
                          validator: _emailRule,
                        ),
                        const SizedBox(height: 14),

                        // Parol
                        TextFormField(
                          controller: _pass,
                          style: const TextStyle(color: Colors.white),
                          obscureText: _hide,
                          autofillHints: const [AutofillHints.password],
                          decoration: _inputDeco(
                            "Parol",
                            Icons.lock_outline,
                            suffix: IconButton(
                              icon: Icon(_hide ? Icons.visibility_outlined : Icons.visibility_off_outlined, size: 22, color: Colors.white70),
                              onPressed: () => setState(() => _hide = !_hide),
                            ),
                          ),
                          validator: (v) => (v ?? '').isEmpty ? "Parolni kiriting" : null,
                          onFieldSubmitted: (_) => _submit(),
                        ),

                        // Xatolik
                        if (_error != null)
                          Padding(
                            padding: const EdgeInsets.only(top: 12),
                            child: Container(
                              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                              decoration: BoxDecoration(color: cs.error.withValues(alpha: 0.15), borderRadius: BorderRadius.circular(10)),
                              child: Row(children: [
                                Icon(Icons.error_outline, color: cs.error, size: 18),
                                const SizedBox(width: 8),
                                Expanded(child: Text(_error!, style: TextStyle(color: cs.error, fontSize: 13))),
                              ]),
                            ),
                          ),
                        const SizedBox(height: 8),

                        // Parolni unutdingizmi
                        Align(
                          alignment: Alignment.centerRight,
                          child: TextButton(
                            onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const ForgotPasswordScreen())),
                            child: const Text("Parolni unutdingizmi?", style: TextStyle(fontSize: 13, color: kMint, fontWeight: FontWeight.w600)),
                          ),
                        ),
                        const SizedBox(height: 8),

                        // Kirish tugmasi
                        FilledButton(
                          style: FilledButton.styleFrom(
                            backgroundColor: kGreen,
                            foregroundColor: Colors.white,
                            minimumSize: const Size.fromHeight(54),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                            textStyle: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
                            elevation: 2,
                          ),
                          onPressed: _busy ? null : _submit,
                          child: _busy
                              ? const SizedBox(height: 22, width: 22, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                              : const Text("Kirish"),
                        ),
                        const SizedBox(height: 16),

                        // Ro'yxatdan o'tish
                        Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                          const Text("Hisobingiz yo'qmi? ", style: TextStyle(color: Colors.white70)),
                          GestureDetector(
                            onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const RegisterScreen())),
                            child: const Text("Ro'yxatdan o'tish", style: TextStyle(color: kMint, fontWeight: FontWeight.bold)),
                          ),
                        ]),
                      ]),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Ijtimoiy tarmoq tugmasi
class _SocialButton extends StatelessWidget {
  const _SocialButton({required this.icon, required this.label, required this.onTap});
  final IconData icon;
  final String label;
  final VoidCallback onTap;
  @override
  Widget build(BuildContext context) => OutlinedButton.icon(
    style: OutlinedButton.styleFrom(
      minimumSize: const Size.fromHeight(52),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      side: BorderSide(color: Colors.white.withValues(alpha: 0.2)),
      foregroundColor: Colors.white,
      backgroundColor: Colors.white.withValues(alpha: 0.08),
    ),
    onPressed: onTap,
    icon: Icon(icon, size: 24, color: Colors.white),
    label: Text(label, style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600)),
  );
}

/// S03 Ro'yxatdan o'tish (18+ va rozilik majburiy — FR-01)
class RegisterScreen extends StatefulWidget {
  const RegisterScreen({super.key});
  @override
  State<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends State<RegisterScreen> with SingleTickerProviderStateMixin {
  final _form = GlobalKey<FormState>();
  final _name = TextEditingController(), _email = TextEditingController(), _pass = TextEditingController(), _pass2 = TextEditingController();
  bool _adult = false, _terms = false, _busy = false, _hidePass = true, _hidePass2 = true;
  String? _error;

  late final AnimationController _anim = AnimationController(vsync: this, duration: const Duration(milliseconds: 700))..forward();
  late final Animation<double> _fade = CurvedAnimation(parent: _anim, curve: Curves.easeOut);

  @override
  void dispose() { _anim.dispose(); _name.dispose(); _email.dispose(); _pass.dispose(); _pass2.dispose(); super.dispose(); }

  Future<void> _submit() async {
    if (!_form.currentState!.validate()) return;
    if (!_adult) return setState(() => _error = "Davom etish uchun 18 yosh va undan katta ekaningizni tasdiqlang");
    if (!_terms) return setState(() => _error = "Foydalanish shartlari va maxfiylik siyosatiga rozilik bering");
    setState(() { _busy = true; _error = null; });
    try {
      await context.read<AppState>().register(_email.text.trim(), _pass.text, fullName: _name.text);
    } on ApiException catch (e) {
      if (mounted) setState(() => _error = e.message);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  InputDecoration _inputDeco(String label, IconData icon, {Widget? suffix, String? helper}) => InputDecoration(
    labelText: label,
    helperText: helper,
    prefixIcon: Icon(icon),
    suffixIcon: suffix,
    filled: true,
    fillColor: Theme.of(context).brightness == Brightness.dark
        ? Colors.white.withValues(alpha: 0.06)
        : Colors.grey.shade50,
    border: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: BorderSide(color: Colors.grey.shade300)),
    enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: BorderSide(color: Colors.grey.shade300)),
    focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: const BorderSide(color: kGreen, width: 2)),
    contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
  );

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Scaffold(
      appBar: AppBar(
        title: const Text("Ro'yxatdan o'tish"),
        centerTitle: true,
        elevation: 0,
        backgroundColor: Colors.transparent,
      ),
      body: ScreenBackground(
        imageName: 'register_bg.jpg',
        child: SafeArea(
          child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 8),
          child: FadeTransition(
            opacity: _fade,
            child: Form(
              key: _form,
              child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                // Sarlavha
                Text("Hisob yaratish", style: Theme.of(context).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.w800)),
                const SizedBox(height: 4),
                const Text("Sog'lom hayotingiz shu yerdan boshlanadi!", style: TextStyle(color: Colors.grey, fontSize: 14)),
                const SizedBox(height: 24),

                // Social login
                _SocialButton(icon: Icons.g_mobiledata, label: "Google orqali davom etish", onTap: () {}),
                const SizedBox(height: 10),
                _SocialButton(icon: Icons.apple, label: "Apple orqali davom etish", onTap: () {}),
                const SizedBox(height: 20),

                // Divider
                Row(children: [
                  Expanded(child: Divider(color: Colors.grey.shade300)),
                  Padding(padding: const EdgeInsets.symmetric(horizontal: 16), child: Text("yoki", style: TextStyle(color: Colors.grey.shade500, fontSize: 13))),
                  Expanded(child: Divider(color: Colors.grey.shade300)),
                ]),
                const SizedBox(height: 20),

                // Form fieldlar
                TextFormField(
                  controller: _name,
                  textCapitalization: TextCapitalization.words,
                  decoration: _inputDeco("Ism va familiya", Icons.person_outline),
                  validator: (v) => (v ?? '').trim().length < 2 ? "Ismingizni kiriting" : null,
                ),
                const SizedBox(height: 14),
                TextFormField(
                  controller: _email,
                  keyboardType: TextInputType.emailAddress,
                  decoration: _inputDeco("Email", Icons.mail_outline),
                  validator: _emailRule,
                ),
                const SizedBox(height: 14),
                TextFormField(
                  controller: _pass,
                  obscureText: _hidePass,
                  decoration: _inputDeco("Parol", Icons.lock_outline,
                    helper: "Kamida 8 belgi, harf va raqam",
                    suffix: IconButton(
                      icon: Icon(_hidePass ? Icons.visibility_outlined : Icons.visibility_off_outlined, size: 22),
                      onPressed: () => setState(() => _hidePass = !_hidePass),
                    ),
                  ),
                  validator: _passRule,
                ),
                const SizedBox(height: 14),
                TextFormField(
                  controller: _pass2,
                  obscureText: _hidePass2,
                  decoration: _inputDeco("Parolni takrorlang", Icons.lock_outline,
                    suffix: IconButton(
                      icon: Icon(_hidePass2 ? Icons.visibility_outlined : Icons.visibility_off_outlined, size: 22),
                      onPressed: () => setState(() => _hidePass2 = !_hidePass2),
                    ),
                  ),
                  validator: (v) => v != _pass.text ? "Parollar mos kelmadi" : null,
                ),
                const SizedBox(height: 16),

                // Checkboxlar
                _CheckTile(
                  value: _adult,
                  onChanged: (v) => setState(() => _adult = v ?? false),
                  icon: Icons.verified_user_outlined,
                  text: "Men 18 yosh va undan kattaman",
                ),
                const SizedBox(height: 8),
                _CheckTile(
                  value: _terms,
                  onChanged: (v) => setState(() => _terms = v ?? false),
                  icon: Icons.description_outlined,
                  text: "Foydalanish shartlari va maxfiylik siyosatiga roziman. Faqat zarur ma'lumotlar yig'iladi; ularni istalgan vaqtda eksport qilish yoki o'chirish mumkin.",
                ),

                // Xatolik
                if (_error != null)
                  Padding(
                    padding: const EdgeInsets.only(top: 12),
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                      decoration: BoxDecoration(color: cs.error.withValues(alpha: 0.08), borderRadius: BorderRadius.circular(10)),
                      child: Row(children: [
                        Icon(Icons.error_outline, color: cs.error, size: 18),
                        const SizedBox(width: 8),
                        Expanded(child: Text(_error!, style: TextStyle(color: cs.error, fontSize: 13))),
                      ]),
                    ),
                  ),
                const SizedBox(height: 20),

                // Hisob ochish
                FilledButton(
                  style: FilledButton.styleFrom(
                    backgroundColor: kGreen,
                    foregroundColor: Colors.white,
                    minimumSize: const Size.fromHeight(54),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                    textStyle: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
                    elevation: 2,
                  ),
                  onPressed: _busy ? null : _submit,
                  child: _busy
                      ? const SizedBox(height: 22, width: 22, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                      : const Text("Hisob ochish"),
                ),
                const SizedBox(height: 16),

                // Kirish link
                Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                  const Text("Hisobingiz bormi? ", style: TextStyle(color: Colors.grey)),
                  GestureDetector(
                    onTap: () => Navigator.pop(context),
                    child: const Text("Kirish", style: TextStyle(color: kGreen, fontWeight: FontWeight.bold)),
                  ),
                ]),
                const SizedBox(height: 20),
              ]),
            ),
          ),
        ),
      ),
    ),
  );
  }
}

/// Stilizatsiyalangan checkbox tile
class _CheckTile extends StatelessWidget {
  const _CheckTile({required this.value, required this.onChanged, required this.icon, required this.text});
  final bool value;
  final ValueChanged<bool?> onChanged;
  final IconData icon;
  final String text;
  @override
  Widget build(BuildContext context) => InkWell(
    borderRadius: BorderRadius.circular(12),
    onTap: () => onChanged(!value),
    child: Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: value ? kGreen.withValues(alpha: 0.06) : Colors.transparent,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: value ? kGreen.withValues(alpha: 0.3) : Colors.grey.shade300),
      ),
      child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
        SizedBox(
          width: 24, height: 24,
          child: Checkbox(
            value: value,
            onChanged: onChanged,
            activeColor: kGreen,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
            materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
            visualDensity: VisualDensity.compact,
          ),
        ),
        const SizedBox(width: 10),
        Icon(icon, size: 18, color: value ? kGreen : Colors.grey),
        const SizedBox(width: 8),
        Expanded(child: Text(text, style: TextStyle(fontSize: 13, color: value ? kGreen : Colors.grey.shade700))),
      ]),
    ),
  );
}

/// S04 Parolni tiklash
class ForgotPasswordScreen extends StatefulWidget {
  const ForgotPasswordScreen({super.key});
  @override
  State<ForgotPasswordScreen> createState() => _ForgotPasswordScreenState();
}

class _ForgotPasswordScreenState extends State<ForgotPasswordScreen> {
  final _email = TextEditingController(), _token = TextEditingController(), _pass = TextEditingController();
  bool _sent = false, _busy = false;
  String? _info, _error;

  Future<void> _run(Future<void> Function() f) async {
    setState(() { _busy = true; _error = null; });
    try {
      await f();
    } on ApiException catch (e) {
      if (mounted) setState(() => _error = e.message);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _send() => _run(() async {
        if (_emailRule(_email.text) != null) throw ApiException(422, "To'g'ri email kiriting");
        final api = context.read<AppState>().api;
        final j = await api.post('/auth/forgot-password', body: {'email': _email.text.trim()}, auth: false);
        setState(() {
          _sent = true;
          _info = j['message'];
          if (j['reset_token'] != null) _token.text = j['reset_token']; // faqat development rejimida
        });
      });

  Future<void> _reset() => _run(() async {
        final rule = _passRule(_pass.text);
        if (rule != null) throw ApiException(422, rule);
        await context.read<AppState>().api.post('/auth/reset-password', body: {'token': _token.text.trim(), 'new_password': _pass.text}, auth: false);
        if (!mounted) return;
        toast(context, "Parol yangilandi. Endi kiring.");
        Navigator.pop(context);
      });

  @override
  Widget build(BuildContext context) => Scaffold(
        appBar: AppBar(title: const Text("Parolni tiklash")),
        body: ScreenBackground(
          imageName: 'welcome_bg.jpg',
          child: SafeArea(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(24),
              child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                TextField(controller: _email, enabled: !_sent, keyboardType: TextInputType.emailAddress, decoration: const InputDecoration(labelText: "Email")),
                const SizedBox(height: 12),
                if (!_sent) FilledButton(onPressed: _busy ? null : _send, child: const Text("Tiklash kodini yuborish")),
                if (_sent) ...[
                  if (_info != null) Padding(padding: const EdgeInsets.only(bottom: 12), child: Text(_info!)),
                  TextField(controller: _token, decoration: const InputDecoration(labelText: "Tiklash kodi (emaildan)")),
                  const SizedBox(height: 12),
                  TextField(controller: _pass, obscureText: true, decoration: const InputDecoration(labelText: "Yangi parol")),
                  const SizedBox(height: 12),
                  FilledButton(onPressed: _busy ? null : _reset, child: const Text("Parolni yangilash")),
                ],
                if (_error != null) Padding(padding: const EdgeInsets.only(top: 12), child: Text(_error!, style: TextStyle(color: Theme.of(context).colorScheme.error))),
              ]),
            ),
          ),
        ),
      );
}
