# arma3lambs

LAMBS Danger FSM 2.6.2 ELITE fork (Cinar) — Global/NATO piyade doktrini yamaları.

Dosyalar orijinal proje yollarıyla aynı yerleşimde; ilgili `.sqf` dosyalarının üzerine kopyalayıp `hemt build` alın.

## İçerik

| Yol | Değişiklik |
|---|---|
| `addons/danger/functions/fnc_commanderAssess.sqf` | **v2 karar mekanizması**: rol ağırlıklı güç oranı (MG 2.0 / nişancı 1.5 / AT 1.4), zırh + AT farkındalığı, düşman MG sayısı, baskı (getSuppression), 6 faktörlü tehdit skoru artık karara dahil, bina savunma avantajı, bilinen düşman (knowsAbout). Cephane hesabı düzeltildi (`magazinesAmmo`) |
| `addons/danger/functions/fnc_tacticsBounding.sqf` | **Ölümcül overwatch**: cycle 1'de FSE'nin tamamı OVERWATCH pozisyonuna oturur (beklenir), ateş üstünlüğü kapısı (odak düşman baskı ≥0.25 olmadan koşucu kalkmaz), sektör yelpazesi (−12/0/+12°), MG sürekli ateş, AT zırha roket, EVADE_ARMOR kararında bounding bırakılır. Eski: **v3 ölümcül + gözle görülür**: ATEŞ → HAREKET (varışa kadar) → ORTAK ATEŞ fazları, sprint + varışta siper stance, odak ateş (aynı düşmana doTarget/doFire), her 3. cycle FSE sıçraması (leapfrog), combatMode RED, jest + callout. Eski: Cycle başı komutan kontrolü (ağır kayıpta Retreat), temizlik/token. **Buddy team**: en güçlü + en zayıf eşleşir, MG koşmaz, siper yoksa 20 m sınırlı atılım (eskiden doğrudan düşmana koşuyordu), tek kalan bounder ilerler, MG/nişancı OVERWATCH atış pozisyonu, taktik sis |
| `addons/danger/functions/fnc_tacticsRetreat.sqf` | **v13**: iki takım (ALPHA / BRAVO=FSE) 40 m'lik dönüşümlü sıçramalarla çekilir; hareket etmeyen takım ateş eder (kimse boş durmaz); hareket edenlerde `forceMove` + AUTOCOMBAT/COVER/TARGET kapalı + `allowFleeing 0` (rastgele koşma yok); 2'li çiftler halinde. Eski: 45 sn cooldown, `splitFireTeams` ile gerçek FSE, combatMode korunur, suya düşmeyen rally, güvenli valf |
| `addons/danger/functions/fnc_tactics.sqf` | Debug kapalıyken log yok |
| `addons/danger/functions/fnc_splitFireTeams.sqf` | **Rol bazlı dağıtım**: FSE = MG → nişancı → AT; Maneuver = lider + tüfekliler; Reserve = sağlıkçı + artanlar |
| `addons/danger/functions/fnc_eliteCover.sqf` | Sıkı cover testi (4 m önünde engel), yaklaşma cezası, nil-güvenli global |
| `addons/danger/functions/fnc_orphanWatchdog.sqf` | Temas / taze komutan kararında dokunmaz |
| `addons/danger/functions/fnc_selectFormation.sqf` | Retreat FILE kilidi, mükerrer blok silindi |
| `addons/main/functions/fnc_findCover.sqf` | **v4**: FIRE-geometri ile MERMİ KORUNMASI (çalı gizler ama korumaz → −20), omuz testi, EVADE modu (sadece sert siper, bina +12). Eski v3: | **v3 puanlamalı siper**: koruma seviyesi, yan açılardan (±25°) ve diğer bilinen düşmanlardan gizlilik, arazi gizlemesi, mesafe/yaklaşma cezası, yumuşak obje (çalı) cezası, askerler arası rezerv (aynı ağaca yığılma yok). Modlar: DEFEND / ADVANCE / OVERWATCH |
| `addons/main/functions/UnitAction/fnc_doCover.sqf` | Düşmana göre gerçek cover (findCover + 2 sn önbellek) |
| `addons/danger/functions/fnc_tacticsPeel.sqf` | Artık sadece `tacticsRetreat`'i çağırır (eski Peel askerleri `PATH/MOVE` kilidiyle dondurabiliyordu; Zeus test komutu doğrudan Peel'e gidiyordu) |
| `addons/danger/functions/fnc_tacticsATEngage.sqf` | **YENİ** — AT zırha taarruz + PİYADE KORUMASI: AT korunaklı atış pozisyonuna gider (zırhtan ≥60 m), her AT'ye 2 eskort piyade AT'nin yanına (düşman piyade yönünde) gider ve düşman piyadeyi bastırır (baskı + nişan + UGL); kalan piyade yerinde bastırır. Karar: `AT_ENGAGE` (kendi AT'si var, zırh 70-400 m) |
| `addons/danger/functions/fnc_tacticalUGL.sqf` | **YENİ** — UGL boost: düşman piyadeye 40-320 m, hat kapalı / binada / küme / %50, 5 sn cooldown; atış LAMBS `doUGL` ile. Bounding ateş ekibi ve AT eskortu kullanır |
| `addons/danger/functions/fnc_tacticsEvadeArmor.sqf` | **YENİ** — AT'si olmayan grup tank/APC'den kaçar: 2'li çiftler `findCover EVADE` ile SERT siperlere (bina/duvar, mermi durduran) sprint eder, zırha ateş açmaz (combatMode GREEN), DOWN saklanır 20 sn, sis perdesi. Karar: `commanderAssess` → `EVADE_ARMOR` (en yüksek öncelik) |
| `addons/danger/functions/fnc_buddyPairs.sqf` | **YENİ** — 2'li buddy çiftleri (en güçlü + en zayıf, tek kalan üçlüye eklenir). Bounding ve Retreat aynı eşleştirmeyi kullanır |
| `addons/danger/functions/fnc_getUnitRole.sqf` | **YENİ** — rol tespiti (MG / AT / MARKSMAN / MEDIC / RIFLE). MG şarjör kapasitesiyle (≥75) bulunur; eski `CfgWeapons >> type in [4,5]` kontrolü hiç eşleşmiyordu |
| `addons/danger/functions/fnc_tacticalSmoke.sqf` | **YENİ** — taktik sis: COVER_MOVE (düşmana doğru, hareketin önüne) / BREAK_CONTACT (geri çekilme perdesi, 2 atıcı), rüzgâr telafisi, 45 sn cooldown, sadece beyaz sis. Bounding, Retreat ve DELAY'de kullanılır |
| `addons/danger/XEH_PREP.hpp` | `getUnitRole` ve `tacticalSmoke` kaydı eklendi |

Not: `ELITE_COVER_RANGE` (main/script_component.hpp) 60 m — 30 m önerilir.
