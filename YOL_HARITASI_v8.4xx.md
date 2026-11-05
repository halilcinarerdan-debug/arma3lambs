# Yol haritası: fazlı birleşik harekât (Fırat Kalkanı tarzı) — v8.407 sonrası

Durum notu: v8.406–v8.407 değişiklikleri (tank piyade bağı sahipliği, harekât objektifi "başka planda" beklemesi, oyuncu yolcu araç, binme beklemesi, sade Saldırı/Savunma Objektifi, Objektif'e İHA desteği) oyunda DOĞRULANMADI. Her aşama kendi "kabul ölçütü" ile RPT üzerinden doğrulanır; doğrulanmayan aşama bir sonrakine geçmez.

İlkeler: (1) kontrol kaybolmaz: yeni davranış varsayılanla kapalı/uyumlu, gelişmiş ayar saklı kalır; (2) eski sahneler bozulmaz (eski modüller durur); (3) her davranış log etiketiyle izlenir; (4) sayılar TASARIM değeridir, kitapta sayı yoksa öyle yazılır.

---

## Aşama 0 — Doğrulama ve temizlik (v8.408)
Amaç: v8.406/407 düzeltmelerinin gerçekten çalıştığını görmek.

| İş | Kabul ölçütü (RPT) |
|---|---|
| Sade Saldırı/Savunma Objektifi 3DEN'de açılıyor, ayarlar görünüyor | `[EDEN] Objektif (3DEN) ... plan istegi gonderildi`; config hatası yok |
| Görev Ata `RECON` / `RECON ARACI` okunuyor | `[GOREV-ATAMA] recon -> RECON`, `[PLAN-RECON]`, `[RECON-ARAC]` |
| Tank dur-kalk bitti | `PIYADE BAGI` satırı 3 sn'de bir tekrar etmiyor; `KAPI-ACILDI` makul sürede |
| Harekât fazı sırası | `FAZ 1 basladi (1 objektif)` → Faz 1 BITTI → `FAZ 2 basladi` |
| Objektif "baska planda" bekleme | `gruplar baska planda mesgul - bekleniyor` sonra `plan KURULDU` |
| Oyuncu yolcu araç kalkıyor | `[TASIMA] ... BINDI`, oyuncunun aracı `YOL ZINCIRI` |
| İHA desteği | `[PLAN-IHA]` satırı, dron görev alıyor |
| Binmeyen asker seferi | `[TASIMA] ... sefer` ve geride asker kalmıyor |

Ek işler: Zeus panelindeki zincir alanlarını kaldır; Görev Ata `Otomatik` hâlâ etiket okumuyorsa `edGorKod` okuma yolunu incele (kök neden açık madde).

## Aşama 1 — Koordinasyon omurgası (v8.409–v8.411) ★ öncelik
Log'larda görülen asıl sorun: planlar arası koordinasyon yok.

1. **Grup/araç sahipliği (v8.409).** Bir grup/araç aynı anda tek planda. Çakışma tespitinde log + nedenli ret (`[PLAN-SAHIP]`). Tank gibi paylaşılan destek unsurları için "hangi plana hizmet ediyor" açık kayıt. Kabul: iki plan aynı grubu almıyor.
2. **Faz hattı / sınır çizgisi (v8.410).** Faza opsiyonel hareket hattı (LD / LOA / ileri sınır). Hattı geçmeden bekleme, komşuyla hizalanma. Harekât modülüne "hat" ayarı; Objektif'e yaklaşma ekseni var, onu kullan.
3. **Sektör ve komşu koordinasyonu (v8.411).** Paralel planlara sektör sınırı; birbirinin önüne geçme ve dost ateşi azaltma. Kabul: iki paralel planda zırh/piyade birbirine yetişiyor, `[PLAN-HAT]` logları tutarlı.

Bağımlılık: `fnc_komutanPlan`, `fnc_komutanPlanDongu`, `fnc_planZirh`. Risk: plan döngüsü büyük; küçük adımlarla, her adımdan sonra RPT.

## Aşama 2 — Ağırlık merkezi ve yedek (v8.412–v8.413)
1. **Ana çaba / yardımcı çaba.** Harekât modülünde faza "ana çaba" objektifi. Zırh, topçu ve İHA önceliği ana çabada.
2. **Yedek komutanı.** `YEDEK` rolünün serbest bırakılması: ana çabada tıkanma (temas + ilerleme yok) ya da kayıp eşiği → yedek devreye. Savunmada karşı saldırı.
3. **Kayıp devri.** Etkisiz grubun görevi komşu/yedek gruba (kayıp eşiği mevcut: %50).
Kabul: tıkanan planda yedek serbest kalıyor (`[PLAN-YEDEK]`).

## Aşama 3 — Ele geçir → güvence → sömürü (v8.414–v8.415)
1. **Güvence aşaması.** Saldırı Objektifi alındıktan sonra otomatik: çevre güvenliği/mevzilenme (mevcut Karakol/Savunma mantığını yeniden kullan), sonra faz geçişi. Eski "zincirde tut" davranışının faz tabanlı karşılığı.
2. **Sömürü.** Düşman kırılınca öncü (mekanize/zırh) sıradaki objektife; ana kol arkadan. Sınır: hat kuralları (Aşama 1) çiğnenmez.
Kabul: Faz geçişinde bırakılan güvence grubu mevzide, ana kol ilerlemiş.

## Aşama 4 — Ateş ve istihbarat entegrasyonu (v8.416–v8.418)
1. **Topçu hedef planı.** Faza bağlı hedef listesi; hazırlık/kaydırma; **FSCL** (dost yaklaşınca ateş durur/kayar). Mevcut dost mesafesi kontrolünü genişlet.
2. **Durum resmi (COP).** Recon + İHA raporlarını tek yapıda topla; faz başlamadan OPORD düşman paragrafını güncelle.
3. **Recon çeşitleri.** Birden çok OP, İHA keşfi + yaya recon birleşik rapor.
Kabul: topçu dost yakınında durur; OPORD güncellemesi oyuncuya düşer.

## Aşama 5 — Çevre ve engeller (v8.419–v8.421)
1. **Engel/mayın/IED modülü + istihkâm rolü.** Konvoy yavaşlar/rota değiştirir; engel temizleme.
2. **Şehir muharebesi.** Kenarda zırh destek, piyade sokak temizleme; bina temizleme yeniden yazımı (mevcut bekleyen iş).
3. **Gece/hava.** NVG/tempo/İHA kısıtı davranış bağlantısı; sivil davranışı.
Kabul: şehir kenarında zırh bekliyor, piyade bina temizliyor; engelde konvoy davranışı log'lu.

## Aşama 6 — Lojistik ve devamlılık (v8.422+)
Faz arası toparlanma içinde yaralı toplama, cephane dağıtımı, yakıt; plan komutanı kaybında devir bildirimi; helikopter medevac/hava nakli (bekleyen).

## Modül sadeleştirmenin devamı (paralel, küçük adımlar)
- Karakol + Garnizon birleşimi → Savunma Objektifi içinde "garnizon" ayarı (eski modüller kalır).
- İHA: türe göre grup (FPV / silahlı-gözlem) ayarlarını Objektif'e taşıma; bağımsız İHA modülü kalır.
- Görev Ata: iki kademeli seçim (Plan rolü / Özel rol) — şimdilik yalnız etiket gruplaması yapıldı.
- Sahne şablonu: örnek "Fırat Kalkanı" görev dosyası + `TEST_SENARYOLARI.md` güncellemesi.

## Sürüm disiplini
- Her aşama: değişiklik → RPT ile kabul ölçütü → `DEVIR_LOGU` ve `OZELLIKLER_LISTESI` güncelleme.
- Doğrulanmayan davranış belgede "T" (doğrulanmadı) işaretlenir.
- Büyük aşama başlamadan önce kod incelemesi ve küçük prototip; geri alma için bayrak (CBA ayarı ile kapatma) bırakılır.

## Açık sorular (karar bekleyen)
1. Faz hattı: çizgi 3DEN'de elle (modül/işaret) mi çizilsin, yoksa Objektif yaklaşma ekseninden otomatik mi türetilsin?
2. Ana çaba seçimi: Harekât modülünde faz başına tek Objektif mi, yoksa Objektif'te "ana çaba" onay kutusu mu?
3. Güvence aşaması varsayılan açık mı kapalı mı? (öneri: açık, süre 5 dk)
