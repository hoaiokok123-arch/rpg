# RPGPlayer

Huong dan nhanh de build IPA bang GitHub Actions va cai bang TrollStore.

## 1) Push code len GitHub

1. Tao repository moi tren GitHub (vi du: `RPGPlayer`).
2. Trong thu muc project, chay:

```bash
git init
git branch -M main
git add .
git commit -m "Initial RPGPlayer project"
git remote add origin https://github.com/<your-username>/RPGPlayer.git
git push -u origin main
```

## 2) Download IPA tu GitHub Actions Artifacts

1. Mo repository tren GitHub.
2. Vao tab `Actions`.
3. Chon workflow `Build RPGPlayer IPA` (trigger boi push len `main`).
4. Mo run moi nhat.
5. O cuoi trang, tai artifact `RPGPlayer-ipa`.
6. Giai nen artifact de lay file `RPGPlayer.ipa`.

## 3) Cai IPA bang TrollStore

1. Chuyen file `RPGPlayer.ipa` vao iPhone/iPad (AirDrop, iCloud Drive, Telegram, ...).
2. Mo `TrollStore`.
3. Nhan `Install IPA` (hoac mo file `.ipa` trong Files va chon TrollStore).
4. Chon `RPGPlayer.ipa` de cai dat.
5. Sau khi cai xong, mo app tu man hinh chinh.
