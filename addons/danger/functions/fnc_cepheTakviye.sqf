#include "script_component.hpp"
/*
 * Author: Cinar (ELITE fork)
 * CEPHE TAKVIYE — PERSONNEL REPLACEMENT (v8.237, Dilim A0). Yalniz sunucuda. fnc_cepheDongu 30 sn'de bir "TUR" cagirir.
 * Mantik (kullanici karari 10.6 #4: takviye FOB'da DOGMAZ, ARACLA gider):
 *   1) TALEP: canli askeri 'minSquad'in altina dusen squad profili takviye ister (talepT); 'gecikme' sn sonra isleme alinir; squad tam kadroya (hedefBoy) kadar doldurulur.
 *   2) HAK: taraf basina takviye hizi (asker / saat) birikir (token, tavan 40); cephe seridindeki squadlar 'yakin carpani' kadar sik (maliyet = 1 / carpan). Ayni anda en cok 'esZamanli' paket yoldadir.
 *   3) PAKET: rezerv havuzundan (faction) dusulur, olen askerlerin siniflariyla bir TAKVIYE profili (L0) takviye varis noktasinda dogar ve squad'i izleyerek SANAL ilerler (duz cizgi, hizi konvoy hizi;
 *      yol grafi / fiziksel arac konvoyu sonraki dilim — A0'da arac YOK: "suya dusme / arac glitch'i yok" kosulu bu yuzden saglanir, fiziksel konvoy ve gercek ates sonraki dilimde).
 *   4) KONVOY-SANAL: yol boyunca dusmana (profil ya da birim) <= 600 m ise her 30 sn'de uye basina 'konvoyKayip' olasiligi (TASARIM DEGERI) ile soyut zaiyat; zaiyat havuzdan dusulmus kalir.
 *   5) VARIS: paket squad'in 60 m yakinina girince birlesir (squad sanalsa uyeler eklenir; fizikselse yeni askerler squad liderinin 20-30 m gerisinde dogar). Squad yok olduysa paket en yakin dost squad'a yonlenir, yoksa askerler havuza doner.
 *   6) HAVUZ BITINCE (ayar): 0 DEVAM (hicbir sey), 1 BITKIN (squad becerisi x0.85 — fiziksel hale gelirken uygulanir), 2 CEKIL (squad takviye varis noktasina cekilir).
 * Ayar kaynagi: faction paneli (taraf bazli, lambs_danger_cepheTakvAyar) > CBA 'ELITE Cephe Komutani' varsayilani. Tum sayilar TASARIM DEGERIDIR (kitapta yok).
 * Modlar: "TUR" (30 sn'lik hesap), "VARDI" (paket birlesir; arg: paket), "YETIM" (hedefi kaybolan paket; arg: paket).
 * Log: [CEPHE-TAKVIYE] [CEPHE-KONVOY]
 *
 * Arguments:
 * 0: Mod <STRING> (default: "TUR")
 * 1: Paket profili <HASHMAP> (VARDI / YETIM icin)
 *
 * Return Value: None
 * Public: No
*/

params [["_mod", "TUR", [""]], ["_p", createHashMap, [createHashMap]]];

if (!isServer) exitWith {};
call FUNC(cepheInit);

private _ca = { params ["_q"]; {_x get "canli"} count (_q get "uyeler") };
private _ayarOku = {
    params ["_taraf"];
    private _o = lambs_danger_cepheTakvAyar getOrDefault [str _taraf, createHashMap];
    private _g = { params ["_ad", "_def"]; missionNamespace getVariable [format ["lambs_danger_%1", _ad], _def] };
    createHashMapFromArray [
        ["hiz", _o getOrDefault ["hiz", ["cepheTakvHizSaat", 60] call _g]],
        ["gecikme", _o getOrDefault ["gecikme", ["cepheTakvGecikmeS", 300] call _g]],
        ["minSquad", _o getOrDefault ["minSquad", ["cepheMinSquad", 4] call _g]],
        ["esZamanli", _o getOrDefault ["esZamanli", ["cepheTakvEsZamanli", 2] call _g]],
        ["beceri", (_o getOrDefault ["beceri", ["cepheTakvBeceri", 60] call _g]) / 100],
        ["yakin", ((_o getOrDefault ["yakin", ["cepheTakvYakinCarpan", 200] call _g]) / 100) max 0.25],
        ["bitince", _o getOrDefault ["bitince", ["cepheHavuzBitince", 0] call _g]],
        ["konvoyKayip", (_o getOrDefault ["konvoyKayip", ["cepheKonvoyKayip", 5] call _g]) / 100],
        ["konvoyKmh", ["cepheKonvoyKmh", 30] call _g]
    ]
};
private _profiller = lambs_danger_cepheProfiller;

