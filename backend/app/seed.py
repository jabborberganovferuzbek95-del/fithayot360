"""Boshlang'ich ma'lumotlar. DEMO kontent: ishlatishdan oldin malakali fitness mutaxassisi ko'rib chiqishi shart (NFR-12).

Ishga tushirish:  python -m app.seed [--demo]
"""
import sys
from datetime import timedelta

from sqlalchemy import select
from sqlalchemy.orm import Session

from .config import settings
from .database import Base, SessionLocal, engine
from .models import (ActivityLog, ActivityType, Exercise, ExerciseCategory, ExerciseLog, FitnessProfile, MeditationItem,
                     PlanItem, Program, ProgramItem, Recipe, User, UserSettings, WorkoutPlan, WorkoutSession, utcnow)
from .migrate import ensure_columns
from .security import hash_password

CATEGORIES = [
    ("home_strength", "Uy: kuch (tana vazni bilan)", "home"),
    ("home_cardio", "Uy: kardio", "home"),
    ("home_mobility", "Uy: cho'zilish va harakatchanlik", "home"),
    ("gym_strength", "Zal: kuch mashqlari", "gym"),
    ("gym_cardio", "Zal: kardio trenajyorlar", "gym"),
]

COMMON = "Og'riq, bosh aylanishi yoki nafas qisilishi sezsangiz, mashqni darhol to'xtating."
NOTE_BODY = f"Harakatni sekin va nazorat bilan bajaring, nafasni ushlab turmang. {COMMON}"
NOTE_WEIGHT = f"Yengil vazndan boshlang, texnikani ishonchli o'zlashtirgach vaznni asta oshiring; zalda trener ko'rsatmasidan foydalaning. {COMMON}"
NOTE_CARDIO = f"Past tezlikdan boshlang, suhbatlasha oladigan tezlikni saqlang. {COMMON}"
NOTE_STRETCH = f"Cho'zilishni og'riqsiz, yengil taranglik darajasida bajaring, sakramang. {COMMON}"

