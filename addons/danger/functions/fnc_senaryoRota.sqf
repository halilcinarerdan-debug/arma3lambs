#include "script_component.hpp"
/*
 * Author: Cinar (ELITE fork)
 * SENARYO MODU ROTA BEKCISI (v8.502; kullanici: 'bounding / overwatch / arka kontrol / ileri gozcu kalsin ama farkli bir rotaya atmasin, senaryoyu zedelemesin').
 *
 * Senaryo modunda (fnc_senaryoKapi) tasarimci waypoint'i olan grup BOUNDING yaparken izlenir (2 sn'de bir):
 *   - bounding basladigi andaki konum + aktif waypoint kaydedilir;
 *   - lider, (baslangic -> waypoint) dogrusundan > 120 m YANA saparsa ya da waypoint'e uzaklik baslangica gore > 60 m ARTARSA (waypoint'ten uzaklasiyor) bounding IPTAL edilir:
 *     isBounding bayragi kaldirilir (bounding dongusu temizlikle kendisi cikar), grup waypoint'ine dondurulur (setCurrentWaypoint).
 * Bounding'in kendisi (siperden siper ates-hareket) ve arka / yan emniyet / nokta elemani / ileri gozcu SERBEST (lidere gore konumlanir, rota degistirmez). Bounding sonu 'hucum devri' senaryo modunda kapali.
 * Esikler TASARIM degeri (kitapta sayi yok). Log: [SENARYO-ROTA] (ilk 30).
 *
 * Arguments: None
 * Return Value: Baslatildi mi <BOOL>
 * Public: No
*/

if (!isNil "lambs_danger_senaryoRotaStarted") exitWith {false};
lambs_danger_senaryoRotaStarted = true;

[] spawn {
    private _logN = 0;
    while {true} do {
        sleep 2;
        {
            private _g = _x;
            if (isNull _g || {!local _g} || {!(_g getVariable [QGVAR(isBounding), false])}) then { _g setVariable [QGVAR(senRotaBas), nil]; continue };
            if !([_g, "rotaBekci"] call FUNC(senaryoKapi)) then { continue };
            // aktif tasarimci waypoint'i (en kucuk indeks >= currentWaypoint)
            private _cur = currentWaypoint _g;
            private _w = (waypoints _g) select { ((waypointName _x) find "ELITE") != 0 && {(_x select 1) > 0} && {(_x select 1) >= _cur} };
            if (_w isEqualTo []) then { continue };
            private _wp = waypointPosition (_w select 0);
            if (_wp isEqualTo [0, 0, 0]) then { continue };
            private _lp = getPosATL (leader _g);
            private _bas = _g getVariable [QGVAR(senRotaBas), []];
            if (_bas isEqualTo [] || {(_bas select 2) isNotEqualTo (_g getVariable [QGVAR(bndToken), ""])}) then {
                _g setVariable [QGVAR(senRotaBas), [_lp, _lp distance2D _wp, _g getVariable [QGVAR(bndToken), ""]]];
                continue
            };
            _bas params ["_bp", "_bd"];
            // lider -> (baslangic -> waypoint) dogrusuna dik uzaklik
            private _dir = _bp getDir _wp;
            private _rel = _bp getDir _lp;
            private _yan = abs (((_bp distance2D _lp) * (sin (_rel - _dir))));
            private _artis = (_lp distance2D _wp) - _bd;
            if (_yan > 120 || {_artis > 60}) then {
                _g setVariable [QGVAR(isBounding), nil];
                _g setVariable [QGVAR(senRotaBas), nil];
                [{ params ["_gg", "_ci"]; if (!isNull _gg && {(count (waypoints _gg)) > _ci}) then { _gg setCurrentWaypoint [_gg, _ci]; }; }, [_g, _cur], 2] call CBA_fnc_waitAndExecute;
                if (_logN < 30) then {
                    _logN = _logN + 1;
                    diag_log format ["[SENARYO-ROTA] %1 | bounding rotadan sapti (yana %2 m, waypoint'ten +%3 m) -> bounding iptal, waypoint'e donuyor", groupId _g, round _yan, round _artis];
                };
            };
        } forEach allGroups;
    };
};
true
