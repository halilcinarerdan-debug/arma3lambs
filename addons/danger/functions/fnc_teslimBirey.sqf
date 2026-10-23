#include "script_component.hpp"
/*
 * Author: Cinar (ELITE fork)
 * BIREYSEL TESLIM (v8.308; kullanici: 'eger bireysel olarak karsilik veremeyecekse teslim olsun o asker').
 * Grup teslimi (fnc_moral) grup coktugunde olur; bu izleyici TEK askeri degerlendirir (5 sn'de bir, yerel, oyuncusuz, yaya):
 *   KARSILIK VEREMEZ = tufek / tabanca yok YA DA ikisinde de atilabilir mermi yok (silahta mermi 0 ve uyumlu sarjor yok; compatibleMagazines ile magazineWell dahil). Roketatar sayilmaz.
 *   TEHDIT = (a) bilinen (knowsAbout >= 0.8) dusman <= 120 m  VEYA  (b) dusman IHA <= 300 m  VEYA  (c) baski >= 0.35 ve bilinen dusman <= 300 m
 *   2 ardisik tur (10 sn) kosul sureklilik -> asker teslim olur: setCaptive, silah birakir / alinir, AI kapatilir, ACE yukluyse ace_captives_fnc_setSurrendered (kelepce / refakat uyumlu).
 *   Lider teslim olacaksa once grupta saglikli, silahli baska bir asker lider yapilir (grup yonetimi bozulmasin).
 * Izin: fnc_moral ile ayni (ana anahtar, fraksiyon listeleri, taraf onay kutusu, doktrin / duzensiz). CBA: lambs_danger_teslimBirey (varsayilan acik).
 * Esir bakimi: grup teslimOldu degilse bu izleyici teslim olan askerlerin silahini alir / AI'sini kapali tutar (ACE kelepcelediyse karismaz).
 * Log: [TESLIM-BIREY]
 *
 * Return Value: Baslatildi mi <BOOL>
 * Public: No
*/

if (!isNil "lambs_danger_teslimBireyStarted") exitWith {false};
lambs_danger_teslimBireyStarted = true;
diag_log "[TESLIM-BIREY] bireysel teslim izleyicisi baslatildi (v8.308)";