# (kategoriya, nom, tavsif, jihoz, daraja, davomiylik, ogohlantirish)
EXERCISES = [
    ("home_strength", "Devordan turtinish", "Devorga yuz tutib turing, kaftlarni yelka kengligida devorga qo'ying. Tanani to'g'ri chiziqda ushlagan holda devorga yaqinlashing va qaytib turtining.", "none", "beginner", "2–3 yondashuv × 10–15 takror", NOTE_BODY),
    ("home_strength", "Tizza ustida turtib ko'tarilish", "Tizzalar va kaftlarga tayanib, tanani boshdan tizzagacha to'g'ri chiziqda ushlang. Ko'krakni polga yaqinlashtiring va qaytib ko'taring.", "mat", "beginner", "2–3 yondashuv × 8–12 takror", NOTE_BODY),
    ("home_strength", "Turtib ko'tarilish", "Kaftlar yelkadan sal keng, tana boshdan tovongacha to'g'ri chiziqda. Tirsaklarni bukib ko'krakni polga yaqinlashtiring va qaytib ko'taring.", "mat", "intermediate", "2–4 yondashuv × 6–15 takror", NOTE_BODY),
    ("home_strength", "Tana vazni bilan cho'kkalash", "Oyoqlar yelka kengligida. Dumbani orqaga tortgan holda sekin cho'kkalang, tizzalar oyoq uchlari yo'nalishida bo'lsin, so'ng turing.", "none", "beginner", "2–3 yondashuv × 10–15 takror", NOTE_BODY),
    ("home_strength", "Stuldan turish va o'tirish", "Barqaror stul oldida turing. Qo'llarni ko'krakda kesishtirib sekin o'tiring va tayanchsiz yoki yengil tayanch bilan turing.", "chair", "beginner", "2–3 yondashuv × 8–12 takror", NOTE_BODY),
    ("home_strength", "Orqaga qadam bilan lanj", "To'g'ri turib, bir oyoq bilan orqaga qadam tashlang va ikkala tizzani nazorat bilan bukib tushing. Boshlang'ich holatga qayting, oyoqni almashtiring.", "none", "intermediate", "2–3 yondashuv × 8–10 takror (har oyoq)", NOTE_BODY),
    ("home_strength", "Plank (tirsakda tayanish)", "Tirsak va oyoq uchlariga tayanib, tanani boshdan tovongacha to'g'ri ushlang. Qorin mushaklarini taranglang, nafas oling.", "mat", "intermediate", "3 yondashuv × 15–40 soniya", NOTE_BODY),
    ("home_strength", "Dumba ko'prigi", "Chalqancha yotib tizzalarni bukib, tovonlarni polga qo'ying. Dumbani tananing to'g'ri chizig'igacha ko'taring va sekin tushiring.", "mat", "beginner", "2–3 yondashuv × 10–15 takror", NOTE_BODY),
    ("home_strength", "Bird-dog (qo'l-oyoq almashtirish)", "To'rt oyoqlab turib, qarama-qarshi qo'l va oyoqni sekin uzating, bel egilmasligiga e'tibor bering, so'ng almashtiring.", "mat", "beginner", "2–3 yondashuv × 8–10 takror", NOTE_BODY),
    ("home_cardio", "Joyida yurish", "Joyingizda yurib, qo'llarni tabiiy harakatlantiring. Tizzani qulay balandlikka ko'taring.", "none", "beginner", "5–15 daqiqa", NOTE_CARDIO),
    ("home_cardio", "Joyida tizzani baland ko'tarish", "Joyida yengil yugurgandek tizzalarni belgacha ko'tarib, qo'llar bilan ritm bering.", "none", "intermediate", "30–60 soniya × 3–5 marta", NOTE_CARDIO),
    ("home_cardio", "Qo'l-oyoq ochib sakrash", "Oyoqlarni yelkadan keng ochib, qo'llarni tepaga ko'tarib sakrang va boshlang'ich holatga qayting. Yumshoq tushing.", "none", "intermediate", "30–45 soniya × 3–4 marta", NOTE_CARDIO),
    ("home_mobility", "Mushuk–sigir", "To'rt oyoqlab turib, nafas chiqarib belni yumaloqlang, nafas olib belni yengil egib bosh va dumbani ko'taring. Sekin almashtiring.", "mat", "beginner", "8–10 takror", NOTE_STRETCH),
    ("home_mobility", "Boldir mushaklarini cho'zish", "Devorga tayanib, bir oyoqni orqaga qo'ying va tovonni polga bosing. Boldirda yengil taranglik sezing.", "none", "beginner", "20–30 soniya (har oyoq)", NOTE_STRETCH),
    ("home_mobility", "Yelka aylantirish", "Tik turib yelkalarni sekin oldinga, yuqoriga va orqaga aylantiring, bo'yinni bo'sh tuting.", "none", "beginner", "10 takror (har yo'nalish)", NOTE_STRETCH),
    ("gym_strength", "Shtanga bilan cho'kkalash", "Shtangani yelka orqasida mustahkam ushlab, oyoqlar yelka kengligida cho'kkalang va turing. Orqa to'g'ri turishi shart.", "barbell", "advanced", "3–5 yondashuv × 5–8 takror", NOTE_WEIGHT),
    ("gym_strength", "Skameykada gantel press", "Skameykaga yotib, gantellarni ko'krak darajasidan tepaga siqib chiqaring va nazorat bilan tushiring.", "dumbbell", "intermediate", "3–4 yondashuv × 8–12 takror", NOTE_WEIGHT),
    ("gym_strength", "Yuqori blokni tortish", "Trenajyorda o'tirib, dastani ko'krak tomon tortib, kurak suyaklarini yaqinlashtiring va sekin qaytaring.", "cable machine", "beginner", "3 yondashuv × 10–12 takror", NOTE_WEIGHT),
    ("gym_strength", "Gorizontal blokni tortish", "O'tirib, dastani qorin tomon tortib, orqani to'g'ri ushlang va qo'llarni nazorat bilan uzating.", "cable machine", "beginner", "3 yondashuv × 10–12 takror", NOTE_WEIGHT),
    ("gym_strength", "Oyoq pressi", "Trenajyorda o'tirib, oyoqlarni platformaga qo'yib, tizzalarni to'liq qulflamasdan siqib chiqaring va qaytaring.", "machine", "beginner", "3 yondashuv × 10–12 takror", NOTE_WEIGHT),
    ("gym_strength", "Gantel bilan yelka pressi", "O'tirib yoki tik turib, gantellarni yelka darajasidan tepaga siqib chiqaring va sekin tushiring.", "dumbbell", "intermediate", "3 yondashuv × 8–12 takror", NOTE_WEIGHT),
    ("gym_strength", "Gantel bilan rumin tortish", "Gantellarni ushlab, tizzalar sal bukilgan holda dumbani orqaga tortib tanani oldinga egiling; orqa tekis, gantellar oyoqqa yaqin.", "dumbbell", "intermediate", "3 yondashuv × 8–10 takror", NOTE_WEIGHT),
    ("gym_strength", "Gantel bilan biceps bukish", "Tirsaklarni tanaga yaqin tutib, gantellarni yelka tomon bukib ko'taring va sekin tushiring.", "dumbbell", "beginner", "3 yondashuv × 10–12 takror", NOTE_WEIGHT),
    ("gym_strength", "Blokda triceps yozish", "Blok oldida turib, tirsaklarni tanaga yaqin ushlab dastani pastga yozing va sekin qaytaring.", "cable machine", "beginner", "3 yondashuv × 10–12 takror", NOTE_WEIGHT),
    ("gym_cardio", "Yugurish yo'lakchasida yurish", "Yo'lakchada qulay tezlikda yuring, tik turing va tutqichga haddan tashqari tayanmang.", "treadmill", "beginner", "10–30 daqiqa", NOTE_CARDIO),
    ("gym_cardio", "Velotrenajyor", "O'rindiq balandligini tizza yengil bukiladigan qilib sozlang va bir tekis pedal aylantiring.", "stationary bike", "beginner", "10–30 daqiqa", NOTE_CARDIO),
    ("gym_cardio", "Elliptik trenajyor", "Oyoq va qo'llar harakatini uyg'unlashtirib, bir tekis ritmda harakatlaning.", "elliptical", "beginner", "10–30 daqiqa", NOTE_CARDIO),
]

