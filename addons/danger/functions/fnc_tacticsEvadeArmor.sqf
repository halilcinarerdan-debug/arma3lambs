#include "script_component.hpp"
/*
 * Author: Cinar (ELITE fork)
 * ZIRHTAN KACIS — kendi AT'si olmayan grup tank / APC'den kacar, SERT SIPERE saklanir.
 *
 * Neden Retreat degil: Retreat acik arazide 120m dogru geri kosar; tank/APC'den hizli ve
 * ates menzili genis, acikta kosan piyade olur. Burada hedef GORUS HATTINI KIRMAK:
 *   - Her 2'li buddy cifti findCover "EVADE" ile SERT siper secer (bina / duvar / kaya,
 *     en az 2 yukseklikte mermi durduran engel, zirhtan >= 40m, bina oncelikli)
 *   - Siper yoksa zirhin kule hattindan DIK acilarla (+-60 derece) 80m uzaklasir
 *   - Hareket: sprint, forceMove + AUTOCOMBAT/COVER/TARGET kapali, allowFleeing 0 (rastgele kosma yok)
 *   - Zirha ATES ACMAZ (combatMode GREEN): konum belli etmez, AT'siz piyade tanka karsi ates etmez
 *   - Varista alcalir (DOWN), zirhi izler, 20 sn saklanir, sonra normale doner
 *   - Sis perdesi (tacticalSmoke BREAK_CONTACT)
 *   - 30 sn cooldown, guvenlik valfi 90 sn
 *
 * Arguments:
 * 0: group <GROUP> or leader <OBJECT>
 * 1: tehdit (zirh) <OBJECT> or position <ARRAY>
 *
 * Return Value:
 * Bool
 *
 * Example (Zeus):
 * [_g, _tank] call lambs_danger_fnc_tacticsEvadeArmor;
 *
 * Public: No
*/

params [
    ["_group", grpNull, [grpNull, objNull]],
    ["_target", objNull, [objNull, []]]
];

if (_group isEqualType objNull) then {_group = group _group;};
if (isNull _group) exitWith {false};
if ((units _group) isEqualTo []) exitWith {false};

private _unit = leader _group;
if (isNull _unit) exitWith {false};

if (_group getVariable [QGVAR(isEvading), false]) exitWith {false};
if (_group getVariable [QGVAR(isRetreating), false]) exitWith {false};

// ---------------------------------------------------------------------------
// COOLDOWN — 30 sn dolmadiysa kacma, saklandigin yerde tut
// ---------------------------------------------------------------------------
if ((time - (_group getVariable [QGVAR(evadeEndTime), -999])) < 30) exitWith {
    _group setVariable [QGVAR(isExecutingTactic), true];
    [_group, _target] call FUNC(tacticsHold);
    [{
        params ["_g"];
        if (!isNull _g) then {
            _g setVariable [QGVAR(isExecutingTactic), nil];
        };
    }, [_group], 20] call CBA_fnc_waitAndExecute;
    false
};

// ---------------------------------------------------------------------------
// ZIRH TESPITI — en yakin murettebatli dusman Tank / APC (700m); yoksa verilen hedef
// ---------------------------------------------------------------------------
private _mySide = side _unit;
private _armor = (_unit nearEntities [["Tank", "Wheeled_APC_F"], 700]) select {
    alive _x
    && {(_mySide getFriend (side _x)) < 0.6}
    && {!((side _x) == civilian)}
};

private _tehdit = _target;
if (_armor isNotEqualTo []) then {
    _armor = [_armor, [], {_unit distance2D _x}, "ASCEND"] call BIS_fnc_sortBy;
    _tehdit = _armor select 0;
};

private _tehditPos = _tehdit call CBA_fnc_getPos;
if ((_tehditPos select 2) > 6) then { _tehditPos set [2, 0.5]; };

private _baslangic = time;
_group setVariable [QGVAR(isEvading), true];
_group setVariable [QGVAR(isExecutingTactic), true];
_group setVariable [QGVAR(evadeStartTime), _baslangic];

// ---------------------------------------------------------------------------
// GUVENLIK VALFI — sadece bu kacisin bayraklarini + AI kilitlerini temizler
// ---------------------------------------------------------------------------
[_group, _baslangic, time + 90] spawn {
    params ["_g", "_start", "_limit"];
    waitUntil { time > _limit || {isNull _g} };
    if (!isNull _g && {((_g getVariable [QGVAR(evadeStartTime), -1]) isEqualTo _start)}) then {
        if (_g getVariable [QGVAR(isEvading), false]) then {
            _g setVariable [QGVAR(isEvading), nil];
            _g setVariable [QGVAR(isExecutingTactic), nil];
            _g setVariable [QGVAR(evadeEndTime), time];
            _g setSpeedMode "NORMAL";
            _g enableAttack true;
            {
                if (alive _x) then {
                    _x enableAI "PATH";
                    _x enableAI "MOVE";
                    _x enableAI "TARGET";
                    _x enableAI "AUTOTARGET";
                    _x enableAI "AUTOCOMBAT";
                    _x enableAI "COVER";
                    _x setVariable [QGVAR(forceMove), nil];
                    _x allowFleeing 0;
                    _x setAnimSpeedCoef 1.0;
                    _x setUnitPos "AUTO";
                    _x doWatch objNull;
                };
            } forEach (units _g);
            diag_log format ["[ZIRH-KAC-VALF] %1 guvenlik valfi temizledi", groupId _g];
        };
    };
};

diag_log format [
    "[ZIRH-KAC-BASLA] %1 | zirh:%2 | mesafe:%3m | zirh sayisi:%4",
    groupId _group,
    if (_tehdit isEqualType objNull) then {typeOf _tehdit} else {"konum"},
    round (_unit distance2D _tehditPos),
    count _armor
];

