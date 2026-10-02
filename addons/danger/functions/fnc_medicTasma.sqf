#include "script_component.hpp"
/*
 * Author: Cinar (ELITE fork)
 * SAGLIKCI TASMASI — saglikci (MEDIC) grubun ONUNE gecmez; temasta lidere gore ARKADA kalir (ileride TCCC icin hazir tutulur).
 *
 * Sorun (RPT 13:54-13:57): saglikci LAMBS tepkileriyle (Dodge! / Heard scream! / Hide / Attacking) kademeli onde kaldi: lidere gore ileri
 *   -15 -> +29 -> +39 -> +51 -> +60 m (dusman 140 -> 83 m), baski 0.98.
 *
 * Kural (2 sn'de bir, yerel / oyuncusuz gruplar, saglikci rolu):
 *   - tetik: temas var VEYA bilinen dusman <= 400 m  VE  saglikci lidere gore ileride (ileri > 2 m) ya da > 35 m uzakta
 *   - MUAF : TCCC aktif (tcccBusy > time) | grup retreat / evade / temas kes | saglikci yarali (baygin)
 *   - hedef: lidere 10-16 m ARKA (dusman yonunun tersi), yana +-6 m dagitma; doMove + forceMove + taktikKilit (6 sn); varis < 4 m ya da 14 sn
 *   - donus suresinde saglikcida LAMBS birim bayragi (disableAI) acilir (Dodge / Attacking kosuyu bozmasin), bitince ESKI degere doner
 *   - cooldown 12 sn / saglikci. Kapatma: lambs_danger_medicTasmaV1 = false
 * Log: [MEDIC-TASMA] (ilk 60 donus: ileri / mesafe / neden), [MEDIC-TASMA-OZET] 60 sn.
 *
 * Arguments: None
 * Return Value: Baslatildi mi <BOOL>
 * Public: No
*/

if (!isNil "lambs_danger_medicTasmaStarted") exitWith {false};
lambs_danger_medicTasmaStarted = true;

diag_log "[MEDIC-TASMA] saglikci tasmasi baslatildi (temasta lidere gore arkada kalir; TCCC aktifken muaf)";

[] spawn {
    private _rolFn = missionNamespace getVariable ["lambs_danger_fnc_getUnitRole", {"RIFLE"}];
    private _say = 0;
    private _logN = 0;
    private _sonOzet = time;
    while {true} do {
        sleep 2;
        if (!(missionNamespace getVariable ["lambs_danger_medicTasmaV1", true])) then { continue };
        {
            private _g = _x;
            if (isNull _g || {!local _g} || {(side _g) isEqualTo civilian}) then { continue };
            if ((units _g) findIf {isPlayer _x} > -1) then { continue };
            if ((_g getVariable [QGVAR(isRetreating), false]) || {_g getVariable [QGVAR(isEvading), false]} || {_g getVariable [QGVAR(isBreakingContact), false]}) then { continue };
            private _l = leader _g;
            if (isNull _l || {!alive _l}) then { continue };
            private _en = _l findNearestEnemy _l;
            private _temas = (_g getVariable [QGVAR(contact), 0]) > time;
            if (!_temas && {isNull _en || {(_l distance2D _en) > 400}}) then { continue };
            private _eDir = if (isNull _en) then {getDir _l} else {_l getDir _en};
            private _fwd = [sin _eDir, cos _eDir, 0];
            private _lPos = getPosATL _l;

            {
                private _m = _x;
                if (_m isEqualTo _l || {!alive _m} || {!local _m} || {!isNull objectParent _m}) then { continue };
                if (([_m] call _rolFn) isNotEqualTo "MEDIC") then { continue };
                if ((_m getVariable [QGVAR(tcccBusy), 0]) > time) then { continue };
                if (!((lifeState _m) in ["HEALTHY", "INJURED"])) then { continue };
                if ((time - (_m getVariable [QGVAR(medicTasmaT), -99])) < 12) then { continue };

                private _ileri = ((getPosATL _m) vectorDiff _lPos) vectorDotProduct _fwd;
                private _mes = _m distance2D _l;
                if (_ileri > 2 || {_mes > 35}) then {
                    _m setVariable [QGVAR(medicTasmaT), time];
                    private _hedef = _lPos getPos [10 + (random 6), _eDir + 180 + ((random 12) - 6)];
                    if (surfaceIsWater _hedef) then { _hedef = _lPos getPos [8, _eDir + 180]; };
                    _say = _say + 1;
                    if (_logN < 60) then {
                        _logN = _logN + 1;
                        diag_log format ["[MEDIC-TASMA] %1 | %2 | ileri:%3 m mesafe:%4 m | neden:%5 | dusman:%6 m | gorev:%7 -> arkaya", groupId _g, name _m, round _ileri, round _mes, [["onde", "uzak"] select (_ileri <= 2), "onde+uzak"] select (_ileri > 2 && {_mes > 35}), if (isNull _en) then {"-"} else {round (_l distance2D _en)}, _m getVariable [QEGVAR(main,currentTask), "-"]];
                    };
                    [_m, _hedef] spawn {
                        params ["_a", "_p"];
                        private _eskiDAI = _a getVariable [QGVAR(disableAI), false];
                        _a setVariable [QGVAR(disableAI), true];
                        _a setVariable [QGVAR(forceMove), true];
                        _a setUnitPosWeak "UP";
                        _a doMove _p;
                        private _t = time + 14;
                        waitUntil {
                            sleep 1;
                            _a setVariable [QGVAR(taktikKilit), time + 6];
                            !alive _a || {(_a distance2D _p) < 4} || {time > _t}
                        };
                        if (alive _a) then {
                            _a setVariable [QGVAR(disableAI), [nil, true] select _eskiDAI];
                            _a setVariable [QGVAR(forceMove), nil];
                            _a setVariable [QGVAR(taktikKilit), nil];
                            _a setUnitPosWeak (["MIDDLE", "DOWN"] select ((getSuppression _a) > 0.4));
                        };
                    };
                };
            } forEach (units _g);
        } forEach allGroups;

        if ((time - _sonOzet) >= 60) then {
            if (_say > 0) then { diag_log format ["[MEDIC-TASMA-OZET] son 60 sn: %1 geri cagirma", _say]; };
            _say = 0;
            _sonOzet = time;
        };
    };
};

true
