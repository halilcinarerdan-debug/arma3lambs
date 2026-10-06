#include "script_component.hpp"
/*
 * Author: Cinar (ELITE fork)
 * KUMANDA MODULU: DESTEK ATESI (support by fire) — kullanici: "A Squad bir tepeye saldirirken (taarruz grubu), telsiz mesafesindeki B Squad otomatik olarak
 *   yan tepede durup doSuppress ile A Squad'inin onune baski atesi acmali".
 * Doktrin ilkesi (genel; sayisal esikler TASARIM tahmini, kaynakli degil): taarruz eden unsur manevra eder, destek unsuru dusman pozisyonunu ates ile bastirir (fix / suppress) ve
 *   hucum yaklasirken atesi kaydirir (dost atesini onleme).
 * TETIK (TAARRUZ GRUBU A): temasta, cmdSit taze (<= 30 sn), son karar ASSAULT / SUPPRESS_ASSAULT / BOUNDING, bounding veya taktik isi var, >= 3 kisi, bilinen dusman 70-450 m,
 *   retreat / kacis / son direnis yok, son 120 sn'de destek istememis, taraf basina en cok 2 es zamanli destek.
 * DESTEK UNSURU B: tahtada 'musait', >= 3 kisi, A'nin telsiz mesafesinde (hqDestekM, varsayilan 1200 m; lider telsizi), A'dan >= 60 m, dusmana >= 120 m, atis zamani mermisi yeterli (mermiTasarruf olmayan en az 2 asker).
 * DESTEK NOKTASI ("yan tepe"): dusman -> A ekseninin +-35..105 derece (A'nin ates hattina DIK / acili: dost atesi riski dusuk), dusmandan 160-380 m; skor = dusmandan yukseklik farki x 1.0
 *   + A'ya gore yukseklik x 0.3 + dusman noktasina arazi gorusu (terrainIntersectASL) + 40 - B'nin yurume mesafesi x 0.05; gorus yoksa aday elenir.
 * B YAPAR: noktaya (dagilik 7 m) hareket (forceMove), varista combatMode RED + herkes doSuppressiveFire dusman noktasina (8 sn'de bir tazelenir; +-6 m dagilim; tasarruf ederken MG / ikinci sirada olmayanlar susar).
 *   A dusman noktasina < 45 m girince ates 40 m ilerisine KAYDIRILIR (hucum eden dosta ates gitmesin). BITIS: A saldirisi bitti / dusman 25 sn bilinmiyor / 150 sn / B temasa girdi / retreat.
 * Log: [HQ-DESTEK] EMIR / VARIS / KAYDIR / BITTI. Kapatma: lambs_danger_hqDestekV1 = false; doktrin anahtari hqDestek (varsayilan true), hqDestekM (1200).
 *
 * Arguments:
 * 0: Taraf <SIDE>
 * 1: Durum tahtasi <ARRAY of HASHMAP>
 *
 * Return Value: Yeni emir verildi mi <BOOL>
 * Public: No
*/

params [["_taraf", sideUnknown, [sideUnknown]], ["_tahta", [], [[]]]];

if (isNil "lambs_danger_hqDestekler") then { lambs_danger_hqDestekler = createHashMap; };
if (isNil "lambs_danger_hqDestekN") then { lambs_danger_hqDestekN = 0; };

private _log = {
    if (lambs_danger_hqDestekN < 150) then {
        lambs_danger_hqDestekN = lambs_danger_hqDestekN + 1;
        diag_log _this;
    };
};

