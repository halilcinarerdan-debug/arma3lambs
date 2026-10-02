#include "script_component.hpp"
/*
 * Author: Cinar (ELITE fork)
 * TEMAS KES — kucuk grup / TEK KALAN ASKER en yakin SERT sipere gider ve orada bekler.
 *
 * Sorun: fnc_tactics komutan beyni yalnizca >= 4 kisilik gruplar icin calisiyordu; 3 kisi ve
 *        alti (ozellikle tek kalan asker) LAMBS'in duz akisina dusup catismaya devam ediyordu.
 *
 * Tetik (oncelik sirali, hepsi `_alive < 4` icin):
 *   - TEK asker + buyuk gruptan kaldi (baslangic >= 2) veya yarali (hasar > 0.3)
 *   - kayip >= %50
 *   - ortalama baski >= 0.7
 *   dusman < 25m ise (yakin dovus) veya > 400m ise tetiklenmez.
 *
 * Davranis:
 *   - 2'li ciftler (tek asker = tek kisilik cift); her cift findCover "SURVIVE" ile EN YAKIN sert siper
 *     (en az 1 yukseklikte mermi durduran engel, uzaklasma bonusu, yaklasma cezasi)
 *   - siper yoksa dusmandan 60m uzaklas (dik acilar)
 *   - SADECE KOSARKEN forceMove + AUTOCOMBAT/COVER/TARGET kapali; VARINCA hepsi acilir (FSM siper alir,
 *     karsilik verir: combatMode YELLOW)
 *   - varista siper stance'i + dusmani izler, 25 sn bekler; dusman 25m icine girerse savasir
 *   - 20 sn cooldown, guvenlik valfi 70 sn
 *
 * Arguments:
 * 0: group <GROUP> or leader <OBJECT>
 * 1: tehdit <OBJECT> or position <ARRAY>
 *
 * Return Value:
 * Temas kesme BASLADI mi <BOOL>
 *
 * Example:
 * [_g, _enemy] call lambs_danger_fnc_tacticsBreakContact;
 *
 * Public: No
*/

params [
    ["_group", grpNull, [grpNull, objNull]],
    ["_target", objNull, [objNull, []]]
];

if (_group isEqualType objNull) then {_group = group _group;};
if (isNull _group) exitWith {false};

private _birimler = (units _group) select {alive _x && {isNull objectParent _x}};
private _alive = count _birimler;
if (_alive < 1 || {_alive >= 4}) exitWith {false};

if (_group getVariable [QGVAR(isBreakingContact), false]) exitWith {false};
if (_group getVariable [QGVAR(isRetreating), false]) exitWith {false};
if (_group getVariable [QGVAR(isEvading), false]) exitWith {false};
if (_group getVariable [QGVAR(isATEngage), false]) exitWith {false};
if ((time - (_group getVariable [QGVAR(bcEndTime), -999])) < ([75, 25] select (_alive isEqualTo 1))) exitWith {false};   // tek kalan: kisa cooldown   // kalici tetik (kayip %50 / tek asker): 75 sn sonra tekrar

// ---------------------------------------------------------------------------
// TETIK DEGERLENDIRMESI
// ---------------------------------------------------------------------------
private _init = _group getVariable [QGVAR(cmdInitialCount), -1];
if (!(_init isEqualType 0) || {_init < 0}) then {
    _init = _alive;
    _group setVariable [QGVAR(cmdInitialCount), _init];
};
private _kayip = if (_init > 0) then {(_init - _alive) / _init} else {0};

private _baski = 0;
{ _baski = _baski + (getSuppression _x); } forEach _birimler;
_baski = _baski / _alive;

private _yarali = (_birimler findIf {(damage _x) > 0.3}) > -1;

private _kac =
    (_alive isEqualTo 1)   // TEK KALAN ASKER her zaman kacar (cmdInitialCount sonradan 1 olarak yazilmis olabiliyordu)
    || {_kayip >= 0.5}
    || {_baski >= 0.7};
if (!_kac) exitWith {false};

