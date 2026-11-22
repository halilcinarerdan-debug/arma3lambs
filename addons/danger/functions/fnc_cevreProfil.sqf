#include "script_component.hpp"
/*
 * Author: Cinar (ELITE fork)
 * CEVRE PROFILI (v8.738; kullanici: 'ormanlik, cqb, acik alan, lythium loglarina gore profil olustur, bulunduklari konuma gore cover profili degissin, bukalemun gibi uyum saglasinlar, kodumuz fazla statik'):
 * Askerin BULUNDUGU yerin cevresini tarar ve bir profil dondurur: "ORMAN" | "KENTSEL" | "ACIK" | "KARISIK". 6 sn onbellek + HISTEREZIS (yeni profil 2 ardisik taramada ayniysa gecilir: bukalemun gibi ama titremez).
 * KANIT (tum RPT [ACIKTA-SINIF-OZET] / [ACIK-SIPER-OZET], ~80 oturum): (1) cangil / orman (cam_lao_nam, GM Weferlingen): acikta kalanin 20 m'sinde sert siper %56-98 + agac %2-81, 'hic yok' ~%0, nesne secimi cok;
 *   (2) CIPLAK ACIK ARAZI (cok sayida oturum): 'hic yok' %96-100, [ACIK-SIPER-OZET] aday_yok 30-1680 / dk (nesne yok; arazi kivrimi / yatis / uzak siper gerekir); (3) KENTSEL / Lythium: sert siper <= 20 m %85-100, bina / kentsel_bina var, 'gorunur' / 'yumusak' az;
 *   (4) karisik (Stratis): sert %60-90 + agac %10-47. Bu fonksiyon (1)-(4)'u askerin CEVRESINDEN canli ayirir.
 * KURAL (olcum yaricaplari): agac = TREE + SMALL TREE <= 30 m; sert = ROCK / ROCKS / WALL / HIDE / FENCE <= 25 m; bina = girilebilir (buildingPos) House <= 40 m.
 *   KENTSEL: bina >= 2 ya da (sert >= 8 ve agac <= 8);  ORMAN: agac >= 12 ve agac > sert x 2;  ACIK: agac + sert + bina x 3 <= 2;  aksi KARISIK.
 * CBA cevreProfil: 0 = kapali (statik, eski), 1 = OTOMATIK (konuma gore), 2 / 3 / 4 = sabit ORMAN / KENTSEL / ACIK. Log: [CEVRE-PROFIL] (profil degisimi, ilk 30) + 60 sn [CEVRE-PROFIL-OZET].
 *
 * Arguments:
 * 0: Asker <OBJECT>
 *
 * Return Value: Profil <STRING>
 * Public: No
*/

params [["_u", objNull, [objNull]]];
private _mod = missionNamespace getVariable ["lambs_danger_cevreProfil", 1];
if (isNull _u || {_mod isEqualTo 0}) exitWith {"KARISIK"};
if (_mod >= 2) exitWith {["ORMAN", "KENTSEL", "ACIK"] select ((_mod - 2) min 2)};

private _c = _u getVariable [QGVAR(cevreP), [-99, "KARISIK", "KARISIK", 0]];   // [son tarama zamani, gecerli profil, aday profil, aday tekrar]
if ((time - (_c select 0)) < 6) exitWith {_c select 1};

private _p = getPosATL _u;
private _ag = count (nearestTerrainObjects [_p, ["TREE", "SMALL TREE"], 30, false, true]);
private _sr = count (nearestTerrainObjects [_p, ["ROCK", "ROCKS", "WALL", "HIDE", "FENCE"], 25, false, true]);
private _bn = count ((nearestObjects [_p, ["House"], 40]) select {(count (_x buildingPos -1)) >= 1});
private _yeni = "KARISIK";
if (_bn >= 2 || {_sr >= 8 && {_ag <= 8}}) then { _yeni = "KENTSEL"; } else {
    if (_ag >= 12 && {_ag > (_sr * 2)}) then { _yeni = "ORMAN"; } else {
        if ((_ag + _sr + (_bn * 3)) <= 2) then { _yeni = "ACIK"; };
    };
};
private _gecerli = _c select 1;
private _aday = _c select 2;
private _tek = _c select 3;
if (_yeni isEqualTo _gecerli) then { _aday = _gecerli; _tek = 0; } else {
    if (_yeni isEqualTo _aday) then { _tek = _tek + 1; } else { _aday = _yeni; _tek = 1; };
    if (_tek >= 2 || {(_c select 0) < 0}) then {
        // gecis
        if ((missionNamespace getVariable ["lambs_danger_cevreLogN", 0]) < 30) then {
            missionNamespace setVariable ["lambs_danger_cevreLogN", (missionNamespace getVariable ["lambs_danger_cevreLogN", 0]) + 1];
            diag_log format ["[CEVRE-PROFIL] %1 | %2 -> %3 | agac %4 (<= 30 m), sert %5 (<= 25 m), bina %6 (<= 40 m)", name _u, _gecerli, _yeni, _ag, _sr, _bn];
        };
        _gecerli = _yeni; _aday = _yeni; _tek = 0;
    };
};
_u setVariable [QGVAR(cevreP), [time, _gecerli, _aday, _tek]];
private _s = missionNamespace getVariable ["lambs_danger_cevreSay", createHashMap];
_s set [_gecerli, (_s getOrDefault [_gecerli, 0]) + 1];
missionNamespace setVariable ["lambs_danger_cevreSay", _s];
if (isNil "lambs_danger_cevreOzetT") then { lambs_danger_cevreOzetT = time + 60; };
if (time > lambs_danger_cevreOzetT) then {
    lambs_danger_cevreOzetT = time + 60;
    diag_log format ["[CEVRE-PROFIL-OZET] 60 sn (asker taramasi): %1", (_s toArray false) apply { format ["%1=%2", _x select 0, _x select 1] }];
    missionNamespace setVariable ["lambs_danger_cevreSay", createHashMap];
};
_gecerli
