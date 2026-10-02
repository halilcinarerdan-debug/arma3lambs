#include "script_component.hpp"
/*
 * Author: Cinar (ELITE fork)
 * Kademeli Geri Cekilme — iki takim, 40m'lik DONUSUMLU sicramalar (bounding retreat)
 * 2026-10-01 v13
 *
 * Sorunlar (v11/v12):
 *   - "olduğu yerde durma": takimlar 0 / 25 / 50 sn'de sirayla kalkiyordu, bekleyenler ATES BILE ETMIYORDU
 *   - "rastgele kosma": forceMove yoktu, allowFleeing 1 + AUTOCOMBAT acikti -> LAMBS dodge/cover/panik
 *     reaksiyonlari emri eziyordu
 *
 * v13:
 *   - ALPHA (maneuver + reserve) ve BRAVO (FSE: MG'ler) dönüşümlü sıçrar:
 *       sicrama 1: ALPHA -> 40m   (BRAVO ortu atesi)
 *       sicrama 2: BRAVO -> 80m   (ALPHA ortu atesi)
 *       sicrama 3: ALPHA -> 120m  (BRAVO ortu atesi)
 *       sicrama 4: BRAVO -> 120m  (ALPHA ortu atesi)
 *     Hareket etmeyen takim doSuppress ile ates eder -> kimse bos durmaz.
 *   - Hareket eden askerlerde forceMove + AUTOCOMBAT/COVER/TARGET kapali + allowFleeing 0:
 *     LAMBS reaksiyonlari emri bozamaz, rastgele kosma yok.
 *   - Her asker kendi varis noktasina (waypoint etrafinda 7m) gider -> yigilma yok.
 *   - 45 sn cooldown, orijinal combatMode geri yuklenir, guvenlik valfi sadece KENDI cekilmesini temizler.
 *   - BASLA / sicrama / TAMAM satirlari debug kapaliyken de RPT'ye yazilir (tani icin).
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

if (_group getVariable [QGVAR(isRetreating), false]) exitWith {false};
if (_group getVariable [QGVAR(isEvading), false]) exitWith {false};
if (_group getVariable [QGVAR(isBreakingContact), false]) exitWith {false};

private _targetPos = _target call CBA_fnc_getPos;
if ((_targetPos select 2) > 6) then { _targetPos set [2, 0.5]; };
if (_targetPos isEqualTo [0, 0, 0]) exitWith {false};

// ---------------------------------------------------------------------------
// COOLDOWN — cekilme biteli 45 sn dolmadiysa tekrar kacma, pozisyon tut
// ---------------------------------------------------------------------------
private _sonBitis = _group getVariable [QGVAR(retreatEndTime), -999];
if ((time - _sonBitis) < 45) exitWith {
    _group setVariable [QGVAR(isExecutingTactic), true];
    [_group, 20] call FUNC(tacticsHold);
    // (kilit + enableAttack geri verme tacticsHold'un kendi 20 sn callback'inde)
    false
};

// ---------------------------------------------------------------------------
// CQB-IPTAL — 40m altinda + meskun mahal: kacmak olu demek, tut
// ---------------------------------------------------------------------------
private _cqbMesafe = _unit distance2D _targetPos;
private _cqbBinalar = nearestTerrainObjects [
    getPosATL _unit,
    ["BUILDING", "HOUSE", "CHURCH", "FUELSTATION"],
    30, false, true
];
private _cqbUrban = (count _cqbBinalar) >= 3;

if (_cqbMesafe < 40 && _cqbUrban) exitWith {
    _group setVariable [QGVAR(isExecutingTactic), true];
    [_group, 20] call FUNC(tacticsHold);
    // (kilit + enableAttack geri verme tacticsHold'un kendi 20 sn callback'inde)
    false
};

// ---------------------------------------------------------------------------
// WAYPOINT'LER — dusmandan uzaga, suya dusmesin
// ---------------------------------------------------------------------------
private _leaderPos = getPosATL _unit;
private _threatDir = [_targetPos, _leaderPos] call BIS_fnc_dirTo;

private _suKontrol = {
    params ["_p", "_o"];
    private _i = 0;
    while {surfaceIsWater _p && {_i < 6}} do {
        _p = _o getPos [((_p distance2D _o) * 0.7), (_o getDir _p)];
        _i = _i + 1;
    };
    _p
};

private _wp1 = [_leaderPos getPos [40, _threatDir], _leaderPos] call _suKontrol;
private _wp2 = [_leaderPos getPos [80, _threatDir], _leaderPos] call _suKontrol;
private _wp3 = [_leaderPos getPos [120, _threatDir], _leaderPos] call _suKontrol;
private _wps = [_wp1, _wp2, _wp3, _wp3];

private _baslangic = time;
_group setVariable [QGVAR(isRetreating), true];
_group setVariable [QGVAR(isExecutingTactic), true];
_group setVariable [QGVAR(retreatStartTime), _baslangic];

// ---------------------------------------------------------------------------
// GUVENLIK VALFI — sadece bu cekilmenin bayraklarini + AI kilitlerini temizler
// ---------------------------------------------------------------------------
[_group, _baslangic, time + 130] spawn {
    params ["_g", "_start", "_limit"];
    waitUntil { time > _limit || {isNull _g} };
    if (!isNull _g && {((_g getVariable [QGVAR(retreatStartTime), -1]) isEqualTo _start)}) then {
        if (_g getVariable [QGVAR(isRetreating), false]) then {
            _g setVariable [QGVAR(isRetreating), nil];
            _g setVariable [QGVAR(isExecutingTactic), nil];
            _g setVariable [QGVAR(retreatEndTime), time];
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
                    _x setBehaviour (if ((_g getVariable [QGVAR(contact), 0]) > time) then {"COMBAT"} else {"AWARE"});
                    _x allowFleeing 0;
                    _x setAnimSpeedCoef 1.0;
                    _x setUnitPos "AUTO";
                };
            } forEach (units _g);
            diag_log format ["[GERI-CEKILME-VALF] %1 guvenlik valfi temizledi", groupId _g];
        };
    };
};

// Tani icin BASLA / sicrama / TAMAM satirlari debug kapaliyken de RPT'ye yazilir
private _msgBasla = format [
    "[GERI-CEKILME-BASLA] %1 | tehdit:%2m | WP1:%3 WP2:%4 WP3:%5",
    groupId _group, round (_unit distance2D _targetPos), _wp1, _wp2, _wp3
];
diag_log _msgBasla;
if (EGVAR(main,debug_functions)) then {
    systemChat _msgBasla;
};

[_group, _unit, _targetPos, _wps, _baslangic] spawn {
    params ["_group", "_unit", "_targetPos", "_wps", "_baslangic"];

    private _origCombat = combatMode _group;
    private _origBeh = behaviour (leader _group);   // v7.5b: bitince AWARE'de KALMASIN
    private _targetASL = AGLToASL _targetPos;

    // Eski kilitleri temizle: onceki Peel/Retreat PATH/MOVE/TARGET'i kapali birakmis olabilir
    {
        _x enableAI "PATH";
        _x enableAI "MOVE";
        _x enableAI "TARGET";
        _x enableAI "AUTOTARGET";
        _x enableAI "AUTOCOMBAT";
        _x enableAI "COVER";
    } forEach (units _group);

    _group setFormation "FILE";
    _group setFormDir (_unit getDir _targetPos);
    _group setSpeedMode "FULL";
    _group enableAttack false;

    private _tumBirimler = (units _group) select {alive _x && {isNull objectParent _x}};

    // -----------------------------------------------------------------------
    // TAKIMLAR — ALPHA = maneuver + reserve (once sicrar), BRAVO = FSE (MG'ler, ortu atesi)
    // -----------------------------------------------------------------------
    private _takimlar = [_group] call FUNC(splitFireTeams);
    _takimlar params ["_fse", "_maneuver", "_reserve"];

    private _alpha = _reserve + _maneuver;
    private _bravo = +_fse;

    // Yedek: bir takim bos kalirsa (4 kisiden az vb.) ikiye bol
    if (_alpha isEqualTo [] || {_bravo isEqualTo []}) then {
        _alpha = [];
        _bravo = [];
        {
            if ((_forEachIndex % 2) isEqualTo 0) then {
                _alpha pushBack _x;
            } else {
                _bravo pushBack _x;
            };
        } forEach _tumBirimler;
    };

    // v7.5: "sadece lider cekiliyor, digerleri catismaya devam ediyor" duzeltmesi:
    //   - <= 4 asker: BOLME YOK, herkes birlikte (cift cift) cekilir (eskiden 3 kisilik grupta biri ates ediyordu)
    //   - > 4 asker: ortu takimi en fazla n/3 (MG'ler), geri kalan herkes sicrar
    private _nCek = count _tumBirimler;
    if (_nCek <= 4) then {
        _alpha = +_tumBirimler;
        _bravo = [];
    } else {
        private _bMax = ceil (_nCek / 3);
        if (count _bravo > _bMax) then {
            _alpha append (_bravo select [_bMax, count _bravo]);
            _bravo = _bravo select [0, _bMax];
        };
    };

    diag_log format [
        "[GERI-CEKILME] %1 takimlar | ALPHA:%2 BRAVO(FSE):%3 | toplam:%4",
        groupId _group, count _alpha, count _bravo, _nCek
    ];

    // Genel ayarlar: kacma YOK. forceMove burada TUM askerlere konmaz (ates altinda siper
    // alamiyorlardi); sadece HAREKET EDERKEN konur (_sicra icinde), varinca kalkar.
    {
        _x allowFleeing 0;
        _x setBehaviour "AWARE";
        _x setAnimSpeedCoef 1.15;
        _x forceSpeed -1;
    } forEach _tumBirimler;

    // Buddy ciftleri (2'li, en guclu + en zayif); fonksiyon yoksa takim tek grup sayilir
    private _pairFn = missionNamespace getVariable ["lambs_danger_fnc_buddyPairs", {[_this select 0]}];

    // -----------------------------------------------------------------------
    // SICRAMA — kapsama takimi ates eder, hareket eden takim 2'li CIFTLER halinde kosar
    // -----------------------------------------------------------------------
    private _sicra = {
        params ["_grup", "_hareketEdenler", "_kapsama", "_wp", "_hedefASL", "_no"];

        diag_log format [
            "[GERI-CEKILME] %1 sicrama %2 | hareket:%3 kapsama:%4",
            groupId _grup, _no, count _hareketEdenler, count _kapsama
        ];

        // 1) Kapsama: hedef alanina baski atesi (kimse bos durmaz)
        {
            if (alive _x && {isNull objectParent _x}) then {
                _x enableAI "TARGET";
                _x enableAI "AUTOTARGET";
                _x setUnitPosWeak "MIDDLE";
                [_x, _hedefASL] call EFUNC(main,doSuppress);
            };
        } forEach _kapsama;

        sleep 1.5;

        // 2) Hareket: 2'li BUDDY CIFTLERI — her cift ayni noktaya (ciftin icinde 3m), ciftler
        //    waypoint etrafinda 12m'e yayilir: kimse tek basina kosmaz, yigilma da yok
        private _varis = [];
        private _ciftler = [_hareketEdenler] call _pairFn;
        {
            private _cift = _x;
            private _ciftNokta = _wp getPos [random 12, random 360];
            if (surfaceIsWater _ciftNokta) then { _ciftNokta = _wp; };
            {
                if (alive _x && {isNull objectParent _x}) then {
                    _x disableAI "TARGET";
                    _x disableAI "AUTOTARGET";
                    _x disableAI "AUTOCOMBAT";
                    _x disableAI "COVER";
                    _x setVariable [QGVAR(forceMove), true];
                    _x setVariable [QEGVAR(main,currentTask), "Retreat/Bound", EGVAR(main,debug_functions)];
                    _x setUnitPosWeak "UP";
                    private _p = _ciftNokta getPos [random 4, random 360];
                    if (surfaceIsWater _p) then { _p = _ciftNokta; };
                    _varis pushBack [_x, _p];
                    _x moveTo _p;
                };
            } forEach _cift;
        } forEach _ciftler;

        // 3) Varisa kadar bekle (en fazla 14 sn); gelmeyenlere emri 3 sn'de bir tazele
        private _bitis = time + 14;
        private _pinned = [];
        while {time < _bitis && {!isNull _grup}} do {
            // Baski >= 0.85: ezilen kosmaya devam etmez, forceMove birakilir -> FSM siper alir
            {
                private _b = _x select 0;
                if (alive _b && {!(_b in _pinned)} && {(getSuppression _b) >= 0.85}) then {
                    _pinned pushBack _b;
                    _b setVariable [QGVAR(forceMove), nil];
                    _b enableAI "AUTOCOMBAT";
                    _b enableAI "COVER";
                    _b setUnitPosWeak "DOWN";
                };
            } forEach _varis;

            private _gelmeyen = _varis select {
                alive (_x select 0)
                && {!((_x select 0) in _pinned)}
                && {((_x select 0) distance2D (_x select 1)) > 9}
            };
            if (_gelmeyen isEqualTo []) exitWith {};
            { (_x select 0) moveTo (_x select 1); } forEach _gelmeyen;
            sleep 3;
        };

        // Sicrama sonucu (diagnostik): kac asker gercekten vardi
        diag_log format [
            "[GERI-CEKILME] %1 sicrama %2 sonuc | vardi:%3/%4 | ezilen:%5",
            groupId _grup, _no,
            count (_varis select {alive (_x select 0) && {((_x select 0) distance2D (_x select 1)) <= 9}}),
            count _varis, count _pinned
        ];

        // 4) Vardilar: siperde alcal, artik ortu atesi veren takima katilirlar
        {
            private _b = _x select 0;
            if (alive _b) then {
                _b setVariable [QGVAR(forceMove), nil];
                _b enableAI "TARGET";
                _b enableAI "AUTOTARGET";
                _b enableAI "AUTOCOMBAT";
                _b enableAI "COVER";
                _b setUnitPosWeak "MIDDLE";
                [_b, _hedefASL] call EFUNC(main,doSuppress);
            };
        } forEach _varis;
    };

    // SIS PERDESI (AYRI thread + fonksiyon yoksa sessizce atla: sis hatasi geri cekilmeyi durdurmasin)
    [_group, _targetPos] spawn {
        params ["_g", "_tp"];
        private _sisFn = missionNamespace getVariable ["lambs_danger_fnc_tacticalSmoke", {false}];
        [_g, _tp, "BREAK_CONTACT"] call _sisFn;
    };

    private _sira = if (_bravo isEqualTo []) then {
        [
            [_alpha, [], 0],
            [_alpha, [], 1],
            [_alpha, [], 2]
        ]
    } else {
        [
            [_alpha, _bravo, 0],
            [_bravo, _alpha, 1],
            [_alpha, _bravo, 2],
            [_bravo, _alpha, 3]
        ]
    };

    {
        _x params ["_hareket", "_kapsama", "_wpIdx"];
        if (isNull _group) exitWith {};
        if ((_hareket select {alive _x}) isEqualTo []) then { continue };
        [
            _group,
            _hareket select {alive _x},
            _kapsama select {alive _x},
            _wps select _wpIdx,
            _targetASL,
            _wpIdx + 1
        ] call _sicra;
    } forEach _sira;

    // -----------------------------------------------------------------------
    // TEMIZLIK
    // -----------------------------------------------------------------------
    if (!isNull _group && {((_group getVariable [QGVAR(retreatStartTime), -1]) isEqualTo _baslangic)}) then {
        _group setVariable [QGVAR(isRetreating), nil];
        _group setVariable [QGVAR(isExecutingTactic), nil];
        _group setVariable [QGVAR(retreatEndTime), time];
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
                // temas suruyorsa COMBAT (siper arar / yatar), degilse cekilme oncesi davranis
                _x setBehaviour (if ((_group getVariable [QGVAR(contact), 0]) > time) then {"COMBAT"} else {_origBeh});
                _x allowFleeing 0;
                _x setAnimSpeedCoef 1.0;
                _x setUnitPos "AUTO";
                _x doWatch objNull;
                _x doFollow (leader _x);
            };
        } forEach (units _group);

        diag_log format ["[GERI-CEKILME-TAMAM] %1", groupId _group];
    };
};

true
