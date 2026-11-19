# TEST PROTOKOLU (v8.684) — oyunda doğrulama turu

Amaç: v8.656+ değişikliklerinin hiçbiri oyunda doğrulanmadı. Bu protokol, **5 kısa senaryo + tek komutla okunan karne** ile hangisinin çalıştığını, hangisinin hâlâ kanıtsız olduğunu gösterir.
Puan iddiası ancak bu karne temizse savunulabilir (puan benim tahminimdir; karne ölçümdür).

## Karne

```bash
python tools/rpt_ozet.py --kabul Arma3_x64_....rpt        # tek RPT
python tools/rpt_ozet.py --kabul a.rpt b.rpt c.rpt        # her senaryo ayrı RPT
```

Her madde: **GECTI** (kanıt var) · **KALDI** (kanıt kötü: düzeltilecek) · **KONTROL** (sınırda / yorum gerekir) · **VERI YOK** (senaryo o özelliği tetiklemedi) · **BILGI** (karar için ölçüm).
`VERI YOK` bir başarı değildir; ilgili senaryoyu çalıştırıp tekrar bakılır.

## Ortak ayarlar (hepsi varsayılan; kontrol et)

CBA: `perfOlcum` açık · `fovOlcum` açık · `temasSonrasiAware` açık · `avantajBagla` açık · duruş disiplini açık. Durum logu varsayılan açık (`lambs_danger_durumLogOff` ayarlanmamış olmalı).
Her senaryodan sonra oyunu kapat (RPT yazılsın). Her senaryo için ayrı RPT, 4–6 dakika temas yeterli.

## Senaryolar

| # | Senaryo | Kurulum | Tetiklenmesi beklenen | Karnede bakılacak |
|---|---|---|---|---|
| A | **Orman 8 vs 8** (yaptığın test) | 2 grup × 8, orman, 30–120 m | komutan kararları, TCCC, durus disiplini, UGL | DUSUNME HIZI · KOMUTAN KARARLILIGI · EMIR GIDIP-GELME · TCCC BEKLEME · DURUS DISIPLINI · UGL SIKLIGI |
| B | **Retreat zorlama** | senin tarafın 4 kişi vs 10–12 düşman, açık arazi, 150–250 m; yakında çukur / yamaç / ev olsun | kayıp ≥ %40 → geri çekilme | RETREAT VARIS (≥ %50 varış) · `[GERI-CEKILME-KORUMA]` · `[DOFOLLOW-ATLA]` · AVANTAJLI YER · KOMUTAN KARARLILIGI (WITHDRAW/DELAY) |
| C | **Köy savunması / HOLD** | 6–8 kişilik grup ev kümesi (≥ 3 bina) yakınında, düşman 80–200 m'den yaklaşır; temas bittikten sonra 90 sn bekle | HOLD/DELAY → savunma yerleşimi, temas sonrası gevşeme | SAVUNMA YERLESIM · AVANTAJLI YER · TEMAS SONRASI GEVSEME · COMBAT'TA KALMA |
| D | **Algı / FOV (açık arazi)** | seyrek ağaçlı açık arazi: A grubu B ile 100–200 m karşılıklı çatışsın; **C grubu yandan / arkadan** 60–150 m'ye yaklaşsın; ≥ 3 dk temas | `[FOV-OLCUM]` (≥ 20 hattı açık çift; ormanda hat kapalı olduğundan veri çıkmaz) | ALGI KAYNAGI (FOV) · camouflageCoef ≤ 0.05 · YAKIN ALGI KATMANI |
| E | **Sniper takımı** | nişancı + gözlemci çifti, düşman 300–500 m | sniper gözlemci takibi | SNIPER GOZLEMCI · MG HAKIM NOKTA (MG'li grup varsa) |

İsteğe bağlı (F): **Altis çukur / yamaç** — açık arazide düşman 80–150 m; `ACIK-SIPER ... ARAZI KIVRIMI` ve `SIPER-ANALIZ` satırlarına bak.

## Ne neyi kanıtlar (sürüm → satır)

| Değişiklik | Kanıt satırı / karne maddesi |
|---|---|
| v8.668 durus disiplini | `[DURUS-DISIPLIN-OZET]` |
| v8.669 MG hakim nokta / kanat baskısı / sektör planı | `[MG-HAKIM]`, `[KANAT-BASKI]`, `[SEKTOR-PLAN]` |
| v8.670 temas sonrası gevşeme | `[TEMAS-SONRASI]` (sessizlik ≥ 75 sn) |
| v8.674–677 avantajlı yer / savunma / yakın temas yerleşimi | `[AVANTAJLI-YER]`, `[SAVUNMA-YER]` |
| v8.680–681 retreat emir koruması | `[GERI-CEKILME-KORUMA]`, `[DOFOLLOW-ATLA]`, `[GERI-CEKILME-EZME-TANI]`; RETREAT VARIS |
| v8.682 komutan kararlılığı (kayıp kilidi + 30 sn savunma taahhüdü) | KOMUTAN KARARLILIGI (savunma → hücum ≥ 25 sn) |
| v8.683 baygın düşman TCCC'yi kilitlemez | TCCC BEKLEME (en uzun bekleme ≤ 90 sn) |
| v8.684 emir gidip-gelme ölçümü | `[EMIR-GIDIP-GELME]`, `[EMIR-TERS-DONUS]` (imza: fm, tk, atis, baski, k:KARAR, g:GOREV, mesafe) |
| v8.684 algı kaynağı ölçümü | `[FOV-OLCUM]` (mesafe × açı + arka yarı kaynağı: ses / grup / yakın / açıklanamayan) |

## "7.5 iddiası" ölçütü (benim kullandığım)

1. Karne: **KALDI yok**; her KONTROL için yazılı açıklama.
2. A–E senaryolarının hepsi çalıştı; kritik maddelerde `VERI YOK` kalmadı (RETREAT VARIS, KOMUTAN KARARLILIGI, TCCC BEKLEME, EMIR GIDIP-GELME, ALGI KAYNAGI).
3. FOV sorusu **ölçümle** cevaplandı (aşağıdaki yorum tablosu); davranış kararı (FOV uygulansın mı) senindir.

### FOV / algı yorum tablosu

| Ölçüm | Anlamı |
|---|---|
| Arka yarı algısı **yakın** kovada ~%90+, 60–250 m'de düşük | neden: yakın mesafede azaltıcı katmanların kapanması (`yakinAlgiM`) → senin hipotezin doğru; çözüm: yakınAlgiM'i küçült ya da arka yarıda kapatma |
| Arka yarı algısı **her mesafede** ~%80+ ve "açıklanamayan" ağırlıklı | motor / 360° algı; mod katmanı değil |
| "grup" ağırlıklı | grup içi bilgi paylaşımı (arkadaşı gören hepsini bilir); gerçekçilik için paylaşım gecikmesi düşünülebilir |
| "ses" ağırlıklı | ateş sesi (gerçekçi); sorun değil |
