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

// ---- v8.145 MURETTEBAT TAMAMLAMA (RPT 6c8708da: "crewden 1 kisi indi, apc islevsiz": surucu iceride, komutan 17 m disarida yayaydi -> "arac grubundan biri aracin DISINDA" ile elendi) ----
private _tamamlandi = 0;
{
    private _v = _x;
    private _d = driver _v;
    if (isNull _d || {isPlayer _d} || {!local _d} || {_v getVariable [QGVAR(tasimaMesgul), false]}) then { continue };
    private _vg = group _d;
    if (_vg getVariable [QGVAR(planAktif), false] || {(time - (_vg getVariable [QGVAR(contact), -999])) < 20}) then { continue };
    private _dis = (units _vg) select {alive _x && {isNull objectParent _x} && {!isPlayer _x} && {(lifeState _x) in ["HEALTHY", "INJURED"]} && {(_x distance2D _v) < 150}};
    if (_dis isEqualTo []) then { continue };
    {
        private _u = _x;
        _u enableAI "PATH";
        private _yakin = (_u distance2D _v) < 30;
        if (isNull (commander _v)) then { _u assignAsCommander _v; if (_yakin) then { _u moveInCommander _v; } else { [_u] orderGetIn true; }; } else {
            if (isNull (gunner _v)) then { _u assignAsGunner _v; if (_yakin) then { _u moveInGunner _v; } else { [_u] orderGetIn true; }; } else {
                _u assignAsCargo _v; if (_yakin) then { _u moveInCargo _v; } else { [_u] orderGetIn true; };
            };
        };
    } forEach _dis;
    _tamamlandi = _tamamlandi + 1;
    diag_log format ["[TASIMA] MURETTEBAT TAMAMLAMA: %1 | disarida kalan murettebat %2 (%3) araca donduruldu", getText (configOf _v >> "displayName"), count _dis, _dis apply {name _x}];
} forEach (vehicles select {alive _x && {_x isKindOf "LandVehicle"} && {canMove _x} && {(_x distance2D _rp) <= (_menzil + 300)}});
if (_tamamlandi > 0) then { sleep 6; };

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
    && {!(_x getVariable ["lambs_danger_reconArac", false])}
    && {(_x emptyPositions "cargo") >= 3}
    && {(_x distance2D _pickRef) <= _menzil}
});
// v8.166: TASIMA atanmis ama surucu grubu baska makinede (Zeus istemcisi) ise sunucuya devret (yerel degilse arac hic hareket etmiyordu)
if (isServer) then {
    private _uzakSurucu = [];
    {
        private _gv = [_x getVariable ["lambs_danger_gorev", ""]] + (crew _x apply {(group _x) getVariable ["lambs_danger_gorev", ""]});
        private _dr = driver _x;
        if ("TASIMA" in _gv && {!isNull _dr} && {!isPlayer _dr} && {!local _dr} && {(side (group _dr)) isEqualTo _taraf} && {(time - ((group _dr) getVariable [QGVAR(gorulduT), -999])) >= 60}) then { _uzakSurucu pushBackUnique (group _dr); };
    } forEach _tumAraclar;
    if (_uzakSurucu isNotEqualTo []) then {
        { diag_log format ["[TASIMA] SURUCU GRUBU DEVIR: %1 | sahip makine %2 -> sunucu", groupId _x, groupOwner _x]; _x setGroupOwner 2; } forEach _uzakSurucu;
        private _t0 = time;
        waitUntil { sleep 0.3; ((_uzakSurucu findIf {!local _x}) isEqualTo -1) || {(time - _t0) > 6} };
    };
};
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
private _dg0 = _gruplar param [0, grpNull];
private _inisM = [_dg0, "tasimaInisM", 500] call FUNC(dk);
private _dropM = if ([_dg0, "tasimaOrpEk", true] call FUNC(dk)) then { _inisM max (_orpM + 150) } else { _inisM };
private _destekKal = [_dg0, "aracDestekKal", false] call FUNC(dk);
// v8.163: gercek koltuk sayisi emptyPositions'tan az olabilir (RPT 69d7f8f5: Fuchs 8 gosterdi, 7 bindi, 3 asker acikta kaldi) -> tip basina OGRENILEN kapasite kullanilir
private _kapGercek = _araclar apply {[_x, (_x emptyPositions "cargo") min (missionNamespace getVariable [format ["lambs_danger_tasimaKap_%1", typeOf _x], 99])]};
private _kalan = [];
private _eslesme = [];   // [arac, [birim dizileri]]
private _yaya = [];
private _bolunen = [];
// v8.165: en BOSTAKI araca yerlestir (worst-fit): tum atanmis araclar dolar, hicbiri bos kalmaz (RPT c4f70534: 5 arac atandi, ilk uyan 3 araca 24 asker dolduruldu, 2 arac bos)
private _yerlestir = {
    params ["_birimler", "_ad"];
    private _n = count _birimler;
    private _i = -1;
    private _en = -1;
    { if ((_x select 1) >= _n && {(_x select 1) > _en}) then { _en = _x select 1; _i = _forEachIndex; }; } forEach _kalan;
    if (_i < 0) exitWith { false };
    (_kalan select _i) set [1, ((_kalan select _i) select 1) - _n];
    private _v = (_kalan select _i) select 0;
    private _e = _eslesme findIf {(_x select 0) isEqualTo _v};
    if (_e < 0) then { _eslesme pushBack [_v, [_birimler]]; } else { ((_eslesme select _e) select 1) pushBack _birimler; };
    true
};
private _tumBirim = 0;
{ _tumBirim = _tumBirim + count ((units _x) select {alive _x && {isNull objectParent _x} && {(_x distance2D _obj) > (_dropM + 150)}}); } forEach _gruplar;
private _yumusak = (ceil (_tumBirim / (count _araclar))) max 5;
for "_tur" from 0 to 1 do {
    // tur 0: arac basina yumusak tavan (dengeli dagilim); sigmayan olursa tur 1: gercek kapasite
    _kalan = _kapGercek apply {[_x select 0, if (_tur isEqualTo 0) then {(_x select 1) min _yumusak} else {_x select 1}]};
    _eslesme = [];
    _yaya = [];
    _bolunen = [];
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
    if (_yaya isEqualTo []) exitWith {};
};
if (_eslesme isEqualTo []) exitWith {
    diag_log format ["[TASIMA] %1 | arac var (%2) ama hicbir takim sigmadi -> yuruyerek", _taraf, count _araclar];
    0
};

