#include "script_component.hpp"
/*
 * Author: Cinar (ELITE fork)
 * YER GOZLEMCISI: LIDER HAKIM NOKTAYA CIKAR (v8.342; kullanici: 'lider hakim noktaya cikarken ev ustlerine merdivenlerden cikabiliyorsa ya da etrafi / savunma yonunu goren bir bolgeye ciksin'). fnc_dronTopcu her taraf icin 20 sn'de bir cagirir.
 * Ne zaman: gozlemci (dron ya da gorus hatti acik lider) YOKKEN ve tarafin topcusu varken, gorev (gozlemli atis) kilidi yokken, taraf basina 120 sn'de bir:
 *   HEDEF  1) tarafin su an bildigi dusman kumesi (lambs_danger_dtGuncel_<taraf>), 2) 180 sn'den taze temas bellegi kaydi, 3) savunma planinda (tip 1, faz MEVZI / BEKLE) tehdit yonu (tehditB >= 0): objektiften 700 m o yonde.
 *   LIDER  tarafin yerel AI grup lideri (yaya, saglikli, temassiz, geri cekilmiyor, TOPCU / MEDEVAC / HARIC / RECON gorevinde degil), hedefe 300-2500 m; ONCE plansiz (musait) gruplar, sonra plandakiler; en yakin 3 lider denenir.
 *   NOKTA  fnc_topcuHakim: ev ust kati / cati (buildingPos >= 3 m, merdivenle) ya da arazi; hedefi goren, 8 yonde acik gorusu iyi nokta; yuruyus <= 450 m.
 *   HAREKET plansiz grup: TUM grup (forceMove, AWARE); plandaki grup: yalniz LIDER gider (grup mevzisinde kalir; plan bozulmaz).
 * Varista lider durur, hedefe bakar; 'gorus hatti acik' ise fnc_dronTopcu onu yer gozlemcisi (FO) olarak kullanir (cagri -> adjust -> FFE). Bitis: 420 sn, varistan 240 sn sonra, lider olur / temasa girer / geri cekilir;
 * gorev (gozlemli atis) surerken sure uzar. Bitince lider eski yerine doner, bayraklar temizlenir.
 * Kapatma: CBA 'foHakimAktif' / lambs_danger_foHakimOff = true. Log: [FO-HAKIM].
 *
 * Arguments:
 * 0: Taraf <SIDE>
 * 1: Su an gozlemci var mi (gorus hatti acik FO ya da dron) <BOOL>
 *
 * Return Value: Yeni atama yapildi mi <BOOL>
 * Public: No
*/

params [["_taraf", sideUnknown, [sideUnknown]], ["_foVar", false, [false]]];
if (!(missionNamespace getVariable ["lambs_danger_foHakimAktif", true]) || {missionNamespace getVariable ["lambs_danger_foHakimOff", false]}) exitWith {false};

private _k = format ["lambs_danger_foGorev_%1", _taraf];
private _st = missionNamespace getVariable [_k, []];
private _kilitli = time < (missionNamespace getVariable [format ["lambs_danger_dtKilit_%1", _taraf], 0]);

