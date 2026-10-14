#include "script_component.hpp"
/*
 * Author: Cinar (ELITE fork)
 * CEPHE SIMULASYONU (v8.237, Dilim A0) — sunucu veri yapilarini (bos ise) olusturur. Tekrar cagrilabilir.
 *   lambs_danger_cepheProfiller   HashMap  profil kimligi -> profil (HashMap)           [PROFIL CEKIRDEGI]
 *   lambs_danger_cepheFactionlar  HashMap  faction sinifi -> {taraf, ad, hedef, rezerv, olu, takviyeGelen, merkez}
 *   lambs_danger_cepheTakvAyar    HashMap  taraf (str side) -> Personnel Replacement paneli ayarlari (CBA varsayilanin ustune yazar)
 *   lambs_danger_cepheVaris       HashMap  taraf (str side) -> takviye varis noktasi
 *   lambs_danger_cepheTakvTok     HashMap  taraf -> birikmis takviye hakki (asker)
 *   lambs_danger_cepheOlayAlani   Array    [[poz, yaricap, bitisZamani, tur], ...]  (temas / ates / topcu darbesi: gecici KESIN-fiziksel alan)
 *   lambs_danger_cepheOpAlanlari  Array    [[poz, yaricap, etiket], ...]            (elle tanimli operasyon alani; plan hedefleri ayrica otomatik)
 *
 * Arguments: None
 * Return Value: Sunucu mu <BOOL>
 * Public: No
*/

if (!isServer) exitWith {false};

{
    if (isNil _x) then { missionNamespace setVariable [_x, createHashMap]; };
} forEach ["lambs_danger_cepheProfiller", "lambs_danger_cepheFactionlar", "lambs_danger_cepheTakvAyar", "lambs_danger_cepheVaris", "lambs_danger_cepheTakvTok"];
{
    if (isNil _x) then { missionNamespace setVariable [_x, []]; };
} forEach ["lambs_danger_cepheOlayAlani", "lambs_danger_cepheOpAlanlari"];
if (isNil "lambs_danger_cepheSayac") then { lambs_danger_cepheSayac = 0; };

true
