#include "script_component.hpp"
/*
 * Author: Cinar (ELITE fork)
 * KARAKOL GARNIZONU (v8.130) — kullanici: "karakol tutan adamlar apc ve nobet tutabilirler, onemli pozisyonlara; LAMBS garrison ile uyumlu ama komutan karar versin, Zeus mudahalesinde bozulmasin;
 * ust katlar ve patrol alt gruplari olusturma, tekrar tekrar duzeltilebilsin ve yeni birim eklenebilsin sisteme".
 *
 * Zeus 'ELITE Karakol Garnizon' modulu bir KARAKOL (ELITE Karakol / HQ) icin su ayari tutar: nobetci sayisi, devriye grup sayisi + boyu, ust kat / cati pozisyonlari, araclarin mevzi olarak kullanimi.
 * Bu bekci SUNUCUDA 15 sn'de bir ayari uygular; modul tekrar calistirilinca ayar ve pozisyonlar yeniden hesaplanir (eski nobet / devriye bozulur, birimler orijinal gruplarina doner).
 *
 * HAVUZ: karakolun yaricap x1.5 icindeki ayni taraf AI piyadeleri (oyuncusuz grup, aracta degil, bayilmamis). Yeni eklenen birimler (Zeus'tan konan / gelen) bir sonraki turda havuza girer ve eksik nobet / devriyeyi tamamlar.
 *   Nobetci secimi: tufekci / nisanci once, lider / hekim / MG / AT en son; pozisyona en yakin.
 * NOBET POZISYONLARI (komutan karar verir; LAMBS rastgele garrison'u degil): (1) ust kat: karakol yaricapindaki binalarin >= 2.5 m yuksekteki en yuksek ic pozisyonu (buildingPos); skor = yukseklik x3 + dis cephe gorusu (8 isin 120 m) x4;
 *   (2) arazi: yaricapin %50-%80'inde 30 derecelik halka, yukseklik x2 + gorus x4. Secim: en yuksek skor + onceki pozisyonlardan uzaklik (en fazla 60 m x 0.6) - her yone dagilir; min aralik 18 m.
 *   Nobetci pozisyona gider (doMove), 3 m icinde PATH kapatilir (yerinde kalir), dis yone doWatch; 120 sn'de varamazsa pozisyona isinlanir (merdiven takilmasi).
 * v8.400: AKILLI / PLANLI DEVRIYE (CBA devAkilli; fnc_devriyeAg: sektor + kademeli tur takvimi + ortak resim) + DEVRIYE AGI (fnc_devriyeHaber: temas raporu paylasimi, destek yonlendirme); IHA yoklugunun nedeni log'a yazilir.
 * v8.399: ANTI-AIR (ayar aa; fnc_aaSinif): MANPADS tasiyan askerler ayri AA nobet noktalarina (acik gokyuzu + yukseklik + 55 m aralik, en cok 3), SPAAG araclari ic halkaya (yaricap %50), STATIK AA (ZU-23 vb.) yerinde kalir.
 * v8.398: IHA GOZLEM (ayar ihaMod / ihaYar / ihaSure / ihalar): karakolun merkezinde gozlem devriyesi atan bosta IHA (surekli ya da yalniz alarmda).
 * v8.397: TAKIM SECIMI (ayar gruplar; Zeus panel fnc_garnizonTakimSec / 3DEN 'Secim modu = takim'): yalniz secilen takimlar garnizona asker verir (yaricap kurali yok; kaynak takimda en az 3 asker kalir).
 * v8.394: ELLE ASKER SECIMI (ayar uyeler; Zeus panel fnc_garnizonAskerSec / 3DEN SYNC) havuzu yalniz secilen askerlere indirir; DEVRIYE MESAFESI (ayar devMes, 0 = karakol yaricapinin %60i) devriye halkasinin merkezden uzakligidir.
 * DEVRIYE (v8.400 akilli mod: sektor turlari, bkz fnc_devriyeAg; eski halka rotasi CBA devAkilli kapaliyken): alt gruplar (devriye boyu 2-6), karakolun %60 yaricapinda (v8.394: devMes ile ayarlanir) halka rotasi (CYCLE), AWARE / LIMITED / STAG COLUMN; temas / alarm olunca (grup temasi < 30 sn) rota kesilir, en yakin cevre noktasina savunmaya gecer, 120 sn temassizsa devam.
 * ARACLAR: karakol icindeki AI surucu + yerel kara araclari (APC / IFV / kamyon) cevrede %75 yaricapta ates mevzisine gider (tehdit yonu bilinmiyorsa esit dagilir), PATH kapatilir, mürettebat icinde kalir; gorev 'KARAKOL_ARAC'.
 * v8.385: 3DEN 'ELITE Catisma Pozisyonu' modulleri (bina ici / cati / ates mevzii; garnizon bayragi acik) karakol yaricapi x1.2 icinde NOBET ADAYI olur ve dogal adaylara oncelikli (skor 120 + puan x 12; modulun sabit durusu ve rol tercihi nobette uygulanir).
 * Altgruplar: grup degiskeni lambs_danger_garnizonAlt (NOBET / DEVRIYE) -> plan / taksi / tasima onlari almaz. Birim degiskeni lambs_danger_garnizonOrijin = eski grup (kaldirinca geri doner).
 * Kapatma: lambs_danger_garnizonOff = true.  Log: [KARAKOL-GARNIZON] (+ 60 sn ozet).
 *
 * Arguments: None
 * Return Value: Baslatildi mi <BOOL>
 * Public: No
*/

if (!isServer) exitWith {false};
if (!isNil "lambs_danger_garnizonStarted") exitWith {false};
lambs_danger_garnizonStarted = true;
if (isNil "lambs_danger_karakolAyar") then { lambs_danger_karakolAyar = createHashMap; };
if (isNil "lambs_danger_garnizonDurum") then { lambs_danger_garnizonDurum = createHashMap; };
if (isNil "lambs_danger_karakollar") then { lambs_danger_karakollar = []; };

diag_log "[KARAKOL-GARNIZON] karakol garnizonu (nobet / devriye / ust kat / arac mevzi) watchdog'u baslatildi (v8.130)";

