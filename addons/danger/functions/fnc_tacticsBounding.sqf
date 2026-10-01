#include "script_component.hpp"
/*
 * Author: Cinar (ELITE fork)
 * Grup, USMC doktrinine uygun "Bounding Overwatch" manevrasi yapar.
 * 2026-10-01 v3 — OLUMCUL + GOZLE GORULUR
 *   - Her cycle 3 faz: ATES (1.5 sn) -> HAREKET (varisa kadar) -> ORTAK ATES
 *   - Hareket sprint (UP) ile; siper stance'i VARISTA (eskiden yatarak yola cikiyordu)
 *   - ODAK ATES: tum kapsama ekibi ayni dusmana (doTarget/doFire) + alana baski
 *   - Her 3. cycle FSE ileri sicrar, maneuver ortu verir (gercek leapfrog)
 *   - Buddy ciftleri: 2'li (en guclu + en zayif), MG kosmaz, tek kalan ilerler
 *   - combatMode RED (bitince geri yuklenir), lider jest + callout
 *   - Siper yok / ileri degilse yanal acili 25m atilim (capraz ates)
*/

params ["_group", "_target", ["_units", []], ["_delay", 180]];

// ---------------------------------------------------------------------------
// Lokal bounding sabitleri (USMC doktrini)
// ---------------------------------------------------------------------------
private _BND_ASSAULT_RANGE   = 55;
private _BND_CYCLE_BASE      = 2.5;   // ortak ates bekleme (sn)
private _BND_CYCLE_RAND      = 1.5;
private _BND_SUPPRESSION_MUL = 3;
private _BND_MAX_CYCLES      = 14;
private _BND_COVER_RANGE     = 30;    // ileri siper arama menzili (m)

// ---------------------------------------------------------------------------
// Grup / lider dogrulama
// ---------------------------------------------------------------------------
if (isNull _group) exitWith {false};
if (_group isEqualType objNull) then {_group = group _group;};
if ((units _group) isEqualTo []) exitWith {false};
private _unit = leader _group;

// ---------------------------------------------------------------------------
// Hedefi normalize et
// ---------------------------------------------------------------------------
_target = _target call CBA_fnc_getPos;
if ((_target select 2) > 6) then {
    _target set [2, 0.5];
};

private _targetASL = AGLToASL _target;

// ---------------------------------------------------------------------------
// CQB ise assault'a devret
// ---------------------------------------------------------------------------
private _boundingCQB = (GVAR(cqbRange) min 20);
if (_unit distance2D _target < _boundingCQB) exitWith {
    [_group, _target] call FUNC(tacticsAssault);
    false
};

// ---------------------------------------------------------------------------
// Minimum 4 kisi
// ---------------------------------------------------------------------------
if (count (units _group) < 4) exitWith {
    [_group, _target] call FUNC(tacticsFlank);
    false
};

// ---------------------------------------------------------------------------
// Taktik kilidi + bounding bayragi
// ---------------------------------------------------------------------------
_group setVariable [QGVAR(isExecutingTactic), true];
_group setVariable [QGVAR(isBounding), true];
_group setVariable [QGVAR(boundingStartTime), time];
private _bndToken = format ["%1-%2", time, random 1000000];
_group setVariable [QGVAR(bndToken), _bndToken];

