#include "script_component.hpp"
/*
 * Author: Cinar (ELITE fork)
 * PLAN ZIRH DESTEK (v8.163) — kullanici: "tank mevzilenmedi, aptal gibi bekledi; tankta hala tik yok; piyadeler combata gecti tank awarede; secim ekraninda sadece piyade vardi".
 * Zeus 'ELITE Objektif' elle secimde secilen TANK / zirhli grup (lider kara aracinda, tasima kapasitesi yok ya da Tank) plan hashinde 'zirhG' olur ve bu fonksiyon plan dongusunde HER TURDA cagrilir:
 *   KUR / TOPLAN / TASIMA / RECON : bekler (piyade toplanir)
 *   ORP ve sonrasi (KESIF / SALDIRI / TOPLANMA / CEKILME / MEVZI / BEKLE): BIR KEZ ates pozisyonu secer (SBF'ye yakin, objektife 380-680 m, su / bina / sik agac disi, objektife gorus hatti VAR (VIEW / FIRE LOD),
 *     yol disi tercih, 500 m'ye yakin tercih) -> surucuye doMove (COMBAT, NORMAL); varinca doStop + tum murettebat objektife doWatch.
 *   Savas modu: KESIF / SALDIRI / TOPLANMA, ya da plan piyadesinden biri temasta -> COMBAT + combatMode RED; degilse COMBAT + YELLOW. Gunner objektif cevresinde BILINEN dusmani (900 m icinde) hedef alir (6 sn'de bir).
 *   Plan biterse (BITTI / IPTAL) serbest birakilir: planAktif silinir, AWARE + YELLOW + doWatch bos.
 * aracSenkron bu gruplari atlar (lambs_danger_planZirh): piyadeyi beklemek icin tankin forceSpeed 0 alinmasi engellenir. Log: [PLAN-ZIRH].
 *
 * Arguments:
 * 0: Plan <HASHMAP>
 *
 * Return Value: None
 * Public: No
*/

params ["_plan"];
private _zg = (_plan getOrDefault ["zirhG", []]) select {!isNull _x};
if (_zg isEqualTo []) exitWith {};
private _id = _plan get "id";
private _faz = _plan get "faz";
private _obj = _plan get "obj";
private _sbf = _plan get "sbf";

// ---- serbest birak ----
if (_faz in ["BITTI", "IPTAL"]) exitWith {
    {
        private _g = _x;
        if (_g getVariable ["lambs_danger_planZirh", false]) then {
            _g setVariable ["lambs_danger_planZirh", nil];
            _g setVariable ["lambs_danger_planZirhPoz", nil];
            _g setVariable ["lambs_danger_planZirhVardi", nil];
            _g setVariable ["lambs_danger_planAktif", nil, true];
            _g setBehaviour "AWARE";
            _g setCombatMode "YELLOW";
            { _x doWatch objNull; } forEach (units _g);
            diag_log format ["[PLAN-ZIRH] %1 | %2 serbest birakildi (plan %3)", _id, groupId _g, _faz];
        };
    } forEach _zg;
};

// v8.178: DONUS fazinda (HQ'ya donus) zirh destek gruplari komuta dongusunun emrinde: ates pozisyonunu tekrar atamaz
if (_faz isEqualTo "DONUS") exitWith {};
if (_faz in ["KUR", "TOPLAN", "TASIMA", "RECON"]) exitWith {};

private _piyadeTemas = ((_plan getOrDefault ["gruplar", []]) findIf {((_x getVariable ["lambs_danger_contact", 0]) > time)}) >= 0;
private _savas = (_faz in ["KESIF", "SALDIRI", "TOPLANMA", "CEKILME"]) || {_piyadeTemas};

