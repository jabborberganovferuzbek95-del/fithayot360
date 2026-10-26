# v1 -> v2 yangilash (ma'lumotlar saqlanadi)

## 1. Server (virtual mashina)
Yangi zipni VM'ga olib o'ting (shared folder yoki scp) va **faqat `backend` papkasini** almashtiring:
```bash
cd ~/fithayot360
cp -r backend backend_eski                       # zaxira
unzip -o ~/fithayot360_project_v2.zip 'backend/*' 'docs/*' 'README.md' -d .   # yoki qo'lda nusxalang
sudo docker compose up --build -d
curl http://localhost:8000/health
```
Yangi jadvallar server ishga tushganda o'zi yaratiladi, retsept va meditatsiya kontenti avtomatik qo'shiladi.
**`docker compose down -v` BERMANG** — u bazani o'chiradi.

Tekshirish: `http://VM_IP:8000/docs` da `/recipes`, `/water`, `/stats` ko'rinishi kerak.

## 2. Ilova (Windows)
`mobile\lib` papkasini yangisiga **to'liq almashtiring** (pubspec.yaml o'zgarmagan, yangi paket yo'q).
`android` papkasi va sozlamalaringiz (INTERNET ruxsati, minSdk, Java 21) saqlanadi, ularga tegmang.
```
cd mobile
flutter pub get
flutter analyze
flutter build apk --release --dart-define=API_BASE_URL=http://10.83.33.177:8000
```
