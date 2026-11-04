#include "script_component.hpp"
/*
 * Author: Cinar (ELITE fork)
 * C2 SUNUCU: TOPCU GOREVI IPTAL (v8.391) — gozlemcinin aktif gorevini sonlandirir: henuz kademeli ates sirasi gelmemis toplar atmaz. HAVADAKI MERMILER GERI ALINAMAZ.
 *
 * Arguments:
 * 0: Gozlemci <OBJECT>
 *
 * Return Value: None
 * Public: No
*/

params [["_obs", objNull, [objNull]]];
if (!isServer) exitWith {};

private _gon = remoteExecutedOwner;
if (_gon isEqualTo 0) then { _gon = clientOwner; };

if (isNull _obs || {!isPlayer _obs} || {(owner _obs) isNotEqualTo _gon}) exitWith {
    diag_log format ["[C2-TOPCU] IPTAL RED: gonderen / gozlemci uyusmuyor (gonderen %1)", _gon];
};

private _no = _obs getVariable [QGVAR(c2Gorev), -1];
_obs setVariable [QGVAR(c2Gorev), -1];
private _m = if (_no < 0) then { "[C2] TOPCU: iptal edilecek aktif gorev yok." } else {
    format ["[C2] TOPCU: gorev #%1 iptal - atmamis toplar durduruldu (havadaki mermiler geri alinamaz).", _no]
};
[_m] remoteExecCall ["systemChat", _gon];
diag_log format ["[C2-TOPCU] %1 | IPTAL gorev #%2", name _obs, _no];
