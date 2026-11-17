#include "script_component.hpp"
/*
 * Author: Cinar (ELITE fork)
 * KAPI BEKCISI (v8.506): yuruyen AI piyadenin 2.5 m onundeki kapali kapi / cit kapisi / ev kapisini acar (fnc_kapiAc). AI kapiyi yol sayip acmadigi icin kapida takiliyor / kapiya bakip kaliyordu
 * (RPT 2026-11-12: [DUVAR-KORUMA] NetFence_02 gate, rhs fence door gate, village_house_03).
 * KOSUL (1 sn'de bir, en fazla 14 asker, donusumlu): yerel, oyuncusuz, yaya, canli, hizi >= 1 km/s (yuruyor) ya da 'duvara bakiyor' (hareketsiz, 3 m onunde nesne), teslim / esir degil.
 * Waypoint / LAMBS gorevi gruplari da dahildir: kapiyi acmak rotayi degistirmez, yalniz gecisi saglar.
 * Kapatma: lambs_danger_kapiAcOff = true.  Log: [KAPI-AC] (ilk 30).
 *
 * Arguments: None
 * Return Value: Baslatildi mi <BOOL>
 * Public: No
*/

if (!isNil "lambs_danger_kapiBekciStarted") exitWith {false};
lambs_danger_kapiBekciStarted = true;
diag_log "[KAPI-AC] kapi bekcisi baslatildi (v8.506): yuruyen / kapiya bakan asker onundeki kapali kapiyi acar, ~20 sn sonra kapatir";

[] spawn {
    private _indeks = 0;
    while {true} do {
        sleep 1;
        if (missionNamespace getVariable ["lambs_danger_kapiAcOff", false]) then { continue };
        private _adaylar = allUnits select {
            local _x && {alive _x} && {!isPlayer _x} && {isNull objectParent _x} && {(side group _x) in [west, east, resistance]}
            && {(lifeState _x) in ["HEALTHY", "INJURED"]} && {!(_x getVariable [QGVAR(teslim), false])} && {!captive _x}
        };
        private _n = count _adaylar;
        if (_n > 0) then {
            private _kesit = 14 min _n;
            for "_i" from 0 to (_kesit - 1) do {
                private _u = _adaylar select ((_indeks + _i) mod _n);
                private _yuruyor = (speed _u) >= 1;
                private _eye = eyePos _u;
                private _yon = if (_yuruyor) then { vectorDir _u } else { eyeDirection _u };
                // v8.520: hizla yuruyen asker kapiya carpmasin (kapi animasyonu ~1.5 sn): bakis mesafesi 3 m + hiz x 1.2 sn (en cok 5 m)
                private _bakM = (3 + (((speed _u) / 3.6) * 1.2)) min 5;
                private _vur = lineIntersectsSurfaces [_eye, _eye vectorAdd (_yon vectorMultiply _bakM), _u, objNull, true, 3, "GEOM", "NONE"];
                if (!_yuruyor && {_vur isEqualTo []}) then { continue };
                {
                    private _o = _x select 2;
                    if (!isNull _o && {!(_o isKindOf "CAManBase")}) then { [_o, _u, 2.5 max (_bakM * 0.9)] call FUNC(kapiAc); };
                } forEach _vur;
                // ayak hizasinda da bak (cit kapisi alt kenari)
                if (_vur isEqualTo []) then {
                    private _ayak = (getPosASL _u) vectorAdd [0, 0, 0.6];
                    private _vur2 = lineIntersectsSurfaces [_ayak, _ayak vectorAdd ((vectorDir _u) vectorMultiply 2.5), _u, objNull, true, 2, "GEOM", "NONE"];
                    { private _o2 = _x select 2; if (!isNull _o2 && {!(_o2 isKindOf "CAManBase")}) then { [_o2, _u, 2.5] call FUNC(kapiAc); }; } forEach _vur2;
                };
            };
            _indeks = _indeks + _kesit;
        };
    };
};
true
