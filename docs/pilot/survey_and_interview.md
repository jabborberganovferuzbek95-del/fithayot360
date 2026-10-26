# Pilot: so'rovnoma va intervyu shablonlari

> Haqiqiy foydalanuvchilar (kamida 18 yosh), yozma rozilik bilan. Sog'liq tashxisi yoki tibbiy ma'lumot **so'ralmaydi**.

## Rozilik matni (qisqa)
"Men FitHayot 360 ilovasini sinovdan o'tkazishda ixtiyoriy qatnashayotganimni, 18 yoshdan kattaligimni, ilova tibbiy maslahat bermasligini
va istalgan vaqtda ma'lumotlarimni o'chirishni so'rashim mumkinligini tushundim."  Ism/imzo: ______  Sana: ______

## Pilot jadvali (tavsiya)
| Kun | Ish |
|---|---|
| 1 | Rozilik, o'rnatish, onboarding va birinchi seans kuzatuvi (5–8 daqiqa) |
| 2–6 | Erkin foydalanish; Active/Home/Gym qaydlari |
| 7 | So'rovnoma (quyida) + 15 daqiqalik intervyu |

## So'rovnoma (1–5 shkala: 1 = umuman rozi emasman, 5 = to'liq roziman)
1. Ro'yxatdan o'tish va profil sozlash oson edi.
2. Kerakli mashqni katalogdan tez topdim.
3. Seans paytida takror/vaznni yozish qulay edi.
4. Haftalik progress ekrani tushunarli va foydali.
5. Uyda, zalda va yurish faolligini bitta ilovada yuritish menga qulay.
6. Ilova xatosiz ishladi (xato bo'lsa, qayerda?).
7. Mashq tavsiflari va xavfsizlik izohlari tushunarli edi.
8. Ilovani yana ishlatgan bo'lardim (NPS: 0–10 do'stingizga tavsiya qilish ehtimoli).
9. Eng yoqqan 1 narsa. 10. Eng bezovta qilgan 1 narsa. 11. Qaysi funksiya yetishmadi?

## Intervyu savollari
- Bugungi mashg'ulotlaringizni hozir qanday qayd etasiz (daftar, boshqa ilova, umuman yo'q)?
- Ilovada birinchi marta nimada adashdingiz? (kuzatuvchi qayd etadi)
- Bitta hisobda uchala yo'nalish bo'lishi sizga nima beradi?
- Qaysi ma'lumotni kiritishni noqulay yoki ortiqcha deb topdingiz?
- Qanday sharoitda pullik versiya haqida o'ylab ko'rardingiz?

## Hisoblanadigan ko'rsatkichlar
- **Aktivatsiya** = profilni to'ldirib, kamida 1 yakunlangan seans yoki faollik yozgan foydalanuvchilar / ro'yxatdan o'tganlar.
- **Hafta davomida faol kunlar** = `GET /progress/weekly` → `days[].sessions + activities > 0` kunlar soni.
- **7 kunlik retention** = 7-kuni ham qayd yozganlar / 1-kuni yozganlar (ilovada login hodisalari saqlanmaydi — qaydlar bo'yicha hisoblang).
- **Xatolar**: qayd etilgan nuqsonlar soni va jiddiyligi (`test_protocol.md`).