// ---------------------------------------------------------------------------
// 1) calisan destekler: yurume -> varis -> baski -> kaydirma -> bitis
// ---------------------------------------------------------------------------
private _kaldir = [];
{
    private _k = _x;
    _y params ["_bG", "_aG", "_pos", "_enP", "_t0", "_durum", "_sonAtes", "_kaydirildi"];
    private _bit = "";
    if (isNull _bG || {!alive (leader _bG)}) then { _kaldir pushBack _k; continue };
    if ((side _bG) isNotEqualTo _taraf) then { continue };
    if (isNull _aG || {!alive (leader _aG)}) then { _bit = "taarruz grubu yok" };
    private _aSit = if (isNull _aG) then {[]} else { _aG getVariable [QGVAR(cmdSit), []] };
    private _aTaze = _aSit isEqualType [] && {(count _aSit) >= 8} && {(time - (_aSit select 0)) < 25};
    if (_bit isEqualTo "" && {(time - _t0) > 150}) then { _bit = "sure" };
    if (_bit isEqualTo "" && {!_aTaze}) then { _bit = "dusman 25 sn bilinmiyor" };
    if (_bit isEqualTo "" && {(_aG getVariable [QGVAR(isRetreating), false]) || {_aG getVariable [QGVAR(isBreakingContact), false]}}) then { _bit = "taarruz grubu cekiliyor" };
    if (_bit isEqualTo "" && {!(_aG getVariable [QGVAR(isBounding), false]) && {!(_aG getVariable [QGVAR(isExecutingTactic), false])} && {(time - _t0) > 20}}) then { _bit = "taarruz bitti" };
    if (_bit isEqualTo "" && {_bG getVariable [QGVAR(isRetreating), false]}) then { _bit = "destek grubu cekiliyor" };
    if (_bit isEqualTo "" && {_durum isEqualTo "BASKI"} && {({alive _x && {(getSuppression _x) > 0.75}} count (units _bG)) >= 2}) then { _bit = "destek grubu ates altinda" };

    if (_bit isNotEqualTo "") then {
        {
            if (alive _x) then {
                if !(time < (_x getVariable [QGVAR(tcccBusy), 0])) then { _x setVariable [QGVAR(forceMove), nil]; };
                _x setVariable [QGVAR(destekAsker), nil];
                _x doWatch objNull;
                _x doFollow (leader _bG);
            };
        } forEach (units _bG);
        _bG setVariable [QGVAR(isExecutingTactic), nil];
        _bG setVariable [QGVAR(destekT), time];
        (format ["[HQ-DESTEK] %1 | BITTI (%2) | destek %3 | %4 sn", _taraf, _bit, groupId _bG, round (time - _t0)]) call _log;
        _kaldir pushBack _k;
        continue;
    };

    private _bL = leader _bG;
    if (_durum isEqualTo "YOLDA") then {
        if ((_bL distance2D _pos) < 30 || {(time - _t0) > 100}) then {
            _y set [5, "BASKI"];
            _bG setCombatMode "RED";
            _bG setBehaviour "COMBAT";
            { if (alive _x && {_x getVariable [QGVAR(destekAsker), false]}) then { doStop _x; _x setUnitPos "MIDDLE"; _x doWatch _enP; }; } forEach (units _bG);
            (format ["[HQ-DESTEK] %1 | VARIS destek %2 (%3 m'de) -> baski %4 | dusman %5", _taraf, groupId _bG, round (_bL distance2D _pos), groupId _aG, mapGridPosition _enP]) call _log;
        };
    };
    if (_y select 5 isEqualTo "BASKI" && {time > _sonAtes}) then {
        _y set [6, time + 8];
        // taarruz grubunun guncel dusman noktasi
        private _hp = _enP;
        if (_aTaze && {(_aSit select 7) isEqualType []} && {(_aSit select 7) isNotEqualTo [0,0,0]}) then { _hp = _aSit select 7; _y set [3, _hp]; };
        // hucum yaklasti: atesi KAYDIR (taarruz lideri dusman noktasina < 45 m)
        private _aMes = (leader _aG) distance2D _hp;
        private _hedef = _hp;
        if (_aMes < 45) then {
            _hedef = _hp getPos [40, (leader _aG) getDir _hp];
            if !(_kaydirildi) then {
                _y set [7, true];
                (format ["[HQ-DESTEK] %1 | KAYDIR destek %2 | taarruz %3 hedefe %4 m -> ates 40 m ilerisine", _taraf, groupId _bG, groupId _aG, round _aMes]) call _log;
            };
        };
        private _sira = 0;
        {
            private _u = _x;
            if (!alive _u || {!isNull objectParent _u} || {isPlayer _u} || {!((lifeState _u) in ["HEALTHY", "INJURED"])} || {_u getVariable ["ACE_isUnconscious", false]}) then { continue };
            if (time < (_u getVariable [QGVAR(tcccBusy), 0])) then { continue };
            // mermi disiplini: tasarruf eden asker (MG degilse) susar; MG surekli
            private _rol = [_u] call (missionNamespace getVariable ["lambs_danger_fnc_getUnitRole", {"RIFLE"}]);
            if ((_u getVariable [QGVAR(mermiTasarruf), false]) && {_rol isNotEqualTo "MG"}) then { continue };
            _sira = _sira + 1;
            // tufekliler dagitik (+-6 m), 2'de 1'i dinlenir (mermi / sicaklik): MG ve MARKSMAN her tikte
            if (_rol in ["MG", "MARKSMAN"] || {(_sira mod 2) isEqualTo (floor (time / 8) mod 2)}) then {
                _u doSuppressiveFire (_hedef getPos [random 6, random 360]);
            };
        } forEach (units _bG);
    };
} forEach lambs_danger_hqDestekler;
{ lambs_danger_hqDestekler deleteAt _x; } forEach _kaldir;

// ---------------------------------------------------------------------------
// 2) yeni destek istegi
// ---------------------------------------------------------------------------
private _calisanTaraf = {(side (_x select 0)) isEqualTo _taraf} count (values lambs_danger_hqDestekler);
if (_calisanTaraf >= 2) exitWith {false};

private _musaitlar = _tahta select {(_x get "musait") && {(_x get "n") >= 3}};
if (_musaitlar isEqualTo []) exitWith {false};

