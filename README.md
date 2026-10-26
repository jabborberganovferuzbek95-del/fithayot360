# FitHayot 360 — MVP

Home (uy), Gym (zal) va Active (kundalik faollik) mashg'ulotlarini **bitta hisob, bitta tarix va bitta haftalik progress**da yurituvchi
mobil ilova. Texnik topshiriq: `FitHayot_360_texnik_topshiriq_15_para.docx`. Ilova tibbiy tashxis/davolash vositasi emas, sun'iy intellekt ishlatilmaydi, 18+.

```
fithayot360/
├── backend/   FastAPI + SQLAlchemy + PostgreSQL (v3: 71 endpoint, 44 test)
├── mobile/    Flutter ilovasi (v3: ~45 ekran, qorong'i tema, Provider + http)
├── docs/      ERD, schema.sql, API, openapi.json, traceability, test bayonnomasi, pilot shablonlari
└── docker-compose.yml
```

## 1. Backend
**Docker bilan (eng oson):**
```bash
docker compose up --build        # API: http://localhost:8000/docs
```
**Qo'lda:**
```bash
cd backend
python -m venv .venv && source .venv/bin/activate
pip install -r requirements.txt
cp .env.example .env             # DATABASE_URL va JWT_SECRET ni to'g'rilang
export $(grep -v '^#' .env | xargs)
python -m app.seed --demo        # jadvallar + katalog + admin + demo foydalanuvchi
uvicorn app.main:app --reload    # Swagger: http://localhost:8000/docs
pytest -q                        # SQLite; PostgreSQL: TEST_DATABASE_URL=postgresql+psycopg2://...
```
Demo hisob: `demo@fithayot.uz` / `Demo12345` · Kontent admin: `.env` dagi `ADMIN_EMAIL` / `ADMIN_PASSWORD`.
Parol tiklash: SMTP ulanmagani uchun `EXPOSE_RESET_TOKEN=true` bo'lganda token javobda qaytadi (faqat development).

## 2. Mobil ilova
Flutter SDK (3.22+) kerak. Bu papkada faqat `lib/` va `pubspec.yaml` bor — platforma papkalarini yarating:
```bash
cd mobile
flutter create . --platforms=android --org uz.fithayot --project-name fithayot360   # lib/ va pubspec.yaml'ni qayta yozmaydi
flutter pub get
flutter run --dart-define=API_BASE_URL=http://10.0.2.2:8000     # Android emulyator
# haqiqiy telefon: --dart-define=API_BASE_URL=http://<kompyuter-IP>:8000
```
Android'da **release** build uchun `android/app/src/main/AndroidManifest.xml` ga qo'shing:
`<uses-permission android:name="android.permission.INTERNET"/>` va (faqat dev, HTTP uchun) `<application android:usesCleartextTraffic="true" ...>`.
Productionda faqat HTTPS ishlating.

## v3: yangi maket (dasturlar, odatlar, maslahatchi, qorong'i tema ...)
Batafsil: [docs/UPDATE_v3.md](docs/UPDATE_v3.md) va [docs/traceability.md](docs/traceability.md).

## v2: yangi dizayn va bo'limlar
Ovqatlanish (retseptlar, kkal), suv, uyqu, qadam (qo'lda), meditatsiya, odatlar, hafta/oy statistikasi, maqsadlar, Premium ("xabar bering").
**Mavjud o'rnatishni yangilash:** [docs/UPDATE_v2.md](docs/UPDATE_v2.md).

## 3. Muhim: nima tekshirilgan, nima yo'q
| | Holat |
|---|---|
| Backend | 26 avtomatik test (AT-01…AT-12 + 14 qo'shimcha) **SQLite va PostgreSQL 16** da o'tgan; server haqiqiy PostgreSQL'da demo ma'lumot bilan ishga tushirilgan |
| Flutter | Kod yozilgan, lekin **kompilyatsiya va qurilmada sinov qilinmagan** (muhitda Flutter SDK yo'q). Birinchi `flutter analyze` / `flutter run` da kichik tuzatishlar chiqishi mumkin |
| Mashq kontenti | Seed ma'lumotlari **DEMO**. Ishlatishdan oldin malakali fitness mutaxassisi tekshirishi shart (NFR-12) |
| Bajarilmagan (kod emas, sizning ishingiz) | Figma dizayn, foydalanuvchi intervyulari va pilot, deploy (HTTPS, server), maxfiylik siyosati/shartlar matni, ilova ikonkasi va store materiallari, himoya prezentatsiyasi |

To'liq talablar jadvali: [docs/traceability.md](docs/traceability.md).

## 4. Keyingi qadamlar (tavsiya etilgan tartib)
1. `flutter create` + `flutter run`, [docs/test_protocol.md](docs/test_protocol.md) dagi M1–M13 ni qurilmada o'tkazing, nuqsonlarni yozing.
2. Mutaxassisga mashq kontentini ko'rsating, admin orqali (`/admin/exercises`) tuzating.
3. Serverga joylashtiring (HTTPS, `APP_ENV=production`, kuchli `JWT_SECRET`, `EXPOSE_RESET_TOKEN=false`, SMTP).
4. Pilot: [docs/pilot/survey_and_interview.md](docs/pilot/survey_and_interview.md).
5. Production oldidan: Alembic migratsiyalari, rate limiting, zaxira nusxa.
