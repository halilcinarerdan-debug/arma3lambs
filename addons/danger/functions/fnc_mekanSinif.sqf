#include "script_component.hpp"
/*
 * Author: Cinar (ELITE fork)
 * MEKAN SINIFI (GRUP DUZEYI; v8.823; kullanici: 'arazi ve mekana gore gercek doktrin secimi' / 'cevreye gore doktrinde ekle'; yol haritasi madde 34): bugunku fnc_cevreProfil ASKER basina parametre olcekliyordu; bu fonksiyon GRUBUN bulundugu / gidecegi mekani siniflar ve
 * fnc_dk bu sinifa gore doktrin degerlerini (hucum / bound mesafeleri, atilim bantlari, overwatch kurulumu, pusu ates mesafesi, yakin muharebe esigi, konsolidasyon suresi) carpar. Manevra SECIMI (kanat / cephe) degismez; yalniz SAYILAR mekana uyar.
 * SINIFLAR: "KENTSEL" | "ORMAN" | "TEPELIK" | "KORIDOR" | "ACIK" | "KARISIK".
 * ORNEKLEME (15 sn'de bir, grup basina): lider konumu (agirlik 2), liderin hedefine dogru 100 m (+ 200 m) ve en yakin bilinen dusmana dogru 100 m: her noktada fnc_cevreProfil'in kurallari (agac <= 30 m, sert <= 25 m, girilebilir bina <= 40 m) ile profil; oylama (en yuksek oy >= %40, aksi KARISIK).
 *   TEPELIK: lider etrafinda 60 / 120 m halkasi 8 yon yukseklik ornegi; yukseklik farki >= 20 m ya da ortalama egim >= 0.18 (~10 derece). KORIDOR: lider yolda ya da 12 m icinde yol, ya da 40 m'de 8 yonden >= 2'si su.
 *   ONCELIK: KENTSEL > ORMAN > TEPELIK > KORIDOR > ACIK > KARISIK (oylamanin sonucu KENTSEL / ORMAN ise o kalir; oylama ACIK / KARISIK iken TEPELIK / KORIDOR ustune yazar).
 * HISTEREZIS: yeni sinif 60 sn boyunca (ardisik taramalarda) ayni kalirsa gecilir (titremez); ilk taramada hemen. Log: [MEKAN-DOKTRIN] (gecis, ilk 30 sonra 30 sn'de bir) + 60 sn [MEKAN-DOKTRIN-OZET].
 * SAYILAR TASARIMDIR (kitapta yok; kaynak ilkeleri: MCWP 3-11.1 arazi / tehlike alanlari, MCWP 3-11.2 8307, TC 3-21.76 6-8, ATP 3-21.8 arazi ve formasyon). CBA mekanDoktrin (kapali = KARISIK / carpan yok).
 * Arguments: 0: Grup <GROUP|OBJECT>
 * Return Value: Sinif <STRING>
 * Public: No
*/
params [["_g", grpNull, [grpNull, objNull]]];
if (_g isEqualType objNull) then { _g = group _g; };
if (isNull _g || {!(missionNamespace getVariable ["lambs_danger_mekanDoktrin", true])}) exitWith {"KARISIK"};
// [aktif sinif, son tarama, aday, adayIlkT]
private _c = _g getVariable [QGVAR(mekanS), ["KARISIK", -99, "KARISIK", 0]];
if ((time - (_c select 1)) < 15) exitWith {_c select 0};
private _l = leader _g;
if (isNull _l || {!alive _l} || {isPlayer _l} || {!isNull objectParent _l}) exitWith {_c select 0};
private _ilkTarama = (_c select 1) < 0;
_c set [1, time];
_g setVariable [QGVAR(mekanS), _c];

