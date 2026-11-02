# Bilgi eşikleri — TEK TABLO (v8.366)

`knowsAbout` (Arma ölçeği 0–4) ile "düşmanı biliyor" ifadesinin sayısal tanımı artık **tek yerde**: `fnc_bilgiEsik` (CBA: *LAMBS Danger → ELITE bilgi eşikleri*). Kodda `knowsAbout` bir sayıyla doğrudan karşılaştırılamaz; `tools/tutarlilik_denetimi.py` `[BILGI-ESIK]` ile yakalar. Eşikler **monoton** tutulur (bir aşama öncekinden küçük olamaz).

## Seçim kuralı: eşik, kararın SONUCUNUN MALİYETİNE göre seçilir

| Aşama | Değer | Anlamı | Karar tipi (hata maliyeti) |
|---|---|---|---|
| ISARET | 0.15 | iz: yeni ateşle vurulmuş / havada silahlı araç asılı | ucuz + geri alınabilir, ama tehdit AĞIR: en ufak ize tepki |
| SEZILDI | 0.30 | bir şey sezildi (ses, kısa görüş, paylaşılan ipucu) | ucuz, geri alınabilir: bakma/dönme, uyarı, ateş üstünlüğü eğilimi, tank-dron uyarısı, kaba düşman merkezi |
| SUPHE | 0.50 | muhtemel düşman, yer kabaca biliniyor | yerel taktik seçim, düşük maliyet: bastırma hedefi, sis, bina penceresi, bounding odağı, roket tepkisi |
| TESPIT | 0.80 | düşman tespit edildi ve konumlandı | grup/plan düzeyi karar, maliyetli ama geri alınabilir: düşman sayımı, köşe temkini, zırhlı hedefe patlayıcı, esir kararı, keskin nişancı hedefi |
| KESIN | 1.20 | düşman teşhis edildi ve izleniyor | GERİ ALINAMAZ / dosta zarar riski / pahalı varlık: dolaylı ateş gözlemi ve karşı-batarya, pusu tetiği, AT / zırh kararları, HQ istihbarat paylaşımı |
| TAM | 2.00 | düşman bizi de TAM biliyor | keskin nişancı karşı-tedbir |

Kaynak etiketi: **[T]** tasarım (kaynak setinde Arma'ya özgü `knowsAbout` yok). Mantık "geri alınamaz karar daha güvenilir istihbarat ister" kavramı **[K~]** (TC 3-21.76 / MCWP 3-11.1'deki karar-kanıt ilişkisi); sayılar tasarımdır.

## Eski → yeni (her kullanım)

Toplam **70** eşik: 43 aynı, 15 daha SIKI (yeni > eski), 12 daha GEVŞEK (yeni < eski). Δ = yeni − eski.

