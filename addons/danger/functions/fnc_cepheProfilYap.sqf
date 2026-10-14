#include "script_component.hpp"
/*
 * Author: Cinar (ELITE fork)
 * CEPHE PROFIL YAP (v8.237, Dilim A0) — PROFIL CEKIRDEGI: bir squad'i SANAL (L0) veri kaydi olarak olusturur ve kayda ekler.
 * Profil = tek dogruluk kaynagi; fiziksel nesneler (grup / askerler) profilin "cismi"dir (fnc_cepheFizikle / fnc_cepheSanalla).
 * Anahtarlar:
 *   id, ad, taraf (side), faction, tur ("SQUAD" | "TAKVIYE"), seviye ("L0" sanal | "L1" fiziksel), konum (ATL), yon, hedef ([] | poz), hizMs (sanal yurume hizi, 0 = varsayilan),
 *   uyeler [ {sinif, canli, loadout, hasar, ace, su, ac} ... ], birimler [obje ...] (uyeler ile ayni sira; yalniz L1'de dolu), grup,
 *   hedefBoy (tam kadro), beceri (-1 = oyun varsayilani), bitkin (havuz bitti cezasi), kilit (elle: komutan / sanal sistem dokunmaz),
 *   tFizik (son fiziksellesme zamani), tSon (son tetik zamani), tier (0..3), yok (tum uyeler oldu), formasyon / davranis / savasModu / hizModu (despawn'da saklanir),
 *   takvAktif / talepT / havuzIslendi (Personnel Replacement durumu), hedefId (TAKVIYE: gidecegi squad profili)
 * Zeus'la ELLE konan birimler profile GIRMEZ (kullanici karari: elle konan fiziksel kalir).
 *
 * Arguments:
 * 0: Faction sinifi <STRING>
 * 1: Taraf <SIDE>
 * 2: Uye sinif listesi <ARRAY of STRING>
 * 3: Konum <ARRAY>
 * 4: Tur ("SQUAD" | "TAKVIYE") <STRING> (default: "SQUAD")
 * 5: Ek anahtarlar [[anahtar, deger], ...] <ARRAY> (default: [])
 *
 * Return Value: Profil <HASHMAP> (sunucu degilse bos HashMap)
 * Public: No
*/

params [["_f", "", [""]], ["_taraf", west, [west]], ["_sinifler", [], [[]]], ["_konum", [0, 0, 0], [[]]], ["_tur", "SQUAD", [""]], ["_ek", [], [[]]]];

if (!isServer) exitWith { createHashMap };
call FUNC(cepheInit);

lambs_danger_cepheSayac = lambs_danger_cepheSayac + 1;
private _id = format ["%1_%2", _f, lambs_danger_cepheSayac];
private _fAd = getText (configFile >> "CfgFactionClasses" >> _f >> "displayName");
if (_fAd isEqualTo "") then { _fAd = _f; };
private _kons = +_konum;
_kons resize 3;
if (isNil {_kons select 2}) then { _kons set [2, 0]; };

private _p = createHashMapFromArray [
    ["id", _id],
    ["ad", format ["%1 #%2", _fAd select [0, 16], lambs_danger_cepheSayac]],
    ["taraf", _taraf],
    ["faction", _f],
    ["tur", _tur],
    ["seviye", "L0"],
    ["konum", _kons],
    ["yon", random 360],
    ["hedef", []],
    ["hizMs", 0],
    ["uyeler", _sinifler apply { createHashMapFromArray [["sinif", _x], ["canli", true], ["loadout", []], ["hasar", []]] }],
    ["birimler", []],
    ["grup", grpNull],
    ["hedefBoy", count _sinifler],
    ["beceri", -1],
    ["bitkin", false],
    ["kilit", false],
    ["tFizik", 0],
    ["tSon", 0],
    ["tier", 0],
    ["yok", false],
    ["olusma", time]
];
{ _p set [_x select 0, _x select 1]; } forEach _ek;
lambs_danger_cepheProfiller set [_id, _p];
_p