// ---------- yurutme ----------
if (_st isNotEqualTo []) exitWith {
    _st params ["_g", "_l", "_pos", "_tip", "_hedef", "_t0", "_durum", "_tV", "_planli", "_org"];
    private _bit = "";
    if (isNull _g || {!alive _l}) then { _bit = "lider yok / olu"; };
    if (_bit isEqualTo "" && {!((lifeState _l) in ["HEALTHY", "INJURED"])}) then { _bit = "lider yarali"; };
    if (_bit isEqualTo "" && {(time - _t0) > 420}) then { _bit = "sure (420 sn)"; };
    if (_bit isEqualTo "" && {(_g getVariable [QGVAR(contact), 0]) > time} && {(_g getVariable [QGVAR(cmdSit), []]) isEqualType []} && {count (_g getVariable [QGVAR(cmdSit), []]) > 1} && {((_g getVariable [QGVAR(cmdSit), []]) select 1) < 200}) then { _bit = "temas (dusman < 200 m)"; };
    if (_bit isEqualTo "" && {(_g getVariable [QGVAR(isRetreating), false]) || {_g getVariable [QGVAR(isBreakingContact), false]}}) then { _bit = "grup cekiliyor"; };
    if (_bit isEqualTo "") then {
        if (_durum isEqualTo "YOLDA") then {
            if ((_l distance2D _pos) < 18 || {(time - _t0) > 240}) then {
                _st set [6, "BEKLE"];
                _st set [7, time];
                _l doWatch _hedef;
                doStop _l;
                (format ["[FO-HAKIM] %1 | %2 lideri %3 gozlem noktasinda (%4 m'de, %5 sn): %6 | hedefe %7 m", _taraf, groupId _g, name _l, round (_l distance2D _pos), round (time - _t0), _tip, round (_l distance2D _hedef)]) call {diag_log _this};
            } else {
                if ((speed _l) < 0.5 && {(time - (_g getVariable [QGVAR(foYenidenT), 0])) > 20}) then { _g setVariable [QGVAR(foYenidenT), time]; _l doMove _pos; };
            };
        } else {
            if (_kilitli) then { _st set [7, time]; };
            if ((time - _tV) > 240) then { _bit = "gozlem suresi doldu"; };
        };
    };
    if (_bit isNotEqualTo "") then {
        { if (alive _x) then { _x setVariable [QGVAR(forceMove), nil]; _x setVariable [QGVAR(destekAsker), nil]; _x doWatch objNull; if (_x isNotEqualTo _l) then { _x doFollow _l; }; }; } forEach (units _g);
        if (!isNull _g && {!_planli}) then { _g setVariable [QGVAR(isExecutingTactic), nil]; };
        if (alive _l) then { _l doMove _org; };
        missionNamespace setVariable [_k, []];
        missionNamespace setVariable [format ["lambs_danger_foGorevT_%1", _taraf], time];
        diag_log format ["[FO-HAKIM] %1 | %2 gorevi BITTI: %3 (%4 sn)", _taraf, groupId _g, _bit, round (time - _t0)];
    };
    false
};

// ---------- yeni atama ----------
if (_foVar || {_kilitli}) exitWith {false};
if ((time - (missionNamespace getVariable [format ["lambs_danger_foGorevT_%1", _taraf], -999])) < 120) exitWith {false};

private _hedef = [];
private _kaynak = "";
private _guncel = missionNamespace getVariable [format ["lambs_danger_dtGuncel_%1", _taraf], []];
if (_guncel isNotEqualTo []) then { _hedef = (_guncel select 0) select 0; _kaynak = "bilinen dusman kumesi"; };
if (_hedef isEqualTo []) then {
    private _bel = (missionNamespace getVariable [format ["lambs_danger_dtBellek_%1", _taraf], []]) select {(time - (_x select 1)) < 180};
    if (_bel isNotEqualTo []) then { _hedef = (([_bel, [], {_x select 2}, "DESCEND"] call BIS_fnc_sortBy) select 0) select 0; _kaynak = "taze temas kaydi (<180 sn)"; };
};
private _planObj = [];
if (_hedef isEqualTo []) then {
    private _pl = (values (missionNamespace getVariable ["lambs_danger_planlar", createHashMap])) select {
        (_x get "taraf") isEqualTo _taraf && {(_x getOrDefault ["tip", 0]) isEqualTo 1} && {(_x getOrDefault ["faz", ""]) in ["MEVZI", "BEKLE"]} && {(_x getOrDefault ["tehditB", -1]) >= 0}
    };
    if (_pl isNotEqualTo []) then {
        private _p = _pl select 0;
        _hedef = (_p get "obj") getPos [700, _p get "tehditB"];
        _kaynak = format ["savunma yonu (tehdit %1 derece)", _p get "tehditB"];
    };
};
if (_hedef isEqualTo []) exitWith {false};

