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
if (({alive _x} count (units _group)) < 1) exitWith {false};   // v8.10: bos (hepsi olu) grup retreat baslatmaz (RPT: toplam:0)

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

// v14: noktalar BINA / DUVAR / CIT icine dusmesin (0/5 varis, 20 sn zaman asimi sorunu: nokta binanin icindeydi)
// Her sicrama kendi oncekinden 40 m; dusman yonunun tersinde +-75 derece kon icinde acik / engelsiz aday secilir.
// MESAFEYE GORE SICRAMA BOYU (doktrin: yakin temasta kisa/hizli sicrama + sis, uzakta daha uzun):
//   tehdit < 100 m : 20 m | 100-200 m : 30 m | > 200 m : 50 m  (kisa, hizli atilim; acikta uzun kosu olum)
private _retAdim = [_group, "retreatAdim", [20, 30, 50]] call FUNC(dk);
private _adimBoy = _retAdim select ([2, [1, 0] select (_cqbMesafe < 100)] select (_cqbMesafe < 200));
// SIPER HEDEFLI SICRAMA (v7.38): her sicrama noktasi artik rastgele "acik nokta" degil, dusmandan GIZLI / dogal siperli (agac, kaya, cali, duvar) aday;
//   - dusman -> nokta gorus hatti kesiliyorsa (+35)  : gercekten siper arkasi
//   - 3 m'de agac / kaya / cali / duvar / siper varsa (+10)
//   - BINA icine dusmesin (-25 / bina): duvar korumasi + navmesh askeri kapida tutuyordu (RPT: retreat lideri 40 sn kipirdamadi)
//   - aday hat boyunca yol engelliyse (-15); su (-500); dusmana yaklasma (-40: aday dusmana mevcut konumdan yakinsa)
// 3 yaricap x 7 aci = 21 aday (adim boyu x 0.7 / 1.0 / 1.3)
private _wpSec = {
    params ["_o", "_dir"];
    private _best = [];
    private _bestS = -9999;
    private _eASL = AGLToASL (_targetPos vectorAdd [0, 0, 1.6]);
    {
        private _r = _adimBoy * _x;
        {
            private _c = _o getPos [_r, _dir + _x];
            private _s = -((abs _x) * 0.08) - (abs (_r - _adimBoy)) * 0.2;
            if (surfaceIsWater _c) then { _s = _s - 500; };
            private _bina = count (nearestTerrainObjects [_c, ["BUILDING", "HOUSE", "CHURCH", "FUELSTATION", "BUNKER"], 6, false, true]);
            _s = _s - (_bina * 25);
            private _cASL = AGLToASL (_c vectorAdd [0, 0, 1.2]);
            if (terrainIntersectASL [_eASL, _cASL] || {lineIntersects [_eASL, _cASL, objNull, objNull]}) then { _s = _s + 35; };
            if ((count (nearestTerrainObjects [_c, ["TREE", "ROCK", "HIDE", "BUSH", "WALL"], 3, false, true])) > 0) then { _s = _s + 10; };
            if (lineIntersects [AGLToASL (_o vectorAdd [0, 0, 1.4]), AGLToASL (_c vectorAdd [0, 0, 1.4])]) then { _s = _s - 15; };
            if ((_c distance2D _targetPos) < (_o distance2D _targetPos)) then { _s = _s - 40; };
            if (_s > _bestS) then { _bestS = _s; _best = _c; };
        } forEach [0, 25, -25, 50, -50, 75, -75];
    } forEach [1, 0.7, 1.3];
    _best
};
private _wp1 = [_leaderPos, _threatDir] call _wpSec;
private _wp2 = [_wp1, _threatDir] call _wpSec;
private _wp3 = [_wp2, _threatDir] call _wpSec;
_wp1 = [_wp1, _leaderPos] call _suKontrol;
_wp2 = [_wp2, _wp1] call _suKontrol;
_wp3 = [_wp3, _wp2] call _suKontrol;
private _wps = [_wp1, _wp2, _wp3, _wp3];

