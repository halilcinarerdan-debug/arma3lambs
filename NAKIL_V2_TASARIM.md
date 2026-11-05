# Nakil V2 (dal: claude/nakil-v2) — tasarım ve test planı

Amaç: personel naklini yamalardan arındırıp tek betikte, açık durum makinesiyle çalıştırmak. Eski `fnc_aracTasima` yerinde duruyor; geçiş CBA ayarı **"Nakil V2"** (varsayılan AÇIK, bu dalda) ya da `lambs_danger_nakilV2 = false` ile.
Sözleşme eskisiyle aynı (`tasimaCtl`: [iptal, kapı, binen asker, yüklenen araç, toplam araç, IFV listesi, …]), bu yüzden komutan planı değişmeden çalışır.

## Eski sistemde görülen sorunlar → V2 karşılığı
| RPT'de görülen | V2'de |
|---|---|
| Her araç kendi betiğinde bekleme döngüsü, erken binen önce gidiyor | Tek betik; tüm araçlar hazır olmadan + plan kapısı açılmadan **hiçbiri kalkmaz** |
| Açıkta kalan 1–2 asker; aynı asker tekrar tekrar "alındı" | Manifest koltuk sayısına göre kurulur; 20 sn sonra kalan (≤300 m) askeri **düz koltuğa oturtma**; kapasiteyi doluluktan öğrenme |
| Oyuncu alınmadan gidiyor / oyuncu kamyonu eşleşmiyor | Oyuncu + ekibi manifestin **en başında**; araç oyuncuyu en çok 90 sn bekler (sohbet bildirimi); binmezse ekibi de iner; oyuncu başka konvoy aracına binerse sayılır |
| Konvoyda herkes birbirini geçmeye çalışıyor | Sıra inişe yakınlığa göre dinamik; arkadaki, öndekinin hızını (+3 m/sn) aşmaz, 12 m'den yaklaşmaz |
| Aynı grup / araç iki planda | Plan seçiminde 25 sn rezervasyon (`planRezT`, v8.407) + nakil havuzunda `tasimaMesgul` |

## Aşamalar (`fnc_nakilV2.sqf`)
1 HAVUZ → 2 MANİFEST → 3 YÜKLEME → 4 KAPI → 5 SÜRÜŞ → 6 İNİŞ. Her aşama `[NAKIL2]` etiketiyle loglanır.

## Bilinen eksikler (ilk sürüm — eski sistemde var, V2'de YOK)
- Su geçidi / dere koruması, pusu davranışı, hasarlı araç için yedek araçla kurtarma nakli (`TASIMA-KURTARMA`).
- İniş sonrası çevre emniyetiyle toplanma (V2: askerler doğrudan serbest, `doFollow`).
- Zeus `taksi` hâlâ eski `aracTasima`'yı çağırır.
- Yol zinciri hesabı araçlar için sırayla yapılır (araç başına ≤4 sn).

## Test kontrol listesi (RPT)
1. Boot: `ELITE build v8.500-NAKIL2`.
2. `[NAKIL2] MANIFEST: … arac / … asker` ve araç başına satırlar; yaya kalan grup listesi.
3. `YUKLENDI x / y asker` her araç için; `ACIKTA` kalan 0 olmalı; `KAPASITE OGRENILDI` (Kirpi gibi araçlar).
4. `KONVOY YUKLU … plan kapisi bekleniyor` → kapı açılınca tüm araçlar birlikte kalkar; `SURUS` satırları.
5. `TAKILMA 1/2/3` satırları (varsa) ve `INIS TAMAM: n / m asker indi`.
6. Plan tarafı: `[PLAN] … TASIMA -> …` geçişi, `tasimaTamam`.

## Hızlı doğrulama (v8.500 araçları)
1. Her push'ta GitHub Actions `kontrol` iş akışı `tools/hemtt_kontrol.sh` çalıştırır: HEMTT sözdizimi (error = 0), L-S12 uyarısı = 0 ve statik tutarlılık (PREP / olay / ayar / sürüm). Elle: `bash tools/hemtt_kontrol.sh` (HEMTT yoksa indirilir).
2. Oyundan sonra: `python tools/rpt_ozet.py --harekat <rpt>` → faz kaydı / sırası, aynı grup iki planda mı, recon varış, plan kapısı (TAVAN?), nakil yükleme / toplu kalkış / iniş, oyuncu nakli, HQ sayısı, 3DEN nitelik okunuyor mu (OK / KONTROL / YOK).
3. Küçük senaryo önerisi: 1 saldırı Objektif'i (2–3 km), 1 recon grubu (adında `recon`), 3–4 nakil aracı, 2 piyade grubu, oyuncu yaya. `--harekat` çıktısında KONTROL satırı kalmamalı.

## Hakem (uzuv kiralama) — "ses yönlendirmesi" (v8.500)
Sorun: 48 dosya aynı sürücünün `forceSpeed`'ine, 82 dosya `doMove`'a yazıyor (`UYUM_DENETIMI.md`, `tools/uyum_denetimi.py`). RPT'lerde görülen konvoy geçme, durup kalkma ve ping-pong bunlardan.
Çözüm (yeni katman değil, ince bir ilkel): `fnc_uzuvKirala` / `fnc_uzuvBirak` / `fnc_uzuvIzin`. Bir uzva aynı anda tek sahip yazar; öncelik + süre; reddedilen istek `[UYUM] RET` olarak sayılır.
Öncelik tablosu: **90 güvenlik** (ezme freni) › **60 nakil** (yükleme + konvoy) › **40 tank-aralık** (park / dağılma) › **20 mekanize** (hız sıfırlama). Eşit öncelikte yeni gelen reddedilir.
Bağlananlar: `nakilV2` (kira + birak), `ezmeKoruma`, `tankAralik`, `mekanizeIzle`. Sıradakiler (denetim listesinden): `aracSenkron`, `aracUnstuck`, `aracKinSurus`, `komutanPlanDongu` (10 hız yazımı), `planZirh`, `taksi`, `aracMedevac`.
Ölçüt: `rpt_ozet --harekat` → "UYUM (HAKEM) RETLERI" (hata değil; hakemin çalıştığını gösterir). Kapatma yok: kiralama süresi dolunca sahip kendiliğinden düşer.
