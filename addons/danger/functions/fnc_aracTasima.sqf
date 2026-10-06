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
 * 7: Kontrol dizisi [iptal <BOOL>, hazir <BOOL>] (iptal: is derhal biter, binenler oldugu yerde iner; hazir: gruplar toplandi, araclar RP'de beklemeyi birakip bindirir; varsayilan [false, true]) <ARRAY>
 *
 * Return Value: Tasinan grup sayisi <NUMBER>
 * Public: No
*/

params ["_taraf", "_gruplar", "_rp", "_obj", "_B", "_orpM", ["_menzil", 2500], ["_ctl", [false, true, 0]]];
if (missionNamespace getVariable ["lambs_danger_tasimaOff", false]) exitWith {0};


// ---- arac adaylari ----
// v8.133: arac araniyor yeri = tasinacak piyadenin AGIRLIK MERKEZI (RP degil): RPT 7f357bf1'de arac + piyade RP'ye 2580 m uzaktaydi, 2500 m sinirina takilip sessizce is yapilmadi
private _merkezPiy = {
    private _l = (_gruplar apply {getPosATL (leader _x)}) select {_x isNotEqualTo [0,0,0]};
    if (_l isEqualTo []) then {_rp} else {
        private _sx = 0; private _sy = 0;
        { _sx = _sx + (_x select 0); _sy = _sy + (_x select 1); } forEach _l;
        [_sx / (count _l), _sy / (count _l), 0]
    }
};
private _pickRef = call _merkezPiy;
private _tumAraclar = (vehicles select {
    alive _x && {_x isKindOf "LandVehicle"} && {canMove _x} && {(fuel _x) > 0.1}
    && {(_x emptyPositions "cargo") >= 3}
    && {(_x distance2D _pickRef) <= _menzil}
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
if (_araclar isEqualTo []) exitWith {
    diag_log format ["[TASIMA] %1 | arac YOK: kara araci(kargo>=3) %2 | menzilde %3 (<= %4 m) | uygun (AI surucu, grup ici, gorev disi) %5 | atanmis TASIMA %6", _taraf,
        count (vehicles select {alive _x && {_x isKindOf "LandVehicle"} && {(_x emptyPositions "cargo") >= 3}}), count _tumAraclar, round _menzil, count _uygun, count _atanan];
    0
};
_araclar = [_araclar, [], {_x distance2D _rp}, "ASCEND"] call BIS_fnc_sortBy;

// ---- v8.131 MEDEVAC REZERVI: Zeus MEDEVAC atamasi yoksa ve >= 2 arac varsa objektiften en uzak (geride) arac medevac icin ayrilir (nakilde kullanilmaz) ----
private _mdVarMi = (_tumAraclar select {("MEDEVAC" in [_x getVariable ["lambs_danger_gorev", ""], (group (driver _x)) getVariable ["lambs_danger_gorev", ""]])}) isNotEqualTo [];
if (count _araclar > 1 && {!_mdVarMi} && {missionNamespace getVariable ["lambs_danger_tasimaMedevacRezerv", true]}) then {
    private _uz = [_araclar, [], {_x distance2D _obj}, "DESCEND"] call BIS_fnc_sortBy;
    private _rez = _uz select 0;
    _rez setVariable ["lambs_danger_medevacRezerv", true, true];
    _araclar = _araclar - [_rez];
    diag_log format ["[TASIMA] %1 | MEDEVAC REZERVI: %2 (%3 m geride) nakilde kullanilmayacak", _taraf, getText (configOf _rez >> "displayName"), round (_rez distance2D _obj)];
};

// ---- birim -> arac eslesmesi: once grup TAMAMI, sigmazsa TAKIM BAZLI (FSE / Maneuver / Reserve; ayni takim ayni araca) ----
private _dropM = (500 max (_orpM + 150));
private _kalan = _araclar apply {[_x, _x emptyPositions "cargo"]};
private _eslesme = [];   // [arac, [birim dizileri]]
private _yaya = [];
private _bolunen = [];
private _yerlestir = {
    params ["_birimler", "_ad"];
    private _n = count _birimler;
    private _i = _kalan findIf {(_x select 1) >= _n};
    if (_i < 0) exitWith { false };
    (_kalan select _i) set [1, ((_kalan select _i) select 1) - _n];
    private _v = (_kalan select _i) select 0;
    private _e = _eslesme findIf {(_x select 0) isEqualTo _v};
    if (_e < 0) then { _eslesme pushBack [_v, [_birimler]]; } else { ((_eslesme select _e) select 1) pushBack _birimler; };
    true
};
{
    private _g = _x;
    private _on = (units _g) select {alive _x && {isNull objectParent _x}};
    if (_on isEqualTo []) then { continue };
    if (((leader _g) distance2D _obj) < (_dropM + 150)) then { continue };   // zaten inis noktasina yakin: nakil gerekmez
    if ([_on, groupId _g] call _yerlestir) then { continue };
    // sigmadi: takim bazli bol
    private _takimlar = ([_g] call FUNC(splitFireTeams)) select {_x isNotEqualTo []};
    _takimlar = [_takimlar, [], {count _x}, "DESCEND"] call BIS_fnc_sortBy;
    private _yerlesen = 0;
    {
        if ([_x, groupId _g] call _yerlestir) then { _yerlesen = _yerlesen + 1; } else { _yaya pushBack [_g, count _x]; };
    } forEach _takimlar;
    if (_yerlesen > 0) then { _bolunen pushBack format ["%1 (%2/%3 takim)", groupId _g, _yerlesen, count _takimlar]; };
} forEach _gruplar;
if (_eslesme isEqualTo []) exitWith {
    diag_log format ["[TASIMA] %1 | arac var (%2) ama hicbir takim sigmadi -> yuruyerek", _taraf, count _araclar];
    0
};

private _drop = _obj getPos [_dropM, _B];
if (surfaceIsWater _drop) then { _drop = _obj getPos [(_dropM + 100), _B]; };
private _nB = 0;
{ { _nB = _nB + count _x; } forEach (_x select 1); } forEach _eslesme;
_ctl set [2, _nB];   // plan: gercekten nakil yapiliyor (> 0) -> is bitince TOPLAN hazir sayilir
diag_log format ["[TASIMA] %1 | %2 arac / %3 asker eslesti | takim bazli bolunen: %4 | yaya kalan birim: %5 | inis noktasi %6 (hedeften %7 m) | atanmis arac: %8",
    _taraf, count _eslesme, _nB, _bolunen, count _yaya, mapGridPosition _drop, round _dropM, count _atanan];

// ---- v8.131 YIGILMA ONLEME: araclar ayni noktaya gitmesin; alma / inis noktasi yanal 24 m aralikla dagitilir ----
private _noktaYay = {
    params ["_nokta", "_i", "_n"];
    private _of = (_i - (_n - 1) / 2) * 24;
    private _p = _nokta getPos [abs _of, _B + ([90, -90] select (_of < 0))];
    if (surfaceIsWater _p) then { _p = _nokta; };
    _p
};

private _tasinan = 0;
private _isler = [];
{
    _x params ["_v", "_gl"];
    private _d = driver _v;
    private _vg = group _d;
    private _rpi = [_rp, _forEachIndex, count _eslesme] call _noktaYay;
    private _dropi = [_drop, _forEachIndex, count _eslesme] call _noktaYay;
    _isler pushBack ([_v, _d, _vg, _gl, _rpi, _dropi, _ctl] spawn {
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
        // v8.133 DINAMIK ALMA: arac tasinacak piyadenin ANLIK merkezine gider (piyade yurumeye devam etse bile takip eder); 60 m'ye gelince durur
        private _pickFn = {
            params ["_gl"];
            private _p = [];
            { _p append ((_x select {alive _x && {isNull objectParent _x}}) apply {getPosATL _x}); } forEach _gl;
            if (_p isEqualTo []) exitWith {[]};
            private _sx = 0; private _sy = 0;
            { _sx = _sx + (_x select 0); _sy = _sy + (_x select 1); } forEach _p;
            [_sx / (count _p), _sy / (count _p), 0]
        };
        private _pk = [_gl] call _pickFn;
        if (_pk isEqualTo []) then { _iptal = "tasinacak asker kalmadi"; } else {
            diag_log format ["[TASIMA] %1 | %2 | piyadeye gidiyor: %3 m | surucu %4", groupId _vg, _ad, round (_v distance2D _pk), name _d];
            _d doMove _pk;
            private _t = time + (150 max (((_v distance2D _pk) / 6) min 420));
            private _sonMove = time;
            waitUntil {
                sleep 1;
                _pk = [_gl] call _pickFn;
                if (_pk isNotEqualTo [] && {(time - _sonMove) > 4}) then { _d doMove _pk; _sonMove = time; };
                !alive _v || {!alive _d} || {_pk isEqualTo []} || {(_v distance2D _pk) < 60} || {time > _t} || {_ctl select 0}
            };
        };
        if (!alive _v || {!alive _d}) then { _iptal = "arac / surucu oldu"; };
        if (_iptal isEqualTo "" && {_ctl select 0}) then { _iptal = "plan zaman asimi (iptal)"; };
        if (_iptal isEqualTo "" && {_pk isEqualTo [] || {(_v distance2D _pk) >= 60}}) then { _iptal = format ["piyadeye varilamadi (kalan %1 m)", [round (_v distance2D _pk), -1] select (_pk isEqualTo [])]; };

        // (2) bin
        private _binen = [];
        if (_iptal isEqualTo "") then {
            doStop _d;
            // v8.132: piyade toplanana kadar (plan TOPLAN hazir) RP'de bekle (en fazla 600 sn)
            if !(_ctl select 1) then {
                diag_log format ["[TASIMA] %1 | %2 | RP'de, piyadenin toplanmasi bekleniyor", groupId _vg, _ad];
                private _wt = time + 600;
                waitUntil { sleep 2; !alive _v || {_ctl select 1} || {_ctl select 0} || {time > _wt} };
            };
            private _hepsi = [];
            { _hepsi append (_x select {alive _x && {isNull objectParent _x}}); } forEach _gl;
            { _x assignAsCargo _v; } forEach _hepsi;
            _hepsi orderGetIn true;
            private _bt = time + 90;
            waitUntil {
                sleep 1;
                !alive _v || {_ctl select 0} || {(_hepsi findIf {alive _x && {(vehicle _x) isNotEqualTo _v}}) isEqualTo -1} || {time > _bt}
                || {(time > (_bt - 15)) && {((_hepsi select {alive _x && {(vehicle _x) isEqualTo _v}}) isEqualTo []) isEqualTo false}}
            };
            // gecikenler: 40 m icindeyse arac icine al
            { if (alive _x && {(vehicle _x) isNotEqualTo _v} && {(_x distance2D _v) < 100} && {(_v emptyPositions "cargo") > 0}) then { _x moveInCargo _v; }; } forEach _hepsi;
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
                || {(_binen findIf {alive _x && {(time - ((group _x) getVariable [QGVAR(contact), -999])) < 5}}) >= 0}
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
    { _tasinan = _tasinan + count _x; } forEach _gl;
} forEach _eslesme;

waitUntil { sleep 2; (_isler findIf {!scriptDone _x}) isEqualTo -1 };
_tasinan
