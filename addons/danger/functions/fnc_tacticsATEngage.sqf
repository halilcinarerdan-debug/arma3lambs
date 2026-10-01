#include "script_component.hpp"
/*
 * Author: Cinar (ELITE fork)
 * AT ZIRHA TAARRUZ + PIYADE KORUMASI (AT escort)
 *
 * Doktrin: AT askeri zirha ates ederken kendisi cok savunmasizdir (roket yeniden doldurma,
 * ates sonrasi gorunur). Bu yuzden:
 *   - AT, zirha gorusu olan KORUNAKLI atis pozisyonuna gider (findCover OVERWATCH, zirhtan >= 60m)
 *   - Her AT'nin YANINA 2 dost piyade ESKORT olarak gider: AT'nin 6-9m'sine, DUSMAN PIYADE
 *     yonunde (+-40 derece) — AT zirha vururken eskort dusman piyadeyi bastirir (baski + nisan + UGL)
 *   - Kalan piyadeler yerinde dusman piyadeyi bastirir (UGL dahil)
 *   - Piyade yoksa eskort zirhin yonunu izler (AT'yi korur)
 *   - AT surekli selectWeapon launcher + doTarget + doFire zirhi; zirh olunce / mermi bitince / 50 sn sonra biter
 *   - Sis perdesi; hareket sprint, forceMove + AUTOCOMBAT/COVER kapali (varisa kadar)
 *
 * Karar: commanderAssess -> "AT_ENGAGE" (kendi AT'si var, zirh 70-400m).
 *
 * Arguments:
 * 0: group <GROUP> or leader <OBJECT>
 * 1: tehdit <OBJECT> or position <ARRAY>
 *
 * Return Value:
 * Bool
 *
 * Example (Zeus):
 * [_g, _tank] call lambs_danger_fnc_tacticsATEngage;
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

if (_group getVariable [QGVAR(isATEngage), false]) exitWith {false};
if (_group getVariable [QGVAR(isRetreating), false]) exitWith {false};
if (_group getVariable [QGVAR(isEvading), false]) exitWith {false};

// ---------------------------------------------------------------------------
// ZIRH + AT'LER
// ---------------------------------------------------------------------------
private _mySide = side _unit;
private _armor = (_unit nearEntities [["Tank", "Wheeled_APC_F"], 450]) select {
    alive _x
    && {(_mySide getFriend (side _x)) < 0.6}
    && {!((side _x) == civilian)}
};
if (_armor isEqualTo []) exitWith {false};
_armor = [_armor, [], {_unit distance2D _x}, "ASCEND"] call BIS_fnc_sortBy;
private _zirh = _armor select 0;

private _ats = (units _group) select {
    alive _x
    && {isNull objectParent _x}
    && {(secondaryWeapon _x) isNotEqualTo ""}
    && {(_x ammo (secondaryWeapon _x)) > 0}
};
if (_ats isEqualTo []) exitWith {false};
_ats = [_ats, [], {_x distance2D _zirh}, "ASCEND"] call BIS_fnc_sortBy;
_ats = _ats select [0, 2 min (count _ats)];

private _baslangic = time;
_group setVariable [QGVAR(isATEngage), true];
_group setVariable [QGVAR(isExecutingTactic), true];
_group setVariable [QGVAR(atEngageStart), _baslangic];

// ---------------------------------------------------------------------------
// GUVENLIK VALFI — sadece bu taarruzun bayraklarini + AI kilitlerini temizler
// ---------------------------------------------------------------------------
[_group, _baslangic, time + 75] spawn {
    params ["_g", "_start", "_limit"];
    waitUntil { time > _limit || {isNull _g} };
    if (!isNull _g && {((_g getVariable [QGVAR(atEngageStart), -1]) isEqualTo _start)}) then {
        if (_g getVariable [QGVAR(isATEngage), false]) then {
            _g setVariable [QGVAR(isATEngage), nil];
            _g setVariable [QGVAR(isExecutingTactic), nil];
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
                    _x setUnitPos "AUTO";
                    _x doWatch objNull;
                };
            } forEach (units _g);
            diag_log format ["[AT-TAARRUZ-VALF] %1 guvenlik valfi temizledi", groupId _g];
        };
    };
};

[_group, _zirh, _ats, _baslangic] spawn {
    params ["_group", "_zirh", "_ats", "_baslangic"];

    private _origCombat = combatMode _group;
    private _leader = leader _group;
    private _mySide = side _leader;
    private _uglFn = missionNamespace getVariable ["lambs_danger_fnc_tacticalUGL", {false}];

    // Bilinen dusman PIYADE (merkez etrafinda 300m): grup bilgisi veya 70m icinde
    private _piyadeBul = {
        params ["_merkez", "_taraf", "_g"];
        private _liste = (_merkez nearEntities ["CAManBase", 300]) select {
            alive _x
            && {(_taraf getFriend (side _x)) < 0.6}
            && {!((side _x) == civilian)}
            && {((_g knowsAbout _x) >= 0.5) || {(_x distance2D _merkez) < 70}}
        };
        [_liste, [], {_merkez distance2D _x}, "ASCEND"] call BIS_fnc_sortBy
    };

    // Eski kilitleri temizle
    {
        _x enableAI "PATH";
        _x enableAI "MOVE";
        _x enableAI "TARGET";
        _x enableAI "AUTOTARGET";
        _x enableAI "AUTOCOMBAT";
        _x enableAI "COVER";
    } forEach (units _group);

    private _hepsi = (units _group) select {alive _x && {isNull objectParent _x}};
    private _zirhPos = getPosATL _zirh;

    // -----------------------------------------------------------------------
    // ROLLER: AT'ler, her AT icin 2 ESKORT (en yakin), geri kalan = baski piyadesi
    // -----------------------------------------------------------------------
    private _kalan = _hepsi - _ats;
    private _eskortlar = [];
    {
        private _at = _x;
        private _sirali = [_kalan, [], {_x distance2D _at}, "ASCEND"] call BIS_fnc_sortBy;
        private _secilen = _sirali select [0, 2 min (count _sirali)];
        _eskortlar append _secilen;
        _kalan = _kalan - _secilen;
    } forEach _ats;
    private _baskiPiyade = _kalan;

    // Kilitler: LAMBS reaksiyonlari emri bozmasin (AT + eskort); kacma YOK
    _group setCombatMode "RED";
    _group enableAttack false;
    {
        _x setVariable [QGVAR(forceMove), true];
        _x allowFleeing 0;
        _x forceSpeed -1;
    } forEach (_ats + _eskortlar);

    // Sis perdesi (AT'nin yaklasma yoluna; ayri thread, fonksiyon yoksa atla)
    [_group, _zirhPos] spawn {
        params ["_g", "_zp"];
        private _sisFn = missionNamespace getVariable ["lambs_danger_fnc_tacticalSmoke", {false}];
        [_g, _zp, "COVER_MOVE"] call _sisFn;
    };

    // -----------------------------------------------------------------------
    // AT POZISYONLARI — zirha gorusu olan korunakli nokta (zirhtan >= 60m)
    // -----------------------------------------------------------------------
    private _atHedefler = [];   // [at, pos]
    {
        private _at = _x;
        private _hedef = getPosATL _at;
        private _cover = [_at, _zirh, 60, "ASCEND", 1, "OVERWATCH"] call EFUNC(main,findCover);
        if (_cover isNotEqualTo []) then {
            private _cp = (_cover select 0) select 0;
            if ((_cp distance2D _zirhPos) >= 60 && {(_cp distance2D _zirhPos) <= 420}) then {
                _hedef = _cp;
            };
        };
        _atHedefler pushBack [_at, _hedef];
    } forEach _ats;

    // Dusman piyade yonu (AT'nin ilk hedefi merkez alinir)
    private _atMerkez = (_atHedefler select 0) select 1;
    private _piyade0 = [_atMerkez, _mySide, _group] call _piyadeBul;
    private _piyadeYon = if (_piyade0 isNotEqualTo []) then {
        _atMerkez getDir (_piyade0 select 0)
    } else {
        _atMerkez getDir _zirhPos
    };

    diag_log format [
        "[AT-TAARRUZ-BASLA] %1 | zirh:%2 %3m | AT:%4 | eskort:%5 | baski piyade:%6 | dusman piyade:%7",
        groupId _group, typeOf _zirh, round (_leader distance2D _zirh),
        count _ats, count _eskortlar, count _baskiPiyade, count _piyade0
    ];

    // -----------------------------------------------------------------------
    // HAREKET: AT -> atis pozisyonu, ESKORT -> AT'nin yanina (dusman piyade yonunde)
    // -----------------------------------------------------------------------
    private _varis = [];

    {
        _x params ["_at", "_atPos"];
        _at disableAI "AUTOCOMBAT";
        _at disableAI "COVER";
        _at setUnitPosWeak "UP";
        _at moveTo _atPos;
        _varis pushBack [_at, _atPos, "MIDDLE"];
    } forEach _atHedefler;

    private _eskortSay = 0;
    private _atanan = [];
    {
        _x params ["_at", "_atPos"];
        // bu AT'ye atanan eskortlar: henuz atanmamis en yakin 2'si (ayni asker iki AT'ye gitmez)
        private _aday = (_eskortlar - _atanan) select {_x distance2D _at < 80};
        private _buEskort = [_aday, [], {_x distance2D _at}, "ASCEND"] call BIS_fnc_sortBy;
        _buEskort = _buEskort select [0, 2 min (count _buEskort)];
        _atanan append _buEskort;
        {
            private _ofs = [-40, 40] select (_eskortSay % 2);
            private _p = _atPos getPos [6 + random 3, _piyadeYon + _ofs];
            _x disableAI "AUTOCOMBAT";
            _x disableAI "COVER";
            _x setUnitPosWeak "UP";
            _x moveTo _p;
            _varis pushBack [_x, _p, "MIDDLE"];
            _eskortSay = _eskortSay + 1;
        } forEach _buEskort;
    } forEach _atHedefler;

    // Varisa kadar bekle (en fazla 14 sn); gelmeyenlere emri 3 sn'de bir tazele
    private _bitis = time + 14;
    while {time < _bitis && {!isNull _group}} do {
        private _gelmeyen = _varis select {
            alive (_x select 0) && {((_x select 0) distance2D (_x select 1)) > 6}
        };
        if (_gelmeyen isEqualTo []) exitWith {};
        { (_x select 0) moveTo (_x select 1); } forEach _gelmeyen;
        sleep 3;
    };

    // Vardilar: siperde alcal, ates serbest
    {
        _x params ["_b", "_p", "_s"];
        if (alive _b) then {
            _b enableAI "TARGET";
            _b enableAI "AUTOTARGET";
            _b setUnitPosWeak _s;
        };
    } forEach _varis;

    // -----------------------------------------------------------------------
    // TAARRUZ DONGUSU (en fazla 50 sn)
    //   AT        : zirha roket (selectWeapon launcher + doTarget + doFire)
    //   ESKORT    : AT'nin yaninda, dusman piyadeyi bastirir (baski + nisan + UGL)
    //   BASKI PIY.: yerinde dusman piyadeyi bastirir
    // -----------------------------------------------------------------------
    private _sonuc = "sure doldu";
    private _loopBitis = time + 50;
    while {time < _loopBitis && {!isNull _group}} do {
        if (!alive _zirh) exitWith { _sonuc = "zirh imha edildi"; };

        private _atVar = _ats select {alive _x && {(_x ammo (secondaryWeapon _x)) > 0}};
        if (_atVar isEqualTo []) exitWith { _sonuc = "AT mermisi bitti / AT oldu"; };

        // AT: roket
        {
            _x selectWeapon (secondaryWeapon _x);
            _x doTarget _zirh;
            _x doFire _zirh;
        } forEach _atVar;

        // dusman piyade (ilk canli AT'nin etrafinda)
        private _merkez = getPosATL (_atVar select 0);
        private _piyade = [_merkez, _mySide, _group] call _piyadeBul;
        private _pHedef = if (_piyade isEqualTo []) then {objNull} else {_piyade select 0};

        // eskort + baski piyadesi: dusman piyadeye karsi ortu
        {
            if (alive _x && {isNull objectParent _x}) then {
                if (!isNull _pHedef) then {
                    _x doWatch _pHedef;
                    [_x, AGLToASL (getPosATL _pHedef)] call EFUNC(main,doSuppress);
                    _x doTarget _pHedef;
                    if ((_x knowsAbout _pHedef) > 1) then {
                        _x doFire _pHedef;
                    };
                    [_x, _pHedef] call _uglFn;
                } else {
                    // piyade yok: eskort AT'yi korumak icin zirhin yonunu izler
                    _x doWatch _zirhPos;
                };
            };
        } forEach (_eskortlar + _baskiPiyade);

        sleep 2.5;
    };

    diag_log format ["[AT-TAARRUZ] %1 bitti: %2", groupId _group, _sonuc];

    // -----------------------------------------------------------------------
    // TEMIZLIK
    // -----------------------------------------------------------------------
    if (!isNull _group && {((_group getVariable [QGVAR(atEngageStart), -1]) isEqualTo _baslangic)}) then {
        _group setVariable [QGVAR(isATEngage), nil];
        _group setVariable [QGVAR(isExecutingTactic), nil];
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
                _x allowFleeing 0;
                _x setUnitPos "AUTO";
                _x doWatch objNull;
                _x doFollow (leader _x);
            };
        } forEach (units _group);

        diag_log format ["[AT-TAARRUZ-TAMAM] %1", groupId _group];
    };
};

true
