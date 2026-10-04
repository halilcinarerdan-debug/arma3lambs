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
if ((time - (_group getVariable [QGVAR(bcEndTime), -999])) < ([75, 8] select (_alive isEqualTo 1))) exitWith {false};   // tek kalan: kisa cooldown   // kalici tetik (kayip %50 / tek asker): 75 sn sonra tekrar

// ---------------------------------------------------------------------------
// TETIK DEGERLENDIRMESI
// ---------------------------------------------------------------------------
private _init = _group getVariable [QGVAR(cmdInitialCount), -1];
if (!(_init isEqualType 0) || {_init < 0}) then {
    _init = _alive;
    _group setVariable [QGVAR(cmdInitialCount), _init];
};
private _hayatta = (units _group) select {alive _x};
// ZEUS / SILINEN / GRUPTAN AYRILAN birimler KAYIP SAYILMAZ (sadece OLEN birim kayiptir): taban sayiyi dusur
private _bilinenEski = _group getVariable [QGVAR(cmdKnown), []];
if !(_bilinenEski isEqualType []) then { _bilinenEski = []; };
private _silinen = 0;
{
    if (!(_x in _hayatta) && {isNull _x || {alive _x}}) then { _silinen = _silinen + 1; };
} forEach _bilinenEski;
if (_silinen > 0) then {
    _init = (_init - _silinen) max _alive;
    _group setVariable [QGVAR(cmdInitialCount), _init];
    diag_log format ["[KAYIP-DUZELT] %1 | %2 birim silindi/ayrildi (olu degil): taban %3", groupId _group, _silinen, _init];
};
_group setVariable [QGVAR(cmdKnown), +_hayatta];

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

// v8.30 SON DIRENIS: <= 3 asker, kacis imkansiz (kayip >= %50 + dusman <= 150 m ya da kayip >= %60) ve yakinda bina varsa KALE SAVUNMASI (fnc_sonDirenis)
if ([_group, _tehditPos] call FUNC(sonDirenis)) exitWith {true};

// KACIS MODU: tek kalan veya kayip >= %75 -> siperde bekleme, dusmandan UZAGA kos (150 m)
private _kacisModu = (_alive isEqualTo 1) || {_kayip >= 0.75};

// ---------------------------------------------------------------------------
// BASLA
// ---------------------------------------------------------------------------
private _baslangic = time;
_group setVariable [QGVAR(bcOrigCombat), combatMode _group];
_group setVariable [QGVAR(isBreakingContact), true];
{ if (alive _x) then { _x setVariable [QGVAR(taktikKilit), time + 45]; }; } forEach (units _group);   // hareket arbitraji kilidi
_group setVariable [QGVAR(isExecutingTactic), true];
_group setVariable [QGVAR(bcStartTime), _baslangic];

