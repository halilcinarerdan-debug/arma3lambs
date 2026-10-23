#include "script_component.hpp"
/*
 * Author: Cinar (ELITE fork)
 * KESIF / KANAT ELEMANI (v8.308; kullanici: 'pusuya hizli tepki ve dronun geldigi yonu inceleme').
 * Grubun 2 (grup >= 4 ise) ya da 1 askerini tahmini bir noktaya gonderir; sure bitince gruba doner (doFollow).
 *   "KANAT"    : tahmini atici konumuna 70-110 m, tahmin ile grup arasi hattin +-60-85 derece yanina; hizli (FULL), hizlica ates altindaki grubu rahatlatir.
 *   "ISTIKSAF" : (dron operatoru yonu) lider -> hedef dogrultusunda, hedefe en fazla 150 m kala dur (80-300 m ilerler); NORMAL hiz, durdugunda hedefe bakar, 60 sn.
 * Secim: lider degil, saglikli, yaya, MG / AT roller disinda (en yakin 2), taktikKilit / forceMove / teslim / captive olmayan. Asker basina 90 sn'de bir.
 * Taktik kilidi (sure + 5 sn): LAMBS / ELITE hareket arbitraji bu askerlere dokunmaz.
 * Kapatma: lambs_danger_istiksafOff = true.   Log: [ISTIKSAF]
 *
 * Arguments:
 * 0: Grup <GROUP>
 * 1: Tahmini hedef noktasi <ARRAY>
 * 2: Mod "KANAT" / "ISTIKSAF" <STRING>
 * 3: Sure (sn) <NUMBER> (opsiyonel; varsayilan 40 / 60)
 *
 * Return Value: Gonderilen asker sayisi <NUMBER>
 * Public: No
*/

params [["_g", grpNull, [grpNull]], ["_est", [], [[]]], ["_mod", "KANAT", [""]], ["_sure", -1, [0]]];
if (isNull _g || {_est isEqualTo []} || {missionNamespace getVariable ["lambs_danger_istiksafOff", false]}) exitWith {0};
private _l = leader _g;
if (isNull _l || {!alive _l}) exitWith {0};
if (_sure < 0) then { _sure = [60, 40] select (_mod isEqualTo "KANAT"); };

private _rolFn = missionNamespace getVariable ["lambs_danger_fnc_getUnitRole", {"RIFLE"}];
private _aday = (units _g) select {
    _x isNotEqualTo _l && {alive _x} && {local _x} && {!isPlayer _x} && {isNull objectParent _x}
    && {(lifeState _x) in ["HEALTHY", "INJURED"]}
    && {!(_x getVariable [QGVAR(forceMove), false])} && {(_x getVariable [QGVAR(taktikKilit), 0]) <= time}
    && {!(_x getVariable [QGVAR(teslim), false])} && {!captive _x}
    && {time >= (_x getVariable [QGVAR(istiksafT), 0])}
    && {!(([_x] call _rolFn) in ["MG", "AT"])} && {(primaryWeapon _x) isNotEqualTo ""}
};
if (_aday isEqualTo []) exitWith {0};
private _lp = getPosATL _l;
private _kisi = _aday select [0, [1, 2] select ((count (units _g select {alive _x})) >= 4)];
_kisi = [_kisi, [], {_x distance2D _est}, "ASCEND"] call BIS_fnc_sortBy;

private _dist = _lp distance2D _est;
private _hedef = [];
if (_mod isEqualTo "KANAT") then {
    if (_dist >= 60) then {
        private _yan = selectRandom [-1, 1];
        _hedef = _est getPos [70 + random 40, (_est getDir _lp) + (_yan * (60 + random 25))];
    };
} else {
    if (_dist >= 120) then {
        private _ileri = ((_dist - 150) max 80) min 300;
        _hedef = _lp getPos [_ileri, (_lp getDir _est) + ((random 20) - 10)];
    };
};
if (_hedef isEqualTo [] || {surfaceIsWater _hedef} || {(_lp distance2D _hedef) > 400}) exitWith {0};

{
    private _u = _x;
    private _p = _hedef getPos [(_forEachIndex * 8), random 360];
    _u setVariable [QGVAR(taktikKilit), time + _sure + 5];
    _u setVariable [QGVAR(istiksafT), time + 90];
    _u forceSpeed -1;
    _u setSpeedMode ([ "NORMAL", "FULL" ] select (_mod isEqualTo "KANAT"));
    _u doMove _p;
    [{
        params ["_uu", "_hp", "_es"];
        !alive _uu || {(_uu distance2D _hp) < 6}
    }, {
        params ["_uu", "_hp", "_es"];
        if (alive _uu) then { _uu doWatch _es; };
    }, [_u, _p, _est], 40, {}] call CBA_fnc_waitUntilAndExecute;
    [{
        params ["_uu", "_gg"];
        if (alive _uu) then {
            _uu setVariable [QGVAR(taktikKilit), nil];
            _uu doWatch objNull;
            if (!isNull _gg && {!isNull (leader _gg)}) then { _uu doFollow (leader _gg); };
        };
    }, [_u, _g], _sure] call CBA_fnc_waitAndExecute;
} forEach _kisi;

diag_log format ["[ISTIKSAF] %1 | %2 | %3 asker | tahmin %4 m (%5 derece) | hedef %6 m ilerisi | %7 sn", groupId _g, _mod, count _kisi, round _dist, round (_lp getDir _est), round (_lp distance2D _hedef), _sure];
count _kisi