ACTIVITY_TYPES = [
    ("walking", "Yurish"), ("jogging", "Yengil yugurish"), ("running", "Yugurish"),
    ("cycling", "Velosiped"), ("hiking", "Piyoda sayr"), ("swimming", "Suzish"), ("other", "Boshqa faollik"),
]


# (nom, tur, kkal, daqiqa, masalliqlar, tayyorlash) — kkal TAXMINIY, DEMO kontent: dietolog ko'rib chiqishi shart
RECIPES = [
    ("Tovuq go'shti bilan salat", "lunch", 320, 15, "Qaynatilgan tovuq filesi 120 g\nBodring, pomidor, salat bargi\nZaytun moyi 1 osh qoshiq\nLimon sharbati", "Tovuqni qaynatib to'g'rang. Sabzavotlarni kesing. Hammasini aralashtirib, moy va limon sharbati bilan to'ldiring."),
    ("Sabzavotli makaron", "dinner", 280, 20, "Makaron 70 g\nQovoqcha, bolgar qalampiri, sabzi\nZaytun moyi 1 choy qoshiq\nTuz, ziravorlar", "Makaronni qaynating. Sabzavotlarni moyda yengil qovuring, makaron bilan aralashtiring."),
    ("Mevali suli bo'tqasi", "breakfast", 310, 10, "Suli yormasi 50 g\nSut yoki suv 200 ml\nBanan yoki olma\nBir hovuch yong'oq", "Yormani sutda 5–7 daqiqa pishiring. Ustiga mevalar va yong'oq qo'shing."),
    ("Ko'katli omlet", "breakfast", 240, 10, "Tuxum 2 dona\nUkrop, petrushka\nPomidor\nBir cho'tka tuz", "Tuxumni ko'kat bilan chayqang, tovada past olovda pishiring, pomidor qo'shing."),
    ("Tvorogli yong'oqli idish", "snack", 180, 5, "Tvorog 100 g\nYong'oq 15 g\nAsal 1 choy qoshiq", "Tvorogni idishga soling, ustiga yong'oq va asal qo'shing."),
    ("Mosh sho'rva", "lunch", 290, 40, "Mosh 60 g\nSabzi, piyoz, kartoshka\nZira, tuz\nZaytun moyi", "Moshni yumshaguncha qaynating, sabzavot qo'shib pishiring, ziravor soling."),
    ("Bug'da pishirilgan baliq va sabzavot", "dinner", 330, 25, "Oq baliq filesi 150 g\nBroqqoli, sabzi\nLimon, tuz", "Baliq va sabzavotlarni bug'da 15–20 daqiqa pishiring, limon sharbati bilan torting."),
    ("Yogurtli meva smuzisi", "snack", 160, 5, "Yogurt 150 g\nBanan yarmi\nQulupnay yoki malina bir hovuch", "Hammasini blenderda silliq qilib aralashtiring."),
    ("Bodring va ko'katli detoks suvi", "detox", 15, 5, "Suv 1 L\nBodring bir necha bo'lak\nYalpiz, limon", "Hammasini ko'zaga solib, sovutgichda 2 soat qoldiring."),
    ("Mevali likopcha", "detox", 120, 5, "Olma, mandarin, uzum\nBir necha yong'oq", "Mevalarni kesib likopchaga yoying."),
]

