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
    // v8.261: gozlem kalitesi (hibrit kuvvet tahmini): sure / 40 sn (en cok 1); recon disi canli gozlem en cok 0.6; temas (gizlilik bozuldu) x0.7
    _plan set ["gozKalite", (((_gozlemS / 40) min 1) min ([0.6, 1] select (_etiket isEqualTo "recon"))) * ([1, 0.7] select _bozuldu)];
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
    // v8.199 BASIT TOPCU (kullanici: "artillery basit olsun, opsiyonel secilebilsin"): dogrulama beklenmez; RED / menzil kurallari _topcuAt icinde kalir
    if ((_plan getOrDefault ["topcuBasit", 0]) isEqualTo 1) exitWith { [true, "BASIT topcu modu: dogrulama beklenmedi", false] };
    if (_dg isEqualTo 2) exitWith { [true, format ["DOGRULAMA YOK: iddiaya guvenildi (guven %1)", ["yetersiz", "orta", "kesin"] select ((_plan getOrDefault ["guven", 1]) min 2)], false] };
    // v8.192 CANLI GOZLEM: recon yoksa (ya da rapor gelmediyse) taraftaki HERKES dogrulayabilir: herhangi bir dost grup liderinin objektifin 500 m cevresinde bildigi (knowsAbout > 0.5) dusman gozlenmis sayilir
    private _objC = _plan get "obj";
    private _tfC = _plan get "taraf";
    private _canli = 0;
    {
        private _gl = leader _x;
        if (!isNull _gl && {alive _gl} && {(side _x) isEqualTo _tfC}) then {
            { if (((_tfC getFriend (_x select 2)) < 0.6) && {((_x select 0) distance2D _objC) < 500} && {(_gl knowsAbout (_x select 4)) > 0.5} && {[_x select 4] call FUNC(gercekHedef)}) then { _canli = _canli + 1; }; } forEach (_gl nearTargets 900);
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
    // v8.285 TOPCU YEREL DEGIL (kullanici: 'topcu ates testi icin 2S1 spawnladim, sunucuda yerel degil dedi'): Zeus'la yaratilan arac + murettebat Zeus istemcisinde yerel kalir; doArtilleryFire yerel nisanci ister.
//   Genel devir bekcisi (fnc_grupSunucuDevir) yeni gruplari 120 sn bekletir. Topcu araci yerel degilse murettebat gruplari BURADA hemen sunucuya devredilir (oyuncu / uzaktan kontrol yoksa, 60 sn'de en fazla bir kez);
//   bu seansta atis yapilmaz, bir sonraki seansta yerel olur. Log: [PLAN-TOPCU] ... DEVIR. Kapatma: lambs_danger_topcuDevirOff = true.
    if (isServer && {!(missionNamespace getVariable ["lambs_danger_topcuDevirOff", false])}) then {
        {
            private _tv = _x;
            if (alive _tv && {(side (group _tv)) isEqualTo _taraf} && {(getNumber (configOf _tv >> "artilleryScanner")) > 0} && {!local _tv} && {!isNull (gunner _tv)} && {!isPlayer (gunner _tv)}) then {
                private _grlar = [];
                { private _gx = group _x; if (!isNull _gx && {!(_gx in _grlar)}) then { _grlar pushBack _gx; }; } forEach (crew _tv);
                private _uygun = (_grlar findIf {
                    ((units _x) findIf {isPlayer _x}) >= 0
                    || {((units _x) findIf {!isNull (_x getVariable ["bis_fnc_moduleRemoteControl_owner", objNull])}) >= 0}
                }) < 0;
                if (_uygun) then {
                    {
                        if ((time - (_x getVariable [QGVAR(topcuDevirT), -999])) > 60) then {
                            _x setVariable [QGVAR(topcuDevirT), time];
                            diag_log format ["[PLAN-TOPCU] %1 | %2 | %3 sunucuda yerel degil -> murettebat grubu %4 sunucuya DEVREDILDI (sahip makine %5); bu seansta atis yok, sonraki seansta atar", _plan get "id", _ad, typeOf _tv, groupId _x, groupOwner _x];
                            _x setGroupOwner 2;
                        };
                    } forEach _grlar;
                };
            };
        } forEach (vehicles select {alive _x && {(getNumber (configOf _x >> "artilleryScanner")) > 0}});
    };
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
                // v8.206 ATIS PACELEME (kullanici RPT ad7a3eb4: 2 M109 x 4 mermi ayni anda 21 askerin ustune dustu; ACE frag "Cannot create non-ai vehicle ace_explosion_reflection_*" x34 + 8 olum + ragdoll, 5 sn sonra SUNUCU DONDU): mermiler 2'serli partiler halinde 6 sn arayla, toplar 3 sn arayla baslar
                [_v, _nokta, _mg] call FUNC(topcuAtisHazirla);   // v8.287: hareket emri iptal, davranis / combatMode, atis tanisi ([TOPCU-ATIS])
                [_v, _nokta, _mg, _mermi, _forEachIndex] spawn {
                    params ["_tv", "_tn", "_tm", "_tk", "_ti"];
                    private _parti = missionNamespace getVariable ["lambs_danger_topcuPartiN", 2];
                    private _aralik = missionNamespace getVariable ["lambs_danger_topcuAralikS", 6];
                    sleep (3 * _ti);
                    while {_tk > 0 && {alive _tv} && {canFire _tv} && {!isNull (gunner _tv)}} do {
                        private _n = _parti min _tk;
                        _tv doArtilleryFire [_tn getPos [random 30, random 360], _tm, _n];
                        _tk = _tk - _n;
                        if (_tk > 0) then { sleep _aralik; };
                    };
                };
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

// v8.254 KAYIP -> HQ'YA DONUS (kullanici: 'bir taraf kaybedince HQ ya geri donsun, sonuna kadar savasmasin'; FM 3-98 3-56: geri cekilme olcutu onceden verilir, kayip tabanli; esikler TASARIM):
//   plan gruplari bounding geri cekilmeyle (tacticsRetreat, tehdit yonunun TERSINE) cekilir -> CEKILME fazi -> HQ / US'ye DONUS (HQ yoksa rally point'e); mevzi tutma kilidi (hendekte) birakilir.
//   Tetikler: ele gecir ORP / KESIF / SALDIRI'da toplam kayip >= %50 (ilk >= 8 asker); savunma BEKLE'de kayip >= %50 ve bilinen dusman >= 2 (ilk >= 6). Kapatma: lambs_danger_kayipDonusOff = true.
private _kayipCekil = {
    params ["_plan", "_neden", ["_tehdit", []]];
    private _gl = (_plan get "gruplar") select {!isNull _x && {({alive _x} count (units _x)) > 0}};
    private _thP = if (_tehdit isEqualTo []) then {_plan get "obj"} else {_tehdit};
    _plan set ["donusNeden", _neden];
    _plan set ["kayipCekildi", true];
    if ((_plan getOrDefault ["hqPoz", []]) isEqualTo []) then {
        _plan set ["hqPoz", _plan get "rp"];
        _plan set ["hqYar", 60];
        _plan set ["hqId", "rally point"];
    };
    {
        private _g = _x;
        [_g] call _wpTemizle;
        _g setVariable [QGVAR(hendekte), nil];
        _g setVariable [QGVAR(mevziIlk), nil];
        _g setVariable [QGVAR(hendekEk), nil];
        { if (alive _x && {isNull objectParent _x}) then { _x setUnitPos "AUTO"; _x doWatch objNull; }; } forEach (units _g);
        [_g, _thP] call FUNC(tacticsRetreat);
    } forEach _gl;
    diag_log format ["[PLAN-KAYIP-DONUS] %1 | %2 | %3 grup cekiliyor -> %4 (%5)", _plan get "id", _neden, count _gl, _plan getOrDefault ["hqId", "HQ"], mapGridPosition (_plan get "hqPoz")];
    [_plan, "CEKILME", _neden] call _fazGec;
};

// v8.258 GUC ORANI (kullanici: "esit sayidaki dusmana sizmak tam bir intihar"; FM 3-90-1: saldirgan icin tipik planlama orani hazirlanmis savunmaya 3:1, hizli savunmaya ~2:1 - TASARIM esigi):
//   dost = plan gruplarinin yayadaki canli askeri + zirh destek (tank x6, IFV x2); dusman = plan liderlerinin objektif <= 500 m'de BILDIGI gercek dusman (piyade 1, tank 6, IFV / zirhli 2, statik silah 2) ve Zeus tahmini 'sayi'nin buyugu.
//   Donus: [dost, dusman, oran, hazirlanmisMi] (dusman 0 / bilinmiyorsa oran 99).
private _gucOrani = {
    params ["_plan", "_gruplar"];
    private _ob = _plan get "obj";
    private _tf = _plan get "taraf";
    private _dost = 0;
    { _dost = _dost + ({alive _x && {isNull objectParent _x}} count (units _x)); } forEach _gruplar;
    {
        private _zl = leader _x;
        private _zv = if (isNull _zl) then {objNull} else {vehicle _zl};
        if (!isNull _zv && {_zv isNotEqualTo _zl} && {alive _zv}) then {
            private _sn = [_zv] call FUNC(aracSinif);
            _dost = _dost + ([0, 6] select ((_sn select 0) isEqualTo "TANK")) + ([0, 2] select ((_sn select 0) isEqualTo "IFV"));
        };
    } forEach (_plan getOrDefault ["zirhG", []]);
    private _bil = [];
    {
        private _gl = leader _x;
        if (!isNull _gl && {alive _gl}) then {
            {
                private _eo = _x select 4;
                if (!isNull _eo && {alive _eo} && {(_tf getFriend (_x select 2)) < 0.6} && {[_eo] call FUNC(gercekHedef)} && {(_gl knowsAbout _eo) >= 0.3} && {((getPosATL _eo) distance2D _ob) <= 500}) then { _bil pushBackUnique _eo; };
            } forEach (_gl nearTargets 900);
        };
    } forEach (_gruplar + (_plan getOrDefault ["reconG", []]));
    private _dus = 0;
    {
        if (_x isKindOf "CAManBase") then { _dus = _dus + 1; } else {
            private _sn2 = [_x] call FUNC(aracSinif);
            _dus = _dus + (if (_x isKindOf "Tank" && {(getNumber (configOf _x >> "armor")) >= 300}) then {6} else { if (_x isKindOf "StaticWeapon") then {2} else { if ((_sn2 select 0) in ["IFV", "TANK"] || {_sn2 select 3}) then {2} else {0} } });
        };
    } forEach _bil;
    // v8.261 HIBRIT TAHMIN (kullanici: 'hibrit olsun, OPORD bilgisi de sallamasyon degil'): Zeus OPORD'undaki iddia (sayi + guven) ile GERCEK gozlem birlestirilir.
    //   gozlenen G (bilinen gercek dusman, agirlikli) HER ZAMAN sayilir; iddia C'nin gozlenmeyen kismi (C - G) yalniz agirlik w ile eklenir: w = gozlem yok ise [0.5 / 0.75 / 1.0] (guven yetersiz / orta / kesin),
    //   tam recon gozlemi (kalite q = 1) varsa [0.2 / 0.35 / 0.5] (recon gormedigi dusmanin cogu gercekte yok demektir); araya q ile enterpole edilir. Agirliklar TASARIM degeri (kitapta sayi yok).
    private _gozO = _dus;
    private _iddiaC = _plan getOrDefault ["iddiaSayi", 0];
    private _gv = (_plan getOrDefault ["guven", 1]) max 0 min 2;
    private _kal = (_plan getOrDefault ["gozKalite", 0]) max 0 min 1;
    private _wYok = [0.5, 0.75, 1] select _gv;
    private _wTam = [0.2, 0.35, 0.5] select _gv;
    private _wH = _wYok + (_wTam - _wYok) * _kal;
    _dus = _gozO + ((_iddiaC - _gozO) max 0) * _wH;
    private _hazir = (_plan getOrDefault ["bina", false]) || {((["LISTE"] call FUNC(hendekAlani)) findIf {((_x select 0) distance2D _ob) <= 400}) >= 0};
    [_dost, _dus, [(_dost / _dus), 99] select (_dus <= 0), _hazir, _gozO, _iddiaC, _kal, _wH]
};

// v8.261 ORAN KONTROLU (erken: recon raporu gelince TOPLAN'da; gec: KESIF sonunda): "GEC" / "BEKLE" / "IPTAL". Ayni sonuc 15 sn onbellekte. BEKLE'de oranTut = true: tanklar ilerlemez (planZirh), nakil araclari piyadeyi almadan / goturmeden bekler (SENKRON kapisi).
private _oranKontrol = {
    params ["_plan", "_gruplar", "_etiket"];
    private _id = _plan get "id";
    private _oranE = _plan getOrDefault ["oranEsik", 2];
    if (_oranE <= 0 || {missionNamespace getVariable ["lambs_danger_oranKapisiOff", false]}) exitWith { _plan set ["oranTut", false]; "GEC" };
    if ((time - (_plan getOrDefault ["oranT", -99])) < 15) exitWith { _plan getOrDefault ["oranKarar", "GEC"] };
    _plan set ["oranT", time];
    private _go = [_plan, _gruplar] call _gucOrani;
    _go params ["_gD", "_gE", "_gR", "_gH", "_gO", "_gC", "_gK", "_gW"];
    private _gEs = _oranE * ([1, 1.5] select _gH);
    _plan set ["oranSon", [_gD, _gE, _gR, _gEs]];
    private _karar = "GEC";
    if (_gE > 0 && {_gR < _gEs}) then {
        if ((_plan getOrDefault ["oranBekleT0", -1]) < 0) then { _plan set ["oranBekleT0", time]; };
        private _bek = time - (_plan get "oranBekleT0");
        _plan set ["oranTut", true];
        _karar = "BEKLE";
        if ((time - (_plan getOrDefault ["oranLogT", -99])) >= 30) then {
            _plan set ["oranLogT", time];
            diag_log format ["[PLAN-ORAN] %1 | %2 | dost %3 : dusman TAHMIN %4 (gozlenen %5 + OPORD iddia %6 x agirlik %7 | guven %8 | gozlem kalitesi %9) = %10 < esik %11 (hazirlanmis savunma %12) -> BEKLE (%13 sn / 300): tanklar ve nakil tutuldu", _id, _etiket, _gD, _gE toFixed 1, _gO toFixed 1, _gC, _gW toFixed 2, ["YETERSIZ", "ORTA", "KESIN"] select ((_plan getOrDefault ["guven", 1]) max 0 min 2), _gK toFixed 2, _gR toFixed 2, _gEs toFixed 2, _gH, round _bek];
        };
        if (_bek > 300) then {
            _plan set ["oranTut", false];
            _karar = "IPTAL";
            [_plan, format ["kuvvet orani yetersiz (dost %1 : dusman tahmin %2 = %3 < %4): saldiri iptal", _gD, _gE toFixed 1, _gR toFixed 2, _gEs toFixed 2]] call _kayipCekil;
        };
    } else {
        if ((_plan getOrDefault ["oranTut", false]) || {(_plan getOrDefault ["oranBekleT0", -1]) >= 0} || {(time - (_plan getOrDefault ["oranGecLogT", -99])) > 600}) then {
            _plan set ["oranGecLogT", time];
            diag_log format ["[PLAN-ORAN] %1 | %2 | dost %3 : dusman TAHMIN %4 (gozlenen %5 + OPORD iddia %6 x agirlik %7 | gozlem kalitesi %8) = %9 (esik %10) -> SALDIRI IZINLI", _id, _etiket, _gD, _gE toFixed 1, _gO toFixed 1, _gC, _gW toFixed 2, _gK toFixed 2, _gR toFixed 2, _gEs toFixed 2];
        };
        if (_plan getOrDefault ["oranTut", false]) then {
            _plan set ["oranTut", false];
            _plan set ["oranBekleT0", -1];
            private _ctlO = _plan getOrDefault ["tasimaCtl", []];
            if (count _ctlO > 1) then { _ctlO set [1, true]; };
            _plan set ["hazirBekle", false];
        };
    };
    _plan set ["oranKarar", _karar];
    _karar
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
        // v8.255 TANI: kayip degerlendirmesi (30 sn'de bir) - geri cekilme esigine (%50) ne kadar kaldigi; 'neden tetiklenmedi / neden tetiklendi' sorusu
        if ((time - (_plan getOrDefault ["kayipLogT", -99])) >= 30 && {!(_faz in ["KUR", "BITTI", "IPTAL"])} && {!(missionNamespace getVariable ["lambs_danger_taniOff", false])}) then {
            _plan set ["kayipLogT", time];
            private _ilkL = _plan getOrDefault ["ilkSayi", createHashMap];
            if ((count _ilkL) > 0) then {
                private _ilkLT = 0; private _simLT = 0; private _ayrL = [];
                { private _ik = _ilkL getOrDefault [groupId _x, 0]; private _sk = {alive _x} count (units _x); _ilkLT = _ilkLT + _ik; _simLT = _simLT + _sk; _ayrL pushBack format ["%1=%2/%3", groupId _x, _sk, _ik]; } forEach _gruplar;
                if (_ilkLT > 0) then {
                    diag_log format ["[KAYIP-DEGERLENDIRME] %1 | taraf=%2 | tip=%3 | faz=%4 | kayip_yuzde=%5 | kalan=%6/%7 | esik_yuzde=50 | esige_kalan_asker=%8 | bilinen_dusman=%9 | hq=%10 | gruplar=%11",
                        _id, _plan get "taraf", _tip, _faz, round ((1 - (_simLT / _ilkLT)) * 100), _simLT, _ilkLT, (_simLT - (ceil (_ilkLT * 0.5))) max 0, _plan getOrDefault ["savDus", "-"], _plan getOrDefault ["hqId", "-"], _ayrL];
                };
            };
        };

        // v8.187 SENKRON KALKIS KAPISI: hazir bayragi (tasimaCtl[1]) gozlem tamam VE tanklar mevzilerine yaklasmis (< 450 m) / 420 sn dolmus iken acilir
        if (_plan getOrDefault ["hazirBekle", false] && {_faz in ["TOPLAN", "RECON", "TASIMA", "KUR"]}) then {
            private _reconOk = ((_plan getOrDefault ["reconG", []]) isEqualTo []) || {_plan getOrDefault ["reconTamam", false]} || {(_plan getOrDefault ["dogrulama", 0]) isEqualTo 2};
            private _tankOk = ((_plan getOrDefault ["zirhG", []]) findIf {
                private _zg = _x;
                private _zv = vehicle (leader _zg);
                private _zp = _zg getVariable ["lambs_danger_planZirhPoz", []];
                !isNull _zg && {_zv isNotEqualTo (leader _zg)} && {(_zp isEqualTo []) || {(_zv distance2D _zp) > 450}} && {!(_zg getVariable ["lambs_danger_planZirhVardi", false])}
                && {!(_zg getVariable ["lambs_danger_planZirhPiyadeTut", false])}   // v8.265: piyade baginda bekleyen tank kapiyi tutmaz (karsilikli bekleme kilidi onlenir)
            }) < 0;
            // v8.200: recon araci tasimayi bitirdi / basarisiz oldu ve recon yaya yola ciktiktan 120 sn sonra ana kol beklemez (RPT 59babdf1: recon Stryker takildi, herkes 420 sn'lik tavani bekledi, "kimse hareket etmedi"); ATP 4-01.45: kesif unsuru ana kolun onunde ayrik gider, ana kol bekletilmez
            private _reconYaya = ("reconFazT" in _plan) && {(time - (_plan get "reconFazT")) > 120};
            // v8.221 RECON YAYA (RPT 0ea7ba5a: recon araci yok -> recon 2 km yuruyerek gidiyor, nakil araclari 96 sn+ piyadeyi ALMADAN bekledi, "apcler tasimadi"): recon APC'siz ise RECON fazi basladiktan 90 sn sonra ana kol beklemez (ATP 4-01.45 kesif ayrik gider)
            private _reconYayaAracsiz = isNull (_plan getOrDefault ["reconArac", objNull]) && {_faz isEqualTo "RECON"} && {_fazSure > 90};
            // v8.226 KESIF ONDE (ATP 4-01.45 / FM 3-98: kesif unsuru ana kolun onunde gider): recon APC OP'ye giden yolun %60'ini gectiyse ana kol kalkar (%60 tasarim degeri)
            private _raG = _plan getOrDefault ["reconArac", objNull];
            private _reconOnde = !isNull _raG && {alive _raG} && {(_plan getOrDefault ["reconAracD0", 0]) > 0} && {(_raG distance2D (_plan get "op")) < 0.4 * (_plan get "reconAracD0")};
            if (!(_plan getOrDefault ["oranTut", false]) && {(_reconOk && _tankOk) || {_reconOnde && {_tankOk}} || {_reconYaya && {_tankOk}} || {_reconYayaAracsiz && {_tankOk}} || {(time - (_plan getOrDefault ["t0", time])) > 420}}) then {
                _plan set ["hazirBekle", false];
                (_plan getOrDefault ["tasimaCtl", [false, true]]) set [1, true];
                diag_log format ["[PLAN] %1 SENKRON: nakil serbest birakildi (gozlem %2, tanklar %3, %4 sn)", _id, _reconOk, _tankOk, round (time - (_plan getOrDefault ["t0", time]))];
                private _kapiNeden = if (_reconOk && _tankOk) then {"recon gozlemi tamam + tanklar mevzide"} else { if (_reconOnde && _tankOk) then {"recon APC yolun %60'ini gecti"} else { if (_reconYaya && _tankOk) then {"recon APC indirdi + 120 sn"} else { if (_reconYayaAracsiz && _tankOk) then {"APCsiz recon: RECON fazi 90 sn"} else {"420 sn TAVAN"} } } };
                ["KAPI-ACILDI", format ["neden: %1 | recon tamam %2 | recon onde %3 | tank %4", _kapiNeden, _reconOk, _reconOnde, _tankOk]] call FUNC(planZaman);
            } else {
                if ((time - (_plan getOrDefault ["kapiLogT", 0])) > 20) then {
                    _plan set ["kapiLogT", time];
                    diag_log format ["[PLAN-KAPI] %1 | kapi KAPALI | recon tamam %2 | recon APC onde %3 (kalan %4 m / baslangic %5 m) | APC indirdi+120 sn %6 | APCsiz recon 90 sn %7 | tank mevzide %8 | faz %9 %10 sn", _id, _reconOk, _reconOnde, if (isNull _raG) then {-1} else {round (_raG distance2D (_plan get "op"))}, round (_plan getOrDefault ["reconAracD0", 0]), _reconYaya, _reconYayaAracsiz, _tankOk, _faz, round _fazSure];
                };
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
        // v8.214 KARSI-BATARYA: bilinen dusman topcu / havan araci icin 40 sn'de bir (yalniz topcu destegi acik planlarda, ates fazlarinda)
        if ((_plan getOrDefault ["topcu", 0]) > 0 && {_faz in ["ORP", "KESIF", "SALDIRI", "BEKLE"]} && {(time - (_plan getOrDefault ["karsiBatT", 0])) > 40}) then {
            _plan set ["karsiBatT", time];
            [_plan get "taraf", _obj, "KARSI", _id] call FUNC(topcuDestek);
        };
        private _sureSn = _plan getOrDefault ["sureSn", 0];
        // SURE SINIRI: ele gecirde hedef alinmadiysa CEKILME; savunmada plan biter
        // v8.249: SAVUNMADA (tip 1) sure siniri TEMASSIZ sure olarak BEKLE fazinda islenir (asagida); toplam sure yalniz ele gecirde
        if (_sureSn > 0 && {_tip isEqualTo 0} && {(time - (_plan get "t0")) > _sureSn} && {!(_faz in ["KUR", "CEKILME", "TOPLANMA", "DONUS", "BITTI", "IPTAL"])}) then {
            if (_tip isEqualTo 0) then {
                [_plan, "CEKILME", format ["SURE SINIRI (%1 sn) doldu, objektif alinamadi", _sureSn]] call _fazGec;
                { [_x] call _wpTemizle; [_x, _obj] call FUNC(tacticsRetreat); } forEach _gruplar;
            } else {
                [_plan, "BITTI", format ["SURE SINIRI (%1 sn) doldu", _sureSn]] call _fazGec;
            };
            continue
        };
        // v8.254: ele gecirde ORP / KESIF'te de (pusu / topcu / temas) toplam kayip >= %50 -> HQ'ya donus (SALDIRI icin FRAGO ayni helper'i kullanir)
        if (_tip isEqualTo 0 && {_faz in ["ORP", "KESIF"]} && {!(missionNamespace getVariable ["lambs_danger_kayipDonusOff", false])} && {(time - (_plan getOrDefault ["kayipDonT", -99])) > 10}) then {
            _plan set ["kayipDonT", time];
            private _ilkK = _plan getOrDefault ["ilkSayi", createHashMap];
            private _ilkKT = 0; private _simKT = 0;
            { _ilkKT = _ilkKT + (_ilkK getOrDefault [groupId _x, 0]); _simKT = _simKT + ({alive _x} count (units _x)); } forEach _gruplar;
            if (_ilkKT >= 8 && {(1 - (_simKT / _ilkKT)) >= 0.5}) then {
                [_plan, format ["%1 fazinda kayip yuzde %2 (esik 50): HQ'ya donus", _faz, round ((1 - (_simKT / _ilkKT)) * 100)]] call _kayipCekil;
                continue
            };
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
            { [_x] call _wpTemizle; _x setVariable ["lambs_danger_planAktif", nil, true]; _x setVariable ["lambs_danger_planId", nil]; if (_x getVariable [QGVAR(hendekte), false]) then { { if (alive _x && {isNull objectParent _x}) then { _x setUnitPos "AUTO"; _x doFollow (leader (group _x)); }; } forEach (units _x); }; _x setVariable [QGVAR(hendekte), nil]; _x setVariable [QGVAR(mevziIlk), nil]; _x setVariable [QGVAR(hendekEk), nil]; } forEach (_plan get "gruplar");   // v8.243: hendekte bayragi plan sonunda silinir (agacGizlen / mevzi tutma sonsuza kadar kilitli kalmasin)
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
            // v8.214 ZINCIR: objektif alindiysa siradaki hedefe gec (hayatta kalan gruplar elle secim olarak devredilir; yeni plan TOPLAN-ORP-KESIF-SALDIRI akisini bastan yurutur)
            private _zincirK = _plan getOrDefault ["zincir", []];
            if (_zincirK isNotEqualTo [] && {_sonuc isEqualTo "OBJEKTIF ALINDI"}) then {
                private _sirada = _zincirK select 0;
                private _yeniAyar = +(_sirada select 1);
                _yeniAyar set ["zincir", false];
                _yeniAyar set ["secili", ((_plan get "gruplar") select {({alive _x} count (units _x)) >= 2}) apply {netId _x}];
                private _kalan = +(_zincirK select [1, 99]);
                diag_log format ["[PLAN-ZINCIR] %1 | objektif alindi -> siradaki hedef %2 (%3 grup devredildi, kalan zincir %4)", _id, mapGridPosition (_sirada select 0), count (_yeniAyar get "secili"), count _kalan];
                [_plan get "taraf", _sirada select 0, _yeniAyar, _kalan] spawn {
                    params ["_zt", "_zo", "_za", "_zk"];
                    sleep 4;
                    private _ok = [_zt, _zo, _za] call FUNC(komutanPlan);
                    if (_ok isEqualTo true && {_zk isNotEqualTo []}) then {
                        // kalan zincir yeni planin sirasina tasinir
                        private _yp = (values lambs_danger_planlar) select {(_x get "taraf") isEqualTo _zt && {((_x get "obj") distance2D _zo) < 5} && {!((_x getOrDefault ["faz", ""]) in ["BITTI", "IPTAL"])}};
                        if (_yp isNotEqualTo []) then { (_yp select 0) set ["zincir", _zk]; };
                    };
                };
            };
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
            // v8.205: SAVUNMA planinda gruplar zaten objektifte (Zeus'un koydugu yerde); RP'ye toplanmak onlari yerinden ederdi (kullanici: "objektifte kendisi waypoint atiyor, degisik") -> RP waypoint'i yazilmaz, TOPLAN atlanir
            if (_tip isNotEqualTo 1 || {!(missionNamespace getVariable ["lambs_danger_savunmaRpAtla", true])}) then { { [_x, [[_rp, "MOVE", "RP (toplan)", "AWARE", "NORMAL", 50]]] call _wpYaz; } forEach _gruplar; };
            // v8.132: nakil araclari plan baslayinca RP'ye yola cikar (piyade toplanirken); bindirme TOPLAN hazir olunca
            if (_tip isNotEqualTo 1 && {!(missionNamespace getVariable ["lambs_danger_tasimaOff", false])}) then {
                // v8.187 SENKRON KALKIS: kesif unsuru (RECON) ya da zirh destek (tank) varsa nakil araclari piyadeyi alip BEKLER (hazir = false); gozlem bitince ve tanklar mevzilerine yaklasinca (komuta dongusu) serbest birakilir
                // v8.188: recon unsuru icin tek bir arac ayrilir (ana nakilden once secilir; aracTasima isaretli araci almaz)
                if ((_plan getOrDefault ["reconG", []]) isNotEqualTo [] && {(_plan getOrDefault ["dogrulama", 0]) isNotEqualTo 2} && {!(_plan getOrDefault ["reconAracDene", false])}) then {
                    _plan set ["reconAracDene", true];
                    private _ra = ["SEC", _plan] call FUNC(reconArac);
                    if (!isNull _ra) then { _plan set ["reconArac", _ra]; };
                };
                // v8.225: kapi KALKISI tutar (yuklen-ve-bekle, en fazla 60 sn); binme beklemez (aracTasima)
                private _bekleKos = (((_plan getOrDefault ["reconG", []]) isNotEqualTo [] && {(_plan getOrDefault ["dogrulama", 0]) isNotEqualTo 2}) || {(_plan getOrDefault ["zirhG", []]) isNotEqualTo []});
                _plan set ["tasimaCtl", [false, !_bekleKos, 0, 0, 0, [], true]];
                _plan set ["hazirBekle", _bekleKos];
                if (_bekleKos) then { diag_log format ["[PLAN] %1 SENKRON: nakil araclari piyadeyi alip bekleyecek (gozlem: %2 | tank / zirh: %3) - serbest birakma kosullari: gozlem tamam + tanklar mevzisine yakin (en cok 420 sn)", _id, (_plan getOrDefault ["reconG", []]) isNotEqualTo [], (_plan getOrDefault ["zirhG", []]) isNotEqualTo []]; };
                _plan set ["tasimaH", [_plan get "taraf", _gruplar, _rp, _obj, _B, (_plan get "ayar") getOrDefault ["orpM", 300], 6000, _plan get "tasimaCtl"] spawn FUNC(aracTasima)];
            };
            [_plan, "TOPLAN", format ["RP %1", mapGridPosition _rp]] call _fazGec;
            continue
        };
        // ---------------------------------------------------------------- v8.248 ARKA TEMAS DESTEGI (kullanici RPT e88d7e9f: ORP gerisinde pusuya dusen BTR ekibine destege giden gruplar, plan ORP fazinda 'temastaki degil' diye 25 sn'de ORP'ye geri yonlendirildi;
        //   kullanici: 'ormanlik oldugu icin tam temiz oldugunu dogrulayamamis olabilirler'). Doktrin: TC 3-21.76 13-7 / 13-8 (temasta olmayan unsurlar yer degistirip destek ates eder; tehdit eliminated denince kurtarma / CASEVAC),
        //   MCWP 3-11.1 (quick reaction force); sayilar TASARIM. Kural: ELE GECIR planinda TOPLAN / ORP / KESIF fazinda bir plan grubu ORP'den > 350 m GERIDE >= 6 sn temastaysa, temasta olmayan en fazla 2 grup (once YEDEK, sonra MANEVRA;
        //   <= 1200 m, >= 3 asker) destege gider: 1) bilinen dusman agirligina saldiri (yoksa temasli gruba hareket), 2) temasli grupla BULUSMA (80 m) + 'sup' (ormanlikta daha uzun); 3) GOREVDEN ALMA: temasli grup >= 45 sn temassiz (ormanlik: 90 sn)
        //   VE destek grubu onunla bulustu (<= 80 m) ya da 300 sn dolmus. Sadece 'temas bitti' ile gorevden alinmaz (orman: dogrulanamayan 'temiz'). Kapatma: lambs_danger_arkaDestekOff = true.
        if (_tip isEqualTo 0 && {_faz in ["TOPLAN", "ORP", "KESIF"]} && {!(missionNamespace getVariable ["lambs_danger_arkaDestekOff", false])} && {(time - (_plan getOrDefault ["arkaDT", -99])) > 6}) then {
            _plan set ["arkaDT", time];
            private _am = _plan getOrDefault ["arkaDestek", createHashMap];
            _plan set ["arkaDestek", _am];
            private _ambGrup = {
                params ["_gid"];
                private _r = grpNull;
                { if ((groupId _x) isEqualTo _gid) exitWith { _r = _x; }; } forEach _gruplar;
                _r
            };
            // 1) gorevden alma / asama gecisi
            private _arkaBit = [];
            {
                private _hid = _x;
                private _hv = _am get _hid;   // [t0, ambushedId, ep, asama, asamaT, ormanlik]
                private _hg = [_hid] call _ambGrup;
                private _ag = [_hv select 1] call _ambGrup;
                if (isNull _hg || {isNull _ag}) then { _arkaBit pushBack [_hid, "grup yok / olu"]; } else {
                    private _ap = getPosATL (leader _ag);
                    private _hm = (leader _hg) distance2D _ap;
                    private _agTemas = [_ag] call _temasta;
                    if (_agTemas) then { _ag setVariable ["lambs_danger_arkaTemasSonT", time]; };
                    private _sessizS = time - (_ag getVariable ["lambs_danger_arkaTemasSonT", _hv select 0]);
                    if ((_hv select 3) isEqualTo 1 && {_hm < 80 || {(time - (_hv select 4)) > 120} || {((leader _hg) distance2D (_hv select 2)) < 60}}) then {
                        // asama 2: temasli gruba BULUSMA
                        _hv set [3, 2]; _hv set [4, time];
                        [_hg, [[_ap, "MOVE", "ARKA DESTEK (bulusma)", "AWARE", "NORMAL", 40]]] call _wpYaz;
                        _hg setVariable ["lambs_danger_isExecutingTactic", nil];
                        _hg setVariable [QGVAR(isBounding), nil];
                    };
                    private _gerekliSessiz = [45, 90] select (_hv select 5);
                    if ((_hv select 3) isEqualTo 2 && {_sessizS >= _gerekliSessiz} && {_hm <= 80}) then { _arkaBit pushBack [_hid, format ["bulustu (%1 m), %2 sn temassiz%3", round _hm, round _sessizS, ["", " (ORMANLIK: uzun dogrulama)"] select (_hv select 5)]]; }
                    else { if ((time - (_hv select 0)) > 300) then { _arkaBit pushBack [_hid, "300 sn doldu"]; }; };
                };
            } forEach (keys _am);
            {
                _x params ["_hid", "_neden"];
                private _hg = [_hid] call _ambGrup;
                if (!isNull _hg) then {
                    [_hg] call _wpTemizle;
                    _hg setVariable ["lambs_danger_isExecutingTactic", nil];
                    _hg setVariable [QGVAR(isBounding), nil];
                    _hg setVariable ["lambs_danger_planYenileT", -999];
                };
                _am deleteAt _hid;
                diag_log format ["[PLAN-ARKA-DESTEK] %1 | %2 destekten ALINDI (%3) -> ORP yoluna doner", _id, _hid, _neden];
            } forEach _arkaBit;
            // 2) yeni destek (en fazla 2 destek grubu; yeni istek 30 sn'de bir)
            if ((count _am) < 2 && {(time - (_plan getOrDefault ["arkaYeniT", -99])) > 30}) then {
                private _amIds = (keys _am) apply { (_am get _x) select 1 };
                private _gerideTemas = _gruplar select {
                    ([_x] call _temasta) && {isNull objectParent (leader _x)} && {(leader _x) distance2D _orp > 350} && {!((groupId _x) in _amIds)}
                };
                // temas baslangic zamani (>= 6 sn kosulu): temaslilarda ilk gorulme zamani, temassizlarda sifirlanir
                { if ((_x getVariable ["lambs_danger_arkaTemasBasT", -1]) < 0) then { _x setVariable ["lambs_danger_arkaTemasBasT", time]; }; } forEach _gerideTemas;
                { _x setVariable ["lambs_danger_arkaTemasBasT", -1]; } forEach (_gruplar - _gerideTemas);
                private _hedefAm = _gerideTemas select {(time - (_x getVariable ["lambs_danger_arkaTemasBasT", time])) >= 6};
                if (_hedefAm isNotEqualTo []) then {
                    private _ag = _hedefAm select 0;
                    private _apos = getPosATL (leader _ag);
                    private _yard = _gruplar select {
                        _x isNotEqualTo _ag && {!([_x] call _temasta)} && {isNull objectParent (leader _x)} && {({alive _x} count (units _x)) >= 3}
                        && {(_roller getOrDefault [groupId _x, "MANEVRA"]) in ["YEDEK", "MANEVRA"]} && {!((groupId _x) in (keys _am))}
                        && {(leader _x) distance2D _apos <= 1200}
                    };
                    _yard = [_yard, [], { ([0, 100000] select ((_roller getOrDefault [groupId _x, ""]) isEqualTo "YEDEK")) - ((leader _x) distance2D _apos) }, "DESCEND"] call BIS_fnc_sortBy;
                    _yard = _yard select [0, (2 - (count _am)) max 0];
                    if (_yard isNotEqualTo []) then {
                        _plan set ["arkaYeniT", time];
                        // bilinen dusman agirlik merkezi (yalniz gercek dusman)
                        private _ep = [];
                        private _bil = ((leader _ag) nearTargets 600) select {((_plan get "taraf") getFriend (_x select 2)) < 0.6 && {((leader _ag) knowsAbout (_x select 4)) > 0.3} && {[_x select 4] call FUNC(gercekHedef)}};
                        if (_bil isNotEqualTo []) then {
                            private _bx = 0; private _by = 0;
                            { _bx = _bx + ((_x select 0) select 0); _by = _by + ((_x select 0) select 1); } forEach _bil;
                            _ep = [_bx / (count _bil), _by / (count _bil), 0];
                        };
                        // ormanlik: ambushed grubun 50 m'sinde >= 15 agac (gorus kisitli: 'temiz' dogrulamasi uzun surer)
                        private _orman = (count (nearestTerrainObjects [_apos, ["TREE", "BUSH"], 50])) >= 15;
                        {
                            private _hg = _x;
                            private _hedefP = if (_ep isEqualTo []) then {_apos} else {_ep};
                            _am set [groupId _hg, [time, groupId _ag, _hedefP, 1, time, _orman]];
                            _hg setVariable ["lambs_danger_planYenileT", time + 3600];
                            [_hg, [[_hedefP, "MOVE", "ARKA DESTEK", "AWARE", "NORMAL", 40]]] call _wpYaz;
                            if (_ep isNotEqualTo []) then { [_hg, "SALDIRI", [_ep]] call FUNC(hqEmir); };
                            diag_log format ["[PLAN-ARKA-DESTEK] %1 | %2 temasta (ORP'den %3 m geride, %4) -> %5 (%6) DESTEGE gidiyor | dusman %7 | hedef %8 m | %9", _id, groupId _ag, round ((leader _ag) distance2D _orp), mapGridPosition _apos, groupId _hg, _roller getOrDefault [groupId _hg, "?"],
                                if (_ep isEqualTo []) then {"bilinmiyor (temasli gruba hareket)"} else {format ["%1 bilinen", count _bil]}, round ((leader _hg) distance2D _hedefP), ["acik arazi", "ORMANLIK: 'temiz' icin 90 sn + bulusma sarti"] select _orman];
                        } forEach _yard;
                    };
                };
            };
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
            if (_reconOnce || {_tip isEqualTo 1 && {missionNamespace getVariable ["lambs_danger_savunmaRpAtla", true]}} || {_hazir >= (ceil ((count _gruplar) * 0.75))} || {_fazSure > 300} || {_plan getOrDefault ["tasimaTamam", false]} || {_plan getOrDefault ["reconTamam", false]} || {("tasimaH" in _plan) && {scriptDone (_plan get "tasimaH")} && {_fazSure > 20} && {((_plan getOrDefault ["tasimaCtl", [false, true, 0]]) param [2, 0]) > 0}}) then {
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
                        _plan set ["reconAracD0", (_plan getOrDefault ["reconArac", objNull]) distance2D _opN];
                        _plan set ["reconAracH", ["CALIS", _plan, _rgl, _opN] spawn FUNC(reconArac)];
                    };
                    diag_log format ["[PLAN-RECON] %1 | recon OP'ye gidiyor (STEALTH + GREEN: ates gelene kadar ates yok) | %2 grup | OP %3", _id, count _rgl, mapGridPosition _opN];
                    [_plan, "RECON", format ["%1 grup gozlem noktasina", count _rgl]] call _fazGec;
                    continue
                };
                // v8.261 ERKEN ORAN KAPISI (kullanici: 'dusman fazla, saldiri ertelendi ama tanklar gitti, bazi askerler yayan gidiyordu'): recon raporu gelir gelmez HIBRIT kuvvet orani olculur (gozlenen + OPORD iddiasi, bkz. _gucOrani);
                //   yetersizse piyade RP'de, nakil araclari beklemede, tanklar yerinde (planZirh) kalir; 300 sn'de duzelmezse saldiri IPTAL + HQ'ya donus.
                if (_tip isNotEqualTo 1 && {_plan getOrDefault ["reconTamam", false]} && {!(_plan getOrDefault ["oranErkenGecti", false])}) then {
                    private _ek = [_plan, _gruplar, "ERKEN (recon raporu)"] call _oranKontrol;
                    if (_ek isEqualTo "GEC") then {
                        _plan set ["oranErkenGecti", true];
                    } else {
                        if (_ek isEqualTo "BEKLE") then {
                            if !(_plan getOrDefault ["hazirBekle", false]) then {
                                _plan set ["hazirBekle", true];
                                private _ctlE = _plan getOrDefault ["tasimaCtl", []];
                                if (count _ctlE > 1) then { _ctlE set [1, false]; };
                            };
                        };
                        continue
                    };
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
                    private _hendekL = ["LISTE"] call FUNC(hendekAlani);
                    private _hendekKul = createHashMap;
                    // v8.252 MEVZI ARAMA YARICAPI (kullanici: 'savun objektifi yakindaki tum mevzilere etki etmeli, mesafeyi slider ile ayarlayabilelim'): Zeus Objektif 'Mevzi arama yaricapi' (plan mevziYar; 0 = eski: hendek 300 m)
                    //   hendek alanlari + elle mevzi noktalari + karakol / mevzi / gozetleme kayitlari (komutanPlan) bu yaricap icinde kullanilir.
                    private _hR = (_plan getOrDefault ["mevziYar", 0]);
                    if (_hR <= 0) then { _hR = 300; };
                    private _hendekVar = (_hendekL findIf {((_x select 0) distance2D _obj) <= _hR && {(_x select 5) in [sideUnknown, _plan get "taraf"]}}) >= 0;
                    private _priSay = createHashMap;
                    // v8.239 COKLU MEVZI: elle konan mevzi noktalari varsa gruplar halka sektoru yerine MEVZILERE dagitilir (once tehdit yonune en yakin mevzi; her mevziye en yakin grup; mevzi sayisi asilirsa turlar halinde ikinci / ucuncu grup yan yana)
                    private _mevziler = _plan getOrDefault ["mevziler", []];
                    private _mevziAta = createHashMap;
                    if (_mevziler isNotEqualTo []) then {
                        private _mKul = _mevziler apply {0};
                        private _mOnc = [_mevziler apply {_forEachIndex}, [], {
                            if (_th >= 0) then { abs ((((_obj getDir ((_mevziler select _x) select 0)) - _th + 540) mod 360) - 180) } else { _x }
                        }, "ASCEND"] call BIS_fnc_sortBy;
                        private _kalanG = +_sirali;
                        private _mTur = 0;
                        // v8.252: hendek alani da varsa her mevziye bir grup (tek tur); artan gruplar hendek alanlarina gider (eskiden ust uste mevziye yigiliyor, hendek alanlari bos kaliyordu)
                        while {_kalanG isNotEqualTo [] && {_mTur < 1 || {!_hendekVar}}} do {
                            _mTur = _mTur + 1;
                            {
                                if (_kalanG isEqualTo []) exitWith {};
                                private _mi = _x;
                                private _mp = (_mevziler select _mi) select 0;
                                private _en = _kalanG select 0;
                                private _enD = 1e9;
                                { private _dd = (leader _x) distance2D _mp; if (_dd < _enD) then { _enD = _dd; _en = _x; }; } forEach _kalanG;
                                _mevziAta set [groupId _en, [_mi, _mKul select _mi]];
                                _mKul set [_mi, (_mKul select _mi) + 1];
                                _kalanG deleteAt (_kalanG find _en);
                            } forEach _mOnc;
                        };
                    };
                    {
                        private _g = _x;
                        private _a = if (_th >= 0) then { _th + (if (_n <= 1) then {0} else {-110 + 220 * (_forEachIndex / (_n - 1))}) } else { _B + (360 / _n) * _forEachIndex };
                        private _poz = [_obj getPos [55, _a]] call _siperNokta;   // v8.181: sektor noktasi 40 m icinde siper yogunlugu en yuksek, kuru, cukur olmayan nokta
                        private _ma = _mevziAta getOrDefault [groupId _g, []];
                        private _mHdk = -1;
                        if (_ma isNotEqualTo []) then {
                            private _mv = _mevziler select (_ma select 0);
                            private _mp = _mv select 0;
                            _a = if ((_mv select 1) >= 0) then { _mv select 1 } else { _obj getDir _mp };   // yon verilmediyse objektiften DISARI
                            private _s = _ma select 1;
                            _poz = if (_s > 0) then { _mp getPos [18 * ceil (_s / 2), _a + 90 + 180 * (_s mod 2)] } else { +_mp };   // ayni mevzide 2. / 3. grup yan yana (18 m)
                            private _hn = ["EN-YAKIN", _poz, 40, side _g] call FUNC(hendekAlani);
                            if (_hn isNotEqualTo []) then { _mHdk = _hn select 1; _poz = _hn select 0; };
                            diag_log format ["[PLAN-MEVZI] %1 | %2 -> mevzi %3 (%4, sira %5, yon %6, hendek %7)", _id, groupId _g, (_ma select 0) + 1, mapGridPosition _mp, _s, round _a, _mHdk];
                        };
                        // v8.230 HENDEK TERCIHI: objektife <= 300 m olan hendek alanlari arasindan EN AZ kullanilan + sektor noktasina en yakin secilir (gruplar farkli hendeklere dagilir); formasyon aranmaz
                        private _hdkI = _mHdk;
                        private _enSk = 1e9;
                        if (_ma isNotEqualTo []) then { _enSk = -1; };
                        {
                            _x params ["_hc", "_ha", "_hb", "_hd", "_hadi", "_htr"];
                            if ((_htr isEqualTo sideUnknown || {_htr isEqualTo (_plan get "taraf")}) && {(_hc distance2D _obj) <= _hR}) then {
                                private _sk = (_hendekKul getOrDefault [_forEachIndex, 0]) * 1000 + (_hc distance2D _poz);
                                if (_sk < _enSk) then { _enSk = _sk; _hdkI = _forEachIndex; };
                            };
                        } forEach _hendekL;
                        if (_hdkI >= 0 && {_ma isEqualTo []}) then {
                            _poz = (_hendekL select _hdkI) select 0;
                            _hendekKul set [_hdkI, (_hendekKul getOrDefault [_hdkI, 0]) + 1];
                            diag_log format ["[PLAN] %1 SAVUN: %2 hendek alanina yerlesecek (alan %3, objektife %4 m, ayni alanda %5 grup)", _id, groupId _g, _hdkI, round (_poz distance2D _obj), _hendekKul get _hdkI];
                        };
                        // v8.252 KAPASITE: grup birincil hendege sigmiyorsa en yakin KULLANILMAYAN hendek alanlari (<= 250 m, en cok 3) ek alan olur; askerler orada kapasite kadar yerlesir
                        _g setVariable [QGVAR(hendekEk), []];
                        if (_hdkI >= 0 && {_ma isEqualTo []}) then {
                            private _nG = {alive _x} count (units _g);
                            private _kap = ["KAPASITE", _hdkI] call FUNC(hendekAlani);
                            private _ek = [];
                            if (_nG > _kap && {!(missionNamespace getVariable ["lambs_danger_hendekEkOff", false])}) then {
                                private _kalanS = _nG - _kap;
                                private _pC = (_hendekL select _hdkI) select 0;
                                private _adayA = [];
                                {
                                    _x params ["_hc2", "_ha2", "_hb2", "_hd2", "_hadi2", "_htr2"];
                                    if ((_htr2 isEqualTo sideUnknown || {_htr2 isEqualTo (_plan get "taraf")}) && {(_hc2 distance2D _obj) <= _hR} && {(_hc2 distance2D _pC) <= 250} && {_forEachIndex isNotEqualTo _hdkI} && {(_hendekKul getOrDefault [_forEachIndex, 0]) isEqualTo 0}) then {
                                        _adayA pushBack [_hc2 distance2D _pC, _forEachIndex];
                                    };
                                } forEach _hendekL;
                                _adayA sort true;
                                {
                                    if (_kalanS <= 0 || {(count _ek) >= 3}) exitWith {};
                                    private _ai = _x select 1;
                                    private _al = (["KAPASITE", _ai] call FUNC(hendekAlani)) min _kalanS;
                                    _ek pushBack [_ai, _al];
                                    _hendekKul set [_ai, 1];
                                    _kalanS = _kalanS - _al;
                                } forEach _adayA;
                                diag_log format ["[PLAN] %1 SAVUN: %2 %3 asker, alan %4 kapasitesi %5 -> ek alanlar %6%7", _id, groupId _g, _nG, _hdkI, _kap, _ek, if (_kalanS > 0) then {format [" (%1 asker icin yer yok: sikisik)", _kalanS]} else {""}];
                            };
                            _g setVariable [QGVAR(hendekEk), _ek];
                            private _ekT = 0;
                            { _ekT = _ekT + (_x select 1); } forEach _ek;
                            _priSay set [groupId _g, [_hdkI, (_nG - _ekT) max 1]];
                        };
                        (_plan get "notlar") set [groupId _g, [_poz, _a, _hdkI]];
                        [_g, [[_poz, "MOVE", format ["MEVZI sektor %1", round _a], "AWARE", "NORMAL", 30]]] call _wpYaz;
                    } forEach _sirali;
                    // v8.252 TUM MEVZILER: yaricap icinde hala bos hendek alani varsa, o alana yakin (<= 250 m) en kalabalik gruptan (birincilde >= 6 asker kalmis) 2+ kisilik ekip ayrilir (birincilde en az 3 kalir)
                    if !(missionNamespace getVariable ["lambs_danger_hendekEkOff", false]) then {
                        {
                            _x params ["_hc3", "_ha3", "_hb3", "_hd3", "_hadi3", "_htr3"];
                            private _bi = _forEachIndex;
                            if ((_htr3 isEqualTo sideUnknown || {_htr3 isEqualTo (_plan get "taraf")}) && {(_hc3 distance2D _obj) <= _hR} && {(_hendekKul getOrDefault [_bi, 0]) isEqualTo 0}) then {
                                private _enG = grpNull;
                                private _enK = 0;
                                {
                                    private _pg = _priSay getOrDefault [groupId _x, []];
                                    if (_pg isNotEqualTo [] && {(_pg select 1) >= 6} && {(((_hendekL select (_pg select 0)) select 0) distance2D _hc3) <= 250} && {(_pg select 1) > _enK}) then { _enK = _pg select 1; _enG = _x; };
                                } forEach _gruplar;
                                if (!isNull _enG) then {
                                    private _pg2 = _priSay get (groupId _enG);
                                    private _al3 = ((["KAPASITE", _bi] call FUNC(hendekAlani)) min ((floor ((_pg2 select 1) / 3)) max 2)) min ((_pg2 select 1) - 3);
                                    if (_al3 >= 2) then {
                                        private _ek3 = (_enG getVariable [QGVAR(hendekEk), []]) + [[_bi, _al3]];
                                        _enG setVariable [QGVAR(hendekEk), _ek3];
                                        _priSay set [groupId _enG, [_pg2 select 0, (_pg2 select 1) - _al3]];
                                        _hendekKul set [_bi, 1];
                                        diag_log format ["[PLAN] %1 SAVUN: bos hendek alani %2 (objektife %3 m) -> %4 grubundan %5 kisilik ekip", _id, _bi, round (_hc3 distance2D _obj), groupId _enG, _al3];
                                    };
                                };
                            };
                        } forEach _hendekL;
                    };
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
                    if (((leader _g) distance2D (_t select 0)) < 40 || {(time - (_plan getOrDefault ["reconOpT", time - _fazSureR])) > 240}) then {
                        if ((_t select 1) < 0) then {
                            _t set [1, time];
                            { if (alive _x && {isNull objectParent _x}) then { _x setUnitPos "DOWN"; }; } forEach (units _g);
                            (leader _g) doWatch (_t param [2, _obj]);
                            diag_log format ["[PLAN-RECON] %1 | %2 OP'ye vardi (%3 m), gozlem basladi", _id, groupId _g, round ((leader _g) distance2D _obj)];
                        };
                        _vardi = _vardi + 1;
                    };
                };
            } forEach _rg;
            if (_vardi >= (count _rg) && {!("reconVarT" in _plan)}) then { _plan set ["reconVarT", time]; };
            private _gozlemS = if (!("reconVarT" in _plan)) then {0} else {time - (_plan get "reconVarT")};
            private _gozlemHedef = [90, 45, 20] select ((_plan getOrDefault ["dogrulama", 0]) min 2);
            // v8.216 RECON EK GOZLEM: objektif OP gozlemi bitince siradaki DUSMAN noktasina gizlice gecilir (STEALTH + GREEN); her noktada bilinen dusman sayisi raporlanir
            private _ekL = _plan getOrDefault ["reconEkNoktalar", []];
            if (_rg isNotEqualTo [] && {!_bozuldu} && {_gozlemS >= _gozlemHedef} && {_fazSure < 1800} && {(_ekL isNotEqualTo []) || {"reconEkSimdi" in _plan}}) then {
                private _simdi = _plan getOrDefault ["reconEkSimdi", []];
                if (_simdi isNotEqualTo []) then {
                    private _sayi = 0;
                    private _tr2 = _plan get "taraf";
                    { private _u = _x; if (alive _u && {(_tr2 getFriend (side _u)) < 0.6} && {(_u distance2D (_simdi select 1)) < 250} && {(_rg findIf {_x knowsAbout _u > 0.3}) >= 0}) then { _sayi = _sayi + 1; }; } forEach (allUnits select {_x isKindOf "CAManBase"});
                    (_plan get "reconEkSonuc") pushBack format ["%1 %2: %3 dusman bilindi", _simdi select 2, mapGridPosition (_simdi select 1), _sayi];
                    diag_log format ["[PLAN-RECON-EK] %1 | gozlem sonucu: %2", _id, (_plan get "reconEkSonuc") select (((count (_plan get "reconEkSonuc")) - 1) max 0)];
                    _plan deleteAt "reconEkSimdi";
                };
                if (_ekL isNotEqualTo []) then {
                    private _sirada = _ekL deleteAt 0;
                    _plan set ["reconEkNoktalar", _ekL];
                    _plan set ["reconEkSimdi", _sirada];
                    _plan set ["reconOpT", time];
                    _plan deleteAt "reconVarT";
                    {
                        private _g = _x;
                        private _poz = (_sirada select 0) getPos [8 * _forEachIndex, random 360];
                        [_g, [[_poz, "MOVE", "RECON -> EK OP", "STEALTH", "LIMITED", 25]]] call _wpYaz;
                        _g setBehaviour "STEALTH"; _g setCombatMode "GREEN"; _g setSpeedMode "LIMITED";
                        { if (alive _x && {isNull objectParent _x}) then { _x setUnitPos "MIDDLE"; _x doMove _poz; }; } forEach (units _g);
                        _notlar set [format ["%1_op", groupId _g], [_poz, -1, _sirada select 1]];
                    } forEach _rg;
                    diag_log format ["[PLAN-RECON-EK] %1 | siradaki dusman noktasi: %2 %3 (gozlem noktasi %4, kalan %5)", _id, _sirada select 2, mapGridPosition (_sirada select 1), mapGridPosition (_sirada select 0), count _ekL];
                    continue
                };
            };
            if (_rg isEqualTo [] || {_bozuldu} || {_gozlemS >= _gozlemHedef} || {_fazSure > 2400} || {_fazSureR > 420 + 420 * (count (_plan getOrDefault ["reconEkSonuc", []]) + count _ekL + ([0, 1] select ("reconEkSimdi" in _plan)))}) then {
                // RAPOR (recon grubunun gozlemi): dusman + sivil sayisi, iddia farki, komutan inanci guncellenir
                private _rap = [_plan, [_rg, _gruplar] select (_rg isEqualTo []), _bozuldu, _gozlemS, "recon"] call _gozlemRapor;
                _plan set ["reconTamam", true];
                if ((_plan getOrDefault ["reconEkSonuc", []]) isNotEqualTo []) then {
                    diag_log format ["[PLAN-RECON-EK] %1 | OZET: %2", _id, _plan get "reconEkSonuc"];
                    private _cuE = (allCurators apply {getAssignedCuratorUnit _x}) select {!isNull _x};
                    if (_cuE isNotEqualTo []) then { [format ["ELITE PLAN %1 RECON ek gozlem: %2", _id, (_plan get "reconEkSonuc") joinString " | "]] remoteExec ["systemChat", _cuE]; };
                };
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
                    // v8.276 GUVENLI SEFER (FM 3-90 14-41: 'surekli gidis-donusle shuttle'; MCWP 3-11.1: inis noktalari dusman dogrudan / dolayli atesinde olabilir): aracin ORP'ye gidip gelmesi YALNIZ temas yokken
                    //   (plan gruplarinin hicbiri temasta degil) yapilir; temas varsa sefer ertelenir (kalanlar yuruyerek devam eder). Kapatma: lambs_danger_seferGuvenliOff = true.
                    private _seferTemas = !(missionNamespace getVariable ["lambs_danger_seferGuvenliOff", false]) && {(_gruplar findIf {(_x getVariable ["lambs_danger_contact", 0]) > time}) >= 0};
                    if (_seferTemas) then {
                        if ((time - (_plan getOrDefault ["seferUyariT", -999])) > 60) then {
                            _plan set ["seferUyariT", time];
                            diag_log format ["[PLAN] %1 TASIMA: SEFER ERTELENDI - plan gruplarindan biri temasta (arac ORP'ye gidip gelmez; geride %2 asker)", _id, _kalan];
                        };
                    } else {
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
                ((leader _x) distance2D _h) < 70 || {[_x] call _temasta} || {(groupId _x) in (keys (_plan getOrDefault ["arkaDestek", createHashMap]))}
            } count _gruplar;
            // temastaki grubu zorlamama; temas kesilince hedefe yeniden yonlendir
            {
                private _g = _x;
                private _h = _notlar getOrDefault [groupId _g, _orp];
                if (!([_g] call _temasta) && {((leader _g) distance2D _h) > 90} && {(time - (_g getVariable ["lambs_danger_planYenileT", -999])) > 25} && {!((groupId _g) in (keys (_plan getOrDefault ["arkaDestek", createHashMap])))}) then {
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
                // v8.258 GUC ORANI KAPISI (v8.261: HIBRIT tahmin + _oranKontrol; erken olcum TOPLAN'da recon raporunda): oran esigin altindaysa saldiri ERTELENIR (en cok 300 sn), sure dolunca IPTAL + HQ'ya donus.
                //   Esik Zeus 'Min. kuvvet orani' (varsayilan 2.0; 0 = kapi kapali), hazirlanmis savunmaya (bina / hendek alani <= 400 m) x1.5. Kapatma: lambs_danger_oranKapisiOff = true.
                if (([_plan, _gruplar, "KESIF"] call _oranKontrol) in ["BEKLE", "IPTAL"]) then { continue };
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
                // v8.214 DUMAN PERDESI: hedefin 60 m onune (yaklasma yonunde) duman mermisi (dusman gozetlemesini kor eder)
                if ((_plan getOrDefault ["topcu", 0]) in [2, 3] && {_maneuv isNotEqualTo []}) then {
                    [_plan get "taraf", _obj getPos [60, _obj getDir (leader (_maneuv select 0))], "SIS", _id] call FUNC(topcuDestek);
                };
                { _x setVariable ["lambs_danger_gizliPos", ""]; { if (alive _x && {isNull objectParent _x}) then { _x setUnitPos "AUTO"; }; } forEach (units _x); _x setCombatMode "YELLOW"; } forEach _gruplar;
                [_plan, "SALDIRI", format ["manevra %1 grup, destek ates baslar", count _maneuv]] call _fazGec;
            };
            continue
        };

        // ---------------------------------------------------------------- SALDIRI
        if (_faz isEqualTo "SALDIRI") then {
            // v8.204 FRAGO - SALDIRI BASARISIZ (FM 3-98 3-56: geri cekilme olcutu onceden verilir, dusman / kayip tabanli; sayilar TASARIM): saldiri gruplarinin toplam kaybi >= %50 ve objektif temizlenmediyse CEKILME
            if ((time - (_plan getOrDefault ["fragoT", -99])) > 10 && {!(missionNamespace getVariable ["lambs_danger_fragoOff", false])}) then {
                _plan set ["fragoT", time];
                private _ilkF = _plan getOrDefault ["ilkSayi", createHashMap];
                private _ilkFT = 0; private _simFT = 0;
                { _ilkFT = _ilkFT + (_ilkF getOrDefault [groupId _x, 0]); _simFT = _simFT + ({alive _x} count (units _x)); } forEach _gruplar;
                if (_ilkFT >= 8 && {(1 - (_simFT / _ilkFT)) >= 0.5} && {_fazSure > 30}) then {
                    diag_log format ["[PLAN-FRAGO] %1 | SALDIRI BASARISIZ: kayip yuzde %2 (esik yuzde 50, %3 / %4 asker) -> CEKILME", _id, round ((1 - (_simFT / _ilkFT)) * 100), _simFT, _ilkFT];
                    [_plan, format ["saldiri kaybi yuzde %1 (esik 50): objektif alinamadi", round ((1 - (_simFT / _ilkFT)) * 100)]] call _kayipCekil;
                    continue
                };
            };
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
            // v8.214 ATES KAYDIRMA (topcu): manevra objektife < 250 m yaklasinca ates objektifin DERINLIGINE (120 m, yaklasma yonunun tersi) kaydirilir; RED kurallari _topcuAt icinde (dost < RED ise atmaz)
            if ((_plan getOrDefault ["topcu", 0]) in [2, 3] && {_yakinM2 < 250} && {_dusmanVar} && {(time - (_plan getOrDefault ["kaydirT", -999])) > 60} && {_maneuv isNotEqualTo []}) then {
                _plan set ["kaydirT", time];
                [_plan, _obj getPos [120, (leader (_maneuv select 0)) getDir _obj], "ATES KAYDIRMA (derinlik)"] call _topcuAt;
            };
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
                    if ((_n param [2, -1]) >= 0) then { [_g, _n select 2, (_n select 1)] call FUNC(hendekYerles); } else { [_g, _n select 0, _n select 1] call FUNC(mevziKur); };
                    // v8.256: hendege yerlesen grup da bos statik silahlari (DShK / MG / AT) kullanir (mevziKur zaten kendi statiklerine bakar)
                    if ((_n param [2, -1]) >= 0) then { [_g, _obj, _n select 1, [_plan getOrDefault ["mevziYar", 0], 300] select ((_plan getOrDefault ["mevziYar", 0]) <= 0)] call FUNC(mevziStatik); };
                } forEach _gruplar;
                [_plan, "BEKLE", "sektorlar tutuldu, garrison / mevzi"] call _fazGec;
            };
            continue
        };
        if (_faz isEqualTo "BEKLE") then {
            // v8.256 STATIK DOLDURMA: 45 sn'de bir bos statik silahlari (olen nisanci yerine) hendek gruplari doldurur
            if (_tip isEqualTo 1 && {(time - (_plan getOrDefault ["statikT", -99])) >= 45}) then {
                _plan set ["statikT", time];
                private _hRs = [_plan getOrDefault ["mevziYar", 0], 300] select ((_plan getOrDefault ["mevziYar", 0]) <= 0);
                { if (_x getVariable [QGVAR(hendekte), false]) then { [_x, _obj, [_plan getOrDefault ["tehditB", _B], _B] select ((_plan getOrDefault ["tehditB", -1]) < 0), _hRs] call FUNC(mevziStatik); }; } forEach _gruplar;
            };
            // v8.243 SAVUNMA SURESI UZATMA (RPT c7592408: 1200 sn dolunca savunma plani saldiri baslamadan 12 sn once BITTI, hendekteki gruplar serbest kaldi): sure dolunca temas / bilinen dusman varsa
            //   savunma 2 katina kadar (TASARIM degeri) surer; temas kesilince biter. Kapatma: lambs_danger_savunmaUzatmaOff = true.
            // v8.249 SAVUNMA TEMASSIZ SURE (kullanici: "savunan takim icin zaman limiti koy: 30 dk temas olmadiysa biraksinlar ya da 10 saat beklesinler; catisma ortasinda adamlar temas olmadan savunmayi biraktilar"):
            //   eski gizli 1200 sn tavan (Zeus 'Sinirsiz' secili olsa bile P1 1266 sn'de bitti) KALDIRILDI. Zeus 'Sure siniri' savunmada TEMASSIZ sure: son temas (grup temasi ya da objektif 400 m cevresinde bilinen dusman)
            //   ile simdi arasi bu kadar olursa BITTI; 'Sinirsiz' = hic bitmez. Global toplam tavan istenirse lambs_danger_planSavunmaS > 0 (varsayilan 0 = yok).
            private _bosS = _plan getOrDefault ["sureSn", 0];
            if (_bosS > 0) then {
                private _temasSimdi = (({[_x] call _temasta} count _gruplar) > 0) || {(_plan getOrDefault ["savDus", 0]) > 0};
                if (_temasSimdi || {(_plan getOrDefault ["sonTemasT", -1]) < 0}) then { _plan set ["sonTemasT", time]; };
                if ((time - (_plan get "sonTemasT")) > _bosS) then {
                    diag_log format ["[PLAN-SAVUNMA] %1 | %2 sn TEMASSIZ gecti (Zeus sure siniri) -> savunma biter", _id, round (time - (_plan get "sonTemasT"))];
                    [_plan, "BITTI", format ["savunma: %1 sn temassiz", round _bosS]] call _fazGec;
                    continue
                };
            };
            private _savS = missionNamespace getVariable ["lambs_danger_planSavunmaS", 0];
            if (_savS > 0 && {_fazSure > _savS}) then {
                private _temasVarS = (({[_x] call _temasta} count _gruplar) > 0) || {(_plan getOrDefault ["savDus", 0]) > 0};
                if (_temasVarS && {_fazSure < (_savS * 2)} && {!(missionNamespace getVariable ["lambs_danger_savunmaUzatmaOff", false])}) then {
                    if !(_plan getOrDefault ["savUzatildi", false]) then {
                        _plan set ["savUzatildi", true];
                        diag_log format ["[PLAN-SAVUNMA] %1 | SURE DOLDU (%2 sn) ama temas / bilinen dusman var (dusman %3) -> savunma temas kesilene kadar surer (en cok %4 sn)", _id, round _savS, _plan getOrDefault ["savDus", 0], round (_savS * 2)];
                    };
                } else {
                    [_plan, "BITTI", "savunma suresi doldu"] call _fazGec;
                };
            };
            // v8.204 SAVUNMA KOMUTANI (kullanici: "savunma sadece bekliyor"; FM 3-98 engagement / disengagement + MCWP 3-11.1 savunmada yedek karsi saldirisi - genel ilke, esikler TASARIM degeri):
            //   ortak resim = plan gruplari liderlerinin objektif 400 m cevresinde bildigi dusman; YEDEK grup, (dusman >= 2 ve (savunma kaybi >= %25 ya da dusman objektife <= 150 m)) olunca dusmanin agirlik merkezine KARSI SALDIRI emri alir (150 sn'de bir);
            //   toplam kayip >= %60 ise savunma "mevzi kaybedildi" sayilir ve hayatta kalanlar cekilir (plan BITTI, gruplar serbest).
            if ((time - (_plan getOrDefault ["savDenT", -99])) > 10 && {!(missionNamespace getVariable ["lambs_danger_savunmaKomutanOff", false])}) then {
                _plan set ["savDenT", time];
                private _tfS = _plan get "taraf";
                private _dusN = [];
                private _dusA = [];   // v8.243: topcu (savunma atesi) icin genis liste: objektife <= 900 m
                {
                    private _glS = leader _x;
                    if (!isNull _glS) then {
                        {
                            private _hobj = _x select 4;
                            // v8.243: yalniz GERCEK dusman (yaya ya da murettebatli arac); bos arac / statik / nesne dusman sayilmaz (RPT c7592408: hic dusman yokken '6 dusman, objektife 19 m' sayildi ve YEDEK acikta kaldi)
                            if (!isNull _hobj && {(_tfS getFriend (_x select 2)) < 0.6} && {alive _hobj} && {(_glS knowsAbout _hobj) > 0.4}
                                && {(_hobj isKindOf "CAManBase") || {(({alive _x} count (crew _hobj)) > 0) && {_hobj isKindOf "AllVehicles"}}}) then {
                                private _dOb = (getPosATL _hobj) distance2D _obj;
                                if (_dOb < 400) then { _dusN pushBackUnique _hobj; };
                                if (_dOb < 900) then { _dusA pushBackUnique _hobj; };
                            };
                        } forEach (_glS nearTargets 900);
                    };
                } forEach _gruplar;
                private _ilkS = _plan getOrDefault ["ilkSayi", createHashMap];
                private _ilkT = 0; private _simdiT = 0;
                { _ilkT = _ilkT + (_ilkS getOrDefault [groupId _x, 0]); _simdiT = _simdiT + ({alive _x} count (units _x)); } forEach _gruplar;
                private _kayipS = if (_ilkT > 0) then {1 - (_simdiT / _ilkT)} else {0};
                private _yakinD = 99999;
                { _yakinD = _yakinD min ((getPosATL _x) distance2D _obj); } forEach _dusN;
                _plan set ["savDus", count _dusN];
                // v8.243 KARSI SALDIRI DONUSU (RPT c7592408: YEDEK grup 'dusman merkezine' gitti, orada acikta LINE halinde 10 dk durdu; 4 mermilik bir salvoda 7 kisi birden oldu): karsi saldiri grubu hedefe varip
                //   temas yoksa (varis + 40 sn) ya da 200 sn sonra / dusman kalmayinca MEVZIsine DONER (hendekYerles / mevziKur, plan notu). Temas suruyorsa savasmaya devam eder.
                private _notlar = _plan get "notlar";
                private _ks = _plan getOrDefault ["karsiGrup", createHashMap];
                _plan set ["karsiGrup", _ks];
                private _ksBit = [];
                {
                    private _kg = objNull;
                    private _kid = _x;
                    { if ((groupId _x) isEqualTo _kid) exitWith { _kg = _x; }; } forEach _gruplar;
                    if (isNull _kg || {({alive _x} count (units _kg)) isEqualTo 0}) then { _ksBit pushBack _kid; } else {
                        private _kv = _ks get _kid;
                        private _kt0 = _kv select 0;
                        private _kep = _kv select 1;
                        private _kGecen = time - _kt0;
                        private _kVardi = ((leader _kg) distance2D _kep) < 45;
                        private _kTemas = [_kg] call _temasta;
                        if (!_kTemas && {(_kGecen > 200) || {_kVardi && {_kGecen > 40}} || {(_dusN isEqualTo []) && {_kGecen > 40}}}) then {
                            _ksBit pushBack _kid;
                            [_kg] call _wpTemizle;
                            _kg setVariable ["lambs_danger_isExecutingTactic", nil];
                            _kg setVariable [QGVAR(isBounding), nil];
                            private _kn = _notlar getOrDefault [groupId _kg, [_obj, _B]];
                            if ((_kn param [2, -1]) >= 0) then { [_kg, _kn select 2, _kn select 1] call FUNC(hendekYerles); } else { [_kg, _kn select 0, _kn select 1] call FUNC(mevziKur); };
                            diag_log format ["[PLAN-SAVUNMA] %1 | KARSI SALDIRI BITTI: %2 mevziye donuyor (%3 sn, %4)", _id, groupId _kg, round _kGecen, ["sure/temas yok", "hedefe vardi"] select _kVardi];
                        };
                    };
                } forEach (keys _ks);
                { _ks deleteAt _x; } forEach _ksBit;
                if (_kayipS >= 0.5 && {(count _dusN) >= 2} && {_ilkT >= 6} && {!(missionNamespace getVariable ["lambs_danger_kayipDonusOff", false])}) then {
                    // v8.254: eskiden %60'ta plan BITTI (gruplar mevzide serbest, sonuna kadar savasiyordu); simdi %50'de HQ'ya (yoksa rally point'e) geri cekilme
                    diag_log format ["[PLAN-SAVUNMA] %1 | KAYIP yuzde %2 (esik 50) ve dusman %3: mevzi tutulamiyor, HQ'ya donus", _id, round (_kayipS * 100), count _dusN];
                    private _epK = [0, 0, 0];
                    { _epK = _epK vectorAdd (getPosATL _x); } forEach _dusN;
                    _epK = _epK vectorMultiply (1 / (count _dusN));
                    [_plan, format ["savunma kaybi yuzde %1 (esik 50, mevzi tutulamiyor)", round (_kayipS * 100)], _epK] call _kayipCekil;
                    continue
                };
                if (_kayipS >= 0.6 && {(count _dusN) >= 2}) then {
                    diag_log format ["[PLAN-SAVUNMA] %1 | KAYIP yuzde %2 (esik yuzde 60) ve dusman %3: mevzi kaybedildi, hayatta kalanlar cekiliyor", _id, round (_kayipS * 100), count _dusN];
                    [_plan, "BITTI", format ["savunma kaybi yuzde %1 (mevzi kaybedildi)", round (_kayipS * 100)]] call _fazGec;
                } else {
                    if ((count _dusN) >= 2 && {(_kayipS >= 0.25) || {_yakinD <= 150}} && {(time - (_plan getOrDefault ["savKarsiT", -999])) > 150}) then {
                        // v8.231 TEK GRUP KARSI SALDIRI YAPMAZ (RPT 92fcbcbb: tek savunma grubu hendege yerlesti, 3 sn sonra "KARSI SALDIRI" ile hendekten cikip dusmana saldirdi — "mevzilenmiyorlar"): karsi saldiri YEDEKTIR; savunmada en az bir grup mevzide KALIR
                        //   (YEDEK rolu en az 2 grup, rolsuz yedek yalniz >= 3 grup varken; mevziyi tutan gruplar karsi saldiriya alinmaz)
                        private _yedekG = if ((count _gruplar) >= 2) then { _gruplar select {(_roller getOrDefault [groupId _x, ""]) isEqualTo "YEDEK" && {({alive _x} count (units _x)) >= 3} && {!([_x] call _temasta)} && {!((groupId _x) in (keys _ks))}} } else {[]};
                        if (_yedekG isEqualTo [] && {(count _gruplar) >= 3}) then { _yedekG = _gruplar select {({alive _x} count (units _x)) >= 4 && {!([_x] call _temasta)} && {!(_x getVariable [QGVAR(hendekte), false])} && {!((groupId _x) in (keys _ks))}}; _yedekG = _yedekG select [0, 1]; };
                        if (_yedekG isNotEqualTo []) then {
                            private _ep = [0, 0, 0];
                            { _ep = _ep vectorAdd (getPosATL _x); } forEach _dusN;
                            _ep = _ep vectorMultiply (1 / (count _dusN));
                            _plan set ["savKarsiT", time];
                            {
                                [_x, "SALDIRI", [_ep]] call FUNC(hqEmir);
                                _ks set [groupId _x, [time, _ep]];
                                _x setVariable [QGVAR(hendekte), nil];   // v8.243: karsi saldiri sirasinda mevzi tutma devre disi; donuste hendekYerles tekrar yazar
                                diag_log format ["[PLAN-SAVUNMA] %1 | KARSI SALDIRI: %2 (%3) -> dusman agirlik merkezi %4 (dusman %5, savunma kaybi yuzde %6, en yakin dusman objektife %7 m) | dusmanlar: %8", _id, groupId _x, _roller getOrDefault [groupId _x, "-"], mapGridPosition _ep, count _dusN, round (_kayipS * 100), round _yakinD,
                                    ((_dusN select [0, 6]) apply { format ["%1/%2", typeOf _x, side (group (effectiveCommander _x))] }) joinString ", "];
                            } forEach _yedekG;
                        };
                    };
                };
                // v8.243 SAVUNMA ATESI (RPT c7592408, kullanici: "savunan takim artillery cagirdi mi"): topcu destegi 'cagri' (2 / 3) olan savunma plani, bilinen dusman >= 3 (objektife <= 900 m) ve dusman
                //   en yakin dostuna >= RED + 25 m iken (kalani _topcuAt kendi RED kurallariyla eler / kaydirir) dusman agirlik merkezine 120 sn'de bir atis ister (FM 3-09 savunma atesi / yaklasma yolu).
                //   Eski durum: savunmada yalniz KARSI-BATARYA vardi (dusman topcusu bilinirse); yaklasan piyade / araca atis YOKTU. Kapatma: lambs_danger_savunmaTopcuOff = true.
                if ((_plan getOrDefault ["topcu", 0]) in [2, 3] && {!(missionNamespace getVariable ["lambs_danger_savunmaTopcuOff", false])} && {(count _dusA) >= 3} && {(time - (_plan getOrDefault ["savTopT", -999])) > 120}) then {
                    private _dostlarS = (allUnits select {alive _x && {(side (group _x)) isEqualTo _tfS}}) apply {getPosATL _x};
                    private _uzakS = _dusA select {
                        private _ph = getPosATL _x;
                        (_dostlarS findIf {(_x distance2D _ph) < 480}) < 0
                    };
                    if ((count _uzakS) >= 2) then {
                        private _tc = [0, 0, 0];
                        { _tc = _tc vectorAdd (getPosATL _x); } forEach _uzakS;
                        _tc = _tc vectorMultiply (1 / (count _uzakS));
                        private _atildi = [_plan, _tc, format ["SAVUNMA ATESI (dusman %1, dosta >= 480 m olan %2)", count _dusA, count _uzakS]] call _topcuAt;
                        _plan set ["savTopT", [time - 90, time] select _atildi];   // atilmadiysa (izin / menzil / RED) 30 sn sonra tekrar dener
                    };
                };
            };
            continue
        };
    } forEach lambs_danger_planlar;
    { lambs_danger_planlar deleteAt _x; } forEach _bitenler;
    missionNamespace setVariable ["lambs_danger_planAdim", "tur bitti"];
};
