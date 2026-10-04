#include "script_component.hpp"
/*
 * Author: nkenny
 * Leader calls for extended aggressive assault towards buildings or location
 *
 * Arguments:
 * 0: group executing tactics <GROUP> or group leader <UNIT>
 * 1: group threat unit <OBJECT> or position <ARRAY>
 * 2: units in group, default all <ARRAY>
 * 3: how many assault cycles <NUMBER>
 * 4: delay until unit is ready again <NUMBER>
 *
 * Return Value:
 * success
 *
 * Example:
 * [bob, angryJoe] call lambs_danger_fnc_tacticsAssault;
 *
 * Public: No
*/
params ["_group", "_target", ["_units", []], ["_delay", 85], ["_hazirGecildi", false]];

// group is missing
if (isNull _group) exitWith {false};

// get leader
if (_group isEqualType objNull) then {_group = group _group;};
if ((units _group) isEqualTo []) exitWith {false};
private _unit = leader _group;

// find target
_target = _target call CBA_fnc_getPos;
if ((_target select 2) > 6) then {
    _target set [2, 0.5];
};

// ---------------------------------------------------------------------------
// v8.63 HAZIRLIK PENCERESI (hucum oncesi ates destegi): hedefe 45-250 m, >= 4 canli asker, grup bastirilmamis, son hazirliktan > 60 sn ise
//   5-8 sn boyunca lider disindaki herkes hedef konuma BASTIRMA atesi acar (UGL'liler 40 mm'yi ZORLA atar), SONRA asil hucum baslar (ayni fonksiyon, _hazirGecildi = true).
//   Doktrin ilkesi (genel; sayisal esik kaynaklarda yok): manevra unsuru hareket etmeden once ates unsuru dusmani bastirir. Kapatma: lambs_danger_hazirlikOff = true.  Log: [ZEKA-HAZIRLIK]
// ---------------------------------------------------------------------------
private _hazirYap = false;
if (!_hazirGecildi && {!(missionNamespace getVariable ["lambs_danger_hazirlikOff", false])}) then {
    private _dM = _unit distance2D _target;
    private _canliH = (units _group) select {alive _x && {isNull objectParent _x}};
    private _bskH = (_canliH findIf {(getSuppression _x) > 0.5}) >= 0;
    private _sonH = time - (_group getVariable [QGVAR(hazirT), -999]);
    if (_dM > 45 && {_dM < 250} && {(count _canliH) >= 4} && {!_bskH} && {_sonH > 60}) then {
        _hazirYap = true;
    } else {
        if (_dM > 45 && {_dM < 250} && {(missionNamespace getVariable ["lambs_danger_hazirLogN", 0]) < 40} && {(time - (_group getVariable [QGVAR(hazirLogT), -999])) > 60}) then {
            _group setVariable [QGVAR(hazirLogT), time];
            missionNamespace setVariable ["lambs_danger_hazirLogN", (missionNamespace getVariable ["lambs_danger_hazirLogN", 0]) + 1];
            diag_log format ["[ZEKA-HAZIRLIK] %1 | hedef %2 m | ATLANDI: asker %3 (>=4), baskida:%4, son hazirlik %5 sn once (>60)", groupId _group, round _dM, count _canliH, _bskH, round (_sonH min 9999)];
        };
    };
};
if (_hazirYap) exitWith {
    _group setVariable [QGVAR(hazirT), time];
    private _sn = 5 + (random 3);
    private _eObj = _unit findNearestEnemy _target;
    private _nAtes = 0;
    private _nUgl = 0;
    {
        private _u = _x;
        if (_u isNotEqualTo _unit && {alive _u} && {isNull objectParent _u} && {(primaryWeapon _u) isNotEqualTo ""}) then {
            _u doWatch _target;
            _u doSuppressiveFire _target;
            _nAtes = _nAtes + 1;
            if (!isNull _eObj && {_eObj isKindOf "CAManBase"} && {([_u] call (missionNamespace getVariable ["lambs_danger_fnc_hasUGL", {""}])) isNotEqualTo ""}) then {
                if ([_u, _eObj, true, 2] call (missionNamespace getVariable ["lambs_danger_fnc_tacticalUGL", {false}])) then { _nUgl = _nUgl + 1; };
            };
        };
    } forEach (units _group);
    diag_log format ["[ZEKA-HAZIRLIK] %1 | hedef %2 m | BASTIRMA PENCERESI %3 sn | ates eden:%4 | UGL:%5 | sonra hucum", groupId _group, round (_unit distance2D _target), _sn toFixed 1, _nAtes, _nUgl];
    [{
        params ["_g", "_t", "_us", "_d"];
        if (!isNull _g && {alive leader _g}) then {
            { if (alive _x) then { _x doWatch objNull; }; } forEach (units _g);
            [_g, _t, _us, _d, true] call (missionNamespace getVariable ["lambs_danger_fnc_tacticsAssault", {false}]);
        };
    }, [_group, _target, _units, _delay], _sn] call CBA_fnc_waitAndExecute;
    true
};

