#include "script_component.hpp"
/*
 * Author: Cinar (ELITE fork)
 * ARAC SURUS A/B TESTI (v8.239) - kullanici: "rhs apc'leri icin A/B testi yazabilirsin". AI surucunun neden surmedigini (kok neden hala bilinmiyor: doMove sonrasi 0 m, hedef 'DoNotPlan')
 * TEK, KISA (<= ~25 sn) bir testle ayirmak icin: ayni arac sinifi, ayni acik arazide, YAN YANA SERIT SERIT, temiz murettebatla (createVehicleCrew, sunucuda yerel) farkli kosullarda 300 m ileri gonderilir.
 * VARYANTLAR (sinif basina):
 *   A  SAF + waypoint     : ELITE / LAMBS izleyicileri bu gruba KAPALI (lambs_danger_disableGroupAI + birim disableAI), vanilla yolu: grup waypoint'i
 *   B  SAF + doMove       : ayni, ama surucuye dogrudan doMove (nakil / recon'un kullandigi yol)
 *   C  ELITE + doMove     : ELITE izleyicileri ACIK (gercek kosul), surucuye doMove
 *   D  ELITE + waypoint   : ELITE acik, grup waypoint'i
 *   E  ELITE + 8 yolcu    : ELITE acik, ayri gruptan 8 piyade kargoda, doMove (gercek nakil kosulu)
 * Cikarim (otomatik, [SURUS-AB-OZET]): A/B gidip C/D/E gitmiyorsa ELITE/LAMBS etkisi; hepsi gitmiyorsa arac sinifi / mod; yalniz doMove gitmiyorsa emir yolu; yalniz yolcuyla gitmiyorsa kargo/yolcu etkisi.
 * Olcum: her saniye mesafe + en yuksek hiz; 5. sn'de expectedDestination + unitReady; 'GITTI' = test suresinde >= 40 m (hedefe giden dogrultuda degil, sadece yer degistirme). Yerellik: arac / surucu sunucuda.
 * BISECT (istege bagli): C gitmiyor ama A/B gidiyorsa, ELITE izleyicilerinin kapatma anahtarlari (mekanizeOff, ezmeOff, murKoruOff, aracSenkronOff, ...) GECICI olarak GLOBAL kapatilip ikili aramayla suclu aranir
 *   (tek suclu varsayimi; her adim ~12 sn; bitince anahtarlar ESKI degerine doner). TEST OTURUMU icin: diger AI'lar o sirada ilgili izleyicilerden yoksun kalir.
 * Zeus: "ELITE Arac SURUS A/B Testi" modulu (duz, ACIK arazide birakin; modul yonu = gidis yonu). Log: [SURUS-AB] satirlar + [SURUS-AB-OZET]. Test araclari bitince silinir (lambs_danger_surusABKal = true ise kalir).
 * Modlar: "BOOT" (olaylari kaydeder; acilista), "SINIFLAR" (aday sinif listesi, istemci), "CALISTIR" (sunucu).
 *
 * Arguments:
 * 0: Mod <STRING> (default: "BOOT")
 * 1: Arguman dizisi <ARRAY>
 *
 * Return Value: moda gore
 * Public: No
*/

params [["_mod", "BOOT", [""]], ["_a", [], [[]]]];

// ------------------------------------------------------------------ aday siniflar (Zeus paneli, istemci)
if (_mod isEqualTo "SINIFLAR") exitWith {
    private _ham = "(getNumber (_x >> 'scope') isEqualTo 2) && {(getNumber (_x >> 'side')) in [0, 1, 2]} && {(getNumber (_x >> 'transportSoldier')) >= 6} && {configName _x isKindOf 'LandVehicle'} && {!(configName _x isKindOf 'StaticWeapon')}" configClasses (configFile >> "CfgVehicles");
    private _liste = _ham apply {
        private _sim = getText (_x >> "simulation");
        [configName _x, format ["%1 [%2] %3 | %4 yolcu", getText (_x >> "displayName"), configName _x, ["TEKERLEKLI", "PALETLI"] select (((toLower _sim) find "tank") >= 0), getNumber (_x >> "transportSoldier")]]
    };
    _liste sort true;
    (_liste select [0, 400])
};

// ------------------------------------------------------------------ olaylar
if (_mod isEqualTo "BOOT") exitWith {
    if (!isNil "lambs_danger_surusABBoot") exitWith {false};
    lambs_danger_surusABBoot = true;
    ["lambs_danger_surusABIstegi", {
        if (!isServer) exitWith {};
        ["CALISTIR", _this] spawn FUNC(surusAB);
    }] call CBA_fnc_addEventHandler;
    ["lambs_danger_surusABYanit", {
        params ["_satirlar"];
        if (!hasInterface) exitWith {};
        { systemChat format ["[SURUS-AB] %1", _x]; } forEach _satirlar;
    }] call CBA_fnc_addEventHandler;
    true
};

