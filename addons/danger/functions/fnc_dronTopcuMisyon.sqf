#include "script_component.hpp"
/*
 * Author: Cinar (ELITE fork)
 * DRON GOZLEMLI TOPCU ATISI — bir ates gorevi (v8.338; kullanici: 'uzaktan gorunen dusmanlar icin kitaba uygun dron topcu'). GOZLEM dronu ILERI GOZLEMCI (FO) rolundedir.
 * Sira (kitaptaki cagri-atesi / gozlemli atis akisi; TC 3-21.76 'Call-for-fire', Tablo 3-6):
 *   1) GUVENLIK ON KONTROLU: dost >= RED + 20 m, ates yasak alan (NFA) / sivil yok (fnc_topcuGuvenlik); mermi butcesi; hedef menzilde.            [K: RED, NFA, danger close]
 *   2) CAGRI (call for fire): gozlemci, uyari emri ADJUST FIRE, hedef yeri (grid + gozlemciden yon / mesafe), hedef tanimi (adam / arac / faaliyet), yontem (area fire; DANGER CLOSE?) -> log.   [K: TC 3-21.76 3-11]
 *   3) ADJUST FIRE: TEK TOP, TEK MERMI; mermi dusunce (SPLASH) gozlemci dusme noktasini hedefle karsilastirir, duzeltme verir. En cok 3 mermi. Duzeltme siniri:
 *        normal gorev 400 m; DANGER CLOSE (dost <= 600 m) 'creeping' <= 100 m ve ilk mermi hedefin dosttan UZAK yaninda (bracketing yok).                     [K: danger close, creeping <= 100 m]
 *      Hedefe 'yeterince yakin' esigi = max(60 m, mesafenin %1.2'si) [T] (AI topun kendi dagilimi). Yakinsamazsa (danger close ise veya hata > 150 m) FFE yok.
 *   4) FIRE FOR EFFECT (FFE): menzildeki toplar (en cok 4; danger close ise TEK top x 2 mermi); top basina 3 mermi (60 / 81 mm: 4) [T]; mermiler 'lambs_danger_topcuPartiN' x 'lambs_danger_topcuAralikS' ile paceli
 *      (v8.206 ACE frag dersi). Dagilim: faal alan 30 m, arac iceren hedef 15 m, danger close 12 m [T]. Her mermi oncesi ve FFE oncesi guvenlik + hedef hala orada mi kontrolu ('CHECK FIRING' = vazgec).
 *   5) BDA / END OF MISSION: ates bitince gozlemci kalan dusmani sayar; >= 2 ve ilk sayinin >= %50'si kaldiysa BIR kez REPEAT (kitapta 'REPEAT: bir daha at'); sonra gorev sonu logu.      [K: END OF MISSION + REPEAT]
 * Gozlemci olurse / gorunmez olursa / hedef 80 m'den fazla kayarsa gorev iptal. Gorev sonu: taraf icin bekleme (varsayilan 150 sn; basarisizlikta 20-90 sn), hedef bolgesi 240 sn kilitli.
 * Log: [DRON-TOPCU]. Kapatma: lambs_danger_dronTopcuAktif (CBA) / lambs_danger_dronTopcuOff = true.
 *
 * Arguments:
 * 0: Taraf <SIDE>
 * 1: Gozlemci IHA <OBJECT>
 * 2: Hedef merkezi <ARRAY>
 * 3: Hedef kimligi (log) <STRING>
 *
 * Return Value: Baslatildi mi <BOOL>
 * Public: No
*/

if (!canSuspend) exitWith { _this spawn FUNC(dronTopcuMisyon); true };

params [["_taraf", sideUnknown, [sideUnknown]], ["_fo", objNull, [objNull]], ["_hedef0", [], [[]]], ["_kimlik", "?", [""]]];
if (isNull _fo || {_hedef0 isEqualTo []}) exitWith {false};

private _kKilit = format ["lambs_danger_dtKilit_%1", _taraf];
missionNamespace setVariable [_kKilit, time + 900];
private _t0 = time;
private _sonuc = "?";
private _bekle = 90;
private _atilan = 0;
private _sonA = _hedef0;
private _sonKalan = -1;   // BDA: gozlemlenen kalan dusman (-1 = bilinmiyor)
private _T = +_hedef0;

// gozlemcinin hedef kumesini gorusu: [taze, merkez, deger, adam, arac]
private _yenile = {
    private _gk = _fo getVariable ["lambs_danger_ihaGorulen", [-99, []]];
    private _taze = alive _fo && {(time - (_gk select 0)) < 15};
    private _kl = [(_gk select 1) select {(_x distance2D _T) < 150}, _taraf] call FUNC(topcuKume);
    if (_kl isEqualTo []) then { [_taze, [], 0, 0, 0] } else {
        private _k0 = _kl select 0;
        [_taze, _k0 select 0, _k0 select 2, _k0 select 3, _k0 select 4]
    }
};