[] spawn {
    private _silahVar = {
        params ["_u"];
        private _ok = false;
        {
            private _w = _x;
            if (_w isNotEqualTo "") then {
                if ((_u ammo _w) > 0) exitWith { _ok = true; };
                private _uyum = compatibleMagazines _w;
                if (((magazines _u) findIf {_x in _uyum}) >= 0) exitWith { _ok = true; };
            };
        } forEach [primaryWeapon _u, handgunWeapon _u];
        _ok
    };
    private _logN = 0;
    while {true} do {
        sleep 5;
        if (!(missionNamespace getVariable ["lambs_danger_teslimBirey", true])) then { continue };
        if (!(missionNamespace getVariable ["lambs_danger_teslimV1", true])) then { continue };

        // ---- esir bakimi (yalniz bireysel esirler; grup teslimiyse fnc_moral bakar) ----
        {
            private _eu = _x;
            if (_eu getVariable [QGVAR(teslim), false] && {!((group _eu) getVariable [QGVAR(teslimOldu), false])}) then {
                if (_eu getVariable ["ace_captives_isHandcuffed", false]) then { _eu setVariable [QGVAR(aceEsir), true]; };
                if (alive _eu && {isNull objectParent _eu} && {!(_eu getVariable [QGVAR(aceEsir), false])}) then {
                    if ((primaryWeapon _eu) isNotEqualTo "" || {(secondaryWeapon _eu) isNotEqualTo ""} || {(handgunWeapon _eu) isNotEqualTo ""}) then { removeAllWeapons _eu; };
                    { _eu disableAI _x; } forEach ["MOVE", "PATH", "TARGET", "AUTOTARGET", "FSM", "WEAPONAIM", "AUTOCOMBAT", "COVER", "SUPPRESSION"];
                    if (!captive _eu) then { _eu setCaptive true; };
                    doStop _eu;
                };
            };
        } forEach (allUnits select {local _x && {alive _x} && {!isPlayer _x} && {_x getVariable [QGVAR(teslim), false]}});

        // ---- aday taramasi ----
        {
            private _u = _x;
            private _g = group _u;
            if ((_g getVariable [QGVAR(teslimOldu), false]) || {side _g isEqualTo civilian}) then { continue };
            if (_u getVariable [QGVAR(teslim), false] || {captive _u}) then { continue };
            if ((lifeState _u) in ["INCAPACITATED", "UNCONSCIOUS"] || {_u getVariable ["ACE_isUnconscious", false]}) then { continue };
            if ([_u] call _silahVar) then { _u setVariable [QGVAR(birTeslimSay), 0]; continue };

            // izin (fnc_moral ile ayni mantik)
            private _frk = toLower (faction _u);
            private _liste = {
                params ["_l"];
                private _ok = false;
                { private _t = toLower ((_x splitString " ") joinString ""); if (_t isNotEqualTo "" && {(_frk find _t) >= 0}) exitWith { _ok = true; }; } forEach (_l splitString ",;");
                _ok
            };
            private _izin = if ([missionNamespace getVariable ["lambs_danger_teslimFraksiyonKapali", ""]] call _liste) then {false} else {
                if ([missionNamespace getVariable ["lambs_danger_teslimFraksiyonAcik", ""]] call _liste) then {true} else {
                    private _tK = switch (side _g) do { case west: {"lambs_danger_teslimWest"}; case east: {"lambs_danger_teslimEast"}; default {"lambs_danger_teslimInd"} };
                    (missionNamespace getVariable [_tK, true]) && {([_g, "teslim", true] call FUNC(dk)) || {missionNamespace getVariable ["lambs_danger_teslimDuzensiz", true]}}
                };
            };
            if (!_izin) then { continue };

            // tehdit
            private _en = _u findNearestEnemy _u;
            private _enD = if (isNull _en || {!alive _en}) then {1e9} else {_u distance2D _en};
            private _bilgi = !isNull _en && {(_u knowsAbout _en) >= 0.8};
            private _drn = (_u nearEntities ["Air", 300]) select {unitIsUAV _x && {alive _x} && {((side _g) getFriend (side (group (effectiveCommander _x)))) < 0.6}};
            private _tehdit = (_bilgi && {_enD <= 120}) || {_drn isNotEqualTo []} || {_bilgi && {_enD <= 300} && {(getSuppression _u) >= 0.35}};
            if (!_tehdit) then { _u setVariable [QGVAR(birTeslimSay), 0]; continue };

            private _say = (_u getVariable [QGVAR(birTeslimSay), 0]) + 1;
            _u setVariable [QGVAR(birTeslimSay), _say];
            if (_say < 2) then { continue };

            // lider ise once halef
            if (_u isEqualTo (leader _g)) then {
                private _halef = (units _g) select {_x isNotEqualTo _u && {alive _x} && {!isPlayer _x} && {(lifeState _x) in ["HEALTHY", "INJURED"]} && {!(_x getVariable [QGVAR(teslim), false])} && {[_x] call _silahVar}};
                if (_halef isNotEqualTo []) then { _g selectLeader (_halef select 0); };
            };

            // TESLIM
            _u setVariable [QGVAR(disableAI), true];
            _u setCaptive true;
            _u setVariable [QGVAR(teslim), true, true];
            private _w = primaryWeapon _u;
            if (_w isNotEqualTo "") then { _u action ["DropWeapon", _u, _w]; };
            [{ params ["_eu"]; if (alive _eu) then { removeAllWeapons _eu; }; }, [_u], 2] call CBA_fnc_waitAndExecute;
            { _u disableAI _x; } forEach ["MOVE", "PATH", "TARGET", "AUTOTARGET", "FSM", "WEAPONAIM", "AUTOCOMBAT", "COVER", "SUPPRESSION"];
            doStop _u;
            if (!isNil "ace_captives_fnc_setSurrendered") then { [_u, true] call ace_captives_fnc_setSurrendered; } else { _u action ["Surrender", _u]; };
            _u doWatch objNull;
            if (_logN < 40) then {
                _logN = _logN + 1;
                diag_log format ["[TESLIM-BIREY] %1 | %2 | karsilik veremez (silah:%3 / ates edilebilir mermi yok) | dusman %4 m | dron %5 | baski %6 | %7", groupId _g, name _u, primaryWeapon _u, if (_enD > 1e8) then {"-"} else {round _enD}, count _drn, (getSuppression _u) toFixed 2, side _g];
            };
        } forEach (allUnits select {local _x && {alive _x} && {!isPlayer _x} && {isNull objectParent _x} && {(side (group _x)) isNotEqualTo civilian}});
    };
};
true
