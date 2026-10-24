#include "script_component.hpp"
/*
 * Author: Cinar (ELITE fork)
 * GOZETLEME ATAMASI (v8.214; kullanici: "hq birimlerinin hangileri hangi mevzi / karakol gozetlemeye gidebilir ayarlayabilelim") — sunucu tarafi.
 * Grup, secilen karakol / mevzi isaretinin yaricapi icinde nobet tutar: gider, dagilir, dis cevreye bakar; temasta LAMBS/ELITE dovusur, temas bitince (8 sn) noktaya doner.
 * Atanan grup planlara alinmaz (lambs_danger_gorev = HARIC; kaldirinca eski deger). Kaldirma: marker "" ile.
 * Hedef noktanin yaricapi lambs_danger_karakollar kaydindan okunur (yoksa 60 m).
 *
 * Arguments:
 * 0: Grup <GROUP>
 * 1: Karakol isaret adi (bos = kaldir) <STRING>
 *
 * Return Value: Yok
 * Public: No
*/

params [["_g", grpNull, [grpNull]], ["_mn", "", [""]]];
if (!isServer || {isNull _g}) exitWith {};

if (_mn isEqualTo "") exitWith {
    if ((_g getVariable ["lambs_danger_gozetleme", ""]) isNotEqualTo "") then {
        _g setVariable ["lambs_danger_gorev", _g getVariable ["lambs_danger_gozetlemeEskiGorev", ""], true];
        _g setVariable ["lambs_danger_gozetleme", nil, true];
        diag_log format ["[GOZETLE] %1 | nobet KALDIRILDI", groupId _g];
    };
};

if ((markerPos _mn) isEqualTo [0, 0, 0]) exitWith { diag_log format ["[GOZETLE] %1 | isaret bulunamadi: %2", groupId _g, _mn]; };
if ((_g getVariable ["lambs_danger_gozetleme", ""]) isEqualTo "") then { _g setVariable ["lambs_danger_gozetlemeEskiGorev", _g getVariable ["lambs_danger_gorev", ""]]; };
_g setVariable ["lambs_danger_gozetleme", _mn, true];
_g setVariable ["lambs_danger_gorev", "HARIC", true];
private _kayit = (missionNamespace getVariable ["lambs_danger_karakollar", []]) select {(_x select 5) isEqualTo _mn};
private _yar = if (_kayit isEqualTo []) then {60} else {((_kayit select 0) select 2) max 30};
diag_log format ["[GOZETLE] %1 | nobet atandi: %2 (%3) yaricap %4 m", groupId _g, markerText _mn, mapGridPosition (markerPos _mn), _yar];

if (_g getVariable ["lambs_danger_gozetleDongu", false]) exitWith {};   // dongu zaten calisiyor (hedef degisimi degiskenden okunur)
_g setVariable ["lambs_danger_gozetleDongu", true];

