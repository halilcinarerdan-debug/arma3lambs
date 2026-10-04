#include "script_component.hpp"
/*
 * Author: Cinar (ELITE fork)
 * TOPLANMA = CONSOLIDATE AND REORGANIZE (retreat sonrasi). Kaynak: TC 3-21.76 Ranger Handbook (26 Apr 2017) Battle Drill "Consolidate and reorganize" s. 8-9 / 8-10,
 * Break Contact s. 8-14 adim 12 ("Unit leaders account for Soldiers, report, reorganize as necessary, continue the mission"); MCWP 3-11.1 s. 6-18 / 6-19 (reorganization = durum raporu, personel / cephane dagitimi, CASEVAC, kontrol).
 * Birincil metin: kaynaklar_doktrin/ ; bulgular: DOKTRIN_KAYNAKLARI.md bolum H2.
 *
 * DOKTRIN SIRASI -> ARMA 3 KARSILIGI (Arma'da kazma / cephane transferi yok; sihirli esya yok):
 *   a. yerel guvenlik        -> grup, toplanma noktasinda (lider konumu) 360 derece halka; herkes disa bakar (doWatch)
 *   b. ates unsuru konumlara -> herkes halka noktasina (kapali yere yakin) gider (forceMove, varista doStop)
 *   c. ates sektorleri       -> her askere halkada tehdit yonune gore sektor (bakis yonu)
 *   d. kritik silahlar tehlikeli yone -> MG / AT / nisanci tehdit yonune en yakin sektorler
 *   f. hizli mevzi           -> halka noktasi 6 m icinde agac / kaya / duvar varsa oraya; durus CROUCH (MG: PRONE)  (kazma yok)
 *   h. gozetleme noktasi     -> >= 5 kisi: 1 tufekci tehdit yonunde 30-45 m'de gizli noktada OP (dusman gelirse grup bilgisi zaten paylasilir)
 *   i. komuta zinciri        -> lider olu ise motor yeni lider atar; logda yazilir
 *   e / j / k / l. cephane, ekip silahlari, teçhizat -> Arma'da esya aktarimi YAPILMAZ (sihirli esya istemiyoruz); yalniz DURUM raporu (kisi basi sarjor) ve komutana veri
 *   m. yaralilar             -> TCCC (fnc_tccc) kendi dongusu; AI saglik sistemi kapaliysa anlamsiz; burada yalniz sayim
 *   RAPOR                    -> [TOPLAN-RAPOR] (kalan / kayip / yarali / sarjor / son dusman) + olay "ToparlanRapor"
 *   KARAR (lider)            -> temas yeniden basladiysa: toparlanma biter, komutan (commanderAssess) yeniden karar verir (cekilme devam / siper);
 *                               temas yoksa: SAVUN (hizli savunma) sure dolana kadar. OTOMATIK KARSI SALDIRI YOK (doktrin: once reorganize et).
 *   SURE: doktrin anahtari konsolidasyonS (varsayilan 45 sn, DUZENSIZ 20) — SURE KAYNAKTA SAYI OLARAK YOK, TASARIM.
 *
 * Retreat temizliginden cagrilir; LAMBS grup taktigi (disableGroupAI) toparlanma boyunca KAPALI kalir, bitince ESKI HALINE doner (bu fonksiyon geri verir).
 * Kapatma: lambs_danger_toparlanV1 = false ya da doktrin toparlan = false (eski davranis: yalniz sure boyunca LAMBS kapali).
 * Log: [TOPLAN] BASLA / RAPOR / BITTI.
 *
 * Arguments:
 * 0: Grup <GROUP>
 * 1: Son bilinen tehdit pozisyonu <ARRAY>
 * 2: Retreat oncesi disableGroupAI degeri <BOOL>
 *
 * Return Value: Baslatildi mi <BOOL>
 * Public: No
*/

params [["_group", grpNull, [grpNull]], ["_tehditPos", [0, 0, 0], [[]]], ["_eskiDGA", false, [false]]];