// ------------------------------------------------------------------ sunucu: testi calistir
if (!isServer || {_mod isNotEqualTo "CALISTIR"}) exitWith {false};
if (!isNil "lambs_danger_surusABCalisiyor" && {lambs_danger_surusABCalisiyor} && {(time - (missionNamespace getVariable ["lambs_danger_surusABT", -999])) < 400}) exitWith {
    ["lambs_danger_surusABYanit", [["onceki test hala calisiyor, bekleyin"]], (_a param [7, 2])] call CBA_fnc_ownerEvent;
    false
};
lambs_danger_surusABCalisiyor = true;
lambs_danger_surusABT = time;

_a params ["_siniflar", "_poz", "_yon", "_elite", "_yolcu", "_sure", "_bisect", "_sahip"];
private _mesafe = missionNamespace getVariable ["lambs_danger_surusABMesafe", 300];
private _hedef = _poz getPos [_mesafe, _yon];
private _satirlar = [];
private _yaz = {
    params ["_m"];
    diag_log _m;
    _satirlar pushBack _m;
};
private _tumArac = [];

private _kodlar = [["A", "SAF + waypoint", false, "WP", false], ["B", "SAF + doMove", false, "DOMOVE", false]];
if (_elite) then {
    _kodlar pushBack ["C", "ELITE + doMove", true, "DOMOVE", false];
    _kodlar pushBack ["D", "ELITE + waypoint", true, "WP", false];
    if (_yolcu) then { _kodlar pushBack ["E", "ELITE + 8 yolcu + doMove", true, "DOMOVE", true]; };
};

// ---- tek arac kur: [sinif, eliteAcik, yolcuVar, seritNo] -> kayit (HashMap)
private _kur = {
    params ["_cls", "_eliteAcik", "_yolcuVar", "_k"];
    private _p = _poz getPos [_k * 26, _yon + 90];
    private _e = _p findEmptyPosition [0, 25, _cls];
    if (_e isNotEqualTo []) then { _p = _e; };
    private _v = createVehicle [_cls, _p, [], 0, "NONE"];
    _v setDir _yon;
    _v setFuel 1;
    private _g = createVehicleCrew _v;
    _g setVariable ["lambs_danger_gorev", "HARIC"];
    _v setVariable ["lambs_danger_gorev", "HARIC"];
    _v setVariable ["lambs_danger_surusAB", true];
    if (!_eliteAcik) then {
        _g setVariable ["lambs_danger_disableGroupAI", true];
        { _x setVariable ["lambs_danger_disableAI", true]; } forEach (units _g);
    };
    private _yolcuSay = 0;
    if (_yolcuVar) then {
        private _pg = createGroup (side _g);
        _pg setVariable ["lambs_danger_gorev", "HARIC"];
        private _pc = switch (side _g) do { case east: {"O_Soldier_F"}; case independent: {"I_Soldier_F"}; default {"B_Soldier_F"} };
        for "_i" from 1 to ((_v emptyPositions "cargo") min 8) do {
            private _u = _pg createUnit [_pc, _p, [], 0, "NONE"];
            _u moveInCargo _v;
            _yolcuSay = _yolcuSay + 1;
        };
    };
    _tumArac pushBack _v;
    createHashMapFromArray [["sinif", _cls], ["arac", _v], ["grup", _g], ["bas", getPosATL _v], ["maks", 0], ["mesafe", 0], ["d5", 0], ["tani5", ""], ["yolcu", _yolcuSay]]
};

// ---- emri ver
private _emir = {
    params ["_r", "_tur"];
    private _v = _r get "arac";
    private _g = _r get "grup";
    private _d = driver _v;
    _r set ["bas", getPosATL _v];
    _r set ["t0", time];
    if (isNull _d) exitWith { _r set ["not", "SURUCU YOK (createVehicleCrew bos)"]; };
    if (_tur isEqualTo "WP") then {
        private _wp = _g addWaypoint [_hedef, 0];
        _wp setWaypointType "MOVE";
        _wp setWaypointSpeed "FULL";
        _wp setWaypointBehaviour "AWARE";
        _g setCurrentWaypoint _wp;
    } else {
        _v engineOn true;
        _d doMove _hedef;
    };
};

