#include "script_component.hpp"
/*
 * Author: Cinar (ELITE fork)
 * BOT ISABETI: OYUNIN aimingAccuracy = 1 SINIRININ OTESI (v8.575; kullanici: 'oyuncunun isabeti ile ilgili her seyi kaldir, ben sadece botlarin 1 limitinden cikmasini istemistim').
 * YALNIZ BOTLAR (oyuncu / oyuncu olcumu / oyuncu yardimi YOK; v8.565-v8.574'teki isabetDenge olcumu, hedef oran, oyuncu yardimi KALDIRILDI).
 * aimingAccuracy / aimingShake en cok 1.0'dir (setSkill siniri). Bu sinirin otesi iki ayarla:
 *   - CBA isabetSeviye (0 = kapali, 1.25 / 1.30 ...): > 1 ise (1) yerel botlarin aimingAccuracy / aimingShake degeri 1.0'a sabitlenir (5 sn'de bir; eski deger saklanir, seviye <= 1 olunca geri yazilir; oyunculu grup / ALiVE / disableAI haric),
 *     (2) mermi yonu hatasi (1 - 1 / seviye) oraninda duzeltilir (isabet seviyesi ~ 1 / hata varsayimi: 1.25 -> %20, 1.30 -> %23, 1.5 -> %33).
 *   - CBA isabetYardim (0-1): seviyeden bagimsiz dogrudan mermi yonu duzeltme orani; ikisi birlikte ise buyuk olan gecerli.
 * MERMI YONU DUZELTME: bot (oyuncusuz grup, yerel mermi) bilinen dusman piyadeye <= 600 m BulletBase mermisi attiginda (hedef = assignedTarget, yoksa en yakin dusman; SuppressTarget / nokta bastirma sayilmaz) mermi hizinin yonu
 *   (azimut + yukselme) hedefe (aimPos + hedef hizi x ucus suresi onculu; yercekimi dusmesi 0.5 g t^2 telafili, ucus suresi = menzil / (hiz x 0.9)) olan hatanin orani kadar duzeltilir; her eksende en cok +-4 derece.
 * SINIR: setVelocity'nin tum mermi turlerinde / ACE Advanced Ballistics ile calistigi DENENMEDI; hava surtunmesi modellenmedi; hile benzeri (aimbot yardimi). Log: [ISABET-SEVIYE] (ilk 10).
 *
 * Arguments: None
 * Return Value: Baslatildi mi <BOOL>
 * Public: No
*/

if (!isNil "lambs_danger_botIsabetStarted") exitWith {false};
lambs_danger_botIsabetStarted = true;
lambs_danger_isabetMermiOn = createHashMap;
diag_log "[ISABET-SEVIYE] bot isabeti (aimingAccuracy 1 siniri otesi: CBA isabetSeviye / isabetYardim) baslatildi (v8.575)";

