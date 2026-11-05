#include "script_component.hpp"
/*
 * Author: Cinar (ELITE fork)
 * UZUV IZIN (v8.500) - yazmadan once SORMA (kiralamadan): uzuv baska sahipte ve oncelik >= benimki ise false. Dusuk oncelikli, kiralamayan yazicilar (mekanize hiz sifirlama gibi) icin.
 * Bkz. fnc_uzuvKirala (oncelik tablosu).
 *
 * Arguments: 0: Birim <OBJECT>, 1: Uzuv <STRING>, 2: Sahip adi <STRING>, 3: Oncelik <NUMBER>
 * Return Value: yazabilir mi <BOOL>
 * Public: No
*/

params [["_u", objNull, [objNull]], ["_uzuv", "HIZ", [""]], ["_sahip", "", [""]], ["_oncelik", 50, [0]]];
if (isNull _u) exitWith {true};
private _m = _u getVariable [format ["lambs_danger_uzuv_%1", _uzuv], []];
if (_m isNotEqualTo [] && {(_m select 2) > time} && {(_m select 0) isNotEqualTo _sahip} && {(_m select 1) >= _oncelik}) exitWith {
    missionNamespace setVariable ["lambs_danger_uyumRet", (missionNamespace getVariable ["lambs_danger_uyumRet", 0]) + 1];
    private _lk = format ["lambs_danger_uyumLogT_%1_%2_%3", _uzuv, _sahip, _m select 0];
    if ((time - (_u getVariable [_lk, -999])) > 30 && {(missionNamespace getVariable ["lambs_danger_uyumLogN", 0]) < 60}) then {
        _u setVariable [_lk, time];
        missionNamespace setVariable ["lambs_danger_uyumLogN", (missionNamespace getVariable ["lambs_danger_uyumLogN", 0]) + 1];
        diag_log format ["[UYUM] RET | %1 | uzuv %2 | istek: %3 (oncelik %4) | mevcut sahip: %5 (oncelik %6, %7 sn kaldi)", typeOf (vehicle _u), _uzuv, _sahip, _oncelik, _m select 0, _m select 1, round ((_m select 2) - time)];
    };
    false
};
true
