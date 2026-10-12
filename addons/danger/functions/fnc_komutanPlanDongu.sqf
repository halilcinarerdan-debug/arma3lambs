#include "script_component.hpp"
/*
 * Author: Cinar (ELITE fork)
 * KOMUTAN PLANI DONGUSU (v8.113) — fnc_komutanPlan'in kurdugu planlari (lambs_danger_planlar) 3 sn'de bir yurutur. Durum plan HashMap'inde tutulur: dongu hata ile olurse bekci yeniden baslatir, plan kaldigi yerden surer.
 * Fazlar (ele gecir): TOPLAN -> ORP -> KESIF -> SALDIRI -> TOPLANMA -> BITTI.   Savun: TOPLAN -> MEVZI -> BEKLE -> BITTI.   IPTAL: waypoint / bayrak temizligi.
 * Waypoint: yalniz "ELITE PLAN:" adli kendi waypoint'lerimiz silinir / yazilir (Zeus'un elle koydugu waypoint'e dokunulmaz). Temastaki grup zorlanmaz.
 * Log: [PLAN] FAZ / ROL / TEMAS / BITTI.
 *
 * Arguments: None
 * Return Value: None
 * Public: No
*/

missionNamespace setVariable ["lambs_danger_planAdim", "basladi"];

private _temasta = {
    params ["_g"];
    private _sit = _g getVariable [QGVAR(cmdSit), []];
    ((_g getVariable [QGVAR(contact), 0]) > time) && {_sit isEqualType []} && {(count _sit) >= 2} && {(time - (_sit select 0)) < 30} && {(_sit select 1) <= 450}
};

// kendi waypoint'lerimizi sil, yenilerini yaz: [[poz, tip, ad, davranis, hiz, yaricap], ...]
private _wpYaz = {
    params ["_g", "_liste"];
    private _w = waypoints _g;
    for "_i" from ((count _w) - 1) to 0 step -1 do {
        if (((waypointName (_w select _i)) find "ELITE PLAN:") isEqualTo 0) then { deleteWaypoint (_w select _i); };
    };
    private _ilk = [];
    {
        _x params ["_poz", "_tip", "_ad", ["_beh", "AWARE"], ["_hiz", "NORMAL"], ["_yar", 40]];
        private _wp = _g addWaypoint [_poz, 0];
        _wp setWaypointType _tip;
        _wp setWaypointName format ["ELITE PLAN: %1", _ad];
        _wp setWaypointDescription format ["ELITE PLAN: %1", _ad];
        // tempo (komutan niyeti): 0 dengeli, 1 sessiz / gizli (STEALTH, yavas, saldiriya kadar ates disiplini GREEN), 2 hizli / agresif (tam hiz)
        private _tm = missionNamespace getVariable ["lambs_danger_planTempoGecici", 0];
        private _savasWp = (_beh isEqualTo "COMBAT") || {_tip isEqualTo "SAD"};
        if (!_savasWp) then {
            _beh = ["AWARE", "STEALTH", "AWARE"] select _tm;
            _hiz = ["NORMAL", "LIMITED", "FULL"] select _tm;
        };
        _wp setWaypointBehaviour _beh;
        _wp setWaypointSpeed _hiz;
        _wp setWaypointCombatMode (["YELLOW", ["GREEN", "YELLOW"] select _savasWp, "YELLOW"] select _tm);   // v8.130: gizli tempoda saldiriya kadar GREEN (ates yok, yalniz savunma)
        _wp setWaypointCompletionRadius _yar;
        if (_ilk isEqualTo []) then { _ilk = _wp; };
    } forEach _liste;
    if (_ilk isNotEqualTo []) then { _g setCurrentWaypoint _ilk; };
};

// v8.134 ISTIHBARAT: komutan IDDIAYA gore planlar (Zeus'un verdigi sayi / konum yanlis olabilir: "100 adam var" dendi, gercekte sivil var); gercek sahne komutandan gizli.
// Gozlem raporu: verilen gruplarin BILDIKLERI (knowsAbout >= 0.8, objektif cevresi 450 m): dusman (piyade / MG / AT / nisanci / zirh) VE sivil sayisi; iddia ile fark loglanir.
private _gozlemRapor = {
    params ["_plan", "_gozGruplar", "_bozuldu", "_gozlemS", "_etiket"];
    private _obj = _plan get "obj";
    private _taraf = _plan get "taraf";
    private _rolFn2 = missionNamespace getVariable ["lambs_danger_fnc_getUnitRole", {"RIFLE"}];
    private _bilinen = (_obj nearEntities [["CAManBase", "LandVehicle", "Air"], 450]) select {
        private _e = _x;
        alive _e && {(_gozGruplar findIf {(_x knowsAbout _e) >= 0.8}) >= 0}
    };
    private _hos = _bilinen select {(side _x) isNotEqualTo civilian && {_taraf getFriend (side _x) < 0.6}};
    private _siv = _bilinen select {(side _x) isEqualTo civilian && {_x isKindOf "CAManBase"}};
    private _adam = _hos select {_x isKindOf "CAManBase"};
    private _mgN = {([_x] call _rolFn2) isEqualTo "MG"} count _adam;
    private _atN = {([_x] call _rolFn2) isEqualTo "AT"} count _adam;
    private _nisN = {([_x] call _rolFn2) isEqualTo "MARKSMAN"} count _adam;
    private _zirhN = {!(_x isKindOf "CAManBase") && {(getNumber (configOf _x >> "armor")) >= 100}} count _hos;
    private _ay = _plan get "ayar";
    private _iddia = _plan getOrDefault ["iddiaSayi", 0];
    if (_mgN > 0) then { _ay set ["mg", true]; };
    if (_atN > 0) then { _ay set ["at", true]; };
    if (_nisN > 0) then { _ay set ["nisanci", true]; };
    if (_zirhN > 0) then { _ay set ["zirh", true]; };
    _plan set ["gozDusman", count _hos];
    _plan set ["gozSivil", count _siv];
    _plan set ["gozAdam", count _adam];
    _plan set ["raporHazir", true];
    // komutan inancini gunceller (tam gozlem): gozlenen sayi iddiadan farkliysa gozlenene gecer
    if (_gozlemS >= 40) then { _ay set ["sayi", count _adam]; };
    private _fark = if (_iddia <= 0) then {"iddia sayisi verilmemis"} else {
        format ["IDDIA %1 / GOZLENEN %2 (%3)", _iddia, count _adam, ["uyumlu", "UYUSMAZLIK: iddia gozlenenin cok ustunde / altinda"] select (((count _adam) < (_iddia * 0.4)) || {(count _adam) > (_iddia * 1.6)})]
    };
    private _rap = format ["gorulen dusman %1 (piyade %2: MG %3, AT %4, nisanci %5; arac / zirh %6), SIVIL %7 | %8 | gozlem %9 sn | %10 | %11", count _hos, count _adam, _mgN, _atN, _nisN, _zirhN, count _siv, _fark, round _gozlemS, ["gizlilik korundu", "TEMAS: gizlilik bozuldu"] select _bozuldu, _etiket];
    _plan set ["reconRapor", _rap];
    { private _g = _x; { _g reveal [_x, 2.5]; } forEach (_hos + _siv); } forEach (_plan get "gruplar");
    diag_log format ["[PLAN-ISTIHBARAT] %1 | RAPOR: %2", _plan get "id", _rap];
    systemChat format ["[ELITE] Istihbarat (%1): %2", _plan get "id", _rap];
    // v8.143 KESIF-ATES (RUS: sensor-atici < 4 dk, ATP 7-100.1 s. 5056): rapor gelir gelmez hazirlik atisi (izin PID kurallariyla; _topcuAt kendi izin kontrolunu yapar)
    if (!(_plan getOrDefault ["hazirlikAtildi", false]) && {(_plan getOrDefault ["topcu", 0]) in [1, 3]} && {[((_plan get "gruplar") param [0, grpNull]), "kesifAtesHizli", false] call FUNC(dk)}) then {
        _plan set ["hazirlikAtildi", true];
        [_plan, _obj, "HAZIRLIK (kesif-ates, doktrin)"] call _topcuAt;
    };
    _rap
};
// Atis izni (PID): dogrulama 0 tam / 1 son dogrulama: rapor gelmeden atis YOK; sivil gozlenirse atis iptal; dusman gozlenmediyse atis iptal. dogrulama 2 (yok): iddiaya guvenilir, atilir (tarihsel hata canlandirmasi; [PLAN-UYARI])
// Doner: [izin, neden, bekle]
private _atisIzni = {
    params ["_plan"];
    private _dg = _plan getOrDefault ["dogrulama", 0];
    if (_dg isEqualTo 2) exitWith { [true, format ["DOGRULAMA YOK: iddiaya guvenildi (guven %1)", ["yetersiz", "orta", "kesin"] select ((_plan getOrDefault ["guven", 1]) min 2)], false] };
    // v8.192 CANLI GOZLEM: recon yoksa (ya da rapor gelmediyse) taraftaki HERKES dogrulayabilir: herhangi bir dost grup liderinin objektifin 500 m cevresinde bildigi (knowsAbout > 0.5) dusman gozlenmis sayilir
    private _objC = _plan get "obj";
    private _tfC = _plan get "taraf";
    private _canli = 0;
    {
        private _gl = leader _x;
        if (!isNull _gl && {alive _gl} && {(side _x) isEqualTo _tfC}) then {
            { if (((_tfC getFriend (_x select 2)) < 0.6) && {((_x select 0) distance2D _objC) < 500} && {(_gl knowsAbout (_x select 4)) > 0.5}) then { _canli = _canli + 1; }; } forEach (_gl nearTargets 900);
        };
    } forEach allGroups;
    if !(_plan getOrDefault ["raporHazir", false]) then {
        if (_canli > 0) then {
            _plan set ["gozDusman", _canli];
        } else {
            _plan set ["canliN", _canli];
        };
    };
    if !(_plan getOrDefault ["raporHazir", false]) exitWith {
        if (_canli > 0) then { [true, format ["canli gozlem (%1): %2 dusman bilgisi, sivil gozlenmedi", ["recon yok", "recon / plan gruplari"] select ((_plan getOrDefault ["reconG", []]) isNotEqualTo []), _canli], false] }
        else { [false, "dogrulama bekleniyor (rapor yok)", true] }
    };
    private _gs = _plan getOrDefault ["gozSivil", 0];
    private _gd = (_plan getOrDefault ["gozDusman", 0]) max _canli;
    if (_gs > 0) exitWith { [false, format ["SIVIL GOZLENDI (%1): atis IPTAL (PID)", _gs], false] };
    if (_gd < 1) exitWith { [false, "hedefte dusman gozlenmedi: atis IPTAL", true] };
    [true, format ["dogrulandi: %1 dusman, 0 sivil", _gd], false]
};

