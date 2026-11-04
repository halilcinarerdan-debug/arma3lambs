#include "script_component.hpp"
/*
 * Author: Cinar (ELITE fork)
 * C2: BOT GRUBUNA EMRI UYGULA (v8.391) — grubun YEREL oldugu makinede calisir (fnc_c2Emir sunucudan groupOwner'a gonderir). Dogrulama fnc_c2Emir'de yapilmistir.
 *   MOVE   : tum waypoint silinir, hedefe MOVE waypoint (AWARE, NORMAL hiz, 25 m)
 *   SAD    : hedefe SAD waypoint (COMBAT, dusman ara / imha; combatMode RED)
 *   TUT    : waypoint silinir, grup yerinde doStop
 *   SERBEST: oyuncu komutasi kalkar (lambs_danger_oyuncuKomuta = nil), waypoint silinir, askerler lideri izler -> ELITE komutani yeniden karar verir
 *
 * Arguments:
 * 0: Grup <GROUP>
 * 1: Emir <STRING>
 * 2: Hedef konum <ARRAY>
 *
 * Return Value: None
 * Public: No
*/

params [["_g", grpNull, [grpNull]], ["_emir", "", [""]], ["_poz", [], [[]]]];
if (isNull _g || {!local _g}) exitWith {};

while { (count (waypoints _g)) > 0 } do { deleteWaypoint ((waypoints _g) select 0); };

if (_emir isEqualTo "SERBEST") then {
    _g setVariable ["lambs_danger_oyuncuKomuta", nil, true];
    { if (alive _x) then { _x doFollow (leader _g); }; } forEach (units _g);
} else {
    _g setVariable ["lambs_danger_oyuncuKomuta", true, true];
    if (_emir isEqualTo "TUT") then {
        _g setBehaviour "AWARE";
        { if (alive _x) then { doStop _x; }; } forEach (units _g);
    } else {
        private _wp = _g addWaypoint [_poz, 0];
        _wp setWaypointCompletionRadius 25;
        if (_emir isEqualTo "SAD") then {
            _wp setWaypointType "SAD";
            _wp setWaypointBehaviour "COMBAT";
            _wp setWaypointCombatMode "RED";
        } else {
            _wp setWaypointType "MOVE";
            _wp setWaypointBehaviour "AWARE";
            _wp setWaypointSpeed "NORMAL";
        };
        { if (alive _x) then { _x doFollow (leader _g); }; } forEach (units _g);
        _g setCurrentWaypoint _wp;
    };
};
diag_log format ["[C2-EMIR] UYGULANDI | %1 | %2 | hedef %3 | oyuncuKomuta %4", groupId _g, _emir, if (_poz isEqualTo []) then {"-"} else {mapGridPosition _poz}, _g getVariable ["lambs_danger_oyuncuKomuta", false]];