private _prof = {
    params ["_p"];
    private _ag = count (nearestTerrainObjects [_p, ["TREE", "SMALL TREE"], 30, false, true]);
    private _sr = count (nearestTerrainObjects [_p, ["ROCK", "ROCKS", "WALL", "HIDE", "FENCE"], 25, false, true]);
    private _bn = count ((nearestObjects [_p, ["House"], 40]) select {(count (_x buildingPos -1)) >= 1});
    if (_bn >= 2 || {_sr >= 8 && {_ag <= 8}}) exitWith {"KENTSEL"};
    if (_ag >= 12 && {_ag > (_sr * 2)}) exitWith {"ORMAN"};
    if ((_ag + _sr + (_bn * 3)) <= 2) exitWith {"ACIK"};
    "KARISIK"
};
private _lp = getPosATL _l;
private _noktalar = [[_lp, 2]];
private _ed = (expectedDestination _l) select 0;
private _yon = if (_ed isEqualType [] && {(count _ed) >= 2} && {_ed isNotEqualTo [0, 0, 0]} && {(_l distance2D _ed) > 30}) then { _lp getDir _ed } else { getDir _l };
_noktalar pushBack [_lp getPos [100, _yon], 1];
if (_ed isEqualType [] && {(count _ed) >= 2} && {(_l distance2D _ed) > 220}) then { _noktalar pushBack [_lp getPos [200, _yon], 1]; };
private _en = _l findNearestEnemy _l;
if (!isNull _en) then { _noktalar pushBack [_lp getPos [100 min ((_l distance2D _en) / 2), _lp getDir _en], 1]; };
private _oy = createHashMap;
private _top = 0;
{
    _x params ["_pt", "_agr"];
    private _sn = [_pt] call _prof;
    _oy set [_sn, (_oy getOrDefault [_sn, 0]) + _agr];
    _top = _top + _agr;
} forEach _noktalar;
private _yeni = "KARISIK";
private _ek = -1;
{
    private _v = _oy get _x;
    if (_v > _ek) then { _ek = _v; _yeni = _x; };
} forEach (keys _oy);
if ((_ek / (_top max 1)) < 0.4) then { _yeni = "KARISIK"; };
if (_yeni in ["ACIK", "KARISIK"]) then {
    // TEPELIK: yukseklik halkasi
    private _hs = [];
    { private _r = _x; for "_i" from 0 to 7 do { _hs pushBack (getTerrainHeightASL (_lp getPos [_r, _i * 45])); }; } forEach [60, 120];
    private _h0 = getTerrainHeightASL _lp;
    private _fark = (selectMax _hs) - (selectMin _hs);
    private _egim = 0;
    { _egim = _egim + ((abs (_x - _h0)) / ([60, 120] select (_forEachIndex >= 8))); } forEach _hs;
    _egim = _egim / ((count _hs) max 1);
    if (_fark >= 20 || {_egim >= 0.18}) then { _yeni = "TEPELIK"; } else {
        // KORIDOR: yol ya da su
        private _su = 0;
        for "_i" from 0 to 7 do { if (surfaceIsWater (_lp getPos [40, _i * 45])) then { _su = _su + 1; }; };
        if (isOnRoad _lp || {!isNull (roadAt _lp)} || {(count (_lp nearRoads 12)) > 0} || {_su >= 2}) then { _yeni = "KORIDOR"; };
    };
};
// histerezis
private _aktif = _c select 0;
private _aday = _c select 2;
private _ilkT = _c select 3;
if (_yeni isEqualTo _aktif) then { _aday = _aktif; _ilkT = time; } else {
    if (_yeni isNotEqualTo _aday) then { _aday = _yeni; _ilkT = time; };
    if ((time - _ilkT) >= 60 || {_ilkTarama}) then {
        if (["mekanDoktrin", 30, 30] call FUNC(logIzin)) then {
            diag_log format ["[MEKAN-DOKTRIN] %1 | %2 -> %3 | oy %4 | nokta %5 | dusman %6 | lider hedefe %7 m", groupId _g, _aktif, _yeni, (_oy toArray false) apply { format ["%1=%2", _x select 0, _x select 1] }, count _noktalar, if (isNull _en) then {"-"} else {str (round (_l distance2D _en))}, if (_ed isEqualType []) then {str (round (_l distance2D _ed))} else {"-"}];
        };
        _aktif = _yeni; _aday = _yeni;
        private _gs = missionNamespace getVariable ["lambs_danger_mekanGecis", 0];
        missionNamespace setVariable ["lambs_danger_mekanGecis", _gs + 1];
    };
};
_g setVariable [QGVAR(mekanS), [_aktif, time, _aday, _ilkT]];
private _s = missionNamespace getVariable ["lambs_danger_mekanSay", createHashMap];
_s set [_aktif, (_s getOrDefault [_aktif, 0]) + 1];
missionNamespace setVariable ["lambs_danger_mekanSay", _s];
if (isNil "lambs_danger_mekanOzetT") then { lambs_danger_mekanOzetT = time + 60; };
if (time > lambs_danger_mekanOzetT) then {
    lambs_danger_mekanOzetT = time + 60;
    private _ms = missionNamespace getVariable ["lambs_danger_mekanDkSay", createHashMap];
    diag_log format ["[MEKAN-DOKTRIN-OZET] 60 sn (grup taramasi): %1 | gecis toplam %2 | uygulanan carpan (sinif|anahtar=adet): %3", (_s toArray false) apply { format ["%1=%2", _x select 0, _x select 1] }, missionNamespace getVariable ["lambs_danger_mekanGecis", 0], (_ms toArray false) apply { format ["%1=%2", _x select 0, _x select 1] }];
    missionNamespace setVariable ["lambs_danger_mekanDkSay", createHashMap];
    missionNamespace setVariable ["lambs_danger_mekanSay", createHashMap];
};
_aktif
