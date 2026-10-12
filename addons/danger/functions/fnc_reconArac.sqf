#include "script_component.hpp"
/*
 * Author: Cinar (ELITE fork)
 * RECON ARACI (v8.188) — kullanici: "RECON apc ile gitsin, bir apc recona ayrilsin, yuruyerek cok zor ama yine sessiz olsun".
 * Kesif unsuru (RECON grubu) ayrilmis TEK bir kara araci (APC / IFV / kamyon) ile gozlem noktasinin (OP) yakinina SESSIZCE tasinir, orada iner ve son yaklasmayi yaya (STEALTH + GREEN) yapar.
 * Modlar:
 *   ["SEC", plan] -> arac secimi (plan kurulurken, ana nakil dagitiminDAN ONCE): kargo >= recon asker sayisi, AI surucu (yerel), taraf ayni, mesgul / planda / HARIC / MEDEVAC / TOPCU / KARAKOL_ARAC degil,
 *                    sinif APC > KAMYON > IFV (IFV'ler indirdikten sonra ates destegine gider), recon grubuna en yakin (<= 4000 m); arac "lambs_danger_reconArac" ile isaretlenir (aracTasima bunu kullanmaz). Doner: arac ya da objNull.
 *   ["CALIS", plan, reconGruplari, OP] -> betik: alma (yakinsa piyade biner) -> sessiz surus (grup STEALTH + GREEN, LIMITED, ~25 km/s, isiksiz, OP'ye 150 m kala dur) -> inis -> arac 250 m geri cekilir.
 *                    Bitince plan["reconAracInis"] = true; basarisizsa plan["reconAracBasarisiz"] = true (komuta dongusu recon'u yaya yollar). Log: [RECON-ARAC].
 * Sessizlik: arac farlari / isiklari kapali, yavas, temasta (grup son 5 sn) iner ve recon kendi STEALTH mantigiyla devam eder. Surucu AUTOCOMBAT kapali, silahci yalniz acilan atese karsilik verir (GREEN).
 *
 * Return Value: mod SEC ise arac, CALIS ise betik
*/

params ["_mod", "_plan", ["_rg", []], ["_op", [0, 0, 0]]];

private _taraf = _plan get "taraf";

if (_mod isEqualTo "SEC") exitWith {
    private _rgl = (_plan getOrDefault ["reconG", []]) select {!isNull _x && {({alive _x} count (units _x)) > 0}};
    if (_rgl isEqualTo []) exitWith {objNull};
    private _birimler = [];
    { _birimler append ((units _x) select {alive _x && {isNull objectParent _x}}); } forEach _rgl;
    if (_birimler isEqualTo []) exitWith {objNull};
    private _mrk = [0, 0, 0];
    { _mrk = _mrk vectorAdd (getPosATL _x); } forEach _birimler;
    _mrk = _mrk vectorMultiply (1 / (count _birimler));
    private _aday = vehicles select {
        private _v = _x;
        private _d = driver _v;
        alive _v && {_v isKindOf "LandVehicle"} && {canMove _v} && {(fuel _v) > 0.1} && {(_v emptyPositions "cargo") >= (count _birimler)}
        && {!isNull _d} && {!isPlayer _d} && {local _d} && {(side (group _d)) isEqualTo _taraf}
        && {(_v distance2D _mrk) <= 4000}
        && {!(_v getVariable [QGVAR(tasimaMesgul), false])} && {!(_v getVariable [QGVAR(reconArac), false])}
        && {!((group _d) getVariable [QGVAR(planAktif), false])}
        && {!(((_v getVariable ["lambs_danger_gorev", ""]) in ["HARIC", "MEDEVAC", "TOPCU", "TOPCU_YOK", "KARAKOL_ARAC"]) || {((group _d) getVariable ["lambs_danger_gorev", ""]) in ["HARIC", "MEDEVAC", "TOPCU", "TOPCU_YOK", "KARAKOL_ARAC"]})}
        && {((units (group _d)) findIf {alive _x && {(vehicle _x) isNotEqualTo _v}}) isEqualTo -1}
        && {(getNumber (configOf _v >> "attendant")) isEqualTo 0}
        && {(([_v] call FUNC(aracSinif)) select 0) in ["APC", "KAMYON", "IFV"]}
    };
    if (_aday isEqualTo []) exitWith {
        diag_log format ["[RECON-ARAC] %1 | uygun arac YOK (kargo >= %2, AI surucu, planda / mesgul degil) -> recon yaya gidecek", _plan get "id", count _birimler];
        objNull
    };
    private _puan = {
        private _s = ([_this] call FUNC(aracSinif)) select 0;
        ([0, 1, 2] select (["IFV", "KAMYON", "APC"] find _s)) * 100000 - (_this distance2D _mrk)
    };
    _aday = [_aday, [], {-(_x call _puan)}, "ASCEND"] call BIS_fnc_sortBy;
    private _v = _aday select 0;
    _v setVariable [QGVAR(reconArac), true];
    diag_log format ["[RECON-ARAC] %1 | recon araci secildi: %2 [%3] (%4 koltuk, %5 m) | recon %6 asker", _plan get "id", getText (configOf _v >> "displayName"), ([_v] call FUNC(aracSinif)) select 0, _v emptyPositions "cargo", round (_v distance2D _mrk), count _birimler];
    _v
};

