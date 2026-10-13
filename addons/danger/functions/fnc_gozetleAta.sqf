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
                    _x doMove _p;
                    _x doWatch (_merkez getPos [150, _a]);
                    _x setUnitPos "MIDDLE";
                } forEach _us;
                if (_yerlesti isNotEqualTo _mk) then { diag_log format ["[GOZETLE] %1 | %2 noktasina yerlesiyor (%3 asker, yaricap %4 m)", groupId _g2, markerText _mk, _n, round _r]; };
                _yerlesti = _mk;
            };
        };
        sleep 20;
    };
    _g2 setVariable ["lambs_danger_gozetleDongu", nil];
};