// ---------------------------------------------------------------------------
if (_mod isEqualTo "YETIM") exitWith {
    if (count _p == 0 || {_p getOrDefault ["yok", false]}) exitWith {};
    private _poz = _p get "konum";
    private _adaylar = (values _profiller) select {
        (_x get "tur") isEqualTo "SQUAD" && {!(_x getOrDefault ["yok", false])} && {(_x get "taraf") isEqualTo (_p get "taraf")} && {(_x get "faction") isEqualTo (_p get "faction")}
    };
    private _sirali = [_adaylar, [], {(_x get "konum") distance2D _poz}, "ASCEND"] call BIS_fnc_sortBy;
    if (_sirali isNotEqualTo []) then {
        _p set ["hedefId", (_sirali select 0) get "id"];
        ["TAKVIYE", format ["%1 | hedef squad yok oldu, paket %2 yonlendirildi", _p get "ad", (_sirali select 0) get "ad"]] call FUNC(cepheLog);
    } else {
        private _n = [_p] call _ca;
        private _fh = lambs_danger_cepheFactionlar getOrDefault [_p get "faction", createHashMap];
        _fh set ["rezerv", (_fh getOrDefault ["rezerv", 0]) + _n];
        _p set ["yok", true];
        _profiller deleteAt (_p get "id");
        ["TAKVIYE", format ["%1 | hedef squad yok, alici dost squad yok: %2 asker havuza DONDU (rezerv %3)", _p get "ad", _n, _fh getOrDefault ["rezerv", 0]]] call FUNC(cepheLog);
    };
};

// ---------------------------------------------------------------------------
if (_mod isEqualTo "VARDI") exitWith {
    if (count _p == 0 || {_p getOrDefault ["yok", false]}) exitWith {};
    private _t = _profiller getOrDefault [_p getOrDefault ["hedefId", ""], createHashMap];
    if ((count _t) == 0) exitWith {};
    private _yeniler = (_p get "uyeler") select {_x get "canli"};
    private _beceri = _p getOrDefault ["beceri", -1];
    private _g = _t getOrDefault ["grup", grpNull];
    private _fiziksel = (_t get "seviye") isEqualTo "L1" && {!isNull _g};
    if (_fiziksel) then {
        private _birimler = _t get "birimler";
        private _lider = objNull;
        { if (!isNull _x && {alive _x}) exitWith { _lider = _x; }; } forEach _birimler;
        if (isNull _lider) then { _fiziksel = false; } else {
            {
                private _m = _x;
                private _poz = (getPosATL _lider) getPos [20 + random 10, (getDir _lider) + 180];
                if (surfaceIsWater _poz) then { _poz = getPosATL _lider; };
                _poz resize 3;
                _poz set [2, 0];
                private _u = _g createUnit [_m get "sinif", _poz, [], 0, "NONE"];
                if (!isNull _u) then {
                    if (_beceri >= 0) then { _u setSkill _beceri; };
                    _u setVariable ["lambs_danger_cepheProfilId", _t get "id"];
                    (_t get "uyeler") pushBack _m;
                    _birimler pushBack _u;
                };
            } forEach _yeniler;
        };
    };
    if (!_fiziksel) then {
        // sanal squad: olu kayitlari at, yenileri ekle
        _t set ["uyeler", ((_t get "uyeler") select {_x get "canli"}) + _yeniler];
    };
    private _fh = lambs_danger_cepheFactionlar getOrDefault [_p get "faction", createHashMap];
    _fh set ["takviyeGelen", (_fh getOrDefault ["takviyeGelen", 0]) + (count _yeniler)];
    _p set ["yok", true];
    _profiller deleteAt (_p get "id");
    ["TAKVIYE", format ["VARDI | %1 askerlik paket -> %2 (%3, %4) | squad simdi %5/%6", count _yeniler, _t get "ad", _t get "id", ["sanal", "fiziksel"] select _fiziksel, [_t] call _ca, _t get "hedefBoy"]] call FUNC(cepheLog);
};

// ---------------------------------------------------------------------------
// TUR (30 sn)
private _simdi = time;
private _dt = (_simdi - (missionNamespace getVariable ["lambs_danger_cepheTakvSon", _simdi])) max 0;
lambs_danger_cepheTakvSon = _simdi;