# (nom, toifa, daqiqa, tavsif, yo'riqnoma) — matnli yo'riqnomalar, audio yo'q
MEDITATIONS = [
    ("Sekin nafas olish", "stress", 5, "Stressni kamaytirish uchun oddiy nafas mashqi.",
     "Qulay o'tiring, yelkalarni bo'shating.\nBurundan 4 sanoq davomida nafas oling.\nOg'izdan 6 sanoq davomida sekin chiqaring.\nShu ritmni takrorlang, fikrlaringiz kelsa — nafasga qayting."),
    ("Tanani skanerlash", "sleep", 10, "Uxlashdan oldin tanani bo'shashtirish.",
     "Yotib, ko'zlarni yuming.\nDiqqatni oyoq barmoqlaridan boshlab asta tepaga ko'taring.\nHar bir qismda tarangliknii sezing va bo'shating.\nOxirida butun tanani bir butun his qiling."),
    ("Nafasni sanash", "focus", 7, "Diqqatni jamlash uchun.",
     "To'g'ri o'tiring, nigohni pastga qarating.\nHar bir nafas chiqarishda ichingizda sanang: 1 dan 10 gacha.\nSanog adashsa, jim 1 dan qayta boshlang.\nFikrlarni haydamang, shunchaki payqab, nafasga qayting."),
    ("Minnatdorchilik lahzasi", "motivation", 5, "Kunni ijobiy boshlash.",
     "Ko'zlarni yuming va uch marta chuqur nafas oling.\nBugun minnatdor bo'lgan uchta narsani eslang.\nHar biriga bir lahza to'xtab, ichingizda rahmat ayting.\nTabassum bilan ko'zlarni oching."),
    ("Kechki tinchlanish", "sleep", 8, "Kunni xotirjam yakunlash.",
     "Chiroqni xira qiling, qulay yoting.\nKun davomidagi eng yaxshi lahzani eslang.\nBoshqa tashvishlarni ertaga qoldirishga o'zingizga ruxsat bering.\nNafas olishni sekinlashtirib, tanani yostiqqa topshiring."),
    ("Qisqa stressdan chiqish", "stress", 6, "Ish o'rtasida tez tinchlanish.",
     "Stulda tik o'tiring, oyoqlar polda.\nYelkalarni quloqlarga ko'taring va nafas chiqarib tushiring (3 marta).\nBo'yinni sekin o'ngga va chapga buring.\nUch marta chuqur nafas oling va ishga qayting."),
]


