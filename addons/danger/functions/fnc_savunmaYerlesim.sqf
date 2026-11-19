#include "script_component.hpp"
/*
 * Author: Cinar (ELITE fork)
 * SAVUNMADA AVANTAJLI YERE YERLESME (v8.675; kullanici: 'avantajli bolgeyi savunmaya ve bounding'e bagla, mis gibi yer varsa manga orayi kullansin').
 * Komutan karari HOLD iken (fnc_tactics) cagrilir: [grup, hedef] call FUNC(savunmaYerlesim) -> Baslatildi mi <BOOL>
 *
 * KURAL: fnc_avantajliYer ("SAVUNMA": tam halka 120 m, atis alani kapsami zorunlu, yukseklik, koy / ev kumesi, sert nesne, ufuk cizgisi cezasi, esik 45 + merkezden >= 15 iyi) ile 'mis gibi' bir yer bulunursa
 *   manga o yere yerlesir: her asker yerin etrafinda dusman yonune DIK bir hatta 5 m arayla dizilir (en sol -> en sag, lider ortada); yurume 'NORMAL' hiz, forceMove + taktikKilit 35 sn;
 *   >= %70'i 8 m icine varinca ya da 40 sn sonra kilitler birakilir, grup yonu dusmana cevrilir, standart temas katmanlari (siper yapisma / duruş disiplini / sektor bakisi) devralir.
 * ATLANIR (hicbiri): grup < 3 asker, oyuncu liderli, retreat / evade / temas kes / bounding / supurme / pusu / soyma / sniper takimi, mevzi / hendek, LAMBS gorevi / 'TUTAN' waypoint, binada (savunma binada ayri),
 *   dusman < 45 m (CQB / dovus), grup baskisi ortalama >= 0.4, cooldown 180 sn (yer bulunamazsa 60 sn). v8.677: dusman 45-120 m ise YAKIN kip (35 m, esik 38, ates-manevra 2 dalga, cooldown 90 sn); fnc_tactics HOLD + DELAY kararindan cagrilir.
 * CBA: lambs_danger_avantajBagla (acik / kapali; savunma + bounding). Log: [SAVUNMA-YER] (ilk 15).
 *
 * Arguments:
 * 0: Grup <GROUP>
 * 1: Hedef (dusman konumu / nesne) <OBJECT veya ARRAY>
 *
 * Return Value: Yerlesme baslatildi mi <BOOL>
 * Public: No
*/

params [["_group", grpNull, [grpNull]], ["_target", [], [[], objNull]]];
if (isNull _group || {!local _group} || {!(missionNamespace getVariable ["lambs_danger_avantajBagla", true])} || {!(missionNamespace getVariable ["lambs_danger_avantajliYer", true])}) exitWith {false};
private _l = leader _group;
if (isNull _l || {isPlayer _l} || {(count (units _group)) < 3}) exitWith {false};
if (time < (_group getVariable [QGVAR(savunmaYerT), 0])) exitWith {false};
if (
    (_group getVariable [QGVAR(isRetreating), false]) || {_group getVariable [QGVAR(isEvading), false]} || {_group getVariable [QGVAR(isBreakingContact), false]}
    || {_group getVariable [QGVAR(isBounding), false]} || {_group getVariable [QGVAR(isSweeping), false]} || {_group getVariable [QGVAR(isAmbushing), false]}
    || {_group getVariable [QGVAR(isPeeling), false]} || {_group getVariable [QGVAR(sniperTeam), false]} || {[_group] call FUNC(mevziDeMi)} || {[_group] call FUNC(mevziTutMu)}
    || {([_group] call FUNC(wpSahip)) in ["LAMBS", "TUTAN"]}
) exitWith {false};

private _tPos = _target call CBA_fnc_getPos;
if ((count _tPos) < 2 || {_tPos isEqualTo [0, 0, 0]}) exitWith {false};
private _lPos = getPosATL _l;
// v8.677 YAKIN TEMAS KIPI (kullanici: 'yakin temas'; Altis RPT aa324317: temas 24-100 m, savunma yerlesimi >= 120 m sarti yuzunden hic tetiklenmedi; CQB katmanlari < 32 m, arada bosluk): dusman 45-120 m ise 'YAKIN':
//   35 m icinde (esik 38, merkezden >= 12 iyi, dusmana >= 40 m) en iyi yere ATES-MANEVRA ile gecis: asker ikiye bolunur, yere YAKIN ilk yarisi kosar, ikinci yarisi yerinde ates eder; ilk yari varinca (en cok 10 sn) ikinci yari kosar.
//   Dusman < 45 m: tasinmaz (CQB / dovus). Uzak kip (>= 120 m) ayni: tam ekip, 120 m, esik 45.
private _ed = _lPos distance2D _tPos;
if (_ed < 45 || {(insideBuilding _l) > 0.5}) exitWith {false};
private _yakin = _ed < 120;
private _us = (units _group) select {alive _x && {isNull objectParent _x} && {!isPlayer _x} && {(lifeState _x) in ["HEALTHY", "INJURED"]} && {!captive _x}};
if ((count _us) < 3) exitWith {false};
private _bsk = 0;
{ _bsk = _bsk + (getSuppression _x); } forEach _us;
if ((_bsk / (count _us)) >= 0.4) exitWith {false};