private _tum = values _profiller;
private _squadlar = _tum select {(_x get "tur") isEqualTo "SQUAD" && {!(_x getOrDefault ["yok", false])}};
private _paketler = _tum select {(_x get "tur") isEqualTo "TAKVIYE" && {!(_x getOrDefault ["yok", false])}};
private _taraflar = [west, east, independent];

// (1) konvoy zaiyat zari
{
    private _pk = _x;
    private _ay = [_pk get "taraf"] call _ayarOku;
    private _poz = _pk get "konum";
    private _taraf = _pk get "taraf";
    private _dusman = ((_squadlar findIf { ((_taraf getFriend (_x get "taraf")) < 0.6) && {((_x get "konum") distance2D _poz) <= 600} }) >= 0)
        || {((_poz nearEntities [["CAManBase", "LandVehicle"], 600]) findIf { alive _x && {(_taraf getFriend (side _x)) < 0.6} }) >= 0};
    if (_dusman && {(_ay get "konvoyKayip") > 0}) then {
        private _oldu = 0;
        {
            if ((_x get "canli") && {random 1 < (_ay get "konvoyKayip")}) then { _x set ["canli", false]; _oldu = _oldu + 1; };
        } forEach (_pk get "uyeler");
        if (_oldu > 0) then {
            ["KONVOY", format ["KONVOY-SANAL | %1 | dusman faaliyeti <= 600 m (%2) | %3 zaiyat, %4 kaldi", _pk get "ad", mapGridPosition _poz, _oldu, [_pk] call _ca]] call FUNC(cepheLog);
            if (([_pk] call _ca) isEqualTo 0) then {
                _pk set ["yok", true];
                _profiller deleteAt (_pk get "id");
                ["KONVOY", format ["KONVOY-SANAL | %1 | paket TAMAMEN yok oldu", _pk get "ad"]] call FUNC(cepheLog);
            };
        };
    };
} forEach _paketler;
_paketler = _paketler select {!(_x getOrDefault ["yok", false])};

