#include "script_component.hpp"
/*
 * Author: Cinar (ELITE fork)
 * KARA ARACI ILE PIYADE NAKLI / TAKSI (v8.129) — kullanici: "apc ler medevac ve transport icin kullanilsin ama cephenin dibine gotürmesin, doktrinler ne diyorsa; transport araclari da eklensin (kara)".
 * GENEL KULLANIM (taksi): fnc_taksi bekcisi herhangi bir AI grubu icin cagirir; plan icin de ayni fonksiyon kullanilir.
 * Komutan plani (fnc_komutanPlanDongu) TOPLAN fazinda RP'de toplanan gruplari, uygun kara araclariyla (APC / IFV / kamyon) INIS NOKTASINA tasir; piyade orada iner ve plan ORP'ye yuruyerek devam eder.
 *
 * DOKTRIN / KAYNAK: nakliye araci objektife (duşmana) YAKLASTIRILMAZ; piyade ORP'den once, tüfek etkili menzilinin DISINDA iner (M16 460 m: MCWP 3-11.2; ORP 200-400 m: TC 3-21.76 s. 7-15).
 *   Inis noktasi: objektiften max (500 m, ORP mesafesi + 150 m) yaklasma ekseninde (500 m = M16 etkili menzili 460 m + pay; kitapta "inis mesafesi" sayisi YOK -> TASARIM).
 *   Arac inip RP'ye (geriye) doner ve bekler; cephe hattina girmez.
 * ARAC ADAYI: ayni taraf, kara araci, canMove, yakit > %10, surucu AI + yerel, arac grubu TAMAMEN aracin icinde, planda / medevac gorevinde degil, RP'ye <= 2500 m, kargo yeri >= 3.
 *   Zeus 'ELITE Gorev Ata' TASIMA atanan araclar once; hic atanmis yoksa ve lambs_danger_tasimaOtomatik != false ise yukaridaki sartlara uyan araclar otomatik secilir.
 *   HARIC / MEDEVAC / TOPCU atanan araclar kullanilmaz.
 * ADIMLAR: (1) arac RP'ye gelir (<= 45 m, en fazla 120 sn) (2) grup araca biner (orderGetIn; 45 sn sonra 40 m icinde kalanlar moveInCargo ile) (3) arac inis noktasina surer;
 *   temas baslarsa (binen grup son 5 sn temas) ya da inis noktasi yakininda (< 40 m) / 300 sn dolunca DUR (4) piyade iner (unassign + doGetOut; 10 sn sonra moveOut) (5) arac RP'ye doner, doStop.
 * Sigmayan gruplar yuruyerek devam eder. Log: [TASIMA]. Kapatma: lambs_danger_tasimaOff = true.
 *
 * Arguments:
 * 0: Taraf <SIDE>
 * 1: Plan gruplari <ARRAY of GROUP>
 * 2: RP <ARRAY>
 * 3: Objektif <ARRAY>
 * 4: Yaklasma ekseni (objektiften dost gruplara yon) <NUMBER>
 * 5: ORP mesafesi (m) <NUMBER> (taksi: 0)
 * 6: Arac arama menzili (m, varsayilan 2500; taksi: 600) <NUMBER>
 * 7: Kontrol dizisi [iptal <BOOL>] (true olunca is derhal biter, binenler oldugu yerde iner) <ARRAY>
 *
 * Return Value: Tasinan grup sayisi <NUMBER>
 * Public: No
*/

params ["_taraf", "_gruplar", "_rp", "_obj", "_B", "_orpM", ["_menzil", 2500], ["_ctl", [false]]];
if (missionNamespace getVariable ["lambs_danger_tasimaOff", false]) exitWith {0};