private _haric = ["TOPCU", "TOPCU_YOK", "MEDEVAC", "HARIC", "RECON", "RECON_ARAC", "KARAKOL_ARAC", "TASIMA"];
private _adaylar = allGroups select {
    private _lg = leader _x;
    (side _x) isEqualTo _taraf && {local _x} && {!isNull _lg} && {alive _lg} && {!isPlayer _lg} && {isNull objectParent _lg} && {(lifeState _lg) in ["HEALTHY", "INJURED"]}
    && {({isPlayer _x} count (units _x)) isEqualTo 0} && {(_x getVariable [QGVAR(contact), 0]) <= time}
    && {!((_x getVariable ["lambs_danger_gorev", ""]) in _haric)} && {(_x getVariable ["lambs_danger_garnizonAlt", ""]) isEqualTo ""}
    && {!(_x getVariable [QGVAR(isRetreating), false])} && {!(_x getVariable [QGVAR(isBreakingContact), false])} && {!(_x getVariable [QGVAR(isSonDirenis), false])}
    && {((_lg distance2D _hedef) >= 300) && {(_lg distance2D _hedef) <= 2500}}
};
if (_adaylar isEqualTo []) exitWith {false};
// once plansiz (musait) gruplar, sonra plandakiler; hedefe yakin olan once
_adaylar = [_adaylar, [], { ((_x getVariable ["lambs_danger_planAktif", false]) call {[0, 100000] select _this}) + ((leader _x) distance2D _hedef) }, "ASCEND"] call BIS_fnc_sortBy;

private _atandi = false;
{
    if (!_atandi) then {
        private _g = _x;
        private _l = leader _g;
        private _sonuc = [getPosATL _l, _hedef, 450] call FUNC(topcuHakim);
        if (_sonuc isNotEqualTo []) then {
            _atandi = true;
            _sonuc params ["_pos", "_tip", "_skor", "_z"];
            private _planli = _g getVariable ["lambs_danger_planAktif", false];
            private _org = getPosATL _l;
            missionNamespace setVariable [_k, [_g, _l, _pos, _tip, _hedef, time, "YOLDA", time, _planli, _org]];
            if (_planli) then {
                _l setVariable [QGVAR(forceMove), true];
                _l doMove _pos;
            } else {
                _g setVariable [QGVAR(isExecutingTactic), true];
                _g setBehaviour "AWARE";
                {
                    if (alive _x && {isNull objectParent _x} && {!isPlayer _x} && {(lifeState _x) in ["HEALTHY", "INJURED"]} && {!(time < (_x getVariable [QGVAR(tcccBusy), 0]))}) then {
                        _x setVariable [QGVAR(forceMove), true];
                        _x doMove (_pos getPos [[0, 5] select (_x isNotEqualTo _l), random 360]);
                    };
                } forEach (units _g);
            };
            diag_log format ["[FO-HAKIM] %1 | %2 lideri %3 -> %4 %5 (%6, yukseklik +%7 m, skor %8) | yuruyus %9 m | hedef %10 (%11 m) | kaynak: %12 | %13", _taraf, groupId _g, name _l, _tip, mapGridPosition _pos,
                ["arazi", "bina ust kat / cati"] select (_tip isEqualTo "BINA"), round _z, round _skor, round (_l distance2D _pos), mapGridPosition _hedef, round (_l distance2D _hedef), _kaynak, ["TUM GRUP gider", "yalniz LIDER gider (plan mevzisi bozulmaz)"] select _planli];
        };
    };
} forEach (_adaylar select [0, 3]);
if (!_atandi) then { missionNamespace setVariable [format ["lambs_danger_foGorevT_%1", _taraf], time - 60]; };
_atandi