call {
    scopeName "ana";

    // ---- 1) guvenlik on kontrolu ----
    private _topcular = [_taraf] call FUNC(topcuListe);
    private _menzilde = _topcular select { _T inRangeOfArtillery [[_x select 0], _x select 1] };
    if (_menzilde isEqualTo []) then { _sonuc = "hedef menzil disi / topcu yok"; _bekle = 60; breakOut "ana"; };
    _menzilde = [_menzilde, [], {(_x select 0) distance2D _T}, "ASCEND"] call BIS_fnc_sortBy;
    { [_x select 0] call FUNC(topcuIzle); } forEach _menzilde;
    private _red = selectMax (_menzilde apply { [_x select 0, _x select 1] call FUNC(topcuRed) });
    ([_taraf, _T, _red] call FUNC(topcuGuvenlik)) params ["_ok", "_neden", "_dF", "_dc", "_fP"];
    if (!_ok) then { _sonuc = format ["guvenlik: %1", _neden]; _bekle = 45; breakOut "ana"; };
    private _butce = missionNamespace getVariable ["lambs_danger_dronTopcuButce", 30];
    if (([_taraf] call FUNC(topcuButce)) >= _butce) then { _sonuc = "mermi butcesi dolu"; _bekle = 60; breakOut "ana"; };
    ([] call _yenile) params ["_taze0", "_c0", "_d0", "_na0", "_nv0"];
    if (!_taze0 || {_c0 isEqualTo []}) then { _sonuc = "hedef gozlemci tarafindan gorulmuyor"; _bekle = 30; breakOut "ana"; };
    _T = +_c0;
    private _bas = _na0 + _nv0;

    // ---- 2) CAGRI (call for fire) ----
    private _yon = (getPosATL _fo) getDir _T;
    diag_log format ["[DRON-TOPCU] %1 | CAGRI (call for fire): gozlemci %2 | UYARI EMRI: ADJUST FIRE | HEDEF YERI: grid %3 (gozlemciden %4 m, yon %5 derece) | HEDEF TANIMI: %6 adam %7 arac, duragan, acik arazi (varsayilan) | YONTEM: alan atesi%8 | topcu: %9 arac menzilde (ilk: %10, %11 m) | en yakin dost %12 m, RED %13 m",
        _kimlik, typeOf _fo, mapGridPosition _T, round ((getPosATL _fo) distance2D _T), round _yon, _na0, _nv0, ["", ", DANGER CLOSE (creeping <= 100 m, bracketing yok)"] select _dc, count _menzilde, typeOf ((_menzilde select 0) select 0), round (((_menzilde select 0) select 0) distance2D _T), round _dF, _red];

    // ---- 3) ADJUST FIRE ----
    private _A = +_T;
    private _cap = 400;
    if (_dc) then {
        _cap = 100;
        _A = _T getPos [100, _fP getDir _T];   // ilk mermi hedefin dosttan UZAK yaninda; sonra hedefe 'creep'
    };
    private _adjV = (_menzilde select 0) select 0;
    private _adjMg = (_menzilde select 0) select 1;
    private _esik = 60 max (0.012 * (_adjV distance2D _T));
    private _hata = 99999;
    private _hazir = false;
    private _n = 0;
    while {_n < 3 && {!_hazir}} do {
        ([] call _yenile) params ["_taze", "_c", "_d", "_na", "_nv"];
        if (!_taze || {_c isEqualTo []}) then { _sonuc = "gozlem kesildi / hedef gorunmuyor (adjust)"; _bekle = 45; breakOut "ana"; };
        if ((_c distance2D _T) > 80) then { _sonuc = format ["hedef kaydi (%1 m) - hareketli hedef icin adjust uygun degil", round (_c distance2D _T)]; _bekle = 20; breakOut "ana"; };
        _A = [(_A select 0) + ((_c select 0) - (_T select 0)), (_A select 1) + ((_c select 1) - (_T select 1)), 0];
        _T = +_c;
        ([_taraf, _A, _red] call FUNC(topcuGuvenlik)) params ["_ok2", "_neden2"];
        if (!_ok2) then { _sonuc = format ["adjust mermisi icin guvenlik: %1", _neden2]; _bekle = 45; breakOut "ana"; };
        if !(_A inRangeOfArtillery [[_adjV], _adjMg]) then { _sonuc = "adjust noktasi menzil disi"; _bekle = 45; breakOut "ana"; };
        _adjV setVariable [QGVAR(dtSplash), []];
        _adjV setVariable [QGVAR(dtIzle), true];
        [_adjV, _A, _adjMg] call FUNC(topcuAtisHazirla);
        _adjV doArtilleryFire [_A, _adjMg, 1];
        _atilan = _atilan + 1;
        _n = _n + 1;
        private _tEnd = time + 45 + ((_adjV getArtilleryETA [_A, _adjMg]) max 8);
        waitUntil { sleep 0.5; ((count (_adjV getVariable [QGVAR(dtSplash), []])) > 0) || {time > _tEnd} || {!alive _adjV} };
        private _sp = _adjV getVariable [QGVAR(dtSplash), []];
        _adjV setVariable [QGVAR(dtIzle), false];
        if (_sp isEqualTo []) then { _sonuc = "adjust mermisi dusmedi / atis yapilmadi"; _bekle = 90; breakOut "ana"; };
        private _spP = _sp select 1;
        if (!alive _fo || {(_fo distance2D _spP) > 2500}) then { _sonuc = "dusme noktasi gozlenemedi (CANNOT OBSERVE)"; _bekle = 60; breakOut "ana"; };
        private _ex = (_spP select 0) - (_T select 0);
        private _ey = (_spP select 1) - (_T select 1);
        _hata = sqrt ((_ex * _ex) + (_ey * _ey));
        private _cx = -_ex;
        private _cy = -_ey;
        private _cl = sqrt ((_cx * _cx) + (_cy * _cy));
        if (_hata <= _esik) then {
            _hazir = true;
            diag_log format ["[DRON-TOPCU] %1 | ADJUST %2/3: SPLASH %3 | hedefe %4 m (esik %5 m) -> YETERLI, duzeltme yok: FIRE FOR EFFECT", _kimlik, _n, mapGridPosition _spP, round _hata, round _esik];
        } else {
            if (_cl > _cap) then { _cx = _cx * _cap / _cl; _cy = _cy * _cap / _cl; };
            _A = [(_A select 0) + _cx, (_A select 1) + _cy, 0];
            diag_log format ["[DRON-TOPCU] %1 | ADJUST %2/3: SPLASH %3 | hedefe %4 m (esik %5 m) -> DUZELTME %6 m yon %7 derece%8", _kimlik, _n, mapGridPosition _spP, round _hata, round _esik, round (sqrt ((_cx * _cx) + (_cy * _cy))), round ([0, 0] getDir [_cx, _cy]), ["", " (creeping <= 100 m)"] select _dc];
        };
    };
    if (!_hazir) then {
        if (_dc || {_hata > 150}) then { _sonuc = format ["adjust yakinsamadi (son hata %1 m%2)", round _hata, ["", ", danger close"] select _dc]; _bekle = 90; breakOut "ana"; };
        diag_log format ["[DRON-TOPCU] %1 | ADJUST: 3 mermide esige girilmedi (son hata %2 m <= 150 m) - alan atesi oldugu icin FFE'ye geciliyor", _kimlik, round _hata];
    };

    // ---- 4) FIRE FOR EFFECT + 5) BDA / REPEAT ----
    _sonuc = "tamam";
    private _tur = 0;
    private _devam = true;
    private _onceki = _bas;
    while {_devam && {_tur < 2}} do {
        ([] call _yenile) params ["_taze", "_c", "_d", "_na", "_nv"];
        if (!_taze || {_c isEqualTo []}) then {
            if (_tur isEqualTo 0) then { _sonuc = "FFE oncesi hedef gorunmuyor (CHECK FIRING)"; _bekle = 45; breakOut "ana"; };
            _devam = false;
        };
        if (_devam) then {
            ([_taraf, _A, _red] call FUNC(topcuGuvenlik)) params ["_ok3", "_neden3"];
            if (!_ok3) then {
                if (_tur isEqualTo 0) then { _sonuc = format ["FFE oncesi guvenlik: %1 (CHECK FIRING)", _neden3]; _bekle = 45; breakOut "ana"; };
                _devam = false;
            };
        };
        if (_devam) then {
            private _ffeV = _menzilde select { _A inRangeOfArtillery [[_x select 0], _x select 1] && {canFire (_x select 0)} };
            _ffeV = _ffeV select [0, [4, 1] select _dc];
            private _mGun = [3, 4] select (_red <= 200);
            if (_dc) then { _mGun = 2; };
            private _toplam = _mGun * (count _ffeV);
            if (_ffeV isEqualTo [] || {([_taraf] call FUNC(topcuButce)) + _toplam > _butce}) then {
                if (_tur isEqualTo 0) then { _sonuc = "FFE icin top / butce yok"; _bekle = 60; breakOut "ana"; };
                _devam = false;
            } else {
                private _yay = [30, 15] select (_nv > 0);
                if (_dc) then { _yay = 12; };
                private _parti = missionNamespace getVariable ["lambs_danger_topcuPartiN", 2];
                private _aralik = missionNamespace getVariable ["lambs_danger_topcuAralikS", 6];
                private _etaMax = 10;
                {
                    _x params ["_tv", "_tm"];
                    [_tv, _A, _tm] call FUNC(topcuAtisHazirla);
                    _etaMax = _etaMax max (_tv getArtilleryETA [_A, _tm]);
                    [_tv, _A, _tm, _mGun, _forEachIndex, _yay, _parti, _aralik] spawn {
                        params ["_tv2", "_tn", "_tm2", "_tk", "_ti", "_ty", "_pa", "_ar"];
                        sleep (2 * _ti);
                        while {_tk > 0 && {alive _tv2} && {canFire _tv2} && {!isNull (gunner _tv2)}} do {
                            private _k = _pa min _tk;
                            _tv2 doArtilleryFire [_tn getPos [random _ty, random 360], _tm2, _k];
                            _tk = _tk - _k;
                            if (_tk > 0) then { sleep _ar; };
                        };
                    };
                } forEach _ffeV;
                _atilan = _atilan + _toplam;
                [_taraf, _toplam] call FUNC(topcuButce);
                _sonA = +_A;
                diag_log format ["[DRON-TOPCU] %1 | %2: %3 top x %4 mermi (alan %5 m, %6) -> %7 | hedef onceki sayim %8 | ilk mermi ETA ~%9 sn | atis noktasi gozlemci duzeltmeli",
                    _kimlik, ["ETKI ATESI (FIRE FOR EFFECT)", "REPEAT (tekrar etki atesi)"] select (_tur > 0), count _ffeV, _mGun, _yay, ["alan atesi", "DANGER CLOSE"] select _dc, mapGridPosition _A, _onceki, round _etaMax];
                sleep (_etaMax + (((ceil (_mGun / _parti)) - 1) * _aralik) + (2 * (count _ffeV)) + 10);

                // BDA
                ([] call _yenile) params ["_taze2", "_c2", "_d2", "_na2", "_nv2"];
                if (!_taze2) then {
                    diag_log format ["[DRON-TOPCU] %1 | BDA: gozlemci gorus disi - sonuc degerlendirilemedi", _kimlik];
                    _devam = false;
                } else {
                    private _kalan = _na2 + _nv2;
                    _sonKalan = _kalan;
                    diag_log format ["[DRON-TOPCU] %1 | BDA: onceki %2 -> kalan %3 (adam %4 arac %5)", _kimlik, _onceki, _kalan, _na2, _nv2];
                    if (_tur isEqualTo 0 && {_kalan >= 2} && {_kalan >= (0.5 * _onceki)}) then {
                        _tur = _tur + 1;
                        _onceki = _kalan;
                        if (_c2 isNotEqualTo []) then { _A = [(_A select 0) + ((_c2 select 0) - (_T select 0)), (_A select 1) + ((_c2 select 1) - (_T select 1)), 0]; _T = +_c2; };
                    } else {
                        _devam = false;
                    };
                };
            };
        };
    };
    _bekle = 150;
};

// ---- gorev sonu ----
missionNamespace setVariable [_kKilit, time + _bekle];
if (_atilan > 0) then {
    private _bolge = (missionNamespace getVariable ["lambs_danger_dtBolge", []]) select {(_x select 1) > time};
    _bolge pushBack [_sonA, time + 240];
    missionNamespace setVariable ["lambs_danger_dtBolge", _bolge];
};
// hedef bolgesi temizlendiyse (BDA: kalan 0) temas bellegindeki o noktayi sil: olu bolgeye taciz atilmaz
if (_atilan > 0 && {_sonKalan isEqualTo 0}) then {
    private _bk = format ["lambs_danger_dtBellek_%1", _taraf];
    missionNamespace setVariable [_bk, (missionNamespace getVariable [_bk, []]) select {((_x select 0) distance2D _sonA) > 150}];
};
diag_log format ["[DRON-TOPCU] %1 | SON (END OF MISSION): %2 | atilan mermi %3 | sure %4 sn | bu taraf icin yeni gorev en erken %5 sn sonra", _kimlik, _sonuc, _atilan, round (time - _t0), _bekle];
true