if (isNull _group || {!(missionNamespace getVariable ["lambs_danger_toparlanV1", true])}) exitWith {false};
if (!([_group, "toparlan", true] call FUNC(dk))) exitWith {false};
if (_group getVariable [QGVAR(isToparlan), false]) exitWith {false};

private _us = (units _group) select {alive _x && {isNull objectParent _x} && {(lifeState _x) in ["HEALTHY", "INJURED"]}};
if ((count _us) < 2) exitWith {false};

private _lider = if (alive (leader _group)) then {leader _group} else {_us select 0};
private _merkez = getPosATL _lider;
private _tehditVar = _tehditPos isNotEqualTo [0, 0, 0];
private _tehditYon = if (_tehditVar) then {_merkez getDir _tehditPos} else {getDir _lider};
private _sure = [_group, "konsolidasyonS", 45] call FUNC(dk);
if (_sure <= 0) exitWith {false};

// --- halka: lider + hekim merkezde, digerleri halkada ---
private _rolFn = missionNamespace getVariable ["lambs_danger_fnc_getUnitRole", {"RIFLE"}];
private _halkaUye = _us select {_x isNotEqualTo _lider && {([_x] call _rolFn) isNotEqualTo "MEDIC"}};
private _n = count _halkaUye;
private _R = [8, 12] select (_n > 4);

// d) kritik silahlar tehdit yonune en yakin sektorler: oncelik MG > AT > MARKSMAN > diger
private _sirali = [_halkaUye, [], { private _i = ([_x] call _rolFn); private _p = ["MG", "AT", "MARKSMAN"] find _i; [99, _p] select (_p > -1) }, "ASCEND"] call BIS_fnc_sortBy;

// sektor acilari: tehdit yonuyle baslayip dalga dalga (0, +a, -a, +2a, -2a ...) -> tehdite yakin sektorler ilk siradakilere
private _adim = [360 / (_n max 1), 90] select (_n <= 3);
private _acilar = [];
for "_i" from 0 to (_n - 1) do {
    private _k = ceil (_i / 2);
    _acilar pushBack (((_tehditYon + ([1, -1] select (_i % 2 == 0)) * _k * _adim) + 720) mod 360);
};
// (i = 0 -> k = 0 -> tam tehdit yonu)

private _atamalar = [];
{
    private _u = _x;
    private _ac = _acilar select _forEachIndex;
    private _nokta = _merkez getPos [_R, _ac];
    if (surfaceIsWater _nokta) then { _nokta = _merkez getPos [4, _ac]; };
    // f) kapali yere yakin: 6 m icinde agac / kaya / duvar
    private _kapali = nearestTerrainObjects [_nokta, ["TREE", "ROCK", "WALL", "HIDE", "BUSH"], 6, true, true];
    if (_kapali isNotEqualTo []) then {
        private _kp = getPosATL (_kapali select 0);
        // nesnenin dusman tarafina degil, arkasina (halka icine dogru) 1.5 m yerlesim
        _nokta = _kp getPos [1.5, _kp getDir _merkez];
        if (surfaceIsWater _nokta) then { _nokta = _merkez getPos [4, _ac]; };
    };
    _atamalar pushBack [_u, _nokta, _ac, [_u] call _rolFn];
} forEach _sirali;