# (nom, tavsif, rejim, tur, daraja, daqiqa, [(mashq nomi boshlanishi, soniya, takror)])
PROGRAMS = [
    ("To'liq tana mashqi", "Butun tanani yengil sur'atda ishlatadigan boshlang'ich dastur. Jihoz kerak emas.", "home", "full_body", "beginner", 20,
     [("Joyida yurish", 60, None), ("Tana vazni bilan cho'kkalash", None, 12), ("Tizza ustida turtib", None, 10), ("Dumba ko'prigi", None, 12),
      ("Plank", 30, None), ("Qo'l-oyoq ochib sakrash", 30, None), ("Mushuk", None, 10)]),
    ("Uyda kuch mashqlari", "Tana vazni bilan kuch va barqarorlikni oshirish.", "home", "strength", "beginner", 18,
     [("Devordan turtinish", None, 12), ("Stuldan turish", None, 10), ("Orqaga qadam", None, 8), ("Plank", 20, None), ("Bird-dog", None, 8)]),
    ("Cho'zilish va harakatchanlik", "Tinch sur'atdagi yengil cho'zilish va bo'g'inlarni qizdirish.", "home", "stretch", "beginner", 12,
     [("Yelka aylantirish", None, 10), ("Mushuk", None, 10), ("Boldir", 30, None), ("Bird-dog", None, 8), ("Dumba ko'prigi", None, 10)]),
    ("Yengil kardio", "Yurak urishini yengil oshiradigan uy kardiosi.", "home", "cardio", "beginner", 15,
     [("Joyida yurish", 120, None), ("Joyida tizzani", 40, None), ("Qo'l-oyoq ochib sakrash", 30, None), ("Joyida yurish", 60, None)]),
    ("Kuch va massa (zal)", "Zalda asosiy mushak guruhlari uchun klassik dastur. Trener ko'rsatmasi tavsiya etiladi.", "gym", "strength", "intermediate", 40,
     [("Shtanga bilan", None, 8), ("Skameykada gantel", None, 10), ("Yuqori blokni", None, 10), ("Gantel bilan yelka", None, 10),
      ("Gantel bilan rumin", None, 10), ("Blokda triceps", None, 12)]),
    ("Zalda kardio", "Trenajyorlarda bir tekis kardio.", "gym", "cardio", "beginner", 25,
     [("Yugurish yo'lakchasida", 600, None), ("Velotrenajyor", 480, None), ("Elliptik", 300, None)]),
]


def seed_reference_data(db: Session) -> None:
    cats = {c.code: c for c in db.scalars(select(ExerciseCategory)).all()}
    for code, name, mode in CATEGORIES:
        if code not in cats:
            cats[code] = ExerciseCategory(code=code, name=name, mode=mode)
            db.add(cats[code])
    existing_types = {t.code for t in db.scalars(select(ActivityType)).all()}
    for code, title in ACTIVITY_TYPES:
        if code not in existing_types:
            db.add(ActivityType(code=code, title=title))
    db.flush()
    titles = {e.title for e in db.scalars(select(Exercise)).unique().all()}
    for cat, title, desc, equip, diff, hint, note in EXERCISES:
        if title not in titles:
            db.add(Exercise(category_id=cats[cat].id, title=title, description=desc, equipment=equip,
                            difficulty=diff, duration_hint=hint, safety_note=note, is_active=True))
    db.flush()
    exs = list(db.scalars(select(Exercise)).unique().all())
    ptitles = {p.title for p in db.scalars(select(Program)).unique().all()}
    for title, desc, mode, kind, diff, mins, items in PROGRAMS:
        if title in ptitles:
            continue
        prog = Program(title=title, description=desc, mode=mode, kind=kind, difficulty=diff, duration_min=mins)
        for i, (prefix, secs, reps) in enumerate(items):
            ex = next((e for e in exs if e.title.startswith(prefix)), None)
            if ex:
                prog.items.append(ProgramItem(exercise_id=ex.id, seconds=secs, reps=reps, sort_order=i))
        db.add(prog)
    rtitles = {r.title for r in db.scalars(select(Recipe)).all()}
    for title, mt, kcal, mins, ingr, instr in RECIPES:
        if title not in rtitles:
            db.add(Recipe(title=title, meal_type=mt, kcal=kcal, prep_minutes=mins, ingredients=ingr, instructions=instr))
    mtitles = {m.title for m in db.scalars(select(MeditationItem)).all()}
    for title, cat, mins, desc, guide in MEDITATIONS:
        if title not in mtitles:
            db.add(MeditationItem(title=title, category=cat, duration_min=mins, description=desc, guide=guide))
    db.commit()