private _baslangic = time;
_group setVariable [QGVAR(isRetreating), true];
// LAMBS taban "sympathetic assault / Advance" tepkileri retreat emrini eziyordu (RPT: RET sirasinda "TACTICS ASSAULT (... with 2 units)").
// Retreat boyunca grup LAMBS reaksiyonlarina kapatilir (disableGroupAI); bitisinde / valfte ESKI degere donulur.
_group setVariable [QGVAR(retreatEskiDGA), _group getVariable [QGVAR(disableGroupAI), false]];
_group setVariable [QGVAR(disableGroupAI), true];
// RPT (11:53): disableGroupAI = true iken bile retreat sirasinda LAMBS "TACTICS FLANK", gestureGo, "OnYourFeet" ve "Group Suppress (Move)"
// gorevi calisti (vardi:0/7). Grup bayragi FSM'in birim duzeyindeki tepkilerini durdurmuyor -> BIRIM DUZEYI bayrak: lambs_danger_disableAI
// (LAMBS API: o birimde Danger FSM tamamen kapali). Retreat bitince / guvenlik valfinde birim basina ESKI deger geri verilir.
{
    _x setVariable [QGVAR(retreatEskiDAI), _x getVariable [QGVAR(disableAI), false]];
    _x setVariable [QGVAR(disableAI), true];
} forEach (units _group);
_group setVariable [QGVAR(isExecutingTactic), true];
_group setVariable [QGVAR(retreatStartTime), _baslangic];

