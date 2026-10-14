#include "script_component.hpp"
/*
 * Author: Cinar (ELITE fork)
 * CEPHE LOGU (v8.237) — tek bicim: [CEPHE-<ETIKET>] t+<sn> | <metin>.  t+ = cephe sisteminin ilk logundan beri gecen saniye
 * (kisa testte zaman cizelgesi ilk bakista okunsun diye; [PLAN-ZAMAN] ile ayni mantik).
 * Etiketler: CEPHE-FACTION CEPHE-FIZIKLE CEPHE-SANALLA CEPHE-TAKVIYE CEPHE-KONVOY CEPHE-SOYUT CEPHE-OZET CEPHE-YOK CEPHE-AYAR CEPHE-HATA
 *
 * Arguments:
 * 0: Etiket (CEPHE- olmadan) <STRING>
 * 1: Metin <STRING>
 *
 * Return Value: None
 * Public: No
*/

params [["_etiket", "?", [""]], ["_metin", "", [""]]];

if (isNil "lambs_danger_cepheT0") then { lambs_danger_cepheT0 = time; };
diag_log format ["[CEPHE-%1] t+%2 | %3", _etiket, round (time - lambs_danger_cepheT0), _metin];