// ---- olc: sure boyunca her saniye mesafe / hiz; 5. sn'de tani
private _olc = {
    params ["_kayitlar", "_sn"];
    for "_s" from 1 to _sn do {
        sleep 1;
        {
            private _r = _x;
            private _v = _r get "arac";
            if (!isNull _v && {alive _v}) then {
                _r set ["mesafe", (_r get "bas") distance2D _v];
                _r set ["maks", (_r get "maks") max (speed _v)];
                if (_s isEqualTo 5) then {
                    _r set ["d5", _r get "mesafe"];
                    private _d = driver _v;
                    _r set ["tani5", if (isNull _d) then {"surucu yok"} else {format ["bekl.hedef %1 | unitReady %2", (expectedDestination _d) select 1, unitReady _d]}];
                };
            };
        } forEach _kayitlar;
    };
};

// ---- temizlik
private _temizle = {
    params ["_kayitlar"];
    if (missionNamespace getVariable ["lambs_danger_surusABKal", false]) exitWith {};
    {
        private _v = _x get "arac";
        private _g = _x get "grup";
        { if (!isNull _x) then { deleteVehicle _x; }; } forEach ((crew _v) + [_v]);
        if (!isNull _g) then { deleteGroup _g; };
    } forEach _kayitlar;
};

// ---- tek ELITE+doMove denemesi (bisect icin): gitti mi?
private _tekDene = {
    params ["_cls", "_sn"];
    private _r = [_cls, true, false, -3] call _kur;   // serit -3: ana test seritlerinin disinda
    sleep 3;
    [_r, "DOMOVE"] call _emir;
    [[_r], _sn] call _olc;
    private _gitti = (_r get "mesafe") >= 40;
    [[_r]] call _temizle;
    _gitti
};

private _baslik = format ["SURUS A/B | %1 sinif | %2 varyant | hedef %3 m | sure %4 sn | konum %5 | yon %6", count _siniflar, count _kodlar, _mesafe, _sure, mapGridPosition _poz, round _yon];
[format ["[SURUS-AB] %1", _baslik]] call _yaz;

private _serit = 0;
private _ozetler = [];
private _bisL = [];
{
    private _cls = _x;
    private _kay = [];
    {
        _x params ["_kod", "_ad", "_eliteAcik", "_tur", "_yolcuVar"];
        private _r = [_cls, _eliteAcik, _yolcuVar, _serit] call _kur;
        _r set ["kod", _kod];
        _r set ["ad", _ad];
        _r set ["tur", _tur];
        _kay pushBack _r;
        _serit = _serit + 1;
    } forEach _kodlar;
    _serit = _serit + 1;   // siniflar arasi bosluk
    _ozetler pushBack [_cls, _kay];
} forEach _siniflar;

sleep 4;   // murettebat otursun, izleyiciler (ELITE) gruplari alsin
private _hepsi = [];
{ _hepsi append (_x select 1); } forEach _ozetler;
{ [_x, _x get "tur"] call _emir; } forEach _hepsi;
[_hepsi, _sure] call _olc;