// ------------------------------------------------------------------------------------------------ CALIS
private _v = _plan getOrDefault ["reconArac", objNull];
private _id = _plan get "id";
if (isNull _v || {!alive _v}) exitWith { _plan set ["reconAracBasarisiz", true]; };
private _d = driver _v;
private _vg = group _d;
private _ad = getText (configOf _v >> "displayName");
private _birimler = [];
{ _birimler append ((units _x) select {alive _x}); } forEach _rg;
private _basarisiz = {
    params ["_neden"];
    diag_log format ["[RECON-ARAC] %1 | BASARISIZ: %2 -> recon yaya gidecek", _id, _neden];
    { if (alive _x) then { _x setVariable [QGVAR(tasimaBekle), nil]; _x enableAI "PATH"; }; } forEach _birimler;
    _plan set ["reconAracBasarisiz", true];
};
_v setVariable [QGVAR(tasimaMesgul), true];
_v setVariable [QGVAR(yolcuBirak), false];
_vg setVariable [QGVAR(isExecutingTactic), true];
_d setVariable [QGVAR(forceMove), true];
private _eskiBeh = behaviour _d;
private _eskiMod = combatMode _vg;
_d disableAI "AUTOCOMBAT";

// ---- 1) alma: recon askerleri yerinde bekler; arac onlara gider (< 120 m ise gitmez)
{ if (alive _x && {isNull objectParent _x}) then { _x setVariable [QGVAR(tasimaBekle), true]; doStop _x; _x disableAI "PATH"; }; } forEach _birimler;
private _merkez = {
    private _p = [0, 0, 0]; private _n = 0;
    { if (alive _x && {isNull objectParent _x}) then { _p = _p vectorAdd (getPosATL _x); _n = _n + 1; }; } forEach _birimler;
    if (_n isEqualTo 0) then {[]} else { _p vectorMultiply (1 / _n) }
};
private _pk = call _merkez;
if (_pk isEqualTo []) exitWith { ["asker kalmadi"] call _basarisiz; };
_vg setBehaviour "SAFE"; _vg setSpeedMode "NORMAL";
_d enableAI "PATH"; _d enableAI "MOVE"; _d forceSpeed -1;
_d action ["EngineOn", _v]; _v engineOn true;
if ((_v distance2D _pk) > 120) then {
    _d doMove _pk;
    private _w = _vg addWaypoint [_pk, 0]; _w setWaypointType "MOVE"; _w setWaypointName "ELITE RECON-ARAC"; _vg setCurrentWaypoint _w;
    private _tl = time + 180;
    waitUntil { sleep 1; !alive _v || {!alive _d} || {(_v distance2D _pk) < 60} || {time > _tl} };
};
if (!alive _v || {!alive _d}) exitWith { ["arac / surucu oldu"] call _basarisiz; };
doStop _d;