// topcu / havan atesi: tarafin artilleryScanner araclari; dost mesafesi < 150 m ise atis yapilmaz (tasarim esigi, kaynakli degil)
private _topcuAt = {
    params ["_plan", "_poz", "_ad"];
    private _taraf = _plan get "taraf";
    private _mermi = round ((_plan getOrDefault ["topcuN", 4]) * ([((_plan getOrDefault ["gruplar", []]) param [0, grpNull]), "topcuMermiCarpan", 1] call FUNC(dk)));   // v8.143 doktrin: RUS ates agirlikli x2
    // KAYNAK: TC 3-21.76 (Ranger El Kitabi, 2017) s. 3-4 / 3-5: DANGER CLOSE = hedef dost birlige <= 600 m (havan / sahra topcusu: komut cagrisinda ilan edilir, yasak DEGIL);
    //   'risk estimate distance' (RED, %0.1 Pi) tablosu (azami sarj, ayakta): 60 mm ~145 m, 81 / 82 mm ~195 m, 105 mm ~455 m, 120 mm ~430 m. Savasta RED, egitimde MSD kullanilir (kitap).
    //   Burada: dost mesafesi < RED ise o arac ATMAZ; RED'in altinda ama <= 600 m ise 'DANGER CLOSE' loglanir. Cap cikarimi mermi / arac sinif adindan (sezgisel).
    private _izin = [_plan] call _atisIzni;
    _plan set ["atisRet", ["RED", "BEKLE"] select (_izin param [2, false])];
    if !(_izin select 0) exitWith {
        diag_log format ["[PLAN-TOPCU] %1 | %2 ATIS YAPILMADI: %3", _plan get "id", _ad, _izin select 1];
        false
    };
    diag_log format ["[PLAN-TOPCU] %1 | %2 atis izni: %3", _plan get "id", _ad, _izin select 1];
    if ((_plan getOrDefault ["dogrulama", 0]) isEqualTo 2) then { diag_log format ["[PLAN-UYARI] %1 | topcu dogrulamasiz (iddiaya guvenerek) atiyor - yanlis istihbarat sivil / dost kaybina yol acabilir", _plan get "id"]; };
    private _dostEn = 99999;
    { if (alive _x && {(side (group _x)) isEqualTo _taraf}) then { _dostEn = _dostEn min (_x distance2D _poz); }; } forEach allUnits;
    private _araclar = vehicles select {
        alive _x && {(side (group _x)) isEqualTo _taraf} && {(getNumber (configOf _x >> "artilleryScanner")) > 0} && {!isNull (gunner _x)} && {!isPlayer (gunner _x)} && {local _x} && {canFire _x}
    };
    // v8.127: Zeus 'ELITE Gorev Ata': TOPCU_YOK olanlar atmaz; en az bir arac TOPCU atandiysa yalniz atananlar atar
    _araclar = _araclar select {!("TOPCU_YOK" in [_x getVariable ["lambs_danger_gorev", ""], (group (gunner _x)) getVariable ["lambs_danger_gorev", ""]])};
    private _isTop = _araclar select {"TOPCU" in [_x getVariable ["lambs_danger_gorev", ""], (group (gunner _x)) getVariable ["lambs_danger_gorev", ""]]};
    if (_isTop isNotEqualTo []) then { _araclar = _isTop; };
    private _atan = 0;
    {
        private _v = _x;
        private _mg = (getArtilleryAmmo [_v]) param [0, ""];
        // v8.181: top hedefe gore menzil disindaysa yer degistirir (min menzil ihlali / uzak); bu seans atmaz, bir sonraki seansta menzil icinde olur
        if (_mg isNotEqualTo "" && {!(_poz inRangeOfArtillery [[_v], _mg])}) then { [_v, _poz, _plan get "id"] call FUNC(topcuKonumla); };
        private _cap = toLower (_mg + "|" + typeOf _v);
        private _red = 300;
        if ((_cap find "60mm") >= 0) then { _red = 145; };
        if ((_cap find "81mm") >= 0 || {(_cap find "82mm") >= 0}) then { _red = 195; };
        if ((_cap find "120mm") >= 0) then { _red = 430; };
        if ((_cap find "105mm") >= 0 || {(_cap find "155mm") >= 0} || {(_cap find "152mm") >= 0}) then { _red = 455; };
        // v8.183 NISAN KAYDIRMA (kullanici: "artilerry?"; RPT ce7738ae: dost 376-447 m, RED 455 m -> top hic atmadi): dost RED'den yakinsa nisan noktasi dostlarin ters yonune
        //   (objektifin DERINLIGINE, en cok 200 m) kaydirilir; kaydirilmis noktada en yakin dost >= RED + 20 m ise atis yapilir (kaynak ilkesi korunur: dost mesafesi < RED ise ATMAZ)
        private _nokta = _poz;
        private _dE = _dostEn;
        if (_dostEn < _red) then {
            private _fp = objNull;
            private _fd = 99999;
            { if (alive _x && {(side (group _x)) isEqualTo _taraf} && {(_x distance2D _poz) < _fd}) then { _fd = _x distance2D _poz; _fp = _x; }; } forEach allUnits;
            if (!isNull _fp) then {
                private _yon = (getPosATL _fp) getDir _poz;
                {
                    private _cand = _poz getPos [_x, _yon];
                    private _dc = 99999;
                    { if (alive _x && {(side (group _x)) isEqualTo _taraf}) then { _dc = _dc min (_x distance2D _cand); }; } forEach allUnits;
                    if (_dc >= (_red + 20) && {!surfaceIsWater _cand}) exitWith { _nokta = _cand; _dE = _dc; };
                } forEach [40, 80, 120, 160, 200];
            };
        };
        if (_dE < _red) then {
            diag_log format ["[PLAN-TOPCU] %1 | %2 | %3 ATMADI: en yakin dost %4 m < RED %5 m, 200 m derinlige kaydirmayla da yeterli mesafe yok (TC 3-21.76 Tablo 3-3, %6)", _plan get "id", _ad, typeOf _v, round _dostEn, _red, _mg];
        } else {
            if (_mg isNotEqualTo "" && {_nokta inRangeOfArtillery [[_v], _mg]}) then {
                private _hd = _nokta getPos [random 30, random 360];
                if (_nokta isNotEqualTo _poz) then { diag_log format ["[PLAN-TOPCU] %1 | %2 | NISAN KAYDIRILDI: dost %3 m < RED %4 m -> nisan noktasi objektifin %5 m derinligine (dost %6 m)", _plan get "id", _ad, round _dostEn, _red, round (_nokta distance2D _poz), round _dE]; };
                _v doArtilleryFire [_hd, _mg, _mermi];
                // ZARAR TAKIBI: atis noktasinin 250 m cevresindeki sivil / dost / dusman anlik listesi (plan sonunda kimlerin oldugu [PLAN-ZARAR] ile yazilir)
                private _yakin = _hd nearEntities ["CAManBase", 250];
                (_plan getOrDefault ["atislar", []]) pushBack [time, _hd, _yakin select {(side _x) isEqualTo civilian}, _yakin select {(side (group _x)) isEqualTo (_plan get "taraf")}, _yakin select {(side _x) isNotEqualTo civilian && {((_plan get "taraf") getFriend (side _x)) < 0.6}}];
                _plan set ["atislar", _plan getOrDefault ["atislar", []]];
                _atan = _atan + 1;
                diag_log format ["[PLAN-TOPCU] %1 | %2 | %3 -> %4 | %5 mermi (%6) | ETA %7 sn | en yakin dost %8 m (RED %9 m)%10", _plan get "id", _ad, typeOf _v, mapGridPosition _hd, _mermi, _mg, round (_v getArtilleryETA [_hd, _mg]), round _dE, _red, ["", " | DANGER CLOSE (<= 600 m)"] select (_dE <= 600)];
            };
        };
    } forEach _araclar;
    if (_atan isEqualTo 0) then {
        // v8.130 TANI: neden atis yok? (kullanici: "topcu atesi calismiyor")
        private _tumTop = vehicles select {alive _x && {(side (group _x)) isEqualTo _taraf} && {(getNumber (configOf _x >> "artilleryScanner")) > 0}};
        private _ned = [
            ["toplam topcu araci", count _tumTop],
            ["topcu yok / gunner yok", {isNull (gunner _x)} count _tumTop],
            ["gunner oyuncu", {!isNull (gunner _x) && {isPlayer (gunner _x)}} count _tumTop],
            ["sunucuda yerel degil", {!local _x} count _tumTop],
            ["ates edemez (canFire false)", {!canFire _x} count _tumTop],
            ["Zeus TOPCU_YOK", {"TOPCU_YOK" in [_x getVariable ["lambs_danger_gorev", ""], (group (gunner _x)) getVariable ["lambs_danger_gorev", ""]]} count _tumTop],
            ["mermi yok (getArtilleryAmmo bos)", {((getArtilleryAmmo [_x]) param [0, ""]) isEqualTo ""} count _tumTop],
            ["hedef menzil disi", {private _m = ((getArtilleryAmmo [_x]) param [0, ""]); _m isNotEqualTo "" && {!(_poz inRangeOfArtillery [[_x], _m])}} count _tumTop]
        ];
        diag_log format ["[PLAN-TOPCU] %1 | %2 ATIS YOK (%3 aday arac) | nedenler: %4 | hedef %5", _plan get "id", _ad, count _araclar, _ned, mapGridPosition _poz];
    };
    _atan > 0
};