// ---------------------------------------------------------------------------
// Cleanup timer
// ---------------------------------------------------------------------------
[
    {
        params [["_group", grpNull], ["_delay", 0], "", "", ["_token", ""]];
        time > _delay
        || {isNull _group}
        || { !(_group getVariable [QGVAR(isExecutingTactic), false]) }
        || { (_group getVariable [QGVAR(bndToken), ""]) isNotEqualTo _token }
    },
    {
        params [["_group", grpNull], "", ["_speedMode", "NORMAL"], ["_formation", "WEDGE"], ["_token", ""]];
        // Token eslesmiyorsa baska bir taktik (Retreat / yeni Bounding) devraldi -> dokunma
        if (!isNull _group && {(_group getVariable [QGVAR(bndToken), ""]) isEqualTo _token}) then {
            _group setVariable [QGVAR(bndToken), nil];
            _group enableAttack true;
            _group setCombatMode (_group getVariable [QGVAR(bndOrigCombat), "YELLOW"]);
            (units _group) allowGetIn true;
            _group setVariable [QGVAR(isExecutingTactic), nil];
            _group setVariable [QGVAR(isBounding), nil];
            _group setVariable [QEGVAR(main,currentTactic), nil];
            _group setSpeedMode _speedMode;

            private _u2 = leader _group;
            private _t2 = _u2 getVariable [QEGVAR(main,currentTarget), [0,0,0]];
            _t2 = _t2 call CBA_fnc_getPos;
            if (_t2 isEqualTo [0,0,0]) then { _t2 = getPosATL _u2 vectorAdd [50, 0, 0]; };
            private _yeniForm = [_u2, _t2, "BOUNDING"] call FUNC(selectFormation);
            _group setFormation _yeniForm;

            {
                _x setVariable [QEGVAR(main,currentTask), nil, EGVAR(main,debug_functions)];
                _x setVariable [QGVAR(forceMove), nil];
                _x setUnitPos "AUTO";
                _x doWatch objNull;
                _x doFollow (leader _x);
            } forEach (units _group);
        };
    },
    [_group, time + _delay, speedMode _unit, formation _unit, _bndToken]
] call CBA_fnc_waitUntilAndExecute;

// ---------------------------------------------------------------------------
// Hazir birlikleri bul
// ---------------------------------------------------------------------------
if (_units isEqualTo []) then {
    _units = _unit call lambs_main_fnc_findReadyUnits;
};
if (count _units < 4) then {
    _units = (units _group) select {alive _x && {isNull objectParent _x}};
};
if (count _units < 4) exitWith {
    _group setVariable ["lambs_danger_isBounding", nil];
    _group setVariable ["lambs_danger_isExecutingTactic", nil];
    false
};

// ---------------------------------------------------------------------------
// Araclar
// ---------------------------------------------------------------------------
private _vehicles = [_unit] call EFUNC(main,findReadyVehicles);

// ---------------------------------------------------------------------------
// Hedef cevresindeki potansiyel hedefler
// ---------------------------------------------------------------------------
private _posList = [_target, 20, true, false] call EFUNC(main,findBuildings);
_posList append ((nearestTerrainObjects [_target, ["HIDE", "TREE", "BUSH", "SMALL TREE"], 8, false, true]) apply { (getPosATL _x) vectorAdd [0, 0, random 2] });
_posList pushBack _target;

// ---------------------------------------------------------------------------
// Gorev degiskenleri
// ---------------------------------------------------------------------------
_unit setVariable [QEGVAR(main,currentTarget), _target, EGVAR(main,debug_functions)];
_unit setVariable [QEGVAR(main,currentTask), "Tactics Bounding", EGVAR(main,debug_functions)];
_group setVariable [QEGVAR(main,currentTactic), "Bounding Overwatch", EGVAR(main,debug_functions)];

// ---------------------------------------------------------------------------
// Jest + callout
// ---------------------------------------------------------------------------
[_unit, ["gestureGo"]] call EFUNC(main,doGesture);
[_units select -1, "gestureGoB"] call EFUNC(main,doGesture);

private _sonCallout = _group getVariable [QGVAR(bndSonCallout), 0];
if (time - _sonCallout > 60) then {
    [_unit, "combat", "Advance", 125] call EFUNC(main,doCallout);
    _group setVariable [QGVAR(bndSonCallout), time];
};

// ---------------------------------------------------------------------------
// Grubu hazirla
// ---------------------------------------------------------------------------
_group setFormDir (_unit getDir _target);

private _formation = [_unit, _target, "BOUNDING"] call FUNC(selectFormation);
_group setFormation _formation;
_group setVariable [QGVAR(dangerFormation), _formation];

_group enableAttack false;
// Olumculuk: serbest ates (combatMode RED); bitince orijinal geri yuklenir
_group setVariable [QGVAR(bndOrigCombat), combatMode _group];
_group setCombatMode "RED";
_units allowGetIn false;
_units doWatch _target;

{
    _x setVariable [QGVAR(forceMove), true];
    _x forceSpeed -1;
} forEach (_units select {isNull objectParent _x});

// ---------------------------------------------------------------------------
// FAZ 2: FIRE TEAM SUBDIVISION
// ---------------------------------------------------------------------------
private _teams = [_group] call FUNC(splitFireTeams);
_teams params ["_fse", "_maneuver", "_reserve"];