// Guvenlik valfi — sadece bu kacisin bayraklarini + AI kilitlerini temizler
[_group, _baslangic, time + ([70, 130] select (_alive isEqualTo 1))] spawn {
    params ["_g", "_start", "_limit"];
    waitUntil { time > _limit || {isNull _g} };
    if (!isNull _g && {((_g getVariable [QGVAR(bcStartTime), -1]) isEqualTo _start)}) then {
        if (_g getVariable [QGVAR(isBreakingContact), false]) then {
            { _x setVariable [QGVAR(taktikKilit), nil]; } forEach (units _g);
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
    "[TEMAS-KES-BASLA] %1 | kalan:%2/%3 | kayip:%4%% | baski:%5 | tehdit:%6m | kacis:%7",
    groupId _group, _alive, _init, round (_kayip * 100), _baski toFixed 2, round _mesafe, _kacisModu
];

[_group, _target, _tehditPos, _baslangic, _kacisModu] spawn {
    params ["_group", "_tehdit", "_tehditPos", "_baslangic", "_kacisModu"];

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
        { _x setVariable [QGVAR(taktikKilit), nil]; } forEach (units _group);
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
    // v8.18: kacis yonu = tehditten GRUP MERKEZINE (ilk askere degil)
    private _merkez = [0, 0, 0];
    { _merkez = _merkez vectorAdd (getPosATL _x); } forEach _birimler;
    _merkez = _merkez vectorMultiply (1 / (count _birimler));
    private _kacisYonu = _tehditPos getDir _merkez;
    // GIZLI KACIS ADAYI (v8.18, kullanici: "dusmanin TERS istikameti ve dusmanin GORMEDIGI noktadan yola ciksinlar"):
    //   cevre 25 / 40 / 60 m x kacis yonunun +-0..80 derece; dusman gozunden (1.6 m) comelmis (1.0 m) asker GORUNMUYORSA +35 (yatik da gizliyse +8);
    //   dusmana 10 m'den az uzaklasan aday elenir (-100); bina -25; sert ortu yakininda +8; sapma -0.15 / derece
    //   doner: [pos, puan, gizliMi] ya da []
    private _tehditGoz = AGLToASL (_tehditPos vectorAdd [0, 0, 1.6]);
    private _gizliAday = {
        params ["_o"];
        private _eb = [];
        private _ebS = -9999;
        private _ebG = false;
        private _oMes = _o distance2D _tehditPos;
        {
            private _r = _x;
            {
                private _c = _o getPos [_r, _kacisYonu + _x];
                if (surfaceIsWater _c) then { continue };
                private _s = -((abs _x) * 0.15);
                if (((_c distance2D _tehditPos) - _oMes) < 10) then { _s = _s - 100; };
                private _gc = AGLToASL (_c vectorAdd [0, 0, 1.0]);
                private _gizli = terrainIntersectASL [_tehditGoz, _gc] || {lineIntersects [_tehditGoz, _gc, objNull, objNull]};
                if (_gizli) then {
                    _s = _s + 35;
                    private _gy = AGLToASL (_c vectorAdd [0, 0, 0.4]);
                    if (terrainIntersectASL [_tehditGoz, _gy] || {lineIntersects [_tehditGoz, _gy, objNull, objNull]}) then { _s = _s + 8; };
                };
                if ((nearestTerrainObjects [_c, ["BUILDING", "HOUSE"], 6, false, true]) isNotEqualTo []) then { _s = _s - 25; };
                if ((nearestTerrainObjects [_c, ["TREE", "ROCK", "WALL", "HIDE"], 3, false, true]) isNotEqualTo []) then { _s = _s + 8; };
                if (_s > _ebS) then { _ebS = _s; _eb = _c; _ebG = _gizli; };
            } forEach [0, 20, -20, 40, -40, 60, -60, 80, -80];
        } forEach [25, 40, 60];
        if (_eb isEqualTo []) exitWith {[]};
        [_eb, _ebS, _ebG]
    };

    private _varis = [];

    {
        private _cift = _x;
        private _ciftIdx = _forEachIndex;
        private _oncu = _cift select 0;
        private _hedef = [];
        private _stance = "MIDDLE";

        if (!isNull _oncu && {alive _oncu}) then {
            private _cover = if (_kacisModu) then {[]} else {[_oncu, _tehdit, 60, "ASCEND", 1, "SURVIVE"] call EFUNC(main,findCover)};
            // v8.18: gizli + ters yon aday varsa (dusman gozunden gorunmeyen, dusmandan >= 10 m uzaklasan) ONCELIKLI
            private _ga = [getPosATL _oncu] call _gizliAday;
            private _gaKullan = _ga isNotEqualTo [] && {_ga select 2} && {(_ga select 1) > 0};
            private _coverGizli = false;
            if (_cover isNotEqualTo []) then {
                private _cc = AGLToASL (((_cover select 0) select 0) vectorAdd [0, 0, 1.0]);
                _coverGizli = terrainIntersectASL [_tehditGoz, _cc] || {lineIntersects [_tehditGoz, _cc, objNull, objNull]};
            };
            if (_gaKullan && {!_coverGizli}) then { _cover = []; };

            // Siper tehdide, bulundugumuz yerden 5 m'den fazla YAKINSA siper sayma (dusmana dogru kosma)
            if (_cover isNotEqualTo [] && {(((_cover select 0) select 0) distance2D _tehditPos) < ((_oncu distance2D _tehditPos) - 5)}) then {
                _cover = [];
            };
            if (_cover isNotEqualTo []) then {
                _hedef = (_cover select 0) select 0;
                _stance = (_cover select 0) select 1;
            } else {
                if (_gaKullan) then {
                    _hedef = _ga select 0;
                    _stance = "MIDDLE";
                    if (isNil "lambs_danger_bcLogN") then { lambs_danger_bcLogN = 0; };
                    if (lambs_danger_bcLogN < 40) then {
                        lambs_danger_bcLogN = lambs_danger_bcLogN + 1;
                        diag_log format ["[TEMAS-KES-YON] %1 | %2 | kacis yonu:%3 | hedef %4 m, sapma %5 | gizli:%6 puan:%7 | dusman %8 m", groupId _group, name _oncu, round _kacisYonu, round (_oncu distance2D _hedef), round (abs ((((_oncu getDir _hedef) - _kacisYonu) + 540) % 360 - 180)), _ga select 2, round (_ga select 1), round (_oncu distance2D _tehditPos)];
                    };
                } else {
                // Sert siper yok: dusmandan 60m uzaklas (dik acilarla)
                private _yan = [-40, 40] select (_ciftIdx % 2);
                _hedef = (getPosATL _oncu) getPos [[60, 150] select _kacisModu, _kacisYonu + _yan];
                if (surfaceIsWater _hedef) then {
                    _hedef = (getPosATL _oncu) getPos [30, _kacisYonu];
                };
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
                    _x doMove _p;
                };
            } forEach _cift;
        };
    } forEach _ciftler;

    // Varisa kadar bekle (en fazla 18 sn); gelmeyenlere emri 3 sn'de bir tazele.
    // Baski >= 0.85 ezilen kosmaya devam etmez: forceMove birakilir -> FSM hemen siper alir.
    private _pinned = [];
    private _bitis = time + ([18, 45] select _kacisModu);
    while {time < _bitis && {!isNull _group}} do {
        {
            private _b = _x select 0;
            if (alive _b && {!(_b in _pinned)} && {(getSuppression _b) >= ([0.85, 0.97] select _kacisModu)}) then {
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
        { (_x select 0) doMove (_x select 1); } forEach _gelmeyen;
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
    // TEK KALAN ASKER: savasma, SAKLAN — yatar, gizlenir, ates yok (GREEN); dusman 20 m'ye girerse (kosede kisti) savasir.
    private _tek = (count ((units _group) select {alive _x})) isEqualTo 1;
    private _yakinMesafe = [25, 20] select _tek;
    if (_tek) then {
        _group setCombatMode "GREEN";
        {
            if (alive _x) then {
                _x setBehaviour "STEALTH";
                _x setUnitPosWeak "DOWN";
            };
        } forEach (units _group);
    } else {
        _group setCombatMode "YELLOW";
    };

    diag_log format ["[TEMAS-KES] %1 sipere vardi, %2 sn bekleniyor%3", groupId _group, [25, 60] select _tek, ["", " (tek kalan: saklaniyor, ates yok)"] select _tek];

    // 25 sn (tek kalan: 60 sn) bekle; dusman yakin mesafeye girerse savas (bekleme biter)
    private _holdBitis = time + ([25, 60] select _tek);
    waitUntil {
        sleep 1;
        isNull _group
        || {time > _holdBitis}
        || {
            ((units _group) findIf {
                alive _x && {
                    private _e = _x findNearestEnemy _x;
                    !isNull _e && {(_x distance2D _e) < _yakinMesafe}
                }
            }) > -1
        }
    };

    // -----------------------------------------------------------------------
    // TEMIZLIK
    // -----------------------------------------------------------------------
    if (!isNull _group && {((_group getVariable [QGVAR(bcStartTime), -1]) isEqualTo _baslangic)}) then {
        { _x setVariable [QGVAR(taktikKilit), nil]; } forEach (units _group);
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