// ---- 2) bindirme (en cok 60 sn); gecikenler moveInCargo
{ if (alive _x) then { _x enableAI "PATH"; _x assignAsCargo _v; }; } forEach _birimler;
_birimler orderGetIn true;
private _tb = time + 60;
waitUntil { sleep 1; !alive _v || {time > _tb} || {(_birimler findIf {alive _x && {(vehicle _x) isNotEqualTo _v}}) isEqualTo -1} };
{ if (alive _x && {(vehicle _x) isNotEqualTo _v} && {(_x distance2D _v) < 60} && {(_v emptyPositions "cargo") > 0}) then { _x moveInCargo _v; }; } forEach _birimler;
private _icerde = _birimler select {alive _x && {(vehicle _x) isEqualTo _v}};
if (_icerde isEqualTo []) exitWith { ["kimse binmedi"] call _basarisiz; };
{ _x disableAI "PATH"; } forEach _icerde;   // sessiz seyir: yolcu kendi basina inmez
diag_log format ["[RECON-ARAC] %1 | %2 | %3 recon askeri bindi -> OP'ye sessiz surus (%4 m)", _id, _ad, count _icerde, round (_v distance2D _op)];

// ---- 3) sessiz surus
private _dur = _op getPos [150, _op getDir (_plan get "rp")];
private _yol = (_dur nearRoads 120) select {!surfaceIsWater (getPosATL _x)};
if (_yol isNotEqualTo []) then { _yol = [_yol, [], {_x distance2D _dur}, "ASCEND"] call BIS_fnc_sortBy; _dur = getPosATL (_yol select 0); };
// v8.190: surucu grubu SAFE / NORMAL + forceSpeed 9 (~32 km/s): STEALTH + LIMITED araci 5-13 km/s'e dusuruyordu ve mekanizeIzle forceSpeed'i her 20 sn sifirliyordu (RPT 2a205c2b); sessizlik: ates yok (GREEN), isiksiz, recon askerleri STEALTH
_vg setBehaviour "SAFE"; _vg setCombatMode "GREEN"; _vg setSpeedMode "NORMAL";
_d setVariable [QGVAR(senkT), time + 900];
_d forceSpeed 9;
_v setPilotLight false; _v setCollisionLight false;
_d doMove _dur;
{ if ((waypointName _x) find "ELITE RECON-ARAC" isEqualTo 0) then { deleteWaypoint _x; }; } forEach (reverse (waypoints _vg));
private _w2 = _vg addWaypoint [_dur, 0]; _w2 setWaypointType "MOVE"; _w2 setWaypointName "ELITE RECON-ARAC"; _w2 setWaypointBehaviour "SAFE"; _w2 setWaypointCombatMode "GREEN"; _w2 setWaypointSpeed "NORMAL"; _vg setCurrentWaypoint _w2;
private _ts = time + 600;
private _ilerD = 1e6; private _ilerT = time; private _kurtN = 0; private _logT = time + 20;
private _bitis = "";
while {_bitis isEqualTo ""} do {
    sleep 1;
    private _dm = _v distance2D _dur;
    if (!alive _v || {!alive _d}) then { _bitis = "oldu"; }
    else { if ((_rg findIf {(time - ((_x) getVariable [QGVAR(contact), -999])) < 5}) >= 0) then { _bitis = "temas"; }
    else { if (_dm < 45) then { _bitis = "vardi"; }
    else { if (time > _ts) then { _bitis = "sure"; }
    else { if (!(canMove _v)) then { _bitis = "hasar"; }; }; }; }; };
    if (_bitis isEqualTo "" && {_dm < (_ilerD - 15)}) then { _ilerD = _dm; _ilerT = time; _kurtN = 0; };
    // v8.191 KURTARMA (RPT bda5fbde: recon araci OP'ye 454 m kala 45 sn ilerlemeyince hemen "takildi" sayildi, recon 375 m geride indi): 18 sn itme + emir yenile, 32 sn kaldir + yan ara nokta, 50 sn 25 m tasi; 75 sn'de pes
    if (_bitis isEqualTo "") then {
        private _dtk = time - _ilerT;
        if (_dtk > 18 && {_kurtN isEqualTo 0}) then {
            _kurtN = 1;
            _d action ["EngineOn", _v]; _v engineOn true; _d enableAI "PATH"; _d enableAI "MOVE"; _d forceSpeed 9;
            _d doMove _dur; _v setVelocityModelSpace [0, 4, 0];
            diag_log format ["[RECON-ARAC] %1 | %2 | KURTARMA 1: %3 sn ilerleme yok (kalan %4 m, hiz %5 km/s, motor %6) -> itme + emir yenilendi", _id, _ad, round _dtk, round _dm, round (speed _v), isEngineOn _v];
        };
        if (_dtk > 32 && {_kurtN isEqualTo 1}) then {
            _kurtN = 2;
            _v setVectorUp [0, 0, 1]; _v setPosATL ((getPosATL _v) vectorAdd [0, 0, 0.8]);
            private _alt = (getPosATL _v) getPos [70, ((getPosATL _v) getDir _dur) + (selectRandom [-40, 40])];
            if (surfaceIsWater _alt) then { _alt = _dur; };
            _d doMove _alt;
            diag_log format ["[RECON-ARAC] %1 | %2 | KURTARMA 2: kaldirildi + yan ara nokta (z %3, egim %4)", _id, _ad, ((getPosATL _v) select 2) toFixed 2, (vectorUp _v) apply {_x toFixed 2}];
        };
        if (_dtk > 50 && {_kurtN isEqualTo 2}) then {
            _kurtN = 3;
            _v setVehiclePosition [(getPosATL _v) getPos [25, (getPosATL _v) getDir _dur], [], 0, "NONE"];
            _d doMove _dur;
            diag_log format ["[RECON-ARAC] %1 | %2 | KURTARMA 3: arac 25 m ileri tasindi", _id, _ad];
        };
        if (time > _logT) then {
            _logT = time + 20;
            diag_log format ["[RECON-ARAC] %1 | %2 | yolda: kalan %3 m | hiz %4 km/s | motor %5 | komut %6", _id, _ad, round _dm, round (speed _v), isEngineOn _v, currentCommand _d];
        };
    };
    if (_bitis isEqualTo "" && {(time - _ilerT) > 75}) then { _bitis = "takildi"; };
    if (_bitis isEqualTo "" && {alive _v} && {!(isEngineOn _v)}) then { _d action ["EngineOn", _v]; _v engineOn true; };
};

