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


// ---- v8.141 MURETTEBAT TOPLAMA (RPT 3deb224e: TASIMA atanan araclarin surucusu aracta degildi: "surucu YOK" x4; mürettebat aracin yaninda ayakta duruyordu) ----
// Surucusu olmayan TASIMA aracina: kayitli ekip grubunun (ekipGrup) ya da TASIMA gorevli grupların aracin 80 m yanindaki yaya askerleri binerek surucu / komutan olur.
{
    private _v = _x;
    private _adaylar = [];
    private _eg = _v getVariable ["lambs_danger_ekipGrup", grpNull];
    if (!isNull _eg) then { _adaylar append ((units _eg) select {alive _x && {isNull objectParent _x} && {!isPlayer _x}}); };
    {
        if (!(_x in _adaylar)) then { _adaylar pushBack _x; };
    } forEach (allUnits select {alive _x && {isNull objectParent _x} && {!isPlayer _x} && {(side _x) isEqualTo _taraf} && {((group _x) getVariable ["lambs_danger_gorev", ""]) isEqualTo "TASIMA"} && {(_x distance2D _v) < 80}});
    if (_adaylar isNotEqualTo []) then {
        private _sr = _adaylar select 0;
        _sr assignAsDriver _v;
        _sr moveInDriver _v;
        diag_log format ["[TASIMA] MURETTEBAT TOPLAMA: %1 | surucu yoktu -> %2 (%3 m yaninda, yayaydi) surucu yapildi; ekip aday %4", getText (configOf _v >> "displayName"), name _sr, round (_sr distance2D _v), count _adaylar];
        if (count _adaylar > 1) then {
            private _kmt = _adaylar select 1;
            if (isNull (commander _v)) then { _kmt assignAsCommander _v; _kmt moveInCommander _v; };
        };
    } else {
        diag_log format ["[TASIMA] MURETTEBAT YOK: %1 | surucu yok, ekip grubu / yakinda TASIMA gorevli yaya asker bulunamadi (ekipGrup %2)", getText (configOf _v >> "displayName"), if (isNull _eg) then {"kayitsiz"} else {groupId _eg}];
    };
} forEach (vehicles select {alive _x && {_x isKindOf "LandVehicle"} && {canMove _x} && {isNull (driver _x)} && {(_x getVariable ["lambs_danger_gorev", ""]) isEqualTo "TASIMA"}});

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
    && {!(_vg getVariable [QGVAR(planAktif), false])} && {(time - (_vg getVariable [QGVAR(tasimaSonT), -999])) > 15}
    && {!(((_v getVariable ["lambs_danger_gorev", ""]) in ["HARIC", "MEDEVAC", "TOPCU", "TOPCU_YOK", "KARAKOL_ARAC"]) || {((_vg getVariable ["lambs_danger_gorev", ""]) in ["HARIC", "MEDEVAC", "TOPCU", "TOPCU_YOK", "KARAKOL_ARAC"])})}
    && {(({isPlayer _x} count (crew _v)) isEqualTo 0)} && {!(_v getVariable [QGVAR(tasimaMesgul), false])}
};
// v8.139 TANI: Zeus TASIMA atadigi halde uygun gorulmeyen araclar icin NEDEN (RPT 045f5750: iki atanmis arac "atanmis arac: 0" olarak elendi, neden bilinmiyordu)
{
    private _v = _x;
    private _d = driver _v;
    private _vg = group _d;
    private _gv = [_v getVariable ["lambs_danger_gorev", ""]] + (crew _v apply {(group _x) getVariable ["lambs_danger_gorev", ""]});
    if ("TASIMA" in _gv && {!(_v in _uygun)}) then {
        private _neden = if (!alive _v) then {"arac yikildi"} else {
            if (!canMove _v) then {"hareket edemiyor (canMove false)"} else {
            if ((fuel _v) <= 0.1) then {"yakit <= %10"} else {
            if ((_v emptyPositions "cargo") < 3) then {format ["bos kargo yeri %1 (< 3)", _v emptyPositions "cargo"]} else {
            if ((_v distance2D _pickRef) > _menzil) then {format ["piyadeye %1 m (> %2)", round (_v distance2D _pickRef), round _menzil]} else {
            if (isNull _d) then {"surucu YOK"} else {
            if (isPlayer _d) then {"surucu oyuncu"} else {
            if (!local _d) then {"surucu sunucuda yerel degil"} else {
            if ((side _vg) isNotEqualTo _taraf) then {format ["taraf %1 (plan %2)", side _vg, _taraf]} else {
            if (((units _vg) findIf {alive _x && {(vehicle _x) isNotEqualTo _v}}) >= 0) then {"arac grubundan biri aracin DISINDA"} else {
            if (_vg getVariable [QGVAR(planAktif), false]) then {"arac grubu planda"} else {
            if ((time - (_vg getVariable [QGVAR(tasimaSonT), -999])) <= 15) then {"son nakilden < 15 sn"} else {
            if (_v getVariable [QGVAR(tasimaMesgul), false]) then {"zaten nakilde (mesgul)"} else {
            if (({isPlayer _x} count (crew _v)) > 0) then {"icinde oyuncu var"} else {"gorev etiketi disinda bir filtre (HARIC / MEDEVAC / KARAKOL_ARAC ...)"}}}}}}}}}}}}}};
        diag_log format ["[TASIMA] ATANMIS ARAC UYGUN DEGIL: %1 | %2", getText (configOf _v >> "displayName"), _neden];
    };
} forEach (vehicles select {alive _x && {_x isKindOf "LandVehicle"}} select {
    private _v = _x; ("TASIMA" in ([_v getVariable ["lambs_danger_gorev", ""]] + (crew _v apply {(group _x) getVariable ["lambs_danger_gorev", ""]})))
});
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
// v8.136: rezerv YALNIZ medevac gorevi varsa (Zeus MEDEVAC atamasi: hekim / medevac ekibi grubu) ayrilir; yoksa tum araclar tasir (RPT 013ca3b7: gorev olmadan rezerv arac bos bekledi)
private _mdGrupVar = (allGroups select {(side _x) isEqualTo _taraf && {(_x getVariable ["lambs_danger_gorev", ""]) isEqualTo "MEDEVAC"}}) isNotEqualTo [];
if (count _araclar > 1 && {_mdGrupVar} && {!_mdVarMi} && {missionNamespace getVariable ["lambs_danger_tasimaMedevacRezerv", true]}) then {
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
    // v8.137: birim bazli: zaten inis noktasina + 150 m icindeki askerler tasinmaz (sefer 2+: ilk seferde sigmayip geride kalanlar alinir)
    private _on = (units _g) select {alive _x && {isNull objectParent _x} && {(_x distance2D _obj) > (_dropM + 150)}};
    if (_on isEqualTo []) then { continue };
    if ([_on, groupId _g] call _yerlestir) then { continue };
    // sigmadi: takim bazli bol
    private _takimlar = (([_g] call FUNC(splitFireTeams)) apply {_x select {alive _x && {isNull objectParent _x} && {(_x distance2D _obj) > (_dropM + 150)}}}) select {_x isNotEqualTo []};
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
// v8.139: inis noktasi yola cekilir (arac yolda cok daha hizli ve takilmaz; RPT 045f5750: Stryker arazide 15-19 km/s gidiyordu): 250 m icindeki yol, objektife >= 460 m (M16 etkili menzili)
private _yollar = (_drop nearRoads 250) select {(getPosATL _x) distance2D _obj >= 460 && {!surfaceIsWater (getPosATL _x)}};
if (_yollar isNotEqualTo []) then {
    _yollar = [_yollar, [], {_x distance2D _drop}, "ASCEND"] call BIS_fnc_sortBy;
    _drop = getPosATL (_yollar select 0);
    diag_log format ["[TASIMA] %1 | inis noktasi yola cekildi: %2 (yol, hedeften %3 m)", _taraf, mapGridPosition _drop, round (_drop distance2D _obj)];
};
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
        private _temasVar = {
            params ["_ul", "_dr"];
            ((_ul findIf {alive _x && {(time - ((group _x) getVariable [QGVAR(contact), -999])) < 5}}) >= 0) || {(getSuppression _dr) > 0.5}
        };

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
                || {(_gl findIf {(_x findIf {alive _x && {(time - ((group _x) getVariable [QGVAR(contact), -999])) < 5}}) >= 0}) >= 0}
            };
        };
        if (!alive _v || {!alive _d}) then { _iptal = "arac / surucu oldu"; };
        if (_iptal isEqualTo "" && {_ctl select 0}) then { _iptal = "plan zaman asimi (iptal)"; };
        if (_iptal isEqualTo "" && {(_gl findIf {(_x findIf {alive _x && {(time - ((group _x) getVariable [QGVAR(contact), -999])) < 5}}) >= 0}) >= 0}) then { _iptal = "alma noktasinda piyade ates altinda (arac yaklasmadi)"; };
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
                || {[_hepsi, _d] call _temasVar}
                || {(time > (_bt - 15)) && {((_hepsi select {alive _x && {(vehicle _x) isEqualTo _v}}) isEqualTo []) isEqualTo false}}
            };
            if ([_hepsi, _d] call _temasVar) then {
                // binerken ates: bindirme iptal; binenler iner (arac ates altinda piyadeyi yuklemez)
                { if (alive _x && {(vehicle _x) isEqualTo _v}) then { unassignVehicle _x; doGetOut _x; }; } forEach _hepsi;
                _iptal = "binerken temas / baski: bindirme iptal";
            };
            // gecikenler: 40 m icindeyse arac icine al
            { if (_iptal isEqualTo "" && {alive _x} && {(vehicle _x) isNotEqualTo _v} && {(_x distance2D _v) < 100} && {(_v emptyPositions "cargo") > 0}) then { _x moveInCargo _v; }; } forEach _hepsi;
            _binen = if (_iptal isEqualTo "") then {_hepsi select {alive _x && {(vehicle _x) isEqualTo _v}}} else {[]};
            if (_iptal isEqualTo "" && {_binen isEqualTo []}) then { _iptal = "kimse binmedi"; };
        };

        // (3) inis noktasina sur
        private _erkenInis = "";
        private _bitis = "";
        private _yakinPusu = false;
        private _gecisT = -1;
        if (_iptal isEqualTo "") then {
            diag_log format ["[TASIMA] %1 | BINDI %2 asker -> inis noktasina %3 m | %4", groupId _vg, count _binen, round (_v distance2D _drop), _ad];
            _d enableAI "PATH";
            _d forceSpeed -1;
            // v8.136: RPT 013ca3b7: Stryker nakilde 11-20 km/s ile gitti (890 m = 5 dk, 240 sn sinirina takildi). Arkada (dusman uzak) SAFE + FULL; inise 220 m kala AWARE + NORMAL
            _vg setBehaviour "SAFE";
            _vg setSpeedMode "FULL";
            _d doMove _drop;
            private _st = time + ((240 max ((_v distance2D _drop) / 3.5)) min 600);
            private _yavasladi = false;
            // v8.135: ilerleme izleme + TAKILMA tespiti (RPT 36a51c57: bir Stryker 2+ dk 0 km/s MOVE komutuyla kaldi; digeri inis noktasini gecip 40 m kuralini hic saglamadi)
            private _durgunT = -1;
            private _denemeN = 0;
            private _logT = time + 20;
            private _yakinT = -1;
            while {_bitis isEqualTo ""} do {
                sleep 1;
                private _dm = _v distance2D _drop;
                private _hz = (speed _v) / 3.6;
                if (!_yavasladi && {_dm < 220}) then { _yavasladi = true; _vg setBehaviour "AWARE"; _vg setSpeedMode "NORMAL"; };
                if (!alive _v || {!alive _d}) then { _bitis = "oldu"; }
                else { if (_ctl select 0) then { _bitis = "iptal"; }
                else { if (time > _st) then { _bitis = "sure"; }
                else { if ((!canMove _v) || {(damage _v) > 0.5}) then { _bitis = "hasar"; }
                else { if ([_binen, _d] call _temasVar && {_gecisT < 0 || {(time - _gecisT) > 40}}) then {
                    // PUSU (v8.138): dusman >= 150 m ve arac hareketli -> ates altinda DURMA, tam gazla gec (en fazla 40 sn); yakin pusu (< 150 m) / hasar -> hemen in
                    private _en = _d findNearestEnemy (getPosATL _d);
                    private _edm = if (isNull _en) then {9999} else {_v distance2D _en};
                    if (_gecisT < 0 && {_edm >= 150}) then {
                        _gecisT = time;
                        _vg setBehaviour "CARELESS";
                        _vg setSpeedMode "FULL";
                        _d forceSpeed -1;
                        _d doMove _drop;
                        diag_log format ["[TASIMA] %1 | PUSU / TEMAS: dusman %2 m -> durmadan HIZLI GECIS (en fazla 40 sn), inise %3 m", groupId _vg, [round _edm, "bilinmiyor"] select (_edm >= 9999), round _dm];
                    } else {
                        _yakinPusu = _edm < 150;
                        _bitis = "temas";
                        diag_log format ["[TASIMA] %1 | %2: dusman %3 m -> HEMEN IN", groupId _vg, ["TEMAS (gecis suresi doldu)", "YAKIN PUSU"] select _yakinPusu, [round _edm, "bilinmiyor"] select (_edm >= 9999)];
                    };
                }
                else { if (_dm < 60) then { _bitis = "vardi"; }
                else { if (_dm < 180 && {_hz < 1}) then { if (_yakinT < 0) then { _yakinT = time; }; if ((time - _yakinT) > 6) then { _bitis = "vardi"; }; } else { _yakinT = -1; }; }; }; }; }; }; };
                if (_bitis isEqualTo "" && {_gecisT > 0} && {!([_binen, _d] call _temasVar)} && {(time - _gecisT) > 12}) then {
                    diag_log format ["[TASIMA] %1 | pusudan cikildi, normal surus (inise %2 m)", groupId _vg, round _dm];
                    _gecisT = -1;
                    _vg setBehaviour "SAFE";
                };
                if (_bitis isEqualTo "") then {
                    if (_hz < 0.8 && {_dm > 90}) then {
                        if (_durgunT < 0) then { _durgunT = time; };
                        private _dg = time - _durgunT;
                        // v8.140: daha hizli mudahale (RPT 2ca0498e: bir Stryker bindirdikten sonra 0 km/s kaldi; 20/45/75 sn cok uzundu) + tani
                        if (_denemeN isEqualTo 0 && {_dg > 8}) then {
                            _denemeN = 1;
                            private _yakin = (nearestObjects [_v, [], 9]) select {_x isNotEqualTo _v && {!(_x isKindOf "CAManBase")}};
                            diag_log format ["[TASIMA] %1 | TAKILMA TANISI (%2 sn hareketsiz, inise %3 m): motor %4 | yakit %5 | hasar %6 | canMove %7 | surucu %8 (%9) | komut %10 | PATH/MOVE AI: %11 / %12 | 9 m icinde nesne: %13",
                                groupId _vg, round _dg, round _dm, isEngineOn _v, (fuel _v) toFixed 2, (damage _v) toFixed 2, canMove _v, name _d, lifeState _d, currentCommand _d,
                                _d checkAIFeature "PATH", _d checkAIFeature "MOVE", _yakin apply {typeOf _x}];
                            _d enableAI "PATH"; _d enableAI "MOVE"; _d enableAI "ANIM";
                            _d setVariable [QGVAR(forceMove), true];
                            _v engineOn true;
                            _d forceSpeed -1; doStop _d; _d doMove _drop;
                            _v setVelocityModelSpace [0, 5, 0];
                        };
                        if (_denemeN isEqualTo 1 && {_dg > 18}) then {
                            _denemeN = 2;
                            private _alt = (getPosATL _v) getPos [60, (getPosATL _v) getDir _drop];
                            diag_log format ["[TASIMA] %1 | TAKILDI: 18 sn; ara noktaya (60 m) yonlendirildi", groupId _vg];
                            _d doMove _alt;
                            _v setVelocityModelSpace [0, 6, 0];
                        };
                        if (_dg > 35) then { _bitis = "takildi"; };
                    } else { _durgunT = -1; if (_denemeN > 0 && {_hz > 2}) then { _denemeN = 0; }; };
                    if (time > _logT) then {
                        _logT = time + 20;
                        diag_log format ["[TASIMA] %1 | yolda: inise %2 m | hiz %3 km/s", groupId _vg, round _dm, round (speed _v)];
                    };
                };
            };
            if (!alive _v || {!alive _d}) then { _iptal = "tasima sirasinda arac / surucu oldu"; };
            if (_iptal isEqualTo "" && {_bitis isNotEqualTo "vardi"}) then {
                _erkenInis = switch (_bitis) do {
                    case "temas": { format ["temas / baski (inise %1 m kala)", round (_v distance2D _drop)] };
                    case "sure": { "sure doldu (240 sn)" };
                    case "hasar": { format ["arac HASARLI / hareket edemiyor (inise %1 m kala)", round (_v distance2D _drop)] };
                    case "takildi": { format ["arac TAKILDI (inise %1 m kala)", round (_v distance2D _drop)] };
                    default { "iptal" };
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
        if (alive _v && {alive _d} && {_yakinPusu}) then {
            // yakin pusu: araci terk edilmis birakma, silahci ates etsin (30 sn), sonra don
            _d enableAI "AUTOCOMBAT";
            _vg setBehaviour "COMBAT";
            _vg setCombatMode "RED";
            sleep 30;
            _vg setCombatMode "YELLOW";
        };
        if (alive _v && {alive _d} && {_bitis isNotEqualTo "hasar"}) then {
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
        _vg setVariable [QGVAR(tasimaSonT), time];
        count _binen
    });
    { _tasinan = _tasinan + count _x; } forEach _gl;
} forEach _eslesme;

waitUntil { sleep 2; (_isler findIf {!scriptDone _x}) isEqualTo -1 };
// v8.138: is hata ile olurse bayraklar sizmasin (arac sonsuza dek "mesgul" / surucu forceMove / AUTOCOMBAT kapali)
{
    _x params ["_v"];
    if (!isNull _v && {_v getVariable [QGVAR(tasimaMesgul), false]}) then {
        _v setVariable [QGVAR(tasimaMesgul), nil];
        private _dr = driver _v;
        if (!isNull _dr) then { _dr setVariable [QGVAR(forceMove), nil]; _dr enableAI "AUTOCOMBAT"; (group _dr) setVariable [QGVAR(isExecutingTactic), nil]; };
        diag_log format ["[TASIMA] TEMIZLIK: %1 bayraklari sifirlandi (is beklenmedik bicimde bitti)", getText (configOf _v >> "displayName")];
    };
} forEach _eslesme;
_tasinan