// h) gozetleme noktasi: >= 5 kisi; en sondaki tufekci (rolu RIFLE) halkadan alinir
private _op = [];
if ((count _us) >= 5 && {_tehditVar}) then {
    private _aday = _atamalar findIf {(_x select 3) isEqualTo "RIFLE"};
    if (_aday > -1) then {
        private _eEye = AGLToASL (_tehditPos vectorAdd [0, 0, 1.6]);
        private _enIyi = [];
        private _enIyiS = -9999;
        { // 30 / 40 / 45 m x -35 / 0 / +35 derece
            private _r = _x;
            {
                private _c = _merkez getPos [_r, _tehditYon + _x];
                private _s = 0;
                if (surfaceIsWater _c) then { _s = _s - 500; };
                private _cASL = AGLToASL (_c vectorAdd [0, 0, 1.0]);
                // tehditten gorunmemek (gizli) iyi
                if (terrainIntersectASL [_eEye, _cASL] || {lineIntersects [_eEye, _cASL, objNull, objNull]}) then { _s = _s + 25; };
                if ((nearestTerrainObjects [_c, ["TREE", "ROCK", "WALL", "HIDE", "BUSH"], 3, false, true]) isNotEqualTo []) then { _s = _s + 10; };
                if (_s > _enIyiS) then { _enIyiS = _s; _enIyi = _c; };
            } forEach [-35, 0, 35];
        } forEach [30, 40, 45];
        if (_enIyi isNotEqualTo [] && {_enIyiS > -100}) then {
            private _a = _atamalar select _aday;
            _a set [1, _enIyi];
            _a set [2, _tehditYon];
            _a set [3, "OP"];
            _op = [_a select 0];
        };
    };
};

// --- bayraklar ---
_group setVariable [QGVAR(isToparlan), true];
_group setVariable [QGVAR(toparlanT), time];
_group setVariable [QGVAR(disableGroupAI), true];
{
    private _u = _x select 0;
    _u setVariable [QGVAR(forceMove), true];
    _u enableAI "PATH"; _u enableAI "MOVE";
    _u setUnitPos "UP";
    _u doMove (_x select 1);
} forEach _atamalar;
// lider: tehdit yonune bakar, merkezde
if (_tehditVar) then { _lider doWatch _tehditPos; };

// TC 3-21.76 Break Contact adim 11: 'Elements and Soldiers that become disrupted stay together and move to the last designated rally point' -> toplanma noktasi = lider konumu; dagilanlar (> 40 m) sayilir, halka noktalarina zaten oraya gelir
private _dagilan = {(_x distance2D _merkez) > 40} count _us;
diag_log format [
    "[TOPLAN] %1 | BASLA | %2 kisi (halka %3, OP %4) | tehdit yonu %5 | yaricap %6 m | sure %7 sn | dagilan (>40 m, son RP'ye): %9 | silah sektorleri: %8",
    groupId _group, count _us, _n, count _op, round _tehditYon, _R, _sure,
    _atamalar apply {format ["%1:%2@%3", _x select 3, name (_x select 0), round (_x select 2)]},
    _dagilan
];