// v8.181: SAVUNMA MEVZI NOKTASI - verilen sektor noktasinin cevresinde (0 / 20 / 40 m, 4 yon) arazi objesi yogunlugu (siper) en yuksek, su / cukur / dik egim olmayan nokta
private _siperNokta = {
    params ["_p0"];
    private _en = _p0;
    private _enS = -1e9;
    {
        private _r = _x;
        {
            private _p = if (_r isEqualTo 0) then {_p0} else {_p0 getPos [_r, _x]};
            if (!surfaceIsWater _p) then {
                private _obje = count (nearestTerrainObjects [_p, ["TREE", "ROCK", "WALL", "BUILDING", "HIDE", "BUSH"], 25, false, true]);
                private _hOrt = 0;
                for "_k" from 0 to 3 do { _hOrt = _hOrt + (getTerrainHeightASL (_p getPos [30, _k * 90])); };
                private _cukur = ((_hOrt / 4) - (getTerrainHeightASL _p)) > 2.5;
                private _s = ((_obje min 20) * 1.5) - ([0, 25] select _cukur) - ([0, 15] select (((surfaceNormal _p) select 2) < 0.95)) - 0.15 * (_p distance2D _p0);
                if (_s > _enS) then { _enS = _s; _en = _p; };
            };
        } forEach ([0, 90, 180, 270] select [0, [4, 1] select (_r isEqualTo 0)]);
    } forEach [0, 20, 40];
    _en
};

private _wpTemizle = {
    params ["_g"];
    private _w = waypoints _g;
    for "_i" from ((count _w) - 1) to 0 step -1 do {
        if (((waypointName (_w select _i)) find "ELITE PLAN:") isEqualTo 0) then { deleteWaypoint (_w select _i); };
    };
};

private _fazGec = {
    params ["_plan", "_yeni", ["_neden", ""]];
    private _eski = _plan get "faz";
    _plan set ["faz", _yeni];
    _plan set ["fazT", time];
    _plan set ["fazHazir", false];
    (_plan getOrDefault ["fazGecmis", []]) pushBack [_eski, round ((time - (_plan getOrDefault ["fazBasT", time])))];
    _plan set ["fazBasT", time];
    diag_log format ["[PLAN] %1 FAZ %2 -> %3 | %4 sn | %5", _plan get "id", _eski, _yeni, round (time - (_plan get "t0")), _neden];
};

// grup ofseti: ayni noktaya yigilma yok (grup indeksine gore yana 30 m)
private _ofset = {
    params ["_poz", "_i", "_B"];
    _poz getPos [30 * (ceil (_i / 2)) * ([1, -1] select (_i mod 2 isEqualTo 1)), _B + 90]
};