[_group, _tehdit, _tehditPos, _baslangic] spawn {
    params ["_group", "_tehdit", "_tehditPos", "_baslangic"];

    private _origCombat = combatMode _group;
    private _pairFn = missionNamespace getVariable ["lambs_danger_fnc_buddyPairs", {[_this select 0]}];

    // Eski kilitleri temizle
    {
        _x enableAI "PATH";
        _x enableAI "MOVE";
        _x enableAI "TARGET";
        _x enableAI "AUTOTARGET";
        _x enableAI "AUTOCOMBAT";
        _x enableAI "COVER";
    } forEach (units _group);

    private _birimler = (units _group) select {alive _x && {isNull objectParent _x}};

    // Kilitler: LAMBS reaksiyonlari emri bozmasin; kacma YOK; zirha ates YOK (konum belli etme)
    _group setSpeedMode "FULL";
    _group enableAttack false;
    _group setCombatMode "GREEN";
    {
        _x setVariable [QGVAR(forceMove), true];
        _x allowFleeing 0;
        _x setBehaviour "AWARE";
        _x setAnimSpeedCoef 1.15;
        _x forceSpeed -1;
        _x disableAI "TARGET";
        _x disableAI "AUTOTARGET";
        _x disableAI "AUTOCOMBAT";
        _x disableAI "COVER";
    } forEach _birimler;

    // Sis perdesi (ayri thread; fonksiyon yoksa sessizce atla)
    [_group, _tehditPos] spawn {
        params ["_g", "_tp"];
        private _sisFn = missionNamespace getVariable ["lambs_danger_fnc_tacticalSmoke", {false}];
        [_g, _tp, "BREAK_CONTACT"] call _sisFn;
    };

    // -----------------------------------------------------------------------
    // 2'li CIFTLER — her cift kendi SERT siperine (findCover EVADE)
    // -----------------------------------------------------------------------
    private _ciftler = [_birimler] call _pairFn;
    private _kacisYonu = _tehditPos getDir (getPosATL (leader _group));   // tehditten bize dogru
    private _varis = [];

    {
        private _cift = _x;
        private _ciftIdx = _forEachIndex;
        private _oncu = _cift select 0;
        private _hedef = [];

        if (!isNull _oncu && {alive _oncu}) then {
            private _cover = [_oncu, _tehdit, 70, "ASCEND", 1, "EVADE"] call EFUNC(main,findCover);
            if (_cover isNotEqualTo []) then {
                _hedef = (_cover select 0) select 0;
            } else {
                // Sert siper yok: zirhin kule hattindan DIK acilarla (+-60 derece) 80m uzaklas
                private _yan = [-60, 60] select (_ciftIdx % 2);
                _hedef = (getPosATL _oncu) getPos [80, _kacisYonu + _yan];
                if (surfaceIsWater _hedef) then {
                    _hedef = (getPosATL _oncu) getPos [40, _kacisYonu];
                };
            };

            {
                if (alive _x && {isNull objectParent _x}) then {
                    private _p = _hedef getPos [random 5, random 360];
                    _varis pushBack [_x, _p];
                    _x setVariable [QEGVAR(main,currentTask), "EvadeArmor/Move", EGVAR(main,debug_functions)];
                    _x setUnitPosWeak "UP";
                    _x moveTo _p;
                };
            } forEach _cift;
        };
    } forEach _ciftler;

    // Varisa kadar bekle (en fazla 22 sn); gelmeyenlere emri 3 sn'de bir tazele
    private _bitis = time + 22;
    while {time < _bitis && {!isNull _group}} do {
        private _gelmeyen = _varis select {
            alive (_x select 0) && {((_x select 0) distance2D (_x select 1)) > 8}
        };
        if (_gelmeyen isEqualTo []) exitWith {};
        { (_x select 0) moveTo (_x select 1); } forEach _gelmeyen;
        sleep 3;
    };

    // Vardilar: alcal, zirhi izle, ates ACMA (saklan)
    {
        private _b = _x select 0;
        if (alive _b) then {
            _b setVariable [QGVAR(forceMove), nil];
            _b enableAI "AUTOCOMBAT";
            _b enableAI "COVER";
            _b setUnitPosWeak "DOWN";
            _b doWatch _tehditPos;
        };
    } forEach _varis;

    diag_log format ["[ZIRH-KAC] %1 saklandi, 20 sn bekleniyor", groupId _group];
    sleep 20;

    // -----------------------------------------------------------------------
    // TEMIZLIK
    // -----------------------------------------------------------------------
    if (!isNull _group && {((_group getVariable [QGVAR(evadeStartTime), -1]) isEqualTo _baslangic)}) then {
        _group setVariable [QGVAR(isEvading), nil];
        _group setVariable [QGVAR(isExecutingTactic), nil];
        _group setVariable [QGVAR(evadeEndTime), time];
        _group setSpeedMode "NORMAL";
        _group enableAttack true;
        _group setCombatMode _origCombat;

        {
            if (alive _x) then {
                _x enableAI "PATH";
                _x enableAI "MOVE";
                _x enableAI "TARGET";
                _x enableAI "AUTOTARGET";
                _x enableAI "AUTOCOMBAT";
                _x enableAI "COVER";
                _x setVariable [QGVAR(forceMove), nil];
                _x setVariable [QEGVAR(main,currentTask), nil, EGVAR(main,debug_functions)];
                _x allowFleeing 0;
                _x setAnimSpeedCoef 1.0;
                _x setUnitPos "AUTO";
                _x doWatch objNull;
                _x doFollow (leader _x);
            };
        } forEach (units _group);

        diag_log format ["[ZIRH-KAC-TAMAM] %1", groupId _group];
    };
};

true