// ---- yardimcilar ----
private _kapsama = {
    // acik cephe sayisi (8 isin, 120 m): yuksek = genis gorus
    params ["_p"];
    private _g = AGLToASL (_p vectorAdd [0, 0, 1.2]);
    private _n = 0;
    for "_a" from 0 to 315 step 45 do {
        private _e = AGLToASL ((_p getPos [120, _a]) vectorAdd [0, 0, 1.2]);
        if (!(lineIntersects [_g, _e, objNull, objNull]) && {!(terrainIntersectASL [_g, _e])}) then { _n = _n + 1; };
    };
    _n
};

private _pozisyonlar = {
    params ["_poz", "_yar", "_n", "_ustKat", ["_tarafK", sideUnknown]];
    private _kapsama = missionNamespace getVariable "lambs_danger_garnizonKapsamaFn";
    private _aday = [];
    // v8.385 3DEN CATISMA POZISYONU modulleri (kullanici: 'mevzi ve karakol sistemi ile entegre olsun'): karakol yaricapi x1.2 icindeki bina ici / cati / ates mevzii (tip 1-3) modulleri
    //   NOBET ADAYI olur ve dogal adaylara (ust kat / arazi halkasi) ONCELIKLIDIR (skor 120 + puan x 12; cati +10). Aday bicimi: [poz, yon, "MODUL", skor, ad, durus, rol] (6. = sabit durus ya da "", 7. = rol tercihi ya da "").
    //   Modul pozisyonlari arasi min aralik 3 m (dogal adaylarda 18 m). Kapatma: CBA 'ELITE catisma pozisyonu modulleri' (lambs_danger_cpAktif).
    if (missionNamespace getVariable ["lambs_danger_cpAktif", true]) then {
        {
            _x params ["_mp", "_md", "_mt", "_mpu", "_mtr", "_mdu", "", "", "_mrl", "_mgz", "_mad"];
            if (!_mgz || {!(_mt in [1, 2, 3])} || {(_mp distance2D _poz) > (_yar * 1.2)} || {surfaceIsWater _mp}) then { continue };
            private _msd = [sideUnknown, west, east, independent] select ((round _mtr) max 0 min 3);
            if (_msd isNotEqualTo sideUnknown && {_tarafK isNotEqualTo sideUnknown} && {_msd isNotEqualTo _tarafK}) then { continue };
            _aday pushBack [_mp, _md, "MODUL", 120 + (_mpu * 12) + ([0, 10] select (_mt isEqualTo 2)), _mad, ["", "DOWN", "MIDDLE", "UP"] select ((round _mdu) max 0 min 3), ["", "MARKSMAN", "MG", "AT", "RIFLE"] select ((round _mrl) max 0 min 4)];
        } forEach (missionNamespace getVariable ["lambs_danger_cpListe", []]);
    };
    if (_ustKat) then {
        private _bl = (nearestObjects [_poz, ["House", "Building"], _yar]) select {(count (_x buildingPos -1)) > 0};
        private _kara = missionNamespace getVariable ["lambs_danger_ustKatKara", []];
        {
            // v8.343 DUSEN ASKER (kullanici: 'askerler asagiya dusuyor'; RPT 23-15: USTKAT 055056 = Land_dp_bigTank_F (silindirik depo ustu), nobetci 120 sn'de varamayinca isinlandi ve kaydi):
            //   (1) depo / baca / silo sinifi binalar elenir, (2) pozisyonun altinda ZEMIN (yuzey) yoksa elenir, (3) onceden dusen konumlar kara listede
            private _ad2 = toLower (typeOf _x);
            if ((["tank", "chimney", "silo", "_pipe"] findIf {(_ad2 find _x) >= 0}) >= 0) then { continue };
            private _bp = (_x buildingPos -1) select {
                private _q = _x;
                (_kara findIf {(_x distance _q) < 3}) < 0
                && {(lineIntersectsSurfaces [AGLToASL (_q vectorAdd [0, 0, 0.8]), AGLToASL (_q vectorAdd [0, 0, -0.8]), objNull, objNull, true, 1]) isNotEqualTo []}
            };
            if (_bp isEqualTo []) then { continue };
            private _en = _bp select 0;
            { if ((_x select 2) > (_en select 2)) then { _en = _x; }; } forEach _bp;
            if ((_en select 2) < 2.5) then { continue };
            private _cov = [_en] call _kapsama;
            private _yon = if ((_en distance2D _poz) < 15) then {random 360} else {_poz getDir _en};
            _aday pushBack [_en, _yon, "USTKAT", (_en select 2) * 3 + _cov * 4, typeOf _x];
        } forEach (_bl select [0, 40]);
    };
    for "_b" from 0 to 330 step 30 do {
        {
            private _p = _poz getPos [_yar * _x, _b];
            if (surfaceIsWater _p || {isOnRoad _p}) then { continue };
            private _h = (getTerrainHeightASL _p) - (getTerrainHeightASL _poz);
            private _cov = [_p] call _kapsama;
            _aday pushBack [_p, _b, "ARAZI", _h * 2 + _cov * 4, ""];
        } forEach [0.5, 0.8];
    };
    private _secilen = [];
    for "_i" from 1 to _n do {
        private _en = []; private _enS = -1e9;
        {
            private _a = _x;
            private _md = 200;
            { _md = _md min ((_a select 0) distance2D (_x select 0)); } forEach _secilen;
            if (_md < ([18, 3] select ((_a select 2) isEqualTo "MODUL"))) then { continue };
            private _s = (_a select 3) + ([0, (_md min 60) * 0.6] select (_secilen isNotEqualTo []));
            if (_s > _enS) then { _enS = _s; _en = _a; };
        } forEach _aday;
        if (_en isEqualTo []) exitWith {};
        _secilen pushBack _en;
    };
    _secilen
};

