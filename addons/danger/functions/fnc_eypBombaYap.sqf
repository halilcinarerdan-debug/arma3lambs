#include "script_component.hpp"
/*
 * Author: Cinar (ELITE fork)
 * BIRIMI / ARACI CANLI BOMBA YAP (editor init satiri + 3DEN / Zeus modulleri ortak) (v8.777; kullanici: 'zeus destegi ve editor destegi olsun'; referans: aral_canl_bomba.txt VBIED + canl_bomba.txt PBIED).
 * Isaretlenen asker (PBIED) ya da arac (VBIED; surucu kosucudur) ayarlanan menzilde dusman bulunca fnc_eypKos ile hedefe gider (CBA canliBomba KAPALI olsa bile calisir; CBA yalniz OLAY-tabanli otomatik secimi yonetir).
 * Dongu 1 sn'de bir dusman arar (tespit menzili); hedefe varamazsa (zaman asimi / hedef yok) 5 sn bekler, 3 basarisiz denemeden sonra birakir; patlayinca / olunce biter.
 * AYAR dizisi (hepsi istege bagli): [menzil m (400), tarz 0 catisarak / 1 gizli / 2 AGRESIF (2; v8.785 varsayilan), son an mesafesi m (-1 = CBA), patlama gucu 0-2 (-1 = CBA), olunce patlama sansi 0-1 (-1 = CBA), hedef taraf 0 otomatik / 1 BLUFOR / 2 OPFOR / 3 INDEP (0), arac ustu gorsel varil 0/1 (1), patlama (tetik) mesafesi m (-1 = CBA canliBombaTetikM)]
 *   tarz 2 (varsayilan) -> AGRESIF: durmadan sprint, hedef alma kapali (CARELESS). tarz 1 (gizli) -> referans PBIED / VBIED: CARELESS + BLUE (ates etmez), yuruyus (arac 45 km/s), son an mesafesinde sprint / tam gaz. gizli = 0 -> catisarak (zikzak + ates; bkz. fnc_eypKos).
 * Uzak yerellik: birim bu makinede yerel degilse olay (lambs_danger_eypBombaYerel) ile sahibine gonderilir.
 *
 * EDITOR INIT SATIRI (birim ya da arac init kutusu; Eden / Zeus modulleri gerekmez):
 *   [this] call lambs_danger_fnc_eypBombaYap;                                     // varsayilanlar (catisarak)
 *   [this, [600, 1, 45, 2, 0.5, 1]] call lambs_danger_fnc_eypBombaYap;            // gizli yaklasim, 600 m tespit, son 45 m sprint, referans guc, BLUFOR hedef
 *
 * Arguments:
 * 0: Asker ya da arac <OBJECT>
 * 1: Ayar dizisi <ARRAY> (varsayilan [])
 *
 * Return Value: Baslatildi mi <BOOL>
 *
 * Public: Yes
*/

params [["_obj", objNull, [objNull]], ["_a", [], [[]]]];
if (isNull _obj || {!alive _obj}) exitWith {false};
if (_obj isKindOf "CAManBase" && {!isNull objectParent _obj}) then { _obj = vehicle _obj; };
if (!local _obj) exitWith { ["lambs_danger_eypBombaYerel", [_obj, _a], _obj] call CBA_fnc_targetEvent; false };
if (!isNil {_obj getVariable QGVAR(eypBomba)}) exitWith {false};
_a params [["_menzil", 400, [0]], ["_tarz", 2, [0]], ["_atilmaM", -1, [0]], ["_guc", -1, [0]], ["_olumSans", -1, [0]], ["_hedefTaraf", 0, [0]], ["_varil", 1, [0]], ["_tetikM", -1, [0]]];
_menzil = (_menzil max 30) min 2000;
_hedefTaraf = round (_hedefTaraf max 0 min 3);

_obj setVariable [QGVAR(eypBomba), true, true];
_tarz = round (_tarz max 0 min 2);
_obj setVariable [QGVAR(eypGizli), _tarz == 1];
_obj setVariable [QGVAR(eypTarz), _tarz];
_obj setVariable [QGVAR(eypAtilmaM), _atilmaM];
_obj setVariable [QGVAR(eypGuc), _guc];
_obj setVariable [QGVAR(eypTetikM), _tetikM];
_obj setVariable [QGVAR(eypMenzil), _menzil];
_obj setVariable [QGVAR(eypHedefTaraf), _hedefTaraf];
_obj setVariable [QGVAR(eypOlumSans), _olumSans];
private _arac = !(_obj isKindOf "CAManBase");
if (_arac && {_varil > 0}) then {
    // referans VBIED: kasada gorsel patlayici varil
    private _v = createVehicle ["Land_MetalBarrel_F", [0, 0, 0], [], 0, "CAN_COLLIDE"];
    _v attachTo [_obj, [0, -1.2, 0.2]];
    _obj setVariable [QGVAR(eypVaril), _v];
};
// surucu / asker panik edip kacmasin, arac inmesin (referans)
private _kos = if (_arac) then {driver _obj} else {_obj};
if (!isNull _kos) then { _kos allowFleeing 0; };
if (_arac) then { _obj allowCrewInImmobile true; };
diag_log format ["[EYP-ISARET] %1 | %2 | tespit %3 m | %4 | son an %5 | guc %6 | olum sansi %7 | hedef taraf %8", typeOf _obj, ["piyade (PBIED)", "arac (VBIED)"] select _arac, _menzil, ["catisarak", "gizli yaklasim", "AGRESIF (durmadan sprint)"] select _tarz, [str _atilmaM + " m", "CBA"] select (_atilmaM < 0), [str _guc, "CBA"] select (_guc < 0), [str _olumSans, "CBA"] select (_olumSans < 0), ["otomatik (dost olmayan)", "BLUFOR", "OPFOR", "INDEP"] select _hedefTaraf];

[_obj, _menzil, _hedefTaraf] spawn {
    params ["_o", "_men", "_ht"];
    private _fail = 0;
    private _sonuc = "";
    while {alive _o && {_fail < 3}} do {
        sleep 1;
        private _r = if (_o isKindOf "CAManBase") then {_o} else {driver _o};
        if (isNull _r || {!alive _r} || {!local _o} || {isPlayer _r}) then { continue };
        private _h = [_o, _men, _ht] call FUNC(eypHedefBul);
        if (isNull _h) then { continue };
        _sonuc = [_r, _h, 120] call FUNC(eypKos);
        diag_log format ["[EYP-ISARET] SONUC | %1 | %2", typeOf _o, _sonuc];
        if (_sonuc isEqualTo "PATLADI" || {!alive _r}) exitWith {};
        _fail = _fail + 1;
        sleep 5;
    };
    deleteVehicle (_o getVariable [QGVAR(eypVaril), objNull]);
    if (alive _o) then { _o setVariable [QGVAR(eypBomba), nil, true]; };
};
true
