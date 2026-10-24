#include "script_component.hpp"
/*
 * Author: Cinar (ELITE fork)
 * GOZLEMCININ GORDUKLERI (v8.342) — ileri gozlemcinin (dron ya da yerdeki lider) o an gordugu dusman nesneleri.
 *   DRON : fnc_ihaGozlem'in yazdigi 'lambs_danger_ihaGorulen' [zaman, nesneler] (dronun gercek algisi).
 *   ASKER: kendi nearTargets (1800 m) listesi; dusman, canli, >= 300 m (tufek catismasi disi), knowsAbout >= 1.0 ve GORUS HATTI ACIK (checkVisibility >= 0.3). Haritadan konum OKUNMAZ.
 *   Yaralanmis / baygin / olu gozlemci bos liste verir.
 *
 * Arguments:
 * 0: Gozlemci <OBJECT>
 * 1: Gozlemcinin tarafi <SIDE>
 *
 * Return Value: [zaman <NUMBER>, nesneler <ARRAY>]
 * Public: No
*/

params [["_fo", objNull, [objNull]], ["_taraf", sideUnknown, [sideUnknown]]];
if (isNull _fo) exitWith {[-99, []]};
if !(_fo isKindOf "CAManBase") exitWith { _fo getVariable ["lambs_danger_ihaGorulen", [-99, []]] };
if (!alive _fo || {!((lifeState _fo) in ["HEALTHY", "INJURED"])}) exitWith {[-99, []]};
private _goz = eyePos _fo;
[time, ((_fo nearTargets 1800) select {
    private _o = _x select 4;
    !isNull _o && {alive _o} && {(_taraf getFriend (_x select 2)) < 0.6} && {(_o distance2D _fo) >= 300} && {(_fo knowsAbout _o) >= 1.0}
    && {(_fo checkVisibility [_goz, (getPosASL _o) vectorAdd [0, 0, 1.2]]) >= 0.3}
}) apply {_x select 4}]
