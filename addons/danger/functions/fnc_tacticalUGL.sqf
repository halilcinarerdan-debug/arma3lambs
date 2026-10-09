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

// v8.62: NEDEN ATMADI sayaci (her cikis nedeni global sayac) + 30 sn'de bir [UGL-OZET] — UGL "hic kullanilmiyor" teshisi
private _red = {
    private _k = format ["lambs_danger_uglSay_%1", _this];
    missionNamespace setVariable [_k, (missionNamespace getVariable [_k, 0]) + 1];
    if (isNil "lambs_danger_uglOzetBasladi") then {
        lambs_danger_uglOzetBasladi = true;
        [] spawn {
            private _adlar = ["cooldown", "mermi_yok", "menzil", "uzak_aralik", "dost_yakin", "guvenlik", "uygun_degil", "rezerv", "yuklu_HE_yok", "isik_duman", "ATIS"];
            private _onceki = [];
            while {true} do {
                sleep 30;
                private _simdi = _adlar apply {missionNamespace getVariable [format ["lambs_danger_uglSay_%1", _x], 0]};
                if (_simdi isNotEqualTo _onceki) then {
                    private _fark = _simdi;
                    if (_onceki isNotEqualTo []) then { _fark = _simdi apply {_x} ; { _fark set [_forEachIndex, (_simdi select _forEachIndex) - (_onceki select _forEachIndex)]; } forEach _simdi; };
                    private _txt = [];
                    { _txt pushBack format ["%1:%2", _x, _fark select _forEachIndex]; } forEach _adlar;
                    diag_log format ["[UGL-OZET] son 30 sn | %1 | toplam ATIS:%2", _txt joinString " ", _simdi select 10];
                    _onceki = _simdi;
                };
            };
        };
    };
    false
};
if ((time - (_unit getVariable [QGVAR(uglLast), -999])) < 6) exitWith {"cooldown" call _red};

// ---------------------------------------------------------------------------
// UGL muzzle (silah basina onbellek) + mermi var mi
// ---------------------------------------------------------------------------
private _w = primaryWeapon _unit;
if (_w isEqualTo "") exitWith {false};

private _gl = [_unit] call (missionNamespace getVariable ["lambs_danger_fnc_hasUGL", {""}]);
if (_gl isEqualTo "") exitWith {false};
// v8.83 UGL YUKLEME (RPT c4eedb1d: 'isik_duman' 18-19 / 30 sn = yuklu 40mm DUMAN / FLARE mermisi, 'mermi_yok' 11-15 = namlu bos; envanterde HE varken atilmiyordu):
//   yuklu mermi olumcul degilse (duman / flare / aydinlatma) ya da namlu bossa ve envanterde olumcul 40mm varsa degistir (10 sn'de en fazla 1 kez).
private _glMags0 = [_w, _gl] call FUNC(uglMags);
private _letalMi = {
    params ["_mg"];
    private _am = getText (configFile >> "CfgMagazines" >> _mg >> "ammo");
    private _ad0 = toLower (_mg + "|" + _am);
    (["flare", "smoke", "illum", "f_40mm", "chemlight", "signal", "cir_"] findIf {(_ad0 find _x) >= 0}) < 0
        && {((getNumber (configFile >> "CfgAmmo" >> _am >> "hit")) + (getNumber (configFile >> "CfgAmmo" >> _am >> "indirectHit"))) > 0}
        && {(getNumber (configFile >> "CfgAmmo" >> _am >> "intensity")) <= 0}
};
private _yukluSimdi = (primaryWeaponMagazine _unit) select {(toLower _x) in _glMags0};
private _yukluLetal = (_yukluSimdi isNotEqualTo []) && {[_yukluSimdi select 0] call _letalMi};
if ((!_yukluLetal || {(_unit ammo _gl) <= 0}) && {(time - (_unit getVariable [QGVAR(glSwapT), -999])) > 10}) then {
    private _heEnv = (magazines _unit) select {(toLower _x) in _glMags0 && {[_x] call _letalMi}};
    if (_heEnv isNotEqualTo []) then {
        _unit setVariable [QGVAR(glSwapT), time];
        private _eski = if (_yukluSimdi isEqualTo []) then {"(bos)"} else {_yukluSimdi select 0};
        if (_yukluSimdi isNotEqualTo []) then { _unit removePrimaryWeaponItem (_yukluSimdi select 0); };
        _unit removeMagazine (_heEnv select 0);
        _unit addPrimaryWeaponItem (_heEnv select 0);
        if ((missionNamespace getVariable ["lambs_danger_glSwapN", 0]) < 40) then {
            missionNamespace setVariable ["lambs_danger_glSwapN", (missionNamespace getVariable ["lambs_danger_glSwapN", 0]) + 1];
            diag_log format ["[UGL-YUKLE] %1 | %2 | eski yuklu: %3 -> HE: %4 | envanterde olumcul 40mm: %5", groupId (group _unit), name _unit, _eski, _heEnv select 0, count _heEnv];
        };
    };
};
if ((_unit ammo _gl) <= 0) exitWith {"mermi_yok" call _red};