// ---------------------------------------------------------------------------
// GUVENLIK VALFI — sadece bu cekilmenin bayraklarini + AI kilitlerini temizler
// ---------------------------------------------------------------------------
[_group, _baslangic, time + 340] spawn {
    params ["_g", "_start", "_limit"];
    waitUntil { time > _limit || {isNull _g} };
    if (!isNull _g && {((_g getVariable [QGVAR(retreatStartTime), -1]) isEqualTo _start)}) then {
        if (_g getVariable [QGVAR(isRetreating), false]) then {
            _g setVariable [QGVAR(isRetreating), nil];
            _g setVariable [QGVAR(disableGroupAI), [nil, true] select (_g getVariable [QGVAR(retreatEskiDGA), false])];
            _g setVariable [QGVAR(retreatEskiDGA), nil];
            {
                _x setVariable [QGVAR(disableAI), [nil, true] select (_x getVariable [QGVAR(retreatEskiDAI), false])];
                _x setVariable [QGVAR(retreatEskiDAI), nil];
            } forEach (units _g);
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
[_group, "RetreatBasla", round (_unit distance2D _targetPos)] call FUNC(olayGonder);
if (EGVAR(main,debug_functions)) then {
    systemChat _msgBasla;
};

[_group, _unit, _targetPos, _wps, _baslangic, _wpSec, _suKontrol, _adimBoy] spawn {
    params ["_group", "_unit", "_targetPos", "_wps", "_baslangic", "_wpSec", "_suKontrol", "_adimBoy"];

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
    // v8.23 TOPLU KOSU: dusman >= cekilTopluM (180 m) ise etkili ates menzili disinda: kapsama takimi gereksiz, herkes BIRLIKTE kosar (dönüsümlü sicrama hizi yariya indiriyordu;
    //   RPT 17:41: dusman 271 m, 5 kisi, 4 sicrama / 64 sn, vardi 0/9). Yakin mesafede (< 180 m) ates-manevra sicramasi korunur.
    private _topluM = [_group, "cekilTopluM", 180] call FUNC(dk);
    private _topluKosu = (_unit distance2D _targetPos) >= _topluM;
    if (_topluKosu) then {
        diag_log format ["[GERI-CEKILME] %1 toplu kosu | dusman:%2 m >= %3 m | kapsama takimi yok, %4 kisi birlikte", groupId _group, round (_unit distance2D _targetPos), _topluM, _nCek];
    };
    if (_nCek <= 4 || {_topluKosu}) then {
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
        _x setBehaviour "COMBAT";   // hareket etmeyen/ortu veren AWARE'de ayakta durmasin; kosarken _sicra AWARE yapar
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
        // HAREKET ARBITRAJI: retreat'e katilan herkes taktik kilidinde (diger watchdog'lar hareket emri vermez)
        { if (alive _x) then { _x setVariable [QGVAR(taktikKilit), time + 32]; }; } forEach (units _grup);

        diag_log format [
            "[GERI-CEKILME] %1 sicrama %2 | hareket:%3 kapsama:%4",
            groupId _grup, _no, count _hareketEdenler, count _kapsama
        ];

        // v8.10: sis perdesi sadece basta degil, tek numarali sicramalarda da tazelenir (cooldown 30 sn korur)
        if (_no > 1 && {(_no % 2) isEqualTo 1}) then {
            [_grup, ASLToAGL _hedefASL] spawn {
                params ["_g", "_tp"];
                [_g, _tp, "BREAK_CONTACT"] call (missionNamespace getVariable ["lambs_danger_fnc_tacticalSmoke", {false}]);
            };
        };

        // 1) Kapsama: hedef alanina baski atesi (kimse bos durmaz)
        {
            if (alive _x && {isNull objectParent _x}) then {
                // v8.6: kapsama veren (ozellikle LIDER) durdurulmazsa grup/gorev waypoint'ine yurur = dusmana dogru kosuyordu
                // (RPT 12:38: lider 13351->13311, digerleri 100 m geride). Once doStop, sonra ortu atesi.
                doStop _x;
                _x enableAI "TARGET";
                _x enableAI "AUTOTARGET";
                _x setBehaviour "COMBAT";
                _x setUnitPosWeak "MIDDLE";
                [_x, _hedefASL] call EFUNC(main,doSuppress);
            };
        } forEach _kapsama;

        sleep 0.4;

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
                    _x forceSpeed -1;      // v8.29: LAMBS doAssaultSpeed (brainForced: ATTACK komutunda) lider icin forceSpeed 2-3 m/s birakir; her sicramada sifirla
                    _x setSpeedMode "FULL";
                    _x enableAI "PATH";    // baska watchdog (komutan bekle vb.) PATH / MOVE kapatmis olabilir -> kosamazdi
                    _x enableAI "MOVE";
                    _x disableAI "TARGET";
                    _x disableAI "AUTOTARGET";
                    _x disableAI "AUTOCOMBAT";
                    _x disableAI "COVER";
                    _x setBehaviour "AWARE";   // sadece kosarken
                    _x setVariable [QGVAR(forceMove), true];
                    _x setVariable [QEGVAR(main,currentTask), "Retreat/Bound", EGVAR(main,debug_functions)];
                    _x setUnitPos "UP";   // v8.22: SERT durus (zayif "UP" yetmedi: RPT 17:30 lider 2 dk boyunca PRONE surunerek ilerledi)
                    private _p = _ciftNokta getPos [random 4, random 360];
                    if (surfaceIsWater _p) then { _p = _ciftNokta; };
                    _varis pushBack [_x, _p, getPosATL _x, time, 0];
                    _x doMove _p;
                };
            } forEach _cift;
        } forEach _ciftler;

        // 3) Varisa kadar bekle (en fazla 16 sn, %75 vardiysa erken cik); sadece TAKILANA (3.5 sn ilerleyemeyen) emri tazele —
        //    her 3 sn'de doMove tekrari yol hesabini sifirlayip askeri yerinde tutuyordu
        private _t0 = time;
        // Pencere MESAFEYE gore: en uzaktaki hareket eden / ~3.5 m/s + 4 sn kalkis (yatis/comelmeden kalkma), 12..26 sn
        // (RPT 12:07: BRAVO 43-62 m uzaktan basladi, 12 sn yetmedi -> vardi 0/3 gorunuyordu)
        private _uzak = 0;
        { _uzak = _uzak max ((_x select 0) distance2D (_x select 1)); } forEach _varis;
        private _bitis = time + ((12 max ((_uzak / 3.5) + 4)) min 26);
        private _pinned = [];
        private _erken = [];
        while {time < _bitis && {!isNull _grup}} do {
            // Baski >= 0.85: ezilen kosmaya devam etmez, forceMove birakilir -> FSM siper alir
            {
                private _b = _x select 0;
                if (alive _b && {!(_b in _pinned)} && {(getSuppression _b) >= 0.85}) then {
                    _pinned pushBack _b;
                    _b setVariable [QGVAR(forceMove), nil];
                    _b enableAI "AUTOCOMBAT";
                    _b enableAI "COVER";
                    _b setBehaviour "COMBAT";
                    _b setUnitPos "AUTO"; _b setUnitPosWeak "DOWN";
                };
            } forEach _varis;

            // Ezilen asker baski dusunce (< 0.5) kosuya geri doner
            {
                private _b = _x select 0;
                if (alive _b && {_b in _pinned} && {(getSuppression _b) < 0.5}) then {
                    _pinned = _pinned - [_b];
                    _b disableAI "TARGET";
                    _b disableAI "AUTOTARGET";
                    _b disableAI "AUTOCOMBAT";
                    _b disableAI "COVER";
                    _b setBehaviour "AWARE";
                    _b setVariable [QGVAR(forceMove), true];
                    _b setUnitPos "UP";
                    _b doMove (_x select 1);
                    _x set [2, getPosATL _b];
                    _x set [3, time];
                };
            } forEach _varis;

            // v8.10 ERKEN VARIS: varan asker pencerenin sonunu AWARE / ayakta BEKLEMEZ (RPT 13:08: awarede beklerken oldu) -> hemen COMBAT, comelme, ortu atesi
            {
                private _b = _x select 0;
                if (alive _b && {!(_b in _erken)} && {!(_b in _pinned)} && {(_b distance2D (_x select 1)) <= 12}) then {
                    _erken pushBack _b;
                    _b setVariable [QGVAR(forceMove), nil];
                    _b enableAI "TARGET";
                    _b enableAI "AUTOTARGET";
                    _b enableAI "AUTOCOMBAT";
                    _b enableAI "COVER";
                    _b setBehaviour "COMBAT";
                    _b setUnitPos "AUTO"; _b setUnitPosWeak "MIDDLE";
                    doStop _b;
                    [_b, _hedefASL] call EFUNC(main,doSuppress);
                };
            } forEach _varis;

            // v8.72 KOMUT EZME TESPITI (RPT bc841e2d: 40 TAKILI satirinin 32'sinde komut ATTACK + beh COMBAT, hedefe medyan 141 m -> baska bir sistem doMove'u ezip askeri
            //   ayakta durdurup ates ettiriyor; vardi 1/10, 3 dk'da dusman mesafesi 155 -> 96 -> 125 m = retreat mesafe kazanmiyordu). Kosan (varamamis, ezilmemis) askerde komut MOVE degilse
            //   ya da davranis COMBAT'a donduyse: AI bayraklari yeniden kapatilir, doStop + doMove (birim basina en fazla 2.5 sn'de bir, grup logu ilk 30 olay).
            {
                private _b = _x select 0;
                if (alive _b && {!(_b in _pinned)} && {(_b distance2D (_x select 1)) > 12} && {(time - (_b getVariable [QGVAR(retEzmeT), -999])) > 2.5} && {(time - _t0) > 1.5}) then {
                    private _kmt = currentCommand _b;
                    if (_kmt isNotEqualTo "MOVE" || {(behaviour _b) isEqualTo "COMBAT"}) then {
                        _b setVariable [QGVAR(retEzmeT), time];
                        if (isNil "lambs_danger_retEzmeN") then { lambs_danger_retEzmeN = 0; };
                        if (lambs_danger_retEzmeN < 30) then {
                            lambs_danger_retEzmeN = lambs_danger_retEzmeN + 1;
                            diag_log format ["[GERI-CEKILME-EZME] %1 | %2 | komut:%3 beh:%4 | hedefe %5 m | TARGET:%6 AUTOTARGET:%7 -> yeniden MOVE", groupId _grup, name _b, _kmt, behaviour _b, round (_b distance2D (_x select 1)), _b checkAIFeature "TARGET", _b checkAIFeature "AUTOTARGET"];
                        };
                        _b disableAI "TARGET";
                        _b disableAI "AUTOTARGET";
                        _b disableAI "AUTOCOMBAT";
                        _b enableAI "PATH";
                        _b enableAI "MOVE";
                        _b setBehaviour "AWARE";
                        _b setUnitPos "UP";
                        _b forceSpeed -1;
                        doStop _b;
                        _b doMove (_x select 1);
                    };
                };
            } forEach _varis;

            // Takilma tespiti: 3.5 sn'de < 1.5 m ilerleyen, hedefe uzak asker -> emri tazele; 2. takilmada dusmandan uzaga yeni nokta
            {
                private _b = _x select 0;
                if (alive _b && {!(_b in _pinned)} && {(_b distance2D (_x select 1)) > 12}) then {
                    if ((_b distance2D (_x select 2)) > 1.5) then {
                        _x set [2, getPosATL _b];
                        _x set [3, time];
                    } else {
                        if ((time - (_x select 3)) > 3.5) then {
                            _x set [4, (_x select 4) + 1];
                            // v8.24 TAKILMA TANISI + KADEMELI MUDAHALE (RPT 17:52: lider STAND / MOVE / baski 0.00 ile 70 sn ayni yerde, gorev Retreat/Bound)
                            if (isNil "lambs_danger_retTakiliN") then { lambs_danger_retTakiliN = 0; };
                            if (lambs_danger_retTakiliN < 40) then {
                                lambs_danger_retTakiliN = lambs_danger_retTakiliN + 1;
                                diag_log format ["[GERI-CEKILME-TAKILI] %1 | %2%3 | hedefe %4 m | komut:%5 | hiz:%6 | stance:%7 | beh:%8 | ready:%9 | beklenen hedef:%10 | takilma:%11 | binada:%12 | yakin nesne:%13 | AI PATH:%14 MOVE:%15 ANIM:%16 FSM:%17", groupId _grup, name _b, ["", " (K)"] select (_b isEqualTo (leader _grup)), round (_b distance2D (_x select 1)), currentCommand _b, round (speed _b), stance _b, behaviour _b, unitReady _b, expectedDestination _b, (_x select 4), round (insideBuilding _b * 100), count (nearestTerrainObjects [_b, ["BUILDING", "HOUSE", "WALL", "FENCE", "ROCK", "TREE"], 3, false, true]), _b checkAIFeature "PATH", _b checkAIFeature "MOVE", _b checkAIFeature "ANIM", _b checkAIFeature "FSM"];
                            };
                            // her takilmada hareket bayraklari yeniden acilir
                            _b enableAI "PATH";
                            _b enableAI "MOVE";
                            _b enableAI "ANIM";
                            _b setUnitPos "UP";
                            _b setSpeedMode "FULL";
                            _b forceSpeed -1;
                            if ((_x select 4) >= 2) then {
                                // 2. takilma: dusmandan uzaga yeni nokta (18-26 m); once DOSTOP ile komut sifirlanir
                                private _np = (getPosATL _b) getPos [18 + random 8, (_hedefASL getDir (getPosATL _b)) + ((random 50) - 25)];
                                if (!surfaceIsWater _np) then { _x set [1, _np]; };
                                _x set [4, 0];
                                doStop _b;
                                sleep 0.3;
                            };
                            _b doMove (_x select 1);
                            _x set [3, time];
                        };
                    };
                };
            } forEach _varis;

            private _vardi = _varis select {alive (_x select 0) && {((_x select 0) distance2D (_x select 1)) <= 12}};
            private _canli = _varis select {alive (_x select 0)};
            private _gelmeyen = _canli select {
                !((_x select 0) in _pinned)
                && {((_x select 0) distance2D (_x select 1)) > 12}
            };
            // v8.8: kalan herkes baski altinda yere yapistiysa (ezilen) pencerenin sonunu BEKLEME (RPT 12:53: 22-26 sn bosa gidiyordu); sonraki sicrama baslar
            if (_gelmeyen isEqualTo [] && {(time - _t0) >= 6 || {(_pinned select {alive _x}) isEqualTo []}}) exitWith {};
            if ((time - _t0) >= 3 && {_canli isNotEqualTo []} && {(count _vardi) >= ((count _canli) * 0.6)}) exitWith {};
            sleep 1;
        };

        // Sicrama sonucu (diagnostik): kac asker gercekten vardi
        diag_log format [
            "[GERI-CEKILME] %1 sicrama %2 sonuc | vardi:%3/%4 | ezilen:%5",
            groupId _grup, _no,
            count (_varis select {alive (_x select 0) && {((_x select 0) distance2D (_x select 1)) <= 12}}),
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
                _b setBehaviour "COMBAT";   // vardi: siper al, AWARE'de ayakta durma
                _b setUnitPos "AUTO"; _b setUnitPosWeak "MIDDLE";
                // DOSTOP: varan asker kendi sicrama noktasinda KALIR (aksi halde formasyon slotuna, yani liderin eski konumuna,
                // geri yuruyordu = "geri git ileri git, ayni yolu tekrar gidiyorlar")
                if ((_b distance2D (_x select 1)) <= 12) then { doStop _b; };   // SADECE varanlar: varamayan durdurulursa hic ilerlemez (RPT: vardi 0/N, 40 sn'de lider kipirdamadi)
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

    // -----------------------------------------------------------------------
    // BASKI KIRMA FAZI (v8.9): ates altinda (ort. baski >= esik) ve dusman >= 80 m ise ONCE siper al + karsi ates + sis,
    // baski dusunce (< 0.4) ya da sure dolunca (en fazla baskiKirmaMaxS) sicramalar baslar. Acikta kosmak olum (RPT 12:53: 7 -> 2 kisi).
    // -----------------------------------------------------------------------
    private _baskiEsik = [_group, "baskiKirmaEsik", 0.5] call FUNC(dk);
    private _baskiMaxS = [_group, "baskiKirmaMaxS", 14] call FUNC(dk);
    private _baskiOrt = {
        private _u = (units _group) select {alive _x && {isNull objectParent _x}};
        if (_u isEqualTo []) exitWith {0};
        private _t = 0;
        { _t = _t + (getSuppression _x); } forEach _u;
        _t / (count _u)
    };
    if ((call _baskiOrt) >= _baskiEsik && {((leader _group) distance2D _targetPos) >= 80}) then {
        diag_log format ["[GERI-CEKILME-SIPER] %1 | baski:%2 | esik:%3 | dusman:%4 m | once siper, sonra cekil", groupId _group, (call _baskiOrt) toFixed 2, _baskiEsik, round ((leader _group) distance2D _targetPos)];
        {
            if (alive _x && {isNull objectParent _x}) then {
                _x enableAI "TARGET";
                _x enableAI "AUTOTARGET";
                _x enableAI "AUTOCOMBAT";
                _x enableAI "COVER";
                _x setBehaviour "COMBAT";
                _x setUnitPosWeak "DOWN";
                private _cv = [_x, _targetPos, 25, "ASCEND", 1, "OVERWATCH"] call EFUNC(main,findCover);
                if (_cv isNotEqualTo [] && {(_cv select 0) isNotEqualTo []}) then {
                    private _cp = (_cv select 0) select 0;
                    if ((getSuppression _x) < 0.85 && {(_x distance2D _cp) > 3}) then {
                        _x setVariable [QGVAR(forceMove), true];
                        _x doMove _cp;
                    };
                };
                [_x, _targetASL] call EFUNC(main,doSuppress);
            };
        } forEach _tumBirimler;
        private _bk0 = time;
        waitUntil {
            sleep 0.5;
            ((time - _bk0) >= 4 && {(call _baskiOrt) < 0.4}) || {(time - _bk0) >= _baskiMaxS} || {isNull _group}
        };
        diag_log format ["[GERI-CEKILME-SIPER] %1 | baski kirma bitti: %2 sn, baski:%3", groupId _group, round (time - _bk0), (call _baskiOrt) toFixed 2];
        { _x setVariable [QGVAR(forceMove), nil]; } forEach _tumBirimler;
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
    // EK SICRAMALAR (v8.6): sabit 4 sicrama ~90 m'de bitiyordu, dusman hala 120-160 m'deydi (RPT 12:39: 'tam olacakken duruyor').
    // Dusman guvenli mesafeye (cekilGuvenM) ulasana, temas kesilene, sure dolana ya da ek sicrama siniri bitene kadar surer.
    // -----------------------------------------------------------------------
    private _ekGuvenM = [_group, "cekilGuvenM", 450] call FUNC(dk);
    private _ekMax = [_group, "cekilEkSicrama", 9] call FUNC(dk);
    // v8.47: "retreat cok kisa" — sure siniri / gozlem-yok alt siniri doktrin anahtari (TASARIM)
    private _ekMaxS = [_group, "cekilMaxS", 300] call FUNC(dk);
    private _ekGozM = [_group, "cekilGozlemM", 280] call FUNC(dk);
    private _ekNo = 0;
    private _ekNeden = "";
    while {!isNull _group && {_ekNo < _ekMax} && {time < (_baslangic + _ekMaxS)}} do {
        private _canli = (units _group) select {alive _x && {isNull objectParent _x}};
        if (_canli isEqualTo []) exitWith {};
        private _ld = [leader _group, _canli select 0] select (isNull (leader _group) || {!alive (leader _group)});
        private _dus = _ld findNearestEnemy _ld;
        private _tp = [getPosATL _dus, _targetPos] select (isNull _dus);
        private _d = (getPosATL _ld) distance2D _tp;
        if (_d >= _ekGuvenM) exitWith { _ekNeden = "guvenli mesafe"; };
        if ((_group getVariable [QGVAR(contact), 0]) <= time && {_d >= (_ekGozM * 0.7)}) then { _ekNeden = "temas kesildi"; };
        // v8.34 DOKTRIN (TC 3-21.76 Break Contact standardi, s. 8-11: "continues to move until the enemy cannot observe or place fire on them"):
        //   bitis kriteri GORUS: dusman biliniyor, >= 100 m (TASARIM: tufek etkili atis alt siniri) ve askerlerin >= %80'i dusmandan siperli (arazi / nesne) ise dur.
        //   Maliyet: ek sicrama basina asker sayisi kadar 2 isin sorgusu (~12-20), ihmal edilebilir.
        if (_ekNeden isEqualTo "" && {!isNull _dus} && {_d >= _ekGozM}) then {
            private _eEye = AGLToASL ((getPosATL _dus) vectorAdd [0, 0, 1.6]);
            private _gizliN = {
                private _uEye = AGLToASL ((getPosATL _x) vectorAdd [0, 0, 1.0]);
                terrainIntersectASL [_eEye, _uEye] || {lineIntersects [_eEye, _uEye, _dus, _x]}
            } count _canli;
            if (_gizliN >= (ceil (0.9 * (count _canli)))) then { _ekNeden = "gozlem yok"; };
        };
        if (_ekNeden isNotEqualTo "") exitWith {};
        _targetPos = _tp;
        _targetASL = AGLToASL _tp;
        // v8.14: ek sicrama GRUBUN ARKASINDAN olculur (en uzak asker) ve adim >= 35 m (RPT 13:09: lider onde oldugu icin nokta zaten askerlerin 12 m icindeydi,
        //   sicrama 1 sn'de "vardi 4/4" bitiyor, mesafe 101-103 m'de kaliyordu = retreat mesafe kazanmiyordu)
        private _arka = _ld;
        { if ((_x distance2D _tp) > (_arka distance2D _tp)) then { _arka = _x; }; } forEach _canli;
        _adimBoy = _adimBoy max 50;
        private _o = getPosATL _arka;
        private _wpE = [_o, _tp getDir _o] call _wpSec;
        _wpE = [_wpE, _o] call _suKontrol;
        private _ciftMi = (_ekNo % 2) isEqualTo 0;
        private _hr = if (_bravo isEqualTo []) then {_alpha} else {[_bravo, _alpha] select _ciftMi};
        private _kp = if (_bravo isEqualTo []) then {[]} else {[_alpha, _bravo] select _ciftMi};
        _hr = _hr select {alive _x};
        if (_hr isEqualTo []) then { _hr = _canli; _kp = []; };
        _ekNo = _ekNo + 1;
        diag_log format ["[GERI-CEKILME-EK] %1 | ek sicrama %2/%3 | dusman:%4 m (guvenli:%5)", groupId _group, _ekNo, _ekMax, round _d, _ekGuvenM];
        [_group, _hr, _kp select {alive _x}, _wpE, _targetASL, (count _sira) + _ekNo] call _sicra;
    };

    // v8.34 DOKTRIN (TC 3-21.76 s. 8-14, adim 10: "consider changing the unit's direction of movement once contact is broken"; dusmanin izi surmesini / etkili dolayli ates getirmesini zorlastirir):
    //   temas koptu / dusman gozlem yapamiyor ise TEK BIR toplu ek sicrama, geri eksenden +-55 derece (TASARIM) sapma ile (en gizli aday _wpSec ile secilir).
    if (!isNull _group && {_ekNeden in ["temas kesildi", "gozlem yok"]} && {time < (_baslangic + _ekMaxS - 10)}) then {
        private _canliY = (units _group) select {alive _x && {isNull objectParent _x}};
        if ((count _canliY) >= 3) then {
            private _arkaY = _canliY select 0;
            { if ((_x distance2D _targetPos) > (_arkaY distance2D _targetPos)) then { _arkaY = _x; }; } forEach _canliY;
            private _oY = getPosATL _arkaY;
            private _yon = (_targetPos getDir _oY) + (selectRandom [55, -55]);
            private _wpY = [_oY, _yon] call _wpSec;
            _wpY = [_wpY, _oY] call _suKontrol;
            diag_log format ["[GERI-CEKILME-YON] %1 | neden:%2 | yon degistirme sicramasi (eksen %3 derece) | dusman son bilinen %4 m", groupId _group, _ekNeden, round (_yon - (_targetPos getDir _oY)), round (_oY distance2D _targetPos)];
            [_group, _canliY, [], _wpY, _targetASL, (count _sira) + _ekNo + 1] call _sicra;
        };
    };
    if (_ekNeden isNotEqualTo "") then {
        diag_log format ["[GERI-CEKILME-BITIS] %1 | neden:%2 | ek sicrama:%3 | sure:%4 sn", groupId _group, _ekNeden, _ekNo, round (time - _baslangic)];
    };

    // -----------------------------------------------------------------------
    // TEMIZLIK
    // -----------------------------------------------------------------------
    if (!isNull _group && {((_group getVariable [QGVAR(retreatStartTime), -1]) isEqualTo _baslangic)}) then {
        { _x setVariable [QGVAR(taktikKilit), nil]; } forEach (units _group);
        _group setVariable [QGVAR(isRetreating), nil];
        // v8.30 TOPLANMA (RPT 18:37: retreat biter bitmez LAMBS "TACTICS FLANK" ile hemen geri dondu): konsolidasyonS (45 sn) boyunca grup LAMBS grup taktigi KAPALI kalir,
        //   sonra eski degere doner (gercekte temas kesildikten sonra toparlanma: yeniden duzen, kayip / cephane sayimi)
        private _eskiDGAk = _group getVariable [QGVAR(retreatEskiDGA), false];
        private _konsS = [_group, "konsolidasyonS", 90] call FUNC(dk);
        if (_konsS > 0 && {({alive _x} count (units _group)) >= 2}) then {
            _group setVariable [QGVAR(disableGroupAI), true];
            diag_log format ["[GERI-CEKILME-TOPLAN] %1 | %2 sn toparlanma: LAMBS grup taktigi kapali (hemen geri hucum yok)", groupId _group, _konsS];
            [_group, _eskiDGAk, _konsS] spawn {
                params ["_g", "_e", "_s"];
                sleep _s;
                // v8.34: toparlanma modulu (fnc_toparlan) calisiyorsa eski degeri O geri verir
                if (!isNull _g && {!(_g getVariable [QGVAR(isRetreating), false])} && {!(_g getVariable [QGVAR(isToparlan), false])}) then {
                    _g setVariable [QGVAR(disableGroupAI), [nil, true] select _e];
                    diag_log format ["[GERI-CEKILME-TOPLAN] %1 | toparlanma bitti, LAMBS grup taktigi geri acildi", groupId _g];
                };
            };
        } else {
            _group setVariable [QGVAR(disableGroupAI), [nil, true] select _eskiDGAk];
        };
        _group setVariable [QGVAR(retreatEskiDGA), nil];
        {
            _x setVariable [QGVAR(disableAI), [nil, true] select (_x getVariable [QGVAR(retreatEskiDAI), false])];
            _x setVariable [QGVAR(retreatEskiDAI), nil];
        } forEach (units _group);
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

        [_group, "RetreatBitti", ""] call FUNC(olayGonder);
        diag_log format ["[GERI-CEKILME-TAMAM] %1", groupId _group];
        // v8.34 DOKTRIN: toparlanma = consolidate and reorganize (TC 3-21.76 s. 8-9 / 8-10; fnc_toparlan). Baslarsa LAMBS grup taktigi eski degeri toparlanma bitince geri gelir.
        [_group, _targetPos, _eskiDGAk] call FUNC(toparlan);
    };
};

true