// Dusman mesafesi: en yakin birim <-> tehdit
private _tehditPos = _target call CBA_fnc_getPos;
if ((_tehditPos select 2) > 6) then { _tehditPos set [2, 0.5]; };
private _mesafe = 99999;
{ _mesafe = _mesafe min (_x distance2D _tehditPos); } forEach _birimler;
if (_mesafe < ([25, 10] select (_alive isEqualTo 1)) || {_mesafe > 400}) exitWith {false};

// ---------------------------------------------------------------------------
// BASLA
// ---------------------------------------------------------------------------
private _baslangic = time;
_group setVariable [QGVAR(bcOrigCombat), combatMode _group];
_group setVariable [QGVAR(isBreakingContact), true];
_group setVariable [QGVAR(isExecutingTactic), true];
_group setVariable [QGVAR(bcStartTime), _baslangic];

// Guvenlik valfi — sadece bu kacisin bayraklarini + AI kilitlerini temizler
[_group, _baslangic, time + 70] spawn {
    params ["_g", "_start", "_limit"];
    waitUntil { time > _limit || {isNull _g} };
    if (!isNull _g && {((_g getVariable [QGVAR(bcStartTime), -1]) isEqualTo _start)}) then {
        if (_g getVariable [QGVAR(isBreakingContact), false]) then {
            _g setVariable [QGVAR(isBreakingContact), nil];
            _g setVariable [QGVAR(isExecutingTactic), nil];
            _g setVariable [QGVAR(bcEndTime), time];
            _g setSpeedMode "NORMAL";
            _g enableAttack true;
            _g setCombatMode (_g getVariable [QGVAR(bcOrigCombat), "YELLOW"]);
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
                    _x setUnitPos "AUTO";
                    _x doWatch objNull;
                };
            } forEach (units _g);
            diag_log format ["[TEMAS-KES-VALF] %1 guvenlik valfi temizledi", groupId _g];
        };
    };
};

diag_log format [
    "[TEMAS-KES-BASLA] %1 | kalan:%2/%3 | kayip:%4%% | baski:%5 | tehdit:%6m",
    groupId _group, _alive, _init, round (_kayip * 100), _baski toFixed 2, round _mesafe
];

