#include "script_component.hpp"
/*
 * Author: Cinar (ELITE fork)
 * TAKTIK UGL (40mm) KULLANIMI — boost
 *
 * Eskiden UGL sadece LAMBS'in nadir tetiklemesine kaliyordu. Bu fonksiyon, ates ekibinin
 * UGL'li askerlerini DUSMAN PIYADEYE karsi sistemli olarak kullanir:
 *   - hedef 40..320 m arasinda piyade
 *   - dogrudan hat KAPALI (siperde / binada saklanan dusman: tufekle vurulamaz, UGL ust eger)
 *   - hedef BINADA
 *   - 8 m icinde 2+ dusman KUME (alan etkisi)
 *   - yoksa %50 sans (her cagrida degil, dogal gorunsun)
 *   - birim basina 12 sn cooldown
 *
 * DUZELTME (v2): LAMBS'in lambs_main_fnc_doUGL'u ILLUMINATION (FLARE / DUMAN) atar — bu fonksiyon onu
 * cagirdigi icin askerler surekli flare ataniyordu. Artik doUGL KULLANILMAZ: yuklu 40mm sarjor
 * HE ise (flare / duman / aydinlatma DEGIL) muzzle secilir ve fireAtTarget ile dogrudan HE atilir.
 *
 * Arguments:
 * 0: unit <OBJECT>
 * 1: dusman piyade <OBJECT>
 * 2: zorla (kontrolleri atla, her zaman at) <BOOL> default false
 * 3: salvo (art arda 40mm sayisi, 1-3; 2. atis ~4 sn sonra, dogru yuklenmis ise) <NUMBER> default 1
 *
 * Return Value:
 * Atis denendi mi <BOOL>
 *
 * Example:
 * [bob, angryJoe] call lambs_danger_fnc_tacticalUGL;
 *
 * Public: No
*/

params [
    ["_unit", objNull, [objNull]],
    ["_target", objNull, [objNull]],
    ["_force", false, [false]],
    ["_salvo", 1, [0]]
];

if (isNull _unit || {!alive _unit} || {isNull _target} || {!alive _target}) exitWith {false};
if (!isNull objectParent _unit) exitWith {false};
if ((time - (_unit getVariable [QGVAR(uglLast), -999])) < 9) exitWith {false};

// ---------------------------------------------------------------------------
// UGL muzzle (silah basina onbellek) + mermi var mi
// ---------------------------------------------------------------------------
private _w = primaryWeapon _unit;
if (_w isEqualTo "") exitWith {false};

private _gl = [_unit] call (missionNamespace getVariable ["lambs_danger_fnc_hasUGL", {""}]);
if (_gl isEqualTo "") exitWith {false};
if ((_unit ammo _gl) <= 0) exitWith {false};

// ---------------------------------------------------------------------------
// MENZIL
// ---------------------------------------------------------------------------
private _d = _unit distance2D _target;
if (_d < 40 || {_d > 320}) exitWith {false};

// Dost atesi: hedefin 12 m cevresinde dost varsa atma (escort / ilerleyen birlik)
if (((_target nearEntities ["CAManBase", 12]) findIf {alive _x && {((side group _unit) getFriend (side _x)) >= 0.6}}) > -1) exitWith {false};

// GUVENLIK: dost / engel (cali, dal) / sekme kontrolu — guvenli degilse ATMA
if (!([_unit, _target, "UGL"] call (missionNamespace getVariable ["lambs_danger_fnc_atisGuvenli", {true}]))) exitWith {false};

// ---------------------------------------------------------------------------
// UYGUN MU: hat kapali / binada / kume / %50
// ---------------------------------------------------------------------------
private _uygun = _force;
if (!_uygun) then {
    private _engelli = lineIntersects [eyePos _unit, eyePos _target, _unit, _target];
    private _binada = (insideBuilding _target) > 0.5;
    private _kume = (count ((_target nearEntities ["CAManBase", 8]) select {
        alive _x && {(side _x) isEqualTo (side _target)}
    })) >= 2;
    _uygun = _engelli || {_binada} || {_kume} || {(random 1) < 0.5};
};
if (!_uygun) exitWith {false};