if (_fse isEqualTo [] || _maneuver isEqualTo []) then {
    _fse = [];
    _maneuver = [];
    {
        if ((_forEachIndex % 2) isEqualTo 0) then {
            _fse pushBack _x;
        } else {
            _maneuver pushBack _x;
        };
    } forEach _units;
    _reserve = [];
};

if (_fse isEqualTo [] || _maneuver isEqualTo []) exitWith {
    _group setVariable ["lambs_danger_isBounding", nil];
    _group setVariable ["lambs_danger_isExecutingTactic", nil];
    false
};

// ---------------------------------------------------------------------------
// Debug
// ---------------------------------------------------------------------------
if (EGVAR(main,debug_functions)) then {
    ["%1 TACTICS BOUNDING (%2 with %3 units [FSE:%4 MVR:%5 RES:%6] @ %7m)", side _unit, name _unit, count _units, count _fse, count _maneuver, count _reserve, round (_unit distance2D _target)] call EFUNC(main,debugLog);

    private _m  = [_unit,   "tactics bounding", _unit call EFUNC(main,debugMarkerColor), "hd_arrow"]    call EFUNC(main,dotMarker);
    private _mt = [_target, "",                 _unit call EFUNC(main,debugMarkerColor), "hd_objective"] call EFUNC(main,dotMarker);
    {_x setMarkerSizeLocal [0.6, 0.6];} forEach [_m, _mt];
    _m setMarkerDirLocal (_unit getDir _target);
    [{{deleteMarker _x; true} count _this;}, [_m, _mt], _delay + 30] call CBA_fnc_waitAndExecute;
};

