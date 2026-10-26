# Talablar bajarilishi (traceability)

Belgilar: ✅ backend'da bajarilgan va avtomatik testlangan · 📱 Flutter'da yozilgan, **qurilmada hali sinalmagan** · 🔧 kodda yo'q / sizning ishingiz.

| Talab | Holat | Qayerda |
|---|---|---|
| FR-01 Ro'yxatdan o'tish, 18+ va rozilik | ✅📱 | `auth.register`, `RegisterScreen`; AT-01 |
| FR-02 Kirish, chiqish, parol tiklash | ✅📱 | `auth.*`, `ForgotPasswordScreen`. Email yuborish (SMTP) 🔧 — hozir dev rejimida token javobda qaytadi |
| FR-03 Fitness profil | ✅📱 | `PATCH /me`, `ProfileSetupScreen` |
| FR-04 Home/Gym/Active bo'limlari | ✅📱 | `MainShell` |
| FR-05 Katalog, qidiruv, filtr | ✅📱 | `GET /exercises`, `CatalogScreen` |
| FR-06 Mashq tafsiloti + xavfsizlik izohi | ✅📱 | `safety_note` har mashqda majburiy |
| FR-07 Haftalik reja | ✅📱 | `/plans`, `PlannerScreen` |
| FR-08 Rejani tahrirlash/olib tashlash | ✅📱 | `/plans/{id}/items` PATCH/DELETE |
| FR-09 Seans boshlash/yakunlash | ✅📱 | `/sessions`, `SessionScreen`, `FinishScreen` |
| FR-10 Yondashuv/takror/vazn/vaqt qaydi | ✅📱 | `/sessions/{id}/logs`; AT-04, AT-06 |
| FR-11 Gym vazn ixtiyoriy | ✅ | AT-04 |
| FR-12 Active qo'lda kiritish | ✅📱 | `/activities`, `ActiveScreen`; AT-05 |
| FR-13 Yagona tarix + filtr | ✅📱 | `/history`; AT-12 |
| FR-14 Haftalik progress | ✅📱 | `/progress/weekly`; AT-05, AT-08 |
| FR-15 Reja bajarilish foizi (bo'sh reja = N/A) | ✅📱 | AT-09, `test_plan_completion_rate` |
| FR-16–FR-19 Kontent admin | ✅ | `/admin/exercises` POST/PATCH + `content_audit`; AT-11. Admin veb-paneli 🔧 (hozir faqat API/Swagger) |
| FR-22 Eksport va hisobni o'chirish | ✅📱 | `GET /me/export`, `DELETE /me` (P1). Mobil ilovada JSON faylni ulashish 🔧 |
| FR-20, 21, 23–25 (eslatma, Excel, tavsiya, ijtimoiy, to'lov) | 🔧 | P1/P2 — MVP doirasidan tashqarida; eslatma kalitchasi UI'da o'chirilgan |
| NFR-01 Parol xavfsizligi | ✅ | bcrypt (12 raund), parol hech qachon qaytarilmaydi |
| NFR-02 Ma'lumot egaligi | ✅ | har resurs `user_id` bo'yicha; begona resurs 404; AT-07 |
| NFR-05 HTTPS | 🔧 | deploy paytida reverse proxy (Caddy/Nginx) orqali |
| NFR-09 Xatolik xabarlari | ✅ | global handler, ichki tafsilot chiqmaydi |
| NFR-12 Mutaxassis tekshiruvi | 🔧 | seed kontent **DEMO**; fitness mutaxassisi ko'rib chiqishi shart |
| Rate limiting, login brute-force himoyasi | 🔧 | reverse proxy yoki `slowapi` bilan qo'shing |
| Alembic migratsiyalar | 🔧 | hozir `create_all`; `docs/schema.sql` bor. Production oldidan Alembic'ga o'ting |

## Qabul testlari (TT 8.2)
AT-01…AT-12 → `backend/tests/test_acceptance.py` (12 ta, hammasi o'tadi). Qo'shimcha 14 ta test `test_extra.py`da.
Jami 26 ta test **SQLite'da ham, PostgreSQL 16'da ham** o'tkazilgan.

## v2: rasm (dizayn) asosida qo'shilgan bo'limlar — TT doirasidan tashqari kengaytma

| Bo'lim | Holat | Izoh |
|---|---|---|
| Yangi dizayn (yashil mavzu, qadam halqasi, bo'limlar to'ri) | 📱 | Rasmdagi fotosuratlar o'rniga ikonka va gradient (litsenziyali rasmlar kiritilmagan) |
| Qadam | ✅📱 | **Qo'lda kiritiladi** (sensor/GPS yo'q) |
| Suv | ✅📱 | maqsad foydalanuvchi belgilaydi; Idempotency-Key |
| Uyqu | ✅📱 | kuniga bitta qayd (upsert), sifat 1–5 ixtiyoriy |
| Ovqatlanish: retseptlar, ovqat qaydi, kkal | ✅📱 | 10 ta DEMO retsept, kkal taxminiy, **dietolog tekshiruvi kerak** |
| Meditatsiya | ✅📱 | matnli yo'riqnoma + taymer + nafas animatsiyasi; audio/video yo'q |
| Odatlar | ✅📱 | ma'lumotlardan avtomatik hisoblanadi |
| Statistika (hafta/oy) | ✅📱 | qadam, ovqat kkal, faol vaqt, suv, uyqu, meditatsiya |
| Premium | ✅📱 | to'lov yo'q: faqat "xabar bering" ro'yxati |
| Rasmdagi vazn/bo'y/yosh, yoqilgan kaloriya, vazn dinamikasi | 🔧 qasddan kiritilmagan | TT: shaxsiy sog'liq ma'lumoti yig'ilmaydi; yoqilgan kaloriya tibbiy da'vo bo'lib qolishi mumkin |
| Mashq videolari, ovqat/yoga fotosuratlari | 🔧 | kontent va litsenziya kerak |

Avtomatik testlar: 35 ta (SQLite va PostgreSQL 16), shundan 9 tasi v2 uchun (`tests/test_wellness.py`).

## v3: yangi maket (to'liq ekranlar to'plami)

| Maketdagi ekran | Holat | Izoh |
|---|---|---|
| Hero + imkoniyatlar onboardingi | 📱 | |
| Hisob yaratish (ism, email, parol) | ✅📱 | Google/Apple orqali kirish **yo'q** (OAuth kalitlari va dasturchi hisoblari kerak) |
| "Asosiy maqsadingiz nima?" (6 maqsad) | ✅📱 | |
| "Shaxsiy ma'lumotlar" | ✅📱 qisman | Faollik darajasi, joy, tajriba, vaqt bor. **Jins/yosh/bo'y/vazn so'ralmaydi** (TT maxfiylik qoidasi) |
| Bosh sahifa (qadam, 6 bo'lim, bugungi reja, ism, bell) | ✅📱 | |
| Mashq dasturlari + tafsilot + bosqichma-bosqich pleyer | ✅📱 | 6 ta DEMO dastur; taymer, avtomatik qayd; rasm uchun `image_url` maydoni bor (fotosuratlar kiritilmagan) |
| Ovqatlanish: retseptlar, ratsion (kkal) | ✅📱 | |
| Suv: Bugun/Hafta/Oy | ✅📱 | **Eslatmalar (push) yo'q**: yangi paket va Android sozlamalari kerak |
| Uyqu: Kuzatuv/Maslahatlar/Tarix | ✅📱 | Uyqu bosqichlari (REM, chuqur) yo'q: sensor kerak |
| Meditatsiya: hero + ro'yxat + taymer | ✅📱 | audio yo'q, matnli yo'riqnoma |
| Odatlar: Bugungi/Haftalik/Barcha + "Yangi odat" + iqtibos | ✅📱 | |
| Statistika: Hafta/Oy/Yil | ✅📱 | vazn dinamikasi yo'q |
| Mening profilim (seanslar, faol kun, seriya, yutuqlar) | ✅📱 | maketdagi vazn/bo'y/yosh o'rniga faollik ko'rsatkichlari |
| Premium | ✅📱 | to'lov yo'q, "xabar bering" ro'yxati |
| AI yordamchi | ✅📱 **o'zgartirilgan** | "Maslahatchi": qoidalarga asoslangan, **AI emas** (TT: sun'iy intellekt ishlatilmaydi) |
| Bildirishnomalar | ✅📱 | ilova ichidagi, ma'lumotlardan hisoblangan maslahatlar; telefon push yo'q |
| Sozlamalar: profil, maqsad, til, **qorong'i tema**, maxfiylik, yordam, haqida | ✅📱 | til hozircha faqat o'zbekcha |

Avtomatik testlar: 44 ta (SQLite va PostgreSQL 16). v2→v3 yangilash haqiqiy PostgreSQL'da sinalgan: eski ma'lumotlar saqlanadi (`app/migrate.py`).