// ---------------------------------------------------------------------------
// MENZIL
// ---------------------------------------------------------------------------
private _d = _unit distance2D _target;
if (_d < 35 || {_d > 320}) exitWith {"menzil" call _red};
// UZAK MESAFE: > 200 m'de atis 25 sn'de bir (RPT: tek bombaatar 300 m'ye 9 sn'de bir 2'li salvo = 30 mermi / 90 sn; M203 pratik menzil ~150-200 m)
if (_d > ([group _unit, "uglUzakM", 200] call FUNC(dk)) && {(time - (_unit getVariable [QGVAR(uglLast), -999])) < ([group _unit, "uglUzakAralik", 25] call FUNC(dk))}) exitWith {"uzak_aralik" call _red};

// Dost atesi: hedefin 12 m cevresinde dost varsa atma (escort / ilerleyen birlik)
if (((_target nearEntities ["CAManBase", 12]) findIf {alive _x && {((side group _unit) getFriend (side _x)) >= 0.6}}) > -1) exitWith {"dost_yakin" call _red};

// GUVENLIK: dost / engel (cali, dal) / sekme kontrolu — guvenli degilse ATMA
if (!([_unit, _target, "UGL"] call (missionNamespace getVariable ["lambs_danger_fnc_atisGuvenli", {true}]))) exitWith {"guvenlik" call _red};

// ---------------------------------------------------------------------------
// UYGUN MU: hat kapali / binada / kume / %50
// ---------------------------------------------------------------------------
private _uygun = _force;
if (!_uygun) then {
    private _engelli = lineIntersects [eyePos _unit, eyePos _target, _unit, _target];
    private _binada = (insideBuilding _target) > 0.5;
    private _kume = (count ((_target nearEntities ["CAManBase", 15]) select {
        alive _x && {(side _x) isEqualTo (side _target)}
    })) >= 2;
    // v8.62: kume yaricapi 8 -> 15 m; sans %50 -> %70; grup bastirilmissa (kendi ates ustunlugu yok) UGL oncelikli
    private _bastirilmis = ((units group _unit) findIf {alive _x && {(getSuppression _x) > 0.3}}) >= 0;
    _uygun = _engelli || {_binada} || {_kume} || {_bastirilmis} || {(random 1) < 0.7};
};
if (!_uygun) exitWith {"uygun_degil" call _red};

// ---------------------------------------------------------------------------
// YUKLU 40mm SARJOR HE MI? (flare / duman / aydinlatma ATILMAZ)
// ---------------------------------------------------------------------------
private _glMags = [_w, _gl] call FUNC(uglMags);
// MERMI REZERVI: elde 3'ten az 40mm kaldiysa 120 m'den uzaga atilmaz (yakin tehdit / bina icin sakla)
private _glKalan = ({(toLower _x) in _glMags} count (magazines _unit)) + ([0, 1] select ((_unit ammo _gl) > 0));
if (_glKalan < ([group _unit, "uglRezerv", 3] call FUNC(dk)) && {_d > ([group _unit, "uglRezervM", 120] call FUNC(dk))}) exitWith {"rezerv" call _red};
private _yuklu = (primaryWeaponMagazine _unit) select {(toLower _x) in _glMags};
if (_yuklu isEqualTo []) exitWith {"yuklu_HE_yok" call _red};