{
    _x params ["_cls", "_kay"];
    private _sonuc = createHashMap;
    {
        private _r = _x;
        private _v = _r get "arac";
        private _gitti = (_r get "mesafe") >= 40;
        _sonuc set [_r get "kod", _gitti];
        private _d = driver _v;
        [format ["[SURUS-AB] %1 | %2 %3 | %4 | %5 sn: %6 m (5. sn %7 m) maks %8 km/s | %9 | yerel arac:%10 surucu:%11 | motor:%12 yakit:%13 canMove:%14 yolcu:%15%16",
            _cls, _r get "kod", _r get "ad", ["GITMEDI", "GITTI"] select _gitti, _sure, round (_r get "mesafe"), round (_r get "d5"), round (_r get "maks"), _r get "tani5",
            local _v, if (isNull _d) then {"yok"} else {local _d}, isEngineOn _v, (fuel _v) toFixed 2, canMove _v, _r get "yolcu", [format [" | NOT: %1", _r getOrDefault ["not", ""]], ""] select ((_r getOrDefault ["not", ""]) isEqualTo "")]] call _yaz;
    } forEach _kay;
    // cikarim
    private _g = { _sonuc getOrDefault [_this, false] };
    private _yorum = "";
    private _safVar = ("A" call _g) || {"B" call _g};
    private _eliteVar = _elite;
    if (!_safVar && {!_elite || {!("C" call _g || {"D" call _g} || {"E" call _g})}}) then {
        _yorum = "HICBIRI GITMEDI: ELITE kapaliyken bile gitmiyor -> arac sinifi / mod / sunucu tarafi (ELITE disi); bu sinif icin motor ya da AI surucu sorunu, farkli sinifla karsilastirin.";
    } else {
        if (_safVar && {_elite} && {!("C" call _g)} && {!("D" call _g)}) then {
            _yorum = "SAF GITTI, ELITE ACIKKEN GITMEDI -> ELITE / LAMBS izleyicilerinden biri surucuyu engelliyor (bisect ile suclu aranir).";
        } else {
            if (_elite && {"C" call _g} && {"D" call _g} && {_yolcu} && {!("E" call _g)}) then {
                _yorum = "YOLCUSUZ GITTI, YOLCULU GITMEDI -> kargodaki yolcu / grup etkisi (binme, ayri grup komutani, agirlik).";
            } else {
                if (("A" call _g) && {!("B" call _g)}) then {
                    _yorum = "waypoint GITTI, doMove GITMEDI -> emir yolu: nakil / recon'u surucuye dogrudan doMove yerine grup waypoint'iyle surmek calisabilir.";
                } else {
                    if (!("A" call _g) && {"B" call _g}) then {
                        _yorum = "doMove GITTI, waypoint GITMEDI -> waypoint yolu sorunlu (nakil doMove kullandigi icin beklenen).";
                    } else {
                        _yorum = "Test kosulunda hepsi GITTI -> temiz murettebatla sorun yok; gercek sorun nakil mantigi / Zeus'ta yerel yaratma + sunucu devri / plan kosulu.";
                    };
                };
            };
        };
    };
    private _oz = format ["[SURUS-AB-OZET] %1 | %2 | %3", _cls, ["A", "B", "C", "D", "E"] apply { format ["%1:%2", _x, if (_x in _sonuc) then {["X", "G"] select (_sonuc get _x)} else {"-"}] } joinString " ", _yorum];
    [_oz] call _yaz;
    if (_bisect && {_elite} && {_safVar} && {!("C" call _g)}) then { _bisL pushBack _cls; };
} forEach _ozetler;

{ [_x select 1] call _temizle; } forEach _ozetler;
// ---- bisect (ana arac seritleri silindikten sonra)
{
    private _cls = _x;
        private _anahtar = ["mekanizeOff", "mekanizeDuzeltOff", "ezmeOff", "murKoruOff", "aracSenkronOff", "aracUzakOff", "sunucuDevirOff", "aracMedevacOff", "taksiOff", "tehditBakisOff", "havaFarkOff", "haltOff"];
        private _dene = {
            params ["_cls2", "_kume"];
            private _eski = _kume apply { missionNamespace getVariable [format ["lambs_danger_%1", _x], false] };
            { missionNamespace setVariable [format ["lambs_danger_%1", _x], true]; } forEach _kume;
            private _gitti2 = [_cls2, 12] call _tekDene;
            { missionNamespace setVariable [format ["lambs_danger_%1", _x], _eski select _forEachIndex]; } forEach _kume;
            _gitti2
        };
        private _tum = [_cls, _anahtar] call _dene;
        [format ["[SURUS-AB-BISECT] %1 | TUM izleyiciler kapali (%2 anahtar): %3", _cls, count _anahtar, ["GITMEDI -> sorun izleyici disi (LAMBS FSM / ELITE cekirdek / arac)", "GITTI -> suclu anahtar araniyor"] select _tum]] call _yaz;
        if (_tum) then {
            private _kume = +_anahtar;
            while {(count _kume) > 1} do {
                private _yarim = floor ((count _kume) / 2);
                private _ilk = _kume select [0, _yarim];
                private _ikinci = _kume select [_yarim, count _kume];
                private _ok = [_cls, _ilk] call _dene;
                [format ["[SURUS-AB-BISECT] %1 | kapali: %2 -> %3", _cls, _ilk joinString ",", ["GITMEDI (suclu digerlerinde)", "GITTI (suclu bunlarda)"] select _ok]] call _yaz;
                _kume = if (_ok) then {_ilk} else {_ikinci};
            };
            private _suclu = _kume select 0;
            private _dogrula = [_cls, [_suclu]] call _dene;
            [format ["[SURUS-AB-BISECT] %1 | SUCLU ADAY: lambs_danger_%2 (yalniz bu kapaliyken %3) - tek suclu varsayimi", _cls, _suclu, ["GITMEDI: tek basina yetmiyor, birden cok neden olabilir", "GITTI: DOGRULANDI"] select _dogrula]] call _yaz;
        };

} forEach _bisL;
["lambs_danger_surusABYanit", [_satirlar select {(_x find "[SURUS-AB-OZET]") >= 0 || {(_x find "[SURUS-AB-BISECT]") >= 0}}], _sahip] call CBA_fnc_ownerEvent;
lambs_danger_surusABCalisiyor = false;
true