[_group, _atamalar, _lider, _tehditPos, _tehditVar, _eskiDGA, _sure, count (units _group)] spawn {
    params ["_g", "_atamalar", "_lider", "_tp", "_tVar", "_eskiDGA", "_sure", "_toplamIlk"];
    private _t0 = time;
    private _raporlandi = false;
    private _neden = "sure doldu";
    private _tick = 0;

    while {time < (_t0 + _sure)} do {
        sleep 2;
        _tick = _tick + 1;
        if (isNull _g) exitWith { _neden = "grup yok"; };
        if (((units _g) findIf {alive _x}) < 0) exitWith { _neden = "grup yok oldu"; };
        if (_g getVariable [QGVAR(isRetreating), false] || {_g getVariable [QGVAR(isBreakingContact), false]} || {_g getVariable [QGVAR(isEvading), false]}) exitWith { _neden = "baska taktik basladi"; };

        // KARAR: temas yeniden basladi (dusman <= 150 m ve son 10 sn'de gorunmus) -> toparlanma biter, komutan karar verir (cekilme devam / siper)
        private _canliL = (units _g) select {alive _x};
        private _ldr = [leader _g, _canliL select 0] select (isNull (leader _g) || {!alive (leader _g)});
        private _dus = _ldr findNearestEnemy _ldr;
        if (!isNull _dus && {(_ldr distance2D _dus) <= 150} && {(_g getVariable [QGVAR(contact), 0]) > time}) exitWith { _neden = format ["temas yeniden basladi (dusman %1 m)", round (_ldr distance2D _dus)]; };
        if ((((units _g) findIf {alive _x && {(getSuppression _x) > 0.8}}) > -1) && {!isNull _dus} && {(_ldr distance2D _dus) < 200}) exitWith { _neden = "baski altinda"; };

        // asker / mevzi: varista doStop + durus + sektor bakisi; 6 sn'de bir sapanlari tekrar yonlendir (LAMBS birim FSM'i dagitabilir)
        {
            _x params ["_u", "_p", "_ac", "_rol"];
            if (!alive _u || {!isNull objectParent _u}) then { continue };
            _u setVariable [QGVAR(taktikKilit), time + 6];
            private _mesafe = _u distance2D _p;
            if (_mesafe < 2.5) then {
                if (_u getVariable [QGVAR(forceMove), false]) then {
                    _u setVariable [QGVAR(forceMove), nil];
                    doStop _u;
                    _u setUnitPos (["MIDDLE", "DOWN"] select (_rol isEqualTo "MG"));
                };
                if ((_tick % 5) == 0) then { _u doWatch (_p getPos [150, _ac]); };
            } else {
                if ((_tick % 3) == 0 && {_mesafe > 6}) then { _u doMove _p; };
            };
        } forEach _atamalar;

        // RAPOR: yeterince yerlestiklerinde (veya 14 sn) bir kez
        if (!_raporlandi && {(time - _t0) > 14 || {({alive (_x select 0) && {((_x select 0) distance2D (_x select 1)) < 4}} count _atamalar) >= (count _atamalar) * 0.8}}) then {
            _raporlandi = true;
            private _canli = (units _g) select {alive _x};
            private _yarali = {(lifeState _x) in ["INCAPACITATED"] || {_x getVariable ["ACE_isUnconscious", false]}} count _canli;
            private _mag = 0;
            { _mag = _mag + (count (magazines _x)); } forEach _canli;
            private _init = _g getVariable [QGVAR(cmdInitialCount), _toplamIlk];
            if (!(_init isEqualType 0) || {_init < (count _canli)}) then { _init = count _canli; };
            private _kayip = if (_init > 0) then {round (100 * (_init - (count _canli)) / _init)} else {0};
            diag_log format [
                "[TOPLAN-RAPOR] %1 | kalan %2/%3 (kayip %4%%) | yarali %5 | sarjor/kisi %6 | komuta %7 | son dusman %8",
                groupId _g, count _canli, _init, _kayip, _yarali, (_mag / ((count _canli) max 1)) toFixed 1, name _ldr,
                if (_tVar) then {format ["%1 m yon %2", round (_ldr distance2D _tp), round (_ldr getDir _tp)]} else {"bilinmiyor"}
            ];
            [_g, "ToparlanRapor", [count _canli, _init, _yarali, round (_mag / ((count _canli) max 1))]] call FUNC(olayGonder);
        };
    };

    if (!isNull _g) then {
        _g setVariable [QGVAR(isToparlan), nil];
        if !(_g getVariable [QGVAR(isRetreating), false]) then {
            _g setVariable [QGVAR(disableGroupAI), [nil, true] select _eskiDGA];
        };
        {
            private _u = _x select 0;
            if (alive _u) then {
                _u setVariable [QGVAR(forceMove), nil];
                _u setVariable [QGVAR(taktikKilit), nil];
                if !(_g getVariable [QGVAR(isRetreating), false]) then {
                    _u setUnitPos "AUTO";
                    _u doWatch objNull;
                    _u doFollow (leader _u);
                };
            };
        } forEach _atamalar;
        _g setVariable [QGVAR(toparlanBitis), time];
        diag_log format ["[TOPLAN] %1 | BITTI | neden:%2 | %3 sn | LAMBS grup taktigi geri acildi", groupId _g, _neden, round (time - _t0)];
        [_g, "ToparlanBitti", _neden] call FUNC(olayGonder);
    };
};

true