private _yer = if (_yakin) then { [_lPos, _tPos, 35, "YAKIN", 38, 12] call FUNC(avantajliYer) } else { [_lPos, _tPos, 120, "SAVUNMA"] call FUNC(avantajliYer) };
if (_yer isEqualTo []) exitWith { _group setVariable [QGVAR(savunmaYerT), time + ([60, 30] select _yakin)]; false };

_group setVariable [QGVAR(savunmaYerT), time + ([180, 90] select _yakin)];
private _yp = _yer select 0;
private _dirT = _yp getDir _tPos;
if ((missionNamespace getVariable ["lambs_danger_savunmaYerLogN", 0]) < 15) then {
    missionNamespace setVariable ["lambs_danger_savunmaYerLogN", (missionNamespace getVariable ["lambs_danger_savunmaYerLogN", 0]) + 1];
    diag_log format ["[SAVUNMA-YER] %1 | %2 | %3 asker | liderden %4 m, dusmana %5 m | %6", groupId _group, ["UZAK", "YAKIN (ates-manevra, 2 dalga)"] select _yakin, count _us, round (_lPos distance2D _yp), round (_yp distance2D _tPos), _yer select 2];
};

[_group, _us, _yp, _dirT, _tPos, _yakin] spawn {
    params ["_g", "_us", "_yp", "_dirT", "_tPos", "_yakin"];
    // dusman yonune dik hat: en sol -> en sag; konum = yer + yanal sapma
    private _n = count _us;
    private _atanan = [];
    {
        private _off = ((_forEachIndex - ((_n - 1) / 2)) * 5);
        private _pt = _yp getPos [abs _off, _dirT + ([90, -90] select (_off < 0))];
        if (surfaceIsWater _pt) then { _pt = _yp; };
        _atanan pushBack [_x, _pt];
    } forEach _us;
    // YAKIN kip: yere yakin ilk yari kosar (w1), diger yari yerinde ates eder (w2); w1 varinca w2 kosar
    private _w1 = _atanan;
    private _w2 = [];
    if (_yakin && {_n >= 4}) then {
        private _srt = _atanan apply { [((_x select 0) distance2D _yp) + (random 0.01), _x] };
        _srt sort true;
        private _k = ceil (_n / 2);
        _w1 = (_srt select [0, _k]) apply { _x select 1 };
        _w2 = (_srt select [_k, _n]) apply { _x select 1 };
    };
    private _hareket = {
        params ["_lst", "_kilit"];
        {
            _x params ["_u", "_pt"];
            if (alive _u) then {
                _u setVariable [QGVAR(forceMove), true];
                _u setVariable [QGVAR(taktikKilit), time + _kilit];
                _u forceSpeed -1;
                _u setSpeedMode (["NORMAL", "FULL"] select _yakin);
                _u doMove _pt;
            };
        } forEach _lst;
    };
    private _vardi = {
        params ["_lst"];
        ({alive (_x select 0) && {((_x select 0) distance2D (_x select 1)) <= 8}} count _lst) >= (ceil (0.7 * ({alive (_x select 0)} count _lst)))
    };
    // beklemedeki yari (w2) yerinde kalir + ates eder: kilit (siper / bekleme katmanlari oynatmasin)
    { (_x select 0) setVariable [QGVAR(taktikKilit), time + 14]; } forEach _w2;
    [_w1, [35, 14] select (_w2 isNotEqualTo [])] call _hareket;
    private _bit1 = time + ([40, 10] select (_w2 isNotEqualTo []));
    waitUntil { sleep 0.5; isNull _g || {time > _bit1} || {[_w1] call _vardi} };
    if (_w2 isNotEqualTo []) then {
        [_w2, 20] call _hareket;
        private _bit2 = time + 12;
        waitUntil { sleep 0.5; isNull _g || {time > _bit2} || {[_w2] call _vardi} };
    };
    {
        _x params ["_u", "_pt"];
        if (alive _u) then {
            _u setVariable [QGVAR(forceMove), nil];
            _u setVariable [QGVAR(taktikKilit), nil];
            _u doWatch (_u getPos [100, _dirT]);
        };
    } forEach _atanan;
    if (!isNull _g) then { _g setFormDir _dirT; };
};
true
