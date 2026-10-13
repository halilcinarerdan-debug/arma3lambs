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
private _ilerD = 1e6; private _ilerT = time; private _kurtN = 0; private _logT = time + 20; private _pozEski = getPosATL _v;
private _bitis = "";
while {_bitis isEqualTo ""} do {
    sleep 1;
    private _dm = _v distance2D _dur;
    if (!alive _v || {!alive _d}) then { _bitis = "oldu"; }
    else { if ((_rg findIf {(time - ((_x) getVariable [QGVAR(contact), -999])) < 5}) >= 0) then { _bitis = "temas"; }
    else { if (_dm < 45) then { _bitis = "vardi"; }
    else { if (time > _ts) then { _bitis = "sure"; }
    else { if (!(canMove _v)) then { _bitis = "hasar"; }; }; }; }; };
    // v8.193: ILERLEME = hedefe yaklasma YA DA gercek yer degistirme (RPT bc090fa2: yol OP'den uzaga dolanirken hedefe mesafe artti, arac 17-35 km/s giderken "takildi" sayildi, recon 2956 m geride indi)
    if (_bitis isEqualTo "" && {(_dm < (_ilerD - 15)) || {(_v distance2D _pozEski) > 12}}) then { _ilerD = _dm min _ilerD; _pozEski = getPosATL _v; _ilerT = time; _kurtN = 0; };
    // v8.191 KURTARMA (RPT bda5fbde: recon araci OP'ye 454 m kala 45 sn ilerlemeyince hemen "takildi" sayildi, recon 375 m geride indi): 18 sn itme + emir yenile, 32 sn kaldir + yan ara nokta, 50 sn 25 m tasi; 75 sn'de pes
    if (_bitis isEqualTo "") then {
        private _dtk = time - _ilerT;
        if (_dtk > 8 && {_kurtN isEqualTo 0}) then {
            _kurtN = 1;
            _d action ["EngineOn", _v]; _v engineOn true; _d enableAI "PATH"; _d enableAI "MOVE"; _d forceSpeed 9;
            // v8.218 YOL ONCELIGI (RPT 5290bbed: TASIMA 18 sn kurtarmasi - yola 60 m ara nokta + 6 m/s itme - duran Stryker'i kurtardi): hedefe yakin en iyi yol noktasi (300 m) ara nokta; yoksa dogrudan hedef
            private _yolK = (getPosATL _v) nearRoads 300;
            private _araK = _dur;
            if (_yolK isNotEqualTo []) then {
                _yolK = [_yolK, [], {(_x distance2D _v) + 0.5 * (_x distance2D _dur)}, "ASCEND"] call BIS_fnc_sortBy;
                _araK = getPosATL (_yolK select 0);
            };
            _d doMove _araK; _v setVelocityModelSpace [0, 6, 0];
            diag_log format ["[RECON-ARAC] %1 | %2 | KURTARMA 1: %3 sn ilerleme yok (kalan %4 m, hiz %5 km/s, motor %6) -> itme + emir yenilendi", _id, _ad, round _dtk, round _dm, round (speed _v), isEngineOn _v];
            // v8.200 TANI (donmus arac nedeni hala bilinmiyor): yerellik, koltuklar, grup lideri, waypoint, komut, engel, sinirlayici bayraklar
            diag_log format ["[RECON-ARAC-TANI] %1 | arac yerel %2 sahip %3 | surucu yerel %4 | koltuklar surucu %5 / komutan %6 / nisanci %7 | grup lideri %8 (aracta %9) | waypoint %10 aktif %11 | beh %12 mod %13 hiz modu %14 | komut %15 | unitReady %16 | bayraklar ezmeFren %17 senkT %18 forceMove %19 | 12 m icinde nesne %20 | komsu arac %21 | yuzey %22",
                _id, local _v, owner _v, local _d, name (driver _v), name (commander _v), name (gunner _v), name (leader _vg), (vehicle (leader _vg)) isEqualTo _v, count (waypoints _vg), currentWaypoint _vg, behaviour _d, combatMode _vg, speedMode _vg, currentCommand _d, unitReady _d,
                _v getVariable [QGVAR(ezmeFren), false], _d getVariable [QGVAR(senkT), 0], _d getVariable [QGVAR(forceMove), false],
                ((nearestObjects [_v, [], 12]) select {_x isNotEqualTo _v && {!(_x isKindOf "CAManBase")}}) apply {typeOf _x}, count ((_v nearEntities ["LandVehicle", 15]) - [_v]), surfaceType (getPosATL _v)];
            [_v, _d, _id, false] call FUNC(aracSurmeTani);   // v8.213: olasi nedenler (sinama KAPALI: 60 m doMove kurtarma emrini eziyordu)
        };
        if (_dtk > 14 && {_kurtN isEqualTo 1}) then {
            _kurtN = 2;
            _v setVectorUp [0, 0, 1]; _v setPosATL ((getPosATL _v) vectorAdd [0, 0, 0.8]);
            private _alt = (getPosATL _v) getPos [70, ((getPosATL _v) getDir _dur) + (selectRandom [-40, 40])];
            if (surfaceIsWater _alt) then { _alt = _dur; };
            _d doMove _alt;
            // v8.209: recon araci da AI surmuyorsa (RPT 91b5ffbd: Stryker 2.4 km'de hic kalkmadi, recon yola cikmadi) ortak kinematik surus (fnc_aracKinSurus) devreye girer
            [_v, _d, _dur, _id] call FUNC(aracKinSurus);
            diag_log format ["[RECON-ARAC] %1 | %2 | KURTARMA 2: kaldirildi + yan ara nokta (z %3, egim %4)", _id, _ad, ((getPosATL _v) select 2) toFixed 2, (vectorUp _v) apply {_x toFixed 2}];
        };
        if (_dtk > 40 && {_kurtN isEqualTo 2}) then {
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
    if (_bitis isEqualTo "" && {(time - _ilerT) > 60}) then { _bitis = "takildi"; };
    if (_bitis isEqualTo "" && {alive _v} && {!(isEngineOn _v)}) then { _d action ["EngineOn", _v]; _v engineOn true; };
};

// ---- 3b) GERI DONUS (kullanici: "yolda recon birligi indi; kitaba uygunsa HQ'ya geri donsun"): OP'ye > 700 m varken tasima basarisiz (takilma / sure / temas) ise recon yol ortasinda INDIRILMEZ;
//   arac hareket edebiliyorsa HQ'ya (yoksa RP'ye) doner, orada indirir; plan recon'u beklemez (reconG bosaltilir, rapor planin kendi gozlemiyle). Tasarim karari (kaynak dogrulanmadi).
// v8.194 KARAR (FM 3-98 3-56 / 4-43 / 4-17): geri cekilme yalniz ENEMY-TABANLI olcutle: temasta dusman / dost orani >= 3 ya da recon gucu < %50 (sayilar tasarim degeri, kitapta yok).
//   Takilma / sure / kucuk temas: recon iner ve YAYA devam eder (arac gidemiyorsa yaya kesif: 4-17); "oldu" / hasar zaten yaya.
private _ilkN = count _birimler;
private _canliN = { alive _x } count _birimler;
private _dusmanN = 0;
if (_bitis isEqualTo "temas") then {
    private _tf = side _vg;
    private _gor = [];
    { { if (((_tf getFriend (_x select 2)) < 0.6) && {(_x select 4) isNotEqualTo objNull}) then { _gor pushBackUnique (_x select 4); }; } forEach ((leader _x) nearTargets 700); } forEach _rg;
    _dusmanN = count _gor;
};
private _zayif = _canliN < (_ilkN * 0.5);
private _ezici = _dusmanN >= (3 * (_canliN max 1));
private _geriDon = (_bitis isEqualTo "temas") && {_zayif || _ezici} && {(_v distance2D _op) > 700} && {alive _v} && {alive _d} && {canMove _v};
if (_bitis isEqualTo "temas" && {!_geriDon}) then { diag_log format ["[RECON-ARAC] %1 | %2 | TEMAS: dusman %3 / recon %4 (%5 basladi) -> geri cekilme olcutu ASILMADI, recon iner ve yaya devam eder", _id, _ad, _dusmanN, _canliN, _ilkN]; };
if (_geriDon) then { diag_log format ["[RECON-ARAC] %1 | %2 | GERI CEKILME OLCUTU: dusman %3 / recon %4 (%5 basladi) | zayif %6 ezici %7", _id, _ad, _dusmanN, _canliN, _ilkN, _zayif, _ezici]; };
if (_geriDon) then {
    private _hq = _plan getOrDefault ["hqPoz", []];
    if (_hq isEqualTo []) then { _hq = _plan get "rp"; };
    diag_log format ["[RECON-ARAC] %1 | %2 | GERI DONUS: tasima %3 (OP'ye %4 m) -> recon yolda indirilmiyor, %5 noktasina (%6 m) donuluyor", _id, _ad, _bitis, round (_v distance2D _op), ["HQ", "RP"] select ((_plan getOrDefault ["hqPoz", []]) isEqualTo []), round (_v distance2D _hq)];
    _plan set ["reconIptal", true];
    _plan set ["reconG", []];
    { if ((waypointName _x) find "ELITE RECON-ARAC" isEqualTo 0) then { deleteWaypoint _x; }; } forEach (reverse (waypoints _vg));
    _vg setBehaviour (["SAFE", "AWARE"] select (_bitis isEqualTo "temas")); _vg setCombatMode "YELLOW"; _vg setSpeedMode "FULL";
    _d forceSpeed -1;
    _d doMove _hq;
    private _wH = _vg addWaypoint [_hq, 0]; _wH setWaypointType "MOVE"; _wH setWaypointName "ELITE RECON-ARAC"; _wH setWaypointSpeed "FULL"; _vg setCurrentWaypoint _wH;
    private _tgH = time + 480;
    private _pE = getPosATL _v; private _pT = time;
    waitUntil {
        sleep 2;
        if ((_v distance2D _pE) > 12) then { _pE = getPosATL _v; _pT = time; };
        if ((time - _pT) > 20 && {alive _d}) then { _pT = time; _d action ["EngineOn", _v]; _v engineOn true; _d doMove _hq; };
        !alive _v || {!alive _d} || {!canMove _v} || {(_v distance2D _hq) < 60} || {time > _tgH}
    };
    { if (!isNull _x) then { _x setVariable ["lambs_danger_planAktif", nil, true]; _x setBehaviour "AWARE"; _x setCombatMode "YELLOW"; _x setSpeedMode "NORMAL"; }; } forEach _rg;
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
if (!_geriDon && {!surfaceIsWater _geri} && {alive _v} && {alive _d} && {canMove _v}) then {
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