def seed_admin(db: Session) -> None:
    if not (settings.admin_email and settings.admin_password):
        return
    email = settings.admin_email.strip().lower()
    if db.scalar(select(User).where(User.email == email)):
        return
    admin = User(email=email, password_hash=hash_password(settings.admin_password), role="content_admin", is_adult_confirmed=True)
    admin.profile = FitnessProfile()
    admin.settings = UserSettings(language_code="uz", privacy_version=settings.policy_version)
    db.add(admin)
    db.commit()


def seed_demo_user(db: Session) -> None:
    """Sintetik demo foydalanuvchi (haqiqiy sog'liq ma'lumoti emas) — Figma/himoya uchun skrinshotlar."""
    email = "demo@fithayot.uz"
    if db.scalar(select(User).where(User.email == email)):
        return
    u = User(email=email, password_hash=hash_password("Demo12345"), role="user", is_adult_confirmed=True)
    u.profile = FitnessProfile(goal="general_fitness", experience_level="beginner", preferred_location="mixed", daily_minutes=30)
    u.settings = UserSettings(language_code="uz", privacy_version=settings.policy_version)
    db.add(u)
    db.flush()
    ex = {e.title: e for e in db.scalars(select(Exercise)).unique().all()}
    monday = (utcnow() + timedelta(minutes=settings.tz_offset_minutes)).date()
    monday -= timedelta(days=monday.weekday())
    plan = WorkoutPlan(user_id=u.id, title="Demo hafta", starts_on=monday, ends_on=monday + timedelta(days=6))
    for d, title, mins in [(0, "Tana vazni bilan cho'kkalash", 15), (0, "Dumba ko'prigi", 10),
                           (2, "Yuqori blokni tortish", 20), (4, "Plank (tirsakda tayanish)", 10)]:
        plan.items.append(PlanItem(exercise_id=ex[title].id, planned_date=monday + timedelta(days=d), planned_minutes=mins))
    db.add(plan)
    db.flush()
    start = utcnow().replace(hour=6, minute=0, second=0, microsecond=0) - timedelta(days=1)
    s = WorkoutSession(user_id=u.id, plan_id=plan.id, mode="home", status="completed", started_at=start, finished_at=start + timedelta(minutes=25))
    db.add(s)
    db.flush()
    db.add(ExerciseLog(session_id=s.id, exercise_id=ex["Tana vazni bilan cho'kkalash"].id, plan_item_id=plan.items[0].id, set_no=1, reps=12))
    db.add(ActivityLog(user_id=u.id, activity_type_id=db.scalar(select(ActivityType.id).where(ActivityType.code == "walking")),
                       occurred_at=start + timedelta(hours=10), duration_minutes=30, distance_km=2.4, note="Ertalabki sayr"))
    db.commit()


def run(demo: bool = False) -> None:
    Base.metadata.create_all(engine)
    ensure_columns(engine)
    with SessionLocal() as db:
        seed_reference_data(db)
        seed_admin(db)
        if demo:
            seed_demo_user(db)


if __name__ == "__main__":
    run(demo="--demo" in sys.argv)
    print("Seed yakunlandi.")
