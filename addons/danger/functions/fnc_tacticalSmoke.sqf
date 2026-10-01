#include "script_component.hpp"
/*
 * Author: Cinar (ELITE fork)
 * Taktik sis kullanimi. Eskiden sis dogrudan DUSMANIN uzerine / rastgele atiliyordu.
 *
 *   COVER_MOVE     : hucum/bounding — sis dusmana dogru, hareket eden birligin onune
 *                    (dusman gorusunu keser). Sorumlu: MG olmayan, sisi olan en yakin asker.
 *   BREAK_CONTACT  : geri cekilme/temas kesme — sis grup ile dusman ARASINA, daha yakina;
 *                    2 atici varsa 5 sn arayla 2 sis (derin perde).
 *
 * Kurallar:
 *   - grup basina 45 sn cooldown
 *   - tehdit 30m'den yakinsa (CQB) veya 400m'den uzaksa atilmaz
 *   - ruzgar telafisi (sis ruzgar yonune kayar -> 3 sn "ruzgar ustu" nisan)
 *   - sadece beyaz/standart sis (kirmizi/yesil/mavi sinyal sisleri atilmaz)
 *   - GVAR(disableAutonomousSmokeGrenades) ayari saygi gorur
 *
 * Arguments:
 * 0: group <GROUP> or leader <OBJECT>
 * 1: tehdit <OBJECT> or position <ARRAY>
 * 2: mod <STRING> "COVER_MOVE" | "BREAK_CONTACT" (default "COVER_MOVE")
 *
 * Return Value:
 * Sis atildi mi <BOOL>
 *
 * Public: No
*/

params [
    ["_group", grpNull, [grpNull, objNull]],
    ["_target", objNull, [objNull, []]],
    ["_mode", "COVER_MOVE", [""]]
];

if (_group isEqualType objNull) then {_group = group _group;};
if (isNull _group) exitWith {false};
private _rolFn = missionNamespace getVariable ["lambs_danger_fnc_getUnitRole", {"RIFLE"}];
if (GVAR(disableAutonomousSmokeGrenades)) exitWith {false};

// cooldown
if ((time - (_group getVariable [QGVAR(smokeLast), -999])) < 45) exitWith {false};

private _targetPos = _target call CBA_fnc_getPos;
if ((_targetPos select 2) > 6) then {_targetPos set [2, 0];};

private _leader = leader _group;
if (isNull _leader) exitWith {false};

private _mesafe = _leader distance2D _targetPos;
if (_mesafe < 30 || {_mesafe > 400}) exitWith {false};

// ---------------------------------------------------------------------------
// SIS TASIYANLAR — standart sis, ayakta, MG degil
// ---------------------------------------------------------------------------
private _sisliMi = {
    params ["_u"];
    ((magazines _u) findIf {
        private _ammo = getText (configFile >> "CfgMagazines" >> _x >> "ammo");
        (_ammo isNotEqualTo "")
        && {_ammo isKindOf ["SmokeShell", configFile >> "CfgAmmo"]}
        && {(_ammo find "Red") < 0} && {(_ammo find "Green") < 0} && {(_ammo find "Blue") < 0}
        && {(_ammo find "Yellow") < 0} && {(_ammo find "Purple") < 0} && {(_ammo find "Orange") < 0}
    }) > -1
};

private _aticilar = (units _group) select {
    alive _x
    && {isNull objectParent _x}
    && {!isPlayer _x}
    && {([_x] call _rolFn) isNotEqualTo "MG"}
    && {[_x] call _sisliMi}
};
if (_aticilar isEqualTo []) exitWith {false};

// tehdide en yakin (en onde) olandan basla
_aticilar = [_aticilar, [], {_x distance2D _targetPos}, "ASCEND"] call BIS_fnc_sortBy;

_group setVariable [QGVAR(smokeLast), time];

private _mod = _mode;
[_aticilar, _targetPos, _mod] spawn {
    params ["_aticilar", "_targetPos", "_mod"];

    private _atisSayisi = if (_mod isEqualTo "BREAK_CONTACT") then { 2 min (count _aticilar) } else { 1 };

    for "_i" from 0 to (_atisSayisi - 1) do {
        private _atici = _aticilar select _i;
        if (!alive _atici || {!isNull objectParent _atici}) then { continue };

        private _aticiPos = getPosATL _atici;
        private _hedefMesafe = _atici distance2D _targetPos;
        private _yon = _aticiPos getDir _targetPos;

        // El bombasi menzili ~38m
        private _atisMesafe = if (_mod isEqualTo "BREAK_CONTACT") then {
            ((_hedefMesafe * 0.4) max 20) min 32
        } else {
            ((_hedefMesafe * 0.65) max 22) min 38
        };
        // 2. sis biraz daha yakin = derin perde
        if (_i > 0) then { _atisMesafe = (_atisMesafe - 8) max 15; };

        private _sisPos = _aticiPos getPos [_atisMesafe, _yon];

        // ruzgar telafisi: sis ruzgar yonune kayar -> ruzgar ustune nisan al
        private _ruzgar = wind;
        _sisPos = _sisPos vectorAdd [-(_ruzgar select 0) * 3, -(_ruzgar select 1) * 3, 0];
        _sisPos set [2, 0];

        if (!surfaceIsWater _sisPos) then {
            [_atici, _sisPos] call EFUNC(main,doSmoke);

            if (EGVAR(main,debug_functions)) then {
                diag_log format [
                    "[SIS] %1 | mod:%2 | atis:%3 | tehdit:%4m | sis:%5m",
                    name _atici, _mod, _i + 1, round _hedefMesafe, round _atisMesafe
                ];
            };
        };

        if (_i < (_atisSayisi - 1)) then { sleep 5; };
    };
};

true