private _magAd = _yuklu select 0;
private _ammoAd = getText (configFile >> "CfgMagazines" >> _magAd >> "ammo");
private _ad = toLower (_magAd + "|" + _ammoAd);
private _isik = (["flare", "smoke", "illum", "f_40mm", "chemlight", "signal", "cir_"] findIf {(_ad find _x) >= 0}) > -1;
private _guc = (getNumber (configFile >> "CfgAmmo" >> _ammoAd >> "hit")) + (getNumber (configFile >> "CfgAmmo" >> _ammoAd >> "indirectHit"));
private _isikli = (getNumber (configFile >> "CfgAmmo" >> _ammoAd >> "intensity")) > 0;
if (_isik || {_isikli} || {_guc <= 0}) exitWith {"isik_duman" call _red};

// ---------------------------------------------------------------------------
// ATIS — dogrudan HE: muzzle sec, hedefe bak, 1.5 sn sonra fireAtTarget, 2 sn sonra tufege don
// ---------------------------------------------------------------------------
_unit setVariable [QGVAR(uglLast), time];
"ATIS" call _red;
if ((missionNamespace getVariable ["lambs_danger_uglKararN", 0]) < 60) then {
    missionNamespace setVariable ["lambs_danger_uglKararN", (missionNamespace getVariable ["lambs_danger_uglKararN", 0]) + 1];
    diag_log format ["[UGL-KARAR] %1 | %2 | hedef %3 m | zorla:%4 | salvo:%5 | mermi:%6", groupId (group _unit), name _unit, round _d, _force, _salvo, _magAd];
};
_unit doWatch _target;
_unit doTarget _target;
if !(missionNamespace getVariable ["lambs_danger_silahDegisimOff", false]) then { _unit selectWeapon _gl };

[{
    params ["_u", "_t", "_muzzle", "_salvo"];
    if (alive _u && {!isNull _t} && {alive _t} && {(_u ammo _muzzle) > 0} && {[_u, _t, "UGL"] call (missionNamespace getVariable ["lambs_danger_fnc_atisGuvenli", {true}])}) then {
        _u fireAtTarget [_t, _muzzle];
    };
    [{
        params ["_u2", "_s2"];
        if (alive _u2 && {_s2 <= 1}) then {
            if !(missionNamespace getVariable ["lambs_danger_silahDegisimOff", false]) then { _u2 selectWeapon (primaryWeapon _u2) };
            _u2 doWatch objNull;
        };
    }, [_u, _salvo], 2] call CBA_fnc_waitAndExecute;
}, [_unit, _target, _gl, _salvo], 1.5] call CBA_fnc_waitAndExecute;   // _salvo ic bloga ARGUMAN olarak gecmeli (hemtt L-S13: tanimsiz degisken)

// SALVO: ikinci / ucuncu atis (yeniden yukleme sonrasi), ayni hedefe — ilk atis duzeltme, sonrakiler etki
for "_i" from 1 to ((_salvo min 3) - 1) do {
    [{
        params ["_u", "_t", "_muzzle"];
        if (alive _u && {!isNull _t} && {alive _t} && {(_u ammo _muzzle) > 0}) then {
            if !(missionNamespace getVariable ["lambs_danger_silahDegisimOff", false]) then { _u selectWeapon _muzzle };
            [{
                params ["_u3", "_t3", "_m3"];
                if (alive _u3 && {!isNull _t3} && {alive _t3} && {(_u3 ammo _m3) > 0} && {[_u3, _t3, "UGL"] call (missionNamespace getVariable ["lambs_danger_fnc_atisGuvenli", {true}])}) then {
                    _u3 fireAtTarget [_t3, _m3];
                };
                [{ params ["_u4"]; if (alive _u4 && {!(missionNamespace getVariable ["lambs_danger_silahDegisimOff", false])}) then { _u4 selectWeapon (primaryWeapon _u4); }; }, [_u3], 1.5] call CBA_fnc_waitAndExecute;
            }, [_u, _t, _muzzle], 1] call CBA_fnc_waitAndExecute;
        };
    }, [_unit, _target, _gl], 4.5 * _i] call CBA_fnc_waitAndExecute;
};

true