| Dosya:satır | Eski | Aşama | Yeni | Δ |
|---|---|---|---|---|
| aracTasima:394 | 0.3 | SEZILDI | 0.30 | 0 |
| aracTasima:799 | 0.2 | SEZILDI | 0.30 | +0.10 |
| aracZirhKac:45 | 0.3 | SEZILDI | 0.30 | 0 |
| atesHareket:117 | 0.6 | SUPHE | 0.50 | -0.10 |
| atisUstunlugu:63 | 0.35 | SEZILDI | 0.30 | -0.05 |
| binaPencere:73 | 0.5 | SUPHE | 0.50 | 0 |
| commanderAssess:100 | 1.2 | KESIN | 1.20 | 0 |
| commanderAssess:100 | 0.4 | SUPHE | 0.50 | +0.10 |
| commanderAssess:166 | 1.2 | KESIN | 1.20 | 0 |
| commanderFormation:89 | 0.3 | SEZILDI | 0.30 | 0 |
| cqbReflex:68 | 1 | TESPIT | 0.80 | -0.20 |
| cqbReflex:144 | 1 | TESPIT | 0.80 | -0.20 |
| dronTopcu:97 | 1.2 | KESIN | 1.20 | 0 |
| fireSupport:73 | 0.5 | SUPHE | 0.50 | 0 |
| havaFarkindalik:156 | 0.15 | ISARET | 0.15 | 0 |
| havaFarkindalik:156 | 0.4 | SUPHE | 0.50 | +0.10 |
| hqIstihbarat:79 | 1.2 | KESIN | 1.20 | 0 |
| hqIstihbarat:111 | 0.8 | TESPIT | 0.80 | 0 |
| ihaBekle:63 | 0.4 | SUPHE | 0.50 | +0.10 |
| ihaSorti:185 | 0.3 | SEZILDI | 0.30 | 0 |
| ihaSorti:185 | 0.4 | SUPHE | 0.50 | +0.10 |
| komutanPlanDongu:61 | 0.8 | TESPIT | 0.80 | 0 |
| komutanPlanDongu:114 | 0.5 | SUPHE | 0.50 | 0 |
| komutanPlanDongu:364 | 0.3 | SEZILDI | 0.30 | 0 |
| komutanPlanDongu:868 | 0.3 | SEZILDI | 0.30 | 0 |
| komutanPlanDongu:1202 | 0.3 | SEZILDI | 0.30 | 0 |
| komutanPlanDongu:1455 | 0.8 | TESPIT | 0.80 | 0 |
| komutanPlanDongu:1581 | 0.4 | SUPHE | 0.50 | +0.10 |
| komutanPlanKapi:403 | 0.5 | SUPHE | 0.50 | 0 |
| komutanZihin:145 | 0.5 | SUPHE | 0.50 | 0 |
| koseTemkin:120 | 1 | TESPIT | 0.80 | -0.20 |
| koseTemkin:218 | 0.3 | SEZILDI | 0.30 | 0 |
| koseTemkin:252 | 1 | TESPIT | 0.80 | -0.20 |
| motorSes:82 | 0.5 | SUPHE | 0.50 | 0 |
| panikFelc:129 | 0.4 | SUPHE | 0.50 | +0.10 |
| patlayici:218 | 0.6 | SUPHE | 0.50 | -0.10 |
| patlayici:231 | 0.8 | TESPIT | 0.80 | 0 |
| planZirh:218 | 0.3 | SEZILDI | 0.30 | 0 |
| planZirh:302 | 0.3 | SEZILDI | 0.30 | 0 |
| planZirh:450 | 0.5 | SUPHE | 0.50 | 0 |
| planZirh:478 | 0.5 | SUPHE | 0.50 | 0 |
| planZirh:574 | 0.5 | SUPHE | 0.50 | 0 |
| planZirh:574 | 0.3 | SEZILDI | 0.30 | 0 |
| pusu:67 | 1.2 | KESIN | 1.20 | 0 |
| pusu:210 | 0.4 | SUPHE | 0.50 | +0.10 |
| pusuTepki:58 | 1 | TESPIT | 0.80 | -0.20 |
| roleStation:362 | 0.4 | SUPHE | 0.50 | +0.10 |
| roleStation:379 | 1 | TESPIT | 0.80 | -0.20 |
| rpgReaction:51 | 0.5 | SUPHE | 0.50 | 0 |
| sniperTeam:285 | 2 | TAM | 2.00 | 0 |
| sniperTeam:343 | 1 | TESPIT | 0.80 | -0.20 |
| soundAwareness:122 | 1.5 | KESIN | 1.20 | -0.30 |
| tacticsATEngage:60 | 1.2 | KESIN | 1.20 | 0 |
| tacticsATEngage:132 | 0.5 | SUPHE | 0.50 | 0 |
| tacticsATEngage:306 | 1 | KESIN | 1.20 | +0.20 |
| tacticsBounding:341 | 0.5 | SUPHE | 0.50 | 0 |
| tacticsBounding:388 | 0.5 | SUPHE | 0.50 | 0 |
| tacticsBounding:401 | 1 | TESPIT | 0.80 | -0.20 |
| tacticsBounding:401 | 0.5 | SUPHE | 0.50 | 0 |
| tacticsEvadeArmor:67 | 1.2 | KESIN | 1.20 | 0 |
| tacticsHide:62 | 1.2 | KESIN | 1.20 | 0 |
| tankAtesKontrol:56 | 0.3 | SEZILDI | 0.30 | 0 |
| tankBakis:39 | 0.4 | SUPHE | 0.50 | +0.10 |
| tankDron:34 | 0.2 | SEZILDI | 0.30 | +0.10 |
| tankDron:34 | 0.2 | SEZILDI | 0.30 | +0.10 |
| tankDuello:38 | 0.5 | SUPHE | 0.50 | 0 |
| tankMuhimmat:227 | 0.3 | SEZILDI | 0.30 | 0 |
| teslimBirey:84 | 0.8 | TESPIT | 0.80 | 0 |
| topcuDestek:88 | 1 | KESIN | 1.20 | +0.20 |
| topcuGoru:24 | 1 | KESIN | 1.20 | +0.20 |

## Davranış değişimi (oyunda DENENMEDİ)

**Daha sıkı (düşman daha geç/kesin sayılır):** aracTasima +0.10, commanderAssess +0.10, havaFarkindalik +0.10, ihaBekle +0.10, ihaSorti +0.10, komutanPlanDongu +0.10, panikFelc +0.10, pusu +0.10, roleStation +0.10, tacticsATEngage +0.20, tankBakis +0.10, tankDron +0.10, topcuDestek +0.20, topcuGoru +0.20.

**Daha gevşek (daha erken tepki):** atesHareket -0.10, atisUstunlugu -0.05, cqbReflex -0.20, koseTemkin -0.20, patlayici -0.10, pusuTepki -0.20, roleStation -0.20, sniperTeam -0.20, soundAwareness -0.30, tacticsBounding -0.20.

En kritik üç kayma: **dolaylı ateş gözlemi 1.0 → 1.2** (`topcuGoru`, `topcuDestek` karşı-batarya: topçu biraz daha geç atar, kasıtlı), **FPV/İHA başlatma 0.4 → 0.5** (`ihaBekle`, `ihaSorti` grup bilgisi), **köşe temkini / CQB / pusu tepkisi / keskin nişancı hedefi 1.0 → 0.8** (yakın temasta daha erken tepki). Ayrıca **ses farkındalığı 1.5 → 1.2** (`soundAwareness`: "zaten iyi biliyor" sayıp ses bilgisi eklemeyi biraz daha erken bırakır).

## Dokunulmayanlar (eşik değil)
- `reveal` seviyeleri (0.4–4: `sniperTeam`, `soundAwareness`, `motorSes`, `rpgReaction`, `fireSupport`, `havaFarkindalik`…) bir BİLGİ VERME düzeyidir, karşılaştırma eşiği değil; ayrı konu.
- `lambs_main_maxRevealValue` (1.5, üst LAMBS ayarı): `hqIstihbarat` paylaşım tavanı.
- `nearTargets` / `targets` içindeki doğruluk (`_x select 5`) alanları knowsAbout değildir.
- Eski gizli değişken `lambs_danger_havaBilgiEsik` kaldırıldı (artık SUPHE/ISARET).

## Ayar
CBA → LAMBS Danger → **ELITE bilgi eşikleri** (6 kaydırıcı). Tüm sistemleri tek yerden sertleştirmek/gevşetmek için: örn. KESIN'i 1.5 yapmak dolaylı ateş + pusu + AT kararlarını birlikte katılaştırır. Değişiklik ≤ 2 sn içinde geçerli.
