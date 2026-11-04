#include "script_component.hpp"
/*
 * Author: Cinar (ELITE fork)
 * C2: BOT GRUBUNA EMRI UYGULA (v8.391; v8.392: waypoint'ler etiketli) — grubun YEREL oldugu makinede calisir (fnc_c2Emir sunucudan groupOwner'a gonderir). Dogrulama fnc_c2Emir'de yapilmistir.
 * C2 waypoint'leri 'C2: ...' aciklamasi tasir (Zeus'ta gorunur); YALNIZ bunlar silinir — plan ('ELITE PLAN: ...'), Zeus ve editor waypoint'lerine dokunulmaz.
 *   MOVE   : onceki C2 waypoint'leri silinir, hedefe MOVE waypoint (AWARE, NORMAL hiz, 25 m) ve gecerli yapilir
 *   SAD    : onceki C2 waypoint'leri silinir, hedefe SAD waypoint (COMBAT, combatMode RED) ve gecerli yapilir
 *   ROTA   : hedef, mevcut C2 rotasinin SONUNA MOVE waypoint olarak eklenir ('C2: ROTA n'); ilk nokta gecerli yapilir (birden cok nokta sirayla gezilir)
 *   TUT    : TUM waypoint'ler silinir (grup plana bagli degildir), grup yerinde doStop
 *   SERBEST: oyuncu komutasi kalkar (lambs_danger_oyuncuKomuta = nil), C2 waypoint'leri silinir, askerler lideri izler -> ELITE komutani yeniden karar verir
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

// yalniz 'C2:' aciklamali waypoint'ler (sondan basa: indeks kaymasin)
private _c2Sil = {
    params ["_gr"];
    private _w = +(waypoints _gr);
    reverse _w;
    { if (((waypointDescription _x) select [0, 3]) isEqualTo "C2:") then { deleteWaypoint _x; }; } forEach _w;
};

if (_emir isEqualTo "SERBEST") then {
    _g setVariable ["lambs_danger_oyuncuKomuta", nil, true];
    [_g] call _c2Sil;
    { if (alive _x) then { _x doFollow (leader _g); }; } forEach (units _g);
} else {
    _g setVariable ["lambs_danger_oyuncuKomuta", true, true];
    if (_emir isEqualTo "TUT") then {
        while { (count (waypoints _g)) > 0 } do { deleteWaypoint ((waypoints _g) select 0); };
        _g setBehaviour "AWARE";
        { if (alive _x) then { doStop _x; }; } forEach (units _g);
    } else {
        private _once = 0;
        if (_emir isEqualTo "ROTA") then {
            _once = { ((waypointDescription _x) select [0, 3]) isEqualTo "C2:" } count (waypoints _g);
        } else {
            [_g] call _c2Sil;
        };
        private _wp = _g addWaypoint [_poz, 0];
        _wp setWaypointCompletionRadius 25;
        _wp setWaypointDescription (if (_emir isEqualTo "ROTA") then {format ["C2: ROTA %1", _once + 1]} else {format ["C2: %1", _emir]});
        if (_emir isEqualTo "SAD") then {
            _wp setWaypointType "SAD";
            _wp setWaypointBehaviour "COMBAT";
            _wp setWaypointCombatMode "RED";
        } else {
            _wp setWaypointType "MOVE";
            _wp setWaypointBehaviour "AWARE";
            _wp setWaypointSpeed "NORMAL";
        };
        if (_emir isNotEqualTo "ROTA" || {_once isEqualTo 0}) then {
            { if (alive _x) then { _x doFollow (leader _g); }; } forEach (units _g);
            _g setCurrentWaypoint _wp;
        };
    };
};
diag_log format ["[C2-EMIR] UYGULANDI | %1 | %2 | hedef %3 | oyuncuKomuta %4 | waypoint %5", groupId _g, _emir, if (_poz isEqualTo []) then {"-"} else {mapGridPosition _poz}, _g getVariable ["lambs_danger_oyuncuKomuta", false], count (waypoints _g)];