[_group, _target, _tehditPos, _baslangic] spawn {
    params ["_group", "_tehdit", "_tehditPos", "_baslangic"];

    private _origCombat = _group getVariable [QGVAR(bcOrigCombat), combatMode _group];
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
    if (_birimler isEqualTo []) exitWith {
        _group setVariable [QGVAR(isBreakingContact), nil];
        _group setVariable [QGVAR(isExecutingTactic), nil];
        _group setVariable [QGVAR(bcEndTime), time];
    };
    _group setSpeedMode "FULL";
    _group enableAttack false;

    // -----------------------------------------------------------------------
    // CIFTLER — her cift kendi EN YAKIN sert siperine
    // -----------------------------------------------------------------------
    private _ciftler = [_birimler] call _pairFn;
    private _kacisYonu = _tehditPos getDir (getPosATL (_birimler select 0));
    private _varis = [];

    {
        private _cift = _x;
        private _ciftIdx = _forEachIndex;
        private _oncu = _cift select 0;
        private _hedef = [];
        private _stance = "MIDDLE";

        if (!isNull _oncu && {alive _oncu}) then {
            private _cover = [_oncu, _tehdit, 60, "ASCEND", 1, "SURVIVE"] call EFUNC(main,findCover);
            // Siper tehdide, bulundugumuz yerden 5 m'den fazla YAKINSA siper sayma (dusmana dogru kosma)
            if (_cover isNotEqualTo [] && {(((_cover select 0) select 0) distance2D _tehditPos) < ((_oncu distance2D _tehditPos) - 5)}) then {
                _cover = [];
            };
            if (_cover isNotEqualTo []) then {
                _hedef = (_cover select 0) select 0;
                _stance = (_cover select 0) select 1;
            } else {
                // Sert siper yok: dusmandan 60m uzaklas (dik acilarla)
                private _yan = [-40, 40] select (_ciftIdx % 2);
                _hedef = (getPosATL _oncu) getPos [60, _kacisYonu + _yan];
                if (surfaceIsWater _hedef) then {
                    _hedef = (getPosATL _oncu) getPos [30, _kacisYonu];
                };
            };

            {
                if (alive _x && {isNull objectParent _x}) then {
                    // Onculer tam siper noktasina; es biraz yaninda. Siper yoksa (kacis noktasi) 5 m'ye yayilir
                    private _p = if (_cover isEqualTo []) then {
                        _hedef getPos [random 5, random 360]
                    } else {
                        [_hedef getPos [1 + (random 1.5), random 360], _hedef] select (_x isEqualTo _oncu)
                    };
                    _varis pushBack [_x, _p, _stance];
                    // SADECE KOSARKEN: LAMBS reaksiyonlari emri bozmasin, kacma yok
                    _x setVariable [QGVAR(forceMove), true];
                    _x allowFleeing 0;
                    _x disableAI "TARGET";
                    _x disableAI "AUTOTARGET";
                    _x disableAI "AUTOCOMBAT";
                    _x disableAI "COVER";
                    _x setVariable [QEGVAR(main,currentTask), "BreakContact/Move", EGVAR(main,debug_functions)];
                    _x setUnitPosWeak "UP";
                    _x forceSpeed -1;
                    _x moveTo _p;
                };
            } forEach _cift;
        };
    } forEach _ciftler;

    // Varisa kadar bekle (en fazla 18 sn); gelmeyenlere emri 3 sn'de bir tazele.
    // Baski >= 0.85 ezilen kosmaya devam etmez: forceMove birakilir -> FSM hemen siper alir.
    private _pinned = [];
    private _bitis = time + 18;
    while {time < _bitis && {!isNull _group}} do {
        {
            private _b = _x select 0;
            if (alive _b && {!(_b in _pinned)} && {(getSuppression _b) >= 0.85}) then {
                _pinned pushBack _b;
                _b setVariable [QGVAR(forceMove), nil];
                _b enableAI "AUTOCOMBAT";
                _b enableAI "COVER";
                _b enableAI "TARGET";
                _b enableAI "AUTOTARGET";
                _b setUnitPosWeak "DOWN";
            };
        } forEach _varis;

        private _gelmeyen = _varis select {
            alive (_x select 0)
            && {!((_x select 0) in _pinned)}
            && {((_x select 0) distance2D (_x select 1)) > 6}
        };
        if (_gelmeyen isEqualTo []) exitWith {};
        { (_x select 0) moveTo (_x select 1); } forEach _gelmeyen;
        sleep 3;
    };

    // -----------------------------------------------------------------------
    // VARDILAR: AI hepsi acik (FSM siper alir / karsilik verir), siper stance'i, tehdidi izle
    // -----------------------------------------------------------------------
    {
        _x params ["_b", "_p", "_s"];
        if (alive _b) then {
            _b setVariable [QGVAR(forceMove), nil];
            _b enableAI "TARGET";
            _b enableAI "AUTOTARGET";
            _b enableAI "AUTOCOMBAT";
            _b enableAI "COVER";
            _b setUnitPosWeak _s;
            _b doWatch _tehditPos;
        };
    } forEach _varis;
    _group setCombatMode "YELLOW";

    diag_log format ["[TEMAS-KES] %1 sipere vardi, 25 sn bekleniyor", groupId _group];

    // 25 sn bekle; dusman 25m icine girerse savas (bekleme biter)
    private _holdBitis = time + 25;
    waitUntil {
        sleep 1;
        isNull _group
        || {time > _holdBitis}
        || {
            ((units _group) findIf {
                alive _x && {
                    private _e = _x findNearestEnemy _x;
                    !isNull _e && {(_x distance2D _e) < 25}
                }
            }) > -1
        }
    };

    // -----------------------------------------------------------------------
    // TEMIZLIK
    // -----------------------------------------------------------------------
    if (!isNull _group && {((_group getVariable [QGVAR(bcStartTime), -1]) isEqualTo _baslangic)}) then {
        _group setVariable [QGVAR(isBreakingContact), nil];
        _group setVariable [QGVAR(isExecutingTactic), nil];
        _group setVariable [QGVAR(bcEndTime), time];
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
                _x setUnitPos "AUTO";
                _x doWatch objNull;
                _x doFollow (leader _x);
            };
        } forEach (units _group);

        diag_log format ["[TEMAS-KES-TAMAM] %1", groupId _group];
    };
};

true