private _istekler = _tahta select {
    private _g = _x get "g";
    private _sit = _x get "sit";
    private _kar = _g getVariable [QGVAR(cmdSonKarar), ""];
    (_x get "temasta")
    && {(_x get "n") >= 3}
    && {_kar in ["ASSAULT", "SUPPRESS_ASSAULT", "BOUNDING"]}
    && {(_g getVariable [QGVAR(isBounding), false]) || {_g getVariable [QGVAR(isExecutingTactic), false]}}
    && {(time - (_g getVariable [QGVAR(destekIstekT), -999])) > 120}
    && {[_g, "hqDestek", true] call FUNC(dk)}
    && {!(_g getVariable [QGVAR(isRetreating), false])} && {!(_g getVariable [QGVAR(isBreakingContact), false])} && {!(_g getVariable [QGVAR(isSonDirenis), false])}
    && {(_sit isEqualType []) && {(count _sit) >= 8} && {(time - (_sit select 0)) < 30} && {(_sit select 1) >= 70} && {(_sit select 1) <= 450} && {(_sit select 2) >= 1}
        && {(_sit select 7) isEqualType []} && {(_sit select 7) isNotEqualTo [0, 0, 0]}}
    && {!((keys lambs_danger_hqDestekler) findIf {(lambs_danger_hqDestekler get _x) select 1 isEqualTo _g} >= 0)}
};
if (_istekler isEqualTo []) exitWith {false};

private _aY = (_istekler apply {[_x, time - ((_x get "g") getVariable [QGVAR(hqTemasBas), time])]});
_aY = [_aY, [], {_x select 1}, "DESCEND"] call BIS_fnc_sortBy;
private _istek = (_aY select 0) select 0;
private _aG = _istek get "g";
private _aPoz = _istek get "poz";
private _sit = _istek get "sit";
private _enP = +(_sit select 7);
private _menzil = [_aG, "hqDestekM", 1200] call FUNC(dk);

private _adaylar = _musaitlar select {
    private _bG = _x get "g";
    private _d = (_x get "poz") distance2D _aPoz;
    _bG isNotEqualTo _aG && {_d >= 60} && {_d <= _menzil} && {((_x get "poz") distance2D _enP) >= 120}
    && {!(_bG getVariable [QGVAR(isExecutingTactic), false])}
    && {({alive _x && {!(_x getVariable [QGVAR(mermiTasarruf), false])}} count (units _bG)) >= 2}
    && {(time - (_bG getVariable [QGVAR(destekT), -999])) > 60}
};
if (_adaylar isEqualTo []) exitWith {false};
private _sirali = [_adaylar, [], { -((_x get "poz") distance2D _aPoz) + (10 * (_x get "n")) }, "DESCEND"] call BIS_fnc_sortBy;
private _b = _sirali select 0;
private _bG = _b get "g";
private _bPoz = _b get "poz";

// destek noktasi ("yan tepe")
private _eksen = _enP getDir _aPoz;
private _hE = getTerrainHeightASL _enP;
private _hA = getTerrainHeightASL _aPoz;
private _gozE = AGLToASL (_enP vectorAdd [0, 0, 1.5]);
private _en = [];
private _enSkor = -1e9;
{
    private _aci = _x;
    {
        private _p = _enP getPos [_x, _eksen + _aci];
        if (!surfaceIsWater _p) then {
            private _hP = getTerrainHeightASL _p;
            private _goz = AGLToASL (_p vectorAdd [0, 0, 1.2]);
            if (!(terrainIntersectASL [_goz, _gozE])) then {
                private _s = (_hP - _hE) + 0.3 * (_hP - _hA) + 40 - 0.05 * (_p distance2D _bPoz);
                // dusman yonune gore taarruz grubunun ates hattina yakinlik cezasi
                if (abs (_aci) < 40) then { _s = _s - 20; };
                if (_s > _enSkor) then { _enSkor = _s; _en = _p; };
            };
        };
    } forEach [160, 240, 320, 380];
} forEach [35, 55, 80, 105, -35, -55, -80, -105];
if (_en isEqualTo []) exitWith {false};

// emir: B grubuna destek
if ([_bG, "DESTEK", [_en, _enP, groupId _aG]] call FUNC(hqEmir)) then {
    lambs_danger_hqDestekler set [groupId _bG, [_bG, _aG, _en, _enP, time, "YOLDA", 0, false]];
    _aG setVariable [QGVAR(destekIstekT), time];
    (format ["[HQ-DESTEK] %1 | EMIR: taarruz %2 (%3 kisi, dusman %4 m, karar %5) | destek %6 (%7 kisi, %8 m) -> nokta %9 (yukseklik farki %10 m) | ates hedefi %11",
        _taraf, groupId _aG, _istek get "n", round (_sit select 1), _aG getVariable [QGVAR(cmdSonKarar), "?"], groupId _bG, _b get "n", round (_bPoz distance2D _aPoz),
        mapGridPosition _en, round ((getTerrainHeightASL _en) - _hE), mapGridPosition _enP]) call _log;
    true
} else { false }
