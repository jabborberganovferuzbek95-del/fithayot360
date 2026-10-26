# Test bayonnomasi (to'ldirish uchun)

## 1. Avtomatik testlar (backend)
```
cd backend && pytest -q                                             # SQLite
TEST_DATABASE_URL=postgresql+psycopg2://... pytest -q               # PostgreSQL
```
Natija (tayyorlash vaqtida): 26 passed — SQLite va PostgreSQL 16.

## 2. Qo'lda sinov (qurilmada) — Flutter ilovasi
Har qatorga sana, qurilma/Android versiyasi va natijani yozing.

| № | Senariy | Kutilgan natija | Natija | Izoh |
|---|---|---|---|---|
| M1 | Onboarding → ro'yxatdan o'tish (18+ belgilanmagan) | Xabar chiqadi, hisob ochilmaydi (AT-01) | | |
| M2 | To'g'ri ro'yxatdan o'tish → profil → dashboard | Profil saqlanadi, qayta kirganda ko'rinadi | | |
| M3 | Noto'g'ri parol bilan kirish | "Email yoki parol noto'g'ri" | | |
| M4 | Katalog: qidiruv + daraja/jihoz filtri | Ro'yxat mos o'zgaradi | | |
| M5 | Mashqni rejaga qo'shish → Planner'da ko'rinish | Tanlangan kunda ko'rinadi (AT-03) | | |
| M6 | Rejadan Home seansini boshlash, 2 yondashuv, yakunlash | Reja bandi ✔, tarixda paydo bo'ladi | | |
| M7 | Gym: takror + vazn; vaznsiz qayd | Ikkalasi saqlanadi (AT-04) | | |
| M8 | Manfiy/0 qiymat kiritish | Maydon xatosi, saqlanmaydi (AT-06) | | |
| M9 | Active 25 daqiqa → Natijalar | Haftalik jami +25 (AT-05) | | |
| M10 | Seans o'rtasida ilovani yopib qayta ochish | "Davom ettirildi" xabari, qaydlar saqlangan | | |
| M11 | Samolyot rejimi → qayd saqlash | Tushunarli xato; ulanish tiklangach qayta urinish dublikat yaratmaydi (AT-10) | | |
| M12 | Reja yo'q hafta progressi | Foiz o'rniga "N/A" (AT-09) | | |
| M13 | Hisobni o'chirish | Tizimdan chiqadi, qayta kirib bo'lmaydi | | |

## 3. Topilgan nuqsonlar
| № | Tavsif | Jiddiylik | Holat |
|---|---|---|---|
