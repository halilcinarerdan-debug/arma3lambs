# arma3lambs

LAMBS Danger FSM 2.6.2 ELITE fork (Cinar) — Global/NATO piyade doktrini yamaları.

Dosyalar orijinal proje yollarıyla aynı yerleşimde; ilgili `.sqf` dosyalarının üzerine kopyalayıp `hemt build` alın.

## İçerik

| Yol | Değişiklik |
|---|---|
| `addons/danger/functions/fnc_commanderAssess.sqf` | Cephane hesabı düzeltildi (`magazinesAmmo`); eski hali ateş açınca hep HOLD veriyordu |
| `addons/danger/functions/fnc_tacticsBounding.sqf` | Cycle başı komutan kontrolü (ağır kayıpta Retreat), `enableAttack`/`allowGetIn`/`doWatch` geri verilir, token ile güvenli temizlik |
| `addons/danger/functions/fnc_tacticsRetreat.sqf` | 45 sn cooldown, `splitFireTeams` ile gerçek FSE, combatMode korunur, suya düşmeyen rally, güvenli valf |
| `addons/danger/functions/fnc_tactics.sqf` | Debug kapalıyken log yok |
| `addons/danger/functions/fnc_splitFireTeams.sqf` | FSE ağır silah yoksa normallerle tamamlanır |
| `addons/danger/functions/fnc_eliteCover.sqf` | Sıkı cover testi (4 m önünde engel), yaklaşma cezası, nil-güvenli global |
| `addons/danger/functions/fnc_orphanWatchdog.sqf` | Temas / taze komutan kararında dokunmaz |
| `addons/danger/functions/fnc_selectFormation.sqf` | Retreat FILE kilidi, mükerrer blok silindi |
| `addons/main/functions/fnc_findCover.sqf` | Objenin düşmana göre arka tarafı, en yüksek gizli stance, mürettebatlı araç elenir |
| `addons/main/functions/UnitAction/fnc_doCover.sqf` | Düşmana göre gerçek cover (findCover + 2 sn önbellek) |

Not: `ELITE_COVER_RANGE` (main/script_component.hpp) 60 m — 30 m önerilir.