// ---------------------------------------------------------------------------
// YUKLU 40mm SARJOR HE MI? (flare / duman / aydinlatma ATILMAZ)
// ---------------------------------------------------------------------------
private _glMags = [_w, _gl] call FUNC(uglMags);
private _yuklu = (primaryWeaponMagazine _unit) select {(toLower _x) in _glMags};
if (_yuklu isEqualTo []) exitWith {false};

private _magAd = _yuklu select 0;
private _ammoAd = getText (configFile >> "CfgMagazines" >> _magAd >> "ammo");
private _ad = toLower (_magAd + "|" + _ammoAd);
private _isik = (["flare", "smoke", "illum", "f_40mm", "chemlight", "signal", "cir_"] findIf {(_ad find _x) >= 0}) > -1;
private _guc = (getNumber (configFile >> "CfgAmmo" >> _ammoAd >> "hit")) + (getNumber (configFile >> "CfgAmmo" >> _ammoAd >> "indirectHit"));
private _isikli = (getNumber (configFile >> "CfgAmmo" >> _ammoAd >> "intensity")) > 0;
if (_isik || {_isikli} || {_guc <= 0}) exitWith {false};

// ---------------------------------------------------------------------------
// ATIS — dogrudan HE: muzzle sec, hedefe bak, 1.5 sn sonra fireAtTarget, 2 sn sonra tufege don
// ---------------------------------------------------------------------------
_unit setVariable [QGVAR(uglLast), time];
_unit doWatch _target;
_unit doTarget _target;
_unit selectWeapon _gl;

[{
    params ["_u", "_t", "_muzzle", "_salvo"];
    if (alive _u && {!isNull _t} && {alive _t} && {(_u ammo _muzzle) > 0} && {[_u, _t, "UGL"] call (missionNamespace getVariable ["lambs_danger_fnc_atisGuvenli", {true}])}) then {
        _u fireAtTarget [_t, _muzzle];
    };
    [{
        params ["_u2", "_s2"];
        if (alive _u2 && {_s2 <= 1}) then {
            _u2 selectWeapon (primaryWeapon _u2);
            _u2 doWatch objNull;
        };
    }, [_u, _salvo], 2] call CBA_fnc_waitAndExecute;
}, [_unit, _target, _gl, _salvo], 1.5] call CBA_fnc_waitAndExecute;   // _salvo ic bloga ARGUMAN olarak gecmeli (hemtt L-S13: tanimsiz degisken)

// SALVO: ikinci / ucuncu atis (yeniden yukleme sonrasi), ayni hedefe — ilk atis duzeltme, sonrakiler etki
for "_i" from 1 to ((_salvo min 3) - 1) do {
    [{
        params ["_u", "_t", "_muzzle"];
        if (alive _u && {!isNull _t} && {alive _t} && {(_u ammo _muzzle) > 0}) then {
            _u selectWeapon _muzzle;
            [{
                params ["_u3", "_t3", "_m3"];
                if (alive _u3 && {!isNull _t3} && {alive _t3} && {(_u3 ammo _m3) > 0} && {[_u3, _t3, "UGL"] call (missionNamespace getVariable ["lambs_danger_fnc_atisGuvenli", {true}])}) then {
                    _u3 fireAtTarget [_t3, _m3];
                };
                [{ params ["_u4"]; if (alive _u4) then { _u4 selectWeapon (primaryWeapon _u4); }; }, [_u3], 1.5] call CBA_fnc_waitAndExecute;
            }, [_u, _t, _muzzle], 1] call CBA_fnc_waitAndExecute;
        };
    }, [_unit, _target, _gl], 4.5 * _i] call CBA_fnc_waitAndExecute;
};

true
