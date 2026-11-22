#include "script_component.hpp"
/*
 * Author: Cinar (ELITE fork)
 * RPG ATIS KAPISI + OLCUMU (v8.746; kullanici: 'lambs rpg arastir' + 'rpg sistemi yapalim'): AI omuz roketatari atisini (Fired, shotRocket / shotMissile, gudumsuz) izler ve guvensizse IPTAL eder.
 * NEDEN: LAMBS RPG yalniz CONFIG modudur (aiAmmoUsageFlags: roketatar secimi motorun kararidir) ve atisin guvenligini DENETLEMEZ; RPT'lerde (120 dosya) AI roketatar atisi HIC loglanmiyordu (kim, neye, ne kadar, kime zarar) -> olcum yoktu.
 * KURAL: fnc_rpgGuvenli (min mesafe, bina ici, hedefte dost, geri duvar, arkada dost, zirh yedegi) ihlalinde mermi silinir (deleteVehicle), 12 sn sonra mermi geri verilir
 *   (silah bossa setAmmo 1, motor yedekten doldurduysa addMagazine); atici 12 sn karar verilmez (rpgBekleT). Gudumlu fuzeye (AA / Javelin / Titan / NLAW: weaponLockSystem / maxControlRange > 0) DOKUNULMAZ.
 *   Dusus noktasi: mermi hiz yonunde 800 m FIRE LOD hatti + arazi (ilk vurus); hedef zirh: dususun 15 m'sinde dusman kara araci / zirh.
 * OLCUM: [RPG-ATIS] (ilk 60: atici, silah, mermi, aiAmmoUsageFlags, dusus mesafesi, hedef turu, kaynak 'karar' = fnc_rpgSistem emri / 'motor' = LAMBS RPG / motor) + [RPG-IPTAL] (ilk 40) + 60 sn [RPG-OZET]. Karne: RPG SISTEMI.
 * CBA: lambs_danger_rpgSistem (varsayilan ACIK; kapali = hicbir sey yapmaz), rpgMinM, rpgDostM, rpgYedek.
 *
 * Arguments:
 * 0: Atici <OBJECT>
 * 1: Silah <STRING>
 * 2: Mermi sinifi <STRING>
 * 3: Sarjor <STRING>
 * 4: Mermi nesnesi <OBJECT>
 *
 * Return Value: Iptal edildi mi <BOOL>
 *
 * Public: No
*/

params ["_unit", "_weapon", "_ammo", "_mag", "_proj"];
if !(missionNamespace getVariable ["lambs_danger_rpgSistem", true]) exitWith {false};
if (isNull _proj || {!local _unit} || {isPlayer _unit}) exitWith {false};
if ((getNumber (configFile >> "CfgWeapons" >> _weapon >> "type")) isNotEqualTo 4) exitWith {false};
private _ac = configFile >> "CfgAmmo" >> _ammo;
if ((getNumber (_ac >> "weaponLockSystem")) > 0 || {(getNumber (_ac >> "maxControlRange")) > 0}) exitWith {false};

private _say = missionNamespace getVariable ["lambs_danger_rpgSay", createHashMap];
missionNamespace setVariable ["lambs_danger_rpgSay", _say];

// dusus noktasi
private _p0 = getPosASL _proj;
private _vel = velocity _proj;
private _vm = vectorMagnitude _vel;
private _dir = if (_vm > 1) then { _vel vectorMultiply (1 / _vm) } else { eyeDirection _unit };
private _son = _p0 vectorAdd (_dir vectorMultiply 800);
private _vur = lineIntersectsSurfaces [_p0, _son, _unit, _proj, true, 1, "FIRE", "NONE"];
private _imp = if (_vur isNotEqualTo []) then { (_vur select 0) select 0 } else { _son };
private _ti = terrainIntersectAtASL [_p0, _son];
if (_ti isNotEqualTo [0, 0, 0] && {(_p0 distance _ti) < (_p0 distance _imp)}) then { _imp = _ti; };
private _yon = (_dir select 0) atan2 (_dir select 1);
private _taraf = side group _unit;

