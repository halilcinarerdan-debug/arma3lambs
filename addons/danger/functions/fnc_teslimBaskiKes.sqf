#include "script_component.hpp"
/*
 * Author: Cinar (ELITE fork)
 * TESLIM OLANA BASTIRMAYI KES (v8.581; kullanici: 'teslim olduysa takim supressi biraksin').
 * Bir asker teslim olunca (fnc_teslimOl), 600 m icindeki DUSMAN yerel AI askerlerden bu askerin <= 20 m'sine BASTIRMA ATESI (currentCommand 'Suppress', doSuppressiveFire'in assignedTarget mantik nesnesi) veriliyorsa emir iptal edilir
 * (doFollow lider: komut sifirlanir, formasyona doner) ve dusman gruplar teslim olani unutur (forgetTarget). Teslim olan hedef secimlerinden zaten dislanir (fnc_teslimMi).
 *
 * Arguments:
 * 0: Teslim olan asker <OBJECT>
 *
 * Return Value: iptal edilen emir sayisi <NUMBER>
 * Public: No
*/

params [["_u", objNull, [objNull]]];
if (isNull _u) exitWith {0};
private _n = 0;
private _tr = side group _u;
{
    private _x0 = _x;
    if (alive _x0 && {local _x0} && {!isPlayer _x0} && {(side group _x0) isNotEqualTo civilian} && {((side group _x0) getFriend _tr) < 0.6}) then {
        (group _x0) forgetTarget _u;
        if ((currentCommand _x0) isEqualTo "Suppress") then {
            private _at = assignedTarget _x0;
            if (!isNull _at && {(getPosATL _at) distance2D (getPosATL _u) <= 20}) then {
                _x0 doWatch objNull;
                _x0 doFollow (leader _x0);
                _n = _n + 1;
            };
        };
    };
} forEach (_u nearEntities ["CAManBase", 600]);
if (_n > 0 && {(missionNamespace getVariable ["lambs_danger_teslimBaskiLogN", 0]) < 15}) then {
    missionNamespace setVariable ["lambs_danger_teslimBaskiLogN", (missionNamespace getVariable ["lambs_danger_teslimBaskiLogN", 0]) + 1];
    diag_log format ["[TESLIM-BASKI-KES] %1 teslim oldu -> %2 dusman askerin bastirma emri iptal edildi (<= 20 m)", name _u, _n];
};
_n
