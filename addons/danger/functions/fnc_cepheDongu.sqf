#include "script_component.hpp"
/*
 * Author: Cinar (ELITE fork)
 * CEPHE DONGUSU (v8.237, Dilim A0) — SANAL / FIZIKSEL (LOD) YONETICISI. Yalniz sunucuda, her cepheTikS sn'de bir (varsayilan 3), yalniz 'lambs_danger_cepheAktif' acikken is yapar.
 * Kullanici kararlari (CEPHE_SIMULASYONU_TASARIM.md 10.6, kilitli):
 *   - Catisma OYUNCU YOKKEN de fiziksel gerceklesir: tetikler oyuncuya bagli DEGIL.
 *   - TIER 3 (zorunlu fiziksel): operasyon alani (aktif plan hedefi + elle alan + temas / ates olay alani), TEMAS (dusman profil / birim cepheTemasMesafe icinde ya da grup temasi).
 *     Tavan icinde HER ZAMAN fiziksel; temasli fiziksel birim tavan asilsa da ASLA sanallanmaz.
 *   - TIER 1 (oyuncu yakin): cephe gerisinde oyuncu cepheFizikYaricap icine girerse fiziksel ("orta sekeri ben ayarlayacagim"); cikis icin x1.3 histerezis.
 *   - TIER 2 (cephe seridi): en yakin dusman profile cepheSeritMesafe icinde; seridin cepheSeritOran kadari fiziksel, cepheSeritTazeleS'de bir dondurulur ("seyrek tazeleme").
 *   - TIER 0: sanal (veri); hedefi varsa duz cizgide cepheSanalHizKmh ile ilerler (yol grafi / arazi ajani sonraki dilim).
 *   - Tavan: cepheFizikMaks (ASKER; varsayilan 300). Tavan asilirsa once uzak ve temassiz fiziksel profiller sanallanir. Yeni tier-3 profil tavana sigmazsa sanal kalir, ayni
 *     bolgede dusman sanal profille temas halindeyse SOYUT CATISMA ile cozulur (cepheSoyutCatisma; 30 sn'de bir, TASARIM DEGERI kayip orani).
 *   - Histerezis: sanallanmak icin tetik yokken cepheDespawnBeklemeS sn gecmeli ve fiziksel kalis >= cepheMinFizikS olmali (acilip kapanma olmasin).
 *   - KILIT (sanallanmaz): elle kilit, aktif plan grubu (planAktif), grupta oyuncu, aracta, baygin / tedavide asker.
 *   - Zeus'la ELLE konan birimler profile girmez; yalniz temas / yakinlik hesabinda dusman olarak sayilir.
 * Durum kaynagi: simulasyon altyapisinin gercek konumlari (komutan zekasi DEGIL; komutan "hile yok" ilkesi ayri katmanda uygulanir).
 * 30 sn'de bir fnc_cepheTakviye (Personnel Replacement), 60 sn'de bir [CEPHE-OZET] satiri. Bekci: betik olurse yeniden baslar ([WATCHDOG-YENIDEN]).
 * Kapatma: CBA 'ELITE Cephe Komutani > Aktif' ya da lambs_danger_cepheAktif = false (hicbir profil silinmez, yalniz dongu durur).
 *
 * Arguments: None
 * Return Value: Baslatildi mi <BOOL>
 * Public: No
*/

if (!isServer) exitWith {false};
if (!isNil "lambs_danger_cepheDonguStarted") exitWith {false};
lambs_danger_cepheDonguStarted = true;
call FUNC(cepheInit);

diag_log "[CEPHE] cephe dongusu (sanal / fiziksel LOD) baslatildi (v8.237, Dilim A0); CBA 'ELITE Cephe Komutani > Aktif' ya da faction paneli ile acilir";