{
    private _g = _x;
    if (!local _g || {({alive _x} count (units _g)) isEqualTo 0}) then { continue };
    private _l = leader _g;
    private _v = vehicle _l;
    if (_v isEqualTo _l || {!alive _v}) then { continue };
    private _d = driver _v;
    if (isNull _d || {isPlayer _d}) then { continue };
    // v8.175 TANK ROLU: kargosuz tank uzaktan agir ates destegi (650 m, SALDIRI'da 450 m'ye sicrar), hedef onceligi zirh > AT > MG; ates acik alana gelince objektif alanina bastirma atesi (dost 70 m disinda)
    private _tankMi = (([_v] call FUNC(aracSinif)) select 0) isEqualTo "TANK";
    _g setVariable ["lambs_danger_planZirh", true];
    _g setVariable ["lambs_danger_planAktif", true, true];

    // v8.174 ZIRH DOKTRINI (MCWP 3-11.1 s. 6-36: arac / zirh piyade temizledikce ileri sicrar ve etkili destegi surdurur): SALDIRI basinda ates pozisyonu bir kez 350 m civarina ilerletilir
    if (_faz isEqualTo "SALDIRI" && {!(_g getVariable ["lambs_danger_planZirhYakin", false])}) then {
        _g setVariable ["lambs_danger_planZirhYakin", true];
        _g setVariable ["lambs_danger_planZirhPoz", []];
        _g setVariable ["lambs_danger_planZirhVardi", nil];
        diag_log format ["[PLAN-ZIRH] %1 | %2 SALDIRI basladi: ates pozisyonu piyadeyle karsilikli destek icin ileri sicrayacak (~350 m)", _id, groupId _g];
    };
    // v8.174 CEKILME: zirh ates ederek RALLY POINT'e doner (piyade ile bulusma); ates pozisyonunda kalmaz
    if (_faz isEqualTo "CEKILME") then {
        if !(_g getVariable ["lambs_danger_planZirhCek", false]) then {
            _g setVariable ["lambs_danger_planZirhCek", true];
            _g setVariable ["lambs_danger_planZirhVardi", nil];
            private _rpP = (_plan get "rp") getPos [12 * (_forEachIndex + 1), (_plan get "B") + 90];
            _g setVariable ["lambs_danger_planZirhPoz", _rpP];
            _g setVariable ["lambs_danger_planZirhT", time];
            _g setBehaviour "COMBAT"; _g setCombatMode "RED"; _g setSpeedMode "FULL";
            _d enableAI "PATH"; _d enableAI "MOVE"; _d forceSpeed -1;
            _d doMove _rpP;
            diag_log format ["[PLAN-ZIRH] %1 | %2 CEKILME: rally point'e donuyor (%3 m) - ates ederek", _id, groupId _g, round (_v distance2D _rpP)];
        };
    };
    private _yk = _g getVariable ["lambs_danger_planZirhYakin", false];
    private _merkezD = if (_tankMi) then {[650, 450] select _yk} else {[500, 350] select _yk};
    // ---- ates pozisyonu (bir kez) ----
    private _poz = _g getVariable ["lambs_danger_planZirhPoz", []];
    if (_poz isEqualTo []) then {
        private _yon = _obj getDir _sbf;
        private _en = [];
        private _enS = -1e9;
        {
            private _dist = _x;
            {
                private _a = _x;
                private _p = _obj getPos [_dist, _yon + _a];
                if (!surfaceIsWater _p && {(nearestObjects [_p, ["House"], 10]) isEqualTo []} && {(count (nearestTerrainObjects [_p, ["TREE"], 12])) < 4}) then {
                    private _e1 = (AGLToASL [_p select 0, _p select 1, 0]) vectorAdd [0, 0, 2.4];
                    private _e2 = (AGLToASL [_obj select 0, _obj select 1, 0]) vectorAdd [0, 0, 1.5];
                    private _gor = (lineIntersectsSurfaces [_e1, _e2, objNull, objNull, true, 1, "VIEW", "FIRE"]) isEqualTo [];
                    private _s = [0, 100] select _gor;
                    _s = _s - (abs (_dist - _merkezD)) / 10 - (abs _a) * 0.2;
                    if (isOnRoad _p) then { _s = _s - 5; };
                    if (_s > _enS) then { _enS = _s; _en = _p; };
                };
            } forEach [0, 15, -15, 30, -30];
        } forEach (if (_tankMi) then {[[650, 600, 700, 550, 750, 800], [450, 400, 500, 350, 550, 600]] select _yk} else {[[500, 450, 550, 400, 600, 650], [350, 300, 400, 330, 380, 450]] select _yk});
        if (_en isEqualTo []) then { _en = _obj getPos [_merkezD, _yon]; };
        _poz = _en;
        _g setVariable ["lambs_danger_planZirhPoz", _poz];
        _g setVariable ["lambs_danger_planZirhT", time];
        _g setBehaviour "COMBAT";
        _g setCombatMode "YELLOW";
        _g setSpeedMode "NORMAL";
        _d enableAI "PATH"; _d enableAI "MOVE";
        _d forceSpeed -1;
        _d doMove _poz;
        diag_log format ["[PLAN-ZIRH] %1 | %2 | %3 -> ates pozisyonu %4 (objektife %5 m, gorus hatti %6, SBF'den %7 m) | faz %8",
            _id, groupId _g, getText (configOf _v >> "displayName"), mapGridPosition _poz, round (_poz distance2D _obj), _enS >= 50, round (_poz distance2D _sbf), _faz];
    };

    // ---- varis ----
    private _vardi = _g getVariable ["lambs_danger_planZirhVardi", false];
    if (!_vardi && {((_v distance2D _poz) < 40) || {(time - (_g getVariable ["lambs_danger_planZirhT", time])) > 240}}) then {
        _vardi = true;
        _g setVariable ["lambs_danger_planZirhVardi", true];
        doStop _d;
        { _x doWatch _obj; } forEach (crew _v);
        diag_log format ["[PLAN-ZIRH] %1 | %2 mevzide (%3 m kalan) | objektife %4 m", _id, groupId _g, round (_v distance2D _poz), round (_v distance2D _obj)];
    } else {
        // yoldayken yeniden yonlendirme (takilmasin)
        if (!_vardi && {(time - (_g getVariable ["lambs_danger_planZirhMoveT", -999])) > 20}) then {
            _g setVariable ["lambs_danger_planZirhMoveT", time];
            _d doMove _poz;
        };
    };

    // ---- savas modu ----
    private _modu = ["YELLOW", "RED"] select _savas;
    if ((_g getVariable ["lambs_danger_planZirhMod", ""]) isNotEqualTo _modu) then {
        _g setVariable ["lambs_danger_planZirhMod", _modu];
        _g setBehaviour "COMBAT";
        _g setCombatMode _modu;
        _d enableAI "AUTOCOMBAT";
        diag_log format ["[PLAN-ZIRH] %1 | %2 COMBAT / %3 (faz %4, piyade temasi %5)", _id, groupId _g, _modu, _faz, _piyadeTemas];
    };

    // ---- hedef: objektif cevresinde BILINEN dusman ----
    if ((_vardi || {_faz isEqualTo "CEKILME"}) && {_savas} && {(time - (_g getVariable ["lambs_danger_planZirhHedefT", -999])) > 6}) then {
        _g setVariable ["lambs_danger_planZirhHedefT", time];
        private _hedefler = (_l nearTargets 900) select {((side _g) getFriend (_x select 2)) < 0.6 && {((_x select 0) distance2D _obj) < 450} && {(_l knowsAbout (_x select 4)) > 0.5}};
        if (_hedefler isNotEqualTo []) then {
            _hedefler = [_hedefler, [], {(_x select 3)}, "DESCEND"] call BIS_fnc_sortBy;
            private _hd = (_hedefler select 0) select 4;
            if (!isNull _hd) then {
                private _gn = gunner _v;
                if (!isNull _gn) then { _gn doTarget _hd; _gn doFire _hd; };
            };
        };
    };

    // ---- TANK: bilinen hedef yoksa objektif alanina bastirma atesi (dost piyade 70 m disinda), 12 sn'de bir ----
    if (_tankMi && {_vardi} && {_savas} && {_faz in ["SALDIRI", "KESIF", "TOPLANMA"]} && {(time - (_g getVariable ["lambs_danger_planZirhBasT", -999])) > 12}) then {
        _g setVariable ["lambs_danger_planZirhBasT", time];
        private _dost = (_obj nearEntities ["CAManBase", 70]) select {(side group _x) isEqualTo (side _g)};
        private _gn2 = gunner _v;
        if (_dost isEqualTo [] && {!isNull _gn2} && {alive _gn2}) then {
            _gn2 doSuppressiveFire (_obj getPos [random 25, random 360]);
        };
    };
} forEach _zg;