// ---------------------------------------------------------------------------
// Bounding dongusunu ayri scheduled thread'de baslat
// ---------------------------------------------------------------------------
[_group, _fse, _maneuver, _reserve, _target, _targetASL, _vehicles, _unit,
 _BND_ASSAULT_RANGE, _BND_CYCLE_BASE, _BND_CYCLE_RAND, _BND_SUPPRESSION_MUL,
 _BND_MAX_CYCLES, _BND_COVER_RANGE, _bndToken] spawn {

    params [
        "_group", "_fse", "_maneuver", "_reserve", "_target", "_targetASL", "_vehicles", "_leader",
        "_BND_ASSAULT_RANGE", "_BND_CYCLE_BASE", "_BND_CYCLE_RAND", "_BND_SUPPRESSION_MUL",
        "_BND_MAX_CYCLES", "_BND_COVER_RANGE", "_bndToken"
    ];

    private _cycleCount = 0;

    // Fonksiyon kayitli degilse (XEH_PREP eksik) hata vermeden devam: rol=TUFEKLI, sis=yok
    private _rolFn = missionNamespace getVariable ["lambs_danger_fnc_getUnitRole", {"RIFLE"}];
    private _sisFn = missionNamespace getVariable ["lambs_danger_fnc_tacticalSmoke", {false}];
    private _pairFn = missionNamespace getVariable ["lambs_danger_fnc_buddyPairs", {[_this select 0]}];

    // -----------------------------------------------------------------------
    // YARDIMCI KODLAR
    // -----------------------------------------------------------------------

    // Bounding'i temiz bitirir (bayraklar + enableAttack/allowGetIn/doWatch/combatMode geri)
    private _bndTemizle = {
        params ["_g"];
        _g setVariable [QGVAR(bndToken), nil];
        _g setVariable [QGVAR(isBounding), nil];
        _g setVariable [QGVAR(isExecutingTactic), nil];
        _g setVariable [QEGVAR(main,currentTactic), nil];
        _g enableAttack true;
        _g setCombatMode (_g getVariable [QGVAR(bndOrigCombat), "YELLOW"]);
        (units _g) allowGetIn true;
        {
            _x setVariable [QGVAR(forceMove), nil];
            _x doWatch objNull;
            _x setUnitPos "AUTO";
        } forEach (units _g);
    };

    // ODAK: grubun bildigi en yakin dusman (hepsi AYNI hedefe ates eder = yogun ates)
    private _odakSec = {
        params ["_g"];
        private _l = leader _g;
        private _e = _l findNearestEnemy _l;
        if (isNull _e || {!alive _e} || {(_l distance2D _e) > 450}) then {objNull} else {_e}
    };

    // ATES: kapsama ekibi alana baski + ODAK dusmana nisan (bilinen dusmana doFire)
    private _atesEt = {
        params ["_birimler", "_hedef", "_hedefASL", "_odak", "_gorev"];
        {
            if (alive _x && {isNull objectParent _x}) then {
                _x setVariable [QEGVAR(main,currentTask), _gorev, EGVAR(main,debug_functions)];
                _x doWatch _hedef;
                [_x, _hedefASL] call EFUNC(main,doSuppress);
                if (!isNull _odak && {alive _odak} && {(_x distance2D _odak) < 350}) then {
                    _x doTarget _odak;
                    if ((_x knowsAbout _odak) > 1) then {
                        _x doFire _odak;
                    };
                };
            };
        } forEach _birimler;
    };

    // Kosucu hareketi: ADVANCE modunda ILERI siperli sicrama; siper yoksa / ileri degilse
    // yanal acili 25m atilim (capraz ates + dagilma). Siper stance'i VARISTA uygulanir
    // (eskiden yatarak/cokerek yola cikiyordu -> yavas ve gorunmez).
    // Doner: [birim, hedefPos, varisStance] veya []
    private _kosanHareket = {
        params ["_kosan", "_hedef", "_siperMenzil", "_hucumMenzil", "_gorev"];
        if (!alive _kosan || {!isNull objectParent _kosan}) exitWith {[]};

        private _mesafe = _kosan distance2D _hedef;
        private _cover = [_kosan, _hedef, _siperMenzil, "ASCEND", 1, "ADVANCE"] call EFUNC(main,findCover);
        private _movePos = [];
        private _stance = "MIDDLE";

        if (_cover isNotEqualTo []) then {
            private _cp = (_cover select 0) select 0;
            // en az 6m ILERI kazanc yoksa siper sayma (yerinde saymasin)
            if ((_mesafe - (_cp distance2D _hedef)) >= 6) then {
                _movePos = _cp;
                _stance = (_cover select 0) select 1;
            };
        };

        if (_movePos isEqualTo []) then {
            private _kayma = [-25, 25] select ((((units (group _kosan)) find _kosan) max 0) % 2);
            private _kalan = (_mesafe - _hucumMenzil) max 0;
            _movePos = (getPosATL _kosan) getPos [(25 min _kalan), ((_kosan getDir _hedef) + _kayma)];
            _stance = "MIDDLE";
        };

        _kosan setVariable [QEGVAR(main,currentTask), _gorev, EGVAR(main,debug_functions)];
        _kosan setUnitPosWeak "UP";
        _kosan moveTo _movePos;
        _kosan doWatch _hedef;
        _kosan forceSpeed -1;

        [_kosan, _movePos, _stance]
    };

    // Taktik sis: dusmana dogru, hareket eden birligin onune (tacticalSmoke cooldown'u var)
    [_group, _target, "COVER_MOVE"] call _sisFn;

    // FORMASYON ZORLAMA
    [_group] spawn {
        params ["_g"];
        while {!isNull _g && {_g getVariable ["lambs_danger_isBounding", false]}} do {
            private _df = _g getVariable ["lambs_danger_dangerFormation", ""];
            if (_df isNotEqualTo "" && {formation _g isNotEqualTo _df}) then {
                _g setFormation _df;
            };
            sleep 0.5;
        };
    };

    // =======================================================================
    // ANA DONGU — her cycle: ATES (1.5 sn) -> HAREKET (varisa kadar) -> ORTAK ATES
    //   normal cycle : maneuver BUDDY RUSH (ciftlerde kosan), FSE + reserve + destekler ates eder
    //   her 3. cycle : FSE (+reserve) ILERI sicrar, maneuver ortu atesi verir  (takim leapfrog)
    // =======================================================================
    while {
        !isNull _group
        && {(_group getVariable [QGVAR(isBounding), false])}
        && {(_group getVariable [QGVAR(isExecutingTactic), false])}
        && {(leader _group) distance2D _target > _BND_ASSAULT_RANGE}
        && {{alive _x} count (units _group) >= 2}
        && {_cycleCount < _BND_MAX_CYCLES}
    } do {
        _cycleCount = _cycleCount + 1;

        // Siste periyodik sis (cooldown 45 sn icinde)
        if ((_cycleCount % 3) isEqualTo 2) then {
            [_group, _target, "COVER_MOVE"] call _sisFn;
        };

        // KAYIP KONTROLU — komutan her cycle'da yeniden degerlendirir.
        private _komutanKarar = [_group, _target] call FUNC(commanderAssess);
        if (_komutanKarar in ["WITHDRAW", "PEEL"]) exitWith {
            [_group] call _bndTemizle;
            [_group, _target] call FUNC(tacticsRetreat);
        };

        // FORMASYON KORUMA
        private _bndFormation = _group getVariable [QGVAR(dangerFormation), "WEDGE"];
        private _mevcutFormation = formation _group;
        if (_mevcutFormation isNotEqualTo _bndFormation) then {
            _group setFormation _bndFormation;
        };

        // FORMASYON GUNCELLEME (arazi degisti mi)
        private _sonPos = _group getVariable [QGVAR(bndSonPos), [0,0,0]];
        private _simdiPos = getPosATL (leader _group);
        private _uzaklik = _sonPos distance2D _simdiPos;

        if (_cycleCount isEqualTo 1 || {_uzaklik > 5}) then {
            _group setVariable [QGVAR(bndSonPos), _simdiPos];
            private _yeniFormasyon = [leader _group, _target, "BOUNDING"] call FUNC(selectFormation);
            if (_yeniFormasyon isNotEqualTo _bndFormation) then {
                _group setVariable [QGVAR(dangerFormation), _yeniFormasyon];
                _group setFormation _yeniFormasyon;
            };
        };

        // Canli birlikleri yeniden ayir
        _fse      = _fse select {alive _x};
        _maneuver = _maneuver select {alive _x};
        _reserve  = _reserve select {alive _x};

        if (count _fse < 2 && {count _reserve > 0}) then {
            _fse pushBack (_reserve deleteAt 0);
        };
        if (count _maneuver < 2 && {count _reserve > 0}) then {
            _maneuver pushBack (_reserve deleteAt 0);
        };

        private _odak = [_group] call _odakSec;

        // -------------------------------------------------------------------
        // HANGI EKIP HAREKET EDIYOR?
        // -------------------------------------------------------------------
        private _fseSicrama = ((_cycleCount % 3) isEqualTo 0) && {(count _maneuver) >= 2} && {(count _fse) > 0};
        private _hareketEdecek = [];
        private _kapsama = [];

        if (_fseSicrama) then {
            // FSE (+reserve) ileri sicrar; maneuver ortu atesi verir
            _hareketEdecek = _fse + _reserve;
            _kapsama = +_maneuver;
        } else {
            // BUDDY RUSH: maneuver 2'li cift (en guclu + en zayif), ciftlerde bir kosar, biri ortu verir
            private _ciftler = [_maneuver] call _pairFn;

            private _kosanlar = [];
            private _destekTum = [];
            {
                private _cift = _x;
                if ((count _cift) isEqualTo 1) then {
                    // tek kalan bounder FSE ates ederken ilerler
                    _kosanlar pushBack (_cift select 0);
                } else {
                    // MG kosmaz; sadece MG'lerden olusan ciftte hepsi aday
                    private _adaylar = _cift select {([_x] call _rolFn) isNotEqualTo "MG"};
                    if (_adaylar isEqualTo []) then { _adaylar = +_cift; };
                    private _kosan = _adaylar select (_cycleCount % (count _adaylar));
                    _kosanlar pushBack _kosan;
                    _destekTum append (_cift - [_kosan]);
                };
            } forEach _ciftler;

            _hareketEdecek = _kosanlar;
            _kapsama = _fse + _reserve + _destekTum;
        };

        // -------------------------------------------------------------------
        // 1) ATES FAZI — kapsama ekibi ates acar, MG/nisanci korunakli atis pozisyonuna
        // -------------------------------------------------------------------
        if ((_cycleCount % 4) isEqualTo 1) then {
            {
                if (alive _x && {isNull objectParent _x} && {([_x] call _rolFn) in ["MG", "MARKSMAN"]}) then {
                    private _ow = [_x, _target, 30, "ASCEND", 1, "OVERWATCH"] call EFUNC(main,findCover);
                    if (_ow isNotEqualTo []) then {
                        private _owPos = (_ow select 0) select 0;
                        if ((_x distance2D _owPos) > 4) then {
                            _x moveTo _owPos;
                        };
                        _x setUnitPosWeak ((_ow select 0) select 1);
                    };
                };
            } forEach _kapsama;
        };

        [_kapsama, _target, _targetASL, _odak, if (_fseSicrama) then {"Bound/Cover(Maneuver)"} else {"Bound/Suppress"}] call _atesEt;
        sleep 1.5;

        // -------------------------------------------------------------------
        // 2) HAREKET FAZI — kosanlar siperli ileri sicrama
        // -------------------------------------------------------------------
        private _hareketler = [];
        {
            private _h = [_x, _target, _BND_COVER_RANGE, _BND_ASSAULT_RANGE, if (_fseSicrama) then {"Leapfrog/Move"} else {"BuddyRush/Move"}] call _kosanHareket;
            if (_h isNotEqualTo []) then { _hareketler pushBack _h; };
        } forEach _hareketEdecek;

        // Gozle gorulur: lider jest + callout (30 sn'de bir)
        if (_hareketler isNotEqualTo []) then {
            [leader _group, ["gestureGo"]] call EFUNC(main,doGesture);
            private _sonCycleCallout = _group getVariable [QGVAR(bndSonCycleCallout), 0];
            if ((time - _sonCycleCallout) > 30) then {
                [leader _group, "combat", "Advance", 125] call EFUNC(main,doCallout);
                _group setVariable [QGVAR(bndSonCycleCallout), time];
            };

            if (EGVAR(main,debug_functions)) then {
                diag_log format [
                    "[BUDDY-RUSH] %1 | cycle:%2 | %3 | hareket:%4 kapsama:%5 | odak:%6",
                    groupId _group, _cycleCount, ["buddy", "FSE-sicrama"] select _fseSicrama,
                    count _hareketler, count _kapsama,
                    if (isNull _odak) then {"yok"} else {name _odak}
                ];
            };
        };

        // Araclar
        { _x doMove _target; } forEach _vehicles;

        // Varisa kadar bekle (9 sn + baski kadar ek), varan askere siper stance'i
        private _maxSupp = 0;
        { _maxSupp = _maxSupp max (getSuppression _x); } forEach (_hareketEdecek select {alive _x});
        private _bekleBitis = time + 9 + (_maxSupp * 4);
        private _inen = [];

        waitUntil {
            sleep 0.5;
            {
                _x params ["_b", "_p", "_s"];
                if (alive _b && {!(_b in _inen)} && {(_b distance2D _p) < 4}) then {
                    _inen pushBack _b;
                    _b setUnitPosWeak _s;
                };
            } forEach _hareketler;
            isNull _group
            || {!(_group getVariable [QGVAR(isBounding), false])}
            || {time > _bekleBitis}
            || {(_hareketler findIf {alive (_x select 0) && {!((_x select 0) in _inen)}}) isEqualTo -1}
        };

        // Varamayanlar da siper stance'ine gecsin
        {
            _x params ["_b", "_p", "_s"];
            if (alive _b) then { _b setUnitPosWeak _s; };
        } forEach _hareketler;

        // -------------------------------------------------------------------
        // 3) ORTAK ATES — kosanlar siperde, herkes baski + odak ates
        // -------------------------------------------------------------------
        private _odak2 = [_group] call _odakSec;
        [(_hareketEdecek + _kapsama) select {alive _x}, _target, _targetASL, _odak2, "Bound/Fire"] call _atesEt;

        sleep (_BND_CYCLE_BASE + (random _BND_CYCLE_RAND) + (_maxSupp * _BND_SUPPRESSION_MUL));
    };

    // Dongu bitti — token eslesiyorsa bu bounding hala bizim (Retreat devralmadi)
    if (
        !isNull _group
        && {(_group getVariable [QGVAR(bndToken), ""]) isEqualTo _bndToken}
    ) then {
        private _yakin = ((leader _group) distance2D _target < (_BND_ASSAULT_RANGE + 10))
            && {({alive _x} count (units _group)) >= 2};
        [_group] call _bndTemizle;
        if (_yakin) then {
            [_group, _target] call FUNC(tacticsAssault);
        } else {
            // Cycle limiti doldu / hedef uzak: kilidi birak, gruba normal davranisi geri ver
            { if (alive _x) then { _x doFollow (leader _x); }; } forEach (units _group);
        };
    };
};

// end
true