// ---- arac adaylari ----
private _tumAraclar = (vehicles select {
    alive _x && {_x isKindOf "LandVehicle"} && {canMove _x} && {(fuel _x) > 0.1}
    && {(_x emptyPositions "cargo") >= 3}
    && {(_x distance2D _rp) <= _menzil}
});
private _uygun = _tumAraclar select {
    private _v = _x;
    private _d = driver _v;
    private _vg = group _d;
    !isNull _d && {!isPlayer _d} && {local _d} && {(side _vg) isEqualTo _taraf}
    && {((units _vg) findIf {alive _x && {(vehicle _x) isNotEqualTo _v}}) isEqualTo -1}
    && {!(_vg getVariable [QGVAR(planAktif), false])} && {(time - (_vg getVariable [QGVAR(aracMedevacT), -999])) > 240}
    && {!(((_v getVariable ["lambs_danger_gorev", ""]) in ["HARIC", "MEDEVAC", "TOPCU", "TOPCU_YOK", "KARAKOL_ARAC"]) || {((_vg getVariable ["lambs_danger_gorev", ""]) in ["HARIC", "MEDEVAC", "TOPCU", "TOPCU_YOK", "KARAKOL_ARAC"])})}
    && {(({isPlayer _x} count (crew _v)) isEqualTo 0)} && {!(_v getVariable [QGVAR(tasimaMesgul), false])}
};
private _atanan = _uygun select {((_x getVariable ["lambs_danger_gorev", ""]) isEqualTo "TASIMA") || {((group (driver _x)) getVariable ["lambs_danger_gorev", ""]) isEqualTo "TASIMA"}};
private _araclar = if (_atanan isNotEqualTo []) then {_atanan} else {
    if (missionNamespace getVariable ["lambs_danger_tasimaOtomatik", true]) then {_uygun} else {[]}
};
if (_araclar isEqualTo []) exitWith {0};
_araclar = [_araclar, [], {_x distance2D _rp}, "ASCEND"] call BIS_fnc_sortBy;

// ---- grup -> arac eslesmesi (grup tamami sigmali) ----
private _kalan = _araclar apply {[_x, _x emptyPositions "cargo"]};
private _eslesme = [];   // [arac, [gruplar]]
private _yaya = [];
{
    private _g = _x;
    private _n = {alive _x && {isNull objectParent _x}} count (units _g);
    private _i = _kalan findIf {(_x select 1) >= _n};
    if (_i < 0) then { _yaya pushBack _g; continue };
    (_kalan select _i) set [1, ((_kalan select _i) select 1) - _n];
    private _v = (_kalan select _i) select 0;
    private _e = _eslesme findIf {(_x select 0) isEqualTo _v};
    if (_e < 0) then { _eslesme pushBack [_v, [_g]]; } else { ((_eslesme select _e) select 1) pushBack _g; };
} forEach _gruplar;
if (_eslesme isEqualTo []) exitWith {
    diag_log format ["[TASIMA] %1 | arac var (%2) ama hicbir grup sigmadi -> yuruyerek", _taraf, count _araclar];
    0
};

private _dropM = (500 max (_orpM + 150));
private _drop = _obj getPos [_dropM, _B];
if (surfaceIsWater _drop) then { _drop = _obj getPos [(_dropM + 100), _B]; };
private _nG = 0;
{ _nG = _nG + count (_x select 1); } forEach _eslesme;
diag_log format ["[TASIMA] %1 | %2 arac / %3 grup eslesti (yaya: %4) | inis noktasi %5 (hedeften %6 m) | atanmis arac: %7",
    _taraf, count _eslesme, _nG, count _yaya, mapGridPosition _drop, round _dropM, count _atanan];

