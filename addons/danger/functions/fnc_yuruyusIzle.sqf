#include "script_component.hpp"
/*
 * Author: Cinar (ELITE fork)
 * YURUNEBILIR ALAN BEKCISI (v8.331) — kullanici: 'yogun objeli trench'ler icin 3D editorden alan koyabilelim, ustunde yurusebilsin AI'. AI yol bulma, cok sayida nesneyle (kum torbasi / tahta / siper parcasi) dolu hendege YOL BULAMAZ; asker kenarda
 * ya da alanin icinde dakikalarca durur. Eden 'ELITE Yurunebilir Alan' modulunun alani (fnc_yuruyusAlani) icinde / en fazla 12 m yaninda olan YEREL AI yaya askerde:
 *   TESPIT (0.5 sn'de bir): hareket emri (currentCommand MOVE), hedef > 2.5 m, asker 2.5 sn boyunca < 0.4 m ilerlemis; hedef alanda (<= 3 m) ya da asker alanda.
 *   YURUTME: PATH kapanir; 0.05 sn adimla (yurume 1.7 / comelme 1.2 m/sn) hedefe dogru konum ADIM ADIM ilerletilir (setPosASL); her adimda nesne ustu yuksekligi aranir
 *   (lineIntersectsSurfaces GEOM; en cok +0.9 m tirmanma, -3 m dusme; adim basina z degisimi <= 0.35 m) -> asker nesnelerin USTUNDEN yurur. Yurume animasyonu playMoveNow. Hedefe varinca / alan disina 4 m cikinca / zaman asiminda PATH acilir.
 * Alan disinda hicbir sey yapmaz; kapatma: lambs_danger_yuruyusOff = true ya da CBA 'Yurunebilir alan'. Log: [YURUYUS] (ilk 40).
 *
 * Arguments: None
 * Return Value: Baslatildi mi <BOOL>
 * Public: No
*/

if (!isNil "lambs_danger_yuruyusStarted") exitWith {false};
lambs_danger_yuruyusStarted = true;
diag_log "[YURUYUS] yurunebilir alan bekcisi baslatildi (v8.331): Eden 'ELITE Yurunebilir Alan' modulu alaninda nesne ustunden betikle yurume";

