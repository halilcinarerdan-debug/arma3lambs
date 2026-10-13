#include "script_component.hpp"
/*
 * Author: Cinar (ELITE fork)
 * ARAC KOMUTANI DUZELTME (v8.215) — HIPOTEZ (RPT ceaca545): recon Stryker'da surucu (Clark) + nisanci (Halliwell) arac grubundan, ama TURET / KOMUTAN koltugunda baska gruptan (recon) bir yolcu (Edwards) oturuyordu
 * (effectiveCommander = Edwards). AI arac, komutani olan yolcunun grubunun emirlerine uyar; surucuye verdigimiz doMove / waypoint yok sayilir ("hedef DoNotPlan", 60 m yakin hedef bile 0 m).
 * Cozum: arac grubundan OLMAYAN AI asker komutan / nisanci / turet koltugundaysa kargo koltuguna alinir (bos kargo varsa). Arac grubundan biri komutan olur (nisanci).
 * Log: [ARAC-KOMUTAN]
 *
 * Arguments:
 * 0: Arac <OBJECT>
 * 1: Arac grubu (surucunun grubu) <GROUP>
 *
 * Return Value: Tasinan yabanci asker sayisi <NUMBER>
 * Public: No
*/

params [["_v", objNull, [objNull]], ["_vg", grpNull, [grpNull]]];
if (isNull _v || {isNull _vg} || {!alive _v}) exitWith {0};

private _yabanci = (fullCrew [_v, "", false]) select {
    private _u = _x select 0;
    (toLower (_x select 1)) in ["commander", "gunner", "turret"] && {alive _u} && {!isPlayer _u} && {(group _u) isNotEqualTo _vg} && {local _u}
};
private _n = 0;
{
    private _u = _x select 0;
    if ((_v emptyPositions "cargo") > 0) then {
        private _eski = _x select 1;
        moveOut _u;
        _u assignAsCargo _v;
        _u moveInCargo _v;
        _n = _n + 1;
        diag_log format ["[ARAC-KOMUTAN] %1 | %2 | yabanci grup askeri %3 (%4) %5 koltugundaydi -> kargo koltuguna alindi (arac komutani arac grubundan olsun)", groupId _vg, getText (configOf _v >> "displayName"), name _u, groupId (group _u), _eski];
    };
} forEach _yabanci;
_n
