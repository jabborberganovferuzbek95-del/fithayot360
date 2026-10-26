# v2 -> v3 yangilash (ma'lumotlar saqlanadi)

## 1. Server (virtual mashina)
`backend` papkasini yangisiga almashtiring va qayta yig'ing:
```bash
cd ~/fithayot360
cp -r backend backend_v2_zaxira
# yangi backend papkasini shu yerga nusxalang (shared folder yoki scp), keyin:
sudo docker compose up --build -d
curl http://localhost:8000/health
```
Yangi jadvallar (dasturlar, odatlar) va yangi ustunlar (ism, faollik darajasi, rasm URL) server ishga tushganda
**o'zi qo'shiladi** (`app/migrate.py`), eski foydalanuvchilar saqlanadi. Dasturlar avtomatik seed qilinadi.
**`docker compose down -v` BERMANG** — u bazani o'chiradi.

Tekshirish: `http://VM_IP:8000/docs` da `/programs`, `/habits`, `/insights`, `/coach/ask`, `/me/summary` ko'rinishi kerak.

## 2. Ilova (Windows)
`mobile\lib` papkasini yangisiga **to'liq almashtiring** (eski fayllarni o'chirib, yangilarini nusxalang).
`pubspec.yaml` o'zgarmagan, yangi paket yo'q. `android` papkasi va sozlamalaringizga tegmang.
```
cd mobile
flutter pub get
flutter analyze
flutter build apk --release --dart-define=API_BASE_URL=http://10.83.33.177:8000
```

## 3. Rasm qo'shish (fotosuratlar)
Fotosuratlarni o'zingiz litsenziyali manbadan olib, biror joyga (masalan, o'z serveringiz) joylashtiring va `image_url` ga yozing:
- mashqlar: `PATCH /admin/exercises/{id}` `{"image_url": "https://..."}`
- retseptlar: `PATCH /admin/recipes/{id}`
Ilova rasm bo'lsa uni ko'rsatadi, bo'lmasa gradient fonni.