private _drop = _obj getPos [_dropM, _B];
if (surfaceIsWater _drop) then { _drop = _obj getPos [(_dropM + 100), _B]; };
// v8.139: inis noktasi yola cekilir (arac yolda cok daha hizli ve takilmaz; RPT 045f5750: Stryker arazide 15-19 km/s gidiyordu): 250 m icindeki yol, objektife >= 460 m (M16 etkili menzili)
private _yollar = (_drop nearRoads 250) select {(getPosATL _x) distance2D _obj >= (_dropM - 40) && {!surfaceIsWater (getPosATL _x)}};
if (_yollar isNotEqualTo []) then {
    // v8.184 KORUNAKLI INIS NOKTASI (kullanici: "indikleri gibi atis yiyorlar, acik arazi"; MCWP 3-11.1 s. 6-37: iniste "relative protection"): adaylar (en yakin 25 yol) objektife gorus hatti KAPALI (+30), cevre obje yogunlugu (siper, 24'e kadar x1.2) ve nominal noktaya yakinlik ile puanlanir
    _yollar = [_yollar, [], {_x distance2D _drop}, "ASCEND"] call BIS_fnc_sortBy;
    _yollar = _yollar select [0, 25];
    private _eniY = _yollar select 0;
    private _eniS = -1e9;
    {
        private _yp = getPosATL _x;
        private _engel = (lineIntersectsSurfaces [(AGLToASL [_yp select 0, _yp select 1, 2]), (AGLToASL [_obj select 0, _obj select 1, 1.5]), objNull, objNull, true, 1, "VIEW", "FIRE"]) isNotEqualTo [];
        private _ob = count (nearestTerrainObjects [_yp, ["TREE", "ROCK", "WALL", "BUILDING", "HIDE", "BUSH"], 40, false, true]);
        private _sc = ([0, 30] select _engel) + ((_ob min 24) * 1.2) - 0.05 * (_yp distance2D _drop);
        if (_sc > _eniS) then { _eniS = _sc; _eniY = _x; };
    } forEach _yollar;
    _drop = getPosATL _eniY;
    diag_log format ["[TASIMA] %1 | inis noktasi korunak puani: %2 (aday %3)", _taraf, round _eniS, count _yollar];
    diag_log format ["[TASIMA] %1 | inis noktasi yola cekildi: %2 (yol, hedeften %3 m)", _taraf, mapGridPosition _drop, round (_drop distance2D _obj)];
};
private _nB = 0;
{ { _nB = _nB + count _x; } forEach (_x select 1); } forEach _eslesme;
_ctl set [2, _nB];   // plan: gercekten nakil yapiliyor (> 0) -> is bitince TOPLAN hazir sayilir
diag_log format ["[TASIMA] %1 | %2 arac / %3 asker eslesti | takim bazli bolunen: %4 | yaya kalan birim: %5 | inis noktasi %6 (hedeften %7 m) | atanmis arac: %8",
    _taraf, count _eslesme, _nB, _bolunen, count _yaya, mapGridPosition _drop, round _dropM, count _atanan];

// v8.165 BEKLE: eslesen askerler oldugu yerde DURUR ve arac gelene kadar yurumez (RPT c4f70534: piyade RP'ye kosuyor, arac peşinden 90-120 sn kovaliyordu)
{ { { if (alive _x) then { _x setVariable [QGVAR(tasimaBekle), true]; doStop _x; _x disableAI "PATH"; }; } forEach _x; } forEach (_x select 1); } forEach _eslesme;

// ---- v8.131 YIGILMA ONLEME: araclar ayni noktaya gitmesin; alma / inis noktasi yanal 24 m aralikla dagitilir ----
private _noktaYay = {
    params ["_nokta", "_i", "_n"];
    // v8.177: araclar ayni yerde YIGILMASIN (kullanici: "apc'ler sikisiyor, hareket edemiyor"): yanal 45 m aralik + tek / cift siralar arasi 35 m derinlik (objektiften uzaga) = en az ~55 m birbirinden
    private _of = (_i - (_n - 1) / 2) * 45;
    private _p = _nokta getPos [abs _of, _B + ([90, -90] select (_of < 0))];
    _p = _p getPos [(_i mod 2) * 35, _B];
    if (surfaceIsWater _p) then { _p = _nokta; };
    _p
};

