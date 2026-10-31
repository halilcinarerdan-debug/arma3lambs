#include "script_component.hpp"
/*
 * Author: Cinar (ELITE fork)
 * TEK ASKERI TESLIM ETTIR (v8.358; kullanici: 'tam teslim olacakken bazen silahi degistiriyor ya da dusuyor, animasyon kitleniyor gibi').
 * Eskiden fnc_moral / fnc_teslimBirey ayni karede DropWeapon aksiyonu + disableAI + doStop + ACE setSurrendered cagiriyor, 2 sn sonra removeAllWeapons yapiyordu:
 * silah birakma (silah degistirme) animasyonu yarida kesiliyor, silah animasyonda kalirken silahlar siliniyor (tufekli durus + silahsiz = takili animasyon).
 *
 * SIRA: (1) AI parcalari kapatilir, captive, doStop (aninda; ates / hareket durur)
 *       (2) birim basina 0-0.6 sn rastgele gecikme (grup ayni karede donmasin)
 *       (3) ana silah DropWeapon ile birakilir; silah elden cikana kadar (en cok 2.5 sn) beklenir; kalan silahlar (roketatar / tabanca) silinir
 *       (4) animasyon hala silahli (Wrfl / Wpst / Wlnr) ise silahsiz durusa gecilir (switchMove AmovPercMstpSnonWnonDnon); duruş UP
 *       (5) ACE yukluyse ace_captives_fnc_setSurrendered, degilse vanilla Surrender; 1.5 sn sonra animasyon 'sur' icermiyorsa teslim animasyonu zorlanir
 * Log: [TESLIM-ANIM] (ilk 30; silah birakma ve animasyon sonucu).
 *
 * Arguments:
 * 0: Asker <OBJECT>
 *
 * Return Value: Baslatildi mi <BOOL>
 *
 * Public: No
*/

params [["_u", objNull, [objNull]]];
if (isNull _u || {!alive _u} || {!isNull objectParent _u}) exitWith {false};

_u setVariable [QGVAR(disableAI), true];
_u setCaptive true;
_u setVariable [QGVAR(teslim), true, true];
_u setVariable [QGVAR(teslimAnimT), time];
{ _u disableAI _x; } forEach ["MOVE", "PATH", "TARGET", "AUTOTARGET", "FSM", "WEAPONAIM", "AUTOCOMBAT", "COVER", "SUPPRESSION"];
doStop _u;
_u doWatch objNull;

[_u] spawn {
    params ["_u"];
    sleep (random 0.6);
    if (!alive _u) exitWith {};
    private _t0 = time;
    private _w = primaryWeapon _u;
    if (_w isNotEqualTo "") then {
        _u action ["DropWeapon", _u, _w];
        private _tB = time + 2.5;
        waitUntil { sleep 0.1; !alive _u || {(primaryWeapon _u) isEqualTo ""} || {time > _tB} };
    };
    if (!alive _u) exitWith {};
    removeAllWeapons _u;
    sleep 0.3;
    private _as0 = toLower (animationState _u);
    if ((_as0 find "wnon") < 0) then { _u switchMove "AmovPercMstpSnonWnonDnon"; };
    _u setUnitPos "UP";
    sleep 0.2;
    if (!isNil "ace_captives_fnc_setSurrendered") then { [_u, true] call ace_captives_fnc_setSurrendered; } else { _u action ["Surrender", _u]; };
    sleep 1.5;
    private _as1 = toLower (animationState _u);
    private _zorla = alive _u && {(_as1 find "sur") < 0};
    if (_zorla) then { _u switchMove "AmovPercMstpSsurWnonDnon"; };
    private _n = missionNamespace getVariable ["lambs_danger_teslimAnimN", 0];
    if (_n < 30) then {
        missionNamespace setVariable ["lambs_danger_teslimAnimN", _n + 1];
        diag_log format ["[TESLIM-ANIM] %1 | %2 | silah birakma %3 sn | onceki anim %4 -> %5 | teslim animasyonu zorlandi: %6", groupId (group _u), name _u, (time - _t0) toFixed 1, _as0, _as1, _zorla];
    };
};

true