// v8.399 AA POZISYONLARI: acik gokyuzu (45 m dikey isin engelsiz) + yukseklik + 55 m asgari aralik; karakol merkezinden 0.45 / 0.65 / 0.85 yaricapta 20 derece adimli adaylar; doner: nobet girdisi [poz, yon, "AA", skor, "AA", "MIDDLE"]
private _aaPozFn = {
    params ["_poz", "_yar", "_n"];
    if (_n <= 0) exitWith {[]};
    private _ad = [];
    {
        private _r = _yar * _x;
        private _kat = _x;
        for "_a" from 0 to 340 step 20 do {
            private _p = _poz getPos [_r, _a];
            if (!surfaceIsWater _p) then {
                private _pA = AGLToASL (_p vectorAdd [0, 0, 1.6]);
                private _acik = !(lineIntersects [_pA, _pA vectorAdd [0, 0, 45], objNull, objNull]);
                private _yuk = (((getTerrainHeightASL _p) - (getTerrainHeightASL _poz)) max -8) min 25;
                _ad pushBack [_p, (_yuk * 1.5) + ([0, 18] select _acik) + ([0, 6] select (_kat isEqualTo 0.65)), _a];
            };
        };
    } forEach [0.45, 0.65, 0.85];
    private _secilen = [];
    for "_i" from 1 to _n do {
        private _en = [];
        private _enS = -1e9;
        {
            private _c = _x;
            private _md = 999;
            { _md = _md min ((_c select 0) distance2D (_x select 0)); } forEach _secilen;
            if (_md >= 55 && {(_c select 1) > _enS}) then { _enS = _c select 1; _en = _c; };
        } forEach _ad;
        if (_en isEqualTo []) exitWith {};
        _secilen pushBack _en;
    };
    _secilen apply { [_x select 0, _x select 2, "AA", _x select 1, "AA", "MIDDLE"] }
};

private _serbest = {
    // karakol altgruplarini dagit: nobetciler / devriyeler orijinal gruplarina doner
    params ["_id"];
    private _d = lambs_danger_garnizonDurum getOrDefault [_id, createHashMap];
    // v8.398: karakola bagli gozlem IHA'sinin gorevi kaldirilir
    private _ihaK = _d getOrDefault ["iha", objNull];
    if (!isNull _ihaK) then { [_ihaK, "KALDIR"] call FUNC(ihaSorti); };
    {
        private _u = _x;
        if (alive _u) then {
            _u enableAI "PATH";
            _u setUnitPos "AUTO";
            _u setVariable ["lambs_danger_nobet", nil, true];
            private _o = _u getVariable ["lambs_danger_garnizonOrijin", grpNull];
            if (!isNull _o && {({alive _x} count (units _o)) > 0}) then { [_u] joinSilent _o; };
            _u setVariable ["lambs_danger_garnizonOrijin", nil];
        };
    } forEach (_d getOrDefault ["birimler", []]);
    { if (!isNull _x) then { { deleteWaypoint _x } forEach (waypoints _x); }; } forEach (_d getOrDefault ["devriyeG", []]);
    { if (!isNull _x) then { { _x enableAI "PATH"; } forEach (units _x); _x setVariable ["lambs_danger_gorev", ""]; (vehicle (leader _x)) setVariable ["lambs_danger_gorev", "", true]; }; } forEach (_d getOrDefault ["aracG", []]);
    lambs_danger_garnizonDurum deleteAt _id;
};