private _tasinan = 0;
private _isler = [];
_ctl set [3, 0];
_ctl set [4, count _eslesme];
// v8.171 SENKRON: [inen arac sayisi, toplam arac, araclar] - konvoy hiz eslemesi ve inis sonrasi toplanma bu diziyi kullanir
private _senk = [0, count _eslesme, _eslesme apply {_x select 0}, []];   // 3: rezerv noktalari (araclar rezervde de dagilsin)
{
    _x params ["_v", "_gl"];
    private _d = driver _v;
    private _vg = group _d;
    private _rpi = [_rp, _forEachIndex, count _eslesme] call _noktaYay;
    private _dropi = [_drop, _forEachIndex, count _eslesme] call _noktaYay;
    _isler pushBack ([_v, _d, _vg, _gl, _rpi, _dropi, _ctl, _destekKal, _obj, _senk] spawn {
        params ["_v", "_d", "_vg", "_gl", "_rp", "_drop", "_ctl", "_destekKal", "_obj", "_senk"];
        private _senkSay = false;
        private _senkBitti = { if (!_senkSay) then { _senkSay = true; _senk set [0, (_senk select 0) + 1]; }; };
        _v setVariable [QGVAR(tasimaMesgul), true];
        _v setVariable [QGVAR(aracMedevacT), time];
        if !(_v getVariable [QGVAR(atesEH), false]) then {
            _v setVariable [QGVAR(atesEH), true];
            _v setVariable [QGVAR(atesSay), 0];
            _v addEventHandler ["Fired", {
                params ["_veh", "_wpn", "", "", "", "", "_proj"];
                private _n = (_veh getVariable [QGVAR(atesSay), 0]) + 1;
                _veh setVariable [QGVAR(atesSay), _n];
                if (_n isEqualTo 1 || {(time - (_veh getVariable [QGVAR(atesLogT), -999])) > 30}) then {
                    _veh setVariable [QGVAR(atesLogT), time];
                    diag_log format ["[ARAC-ATES] %1 | silah %2 | atis #%3 | hiz %4 km/s", getText (configOf _veh >> "displayName"), _wpn, _n, round (speed _veh)];
                };
            }];
        };
        // v8.172 SILAHCI KARSILIK (kullanici: "apc kacamayacaksa karsilik versin, turret dusmani gorur gormez, donuste de"): is boyunca ve bitisten 180 sn sonrasina kadar silahci (yoksa komutan; surucu degil)
        // bilinen en yakin dusmana (<= 900 m) doTarget / doFire; yol / inis / geri donus fark etmez; tasima grubunun ates modu GREEN / BLUE ise YELLOW'a alinir
        _v setVariable [QGVAR(silahciSon), time + 99999];
        if ((combatMode _vg) in ["GREEN", "BLUE"]) then { _vg setCombatMode "YELLOW"; };
        if !(_v getVariable [QGVAR(silahciVar), false]) then { _v setVariable [QGVAR(silahciVar), true]; [_v] spawn {
            params ["_v"];
            private _logT = -999;
            while {alive _v && {time < (_v getVariable [QGVAR(silahciSon), 0])}} do {
                private _dr = driver _v;
                private _gn = if (!isNull (gunner _v) && {(gunner _v) isNotEqualTo _dr}) then {gunner _v} else {commander _v};
                if (!isNull _gn && {alive _gn} && {_gn isNotEqualTo _dr} && {(lifeState _gn) in ["HEALTHY", "INJURED"]}) then {
                    private _hd = _gn findNearestEnemy (getPosATL _v);
                    if (!isNull _hd && {alive _hd} && {(_v distance2D _hd) <= 900} && {(_gn knowsAbout _hd) > 0.3}) then {
                        _gn enableAI "TARGET"; _gn enableAI "AUTOTARGET";
                        _gn doTarget _hd;
                        _gn doFire _hd;
                        if ((time - _logT) > 20) then {
                            _logT = time;
                            diag_log format ["[ARAC-ATES] %1 | silahci %2 hedefe donuyor: %3 m | arac hizi %4 km/s", getText (configOf _v >> "displayName"), name _gn, round (_v distance2D _hd), round (speed _v)];
                        };
                    };
                };
                sleep 2;
            };
            _v setVariable [QGVAR(silahciVar), nil];
        }; };
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

        // v8.180 PARK CIKISI: arac baska arac(lar)a 12 m'den yakin park halindeyse (Zeus ayni yere dizmis; RPT 01650734: yan yana iki M113 LATGM kalkamadi, 8 asker 4.4 km geride indi) komsulardan >= 9 m uzak, su / bina / duvar disi bos bir konuma (14 / 20 / 28 m, 8 yon) tasinir
        private _cikisFn = {
            params ["_v", "_drop"];
            private _en = [];
            private _enS = -1;
            {
                private _m = _x;
                {
                    private _a = (_v getDir _drop) + _x;
                    private _p = (getPosATL _v) getPos [_m, _a];
                    if (!surfaceIsWater _p
                        && {((_p nearEntities [["LandVehicle", "Air"], 9]) select {_x isNotEqualTo _v}) isEqualTo []}
                        && {(nearestTerrainObjects [_p, ["BUILDING", "WALL", "TREE", "ROCK"], 5, false, true]) isEqualTo []}
                        && {((surfaceNormal _p) select 2) > 0.9}) then {
                        // oncelik: inise bakan yon (|aci| kucuk)
                        private _s = 100 - abs _x - _m;
                        if (_s > _enS) then { _enS = _s; _en = _p; };
                    };
                } forEach [0, 45, -45, 90, -90, 135, -135, 180];
            } forEach [14, 20, 28];
            _en
        };
        private _birak = {
            params ["_gl2"];
            { { if (alive _x) then { _x setVariable [QGVAR(tasimaBekle), nil]; _x enableAI "PATH"; }; } forEach _x; } forEach _gl2;
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
        private _yayaGelsin = false;   // v8.168: arac piyadeye varamazsa / piyade yakinsa piyade araca YURUR
        if (_pk isEqualTo []) then { _iptal = "tasinacak asker kalmadi"; } else {
            if ((_v distance2D _pk) < 250) then {
                // v8.168: piyade zaten 250 m icinde: arac HAREKET ETMEZ, piyade araca biner (RPT 5792af8a: 61 / 77 m'deki araclar 0 km/s MOVE ile hic kipirdamadi)
                _yayaGelsin = true;
                diag_log format ["[TASIMA] %1 | %2 | piyade yakin (%3 m): arac beklemede, piyade araca biner | surucu %4", groupId _vg, _ad, round (_v distance2D _pk), name _d];
            } else {
                diag_log format ["[TASIMA] %1 | %2 | piyadeye gidiyor: %3 m | surucu %4", groupId _vg, _ad, round (_v distance2D _pk), name _d];
                _d doMove _pk;
                private _t = time + (150 max (((_v distance2D _pk) / 6) min 420));
                private _sonMove = time;
                private _durT = -1;
                private _kurt = 0;
                private _vazgec = false;
                waitUntil {
                    sleep 1;
                    _pk = [_gl] call _pickFn;
                    if (_pk isNotEqualTo [] && {(time - _sonMove) > 4}) then { _d doMove _pk; _sonMove = time; };
                    // v8.168 TAKILMA KURTARMA (alma yolu): 8 sn hareketsiz -> motor / AI ozellikleri / yeniden komut; 18 sn -> surucu yeniden otur; 30 sn -> vazgec, piyade araca yurur
                    if (alive _v && {(speed _v) < 1} && {_pk isNotEqualTo []} && {(_v distance2D _pk) > 60}) then {
                        if (_durT < 0) then { _durT = time; };
                        private _dg = time - _durT;
                        if (_kurt isEqualTo 0 && {_dg > 8}) then {
                            _kurt = 1;
                            diag_log format ["[TASIMA] %1 | ALMA TAKILMASI (8 sn hareketsiz, piyadeye %2 m): motor %3 | canMove %4 | PATH/MOVE %5 / %6 | komut %7", groupId _vg, round (_v distance2D _pk), isEngineOn _v, canMove _v, _d checkAIFeature "PATH", _d checkAIFeature "MOVE", currentCommand _d];
                            _d enableAI "PATH"; _d enableAI "MOVE"; _d enableAI "ANIM";
                            _v engineOn true; _d forceSpeed -1; doStop _d; _d doMove _pk; _sonMove = time;
                        };
                        if (_kurt isEqualTo 1 && {_dg > 18}) then {
                            _kurt = 2;
                            _d action ["EngineOn", _v]; _v engineOn true;   // v8.184: moveOut / moveIn kaldirildi (surucu gir-cik yapiyordu; RPT 94057b17)
                            _d enableAI "PATH"; _d enableAI "MOVE"; _d doMove _pk; _sonMove = time;
                        };
                        if (_dg > 30) then { _vazgec = true; };
                    } else { _durT = -1; };
                    !alive _v || {!alive _d} || {_pk isEqualTo []} || {(_v distance2D _pk) < 60} || {time > _t} || {_ctl select 0} || {_vazgec}
                    || {(_gl findIf {(_x findIf {alive _x && {(time - ((group _x) getVariable [QGVAR(contact), -999])) < 5}}) >= 0}) >= 0}
                };
                if (_pk isNotEqualTo [] && {alive _v} && {(_v distance2D _pk) >= 60} && {(_v distance2D _pk) < 450} && {!(_ctl select 0)}) then {
                    _yayaGelsin = true;
                    diag_log format ["[TASIMA] %1 | %2 | arac piyadeye varamadi (%3 m kaldi) -> piyade araca YURUYOR", groupId _vg, _ad, round (_v distance2D _pk)];
                };
            };
        };
        if (!alive _v || {!alive _d}) then { _iptal = "arac / surucu oldu"; };
        if (_iptal isEqualTo "" && {_ctl select 0}) then { _iptal = "plan zaman asimi (iptal)"; };
        if (_iptal isEqualTo "" && {(_gl findIf {(_x findIf {alive _x && {(time - ((group _x) getVariable [QGVAR(contact), -999])) < 5}}) >= 0}) >= 0}) then { _iptal = "alma noktasinda piyade ates altinda (arac yaklasmadi)"; };
        if (_iptal isEqualTo "" && {!_yayaGelsin} && {_pk isEqualTo [] || {(_v distance2D _pk) >= 60}}) then { _iptal = format ["piyadeye varilamadi (kalan %1 m)", [round (_v distance2D _pk), -1] select (_pk isEqualTo [])]; };

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
            [_gl] call _birak;
            { _x assignAsCargo _v; } forEach _hepsi;
            _hepsi orderGetIn true;
            private _bt = time + 90;
            // v8.163: arac DOLDUYSA ya da son 12 sn'de kimse binmediyse (en az 1 binen varken) bekleme biter (eski: 75 sn bos bekleme, RPT 69d7f8f5)
            private _bn = 0;
            private _bTT = time;
            waitUntil {
                sleep 1;
                private _n = count (_hepsi select {alive _x && {(vehicle _x) isEqualTo _v}});
                if (_n isNotEqualTo _bn) then { _bn = _n; _bTT = time; };
                !alive _v || {_ctl select 0} || {(_hepsi findIf {alive _x && {(vehicle _x) isNotEqualTo _v}}) isEqualTo -1} || {time > _bt}
                || {[_hepsi, _d] call _temasVar}
                || {_n > 0 && {(_v emptyPositions "cargo") isEqualTo 0}}
                || {_n > 0 && {(time - _bTT) > 15}}
            };
            // kapasite ogrenme: arac dolu ve disarida kalan var -> gercek koltuk = binen sayisi
            private _disarida = _hepsi select {alive _x && {(vehicle _x) isNotEqualTo _v}};
            private _icerde = count (_hepsi select {alive _x && {(vehicle _x) isEqualTo _v}});
            if (_disarida isNotEqualTo [] && {_icerde > 0} && {(_v emptyPositions "cargo") isEqualTo 0}) then {
                missionNamespace setVariable [format ["lambs_danger_tasimaKap_%1", typeOf _v], _icerde];
                diag_log format ["[TASIMA] %1 | KAPASITE OGRENILDI: %2 gercek %3 koltuk (emptyPositions fazla gosteriyordu); %4 asker disarida kaldi (sefer ile alinacak)", groupId _vg, typeOf _v, _icerde, count _disarida];
            };
            // disarida kalanlarin bu araca atamasi kalkar (sefer icin serbest)
            { unassignVehicle _x; } forEach _disarida;
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
        // plan: kac arac binmeyi bitirdi (v8.163: sefer bu sayac tamamlaninca BASLAR, nakil isi bitmeyi beklemez)
        _ctl set [3, (_ctl param [3, 0]) + 1];

        // (3) inis noktasina sur
        private _erkenInis = "";
        private _bitis = "";
        private _yakinPusu = false;
        private _gecisT = -1;
        if (_iptal isEqualTo "") then {
            diag_log format ["[TASIMA] %1 | BINDI %2 asker -> inis noktasina %3 m | %4", groupId _vg, count _binen, round (_v distance2D _drop), _ad];
            // v8.148 YOLCU BEKCISI (RPT 16fa2656: Newton / Moore "komut:GET OUT" 80-90 km/s giden Stryker'da, Moore 12:12:39 28 km/s anim:unconscious = disari atlamis):
            // tasima suresince yolcunun PATH'i kapali, "GET OUT" emri alirsa iptal (doStop), araca aitken disarida kalirsa (aractan < 80 m, arac hareketli) geri alinir. Inis (4) bayrak koyunca biter.
            _v setVariable [QGVAR(yolcuBirak), false];
            [_v, _binen, groupId _vg] spawn {
                params ["_v", "_ps", "_gid"];
                { if (alive _x) then { _x disableAI "PATH"; }; } forEach _ps;
                private _ilk = [];
                while {alive _v && {!(_v getVariable [QGVAR(yolcuBirak), false])} && {_v getVariable [QGVAR(tasimaMesgul), false]}} do {
                    {
                        private _u = _x;
                        if (!alive _u) then { continue };
                        if ((vehicle _u) isEqualTo _v) then {
                            if ((currentCommand _u) isEqualTo "GET OUT" && {(speed _v) > 5}) then {   // v8.187: arac DURMUSKEN (temas / hasar / takilma) inme emri iptal edilmez (RPT 95be8b53: durmus aracta 1-2 asker inemedi)
                                doStop _u;
                                if !(_u in _ilk) then {
                                    _ilk pushBack _u;
                                    diag_log format ["[TASIMA] %1 | YOLCU INME EMRI IPTAL: %2 | arac hizi %3 km/s | grup %4 | grup lideri aracta mi: %5", _gid, name _u, round speed _v, groupId (group _u), (vehicle (leader (group _u))) isEqualTo _v];
                                };
                            };
                        } else {
                            if ((_u distance2D _v) < 80 && {(speed _v) > 3} && {isNull objectParent _u} && {(lifeState _u) in ["HEALTHY", "INJURED"]} && {(_v emptyPositions "cargo") > 0}) then {
                                _u moveInCargo _v;
                                diag_log format ["[TASIMA] %1 | YOLCU GERI ALINDI: %2 | arac hizi %3 km/s", _gid, name _u, round speed _v];
                            };
                        };
                    } forEach _ps;
                    sleep 0.25;
                };
                { if (alive _x) then { _x enableAI "PATH"; }; } forEach _ps;
            };
            if (((_v nearEntities [["LandVehicle"], 7]) select {_x isNotEqualTo _v && {!(_x isKindOf "StaticWeapon")}}) isNotEqualTo []) then {   // v8.185: 12 -> 7 m (setVehiclePosition ile gereksiz tasima kalkisi bozuyor olabilir; yalniz ic ice park)
                private _cp = [_v, _drop] call _cikisFn;
                if (_cp isNotEqualTo []) then {
                    private _eskiP = getPosATL _v;
                    _v setVehiclePosition [_cp, [], 0, "NONE"];
                    _v setDir (_v getDir _drop);
                    diag_log format ["[TASIMA] %1 | PARK CIKISI: komsu arac < 12 m -> %2 m ileri / yana bos konuma tasindi", groupId _vg, round (_eskiP distance2D _cp)];
                };
            };
            // v8.181 KALKIS: motor kapaliysa once AI "EngineOn" eylemi + engineOn, acilana kadar (en cok 6 sn) bekle (RPT ce7738ae: kalkamayan 4 aracin hepsinde "MOTOR KAPALIYDI"; yalniz grup WAYPOINT'i hareket ettirdi)
            if !(isEngineOn _v) then {
                _d action ["EngineOn", _v];
                _v engineOn true;
                private _tM = time + 6;
                waitUntil { sleep 0.5; (isEngineOn _v) || {time > _tM} };
            };
            _d enableAI "PATH";
            _d forceSpeed -1;
            // v8.136: RPT 013ca3b7: Stryker nakilde 11-20 km/s ile gitti (890 m = 5 dk, 240 sn sinirina takildi). Arkada (dusman uzak) SAFE + FULL; inise 220 m kala AWARE + NORMAL
            _vg setBehaviour "SAFE";
            _vg setSpeedMode "FULL";
            _d doMove _drop;
            // v8.181: doMove'a EK olarak grup WAYPOINT'i (v8.180 kaydinda tek calisan yol); inis / is sonunda "ELITE NAKIL" adli waypoint'ler silinir
            { if ((waypointName _x) find "ELITE NAKIL" isEqualTo 0) then { deleteWaypoint _x; }; } forEach (reverse (waypoints _vg));
            private _wpS = _vg addWaypoint [_drop, 0];
            _wpS setWaypointType "MOVE";
            _wpS setWaypointName "ELITE NAKIL";
            _wpS setWaypointSpeed "FULL";
            _wpS setWaypointBehaviour "SAFE";
            _vg setCurrentWaypoint _wpS;
            private _st = time + ((240 max ((_v distance2D _drop) / 3.5)) min 600);
            private _yavasladi = false;
            // v8.135: ilerleme izleme + TAKILMA tespiti (RPT 36a51c57: bir Stryker 2+ dk 0 km/s MOVE komutuyla kaldi; digeri inis noktasini gecip 40 m kuralini hic saglamadi)
            private _durgunT = -1;
            private _denemeN = 0;
            private _logT = time + 20;
            private _yakinT = -1;
            private _senkT = 0;
            private _itmeT = -999;
            private _senkli = false;
            private _senkLogT = -999;
            private _ilerD = 1e6;
            private _ilerT = time;
            private _frenli = false;
            private _frenBas = -1;
            private _frenLogT = -999;
            while {_bitis isEqualTo ""} do {
                sleep 1;
                private _dm = _v distance2D _drop;
                private _hz = (speed _v) / 3.6;
                // v8.167 CARPISMA GUVENLIGI: onde (+-35 derece, 40 m) baska kara araci varsa arac hizina gore mesafe tutar; cok yakinsa durur. Tikaniklik: bir engelleme en fazla 20 sn frenler (sonra takilma kurtarmasi devreye girer)
                if (_bitis isEqualTo "" && {alive _v} && {alive _d}) then {
                    // v8.178: duragan baslangicta (< 2 m/s) FREN YOK (RPT 2491473c: yan yana duran araclar birbirini 8 m onde sayip forceSpeed 0 ile kilitlendi, 8 asker 1.3 km geride indi); koni +-25 derece
                    private _onde = if (_hz < 2) then {[]} else { ((getPosATL _v) nearEntities ["LandVehicle", 40]) select {
                        _x isNotEqualTo _v && {alive _x} && {!(_x isKindOf "StaticWeapon")} && {private _r = _v getRelDir _x; _r < 25 || {_r > 335}}
                    } };
                    private _en = objNull;
                    private _enD = 9999;
                    { private _dx = _v distance2D _x; if (_dx < _enD) then { _enD = _dx; _en = _x; }; } forEach _onde;
                    private _emniyet = 12 + (_hz * 1.0);
                    // v8.181: yalniz YAKLASIYORSA frenle (ayni hizda giden konvoy yavaslatilmaz: RPT ce7738ae 49 km/s'te 25 m'de gereksiz fren); < 9 m her zaman
                    private _yaklasma = _hz - (if (isNull _en) then {0} else {((speed _en) max 0) / 3.6});
                    if (!isNull _en && {_enD < _emniyet} && {_yaklasma > 1.5 || {_enD < 9}} && {(_frenBas < 0) || {(time - _frenBas) < 8}}) then {
                        if (_frenBas < 0) then { _frenBas = time; };
                        _frenli = true;
                        private _hedefHz = if (_enD < 10) then {0} else {((speed _en) max 0) / 3.6 * 0.8};
                        _d forceSpeed (_hedefHz min (_hz max 0));
                        _durgunT = -1;
                        if ((time - _frenLogT) > 15) then {
                            _frenLogT = time;
                            diag_log format ["[TASIMA] %1 | CARPISMA GUVENLIGI: onde %2 %3 m | hiz %4 km/s -> frenleniyor", groupId _vg, getText (configOf _en >> "displayName"), round _enD, round (speed _v)];
                        };
                    } else {
                        if (_frenli) then { _frenli = false; _d forceSpeed -1; _d doMove _drop; };
                        if (isNull _en && {_frenBas >= 0}) then { _frenBas = -1; };
                    };
                };
                if (!_yavasladi && {_dm < 220}) then { _yavasladi = true; _vg setBehaviour "AWARE"; _vg setSpeedMode "NORMAL"; };
                // v8.171 KONVOY SENKRONU (MCWP 3-11.1 s. 6-36: tank / piyade araclari karsilikli destek mesafesinde birlikte ilerler; inis noktasinda kontrol kurulup birlikte saldirilir): hizli arac, ardindaki arac(lar)i > 250 m geride birakmasin
                if (_bitis isEqualTo "" && {!_frenli} && {_dm > 350} && {alive _v} && {alive _d}) then {
                    private _geri = (_senk select 2) select {
                        _x isNotEqualTo _v && {alive _x} && {_x getVariable [QGVAR(tasimaMesgul), false]} && {(_x getVariable [QGVAR(yolcuBirak), false]) isEqualTo false} && {(_x distance2D _drop) > (_dm + 250)}
                    };
                    if (_geri isNotEqualTo [] && {_senkT < 90}) then {
                        private _en = 9999;
                        { _en = _en min ((speed _x) / 3.6); } forEach _geri;
                        _d forceSpeed ((_en * 1.15) max 5);
                        _senkT = _senkT + 1;
                        _senkli = true;
                        if ((time - _senkLogT) > 20) then { _senkLogT = time; diag_log format ["[TASIMA] %1 | KONVOY SENKRONU: %2 arac > 250 m geride -> hiz %3 km/s'ya dusuruldu (toplam %4 sn)", groupId _vg, count _geri, round (((_en * 1.15) max 5) * 3.6), _senkT]; };
                    } else {
                        if (_senkli) then { _senkli = false; _d forceSpeed -1; };
                    };
                };
                // v8.169 ILERLEME: inise < 800 m iken 35 sn boyunca mesafe 20 m bile azalmadiysa (yavas surunme hiz esigini sifirlayip kilitliyordu: RPT 59d6c742, 3-6 km/s ile 340-400 m'de dakikalarca) -> hemen in
                if (_bitis isEqualTo "" && {_dm < 800}) then {
                    if (_dm < (_ilerD - 20)) then { _ilerD = _dm; _ilerT = time; } else { if ((time - _ilerT) > 35) then { _bitis = "ilerlemedi"; }; };
                };
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
                else { if (_dm < 45) then { _bitis = "vardi"; }
                else { if (_dm < 180 && {_hz < 1}) then { if (_yakinT < 0) then { _yakinT = time; }; if ((time - _yakinT) > 6) then { _bitis = "vardi"; }; } else { _yakinT = -1; }; }; }; }; }; }; };
                if (_bitis isEqualTo "" && {_gecisT > 0} && {!([_binen, _d] call _temasVar)} && {(time - _gecisT) > 12}) then {
                    diag_log format ["[TASIMA] %1 | pusudan cikildi, normal surus (inise %2 m)", groupId _vg, round _dm];
                    _gecisT = -1;
                    _vg setBehaviour "SAFE";
                };
                // v8.147: MOTOR ZORLAMASI (RPT 16fa2656: Stryker 1-5 "motor false", 35 sn hareketsiz, tek engineOn yetmedi) -> yolda motor kapaliysa surekli ac
                if (_bitis isEqualTo "" && {alive _v} && {!(isEngineOn _v)} && {_dm > 40}) then {
                    _d action ["EngineOn", _v];
                    _v engineOn true;
                    if !(_v getVariable [QGVAR(motorLogT), false]) then {
                        _v setVariable [QGVAR(motorLogT), true];
                        diag_log format ["[TASIMA] %1 | MOTOR KAPALIYDI -> engineOn true zorlandi (%2)", groupId _vg, getText (configOf _v >> "displayName")];
                    };
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
                            // v8.180 DERIN TANI: kalkamayan arac icin tum kosullar (komsu araclar, koltuklar, grup lideri, waypoint, AI ozellikleri, egim, bayraklar)
                            diag_log format ["[TASIMA-TAKILMA] %1 | %2 | koltuklar: surucu %3 / komutan %4 / nisanci %5 | grup lideri %6 (aracta %7) | grup beh %8 mod %9 hiz modu %10 formasyon %11 | waypoint %12 (aktif %13) | AI: AUTOTARGET %14 TARGET %15 FSM %16 AUTOCOMBAT %17 | unitReady %18 | forceSpeed %19 | egim %20 | komsu araclar (<= 20 m): %21 | bayraklar: forceMove %22 yolcuBirak %23 tasimaMesgul %24 isExecutingTactic %25 | hiz vektoru %26",
                                groupId _vg, getText (configOf _v >> "displayName"), name (driver _v), name (commander _v), name (gunner _v), name (leader _vg), (vehicle (leader _vg)) isEqualTo _v,
                                behaviour _d, combatMode _vg, speedMode _vg, formation _vg, count (waypoints _vg), currentWaypoint _vg,
                                _d checkAIFeature "AUTOTARGET", _d checkAIFeature "TARGET", _d checkAIFeature "FSM", _d checkAIFeature "AUTOCOMBAT", unitReady _d, "?",
                                (surfaceNormal (getPosATL _v)) select 2,
                                ((_v nearEntities [["LandVehicle"], 20]) select {_x isNotEqualTo _v}) apply {[typeOf _x, round (_v distance2D _x), round (speed _x)]},
                                _d getVariable [QGVAR(forceMove), false], _v getVariable [QGVAR(yolcuBirak), false], _v getVariable [QGVAR(tasimaMesgul), false], _vg getVariable [QGVAR(isExecutingTactic), false],
                                (velocity _v) apply {round _x}];
                            _d enableAI "PATH"; _d enableAI "MOVE"; _d enableAI "ANIM";
                            _d setVariable [QGVAR(forceMove), true];
                            _v engineOn true;
                            _d forceSpeed -1; doStop _d; _d doMove _drop;
                            _v setVelocityModelSpace [0, 5, 0];
                        };
                        // v8.180: 12 sn - doMove sonuc vermediyse WAYPOINT ile yurut (grup waypoint'i: bazi AI suruculer tekil doMove'u yok sayiyor)
                        if (_denemeN isEqualTo 1 && {_dg > 12} && {!(_v getVariable [QGVAR(wpDenendi), false])}) then {
                            _v setVariable [QGVAR(wpDenendi), true];
                            { if ((waypointName _x) find "ELITE NAKIL" isEqualTo 0) then { deleteWaypoint _x; }; } forEach (reverse (waypoints _vg));
                            private _wpD = _vg addWaypoint [_drop, 0];
                            _wpD setWaypointName "ELITE NAKIL";
                            _wpD setWaypointType "MOVE";
                            _wpD setWaypointSpeed "FULL";
                            _wpD setWaypointBehaviour "SAFE";
                            _vg setCurrentWaypoint _wpD;
                            diag_log format ["[TASIMA] %1 | TAKILMA: doMove sonuc vermedi -> grup WAYPOINT ile yurutuluyor (hedef %2 m)", groupId _vg, round _dm];
                        };
                        if (_denemeN isEqualTo 1 && {_dg > 18}) then {
                            _denemeN = 2;
                            private _alt = (getPosATL _v) getPos [60, (getPosATL _v) getDir _drop];
                            diag_log format ["[TASIMA] %1 | TAKILDI: 18 sn; surucu yeniden oturtuldu + ara noktaya (60 m) yonlendirildi (motor %2)", groupId _vg, isEngineOn _v];
                            // v8.147: AI surucu durumu bozuk olabilir -> koltuktan cikarip tekrar oturt (yolcular yerinde kalir)
                            _d action ["EngineOn", _v];   // v8.184: moveOut / moveIn kaldirildi (surucu gir-cik yapiyordu); koltukta kalir
                            _v engineOn true;
                            _d enableAI "PATH"; _d enableAI "MOVE";
                            _d doMove _alt;
                            _v setVelocityModelSpace [0, 6, 0];
                        };
                        // v8.175: son care - arac hala kimildamadiysa (guc hatti diregi / cit / cukur) 28 sn'de inise dogru bos bir konuma tasinir; boylece 8 askeri 1.4 km geride indirmek yerine yola devam eder
                        if (_denemeN isEqualTo 2 && {_dg > 28} && {_dm > 150}) then {
                            _denemeN = 3;
                            private _sp = [_v, _drop] call _cikisFn;
                            if (_sp isNotEqualTo []) then {
                                private _eskiSp = getPosATL _v;
                                _v setVehiclePosition [_sp, [], 0, "NONE"];
                                _v setDir ((getPosATL _v) getDir _drop);
                                _v engineOn true;
                                _d doMove _drop;
                                diag_log format ["[TASIMA] %1 | TAKILMA SON CARE: arac %2 m uzaktaki bos konuma tasindi (komsulara >= 9 m) (inise %3 m)", groupId _vg, round (_eskiSp distance2D _sp), round _dm];
                            };
                        };
                        // v8.185 SABIR: inise > 800 m kala hala kalkamadiysa askerleri yolun ortasinda indirmek yerine 120 sn'ye kadar dener (itme + waypoint yenileme, 6 sn'de bir); 35 sn'lik eski sinir yalniz inise < 800 m icin
                        if (_dm > 800 && {_dg > 30} && {(time - _itmeT) > 6}) then {
                            _itmeT = time;
                            _d action ["EngineOn", _v];
                            _v engineOn true;
                            _d enableAI "PATH"; _d enableAI "MOVE"; _d forceSpeed -1;
                            _v setVelocityModelSpace [0, 4, 0];
                            private _wpI = _vg addWaypoint [_drop, 0];
                            _wpI setWaypointType "MOVE"; _wpI setWaypointName "ELITE NAKIL"; _wpI setWaypointSpeed "FULL";
                            _vg setCurrentWaypoint _wpI;
                            if (_dg < 40 || {(round _dg) mod 30 < 7}) then {
                                diag_log format ["[TASIMA] %1 | TAKILMA SABIR: %2 sn, inise %3 m - itme + waypoint yenilendi | ezme fren %4 sn once | senkron '%5' (ata %6 sn)", groupId _vg, round _dg, round _dm, round (time - (_v getVariable [QGVAR(ezmeSonT), -999])), _d getVariable [QGVAR(senkDurum), ""], round ((_d getVariable [QGVAR(senkT), 0]) - time)];
                            };
                        };
                        if (_dg > ([35, 120] select (_dm > 800))) then { _bitis = "takildi"; };
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
                    case "ilerlemedi": { format ["35 sn ilerleme yok (inise %1 m kala)", round (_v distance2D _drop)] };
                    case "takildi": { format ["arac TAKILDI (inise %1 m kala)", round (_v distance2D _drop)] };
                    default { "iptal" };
                };
            };
        };

        // v8.169 SU KORUMASI: arac yol disi suyun icindeyse (dere / goletsiz gecit) yolcular suya inmesin; en fazla 25 sn kuru zemine surulur
        if (alive _v && {alive _d} && {surfaceIsWater (getPosATL _v)} && {!(isOnRoad _v)}) then {
            diag_log format ["[TASIMA] %1 | %2 | inis noktasi suda: kuru zemine surulecek (en fazla 25 sn)", groupId _vg, _ad];
            _d enableAI "PATH"; _d enableAI "MOVE"; _d forceSpeed -1;
            _d doMove ((getPosATL _v) getPos [60, _v getDir _drop]);
            private _wt = time + 25;
            waitUntil { sleep 1; !alive _v || {!alive _d} || {!surfaceIsWater (getPosATL _v)} || {time > _wt} };
        };
        // (4) in
        { if ((waypointName _x) find "ELITE NAKIL" isEqualTo 0) then { deleteWaypoint _x; }; } forEach (reverse (waypoints _vg));   // v8.181: nakil waypoint'i inisten sonra arac dusurmesin
        _v setVariable [QGVAR(yolcuBirak), true];
        { if (alive _x) then { _x enableAI "PATH"; }; } forEach _binen;
        doStop _d;
        {
            if (alive _x && {(vehicle _x) isEqualTo _v} && {_x isNotEqualTo _d}) then { unassignVehicle _x; doGetOut _x; };
        } forEach _binen;
        sleep 10;
        { if (alive _x && {(vehicle _x) isEqualTo _v} && {_x isNotEqualTo _d}) then { moveOut _x; }; } forEach _binen;
        sleep 3;
        // v8.187: hala aracta kalan varsa (inemeyen 1-2 asker) tekrar indir + log
        private _kalanIc = _binen select {alive _x && {(vehicle _x) isEqualTo _v} && {_x isNotEqualTo _d}};
        if (_kalanIc isNotEqualTo []) then {
            { unassignVehicle _x; moveOut _x; _x enableAI "PATH"; } forEach _kalanIc;
            diag_log format ["[TASIMA] %1 | INEMEYEN ASKER: %2 kisi 3 sn sonra hala aractaydi -> zorla indirildi: %3", groupId _vg, count _kalanIc, _kalanIc apply {name _x}];
        };
        { if (alive _x) then { _x doFollow (leader (group _x)); }; } forEach _binen;
        call _senkBitti;
        // v8.171 INIS SONRASI TOPLANMA: inenler tum araclar inene kadar (en fazla 75 sn) cevre emniyetiyle COMBAT + comelmis bekler, sonra BIRLIKTE ilerler (kullanici: komutanlar arkada, askerler onden gidiyordu)
        [_binen select {_x isNotEqualTo _d}, _senk, _obj, _v] spawn {
            params ["_ps", "_senk", "_obj", "_v"];
            _ps = _ps select {alive _x && {isNull objectParent _x}};
            if (_ps isEqualTo []) exitWith {};
            private _yon = (getPosATL (_ps select 0)) getDir _obj;
            // v8.174: inenler en yakin siperi / engeli bulup koser (arac onunde yigilmaz, arac ilerleyebilir); siper yoksa aractan >= 18 m uzaklasir; sonra cevre emniyetinde bekler
            private _hedefler = [];
            {
                private _u = _x;
                _u setVariable [QGVAR(tasimaBekle), true];
                _u enableAI "PATH";
                (group _u) setBehaviour "COMBAT";
                // v8.177: aractan >= 25 m (arka / yan / on fark etmez); siper objesi de aractan > 20 m olmali; yoksa 28 m + her askere ayri aci
                private _c = (nearestTerrainObjects [getPosATL _u, ["TREE", "ROCK", "WALL", "BUILDING", "HIDE"], 55, true, true]) select {(_x distance2D _v) > 20};
                private _tp = if (_c isNotEqualTo []) then { (getPosATL (_c select 0)) getPos [2.2, _yon + 180] } else { (getPosATL _u) getPos [28 + (_forEachIndex * 3), (_v getDir _u) + ((_forEachIndex mod 3) - 1) * 30] };
                if (surfaceIsWater _tp || {(_tp distance2D _v) < 22}) then { _tp = (getPosATL _v) getPos [30, (_v getDir _u) + (_forEachIndex * 20)]; };
                if (surfaceIsWater _tp) then { _tp = getPosATL _u; };
                _hedefler pushBack _tp;
                _u setUnitPos "AUTO";
                _u doMove _tp;
            } forEach _ps;
            private _tSiper = time + 18;
            waitUntil { sleep 1; (time > _tSiper) || {({alive _x && {(_x distance2D (_hedefler select (_ps find _x))) > 4}} count _ps) isEqualTo 0} || {(_ps findIf {alive _x && {(time - ((group _x) getVariable [QGVAR(contact), -999])) < 5}}) >= 0} };
            {
                doStop _x;
                _x disableAI "PATH";
                _x setUnitPos "MIDDLE";
                _x doWatch ((getPosATL _x) getPos [150, _yon + ([0, 110, -110] select (_forEachIndex mod 3))]);
            } forEach (_ps select {alive _x});
            diag_log format ["[TASIMA] INIS TOPLANMA: %1 asker cevre emniyetinde bekliyor (inen arac %2 / %3)", count _ps, _senk select 0, _senk select 1];
            private _t0 = time;
            waitUntil {
                sleep 1;
                ((_senk select 0) >= (_senk select 1)) || {(time - _t0) > 75}
                || {(_ps findIf {alive _x && {(time - ((group _x) getVariable [QGVAR(contact), -999])) < 5}}) >= 0}
            };
            diag_log format ["[TASIMA] INIS TOPLANMA bitti: %1 sn | inen arac %2 / %3 -> birlikte ilerleme", round (time - _t0), _senk select 0, _senk select 1];
            {
                if (alive _x) then {
                    _x setVariable [QGVAR(tasimaBekle), nil];
                    _x enableAI "PATH";
                    _x setUnitPos "AUTO";
                    _x doWatch objNull;
                    _x doFollow (leader (group _x));
                };
            } forEach _ps;
        };
        diag_log format ["[TASIMA] %1 | %2 | inen %3 / %4%5", groupId _vg, ["TAMAM", "IPTAL: " + _iptal] select (_iptal isNotEqualTo ""), {alive _x && {(vehicle _x) isNotEqualTo _v}} count _binen, count _binen, ["", " | erken inis: " + _erkenInis] select (_erkenInis isNotEqualTo "")];

        // v8.177 EZILME ONLEME: araci yolcular ARAC CEVRESINDEN (on / arka / yan, 14 m) cikana kadar (en cok 25 sn) hareket ettirme
        if (alive _v) then {
            private _tUz = time + 25;
            waitUntil { sleep 1; (time > _tUz) || {!alive _v} || {({alive _x && {isNull objectParent _x} && {(_x distance2D _v) < 14}} count _binen) isEqualTo 0} };
        };
        // (5) RP'ye don, bekle
        if (alive _v && {alive _d} && {_yakinPusu}) then {
            // yakin pusu: araci terk edilmis birakma, silahci ates etsin (30 sn), sonra don
            _d enableAI "AUTOCOMBAT";
            _vg setBehaviour "COMBAT";
            _vg setCombatMode "RED";
            sleep 30;
            _vg setCombatMode "YELLOW";
        };
        if (alive _v && {alive _d} && {_destekKal} && {_bitis isNotEqualTo "hasar"} && {_iptal isEqualTo ""}) then {
            // RUS bronegruppa: arac inis noktasinda kalir, objektife bakar, piyadeyi ates destegiyle izler (RP'ye donmez)
            doStop _d;
            _d enableAI "AUTOCOMBAT";
            _vg setBehaviour "COMBAT";
            _vg setCombatMode "YELLOW";
            { _x doWatch _obj; } forEach (crew _v);
            diag_log format ["[TASIMA] %1 | BRONEGRUPPA: arac %2 inis noktasinda ates destegi icin kaldi (hedefe %3 m)", groupId _vg, _ad, round (_v distance2D _obj)];
        } else {
        // v8.164 IFV: piyadeyle birlikte savasir; indirdikten sonra geri cekilmez, planin ZIRH DESTEK unsuruna katilir (ates pozisyonu planZirh'te secilir). APC / KAMYON "savas taksisi": geride rezerv.
        private _sinifV = ([_v] call FUNC(aracSinif)) select 0;
        if (_sinifV isEqualTo "IFV" && {_ctl param [6, false]} && {[_vg, "ifvDestek", true] call FUNC(dk)} && {alive _v} && {alive _d} && {_bitis isNotEqualTo "hasar"} && {_iptal isEqualTo ""}) then {
            private _ifvL = _ctl param [5, []];
            _ifvL pushBackUnique _vg;
            _ctl set [5, _ifvL];
            diag_log format ["[TASIMA] %1 | %2 | IFV: piyadeyi indirdi, planin ZIRH DESTEK unsuruna devredildi (ates pozisyonuna cikacak; geri cekilmez)", groupId _vg, _ad];
        } else {
        if (alive _v && {alive _d} && {_bitis isNotEqualTo "hasar"}) then {
            // v8.163: inis sonrasi arac ON HATTA (RP ~ inis noktasi, RPT 69d7f8f5: "apc'ler piyadeyi indirdikleri gibi oylece beklediler") degil, GERIDE REZERV noktasina cekilir
            // (inis noktasindan objektiften uzaga 700 m, yola cekilmis, su disi); medevac / sefer / sonraki nakil icin hazir bekler
            private _geriYon = _obj getDir _drop;
            private _geri = _obj getPos [((_obj distance2D _drop) + 700), _geriYon];
            private _gYol = (_geri nearRoads 250) select {!surfaceIsWater (getPosATL _x) && {(getPosATL _x) distance2D _obj >= ((_obj distance2D _drop) + 450)}};
            if (_gYol isNotEqualTo []) then {
                _gYol = [_gYol, [], {_x distance2D _geri}, "ASCEND"] call BIS_fnc_sortBy;
                _geri = getPosATL (_gYol select 0);
            } else {
                if (surfaceIsWater _geri) then { _geri = _rp; };
            };
            diag_log format ["[TASIMA] %1 | %2 | inis sonrasi geride REZERV noktasina cekiliyor (%3 m, objektiften %4 m)", groupId _vg, _ad, round (_v distance2D _geri), round (_geri distance2D _obj)];
            // v8.177: rezerv noktalari de dagilir - diger araclarin rezerv noktalarina < 45 m ise yan / geri kaydirilir
            private _rzv = _senk select 3;
            private _deneme = 0;
            while {(_rzv findIf {(_x distance2D _geri) < 45}) >= 0 && {_deneme < 8}} do {
                _deneme = _deneme + 1;
                _geri = (_geri getPos [45, _geriYon + 90 + (_deneme * 40)]);
                if (surfaceIsWater _geri) then { _geri = _geri getPos [45, _geriYon]; };
            };
            _rzv pushBack _geri;
            _v setVariable [QGVAR(rezervNokta), _geri];
            _d doMove _geri;
            private _bt2 = time + 240;
            waitUntil { sleep 2; !alive _v || {(_v distance2D _geri) < 60} || {time > _bt2} };
            if (alive _d) then { doStop _d; };
            _v setVariable [QGVAR(aracRezervT), time];
        };
        };
        };
        // v8.176 ARAC DURUM RAPORU (kullanici: "arkada kalan apc'nin neden orada kaldigini yakalayalim"): is sonunda NEDEN + tam durum, sonra park halindeyken 45 sn'de bir (en cok 8 kez) yeniden
        private _sinifSon = ([_v] call FUNC(aracSinif)) select 0;
        private _neden = if (!alive _v || {!alive _d}) then {"arac / surucu yok"} else {
            if (_iptal isNotEqualTo "") then {format ["nakil IPTAL: %1", _iptal]} else {
            if (_bitis isEqualTo "hasar") then {"arac hasarli / hareket edemiyor"} else {
            if (_destekKal) then {"RUS bronegruppa: inis noktasinda destek atesi icin KALDI (tasarim)"} else {
            if (_sinifSon isEqualTo "IFV" && {_ctl param [6, false]}) then {"IFV: planin ZIRH DESTEK unsuruna devredildi, planZirh ates pozisyonuna cikaracak (tasarim)"} else {
                format ["%1 savas taksisi: indirdi, geride REZERV noktasinda bekliyor (tasarim; rezerv %2)", _sinifSon, mapGridPosition (_v getVariable [QGVAR(rezervNokta), getPosATL _v])]
            }}}}};
        [_v, _d, _vg, _obj, _drop, _rp, _neden, _bitis, _erkenInis, _sinifSon, count _binen] spawn {
            params ["_v", "_d", "_vg", "_obj", "_drop", "_rp", "_neden", "_bitis", "_erkenInis", "_sinif", "_n"];
            for "_i" from 0 to 7 do {
                if (!alive _v) exitWith { diag_log format ["[ARAC-DURUM] %1 | arac YOK EDILDI", getText (configOf _v >> "displayName")]; };
                private _dr = driver _v;
                private _fl = [];
                private _plan = (values (missionNamespace getVariable ["lambs_danger_planlar", createHashMap])) select {(_x get "taraf") isEqualTo (side (group _dr)) && {((_x get "obj") distance2D _obj) < 400}};
                private _planFaz = if (_plan isEqualTo []) then {"plan yok"} else {(_plan select 0) getOrDefault ["faz", "?"]};
                private _dostPiyade = (allGroups select {(side _x) isEqualTo (side (group _dr)) && {(count (units _x)) > 2} && {isNull objectParent (leader _x)}}) apply {(leader _x) distance2D _v};
                _dostPiyade sort true;
                if (!isNull _dr) then {
                    _fl = ["tasimaMesgul", "forceMove", "isExecutingTactic", "planAktif", "planZirh", "aracMedevacT", "aracRezervT"] select {((_v getVariable ["lambs_danger_" + _x, objNull]) isNotEqualTo objNull) || {((_dr getVariable ["lambs_danger_" + _x, objNull]) isNotEqualTo objNull)} || {(((group _dr) getVariable ["lambs_danger_" + _x, objNull]) isNotEqualTo objNull)}};
                };
                diag_log format ["[ARAC-DURUM] #%1 %2 (%3) | NEDEN: %4 | bitis '%5' erken inis '%6' | binen %7 | konum %8 | hedefe %9 m, inise %10 m, RP'ye %11 m, en yakin dost piyade %12 m | hiz %13 km/s motor %14 canMove %15 yakit %16 hasar %17 | surucu %18 %19 komut '%20' beh %21 mod %22 hiz modu %23 PATH %24 MOVE %25 | gorev '%26' | bayraklar %27 | plan fazi %28 | rezerv yasi %29 sn",
                    _i, getText (configOf _v >> "displayName"), groupId (group _dr), _neden, _bitis, _erkenInis, _n, mapGridPosition _v,
                    round (_v distance2D _obj), round (_v distance2D _drop), round (_v distance2D _rp), if (_dostPiyade isEqualTo []) then {-1} else {round (_dostPiyade select 0)},
                    round (speed _v), isEngineOn _v, canMove _v, (fuel _v) toFixed 2, (damage _v) toFixed 2,
                    if (isNull _dr) then {"YOK"} else {name _dr}, if (isNull _dr) then {"-"} else {lifeState _dr}, if (isNull _dr) then {""} else {currentCommand _dr}, if (isNull _dr) then {""} else {behaviour _dr}, if (isNull _dr) then {""} else {combatMode (group _dr)}, if (isNull _dr) then {""} else {speedMode (group _dr)},
                    if (isNull _dr) then {false} else {_dr checkAIFeature "PATH"}, if (isNull _dr) then {false} else {_dr checkAIFeature "MOVE"},
                    _v getVariable ["lambs_danger_gorev", ""], _fl, _planFaz, round (time - (_v getVariable [QGVAR(aracRezervT), time]))];
                if ((speed _v) > 3 && {_i > 0}) exitWith {};
                sleep 45;
            };
        };
        if (!isNull _vg) then {
            _vg setVariable [QGVAR(isExecutingTactic), nil];
            _vg setBehaviour _eskiBeh;
            _vg setSpeedMode _eskiHiz;
            _vg setVariable [QGVAR(aracMedevacT), time];
        };
        if (alive _d) then {
            _d forceSpeed -1;
            _d setVariable [QGVAR(forceMove), nil];
            if (_eskiAC) then { _d enableAI "AUTOCOMBAT"; };
        };
        _v setVariable [QGVAR(tasimaMesgul), nil];
        _vg setVariable [QGVAR(tasimaSonT), time];
        [_gl] call _birak;
        call _senkBitti;
        _v setVariable [QGVAR(silahciSon), time + 180];
        count _binen
    });
    { _tasinan = _tasinan + count _x; } forEach _gl;
} forEach _eslesme;

waitUntil { sleep 2; (_isler findIf {!scriptDone _x}) isEqualTo -1 };
// v8.165: is hata ile olursa bekleyen askerler sabit kalmasin
{ { { if (alive _x && {_x getVariable [QGVAR(tasimaBekle), false]}) then { _x setVariable [QGVAR(tasimaBekle), nil]; _x enableAI "PATH"; }; } forEach _x; } forEach (_x select 1); } forEach _eslesme;
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