// reset tactics
[
    {
        params [["_group", grpNull], ["_enableAttack", true], ["_isIRLaserOn", false], ["_speedMode", "NORMAL"], ["_formation", "WEDGE"]];
        if (!isNull _group) then {
            _group setVariable [QGVAR(isExecutingTactic), nil];
            _group setVariable [QEGVAR(main,currentTactic), nil];
            _group enableAttack _enableAttack;
            _group enableIRLasers _isIRLaserOn;
            _group setSpeedMode _speedMode;
            // v8.61 FORMASYON FELCI KOK NEDENI: zamanlayici, taktik cagrildigi andaki formasyonu geri yaziyordu; taktik her ~10 sn'de yeniden cagrilinca (ASSAULT) bir onceki cagrinin
            //   LINE'i yerine eski zamanlayici ilk formasyonu (ECH RIGHT) geri yaziyor -> LINE <-> ECH RIGHT dongusu (RPT bc9dd1d6: Alpha 1-5, 3 dk, 5-10 sn aralikla).
            //   Artik geri yazma YOK: taktik bitince formasyonu fnc_commanderFormation / selectFormation belirler (tacticsHold ile ayni cozum).
            {
                _x setVariable [QEGVAR(main,currentTask), nil, EGVAR(main,debug_functions)];
                _x doFollow leader _x;
                _x forceSpeed -1;
            } forEach (units _group);
        };
    },
    [_group, attackEnabled _group, _unit isIRLaserOn (currentWeapon _unit), speedMode _group, formation _group],
    _delay
] call CBA_fnc_waitAndExecute;

// set speed and enableAttack
_group enableAttack false;
_group setSpeedMode "FULL";
_group setVariable [QGVAR(taktikFormT), time];
if ((formation _group) isNotEqualTo "LINE") then { _group setFormation "LINE"; };

// find units
if (_units isEqualTo []) then {
    _units = [_unit, 250] call EFUNC(main,findReadyUnits);
};
if (_units isEqualTo []) exitWith {false};

// sort potential targets
private _buildings = [_target, 28, true, true] call EFUNC(main,findBuildings);

// more than 25 building positions. Reduce size!
if (count _buildings > 25) then {
    _buildings resize 25
};

// add building positions to group memory
_group setVariable [QEGVAR(main,groupMemory), _buildings];

// find vehicles
private _vehicles = [_unit] call EFUNC(main,findReadyVehicles);
private _overwatch = [ASLToAGL (getPosASL _unit), EGVAR(main,minSuppressionRange) * 2, EGVAR(main,minSuppressionRange), 4, _target, false] call EFUNC(main,findOverwatch);
if (_overwatch isNotEqualTo []) then {
    {
        private _roads = _overwatch nearRoads 30;
        if (_roads isNotEqualTo []) then {_overwatch = ASLToAGL (getPosASL (selectRandom _roads))};
        _x doMove _overwatch;
        _x doWatch (selectRandom _buildings);
    } forEach _vehicles;
};

// set tasks
_unit setVariable [QEGVAR(main,currentTarget), _target, EGVAR(main,debug_functions)];
_unit setVariable [QEGVAR(main,currentTask), "Tactics Assault", EGVAR(main,debug_functions)];

// set group task
_group setVariable [QEGVAR(main,currentTactic), "Assaulting", EGVAR(main,debug_functions)];

// gesture
[_unit, "gestureGo"] call EFUNC(main,doGesture);
[_units select -1, "gestureGoB"] call EFUNC(main,doGesture);

// leader callout
[_unit, "combat", "Advance", 125] call EFUNC(main,doCallout);

// concealment
if (!GVAR(disableAutonomousSmokeGrenades)) then {

    // leader smoke
    [_unit, _target] call EFUNC(main,doSmoke);

    // grenadier smoke
    [{_this call EFUNC(main,doUGL)}, [_units, _target, "shotSmoke"], 3] call CBA_fnc_waitAndExecute;
};

// ready group
_group setFormDir (_unit getDir _target);
_group enableIRLasers true;
_units doWatch objNull;
_units doMove _target;

// check for reload
{
    reload _x;
} forEach (_units select {getSuppression _x < 0.7 && {needReload _x > 0.6}});

// debug
if (EGVAR(main,debug_functions)) then {
    ["%1 TACTICS ASSAULT (%2 with %3 units @ %4m with %5 buildings)", side _unit, name _unit, count _units, round (_unit distance2D _target), count _buildings] call EFUNC(main,debugLog);
    private _m = [_unit, "tactics assault", _unit call EFUNC(main,debugMarkerColor), "hd_arrow"] call EFUNC(main,dotMarker);
    private _mt = [_target, "", _unit call EFUNC(main,debugMarkerColor), "hd_join"] call EFUNC(main,dotMarker);
    {_x setMarkerSizeLocal [0.6, 0.6];} forEach [_m, _mt];
    _m setMarkerDirLocal (_unit getDir _target);
    [{{deleteMarker _x;true} count _this;}, [_m, _mt], _delay + 30] call CBA_fnc_waitAndExecute;
};

// end
true