// (2) taraf bazli talep + tahsis
{
    private _taraf = _x;
    private _ay = [_taraf] call _ayarOku;
    private _anah = str _taraf;
    private _benimSq = _squadlar select {(_x get "taraf") isEqualTo _taraf};
    if (_benimSq isNotEqualTo []) then {
        private _tok = ((lambs_danger_cepheTakvTok getOrDefault [_anah, 0]) + ((_ay get "hiz") * _dt / 3600)) min 40;
        private _benimPk = _paketler select {(_x get "taraf") isEqualTo _taraf};
        private _adaylar = [];
        {
            private _sq = _x;
            private _a = [_sq] call _ca;
            private _bekleyen = 0;
            { if ((_x get "hedefId") isEqualTo (_sq get "id")) then { _bekleyen = _bekleyen + ([_x] call _ca); }; } forEach _benimPk;
            _sq set ["bekleyen", _bekleyen];
            if (_a < (_ay get "minSquad") && {!(_sq getOrDefault ["takvAktif", false])}) then {
                _sq set ["takvAktif", true];
                _sq set ["talepT", _simdi];
                _sq set ["havuzIslendi", false];
                ["TAKVIYE", format ["TALEP | %1 (%2) | canli %3 < min %4, tam kadro %5 | gecikme %6 sn", _sq get "ad", _sq get "id", _a, _ay get "minSquad", _sq get "hedefBoy", _ay get "gecikme"]] call FUNC(cepheLog);
            };
            if ((_sq getOrDefault ["takvAktif", false]) && {(_a + _bekleyen) >= (_sq get "hedefBoy")}) then {
                _sq set ["takvAktif", false];
            };
            if ((_sq getOrDefault ["takvAktif", false]) && {(_simdi - (_sq get "talepT")) >= (_ay get "gecikme")} && {(_a + _bekleyen) < (_sq get "hedefBoy")}) then {
                _adaylar pushBack _sq;
            };
        } forEach _benimSq;

        _adaylar = [_adaylar, [], { (if ((_x getOrDefault ["tier", 0]) >= 2) then {0} else {1}) * 100000 + (_x get "talepT") }, "ASCEND"] call BIS_fnc_sortBy;
        private _aktifPaket = count _benimPk;
        {
            private _sq = _x;
            if (_aktifPaket >= (_ay get "esZamanli")) exitWith {};
            private _fh = lambs_danger_cepheFactionlar getOrDefault [_sq get "faction", createHashMap];
            private _havuz = _fh getOrDefault ["rezerv", 0];
            if (_havuz > 0) then {
                private _maliyet = if ((_sq getOrDefault ["tier", 0]) >= 2) then { 1 / (_ay get "yakin") } else { 1 };
                private _ihtiyac = (_sq get "hedefBoy") - ([_sq] call _ca) - (_sq get "bekleyen");
                private _n = floor (_ihtiyac min (_tok / _maliyet) min _havuz min 12);
                if (_n >= 1) then {
                    private _olu = ((_sq get "uyeler") select {!(_x get "canli")}) apply {_x get "sinif"};
                    private _hepsi = (_sq get "uyeler") apply {_x get "sinif"};
                    private _sinifler = [];
                    for "_i" from 0 to (_n - 1) do {
                        if (_i < (count _olu)) then { _sinifler pushBack (_olu select _i); } else { _sinifler pushBack (_hepsi select (_i mod (count _hepsi))); };
                    };
                    private _varis = lambs_danger_cepheVaris getOrDefault [_anah, _fh getOrDefault ["merkez", _sq get "konum"]];
                    private _pk = [_sq get "faction", _taraf, _sinifler, _varis, "TAKVIYE", [
                        ["hedefId", _sq get "id"], ["hizMs", (_ay get "konvoyKmh") / 3.6], ["beceri", _ay get "beceri"], ["hedef", +(_sq get "konum")], ["ad", format ["Takviye -> %1", _sq get "ad"]]
                    ]] call FUNC(cepheProfilYap);
                    _tok = _tok - (_n * _maliyet);
                    _fh set ["rezerv", _havuz - _n];
                    _aktifPaket = _aktifPaket + 1;
                    private _mesafe = _varis distance2D (_sq get "konum");
                    ["TAKVIYE", format ["YOLDA | %1 asker -> %2 | varis noktasi %3, mesafe %4 m, konvoy %5 km/h, ETA %6 sn | rezerv %7 -> %8 | maliyet %9%10",
                        _n, _sq get "ad", mapGridPosition _varis, round _mesafe, round (_ay get "konvoyKmh"), round (_mesafe / (((_ay get "konvoyKmh") / 3.6) max 0.1)), _havuz, _havuz - _n,
                        (round (_maliyet * 100)) / 100, ["", " (cephe seridi carpani)"] select ((_sq getOrDefault ["tier", 0]) >= 2)]] call FUNC(cepheLog);
                };
            };
        } forEach _adaylar;
        lambs_danger_cepheTakvTok set [_anah, _tok];

        // (3) havuz bitti
        {
            private _sq = _x;
            private _fh = lambs_danger_cepheFactionlar getOrDefault [_sq get "faction", createHashMap];
            if ((_sq getOrDefault ["takvAktif", false]) && {!(_sq getOrDefault ["havuzIslendi", false])} && {(_fh getOrDefault ["rezerv", 0]) <= 0} && {(_sq get "bekleyen") isEqualTo 0}) then {
                _sq set ["havuzIslendi", true];
                switch (_ay get "bitince") do {
                    case 1: {
                        _sq set ["bitkin", true];
                        ["TAKVIYE", format ["HAVUZ BITTI | %1 | BITKIN (beceri x0.85 fiziksel hale gelirken)", _sq get "ad"]] call FUNC(cepheLog);
                    };
                    case 2: {
                        private _v = lambs_danger_cepheVaris getOrDefault [_anah, _fh getOrDefault ["merkez", []]];
                        if (_v isNotEqualTo []) then {
                            _sq set ["hedef", +_v];
                            if ((_sq get "seviye") isEqualTo "L1" && {!isNull (_sq get "grup")}) then {
                                private _wp = (_sq get "grup") addWaypoint [_v, 0];
                                _wp setWaypointType "MOVE";
                            };
                        };
                        ["TAKVIYE", format ["HAVUZ BITTI | %1 | CEKILIYOR (takviye varis noktasina %2)", _sq get "ad", mapGridPosition _v]] call FUNC(cepheLog);
                    };
                    default {
                        ["TAKVIYE", format ["HAVUZ BITTI | %1 | devam (kadro eksik kaliyor)", _sq get "ad"]] call FUNC(cepheLog);
                    };
                };
            };
        } forEach _benimSq;
    };
} forEach _taraflar;
