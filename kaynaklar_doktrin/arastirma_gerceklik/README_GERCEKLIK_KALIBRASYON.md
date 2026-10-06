# Gerçeklik kalibrasyonu — özet (v8.90)

**UYARI (kaynak sınırı):** Araştırma ajanlarının `WebFetch` erişimi çoğu siteye (DTIC, Wikipedia, ACE / BI wiki, Steam) engelliydi; sayıların çoğu **WebSearch özetlerinden** geldi → güven orta/düşük. Birincil kaynakta doğrulanmadan kesin sayı olarak kullanma.
Yalnızca GitHub ham kodu (ACE3 kaynağı) doğrudan okundu (güven yüksek). Ayrıntı ve URL'ler 1-4 numaralı dosyalarda. "TAHMİN (kaynaksız)" etiketli satırlar araştırmacıların yargısıdır.

## Kullanıcı senaryosu (Zeus sandbox)
Açık arazi, 200-300 m, IS (AK, RPG, optik YOK, ~20-23 kişi, 3 grup) vs USMC/ABD (~28+ kişi, ACOG'lu M4 / M27, M203, Stryker .50 / MK19).

## Gerçek veriden çıkan hedef aralıklar
| Konu | Bulgu | Kaynak dosya | Güven |
|---|---|---|---|
| Çatışma mesafesi | WW2/Kore: %70 < 91 m, %90 < 275 m; Irak ort. < 100 m (çoğu 20-30 m); Afganistan'da angajmanların ~%50'si > 300 m | 1 | düşük-orta |
| Optik farkı | 200 m: açık ~%71 / optik >%90; 300 m: ~%55 / ~%87; USMC ilk atış 137-432 m: M16A2 açık %45 / ACOG %88 | 1 | orta |
| Baskı | .50 cal altında nişan süresi ~%57 düşer; isabet yüzdesi düşüşü bulunamadı | 1 | düşük |
| RPG-7 hareketli hedef | 100 m %96, 200 m %51, 300 m %22, 400 m %9 | 3 | orta |
| Stryker slat | RPG'ye ~%50-70, tandem / RPG-29'a zayıf | 3 | orta-düşük |
| KIA/WIA | Irak 0.14, Afg. 0.12 (yaralıların ~%86-88'i hayatta); ölenlerin ~%90'ı tesise ulaşmadan | 3 | orta |
| Büyük ölçek kayıp oranı | Fallujah II ~12-35 isyancı ölü / 1 ABD ölü (şehir, hava/topçu destekli, şişirilmiş olabilir); Wanat ~2.3:1 | 2 | düşük |
| Küçük birim açık arazi USMC vs DAESH | yayımlanmış veri YOK; kaynaksız tahmin ~5:1-15:1 (ölü), IS %20-30 kayıpta kopar | 2 | tahmin |
| Kırılma noktası | WW2 taburları ort. ~%40 kayıp, aralık %1-100; sabit yüzde yok | 2 | orta |

## Arma / ACE bulguları (4)
- **AI optikten isabet kazanmaz** (düşük güvenli ikinci el kaynak): oyunda IS'nin 'optiksiz' olması hiçbir etki yapmıyordu → v8.90: optiksiz birimin `aimingAccuracy` x0.75.
- ACE yüklüyken düşük `aimingAccuracy` isabeti beklenenden az düşürür (ACE3 issue #6948: 300 m'de skill 0.1 → vanilla %3.5, ACE %35.5). Etki sınırlı olabilir; ölçerek ayarla.
- ACE yaralı AI'nın nişanını bozmaz (issue #7391 'not planned'); bayılan AI ateşi bırakır.
- ACE eşikleri: oyuncu / AI ayrımı var, **taraf ayrımı yok**. ACE resmi co-op önerisi: `fatalDamageSource=1`, `AIDamageThreshold=0.2`, `playerDamageThreshold=3.5`, `bleedingCoefficient=0.25`, `AIUnconsciousness=true`, `cardiacArrestTime=630`. (BU DEĞERLER SİZİN ACE AYARLARINIZDIR; ben değiştirmedim.)
- LAMBS beceri değerine dokunmaz; ZEN 'Global AI Skill' taraf ayırmaz.

## v8.90'da koda alınan (kanıta dayalı)
1. Optiksiz birim: `aimingAccuracy` x0.75 (kapatma `lambs_danger_optikSkillOff`).
2. `rpt_ozet` kayıp tablosu: taraf başına ölü + bayılan (bkz. `--kayip`).

## Kalibrasyon DENENMEDİ / yapılacak
- Oyunda ölçülen kayıp oranı (taraf başına ölü + bayılan) ile bu tablonun karşılaştırılması: aynı teçhizat / aynı sayı simetrik testleri + açık arazi 200-300 m senaryosu, birkaç tekrar.
- ACE hasar eşikleri ve AI beceri tabanı (ASR sınıfları: düzenli ordu ~0.20+0.1, milis ~0.15+0.1 — kaynak ASR_AI3 koduna göre) kullanıcı ayarıdır; önerileri 4 numaralı dosyada.
