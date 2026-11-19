#include "script_component.hpp"
/*
 * Author: Cinar (ELITE fork)
 * GARNIZON MU (v8.623; kullanici: 'cqb olayi garrisonda da olsun, gelis yonune bakma falan'): grup LAMBS Garrison gorevinde mi (lambs_main_currentTactic 'taskGarrison' ya da aktif waypoint script'i lambs_wp garrison)?
 * Garnizon askeri yerinde durur (PATH kapali); ELITE yalniz BAKIS katmanlarini (fnc_gelisYonu, fnc_duvarBakis; fnc_icBakisDenetci zaten senaryo kapisindan bagimsiz) acar, hareket eden CQB katmanlari (cqbCevik / yakinHareket / cqbKume) kapali kalir.
 *
 * Arguments:
 * 0: Grup <GROUP>
 *
 * Return Value: Garnizon mu <BOOL>
 * Public: No
*/

params [["_g", grpNull, [grpNull]]];
if (isNull _g) exitWith {false};
private _t = _g getVariable ["lambs_main_currentTactic", ""];
if (_t isEqualType "" && {((toLower _t) find "garrison") >= 0}) exitWith {true};
private _cur = (currentWaypoint _g) max 1;
private _w = (waypoints _g) select {((waypointName _x) find "ELITE") != 0 && {(_x select 1) >= _cur}};
(_w isNotEqualTo []) && {((toLower (waypointScript (_w select 0))) find "garrison") >= 0}