while {true} do {
    sleep 3;
    if (missionNamespace getVariable ["lambs_danger_komutanPlanOff", false]) then { continue };
    private _bitenler = [];
    {
        private _id = _x;
        private _plan = _y;
        missionNamespace setVariable ["lambs_danger_planAdim", format ["%1 faz %2", _id, _plan get "faz"]];
        private _faz = _plan get "faz";
        private _tip = _plan get "tip";
        private _obj = _plan get "obj";
        private _rp = _plan get "rp";
        private _orp = _plan get "orp";
        private _sbf = _plan get "sbf";
        private _B = _plan get "B";
        private _roller = _plan get "roller";
        private _gruplar = (_plan get "gruplar") select {!isNull _x && {({alive _x} count (units _x)) > 0}};
        _plan set ["gruplar", _gruplar];
        private _fazSure = time - (_plan get "fazT");

        // v8.187 SENKRON KALKIS KAPISI: hazir bayragi (tasimaCtl[1]) gozlem tamam VE tanklar mevzilerine yaklasmis (< 450 m) / 420 sn dolmus iken acilir
        if (_plan getOrDefault ["hazirBekle", false] && {_faz in ["TOPLAN", "RECON", "TASIMA", "KUR"]}) then {
            private _reconOk = ((_plan getOrDefault ["reconG", []]) isEqualTo []) || {_plan getOrDefault ["reconTamam", false]} || {(_plan getOrDefault ["dogrulama", 0]) isEqualTo 2};
            private _tankOk = ((_plan getOrDefault ["zirhG", []]) findIf {
                private _zg = _x;
                private _zv = vehicle (leader _zg);
                private _zp = _zg getVariable ["lambs_danger_planZirhPoz", []];
                !isNull _zg && {_zv isNotEqualTo (leader _zg)} && {(_zp isEqualTo []) || {(_zv distance2D _zp) > 450}} && {!(_zg getVariable ["lambs_danger_planZirhVardi", false])}
            }) < 0;
            if ((_reconOk && _tankOk) || {(time - (_plan getOrDefault ["t0", time])) > 420}) then {
                _plan set ["hazirBekle", false];
                (_plan getOrDefault ["tasimaCtl", [false, true]]) set [1, true];
                diag_log format ["[PLAN] %1 SENKRON: nakil serbest birakildi (gozlem %2, tanklar %3, %4 sn)", _id, _reconOk, _tankOk, round (time - (_plan getOrDefault ["t0", time]))];
            };
        };

        missionNamespace setVariable ["lambs_danger_planTempoGecici", _plan getOrDefault ["tempo", 0]];
        private _tempo = _plan getOrDefault ["tempo", 0];
        // v8.138 RECON temas: gizlilik bozulduysa (GREEN = ates yok) serbest birak: YELLOW + AUTO durus; kesif unsuru donup kalmasin
        {
            private _rg2 = _x;
            if (!isNull _rg2 && {[_rg2] call _temasta} && {!(_rg2 getVariable ["lambs_danger_reconCikti", false])}) then {
                _rg2 setVariable ["lambs_danger_reconCikti", true];
                _rg2 setCombatMode "YELLOW";
                _rg2 setBehaviour "AWARE";
                _rg2 setSpeedMode "NORMAL";
                { if (alive _x && {isNull objectParent _x}) then { _x setUnitPos "AUTO"; }; } forEach (units _rg2);
                diag_log format ["[PLAN-RECON] %1 | %2 TEMAS: gizlilik bozuldu -> ates serbest (YELLOW), durus AUTO, ELITE temas kesme devralir", _id, groupId _rg2];
            };
        } forEach (_plan getOrDefault ["reconG", []]);
        // v8.163 ZIRH DESTEK: elle secilen tank / zirhli gruplar (ates pozisyonu, COMBAT, hedef) - her tur
        // IFV'ler piyadeyi indirince (aracTasima, tasimaCtl[5]) ZIRH DESTEK listesine eklenir
        {
            if (!isNull _x && {({alive _x} count (units _x)) > 0}) then {
                private _zl = _plan getOrDefault ["zirhG", []];
                if !(_x in _zl) then {
                    _zl pushBack _x;
                    _plan set ["zirhG", _zl];
                    _x setVariable ["lambs_danger_planAktif", true, true];
                    diag_log format ["[PLAN-ZIRH] %1 | %2 IFV ates destegi unsuru olarak eklendi", _id, groupId _x];
                };
            };
        } forEach ((_plan getOrDefault ["tasimaCtl", []]) param [5, []]);
        [_plan] call FUNC(planZirh);
        // v8.130 SIZMA / GIZLILIK ONCELIGI (tempo = sessiz / gizli, ya da baskin): toplan / ORP / kesif sirasinda temas yoksa ates yok (GREEN); objektife < 450 m'de comelerek (MIDDLE) ilerle;
        // temas olursa serbest (YELLOW, AUTO). SALDIRI baslayinca herkes AUTO + YELLOW. Doktrin: yaklasma gizli, ates ancak saldiri / temasta (sayi kitapta yok: 450 m = M16 etkili menzil tasarim kullanimi).
        if (_tempo isEqualTo 1 && {_faz in ["TOPLAN", "ORP", "KESIF", "TASIMA"]}) then {
            {
                private _g = _x;
                private _tm = [_g] call _temasta;
                private _yak = (leader _g) distance2D _obj;
                private _hedefPos = if (_tm || {_yak > 450} || {_faz in ["TOPLAN", "TASIMA"]}) then {"AUTO"} else {"MIDDLE"};
                if ((_g getVariable ["lambs_danger_gizliPos", ""]) isNotEqualTo _hedefPos) then {
                    _g setVariable ["lambs_danger_gizliPos", _hedefPos];
                    { if (alive _x && {isNull objectParent _x}) then { _x setUnitPos _hedefPos; }; } forEach (units _g);
                    diag_log format ["[PLAN] %1 GIZLILIK %2 | durus %3 | objektife %4 m | temas:%5", _id, groupId _g, _hedefPos, round _yak, _tm];
                };
                _g setCombatMode (["GREEN", "YELLOW"] select _tm);
            } forEach _gruplar;
        };
        private _sureSn = _plan getOrDefault ["sureSn", 0];
        // SURE SINIRI: ele gecirde hedef alinmadiysa CEKILME; savunmada plan biter
        if (_sureSn > 0 && {(time - (_plan get "t0")) > _sureSn} && {!(_faz in ["KUR", "CEKILME", "TOPLANMA", "DONUS", "BITTI", "IPTAL"])}) then {
            if (_tip isEqualTo 0) then {
                [_plan, "CEKILME", format ["SURE SINIRI (%1 sn) doldu, objektif alinamadi", _sureSn]] call _fazGec;
                { [_x] call _wpTemizle; [_x, _obj] call FUNC(tacticsRetreat); } forEach _gruplar;
            } else {
                [_plan, "BITTI", format ["SURE SINIRI (%1 sn) doldu", _sureSn]] call _fazGec;
            };
            continue
        };
        if (_faz isEqualTo "CEKILME") then {
            // v8.174 BASARISIZLIKTA BULUSMA: geride REZERV bekleyen tasima araclari (APC / kamyon) rally point'e gelir; piyade ile bulusur (kullanici: "mission fail olunca rally pointte bulusmadilar")
            if !(_plan getOrDefault ["cekilmeAraclar", false]) then {
                _plan set ["cekilmeAraclar", true];
                private _zg = _plan getOrDefault ["zirhG", []];
                private _sayi = 0;
                {
                    private _v = _x;
                    private _d = driver _v;
                    if (alive _v && {!isNull _d} && {!isPlayer _d} && {local _d} && {(side (group _d)) isEqualTo (_plan get "taraf")} && {!((group _d) in _zg)}
                        && {((_v getVariable ["lambs_danger_gorev", ""]) isEqualTo "TASIMA") || {((group _d) getVariable ["lambs_danger_gorev", ""]) isEqualTo "TASIMA"}}
                        && {!(_v getVariable ["lambs_danger_tasimaMesgul", false])}) then {
                        private _rpA = (_plan get "rp") getPos [14 * (_sayi + 1), (_plan get "B") - 90];
                        _sayi = _sayi + 1;
                        (group _d) setVariable ["lambs_danger_aracMedevacT", time];
                        (group _d) setBehaviour "SAFE";
                        (group _d) setSpeedMode "FULL";
                        _d enableAI "PATH"; _d enableAI "MOVE"; _d forceSpeed -1;
                        _v engineOn true;
                        _d doMove _rpA;
                        diag_log format ["[PLAN] %1 CEKILME: %2 (%3) rally point'e cagrildi (%4 m)", _id, getText (configOf _v >> "displayName"), groupId (group _d), round (_v distance2D _rpA)];
                    };
                } forEach (vehicles select {_x isKindOf "LandVehicle"});
            };
            if (_fazSure > 150) then {
                // v8.178: rally point sonrasi HQ / US'ye DONUS (aynı ciddiyette)
                if ((_plan getOrDefault ["hqPoz", []]) isNotEqualTo []) then { _plan set ["donusNeden", "basarisiz (cekilme)"]; [_plan, "DONUS", "rally point sonrasi HQ / US'ye donus"] call _fazGec; } else { [_plan, "BITTI", "cekilme tamamlandi"] call _fazGec; };
            };
            continue
        };
        // ---------------------------------------------------------------- DONUS (v8.178): iptal / basarisizlik sonrasi gruplar + araclar HQ / US'ye geri doner
        if (_faz isEqualTo "DONUS") then {
            private _hqP = _plan getOrDefault ["hqPoz", []];
            if (_hqP isEqualTo []) then { [_plan, "BITTI", "DONUS: HQ konumu yok"] call _fazGec; continue };
            if !(_plan getOrDefault ["donusBasladi", false]) then {
                _plan set ["donusBasladi", true];
                (_plan getOrDefault ["tasimaCtl", [false]]) set [0, true];   // devam eden / bekleyen nakil isleri iptal
                private _hqI = 0;
                {
                    private _g = _x;
                    private _hedef = _hqP getPos [25 + 18 * _hqI, 70 * _hqI];
                    _hqI = _hqI + 1;
                    (_plan get "notlar") set [groupId _g, _hedef];
                    [_g, [[_hedef, "MOVE", format ["HQ'ya donus (%1)", _plan getOrDefault ["hqId", "HQ"]], "AWARE", "NORMAL", 40]]] call _wpYaz;
                    _g setCombatMode "YELLOW";
                    { _x setUnitPos "AUTO"; _x doWatch objNull; _x setVariable ["lambs_danger_tasimaBekle", nil]; _x enableAI "PATH"; } forEach ((units _g) select {alive _x && {isNull objectParent _x}});
                } forEach _gruplar;
                // araclar: zirh destek gruplari + plana bagli TASIMA araclari HQ cevresine (yayilarak)
                private _araclar = [];
                { private _v = vehicle (leader _x); if (_v isNotEqualTo (leader _x)) then { _araclar pushBackUnique _v; }; } forEach (_plan getOrDefault ["zirhG", []]);
                { if (alive _x && {(_x getVariable ["lambs_danger_gorev", ""]) isEqualTo "TASIMA"} && {(side (group (driver _x))) isEqualTo (_plan get "taraf")}) then { _araclar pushBackUnique _x; }; } forEach (vehicles select {_x isKindOf "LandVehicle"});
                private _aI = 0;
                {
                    private _v = _x;
                    private _d = driver _v;
                    if (alive _v && {!isNull _d} && {!isPlayer _d} && {local _d}) then {
                        private _hv = _hqP getPos [60 + 40 * _aI, 35 + 60 * _aI];
                        _aI = _aI + 1;
                        (group _d) setVariable ["lambs_danger_planZirh", nil];
                        (group _d) setVariable ["lambs_danger_aracMedevacT", time];
                        (group _d) setBehaviour "SAFE"; (group _d) setSpeedMode "NORMAL";
                        _d enableAI "PATH"; _d enableAI "MOVE"; _d forceSpeed -1;
                        _v engineOn true;
                        _d doMove _hv;
                        diag_log format ["[PLAN] %1 DONUS: %2 (%3) HQ'ya (%4 m)", _id, getText (configOf _v >> "displayName"), groupId (group _d), round (_v distance2D _hv)];
                    };
                } forEach _araclar;
                diag_log format ["[PLAN] %1 DONUS basladi (%2): %3 grup + %4 arac -> %5 (%6)", _id, _plan getOrDefault ["donusNeden", "?"], count _gruplar, count _araclar, _plan getOrDefault ["hqId", "HQ"], mapGridPosition _hqP];
            };
            private _esik = ((_plan getOrDefault ["hqYar", 100]) * 0.7) max 80;
            private _vardiD = {(leader _x) distance2D _hqP < _esik} count _gruplar;
            if (_vardiD >= (count _gruplar) || {_fazSure > 900}) then { [_plan, "BITTI", format ["HQ'ya donuldu (%1/%2 grup)", _vardiD, count _gruplar]] call _fazGec; };
            continue
        };

        // plan bitti / iptal / grup yok
        if (_faz isEqualTo "IPTAL" || {_gruplar isEqualTo []} || {_faz isEqualTo "BITTI"}) then {
            { [_x] call _wpTemizle; _x setVariable ["lambs_danger_planAktif", nil, true]; _x setVariable ["lambs_danger_planId", nil]; } forEach (_plan get "gruplar");
            { if (!isNull _x) then { [_x] call _wpTemizle; _x setVariable ["lambs_danger_planAktif", nil, true]; _x setCombatMode "YELLOW"; _x setBehaviour "AWARE"; _x setSpeedMode "NORMAL"; { _x setUnitPos "AUTO"; _x doWatch objNull; } forEach (units _x); }; } forEach (_plan getOrDefault ["reconG", []]);
            (_plan getOrDefault ["tasimaCtl", [false, true]]) set [0, true];   // bekleyen / yoldaki nakil isi iptal (v8.132)
            { deleteMarker _x; } forEach (_plan get "isaretler");
            { _x setVariable ["lambs_danger_agirYasak", nil]; } forEach (_plan get "gruplar");
            lambs_danger_planCCPlar = (missionNamespace getVariable ["lambs_danger_planCCPlar", []]) select {(_x select 0) isNotEqualTo _id};
            // AAR ('ne oldu?'): faz sureleri, kayiplar, sonuc — logla + Zeus'lara sohbet mesaji
            private _ilk = _plan getOrDefault ["ilkSayi", createHashMap];
            private _kayipMetin = (_plan get "gruplar") apply {
                private _gi = groupId _x;
                private _bas = _ilk getOrDefault [_gi, 0];
                private _sag = {alive _x && {(lifeState _x) in ["HEALTHY", "INJURED"]} && {!(_x getVariable ["ACE_isUnconscious", false])}} count (units _x);
                private _bay = {alive _x && {((lifeState _x) in ["INCAPACITATED", "UNCONSCIOUS"]) || {_x getVariable ["ACE_isUnconscious", false]}}} count (units _x);
                format ["%1: %2 -> %3 etkin, %4 bayilmis, %5 olu", _gi, _bas, _sag, _bay, (_bas - _sag - _bay) max 0]
            };
            private _sonuc = switch (true) do {
                case (_faz isEqualTo "IPTAL"): {"IPTAL (Zeus)"};
                case (_gruplar isEqualTo []): {"GRUP KALMADI (plan basarisiz)"};
                case (_tip isEqualTo 1): {"SAVUNMA SURESI / PLAN BITTI"};
                case ((_plan getOrDefault ["fazGecmis", []]) findIf {(_x select 0) isEqualTo "TOPLANMA"} >= 0): {"OBJEKTIF ALINDI"};
                case ((_plan getOrDefault ["fazGecmis", []]) findIf {(_x select 0) isEqualTo "CEKILME"} >= 0): {"OBJEKTIF ALINAMADI (cekilme)"};
                default {"BELIRSIZ"};
            };
            private _aar = format ["[PLAN-OZET] %1 | SONUC: %2 | toplam %3 sn | fazlar: %4 | gruplar: %5 | MANUEL noktalar: %6 | uyarilar: %7",
                _id, _sonuc, round (time - (_plan getOrDefault ["kurT", _plan get "t0"])), (_plan getOrDefault ["fazGecmis", []]) apply {format ["%1 %2 sn", _x select 0, _x select 1]},
                _kayipMetin, _plan getOrDefault ["manuelNoktalar", []], _plan getOrDefault ["uyarilar", []]];
            // v8.134: istihbarat ozeti + atis zarari (sivil / dost / dusman)
            private _ist = format ["[PLAN-ISTIHBARAT] %1 | OZET: guven %2 | dogrulama %3 | iddia sayi %4 | rapor: %5", _id, ["YETERSIZ (iddia)", "ORTA", "KESIN (iddia)"] select ((_plan getOrDefault ["guven", 1]) min 2), ["tam kesif", "son dogrulama", "YOK (iddiaya guvenildi)"] select ((_plan getOrDefault ["dogrulama", 0]) min 2), _plan getOrDefault ["iddiaSayi", 0], _plan getOrDefault ["reconRapor", "rapor alinmadi"]];
            diag_log _ist;
            private _zrr = [];
            {
                _x params ["_t", "_hd", "_sv", "_df", "_dm"];
                _zrr pushBack format ["atis %1 (t+%2 sn): sivil %3/%4 oldu, dost %5/%6 oldu, dusman %7/%8 oldu", mapGridPosition _hd, round (_t - (_plan getOrDefault ["kurT", _plan get "t0"])), {!alive _x} count _sv, count _sv, {!alive _x} count _df, count _df, {!alive _x} count _dm, count _dm];
            } forEach (_plan getOrDefault ["atislar", []]);
            if (_zrr isNotEqualTo []) then {
                diag_log format ["[PLAN-ZARAR] %1 | atis sonrasi olenler (nedeni kesin atanamaz, atis noktasinin 250 m cevresindeki anlik listeye gore): %2", _id, _zrr];
                private _scu = (allCurators apply {getAssignedCuratorUnit _x}) select {!isNull _x};
                if (_scu isNotEqualTo []) then { [format ["ELITE PLAN %1 ZARAR: %2", _id, _zrr joinString " | "]] remoteExec ["systemChat", _scu]; };
            };
            diag_log _aar;
            private _cu = (allCurators apply {getAssignedCuratorUnit _x}) select {!isNull _x};
            if (_cu isNotEqualTo []) then { [format ["ELITE PLAN %1: %2 (%3 sn)", _id, _sonuc, round (time - (_plan getOrDefault ["kurT", _plan get "t0"]))]] remoteExec ["systemChat", _cu]; };
            diag_log format ["[PLAN] %1 BITTI (%2) | %3 sn", _id, ["tamam", ["iptal", "grup kalmadi"] select (_gruplar isEqualTo [])] select (_faz isEqualTo "IPTAL" || {_gruplar isEqualTo []}), round (time - (_plan get "t0"))];
            _bitenler pushBack _id;
            continue
        };

        // ---------------------------------------------------------------- KUR / TOPLAN
        if (_faz isEqualTo "KUR") then {
            if (_plan getOrDefault ["bekleOnay", false]) then {
                if !(_plan getOrDefault ["onayLog", false]) then {
                    _plan set ["onayLog", true];
                    diag_log format ["[PLAN] %1 ZEUS ONAYI BEKLENIYOR (H-saati): harita isaretleri hazir, 'ONAY VER' modulunu yerlestirin", _id];
                };
                continue
            };
            if (time < (_plan getOrDefault ["baslaT", 0])) then { continue };
            _plan set ["kurT", _plan get "t0"];
            _plan set ["t0", time];
            _plan set ["fazBasT", time];
            private _ilkSay = createHashMap;
            { _ilkSay set [groupId _x, {alive _x} count (units _x)]; } forEach _gruplar;
            _plan set ["ilkSayi", _ilkSay];
            { [_x, [[_rp, "MOVE", "RP (toplan)", "AWARE", "NORMAL", 50]]] call _wpYaz; } forEach _gruplar;
            // v8.132: nakil araclari plan baslayinca RP'ye yola cikar (piyade toplanirken); bindirme TOPLAN hazir olunca
            if (_tip isNotEqualTo 1 && {!(missionNamespace getVariable ["lambs_danger_tasimaOff", false])}) then {
                // v8.187 SENKRON KALKIS: kesif unsuru (RECON) ya da zirh destek (tank) varsa nakil araclari piyadeyi alip BEKLER (hazir = false); gozlem bitince ve tanklar mevzilerine yaklasinca (komuta dongusu) serbest birakilir
                // v8.188: recon unsuru icin tek bir arac ayrilir (ana nakilden once secilir; aracTasima isaretli araci almaz)
                if ((_plan getOrDefault ["reconG", []]) isNotEqualTo [] && {(_plan getOrDefault ["dogrulama", 0]) isNotEqualTo 2} && {!(_plan getOrDefault ["reconAracDene", false])}) then {
                    _plan set ["reconAracDene", true];
                    private _ra = ["SEC", _plan] call FUNC(reconArac);
                    if (!isNull _ra) then { _plan set ["reconArac", _ra]; };
                };
                private _bekleKos = ((_plan getOrDefault ["reconG", []]) isNotEqualTo [] && {(_plan getOrDefault ["dogrulama", 0]) isNotEqualTo 2}) || {(_plan getOrDefault ["zirhG", []]) isNotEqualTo []};
                _plan set ["tasimaCtl", [false, !_bekleKos, 0, 0, 0, [], true]];
                _plan set ["hazirBekle", _bekleKos];
                if (_bekleKos) then { diag_log format ["[PLAN] %1 SENKRON: nakil araclari piyadeyi alip bekleyecek (gozlem: %2 | tank / zirh: %3) - serbest birakma kosullari: gozlem tamam + tanklar mevzisine yakin (en cok 420 sn)", _id, (_plan getOrDefault ["reconG", []]) isNotEqualTo [], (_plan getOrDefault ["zirhG", []]) isNotEqualTo []]; };
                _plan set ["tasimaH", [_plan get "taraf", _gruplar, _rp, _obj, _B, (_plan get "ayar") getOrDefault ["orpM", 300], 6000, _plan get "tasimaCtl"] spawn FUNC(aracTasima)];
            };
            [_plan, "TOPLAN", format ["RP %1", mapGridPosition _rp]] call _fazGec;
            continue
        };
        if (_faz isEqualTo "TOPLAN") then {
            // v8.192 GEC KATILAN RECON (RPT 038c2564: Zeus 'RECON' gorevi plan kurulduktan 70 sn SONRA atandi -> "recon yola cikmadi"): TOPLAN suresince atanan recon plana alinir
            if (_tip isNotEqualTo 1 && {(_plan getOrDefault ["reconG", []]) isEqualTo []} && {!(_plan getOrDefault ["reconYapildi", false])} && {(_plan getOrDefault ["dogrulama", 0]) isNotEqualTo 2}) then {
                private _yeniR = allGroups select {
                    private _rl = leader _x;
                    (_x getVariable ["lambs_danger_gorev", ""]) isEqualTo "RECON" && {!isNull _rl} && {alive _rl} && {!isPlayer _rl} && {(side _x) isEqualTo (_plan get "taraf")}
                    && {({isPlayer _x} count (units _x)) isEqualTo 0} && {({alive _x} count (units _x)) >= 2} && {isNull objectParent _rl}
                    && {(_rl distance2D _obj) <= 4000} && {!(_x getVariable ["lambs_danger_planAktif", false])}
                };
                if (_yeniR isNotEqualTo []) then {
                    private _opY = _obj getPos [520, _B];
                    if (surfaceIsWater _opY) then { _opY = _obj getPos [450, _B]; };
                    _plan set ["reconG", _yeniR];
                    _plan set ["op", _opY];
                    { _x setVariable ["lambs_danger_planAktif", true, true]; } forEach _yeniR;
                    if !(_plan getOrDefault ["reconTamam", false]) then {
                        _plan set ["hazirBekle", true];
                        private _ctlR = _plan getOrDefault ["tasimaCtl", []];
                        if (count _ctlR > 1) then { _ctlR set [1, false]; };
                    };
                    if !(_plan getOrDefault ["reconAracDene", false]) then {
                        _plan set ["reconAracDene", true];
                        private _raY = ["SEC", _plan] call FUNC(reconArac);
                        if (!isNull _raY) then { _plan set ["reconArac", _raY]; };
                    };
                    diag_log format ["[PLAN-RECON] %1 | GEC KATILDI: recon %2 grup: %3 | OP %4 (objektiften %5 m) | nakil piyadeyi alip bekleyecek", _id, count _yeniR, _yeniR apply {groupId _x}, mapGridPosition _opY, round (_opY distance2D _obj)];
                };
            };
            // v8.192: recon yoksa canli gozlemle (herkes dogrulayabilir) hazirlik atisi KESIF'i beklemeden denenir (10 sn'de bir)
            if (!(_plan getOrDefault ["hazirlikAtildi", false]) && {(_plan getOrDefault ["topcu", 0]) in [1, 3]} && {(time - (_plan getOrDefault ["topcuDenT", -99])) > 10}) then {
                _plan set ["topcuDenT", time];
                private _firedC = [_plan, _obj, "HAZIRLIK (canli gozlem, recon yok)"] call _topcuAt;
                if (_firedC || {(_plan getOrDefault ["atisRet", ""]) isNotEqualTo "BEKLE"}) then { _plan set ["hazirlikAtildi", true]; };
            };
            private _hazir = {((leader _x) distance2D _rp) < 80 || {[_x] call _temasta}} count _gruplar;
            // v8.187: kesif unsuru varsa TOPLAN'in 300 sn zaman asimini beklemeden HEMEN gozleme gonderilir (once recon, sonra digerleri)
            private _reconOnce = (_tip isNotEqualTo 1) && {(_plan getOrDefault ["reconG", []]) isNotEqualTo []} && {!(_plan getOrDefault ["reconYapildi", false])} && {(_plan getOrDefault ["dogrulama", 0]) isNotEqualTo 2};
            if (_reconOnce || {_hazir >= (ceil ((count _gruplar) * 0.75))} || {_fazSure > 300} || {_plan getOrDefault ["tasimaTamam", false]} || {_plan getOrDefault ["reconTamam", false]} || {("tasimaH" in _plan) && {scriptDone (_plan get "tasimaH")} && {_fazSure > 20} && {((_plan getOrDefault ["tasimaCtl", [false, true, 0]]) param [2, 0]) > 0}}) then {
                // v8.131 RECON: gozlem noktasina gizlice (STEALTH + GREEN = ates gelene kadar ates yok) gidip bilgi toplar; raporu plan gruplarina isler
                if (_tip isNotEqualTo 1 && {(_plan getOrDefault ["dogrulama", 0]) isNotEqualTo 2} && {(_plan getOrDefault ["reconG", []]) isNotEqualTo []} && {!(_plan getOrDefault ["reconYapildi", false])}) then {
                    _plan set ["reconYapildi", true];
                    private _rgl = (_plan get "reconG") select {!isNull _x && {({alive _x} count (units _x)) > 0}};
                    private _opN = _plan get "op";
                    {
                        private _g = _x;
                        private _poz = _opN getPos [10 * _forEachIndex, _B + ([90, -90] select (_forEachIndex % 2 isEqualTo 1))];
                        // v8.188: recon araci varsa yaya waypoint ARAC INISINDAN sonra (RECON dali) yazilir
                        if (isNull (_plan getOrDefault ["reconArac", objNull])) then {
                        [_g, [[_poz, "MOVE", "RECON -> OP", "STEALTH", "LIMITED", 25]]] call _wpYaz;
                        private _wr = (waypoints _g) select ((count (waypoints _g)) - 1);
                        _wr setWaypointBehaviour "STEALTH";
                        _wr setWaypointCombatMode "GREEN";
                        _wr setWaypointSpeed "LIMITED";
                        _g setBehaviour "STEALTH";
                        _g setCombatMode "GREEN";
                        _g setSpeedMode "LIMITED";
                        { if (alive _x && {isNull objectParent _x}) then { _x setUnitPos "MIDDLE"; }; } forEach (units _g);
                        };
                        (_plan get "notlar") set [format ["%1_op", groupId _g], [_poz, -1]];
                    } forEach _rgl;
                    if (!isNull (_plan getOrDefault ["reconArac", objNull])) then {
                        _plan set ["reconAracH", ["CALIS", _plan, _rgl, _opN] spawn FUNC(reconArac)];
                    };
                    diag_log format ["[PLAN-RECON] %1 | recon OP'ye gidiyor (STEALTH + GREEN: ates gelene kadar ates yok) | %2 grup | OP %3", _id, count _rgl, mapGridPosition _opN];
                    [_plan, "RECON", format ["%1 grup gozlem noktasina", count _rgl]] call _fazGec;
                    continue
                };
                // v8.129: ele gecirde RP'de toplanan gruplar uygun kara araclariyla INIS NOKTASINA tasinir (objektiften >= 500 m); once TASIMA fazi
                if (_tip isNotEqualTo 1 && {!(_plan getOrDefault ["tasimaYapildi", false])} && {!(("tasimaH" in _plan) && {scriptDone (_plan get "tasimaH")})}) then {
                    _plan set ["tasimaYapildi", true];
                    if (!("tasimaH" in _plan) || {isNull (_plan get "tasimaH")}) then {
                        _plan set ["tasimaCtl", [false, true, 0, 0, 0, [], true]];
                        _plan set ["tasimaH", [_plan get "taraf", _gruplar, _rp, _obj, _B, (_plan get "ayar") getOrDefault ["orpM", 300], 6000, _plan get "tasimaCtl"] spawn FUNC(aracTasima)];
                    } else {
                        (_plan get "tasimaCtl") set [1, true];
                    };
                    [_plan, "TASIMA", "arac nakli (varsa)"] call _fazGec;
                    continue
                };
                if (_tip isEqualTo 1) then {
                    // SAVUN: objektif cevresinde sektorlu halka (komutan grubu merkezde degil, halkanin guvenli yaninda)
                    private _n = count _gruplar;
                    private _th = _plan getOrDefault ["tehditB", -1];
                    // DESTEK / MG grubu tehdit yonunun tam karsisina (sektor merkezi)
                    private _destekG = _gruplar select {(_roller getOrDefault [groupId _x, ""]) isEqualTo "DESTEK"};
                    private _digerG = _gruplar select {!(_x in _destekG)};
                    private _sirali = (_digerG select [0, floor ((count _digerG) / 2)]) + _destekG + (_digerG select [floor ((count _digerG) / 2), count _digerG]);
                    {
                        private _g = _x;
                        private _a = if (_th >= 0) then { _th + (if (_n <= 1) then {0} else {-110 + 220 * (_forEachIndex / (_n - 1))}) } else { _B + (360 / _n) * _forEachIndex };
                        private _poz = [_obj getPos [55, _a]] call _siperNokta;   // v8.181: sektor noktasi 40 m icinde siper yogunlugu en yuksek, kuru, cukur olmayan nokta
                        (_plan get "notlar") set [groupId _g, [_poz, _a]];
                        [_g, [[_poz, "MOVE", format ["MEVZI sektor %1", round _a], "AWARE", "NORMAL", 30]]] call _wpYaz;
                    } forEach _sirali;
                    [_plan, "MEVZI", format ["%1 sektor", _n]] call _fazGec;
                } else {
                    private _i = 0;
                    // v8.171: arac nakliyle inildiyse ORP'ye COMBAT ile (dusmana dogru, savas durusu) ilerle
                    private _orpBeh = ["AWARE", "COMBAT"] select ((((_plan getOrDefault ["tasimaCtl", []]) param [2, 0]) > 0));
                    {
                        private _g = _x;
                        private _r = _roller getOrDefault [groupId _g, "MANEVRA"];
                        private _hedef = if (_r isEqualTo "DESTEK") then { _sbf } else { [_orp, _i, _B] call _ofset };
                        if (_r isNotEqualTo "DESTEK") then { _i = _i + 1; };
                        (_plan get "notlar") set [groupId _g, _hedef];
                        [_g, [[_hedef, "MOVE", format ["%1 -> %2", _r, ["ORP", "SBF"] select (_r isEqualTo "DESTEK")], _orpBeh, "NORMAL", 40]]] call _wpYaz;
                        diag_log format ["[PLAN] %1 ROL %2 = %3 | hedef %4", _id, groupId _g, _r, mapGridPosition _hedef];
                    } forEach _gruplar;
                    [_plan, "ORP", "ORP / destek noktasina intikal"] call _fazGec;
                };
            };
            continue
        };

        // ---------------------------------------------------------------- RECON (gozlem noktasinda bilgi toplama; temas arama, ates yok)
        if (_faz isEqualTo "RECON") then {
            private _notlar = _plan get "notlar";
            // v8.195: recon gozlemi surerken de (rapor beklemeden) canli gozlem dogrulamasiyla hazirlik atisi denenir (RPT f82d65d0: recon OP'ye vardiktan 1.5 dk sonra oyun bitti, rapor gelmedi)
            if (!(_plan getOrDefault ["hazirlikAtildi", false]) && {(_plan getOrDefault ["topcu", 0]) in [1, 3]} && {(time - (_plan getOrDefault ["topcuDenT", -99])) > 10}) then {
                _plan set ["topcuDenT", time];
                private _firedV = [_plan, _obj, "HAZIRLIK (recon gozlemi sirasinda)"] call _topcuAt;
                if (_firedV || {(_plan getOrDefault ["atisRet", ""]) isNotEqualTo "BEKLE"}) then { _plan set ["hazirlikAtildi", true]; };
            };
            private _rg = (_plan get "reconG") select {!isNull _x && {({alive _x} count (units _x)) > 0}};
            private _vardi = 0;
            private _bozuldu = false;
            // v8.188 RECON ARACI: arac sessizce goturup indirene kadar bekle; sonra (ya da basarisizsa) yaya STEALTH waypoint yazilir
            private _raVar = !isNull (_plan getOrDefault ["reconArac", objNull]);
            private _raBitti = (_plan getOrDefault ["reconAracInis", false]) || {_plan getOrDefault ["reconAracBasarisiz", false]} || {!_raVar};
            if (_raVar && {_raBitti} && {!(_plan getOrDefault ["reconYayaYazildi", false])}) then {
                _plan set ["reconYayaYazildi", true];
                _plan set ["reconFazT", time];
                private _opR = _plan get "op";
                {
                    private _g = _x;
                    private _poz = (_notlar getOrDefault [format ["%1_op", groupId _g], [_opR, -1]]) select 0;
                    [_g, [[_poz, "MOVE", "RECON -> OP", "STEALTH", "LIMITED", 25]]] call _wpYaz;
                    private _wr = (waypoints _g) select ((count (waypoints _g)) - 1);
                    _wr setWaypointBehaviour "STEALTH";
                    _wr setWaypointCombatMode "GREEN";
                    _wr setWaypointSpeed "LIMITED";
                    _g setBehaviour "STEALTH";
                    _g setCombatMode "GREEN";
                    _g setSpeedMode "LIMITED";
                } forEach _rg;
                diag_log format ["[PLAN-RECON] %1 | recon araci isi bitti (%2) -> son yaklasma yaya", _id, ["basarisiz", "indirdi"] select (_plan getOrDefault ["reconAracInis", false])];
            };
            private _fazSureR = if (_raVar) then {time - (_plan getOrDefault ["reconFazT", time])} else {_fazSure};
            {
                private _g = _x;
                private _t = _notlar getOrDefault [format ["%1_op", groupId _g], []];
                if ([_g] call _temasta) then { _bozuldu = true; };
                if (_t isNotEqualTo [] && {_raBitti}) then {
                    if (((leader _g) distance2D (_t select 0)) < 40 || {_fazSureR > 240}) then {
                        if ((_t select 1) < 0) then {
                            _t set [1, time];
                            { if (alive _x && {isNull objectParent _x}) then { _x setUnitPos "DOWN"; }; } forEach (units _g);
                            (leader _g) doWatch _obj;
                            diag_log format ["[PLAN-RECON] %1 | %2 OP'ye vardi (%3 m), gozlem basladi", _id, groupId _g, round ((leader _g) distance2D _obj)];
                        };
                        _vardi = _vardi + 1;
                    };
                };
            } forEach _rg;
            if (_vardi >= (count _rg) && {!("reconVarT" in _plan)}) then { _plan set ["reconVarT", time]; };
            private _gozlemS = if (!("reconVarT" in _plan)) then {0} else {time - (_plan get "reconVarT")};
            private _gozlemHedef = [90, 45, 20] select ((_plan getOrDefault ["dogrulama", 0]) min 2);
            if (_rg isEqualTo [] || {_bozuldu} || {_gozlemS >= _gozlemHedef} || {_fazSure > 900} || {_fazSureR > 420}) then {
                // RAPOR (recon grubunun gozlemi): dusman + sivil sayisi, iddia farki, komutan inanci guncellenir
                private _rap = [_plan, [_rg, _gruplar] select (_rg isEqualTo []), _bozuldu, _gozlemS, "recon"] call _gozlemRapor;
                _plan set ["reconTamam", true];
                // v8.189: topcu hazirligi recon raporundan HEMEN sonra (piyade yaklasirken); onceden ancak ORP'de (KESIF) atiliyordu ve plan oraya hic ulasmiyordu (RPT aee29fdd: 15 dk, 0 atis). Izin / RED kurallari _topcuAt icinde
                if (!(_plan getOrDefault ["hazirlikAtildi", false]) && {(_plan getOrDefault ["topcu", 0]) in [1, 3]}) then {
                    private _firedR = [_plan, _obj, "HAZIRLIK (recon raporu sonrasi)"] call _topcuAt;
                    if (_firedR || {(_plan getOrDefault ["atisRet", ""]) isNotEqualTo "BEKLE"}) then { _plan set ["hazirlikAtildi", true]; };
                };
                [_plan, "TOPLAN", "recon raporu alindi"] call _fazGec;
            };
            continue
        };

        // ---------------------------------------------------------------- TASIMA (arac nakli bitince TOPLAN'a doner; gruplar inis noktasindadir)
        if (_faz isEqualTo "TASIMA") then {
            private _th = _plan getOrDefault ["tasimaH", scriptNull];
            // v8.192: recon yoksa canli gozlemle (herkes dogrulayabilir) hazirlik atisi KESIF'i beklemeden denenir (10 sn'de bir)
            if (!(_plan getOrDefault ["hazirlikAtildi", false]) && {(_plan getOrDefault ["topcu", 0]) in [1, 3]} && {(time - (_plan getOrDefault ["topcuDenT", -99])) > 10}) then {
                _plan set ["topcuDenT", time];
                private _firedC = [_plan, _obj, "HAZIRLIK (canli gozlem, recon yok)"] call _topcuAt;
                if (_firedC || {(_plan getOrDefault ["atisRet", ""]) isNotEqualTo "BEKLE"}) then { _plan set ["hazirlikAtildi", true]; };
            };
            // v8.138: plan gruplari ates altindaysa (arac yolda olsa bile) nakil iptal: piyade oldugu yerde savasir / plan devam eder
            if (!scriptDone _th && {(_gruplar findIf {[_x] call _temasta}) >= 0} && {!((_plan getOrDefault ["tasimaCtl", [false]]) select 0)}) then {
                (_plan getOrDefault ["tasimaCtl", [false]]) set [0, true];
                diag_log format ["[PLAN] %1 TASIMA: plan grubu temasta -> nakil iptal (binenler oldugu yerde iner)", _id];
            };
            if (_fazSure > 420 && {!scriptDone _th}) then {
                (_plan getOrDefault ["tasimaCtl", [false]]) set [0, true];
                diag_log format ["[PLAN] %1 TASIMA zaman asimi (420 sn): nakil iptal, gruplar oldugu yerden devam", _plan get "id"];
                _plan set ["tasimaTamam", true];
                _plan set ["tasimaH", scriptNull];
                [_plan, "TOPLAN", "arac nakli zaman asimi"] call _fazGec;
                continue
            };
            // v8.137 SEFER (v8.163: ERKEN): ilk seferde araca sigmayan uzaktaki askerler icin ek sefer; artik TUM araclar bindirmeyi bitirir bitirmez (nakil isi bitmeyi beklemeden) ve bos arac varsa baslar
            private _ctlS = _plan getOrDefault ["tasimaCtl", [false, true, 0]];
            private _bindiHepsi = ((_ctlS param [4, 0]) > 0) && {(_ctlS param [3, 0]) >= (_ctlS param [4, 0])};
            if ((scriptDone _th || {_bindiHepsi && {_fazSure > 25}}) && {(_plan getOrDefault ["sefer", 1]) < 3} && {_fazSure < 400} && {(_ctlS param [2, 0]) > 0} && {(time - (_plan getOrDefault ["seferT", -999])) > 45}) then {
                private _dropMS = (500 max (((_plan get "ayar") getOrDefault ["orpM", 300]) + 150));
                private _kalan = 0;
                private _kalanBirim = [];
                { { if (alive _x && {isNull objectParent _x} && {(_x distance2D _obj) > (_dropMS + 400)}) then { _kalan = _kalan + 1; _kalanBirim pushBack _x; }; } forEach (units _x); } forEach _gruplar;
                // v8.174: 2-3 askeri icin sefer yapilmaz (RPT d0839622: 2 asker icin sivil sihhiye kamyonuyla 2 sefer, nakil 568 sn surdu); en az 4 asker ya da tasinanin %20'si
                if (_kalan >= 4 || {_kalan >= 2 && {_kalan >= (0.2 * (_ctlS param [2, 0]))}}) then {
                    // bos (nakilde olmayan) uygun arac var mi? yoksa sayaci bosa harcama, sonra tekrar bak
                    private _kp = [0, 0, 0];
                    { _kp = [(_kp select 0) + ((getPosATL _x) select 0), (_kp select 1) + ((getPosATL _x) select 1), 0]; } forEach _kalanBirim;
                    _kp = [(_kp select 0) / _kalan, (_kp select 1) / _kalan, 0];
                    private _bosArac = vehicles select {
                        alive _x && {_x isKindOf "LandVehicle"} && {canMove _x} && {(_x emptyPositions "cargo") >= 1} && {!(_x getVariable ["lambs_danger_tasimaMesgul", false])}
                        && {(getNumber (configOf _x >> "attendant")) isEqualTo 0} && {!(_x getVariable ["lambs_danger_gorev", ""] in ["MEDEVAC", "HARIC", "KARAKOL_ARAC"])} && {!((group (driver _x)) getVariable ["lambs_danger_gorev", ""] in ["MEDEVAC", "HARIC", "KARAKOL_ARAC"])}
                        && {!isNull (driver _x)} && {!isPlayer (driver _x)} && {(side (group (driver _x))) isEqualTo (_plan get "taraf")} && {(_x distance2D _kp) < 6000}
                        && {!((group (driver _x)) getVariable ["lambs_danger_planAktif", false])}
                    };
                    if (_bosArac isNotEqualTo []) then {
                        _plan set ["sefer", (_plan getOrDefault ["sefer", 1]) + 1];
                        _plan set ["seferT", time];
                        private _yh = [_plan get "taraf", _gruplar, _rp, _obj, _B, (_plan get "ayar") getOrDefault ["orpM", 300], 6000, _ctlS] spawn FUNC(aracTasima);
                        _plan set ["tasimaYardim", (_plan getOrDefault ["tasimaYardim", []]) + [_yh]];
                        diag_log format ["[PLAN] %1 TASIMA %2. SEFER: geride kalan %3 asker (inis noktasindan > 400 m uzakta) | bos arac %4", _id, _plan get "sefer", _kalan, count _bosArac];
                        continue
                    } else {
                        if ((time - (_plan getOrDefault ["seferUyariT", -999])) > 60) then {
                            _plan set ["seferUyariT", time];
                            diag_log format ["[PLAN] %1 TASIMA: geride %2 asker kaldi ama bos arac yok (tum araclar nakilde / uygun degil); arac donunce tekrar bakilacak", _id, _kalan];
                        };
                    };
                };
            };
            // v8.174: sefer en cok 150 sn; sure dolarsa yardimci isler iptal edilir ve faz biter
            private _yardimBitti = ((_plan getOrDefault ["tasimaYardim", []]) findIf {!scriptDone _x}) isEqualTo -1;
            if (scriptDone _th && {!_yardimBitti} && {(time - (_plan getOrDefault ["seferT", time])) > 150}) then {
                (_plan getOrDefault ["tasimaCtl", [false]]) set [0, true];
                diag_log format ["[PLAN] %1 TASIMA: sefer 150 sn'yi asti, kalanlar yuruyerek devam", _id];
                _yardimBitti = true;
            };
            if (scriptDone _th && {_yardimBitti}) then {
                _plan set ["tasimaTamam", true];
                [_plan, "TOPLAN", "arac nakli bitti"] call _fazGec;
            };
            continue
        };

        // ---------------------------------------------------------------- ELE GECIR: ORP -> KESIF
        if (_faz isEqualTo "ORP") then {
            private _notlar = _plan get "notlar";
            private _vardi = {
                private _h = _notlar getOrDefault [groupId _x, _orp];
                ((leader _x) distance2D _h) < 70 || {[_x] call _temasta}
            } count _gruplar;
            // temastaki grubu zorlamama; temas kesilince hedefe yeniden yonlendir
            {
                private _g = _x;
                private _h = _notlar getOrDefault [groupId _g, _orp];
                if (!([_g] call _temasta) && {((leader _g) distance2D _h) > 90} && {(time - (_g getVariable ["lambs_danger_planYenileT", -999])) > 25}) then {
                    _g setVariable ["lambs_danger_planYenileT", time];
                    [_g, [[_h, "MOVE", format ["%1 -> %2", _roller getOrDefault [groupId _g, "?"], "hedef"], "AWARE", "NORMAL", 40]]] call _wpYaz;
                };
            } forEach _gruplar;
            if (_vardi >= (count _gruplar) || {_fazSure > 280}) then {
                { _x setBehaviour "AWARE"; _x setSpeedMode "LIMITED"; } forEach _gruplar;
                [_plan, "KESIF", "ORP'de guvenlik / kesif (40 sn)"] call _fazGec;
            };
            continue
        };
        if (_faz isEqualTo "KESIF") then {
            private _topcuTip = _plan getOrDefault ["topcu", 0];
            if (!(_plan getOrDefault ["hazirlikAtildi", false]) && {_topcuTip in [1, 3]} && {(time - (_plan getOrDefault ["topcuDenT", -99])) > 10}) then {
                _plan set ["topcuDenT", time];
                private _fired = [_plan, _obj, "HAZIRLIK"] call _topcuAt;
                if (_fired || {(_plan getOrDefault ["atisRet", ""]) isNotEqualTo "BEKLE"}) then { _plan set ["hazirlikAtildi", true]; };
            };
            // KESIF = ORP'de guvenlik halti: TC 3-21.76 s. 6-22: short halt tipik 1-2 dk, long halt > 2 dk -> dengeli 60 sn, sessiz 90 sn, hizli 30 sn (kitap araligi icinde; secim tasarim)
            private _kesifS = (([60, 90, 30] select _tempo)) max ([0, 35] select (_topcuTip in [1, 3]));
            // v8.134: kesif kisa / uzun: dogrulama 0 tam (guven yetersizse x2), 1 son dogrulama (30 sn), 2 yok (20 sn)
            private _dgz = _plan getOrDefault ["dogrulama", 0];
            private _kesifS2 = switch (_dgz) do { case 1: {(_kesifS min 30)}; case 2: {20}; default {_kesifS * ([1, 2] select ((_plan getOrDefault ["guven", 1]) isEqualTo 0))} };
            _kesifS2 = _kesifS2 * ([(_gruplar param [0, grpNull]), "kesifCarpan", 1] call FUNC(dk));   // v8.143 doktrin carpani (RUS 0.6: tempo)
            if (_fazSure > _kesifS2) then {
                // plan gruplari bu noktaya kadar gozlediklerini rapor eder (recon raporu yoksa); sonra bekleyen hazirlik atisi yeniden degerlendirilir
                if (_dgz isNotEqualTo 2 && {!(_plan getOrDefault ["raporHazir", false])}) then { [_plan, _gruplar, false, _fazSure, "ORP gozlemi (recon yok)"] call _gozlemRapor; };
                if (!(_plan getOrDefault ["hazirlikAtildi", false]) && {_topcuTip in [1, 3]}) then {
                    _plan set ["hazirlikAtildi", true];
                    [_plan, _obj, "HAZIRLIK (dogrulamadan sonra)"] call _topcuAt;
                };
                private _maneuv = _gruplar select {(_roller getOrDefault [groupId _x, "MANEVRA"]) isEqualTo "MANEVRA"};
                private _i = 0;
                {
                    private _g = _x;
                    private _kanat = (_plan get "kanatGerek") && {(count _maneuv) >= 2};
                    if (_kanat) then {
                        private _k = (_plan get "kanatNokta") select (_i mod 2);
                        [_g, [[_k, "MOVE", "KANAT noktasi", "AWARE", "NORMAL", 40]]] call _wpYaz;
                        [_g, "KANAT", [_k, "plan"]] call FUNC(hqEmir);
                        (_plan get "notlar") set [format ["%1_kanat", groupId _g], [_k, time]];
                        diag_log format ["[PLAN] %1 KANAT %2 -> %3", _id, groupId _g, mapGridPosition _k];
                    } else {
                        [_g, [[_obj, "SAD", "SALDIRI (objektif)", "COMBAT", "NORMAL", 60]]] call _wpYaz;   // Zeus'ta objektif waypoint'i gorunur
                        [_g, "SALDIRI", [_obj]] call FUNC(hqEmir);
                    };
                    _i = _i + 1;
                } forEach _maneuv;
                { if ((_roller getOrDefault [groupId _x, ""]) isEqualTo "DESTEK") then { _x setCombatMode (["RED", "YELLOW"] select (_plan getOrDefault ["sivil", false])); _x setBehaviour "COMBAT"; } else { _x setCombatMode "YELLOW"; }; } forEach _gruplar;
                if ((_plan getOrDefault ["topcu", 0]) in [2, 3]) then { [_plan, _obj, "CAGRI (saldiri basi)"] call _topcuAt; _plan set ["cagriT", time]; };
                { _x setVariable ["lambs_danger_gizliPos", ""]; { if (alive _x && {isNull objectParent _x}) then { _x setUnitPos "AUTO"; }; } forEach (units _x); _x setCombatMode "YELLOW"; } forEach _gruplar;
                [_plan, "SALDIRI", format ["manevra %1 grup, destek ates baslar", count _maneuv]] call _fazGec;
            };
            continue
        };

        // ---------------------------------------------------------------- SALDIRI
        if (_faz isEqualTo "SALDIRI") then {
            private _notlar = _plan get "notlar";
            private _maneuv = _gruplar select {(_roller getOrDefault [groupId _x, "MANEVRA"]) isEqualTo "MANEVRA"};
            // kanat noktasina varinca (60 m) / 120 sn sonra SALDIRI emri
            {
                private _g = _x;
                private _kn = _notlar getOrDefault [format ["%1_kanat", groupId _g], []];
                if (_kn isNotEqualTo []) then {
                    if (((leader _g) distance2D (_kn select 0)) < 60 || {(time - (_kn select 1)) > 120}) then {
                        [_g, [[_obj, "SAD", "SALDIRI (objektif)", "COMBAT", "NORMAL", 60]]] call _wpYaz;
                        [_g, "SALDIRI", [_obj]] call FUNC(hqEmir);
                        _notlar deleteAt (format ["%1_kanat", groupId _g]);
                        diag_log format ["[PLAN] %1 SALDIRI %2 (kanattan)", _id, groupId _g];
                    };
                };
            } forEach _maneuv;
            // destek ateşi: objektife baski; manevra lideri objektife < 45 m ise 40 m ileri kaydir (dost atesi)
            if (time > (_plan getOrDefault ["destekT", 0])) then {
                _plan set ["destekT", time + 8];
                private _yakinM = 9999;
                private _ml = objNull;
                { private _dm = (leader _x) distance2D _obj; if (_dm < _yakinM) then { _yakinM = _dm; _ml = leader _x; }; } forEach _maneuv;
                private _hedefAtes = _obj;
                if (_yakinM < 45 && {!isNull _ml}) then { _hedefAtes = _obj getPos [40, _ml getDir _obj]; };
                {
                    private _g = _x;
                    if ((_roller getOrDefault [groupId _g, ""]) in ["DESTEK"] && {!(_plan getOrDefault ["sivil", false])}) then {
                        {
                            private _u = _x;
                            if (alive _u && {isNull objectParent _u} && {(lifeState _u) in ["HEALTHY", "INJURED"]} && {!(time < (_u getVariable [QGVAR(tcccBusy), 0]))}) then {
                                private _rol = [_u] call (missionNamespace getVariable ["lambs_danger_fnc_getUnitRole", {"RIFLE"}]);
                                if (!(_u getVariable [QGVAR(mermiTasarruf), false]) || {_rol isEqualTo "MG"}) then {
                                    _u doSuppressiveFire (_hedefAtes getPos [random 7, random 360]);
                                };
                            };
                        } forEach (units _g);
                    };
                } forEach _gruplar;
            };
            // objektif temiz: yakin (< 80 m) duşman 30 sn bilinmiyor ve bir manevra lideri objektife < 50 m
            private _dusmanVar = false;
            {
                private _g = _x;
                { if (alive _x && {((side _g) getFriend (side _x)) < 0.6} && {(_x distance2D _obj) < 80} && {(_g knowsAbout _x) >= 0.8}) then { _dusmanVar = true; }; } forEach (_obj nearEntities ["CAManBase", 80]);
            } forEach _gruplar;
            if (_dusmanVar) then { _plan set ["dusmanT", time]; };
            if (_dusmanVar && {(_plan getOrDefault ["topcu", 0]) in [2, 3]} && {_fazSure > 150} && {(time - (_plan getOrDefault ["cagriT", 0])) > 120}) then {
                _plan set ["cagriT", time];
                [_plan, _obj, "CAGRI (objektif temizlenmedi)"] call _topcuAt;
            };
            private _yakinM2 = 9999;
            { _yakinM2 = _yakinM2 min ((leader _x) distance2D _obj); } forEach _maneuv;
            private _baskinS = _plan getOrDefault ["baskinS", 0];
            if (_baskinS > 0) then {
                // v8.128 BASKIN (vur-cekil): hedef temizlenince ya da baskin suresi dolunca TOPLANMA yerine CEKILME (karakol baskini canlandirmasi)
                private _temiz = (_yakinM2 < 50 && {(time - (_plan getOrDefault ["dusmanT", _plan get "fazT"])) > 30});
                if (_temiz || {_fazSure > _baskinS}) then {
                    [_plan, "CEKILME", [format ["BASKIN: hedef temiz (manevra %1 m), cekiliyor", round _yakinM2], format ["BASKIN SURESI (%1 sn) doldu, cekiliyor", _baskinS]] select (!_temiz)] call _fazGec;
                    { [_x] call _wpTemizle; [_x, _obj] call FUNC(tacticsRetreat); } forEach _gruplar;
                };
            } else {
                if ((_yakinM2 < 50 && {(time - (_plan getOrDefault ["dusmanT", _plan get "fazT"])) > 30}) || {_fazSure > 480}) then {
                    [_plan, "TOPLANMA", [format ["objektif temiz (manevra %1 m)", round _yakinM2], "SURE DOLDU (480 sn)"] select (_fazSure > 480)] call _fazGec;
                };
            };
            continue
        };

        // ---------------------------------------------------------------- TOPLANMA (cevre savunmasi + reorganizasyon)
        if (_faz isEqualTo "TOPLANMA") then {
            private _notlar = _plan get "notlar";
            if !(_plan getOrDefault ["fazHazir", false]) then {
                _plan set ["fazHazir", true];
                private _n = count _gruplar;
                {
                    private _g = _x;
                    private _a = _B + (360 / _n) * _forEachIndex;
                    private _poz = _obj getPos [45, _a];
                    _notlar set [format ["%1_tpl", groupId _g], [_poz, false]];
                    [_g, [[_poz, "MOVE", format ["TOPLANMA sektor %1", round _a], "AWARE", "NORMAL", 30]]] call _wpYaz;
                    _g setCombatMode "YELLOW";
                } forEach _gruplar;
            };
            // sektora varinca (45 m) / 90 sn sonra toparlanma: sayim, rapor, guvenlik (TC 3-21.76 consolidate and reorganize)
            {
                private _g = _x;
                private _t = _notlar getOrDefault [format ["%1_tpl", groupId _g], []];
                if (_t isNotEqualTo [] && {!(_t select 1)} && {(((leader _g) distance2D (_t select 0)) < 45) || {_fazSure > 90}}) then {
                    _t set [1, true];
                    [_g, _obj getPos [200, _B]] call FUNC(toparlan);
                };
            } forEach _gruplar;
            if (_fazSure > 180) then { [_plan, "BITTI", "toparlanma suresi doldu"] call _fazGec; };
            continue
        };

        // ---------------------------------------------------------------- SAVUN: MEVZI -> BEKLE
        if (_faz isEqualTo "MEVZI") then {
            private _notlar = _plan get "notlar";
            private _vardi = {
                private _n = _notlar getOrDefault [groupId _x, [_obj, 0]];
                ((leader _x) distance2D (_n select 0)) < 50 || {[_x] call _temasta}
            } count _gruplar;
            if (_vardi >= (count _gruplar) || {_fazSure > 240}) then {
                {
                    private _g = _x;
                    private _n = _notlar getOrDefault [groupId _g, [_obj, _B]];
                    // v8.171: en yakin bina (garrison) + bos statik silahlar + COMBAT / comelme -> fnc_mevziKur
                    [_g, _n select 0, _n select 1] call FUNC(mevziKur);
                } forEach _gruplar;
                [_plan, "BEKLE", "sektorlar tutuldu, garrison / mevzi"] call _fazGec;
            };
            continue
        };
        if (_faz isEqualTo "BEKLE") then {
            if (_fazSure > (missionNamespace getVariable ["lambs_danger_planSavunmaS", 1200])) then { [_plan, "BITTI", "savunma suresi doldu"] call _fazGec; };
            continue
        };
    } forEach lambs_danger_planlar;
    { lambs_danger_planlar deleteAt _x; } forEach _bitenler;
    missionNamespace setVariable ["lambs_danger_planAdim", "tur bitti"];
};