// ---- 4) inis
diag_log format ["[RECON-ARAC] %1 | %2 | sessiz surus bitti (%3): OP'ye %4 m, inise %5 m -> recon iniyor", _id, _ad, _bitis, round (_v distance2D _op), round (_v distance2D _dur)];
_v setVariable [QGVAR(yolcuBirak), true];
doStop _d;
{ if (alive _x && {(vehicle _x) isEqualTo _v} && {_x isNotEqualTo _d}) then { unassignVehicle _x; _x enableAI "PATH"; doGetOut _x; }; } forEach _icerde;
sleep 6;
{ if (alive _x && {(vehicle _x) isEqualTo _v} && {_x isNotEqualTo _d}) then { moveOut _x; }; } forEach _icerde;
sleep 2;
{ if (alive _x) then { _x setVariable [QGVAR(tasimaBekle), nil]; _x enableAI "PATH"; }; } forEach _birimler;
_plan set ["reconAracInis", true];

// ---- 5) arac sessizce 250 m geri cekilir, orada bekler (recon alma / destek icin); isiklar kapali
private _geri = _dur getPos [250, (_plan get "rp") getDir _dur];
if (!surfaceIsWater _geri && {alive _v} && {alive _d} && {canMove _v}) then {
    _d forceSpeed 9;
    _d doMove _geri;
    private _tg = time + 120;
    waitUntil { sleep 2; !alive _v || {(_v distance2D _geri) < 40} || {time > _tg} };
    if (alive _d) then { doStop _d; };
};
_v setVariable [QGVAR(aracRezervT), time];
if (!isNull _vg) then {
    { if ((waypointName _x) find "ELITE RECON-ARAC" isEqualTo 0) then { deleteWaypoint _x; }; } forEach (reverse (waypoints _vg));
    _vg setVariable [QGVAR(isExecutingTactic), nil];
    _vg setBehaviour _eskiBeh;
    _vg setCombatMode _eskiMod;
    _vg setVariable [QGVAR(aracMedevacT), time];
};
if (alive _d) then { _d setVariable [QGVAR(senkT), nil]; _d forceSpeed -1; _d setVariable [QGVAR(forceMove), nil]; _d enableAI "AUTOCOMBAT"; };
_v setVariable [QGVAR(tasimaMesgul), nil];
_vg setVariable [QGVAR(tasimaSonT), time];
diag_log format ["[RECON-ARAC] %1 | %2 | geri cekildi, rezerv", _id, _ad];
true