private _tasinan = 0;
private _isler = [];
{
    _x params ["_v", "_gl"];
    private _d = driver _v;
    private _vg = group _d;
    _isler pushBack ([_v, _d, _vg, _gl, _rp, _drop, _ctl] spawn {
        params ["_v", "_d", "_vg", "_gl", "_rp", "_drop", "_ctl"];
        _v setVariable [QGVAR(tasimaMesgul), true];
        _v setVariable [QGVAR(aracMedevacT), time];
        private _eskiBeh = behaviour _d;
        private _eskiHiz = speedMode _vg;
        private _eskiAC = _d checkAIFeature "AUTOCOMBAT";
        _vg setVariable [QGVAR(aracMedevacT), time];   // medevac / diger arac gorevleri 240 sn almasin
        _vg setVariable [QGVAR(isExecutingTactic), true];
        _d setVariable [QGVAR(forceMove), true];
        _vg setBehaviour "AWARE";
        _vg setSpeedMode "NORMAL";
        _d disableAI "AUTOCOMBAT";
        private _ad = getText (configOf _v >> "displayName");
        private _iptal = "";

        // (1) RP'ye gel
        diag_log format ["[TASIMA] %1 | %2 | alma noktasina %3 m (RP) | surucu %4", groupId _vg, _ad, round (_v distance2D _rp), name _d];
        _d doMove _rp;
        private _t = time + 150;
        waitUntil { sleep 1; !alive _v || {!alive _d} || {(_v distance2D _rp) < 45} || {time > _t} || {_ctl select 0} };
        if (!alive _v || {!alive _d}) then { _iptal = "arac / surucu oldu"; };
        if (_iptal isEqualTo "" && {_ctl select 0}) then { _iptal = "plan zaman asimi (iptal)"; };
        if (_iptal isEqualTo "" && {(_v distance2D _rp) >= 45}) then { _iptal = format ["RP'ye varilamadi (150 sn, kalan %1 m)", round (_v distance2D _rp)]; };

        // (2) bin
        private _binen = [];
        if (_iptal isEqualTo "") then {
            doStop _d;
            private _hepsi = [];
            { _hepsi append ((units _x) select {alive _x && {isNull objectParent _x}}); } forEach _gl;
            { _x assignAsCargo _v; } forEach _hepsi;
            _hepsi orderGetIn true;
            private _bt = time + 60;
            waitUntil {
                sleep 1;
                !alive _v || {_ctl select 0} || {(_hepsi findIf {alive _x && {(vehicle _x) isNotEqualTo _v}}) isEqualTo -1} || {time > _bt}
                || {(time > (_bt - 15)) && {((_hepsi select {alive _x && {(vehicle _x) isEqualTo _v}}) isEqualTo []) isEqualTo false}}
            };
            // gecikenler: 40 m icindeyse arac icine al
            { if (alive _x && {(vehicle _x) isNotEqualTo _v} && {(_x distance2D _v) < 40} && {(_v emptyPositions "cargo") > 0}) then { _x moveInCargo _v; }; } forEach _hepsi;
            _binen = _hepsi select {alive _x && {(vehicle _x) isEqualTo _v}};
            if (_binen isEqualTo []) then { _iptal = "kimse binmedi"; };
        };

        // (3) inis noktasina sur
        private _erkenInis = "";
        if (_iptal isEqualTo "") then {
            diag_log format ["[TASIMA] %1 | BINDI %2 asker -> inis noktasina %3 m | %4", groupId _vg, count _binen, round (_v distance2D _drop), _ad];
            _d doMove _drop;
            private _st = time + 240;
            waitUntil {
                sleep 1;
                !alive _v || {!alive _d} || {(_v distance2D _drop) < 40} || {time > _st}
                || {(_gl findIf {(time - (_x getVariable [QGVAR(contact), -999])) < 5}) >= 0}
                || {(getSuppression _d) > 0.5} || {_ctl select 0}
            };
            if (!alive _v || {!alive _d}) then { _iptal = "tasima sirasinda arac / surucu oldu"; };
            if (_iptal isEqualTo "") then {
                if ((_v distance2D _drop) >= 40) then {
                    _erkenInis = [format ["temas / baski (inise %1 m kala)", round (_v distance2D _drop)], "sure doldu (240 sn)"] select (time > _st);
                };
            };
        };

        // (4) in
        doStop _d;
        {
            if (alive _x && {(vehicle _x) isEqualTo _v} && {_x isNotEqualTo _d}) then { unassignVehicle _x; doGetOut _x; };
        } forEach _binen;
        sleep 10;
        { if (alive _x && {(vehicle _x) isEqualTo _v} && {_x isNotEqualTo _d}) then { moveOut _x; }; } forEach _binen;
        { if (alive _x) then { _x doFollow (leader (group _x)); }; } forEach _binen;
        diag_log format ["[TASIMA] %1 | %2 | inen %3 / %4%5", groupId _vg, ["TAMAM", "IPTAL: " + _iptal] select (_iptal isNotEqualTo ""), {alive _x && {(vehicle _x) isNotEqualTo _v}} count _binen, count _binen, ["", " | erken inis: " + _erkenInis] select (_erkenInis isNotEqualTo "")];

        // (5) RP'ye don, bekle
        if (alive _v && {alive _d}) then {
            _d doMove _rp;
            private _bt2 = time + 150;
            waitUntil { sleep 2; !alive _v || {(_v distance2D _rp) < 50} || {time > _bt2} };
            if (alive _d) then { doStop _d; };
        };
        if (!isNull _vg) then {
            _vg setVariable [QGVAR(isExecutingTactic), nil];
            _vg setBehaviour _eskiBeh;
            _vg setSpeedMode _eskiHiz;
            _vg setVariable [QGVAR(aracMedevacT), time];
        };
        if (alive _d) then {
            _d setVariable [QGVAR(forceMove), nil];
            if (_eskiAC) then { _d enableAI "AUTOCOMBAT"; };
        };
        _v setVariable [QGVAR(tasimaMesgul), nil];
        count _binen
    });
    _tasinan = _tasinan + count _gl;
} forEach _eslesme;

waitUntil { sleep 2; (_isler findIf {!scriptDone _x}) isEqualTo -1 };
_tasinan