private _calis = {
    private _logN = 0;
    while {true} do {
        sleep 0.5;
        if (missionNamespace getVariable ["lambs_danger_yuruyusOff", false] || {!(missionNamespace getVariable ["lambs_danger_yuruyusAktif", true])}) then { sleep 5; continue };
        private _alanlar = ["LISTE"] call FUNC(yuruyusAlani);
        if (_alanlar isEqualTo []) then { sleep 5; continue };
        {
            private _u = _x;
            if (_u getVariable [QGVAR(yurAktif), false]) then { continue };
            if ((currentCommand _u) isNotEqualTo "MOVE") then { _u setVariable [QGVAR(yurSon), nil]; continue };
            private _en = ["MESAFE", getPosATL _u] call FUNC(yuruyusAlani);
            if ((_en select 0) < 0 || {(_en select 1) > 12}) then { _u setVariable [QGVAR(yurSon), nil]; continue };
            private _dest = (expectedDestination _u) select 0;
            if (_dest isEqualTo [0, 0, 0] || {(_u distance2D _dest) < 2.5}) then { _u setVariable [QGVAR(yurSon), nil]; continue };
            private _destAlan = ["MESAFE-ALAN", _dest, _en select 0] call FUNC(yuruyusAlani);
            if ((_en select 1) > 0 && {_destAlan > 3}) then { _u setVariable [QGVAR(yurSon), nil]; continue };
            // takilma: 2.5 sn'de < 0.4 m
            private _son = _u getVariable [QGVAR(yurSon), [[0, 0, 0], -1]];
            if ((_son select 1) < 0 || {(_u distance2D (_son select 0)) > 0.4}) then {
                _u setVariable [QGVAR(yurSon), [getPosATL _u, time]];
                continue
            };
            if ((time - (_son select 1)) < 2.5) then { continue };

            // ---- YURUME ----
            _u setVariable [QGVAR(yurAktif), true];
            _u setVariable [QGVAR(yurSon), nil];
            if (_logN < 40) then {
                _logN = _logN + 1;
                diag_log format ["[YURUYUS] %1 | %2 | alan %3 | takildi (2.5 sn < 0.4 m), hedefe %4 m: nesne ustunden betikle yuruyor | alana %5 m, hedef alana %6 m", name _u, groupId (group _u), _en select 0, round (_u distance2D _dest), round (_en select 1), round _destAlan];
            };
            [_u, _dest, _en select 0, _destAlan <= 3] spawn {
                params ["_u", "_dest", "_idx", "_destAlanda"];
                private _adim = 0.05;
                private _stance = unitPos _u;
                private _comel = (stance _u) in ["CROUCH"];
                private _hiz = [1.7, 1.2] select _comel;
                private _tirmanma = 0.9;
                private _silahli = (primaryWeapon _u) isNotEqualTo "" && {(currentWeapon _u) isEqualTo (primaryWeapon _u)};
                private _anim = if (_silahli) then { ["AmovPercMwlkSrasWrflDf", "AmovPknlMwlkSrasWrflDf"] select _comel } else { ["AmovPercMwlkSnonWnonDf", "AmovPknlMwlkSnonWnonDf"] select _comel };
                if ((stance _u) isEqualTo "PRONE") then { _u setUnitPos "MIDDLE"; };
                _u disableAI "PATH";
                private _t0 = time;
                private _sure = ((_u distance2D _dest) / _hiz) * 1.8 + 6;
                private _animT = 0;
                private _tOnce = diag_tickTime;
                private _neden = "zaman asimi";
                while {time < (_t0 + _sure)} do {
                    if (!alive _u || {!local _u} || {!isNull objectParent _u} || {!((lifeState _u) in ["HEALTHY", "INJURED"])}) exitWith { _neden = "asker durumu"; };
                    if (missionNamespace getVariable ["lambs_danger_yuruyusOff", false]) exitWith { _neden = "kapatildi"; };
                    private _kalan = _u distance2D _dest;
                    if (_kalan < 1.0) exitWith { _neden = "vardi"; };
                    if (!_destAlanda && {(["MESAFE-ALAN", getPosATL _u, _idx] call FUNC(yuruyusAlani)) > 4}) exitWith { _neden = "alandan cikti"; };
                    if (time > _animT) then { _animT = time + 1.5; _u playMoveNow _anim; };
                    private _yon = _u getDir _dest;
                    _u setDir _yon;
                    private _p = getPosASL _u;
                    private _dt = ((diag_tickTime - _tOnce) max 0.01) min 0.2;   // gercek kare suresi (dusuk FPS'te hiz sabit kalir)
                    _tOnce = diag_tickTime;
                    private _nx = (_p select 0) + ((sin _yon) * _hiz * _dt);
                    private _ny = (_p select 1) + ((cos _yon) * _hiz * _dt);
                    private _ust = lineIntersectsSurfaces [[_nx, _ny, (_p select 2) + _tirmanma], [_nx, _ny, (_p select 2) - 3], _u, objNull, true, 1, "GEOM", "NONE"];
                    private _z = if (_ust isNotEqualTo []) then { ((_ust select 0) select 0) select 2 } else { getTerrainHeightASL [_nx, _ny] };
                    _z = (_p select 2) + (((_z - (_p select 2)) max -0.35) min 0.35);
                    _u setPosASL [_nx, _ny, _z];
                    sleep _adim;
                };
                if (!isNull _u) then {
                    _u enableAI "PATH";
                    _u setVariable [QGVAR(yurAktif), nil];
                    if (alive _u) then { _u setUnitPos _stance; };
                    diag_log format ["[YURUYUS] %1 | bitti: %2 | %3 sn | hedefe kalan %4 m", name _u, _neden, round (time - _t0), round (_u distance2D _dest)];
                };
            };
        } forEach (allUnits select {local _x && {alive _x} && {!isPlayer _x} && {isNull objectParent _x} && {(lifeState _x) in ["HEALTHY", "INJURED"]}});
    };
};
[] spawn _calis;
true