private _calis = {
    private _ayar = { params ["_ad", "_def"]; missionNamespace getVariable [format ["lambs_danger_%1", _ad], _def] };
    private _ca = { params ["_p"]; {_x get "canli"} count (_p get "uyeler") };
    private _tSon = time;
    private _tOzet = time;
    private _tTakv = time;
    private _tSoyut = time;
    private _sayFizikle = 0;
    private _saySanalla = 0;
    private _sayBlok = 0;
    private _taraflar = [west, east, independent];

    while {true} do {
        sleep (1 max (["cepheTikS", 3] call _ayar));
        private _simdi = time;
        private _dt = (_simdi - _tSon) min 30;
        _tSon = _simdi;
        if !(["cepheAktif", false] call _ayar) then { continue };
        missionNamespace setVariable ["lambs_danger_cepheAdim", "basladi"];

        private _profiller = lambs_danger_cepheProfiller;
        private _fhHash = lambs_danger_cepheFactionlar;
        private _tum = values _profiller;
        if (_tum isEqualTo []) then { continue };

        private _fizikYaricap = ["cepheFizikYaricap", 1500] call _ayar;
        private _fizikMaks = ["cepheFizikMaks", 300] call _ayar;
        private _temasM = ["cepheTemasMesafe", 1200] call _ayar;
        private _seritM = ["cepheSeritMesafe", 3000] call _ayar;
        private _seritOran = (["cepheSeritOran", 35] call _ayar) / 100;
        private _seritTazeleS = ["cepheSeritTazeleS", 300] call _ayar;
        private _opYar = ["cepheOpYaricap", 800] call _ayar;
        private _minFizikS = ["cepheMinFizikS", 90] call _ayar;
        private _despawnBekleS = ["cepheDespawnBeklemeS", 60] call _ayar;
        private _tikSpawn = 1 max (["cepheTikSpawn", 3] call _ayar);
        private _hizMs = (["cepheSanalHizKmh", 4] call _ayar) / 3.6;

        // ---- A) fizikselleri profile esitle (konum, kayip), yok olanlari kaldir ----
        missionNamespace setVariable ["lambs_danger_cepheAdim", "senkron"];
        {
            private _p = _x;
            if ((_p get "seviye") isEqualTo "L1") then {
                private _uyeler = _p get "uyeler";
                private _canli = [];
                {
                    private _m = _uyeler select _forEachIndex;
                    if (_m get "canli") then {
                        if (isNull _x || {!alive _x}) then {
                            _m set ["canli", false];
                            private _fh = _fhHash getOrDefault [_p get "faction", createHashMap];
                            _fh set ["olu", (_fh getOrDefault ["olu", 0]) + 1];
                        } else {
                            _canli pushBack _x;
                        };
                    };
                } forEach (_p get "birimler");
                if (_canli isEqualTo []) then {
                    _p set ["yok", true];
                } else {
                    private _lider = _canli select 0;
                    _p set ["konum", getPosATL _lider];
                    _p set ["yon", getDir _lider];
                    private _h = _p get "hedef";
                    if (_h isNotEqualTo [] && {(_lider distance2D _h) < 40}) then { _p set ["hedef", []]; };
                };
            };
        } forEach _tum;
        {
            if (_x getOrDefault ["yok", false]) then {
                private _g = _x getOrDefault ["grup", grpNull];
                if (!isNull _g && {(count (units _g)) isEqualTo 0}) then { deleteGroup _g; };
                _profiller deleteAt (_x get "id");
                ["YOK", format ["%1 (%2) | profil yok edildi (tum uyeler oldu) | %3 | %4", _x get "ad", _x get "id", _x get "tur", mapGridPosition (_x get "konum")]] call FUNC(cepheLog);
            };
        } forEach _tum;
        _tum = _tum select {!(_x getOrDefault ["yok", false])};
        if (_tum isEqualTo []) then { continue };

        // ---- B) baglam: oyuncular, operasyon alanlari, taraf konumlari ----
        missionNamespace setVariable ["lambs_danger_cepheAdim", "baglam"];
        private _oyuncular = (allPlayers select {alive _x && {!(_x isKindOf "VirtualMan_F")}}) apply { getPosATL _x };
        private _opAlan = [];
        {
            if !((_y getOrDefault ["faz", ""]) in ["BITTI", "IPTAL"]) then { _opAlan pushBack [_y get "obj", _opYar]; };
        } forEach (missionNamespace getVariable ["lambs_danger_planlar", createHashMap]);
        { _opAlan pushBack [_x select 0, _x select 1]; } forEach (missionNamespace getVariable ["lambs_danger_cepheOpAlanlari", []]);
        lambs_danger_cepheOlayAlani = lambs_danger_cepheOlayAlani select {(_x select 2) > _simdi};
        { _opAlan pushBack [_x select 0, _x select 1]; } forEach lambs_danger_cepheOlayAlani;

        private _squadlar = _tum select {(_x get "tur") isEqualTo "SQUAD"};
        private _yan = createHashMap;
        {
            private _k = str (_x get "taraf");
            private _l = _yan getOrDefault [_k, []];
            _l pushBack (_x get "konum");
            _yan set [_k, _l];
        } forEach _squadlar;
        private _dusmanPoz = createHashMap;
        {
            private _s = _x;
            private _l = [];
            { if ((_s getFriend _x) < 0.6) then { _l append (_yan getOrDefault [str _x, []]); }; } forEach _taraflar;
            _dusmanPoz set [str _s, _l];
        } forEach _taraflar;

        // ---- C) her profil icin tier + kilit ----
        missionNamespace setVariable ["lambs_danger_cepheAdim", "tier"];
        private _t3 = [];
        private _t2 = [];
        private _t1 = [];
        {
            private _p = _x;
            private _poz = _p get "konum";
            private _taraf = _p get "taraf";
            private _l1 = (_p get "seviye") isEqualTo "L1";
            private _grp = _p get "grup";
            private _dO = 1e9;
            { private _d = _poz distance2D _x; if (_d < _dO) then { _dO = _d; }; } forEach _oyuncular;
            private _dD = 1e9;
            { private _d = _poz distance2D _x; if (_d < _dD) then { _dD = _d; }; } forEach (_dusmanPoz getOrDefault [str _taraf, []]);
            private _tm = _temasM * ([1, 1.5] select _l1);
            private _temas = _dD < _tm;
            if (!_temas) then {
                _temas = ((_poz nearEntities [["CAManBase", "LandVehicle"], _tm]) findIf { alive _x && {(_taraf getFriend (side _x)) < 0.6} }) >= 0;
            };
            if (!_temas && {_l1} && {!isNull _grp}) then {
                _temas = (_grp getVariable ["lambs_danger_contact", 0]) > _simdi;
            };
            private _op = (_opAlan findIf {(_poz distance2D (_x select 0)) < (_x select 1)}) >= 0;
            private _rO = _fizikYaricap * ([1, 1.3] select _l1);
            private _tier = 0;
            private _ad = "";
            if (_temas || _op) then {
                _tier = 3;
                _ad = ["OPERASYON", "TEMAS"] select _temas;
            } else {
                if (_dO < _rO) then {
                    _tier = 1;
                    _ad = "OYUNCU-YAKIN";
                } else {
                    if (_dD < _seritM) then { _tier = 2; _ad = "CEPHE-SERIDI"; };
                };
            };
            private _pin = _p getOrDefault ["kilit", false];
            if (_l1 && {!_pin}) then {
                _pin = (!isNull _grp && {_grp getVariable ["lambs_danger_planAktif", false]})
                    || {((_p get "birimler") findIf {
                        !isNull _x && {alive _x} && {
                            isPlayer _x || {(vehicle _x) isNotEqualTo _x} || {(lifeState _x) isEqualTo "INCAPACITATED"}
                            || {_x getVariable ["ACE_isUnconscious", false]} || {(_x getVariable ["lambs_danger_tcccBusy", 0]) > _simdi}
                        }
                    }) >= 0};
            };
            _p set ["tier", _tier];
            _p set ["tetikAd", _ad];
            _p set ["dOyuncu", _dO];
            _p set ["dDusman", _dD];
            _p set ["pin", _pin];
            switch (_tier) do {
                case 3: { _t3 pushBack _p; };
                case 2: { _t2 pushBack _p; };
                case 1: { _t1 pushBack _p; };
                default {};
            };
        } forEach _squadlar;

        // ---- D) fiziksel kume secimi (tavan butcesi: ASKER) ----
        missionNamespace setVariable ["lambs_danger_cepheAdim", "secim"];
        private _secilen = createHashMap;
        private _kul = 0;
        {
            _secilen set [_x get "id", true];
            _kul = _kul + ([_x] call _ca);
        } forEach (_squadlar select {(_x get "seviye") isEqualTo "L1" && {_x get "pin"}});

        private _sirala = {
            params ["_liste"];
            [_liste, [], { (if ((_x get "seviye") isEqualTo "L1") then {0} else {1}) * 1000000 + (_x getOrDefault ["dOyuncu", 1e9]) }, "ASCEND"] call BIS_fnc_sortBy
        };
        // tier 3: fiziksel olan HER ZAMAN kalir; yeni olan tavana sigarsa
        {
            if !((_x get "id") in _secilen) then {
                private _n = [_x] call _ca;
                if ((_x get "seviye") isEqualTo "L1" || {(_kul + _n) <= _fizikMaks}) then {
                    _secilen set [_x get "id", true];
                    _kul = _kul + _n;
                } else {
                    _sayBlok = _sayBlok + 1;
                    _x set ["capBlok", _simdi];
                };
            };
        } forEach ([_t3] call _sirala);
        // tier 1 (oyuncu yakin)
        {
            if !((_x get "id") in _secilen) then {
                private _n = [_x] call _ca;
                if ((_kul + _n) <= _fizikMaks) then { _secilen set [_x get "id", true]; _kul = _kul + _n; };
            };
        } forEach ([_t1] call _sirala);
        // tier 2 (cephe seridi): kota + tazeleme (tazeligi dolan fiziksel profil siranin sonuna gider)
        private _kota = ceil (_seritOran * (count _t2));
        private _sera = [_t2, [], {
            private _o = _x getOrDefault ["dOyuncu", 1e9];
            if ((_x get "seviye") isEqualTo "L1") then {
                if ((_simdi - (_x get "tFizik")) < _seritTazeleS) then { _o } else { 2000000 + _o }
            } else { 1000000 + _o }
        }, "ASCEND"] call BIS_fnc_sortBy;
        {
            if (_forEachIndex >= _kota) exitWith {};
            if !((_x get "id") in _secilen) then {
                private _n = [_x] call _ca;
                if ((_kul + _n) <= _fizikMaks) then { _secilen set [_x get "id", true]; _kul = _kul + _n; };
            };
        } forEach _sera;

        // ---- E) sanallama (tetik yok + bekleme; tavan asimi) ----
        missionNamespace setVariable ["lambs_danger_cepheAdim", "sanalla"];
        private _sanalAday = [];
        {
            if ((_x get "seviye") isEqualTo "L1") then {
                if ((_x get "id") in _secilen) then {
                    _x set ["tSon", _simdi];
                } else {
                    if (!(_x get "pin") && {(_simdi - (_x get "tFizik")) >= _minFizikS} && {(_simdi - (_x get "tSon")) >= _despawnBekleS}) then {
                        _sanalAday pushBack [_x, "tetik yok (bekleme doldu)"];
                    };
                };
            };
        } forEach _squadlar;
        // tavan: sanallananlar dusunce hala fazlaysa uzak + temassiz + kilitsiz olanlari zorla sanalla
        private _fizikKalan = 0;
        {
            private _pp = _x;
            if ((_pp get "seviye") isEqualTo "L1" && {(_sanalAday findIf {(_x select 0) isEqualTo _pp}) < 0}) then { _fizikKalan = _fizikKalan + ([_pp] call _ca); };
        } forEach _squadlar;
        if (_fizikKalan > _fizikMaks) then {
            private _zorlaAday = [];
            {
                private _pp = _x;
                if ((_pp get "seviye") isEqualTo "L1" && {!(_pp get "pin")} && {(_pp get "tier") < 3} && {(_simdi - (_pp get "tFizik")) >= 20}
                    && {(_sanalAday findIf {(_x select 0) isEqualTo _pp}) < 0}) then { _zorlaAday pushBack _pp; };
            } forEach _squadlar;
            private _zorla = [_zorlaAday, [], {_x getOrDefault ["dOyuncu", 1e9]}, "DESCEND"] call BIS_fnc_sortBy;
            {
                if (_fizikKalan <= _fizikMaks) exitWith {};
                _sanalAday pushBack [_x, "tavan asildi (uzak profil)"];
                _fizikKalan = _fizikKalan - ([_x] call _ca);
            } forEach _zorla;
        };
        private _ds = 0;
        {
            if (_ds >= 6) exitWith {};
            if ([_x select 0, _x select 1] call FUNC(cepheSanalla)) then { _ds = _ds + 1; _saySanalla = _saySanalla + 1; };
        } forEach _sanalAday;

        // ---- F) fizikselleme (tier ve yakinliga gore, tikta en cok _tikSpawn; temas / operasyon 3 kat) ----
        missionNamespace setVariable ["lambs_danger_cepheAdim", "fizikle"];
        private _fizikAday = [_squadlar select {(_x get "seviye") isEqualTo "L0" && {(_x get "id") in _secilen}}, [], { (-1000000 * (_x get "tier")) + (_x getOrDefault ["dOyuncu", 1e9]) }, "ASCEND"] call BIS_fnc_sortBy;
        private _ns = 0;
        {
            private _tier = _x get "tier";
            if (_ns >= (_tikSpawn * ([1, 3] select (_tier isEqualTo 3)))) exitWith {};
            private _dO = _x get "dOyuncu";
            private _neden = format ["%1 | oyuncu %2 m | dusman %3 m", _x get "tetikAd", [round _dO, "yok"] select (_dO > 1e8), [round (_x get "dDusman"), "yok"] select ((_x get "dDusman") > 1e8)];
            if ([_x, _neden] call FUNC(cepheFizikle)) then { _ns = _ns + 1; _sayFizikle = _sayFizikle + 1; };
        } forEach _fizikAday;

        // ---- G) sanal hareket (duz cizgi; TAKVIYE paketleri hedef squad'i izler ve varinca birlesir) ----
        missionNamespace setVariable ["lambs_danger_cepheAdim", "hareket"];
        {
            private _p = _x;
            if ((_p get "seviye") isEqualTo "L0" && {!(_p getOrDefault ["yok", false])}) then {
                if ((_p get "tur") isEqualTo "TAKVIYE") then {
                    private _t = _profiller getOrDefault [_p getOrDefault ["hedefId", ""], createHashMap];
                    if ((count _t) > 0) then {
                        _p set ["hedef", +(_t get "konum")];
                        if (((_p get "konum") distance2D (_t get "konum")) < 60) then { ["VARDI", _p] call FUNC(cepheTakviye); };
                    } else {
                        ["YETIM", _p] call FUNC(cepheTakviye);
                    };
                };
                private _h = _p get "hedef";
                if (_h isNotEqualTo [] && {!(_p getOrDefault ["yok", false])}) then {
                    private _v = _p getOrDefault ["hizMs", 0];
                    if (_v <= 0) then { _v = _hizMs; };
                    private _poz = _p get "konum";
                    private _d = _poz distance2D _h;
                    if (_d <= 12) then {
                        _p set ["hedef", []];
                    } else {
                        private _yeni = _poz getPos [(_v * _dt) min _d, _poz getDir _h];
                        if (surfaceIsWater _yeni) then {
                            _p set ["hedef", []];
                            ["HATA", format ["%1 (%2) | sanal hareket SUYA denk geldi, hedef iptal (yol grafi arazi ajaninda, sonraki dilim) | %3", _p get "ad", _p get "id", mapGridPosition _poz]] call FUNC(cepheLog);
                        } else {
                            _p set ["konum", _yeni];
                            _p set ["yon", _poz getDir _h];
                        };
                    };
                };
            };
        } forEach _tum;

        // ---- H) soyut catisma (tavan yuzunden sanal kalan temaslar; 30 sn'de bir) ----
        if ((_simdi - _tSoyut) >= 30) then {
            _tSoyut = _simdi;
            if (["cepheSoyutCatisma", true] call _ayar) then {
                missionNamespace setVariable ["lambs_danger_cepheAdim", "soyut"];
                private _mesafe = ["cepheSoyutMesafe", 500] call _ayar;
                private _l0 = _squadlar select {(_x get "seviye") isEqualTo "L0"};
                private _blokluk = _l0 select {(_simdi - (_x getOrDefault ["capBlok", -1000000])) < 40};
                private _islendi = createHashMap;
                {
                    private _a = _x;
                    {
                        private _b = _x;
                        private _ids = [_a get "id", _b get "id"];
                        _ids sort true;
                        private _anah = _ids joinString "|";
                        if !(_anah in _islendi) then {
                            if (((_a get "taraf") getFriend (_b get "taraf")) < 0.6 && {((_a get "konum") distance2D (_b get "konum")) <= _mesafe}) then {
                                _islendi set [_anah, true];
                                private _na = [_a] call _ca;
                                private _nb = [_b] call _ca;
                                // TASARIM DEGERI: 30 sn'de karsi tarafin canli mevcudunun en cok %15'i (rastgele)
                                private _kayipA = round ((random 0.15) * _nb);
                                private _kayipB = round ((random 0.15) * _na);
                                {
                                    _x params ["_prof", "_k"];
                                    private _canlilar = (_prof get "uyeler") select {_x get "canli"};
                                    for "_i" from 1 to (_k min (count _canlilar)) do {
                                        private _m = selectRandom ((_prof get "uyeler") select {_x get "canli"});
                                        _m set ["canli", false];
                                        private _fh = _fhHash getOrDefault [_prof get "faction", createHashMap];
                                        _fh set ["olu", (_fh getOrDefault ["olu", 0]) + 1];
                                    };
                                    if (([_prof] call _ca) isEqualTo 0) then { _prof set ["yok", true]; };
                                } forEach [[_a, _kayipA], [_b, _kayipB]];
                                ["SOYUT", format ["%1 (%2 -> -%3) <-> %4 (%5 -> -%6) | tavan yuzunden sanal temas, mesafe %7 m", _a get "ad", _na, _kayipA, _b get "ad", _nb, _kayipB, round ((_a get "konum") distance2D (_b get "konum"))]] call FUNC(cepheLog);
                            };
                        };
                    } forEach _l0;
                } forEach _blokluk;
            };
        };

        // ---- I) Personnel Replacement (30 sn) ----
        if ((_simdi - _tTakv) >= 30) then {
            _tTakv = _simdi;
            missionNamespace setVariable ["lambs_danger_cepheAdim", "takviye"];
            ["TUR"] call FUNC(cepheTakviye);
        };

        // ---- J) ozet (60 sn) ----
        if ((_simdi - _tOzet) >= 60) then {
            _tOzet = _simdi;
            private _sq = values lambs_danger_cepheProfiller;
            private _sqS = _sq select {(_x get "tur") isEqualTo "SQUAD"};
            private _fizikAskerOzet = 0;
            private _toplamAsker = 0;
            { private _n = [_x] call _ca; _toplamAsker = _toplamAsker + _n; if ((_x get "seviye") isEqualTo "L1") then { _fizikAskerOzet = _fizikAskerOzet + _n; }; } forEach _sqS;
            private _yanSatir = [];
            {
                private _s = _x;
                private _pr = _sqS select {(_x get "taraf") isEqualTo _s};
                if (_pr isNotEqualTo []) then {
                    private _a = 0;
                    private _f = 0;
                    { private _n = [_x] call _ca; _a = _a + _n; if ((_x get "seviye") isEqualTo "L1") then { _f = _f + _n; }; } forEach _pr;
                    _yanSatir pushBack format ["%1 %2 squad %3 asker (fiz %4)", _s, count _pr, _a, _f];
                };
            } forEach _taraflar;
            diag_log format [
                "[CEPHE-OZET] t=%1 | profil %2 (L0 %3 / L1 %4 / takviye-paketi %5) | fiziksel asker %6/%7 (toplam canli %8) | tier3 %9 oyuncu %10 serit %11 | son 60 sn: fizikle %12 sanalla %13 tavan-blok %14 | oyuncu %15 | %16",
                round _simdi, count _sq, {(_x get "seviye") isEqualTo "L0" && {(_x get "tur") isEqualTo "SQUAD"}} count _sq, {(_x get "seviye") isEqualTo "L1"} count _sq,
                {(_x get "tur") isEqualTo "TAKVIYE"} count _sq, _fizikAskerOzet, _fizikMaks, _toplamAsker,
                count _t3, count _t1, count _t2, _sayFizikle, _saySanalla, _sayBlok, count _oyuncular, _yanSatir joinString " | "
            ];
            _sayFizikle = 0;
            _saySanalla = 0;
            _sayBlok = 0;
        };
        missionNamespace setVariable ["lambs_danger_cepheAdim", "tur bitti"];
    };
};

// bekci: betik hata ile olurse yeniden baslat
[_calis] spawn {
    params ["_fn"];
    while {true} do {
        private _h = [] spawn _fn;
        waitUntil { sleep 5; scriptDone _h };
        diag_log format ["[WATCHDOG-YENIDEN] cephe dongusu betigi sonlandi (hata?), son adim: %1", missionNamespace getVariable ["lambs_danger_cepheAdim", "?"]];
        sleep 5;
    };
};

true