private _calis = {
    missionNamespace setVariable ["lambs_danger_garnizonAdim", "basladi"];
    private _pozFn = missionNamespace getVariable "lambs_danger_garnizonPozFn";
    private _serbestFn = missionNamespace getVariable "lambs_danger_garnizonSerbestFn";
    private _aaPozFnC = missionNamespace getVariable "lambs_danger_garnizonAAPozFn";
    private _rolFn = missionNamespace getVariable ["lambs_danger_fnc_getUnitRole", {"RIFLE"}];
    private _ozetT = time + 60;
    while {true} do {
        sleep 15;
        if (missionNamespace getVariable ["lambs_danger_garnizonOff", false]) then { continue };
        // kaldirilmis karakolun garnizonu bosalt
        private _aktifAd = lambs_danger_karakollar apply {_x select 5};
        { if !(_x in _aktifAd) then { [_x] call _serbestFn; }; } forEach (keys lambs_danger_garnizonDurum);
        // v8.400: devriye agi - temas raporu paylasimi + destek yonlendirme (tum karakollarin devriyeleri ve nobet gruplari ortak resim)
        [] call FUNC(devriyeHaber);
        {
            private _k = _x;
            _k params ["_taraf", "_poz", "_yar", "_ad", "_sav", "_mn"];
            private _ay = lambs_danger_karakolAyar getOrDefault [_mn, createHashMap];
            private _durum = lambs_danger_garnizonDurum getOrDefault [_mn, createHashMap];
            if ((count _ay) isEqualTo 0) then {
                if ((count _durum) > 0) then { [_mn] call _serbestFn; };
                continue
            };
            missionNamespace setVariable ["lambs_danger_garnizonAdim", format ["karakol %1", _mn]];
            private _nobetN = _ay getOrDefault ["nobet", 0];
            private _devN = _ay getOrDefault ["devriye", 0];
            private _devBoy = _ay getOrDefault ["devBoy", 3];
            private _ustKat = _ay getOrDefault ["ustKat", true];
            private _arac = _ay getOrDefault ["arac", true];
            private _aaMod = _ay getOrDefault ["aa", 0];   // v8.399: 1 = anti-air konumlandirma (MANPADS nobetcileri ayri acik noktalarda, SPAAG ic halkada, statik AA yerinde)
            private _surum = _ay getOrDefault ["surum", 0];

            // ayar degisti: eskiyi bosalt, pozisyonlari yeniden hesapla
            if ((_durum getOrDefault ["surum", -1]) isNotEqualTo _surum) then {
                [_mn] call _serbestFn;
                _durum = createHashMap;
                _durum set ["surum", _surum];
                _durum set ["pozlar", [_poz, _yar, _nobetN, _ustKat, _taraf] call _pozFn];
                if (_aaMod > 0) then {
                    // MANPADS tasiyan ayni taraf piyade (karakol yaricapi x1.5): en cok 3 AA nobet noktasi
                    private _aaN = (count (allUnits select {alive _x && {!isPlayer _x} && {isNull objectParent _x} && {(side (group _x)) isEqualTo _taraf} && {(_x distance2D _poz) <= (_yar * 1.5)} && {([_x] call FUNC(aaSinif)) isEqualTo "MANPADS"}})) min 3;
                    private _aaP = [_poz, _yar, _aaN] call _aaPozFnC;
                    (_durum get "pozlar") append _aaP;
                    // statik AA (ZU-23 vb.): yerinde kalir, isaretlenir
                    private _stAA = ((_poz nearEntities [["StaticWeapon"], _yar * 1.2]) select {alive _x && {([_x] call FUNC(aaSinif)) isEqualTo "STATIK"}});
                    { _x setVariable ["lambs_danger_aaStatik", true, true]; } forEach _stAA;
                    diag_log format ["[KARAKOL-GARNIZON] %1 | AA konumlandirma: %2 MANPADS nobet noktasi, %3 statik AA YERINDE (tasinmaz)", _ad, count _aaP, count _stAA];
                };
                _durum set ["birimler", []];
                _durum set ["devriyeG", []];
                _durum set ["aracG", []];
                _durum set ["atama", createHashMap];
                lambs_danger_garnizonDurum set [_mn, _durum];
                diag_log format ["[KARAKOL-GARNIZON] %1 %2 | AYAR: nobet %3 devriye %4 x %5 | ust kat:%6 arac:%7 | pozisyon: %8", _taraf, _ad, _nobetN, _devN, _devBoy, _ustKat, _arac,
                    (_durum get "pozlar") apply {format ["%1 %2 (%3 m, skor %4%5)", _x select 2, mapGridPosition (_x select 0), round ((_x select 0) distance2D _poz), round (_x select 3), ["", " " + (_x select 4)] select ((_x select 4) isNotEqualTo "")]}];
            };

            // v8.394: elle secilen askerler (ayar 'uyeler': netId) -> havuz YALNIZ onlar (yaricap / 'kaynakta en az 3 asker' kurali yok); devriye mesafesi 'devMes' (0 = yaricap %60)
            private _uyeNid = _ay getOrDefault ["uyeler", []];
            private _uyeMod = _uyeNid isNotEqualTo [];
            // v8.397: TAKIM (grup) secimi: ayar 'gruplar' (grup netId) - hangi takimlar garnizon askeri verebilir (yaricap kurali yok; kaynak takimda en az 3 asker kalir, hekim korumasi sureer). 'uyeler' doluysa o oncelikli.
            private _grupNid = _ay getOrDefault ["gruplar", []];
            private _grpSecili = (_grupNid apply {groupFromNetId _x}) select {!isNull _x};
            private _grpMod = !_uyeMod && {_grupNid isNotEqualTo []};
            private _uzakOk = _uyeMod || _grpMod;
            private _devMes = _ay getOrDefault ["devMes", 0];
            private _devBaz = if (_devMes > 0) then {_devMes} else {_yar * 0.6};
            // ---- havuz ----
            private _altGrupAd = {(_x getVariable ["lambs_danger_garnizonAlt", ""]) isNotEqualTo ""};
            private _havuz = [];
            // v8.402 (RPT 2026-11: 3DEN'de 1 asker SYNC'liydi, nobet 3 + devriye 1x3 istenmisti -> 8 dk 'nobet 1/3, devriye 0/1', devriye HIC kurulmadi): secili asker sayisi gereken (nobet + devriye x boy)
            //   sayisindan azsa havuz yaricap havuzuyla TAMAMLANIR (secililer once kullanilir); hala yetmezse OZET satirinda 'havuz X / gerek Y' yazilir.
            private _uyeHavuz = [];
            if (_uyeMod) then {
                _uyeHavuz = (_uyeNid apply {objectFromNetId _x}) select {
                    !isNull _x && {alive _x} && {!isPlayer _x} && {isNull objectParent _x} && {(lifeState _x) in ["HEALTHY", "INJURED"]} && {local _x}
                    && {(side (group _x)) isEqualTo _taraf} && {((group _x) getVariable ["lambs_danger_garnizonAlt", ""]) isEqualTo ""}
                };
            };
            private _gerekAsker = _nobetN + _devN * _devBoy;
            private _uyeYetmez = _uyeMod && {(count _uyeHavuz) < _gerekAsker};
            if (_uyeYetmez && {(_durum getOrDefault ["yetmezLog", -1]) isNotEqualTo _surum}) then {
                _durum set ["yetmezLog", _surum];
                diag_log format ["[KARAKOL-GARNIZON] %1 | SECILI ASKER YETERSIZ: %2 asker secili < gereken %3 (nobet %4 + devriye %5 x %6) -> havuz karakol yaricapindaki (x1.5) takim askerleriyle TAMAMLANIYOR", _ad, count _uyeHavuz, _gerekAsker, _nobetN, _devN, _devBoy];
            };
            {
                private _g = _x;
                if ((side _g) isNotEqualTo _taraf || {isNull (leader _g)} || {isPlayer (leader _g)}) then { continue };
                if (({isPlayer _x} count (units _g)) > 0) then { continue };
                if (!_grpMod && {(leader _g) distance2D _poz > (_yar * 1.5)}) then { continue };
                // v8.136: kaynak gruptan EN AZ 3 asker (lider dahil) grupta kalir; aksi halde savunma plani / grup bosalir (RPT 013ca3b7: plan 24 sn'de "grup kalmadi" ile bitti)
                private _us = (units _g) select {alive _x && {isNull objectParent _x} && {(lifeState _x) in ["HEALTHY", "INJURED"]} && {local _x}};
                private _ayril = ((count (units _g select {alive _x})) - 3) max 0;
                private _aday = (_us - [leader _g]);
                // v8.341 SIHHIYE KORUMASI (kullanici: 'komutan ve sihhiye takimi degilse formasyonda sihhiyeler geride dursun, once atilmasin'): formasyon sirasinda sihhiyeler EN SONDA oldugu icin
                //   asagidaki 'reverse' onlari ILK nobet / devriyeye atiyordu. Komutan / MEDEVAC grubu ya da sihhiye cogunluklu grup disinda sihhiye havuza ALINMAZ.
                private _medGrup = ((_g getVariable ["lambs_danger_gorev", ""]) in ["MEDEVAC", "KOMUTAN"]) || {(({([_x] call _rolFn) isEqualTo "MEDIC"} count _us) * 2) > (count _us)};
                if (!_medGrup) then { _aday = _aday select {([_x] call _rolFn) isNotEqualTo "MEDIC"}; };
                reverse _aday;
                { _havuz pushBack _x; } forEach (_aday select [0, _ayril min (count _aday)]);
            } forEach ([[allGroups select {!(call _altGrupAd)}, _grpSecili select {!(call _altGrupAd)}] select _grpMod, []] select (_uyeMod && {!_uyeYetmez}));
            if (_uyeMod) then {
                // secililer basta, yaricap havuzu (yalniz secili yetmediyse dolu) arkada
                _havuz = _uyeHavuz + (_havuz - _uyeHavuz);
            };
            _durum set ["havuzN", count _havuz];
            _durum set ["gerekN", _gerekAsker];
            // nobetci / devriye icin zaten kullanilanlar havuzda sayilmaz (altgrup disinda)
            private _atama = _durum getOrDefault ["atama", createHashMap];
            private _pozlar = _durum getOrDefault ["pozlar", []];
            private _birimler = _durum getOrDefault ["birimler", []];

            // ---- NOBETCILER ----
            private _nobetG = _durum getOrDefault ["nobetG", grpNull];
            if (isNull _nobetG) then {
                _nobetG = createGroup [_taraf, true];
                _nobetG setVariable ["lambs_danger_garnizonAlt", "NOBET", true];
                _durum set ["nobetG", _nobetG];
            };
            {
                private _i = _forEachIndex;
                private _p = _x select 0;
                private _girdi = _x;
                private _u = _atama getOrDefault [str _i, objNull];
                if (alive _u && {_u in (units _nobetG)}) then {
                    // v8.138: nobetci ates altinda / yaraliysa PATH serbest (siper alsin); 90 sn sonra pozisyonuna doner (donup kalmasin / yerinde olu ordek olmasin)
                    if ((_u getVariable ["lambs_danger_nobet", false]) && {((getSuppression _u) > 0.7) || {(damage _u) > 0.4}}) then {
                        _u setVariable ["lambs_danger_nobet", false, true];
                        _u setVariable ["lambs_danger_nobetT", time + 90];
                        _u enableAI "PATH";
                        _u setUnitPos "AUTO";
                        diag_log format ["[KARAKOL-GARNIZON] %1 | NOBET %2 ates altinda (baski %3, hasar %4): serbest, 90 sn sonra pozisyona doner", _ad, name _u, (getSuppression _u) toFixed 2, (damage _u) toFixed 2];
                    };
                    // varmadi mi? (120 sn) -> isinla; varsa PATH kapat
                    if (((getPosATL _u) distance _p) < 4.5) then {
                        if !(_u getVariable ["lambs_danger_nobet", false]) then {
                            _u setVariable ["lambs_danger_nobet", true, true];
                            doStop _u;
                            _u disableAI "PATH";
                            _u setUnitPos (if ((count _x) > 5 && {(_x select 5) isNotEqualTo ""}) then {_x select 5} else {["MIDDLE", "UP"] select ((_x select 2) isEqualTo "USTKAT")});
                            _u doWatch (_p getPos [150, _x select 1]);
                            _u setBehaviour "AWARE";
                            diag_log format ["[KARAKOL-GARNIZON] %1 | NOBET pozisyonda: %2 (%3 %4)", _ad, name _u, _x select 2, mapGridPosition _p];
                        };
                    } else {
                        if (!(_u getVariable ["lambs_danger_nobet", false]) && {time > (_u getVariable ["lambs_danger_nobetT", 0])} && {(time - (_u getVariable ["lambs_danger_nobetT", time])) <= 120}) then { _u doMove _p; };
                        if ((time - (_u getVariable ["lambs_danger_nobetT", time])) > 120 && {!(_u getVariable ["lambs_danger_nobet", false])}) then {
                            _u setPosATL (_p vectorAdd [0, 0, 0.05]);
                            // v8.343: 4 sn sonra pozisyonun >1.5 m altindaysa (dustu) konum kara listeye alinir
                            if ((_x select 2) isEqualTo "USTKAT") then {
                                [{
                                    params ["_uu", "_pp"];
                                    if (alive _uu && {((getPosATL _uu) select 2) < ((_pp select 2) - 1.5)}) then {
                                        private _kr = missionNamespace getVariable ["lambs_danger_ustKatKara", []];
                                        _kr pushBack _pp;
                                        missionNamespace setVariable ["lambs_danger_ustKatKara", _kr];
                                        _uu setVariable ["lambs_danger_nobet", false, true];
                                        diag_log format ["[KARAKOL-GARNIZON] USTKAT %1 DUSTU (%2): konum kara listeye alindi", mapGridPosition _pp, name _uu];
                                    };
                                }, [_u, _p], 4] call CBA_fnc_waitAndExecute;
                            };
                            _u setVariable ["lambs_danger_nobetT", time];
                            // isinlanan nobetci hemen pozisyonda sayilir (RPT 23251a0a: ayni nobetciler 120 sn'de bir tekrar isinlaniyordu, PATH acik kalip yuruyordu)
                            _u setVariable ["lambs_danger_nobet", true, true];
                            doStop _u;
                            _u disableAI "PATH";
                            _u setUnitPos (if ((count _x) > 5 && {(_x select 5) isNotEqualTo ""}) then {_x select 5} else {["MIDDLE", "UP"] select ((_x select 2) isEqualTo "USTKAT")});
                            _u doWatch (_p getPos [150, _x select 1]);
                            diag_log format ["[KARAKOL-GARNIZON] %1 | NOBET %2 pozisyona 120 sn'de varamadi -> isinlandi", _ad, name _u];
                        };
                    };
                } else {
                    // bos / olu nobet: havuzdan en uygun
                    private _adaylar = _havuz select {!(_x in _birimler) && {!(_x in (units _nobetG))} && {_uzakOk || {(_x distance2D _poz) <= (_yar * 1.5)}}};
                    // v8.399: AA girdisi YALNIZ MANPADS tasiyiciya; AA girdisi varsa MANPADS tasiyicilar normal nobete alinmaz
                    if ((_x select 2) isEqualTo "AA") then {
                        _adaylar = _adaylar select {([_x] call FUNC(aaSinif)) isEqualTo "MANPADS"};
                    } else {
                        if ((_pozlar findIf {(_x select 2) isEqualTo "AA"}) >= 0) then { _adaylar = _adaylar select {([_x] call FUNC(aaSinif)) isNotEqualTo "MANPADS"}; };
                    };
                    if (_adaylar isEqualTo []) then { continue };
                    private _s = [_adaylar, [], { private _r = [_x] call _rolFn; (([0, 200, 400, 600, 900] select ((["RIFLE", "MARKSMAN", "RTO", "MEDIC", "MG"] find _r) max 0)) max ([0, 800] select (_r isEqualTo "AT"))) + ([0, 1500] select (_x isEqualTo (leader (group _x)))) + ((_x distance2D _p) / 5) - ([0, 1600] select (((count _girdi) > 6) && {(_girdi select 6) isNotEqualTo ""} && {_r isEqualTo (_girdi select 6)})) }, "ASCEND"] call BIS_fnc_sortBy;
                    private _sec = _s select 0;
                    _sec setVariable ["lambs_danger_garnizonOrijin", group _sec];
                    [_sec] joinSilent _nobetG;
                    _sec setVariable ["lambs_danger_nobetT", time];
                    _sec setVariable ["lambs_danger_nobet", nil, true];
                    _sec enableAI "PATH";
                    _sec doMove _p;
                    _atama set [str _i, _sec];
                    _birimler pushBack _sec;
                    diag_log format ["[KARAKOL-GARNIZON] %1 | NOBET atandi: %2 -> %3 %4 (%5 m)", _ad, name _sec, _x select 2, mapGridPosition _p, round (_sec distance2D _p)];
                };
            } forEach _pozlar;

            // ---- DEVRIYELER ----
            private _devG = _durum getOrDefault ["devriyeG", []];
            _devG = _devG select {!isNull _x && {({alive _x} count (units _x)) > 0}};
            private _alarm = false;
            {
                if ((time - (_x getVariable [QGVAR(contact), -999])) < 30) exitWith { _alarm = true; };
            } forEach ((allGroups select {(side _x) isEqualTo _taraf && {!isNull (leader _x)} && {((leader _x) distance2D _poz) < (_yar * 2)}}));
            while {count _devG < _devN} do {
                private _adaylar = _havuz select {!(_x in _birimler) && {!(_x in (units _nobetG))} && {((group _x) getVariable ["lambs_danger_garnizonAlt", ""]) isEqualTo ""}};
                if (count _adaylar < _devBoy) exitWith {
                    // v8.402: devriye neden kurulmadi (RPT 2026-11: sessizce 0/1 kaliyordu) - 60 sn'de bir
                    if ((time - (_durum getOrDefault ["devYetmezT", -999])) > 60) then {
                        _durum set ["devYetmezT", time];
                        diag_log format ["[KARAKOL-GARNIZON] %1 | DEVRIYE kurulamadi: bosta aday %2 < devriye boyu %3 (havuz %4, nobetciler dusuldukten sonra) - garnizona daha cok asker SYNC'le / takim modunu sec / karakol yaricapina asker koy", _ad, count _adaylar, _devBoy, count _havuz];
                    };
                };
                private _s = [_adaylar, [], {(rankId _x) * -10 + (_x distance2D _poz) / 20}, "ASCEND"] call BIS_fnc_sortBy;
                private _uyeler = _s select [0, _devBoy];
                private _dg = createGroup [_taraf, true];
                _dg setVariable ["lambs_danger_garnizonAlt", "DEVRIYE", true];
                { _x setVariable ["lambs_danger_garnizonOrijin", group _x]; [_x] joinSilent _dg; _birimler pushBack _x; } forEach _uyeler;
                _dg selectLeader (_uyeler select 0);
                _devG pushBack _dg;
                diag_log format ["[KARAKOL-GARNIZON] %1 | DEVRIYE kuruldu: %2 | %3 kisi", _ad, groupId _dg, _uyeler apply {name _x}];
            };
            {
                private _dg = _x;
                private _idx = _forEachIndex;
                private _wl = waypoints _dg;
                if (_alarm) then {
                    if !(_dg getVariable ["lambs_danger_devAlarm", false]) then {
                        _dg setVariable ["lambs_danger_devAlarm", true];
                        _dg setVariable ["lambs_danger_devDurum", "KESILDI"];   // v8.400: alarm bitince fnc_devriyeAg yeni tur planlar (sektor ziyaret edildi sayilmaz)
                        { deleteWaypoint _x } forEach _wl;
                        private _gp = _poz getPos [_yar * 0.7, (_poz getDir (leader _dg)) ];
                        if (surfaceIsWater _gp) then { _gp = getPosATL (leader _dg); };   // v8.195
                        _dg setBehaviour "COMBAT";
                        _dg setCombatMode "RED";
                        (leader _dg) doMove _gp;
                        diag_log format ["[KARAKOL-GARNIZON] %1 | ALARM: devriye %2 cevre savunmasina geciyor", _ad, groupId _dg];
                    };
                } else {
                    if (_dg getVariable ["lambs_danger_devAlarm", false] && {(time - (_dg getVariable [QGVAR(contact), -999])) > 120}) then { _dg setVariable ["lambs_danger_devAlarm", false]; _wl = []; { deleteWaypoint _x } forEach (waypoints _dg); _dg setBehaviour "AWARE"; _dg setCombatMode "YELLOW"; };
                    if (!(_dg getVariable ["lambs_danger_devAlarm", false]) && {missionNamespace getVariable ["lambs_danger_devAkilli", true]}) then {
                        // v8.400: AKILLI / PLANLI devriye (sektor + takvim + ortak resim; fnc_devriyeAg)
                        [_dg, _idx, _mn, _poz, _yar, _devBaz, _taraf, _ad, _devN] call FUNC(devriyeAg);
                    };
                    if (!(_dg getVariable ["lambs_danger_devAlarm", false]) && {!(missionNamespace getVariable ["lambs_danger_devAkilli", true])} && {count (waypoints _dg) < 2}) then {
                        { deleteWaypoint _x } forEach (waypoints _dg);
                        private _a0 = _idx * (360 / (_devN max 1));
                        for "_j" from 0 to 4 do {
                            // v8.195: devriye noktasi suda / su kenarinda olmaz (RPT f82d65d0: 65 m derin suya yuruyen devriye bogulup oldu): yaricap 0.6 -> 0.45 -> 0.3, aci +-20 derece denenir
                            private _wpPos = [];
                            {
                                if (_wpPos isEqualTo []) then {
                                    private _rr = _devBaz * _x;
                                    { private _cp = _poz getPos [_rr, _a0 + _j * 72 + _x]; if (_wpPos isEqualTo [] && {!surfaceIsWater _cp} && {(count ([0, 90, 180, 270] select {surfaceIsWater (_cp getPos [12, _x])})) isEqualTo 0}) then { _wpPos = _cp; }; } forEach [0, 20, -20];
                                };
                            } forEach [1, 0.75, 0.5];
                            if (_wpPos isEqualTo []) then { continue };
                            private _wp = _dg addWaypoint [_wpPos, 8];
                            _wp setWaypointType "MOVE";
                            _wp setWaypointName "ELITE GARNIZON: devriye";
                            _wp setWaypointBehaviour "AWARE";
                            _wp setWaypointSpeed "LIMITED";
                            _wp setWaypointFormation "STAG COLUMN";
                            _wp setWaypointCombatMode "YELLOW";
                            if (_j isEqualTo 4) then { _wp setWaypointType "CYCLE"; };
                        };
                    };
                };
            } forEach _devG;
            _durum set ["devriyeG", _devG];

            // ---- v8.398 IHA GOZLEM (kullanici: 'karakola ihayi ekle'): ayar ihaMod 1 = surekli gozlem devriyesi, 2 = yalniz ALARMDA (grup temasi < 30 sn). Aday: ayni taraf, ucan, GOZLEM tipi (FPV / bomba degil), bosta
            //   (gorevi yok, operatoru yok), yakiti > %30 IHA - 3DEN'de baglanmis ('ihalar') varsa yalniz onlar, yoksa karakol yaricapinin x1.5 (en az 300 m) icindeki en yakin. fnc_ihaSorti GOZLEM: karakol merkezi etrafinda
            //   devriye (yaricap: ihaYar, 0 = karakol yaricapi 100-800 m), sure ihaSure dk (0 = CBA 'Gozlem IHA suresi'); gorev bitince / dusunce 90 sn sonra yeni aday secilir. Karakol kaldirilinca gorev kaldirilir.
            private _ihaMod = _ay getOrDefault ["ihaMod", 0];
            if (_ihaMod > 0) then {
                private _ihaU = _durum getOrDefault ["iha", objNull];
                private _ihaAktif = !isNull _ihaU && {alive _ihaU} && {(_ihaU getVariable [QGVAR(ihaTok), -1]) >= 0};
                if (!_ihaAktif && {_ihaMod isEqualTo 1 || {_alarm}} && {(time - (_durum getOrDefault ["ihaT", -999])) > 90}) then {
                    _durum set ["ihaT", time];
                    private _ihaNid = _ay getOrDefault ["ihalar", []];
                    private _ihaAday = vehicles select {
                        unitIsUAV _x && {alive _x} && {_x isKindOf "Air"} && {(fuel _x) > 0.3}
                        && {([_x] call FUNC(ihaTip)) isEqualTo "GOZLEM"} && {(_x getVariable [QGVAR(ihaTok), -1]) < 0}
                        && {((count (UAVControl _x)) isEqualTo 0) || {isNull ((UAVControl _x) select 0)}}
                        && {(if ((crew _x) isNotEqualTo []) then {side (group ((crew _x) select 0))} else {[east, west, independent, civilian] select (((getNumber (configOf _x >> "side")) max 0) min 3)}) isEqualTo _taraf}
                        && {if (_ihaNid isEqualTo []) then {(_x distance2D _poz) <= ((_yar * 1.5) max 300)} else {(netId _x) in _ihaNid}}
                    };
                    if (_ihaAday isEqualTo []) then {
                        if ((time - (_durum getOrDefault ["ihaYokLogT", -999])) > 300) then {
                            _durum set ["ihaYokLogT", time];
                            // v8.400: her IHA'nin NEDEN elendigi (3 km icindeki / baglanan IHA'lar)
                            private _ihaNeden = (vehicles select {unitIsUAV _x && {((_x distance2D _poz) <= 3000) || {(netId _x) in _ihaNid}}}) apply {
                                private _v = _x;
                                private _r = [];
                                private _sd = if ((crew _v) isNotEqualTo []) then {side (group ((crew _v) select 0))} else {[east, west, independent, civilian] select (((getNumber (configOf _v >> "side")) max 0) min 3)};
                                if !(_v isKindOf "Air") then { _r pushBack "hava araci degil" };
                                if (!alive _v) then { _r pushBack "yikik" };
                                if ((fuel _v) <= 0.3) then { _r pushBack "yakit <= 30 yuzde" };
                                if (([_v] call FUNC(ihaTip)) isNotEqualTo "GOZLEM") then { _r pushBack ("tip " + ([_v] call FUNC(ihaTip))) };
                                if ((_v getVariable [QGVAR(ihaTok), -1]) >= 0) then { _r pushBack "baska gorevde" };
                                if ((count (UAVControl _v)) > 0 && {!isNull ((UAVControl _v) select 0)}) then { _r pushBack "operatoru var" };
                                if (_sd isNotEqualTo _taraf) then { _r pushBack format ["taraf %1 <> karakol %2", _sd, _taraf] };
                                if (_ihaNid isEqualTo [] && {(_v distance2D _poz) > ((_yar * 1.5) max 300)}) then { _r pushBack format ["menzil disi (%1 m > %2 m)", round (_v distance2D _poz), round ((_yar * 1.5) max 300)] };
                                if (_ihaNid isNotEqualTo [] && {!((netId _v) in _ihaNid)}) then { _r pushBack "bu garnizona baglanmamis" };
                                format ["%1 [%2]", typeOf _v, if (_r isEqualTo []) then {"elenmedi"} else {_r joinString ", "}]
                            };
                            diag_log format ["[KARAKOL-GARNIZON] %1 | IHA gozlem: uygun IHA yok (ayni taraf, ucan, GOZLEM tipi, bosta, yakit > %%30; %2) | IHA durumu: %3", _ad, ["karakol yaricapinin x1.5 icinde", "3DEN baglantili"] select (_ihaNid isNotEqualTo []), if (_ihaNeden isEqualTo []) then {"3 km icinde / bagli IHA yok"} else {_ihaNeden}];
                        };
                    } else {
                        _ihaAday = [_ihaAday, [], {_x distance2D _poz}, "ASCEND"] call BIS_fnc_sortBy;
                        private _ihaC = _ihaAday select 0;
                        private _ihaR = if ((_ay getOrDefault ["ihaYar", 0]) > 0) then {_ay getOrDefault ["ihaYar", 0]} else {(_yar max 100) min 800};
                        _durum set ["iha", _ihaC];
                        [_ihaC, "GOZLEM", "GOZLEM", _taraf, _poz, _ihaR, 3000, objNull, 0, (_ay getOrDefault ["ihaSure", 0]) * 60] spawn FUNC(ihaSorti);
                        diag_log format ["[KARAKOL-GARNIZON] %1 | IHA gozlem BASLADI: %2 | merkez %3 | yaricap %4 m | mod %5%6", _ad, getText (configOf _ihaC >> "displayName"), mapGridPosition _poz, round _ihaR, ["", "surekli", "alarmda"] select (_ihaMod min 2), ["", " (ALARM)"] select _alarm];
                    };
                };
            };

            // ---- ARAC MEVZILERI ----
            private _aracG = _durum getOrDefault ["aracG", []];
            if (_arac || {_aaMod > 0}) then {
                // v8.402: SPAAG icin tarama yaricapi en az 250 m (ZSU karakol disinda park halindeyse da ic halkaya cekilir); diger araclar eski yaricap (yar x 1.2)
                private _vl = (_poz nearEntities [["LandVehicle"], (_yar * 1.2) max ([0, 250] select (_aaMod > 0))]) select {
                    alive _x && {!(_x isKindOf "StaticWeapon")} && {((_x distance2D _poz) <= (_yar * 1.2)) || {_aaMod > 0 && {([_x] call FUNC(aaSinif)) isEqualTo "SPAAG"}}} && {canMove _x} && {!isNull (driver _x)} && {!isPlayer (driver _x)} && {local (driver _x)} && {(side (group (driver _x))) isEqualTo _taraf}
                    && {(_arac && {(_x emptyPositions "cargo") >= 2 || {(getNumber (configOf _x >> "armor")) >= 100}}) || {_aaMod > 0 && {([_x] call FUNC(aaSinif)) isEqualTo "SPAAG"}}}
                    && {!(((group (driver _x)) getVariable ["lambs_danger_garnizonAlt", ""]) isNotEqualTo "")}
                };
                {
                    private _v = _x;
                    private _dg2 = group (driver _v);
                    if (_dg2 in _aracG) then { continue };
                    if ((_v getVariable ["lambs_danger_gorev", ""]) in ["MEDEVAC", "TASIMA", "TOPCU", "HARIC"] || {_v getVariable [QGVAR(tasimaMesgul), false]}) then { continue };
                    private _n = count _aracG;
                    private _a = (_poz getDir (getPosATL _v)) + 30 * _n;
                    private _aaV = _aaMod > 0 && {([_v] call FUNC(aaSinif)) isEqualTo "SPAAG"};   // v8.399: SPAAG ic halkada (merkeze yakin, karakolu korur)
                    private _vp = _poz getPos [_yar * ([0.75, 0.5] select _aaV), (_n * (360 / ((count _vl) max 1))) + 20];
                    if (surfaceIsWater _vp) then { _vp = _poz getPos [_yar * 0.5, (_n * 90)]; };
                    _dg2 setVariable ["lambs_danger_gorev", "KARAKOL_ARAC", true];
                    _v setVariable ["lambs_danger_gorev", "KARAKOL_ARAC", true];
                    _v setVariable ["lambs_danger_garnizonPoz", [_vp, _poz getDir _vp]];
                    (driver _v) enableAI "PATH";
                    (driver _v) doMove _vp;
                    _aracG pushBack _dg2;
                    diag_log format ["[KARAKOL-GARNIZON] %1 | ARAC mevzisine: %2 -> %3 (%4 m)", _ad, getText (configOf _v >> "displayName"), mapGridPosition _vp, round (_v distance2D _vp)];
                } forEach _vl;
                {
                    private _v = vehicle (leader _x);
                    private _pp = _v getVariable ["lambs_danger_garnizonPoz", []];
                    if (_pp isNotEqualTo [] && {alive _v} && {(_v distance2D (_pp select 0)) < 12} && {!((driver _v) getVariable ["lambs_danger_nobet", false])}) then {
                        private _d = driver _v;
                        _d setVariable ["lambs_danger_nobet", true, true];
                        doStop _d;
                        _d disableAI "PATH";
                        { _x doWatch ((_pp select 0) getPos [200, _pp select 1]); } forEach (crew _v);
                        diag_log format ["[KARAKOL-GARNIZON] %1 | ARAC mevzide: %2 (yon %3)", _ad, getText (configOf _v >> "displayName"), round (_pp select 1)];
                    };
                } forEach _aracG;
            };
            _durum set ["aracG", _aracG select {!isNull _x}];
            _atama = _atama;
            _durum set ["atama", _atama];
            _durum set ["birimler", _birimler select {alive _x}];
            _durum set ["alarm", _alarm];
            lambs_danger_garnizonDurum set [_mn, _durum];
        } forEach lambs_danger_karakollar;

        if (time > _ozetT) then {
            _ozetT = time + 60;
            {
                private _id = _x;
                private _d = _y;
                private _ay = lambs_danger_karakolAyar getOrDefault [_id, createHashMap];
                private _atama = _d getOrDefault ["atama", createHashMap];
                private _nb = {alive (_atama get _x)} count (keys _atama);
                diag_log format ["[KARAKOL-GARNIZON-OZET] %1 | nobet %2/%3 (pozisyonda %4) | devriye %5/%6 | arac %7 | alarm:%8 | havuz %10 / gerek %11 | devriye durumu: %9",
                    _id, _nb, _ay getOrDefault ["nobet", 0], {(_atama get _x) getVariable ["lambs_danger_nobet", false]} count (keys _atama),
                    count (_d getOrDefault ["devriyeG", []]), _ay getOrDefault ["devriye", 0], count (_d getOrDefault ["aracG", []]), _d getOrDefault ["alarm", false],
                    (_d getOrDefault ["devriyeG", []]) apply {format ["%1:%2 S%3", groupId _x, _x getVariable ["lambs_danger_devDurum", "klasik"], _x getVariable ["lambs_danger_devSektor", "-"]]}, _d getOrDefault ["havuzN", 0], _d getOrDefault ["gerekN", 0]];
            } forEach lambs_danger_garnizonDurum;
        };
        missionNamespace setVariable ["lambs_danger_garnizonAdim", "tur bitti"];
    };
};
missionNamespace setVariable ["lambs_danger_garnizonKapsamaFn", _kapsama];
missionNamespace setVariable ["lambs_danger_garnizonPozFn", _pozisyonlar];
missionNamespace setVariable ["lambs_danger_garnizonSerbestFn", _serbest];
missionNamespace setVariable ["lambs_danger_garnizonAAPozFn", _aaPozFn];

[_calis] spawn {
    params ["_fn"];
    while {true} do {
        private _h = [] spawn _fn;
        waitUntil { sleep 5; scriptDone _h };
        diag_log format ["[WATCHDOG-YENIDEN] karakolGarnizon betigi sonlandi (hata?), son adim: %1", missionNamespace getVariable ["lambs_danger_garnizonAdim", "?"]];
        sleep 5;
    };
};

true