[_g] spawn {
    params ["_g2"];
    private _yerlesti = "";
    while {({alive _x} count (units _g2)) > 0 && {(_g2 getVariable ["lambs_danger_gozetleme", ""]) isNotEqualTo ""}} do {
        private _mk = _g2 getVariable ["lambs_danger_gozetleme", ""];
        private _merkez = markerPos _mk;
        private _kyt = (missionNamespace getVariable ["lambs_danger_karakollar", []]) select {(_x select 5) isEqualTo _mk};
        private _r = if (_kyt isEqualTo []) then {60} else {((_kyt select 0) select 2) max 30};
        private _temasta = (_g2 getVariable ["lambs_danger_contact", 0]) > time;
        if (local _g2 && {!_temasta} && {!(_g2 getVariable ["lambs_danger_tasimaBekle", false])}) then {
            private _uzak = ((units _g2) select {alive _x && {isNull objectParent _x}}) select {(_x distance2D _merkez) > (_r + 25)};
            if (_yerlesti isNotEqualTo _mk || {_uzak isNotEqualTo []}) then {
                // yerlesim: her asker cevre halkasinda kendi sektorunde, disa bakar
                private _us = (units _g2) select {alive _x && {isNull objectParent _x} && {!isPlayer _x}};
                private _n = count _us max 1;
                _g2 setBehaviour "AWARE"; _g2 setSpeedMode "NORMAL";
                {
                    private _a = (360 / _n) * _forEachIndex;
                    private _p = _merkez getPos [(_r * 0.6) min 40, _a];
                    _x enableAI "PATH"; _x enableAI "MOVE";
                    _x setVariable [QGVAR(yurHedef), [_p, time]];
                    _x doMove _p;
                    _x doWatch (_merkez getPos [150, _a]);
                    _x setUnitPos "MIDDLE";
                } forEach _us;
                if (_yerlesti isNotEqualTo _mk) then { diag_log format ["[GOZETLE] %1 | %2 noktasina yerlesiyor (%3 asker, yaricap %4 m)", groupId _g2, markerText _mk, _n, round _r]; };
                _yerlesti = _mk;
            };
        };
        // v8.216 ARAC GRUPLARI (kullanici: "tank atandigi karakola gitmedi" — piyade dongusu aractakileri atliyordu): surucu araci noktanin icine surer, durunca nisanci disa bakar
        if (local _g2 && {!_temasta}) then {
            private _araclar = [];
            { private _av = vehicle _x; if (_av isNotEqualTo _x && {_av isKindOf "LandVehicle"} && {alive _av}) then { _araclar pushBackUnique _av; }; } forEach (units _g2);
            {
                private _av = _x;
                private _sr = driver _av;
                if (!isNull _sr && {alive _sr} && {local _sr} && {!isPlayer _sr}) then {
                    private _hp = _av getVariable ["lambs_danger_gozetlePoz", []];
                    if (_hp isEqualTo [] || {(_av getVariable ["lambs_danger_gozetleMk", ""]) isNotEqualTo _mk}) then {
                        _hp = [_merkez, 0, (_r * 0.6) min 80, 7, 0, 0.3, 0] call BIS_fnc_findSafePos;
                        _av setVariable ["lambs_danger_gozetlePoz", _hp];
                        _av setVariable ["lambs_danger_gozetleMk", _mk];
                        _av setVariable ["lambs_danger_gozetleT", time];
                        _av setVariable ["lambs_danger_gozetleKonum", getPosATL _av];
                        diag_log format ["[GOZETLE-ARAC] %1 | %2 -> %3 (noktaya %4 m, hedef konum %5)", groupId _g2, getText (configOf _av >> "displayName"), markerText _mk, round (_av distance2D _merkez), mapGridPosition _hp];
                    };
                    if ((_av distance2D _hp) > 30) then {
                        _sr enableAI "PATH"; _sr enableAI "MOVE"; _sr forceSpeed -1;
                        (group _sr) setBehaviour "AWARE"; (group _sr) setSpeedMode "NORMAL";
                        _sr doMove _hp;
                        // 45 sn'de 5 m'den az ilerlediyse: motor + itme + en yakin yola yonlendirme (TASIMA 18 sn kurtarmasiyla ayni), log
                        if ((time - (_av getVariable ["lambs_danger_gozetleT", time])) > 45) then {
                            if ((_av distance2D (_av getVariable ["lambs_danger_gozetleKonum", getPosATL _av])) < 5) then {
                                _av engineOn true;
                                private _yl = (getPosATL _av) nearRoads 200;
                                if (_yl isNotEqualTo []) then { _sr doMove (getPosATL (([_yl, [], {(_x distance2D _hp)}, "ASCEND"] call BIS_fnc_sortBy) select 0)); };
                                _av setVelocityModelSpace [0, 6, 0];
                                diag_log format ["[GOZETLE-ARAC] %1 | %2 45 sn ilerlemedi (noktaya %3 m): motor + itme + yola yonlendirme | komut %4", groupId _g2, getText (configOf _av >> "displayName"), round (_av distance2D _hp), currentCommand _sr];
                            };
                            _av setVariable ["lambs_danger_gozetleT", time];
                            _av setVariable ["lambs_danger_gozetleKonum", getPosATL _av];
                        };
                    } else {
                        if (!(_av getVariable ["lambs_danger_gozetleVardi", false])) then {
                            _av setVariable ["lambs_danger_gozetleVardi", true];
                            doStop _sr;
                            private _dir = (_merkez getDir _hp) + 180;
                            // v8.244 (RPT c7592408: EAST T-90 gozetleme noktasina vardi ve dusmanin geldigi yonun TERSINE, 259 derece gozetledi): bilinen dusman varsa ona, yoksa ayni taraftaki planin tehdit yonune bak
                            private _enG = _sr findNearestEnemy _sr;
                            if (!isNull _enG) then { _dir = _av getDir _enG; } else {
                                private _pl = (values (missionNamespace getVariable ["lambs_danger_planlar", createHashMap])) select {(_x getOrDefault ["taraf", sideUnknown]) isEqualTo (side _g2) && {(_x getOrDefault ["tehditB", -1]) >= 0}};
                                if (_pl isNotEqualTo []) then { _dir = (_pl select 0) get "tehditB"; };
                            };
                            { if (alive _x) then { _x doWatch (_av getPos [300, _dir]); }; } forEach ((crew _av) select {_x isNotEqualTo _sr});
                            diag_log format ["[GOZETLE-ARAC] %1 | %2 noktaya VARDI (%3 m), %4 derece gozetliyor", groupId _g2, getText (configOf _av >> "displayName"), round (_av distance2D _merkez), round _dir];
                        };
                    };
                    if ((_av distance2D _hp) > 30) then { _av setVariable ["lambs_danger_gozetleVardi", false]; };
                };
            } forEach _araclar;
        };
        sleep 20;
    };
    _g2 setVariable ["lambs_danger_gozetleDongu", nil];
};