// hedef turu (dususun 15 m'si)
private _yakin = ((ASLToAGL _imp) nearEntities [["CAManBase", "LandVehicle", "StaticWeapon"], 15]) select {alive _x && {(_taraf getFriend (side group _x)) < 0.6} && {(side group _x) isNotEqualTo civilian}};
private _zirh = (_yakin findIf {(_x isKindOf "Tank") || {_x isKindOf "APC"} || {_x isKindOf "Wheeled_APC_F"}}) >= 0;
private _arac = (_yakin findIf {_x isKindOf "LandVehicle"}) >= 0;
private _tur = if (_zirh) then {"zirh"} else { if (_arac) then {"arac"} else { if ((_yakin findIf {_x isKindOf "CAManBase" && {(insideBuilding _x) > 0.5}}) >= 0) then {"bina ici dusman"} else { if (_yakin isNotEqualTo []) then {"piyade"} else {"hedef yok / nokta"} } } };

private _neden = [_unit, _weapon, _yon, _imp, _zirh, true] call FUNC(rpgGuvenli);
private _kaynak = ["motor", "karar"] select ((time - (_unit getVariable [QGVAR(rpgKararT), -999])) < 10);
private _dI = _unit distance _imp;

if (_neden isNotEqualTo "") then {
    deleteVehicle _proj;
    _unit setVariable [QGVAR(rpgBekleT), time + 12];
    [{
        params ["_u", "_w", "_m"];
        if (alive _u && {(secondaryWeapon _u) isEqualTo _w}) then {
            if ((_u ammo _w) <= 0) then { _u setAmmo [_w, 1]; } else { _u addMagazine _m; };
        };
    }, [_unit, _weapon, _mag], 12] call CBA_fnc_waitAndExecute;
    private _k = format ["iptal_%1", _neden];
    _say set [_k, (_say getOrDefault [_k, 0]) + 1];
    private _n = missionNamespace getVariable ["lambs_danger_rpgIptalLogN", 0];
    if (_n < 40) then {
        missionNamespace setVariable ["lambs_danger_rpgIptalLogN", _n + 1];
        diag_log format ["[RPG-IPTAL] %1 | %2 | %3 (%4) | neden: %5 | dusus %6 m | dusus hedefi: %7 | kaynak: %8 | mermi 12 sn sonra geri verilir", groupId group _unit, name _unit, _weapon, _ammo, _neden, round _dI, _tur, _kaynak];
    };
} else {
    private _k = format ["atis_%1", _kaynak];
    _say set [_k, (_say getOrDefault [_k, 0]) + 1];
    private _kt = format ["hedef_%1", _tur];
    _say set [_kt, (_say getOrDefault [_kt, 0]) + 1];
    private _n = missionNamespace getVariable ["lambs_danger_rpgAtisLogN", 0];
    if (_n < 60) then {
        missionNamespace setVariable ["lambs_danger_rpgAtisLogN", _n + 1];
        diag_log format ["[RPG-ATIS] %1 | %2 | %3 (%4) | aiAmmoUsageFlags %5 | dusus %6 m | dusus hedefi: %7 | kaynak: %8 | kalan roket %9", groupId group _unit, name _unit, _weapon, _ammo, getNumber (_ac >> "aiAmmoUsageFlags"), round _dI, _tur, _kaynak, (_unit ammo _weapon) + ({(toLower (_x select 0)) in ((compatibleMagazines _weapon) apply {toLower _x})} count (magazinesAmmo _unit))];
    };
};

private _ot = missionNamespace getVariable ["lambs_danger_rpgOzetT", -1];
if (_ot < 0) then { missionNamespace setVariable ["lambs_danger_rpgOzetT", time + 60]; } else {
    if (time > _ot) then {
        missionNamespace setVariable ["lambs_danger_rpgOzetT", time + 60];
        private _nz = (keys _say) select {(_say get _x) > 0};
        if (_nz isNotEqualTo []) then {
            diag_log format ["[RPG-OZET] 60 sn: %1", (([_nz, [], {_x}, "ASCEND"] call BIS_fnc_sortBy) apply { format ["%1=%2", _x, _say get _x] }) joinString " "];
        };
        { _say set [_x, 0]; } forEach (keys _say);
    };
};
_neden isNotEqualTo ""