["CAManBase", "Fired", {
    params ["_u", "_wep", "", "", "_ammo", "", "_proj"];
    if (!local _u || {isPlayer _u} || {isNull _proj} || {_wep isEqualTo (secondaryWeapon _u)}) exitWith {};
    private _yrd = missionNamespace getVariable ["lambs_danger_isabetYardim", 0];
    private _sev = missionNamespace getVariable ["lambs_danger_isabetSeviye", 0];
    if (_sev > 1) then { _yrd = _yrd max (1 - (1 / _sev)); };
    if (_yrd <= 0 || {((units group _u) findIf {isPlayer _x}) > -1}) exitWith {};
    private _on = lambs_danger_isabetMermiOn;
    private _b = _on getOrDefault [_ammo, -1];
    if (_b < 0) then { _b = [0, 1] select (_ammo isKindOf ["BulletBase", configFile >> "CfgAmmo"]); _on set [_ammo, _b]; };
    if (_b isEqualTo 0) exitWith {};
    private _t = assignedTarget _u;
    if (isNull _t || {!(_t isKindOf "CAManBase")}) then { _t = _u findNearestEnemy _u; };
    if (isNull _t || {!alive _t} || {!(_t isKindOf "CAManBase")} || {((side group _u) getFriend (side group _t)) >= 0.6}) exitWith {};
    if ((_u distance _t) > 600) exitWith {};
    private _v = velocity _proj;
    private _sp = vectorMagnitude _v;
    private _vh = sqrt (((_v select 0) ^ 2) + ((_v select 1) ^ 2));
    if (_sp < 50 || {_vh < 1}) exitWith {};
    private _p0 = getPosASL _proj;
    private _tp = aimPos _t;
    private _d = _tp vectorDiff _p0;
    private _R = (sqrt (((_d select 0) ^ 2) + ((_d select 1) ^ 2))) max 1;
    private _tof = _R / (_sp * 0.9);
    private _d2 = (_tp vectorAdd ((velocity _t) vectorMultiply _tof)) vectorDiff _p0;
    private _R2 = (sqrt (((_d2 select 0) ^ 2) + ((_d2 select 1) ^ 2))) max 1;
    private _azI = (_d2 select 0) atan2 (_d2 select 1);
    private _elI = atan ((((_d2 select 2) + (0.5 * 9.81 * _tof * _tof))) / _R2);
    private _azC = (_v select 0) atan2 (_v select 1);
    private _elC = atan ((_v select 2) / _vh);
    private _dAz = ((((_azI - _azC) + 540) mod 360) - 180) max -4 min 4;
    private _dEl = ((_elI - _elC) max -4) min 4;
    private _azN = _azC + (_dAz * _yrd);
    private _elN = _elC + (_dEl * _yrd);
    _proj setVelocity ([(sin _azN) * (cos _elN), (cos _azN) * (cos _elN), sin _elN] vectorMultiply _sp);
}, true, [], true] call CBA_fnc_addClassEventHandler;

// ---- isabet seviyesi > 1 -> bot becerisi azami (5 sn'de bir; seviye <= 1 olunca eski deger) ----
[] spawn {
    private _logN = 0;
    while {true} do {
        sleep 5;
        private _sev = missionNamespace getVariable ["lambs_danger_isabetSeviye", 0];
        {
            private _u = _x;
            private _bay = _u getVariable ["lambs_danger_isabetSevBay", false];
            if (_sev > 1) then {
                if (isPlayer _u || {((units group _u) findIf {isPlayer _x}) > -1} || {_u getVariable [QGVAR(disableAI), false]} || {[_u] call FUNC(aliveSahip)}) then { continue };
                if (!_bay) then {
                    _u setVariable ["lambs_danger_isabetSevEski", [_u skill "aimingAccuracy", _u skill "aimingShake"]];
                    _u setVariable ["lambs_danger_isabetSevBay", true];
                    if (_logN < 10) then { _logN = _logN + 1; diag_log format ["[ISABET-SEVIYE] %1 | seviye %2: aimingAccuracy %3 -> 1.00, aimingShake %4 -> 1.00 | mermi hatasi duzeltme orani %5", name _u, _sev toFixed 2, (_u skill "aimingAccuracy") toFixed 2, (_u skill "aimingShake") toFixed 2, (1 - (1 / _sev)) toFixed 2]; };
                };
                if ((_u skill "aimingAccuracy") < 0.99) then { _u setSkill ["aimingAccuracy", 1]; };
                if ((_u skill "aimingShake") < 0.99) then { _u setSkill ["aimingShake", 1]; };
            } else {
                if (_bay) then {
                    private _e = _u getVariable ["lambs_danger_isabetSevEski", []];
                    if (_e isNotEqualTo []) then { _u setSkill ["aimingAccuracy", _e select 0]; _u setSkill ["aimingShake", _e select 1]; };
                    _u setVariable ["lambs_danger_isabetSevBay", nil];
                    _u setVariable ["lambs_danger_isabetSevEski", nil];
                };
            };
        } forEach (allUnits select {local _x && {alive _x} && {_x isKindOf "CAManBase"} && {!isPlayer _x} && {(_sev > 1) || {_x getVariable ["lambs_danger_isabetSevBay", false]}}});
    };
};
true
