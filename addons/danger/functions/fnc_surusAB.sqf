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
 *   F  RECON profili      : fnc_reconArac'in TAM ayarlari (kullanici: 'operasyon emrinde yalniz recon gitmiyor, digerleri normal'): 4 yolcu (PATH kapali), doStop -> grup SAFE / GREEN / NORMAL, farlar kapali,
 *                           surucu forceSpeed 9 + AUTOCOMBAT kapali, grup isExecutingTactic + surucu forceMove / senkT bayraklari, doMove + 'ELITE RECON-ARAC' waypoint'i
 *   G  RECON-HAFIF        : F'nin yalniz SAFE / GREEN / isiksiz / doStop / doMove + waypoint kismi (forceSpeed 9, AUTOCOMBAT kapali, yolcu PATH kapali, ELITE bayraklari YOK)
 *   Cikarim: F gitmiyor + G gidiyor -> forceSpeed 9 / yolcu PATH / ELITE bayraklari; ikisi de gitmiyor + C gidiyor -> SAFE / GREEN / isiksiz / doStop-doMove sirasi; ikisi de gidiyor -> recon'un sorunu secim / alma (pickup) asamasinda.
 * TEST SETLERI (v8.239c; kullanici sonucu: Stryker YOLCUSUZ hepsi gitti, YOLCULU (E / F / G) gitmedi; BTR-70 E gitti ama RECON profili F / G gitmedi):
 *   set 0 Temel (A-G, yukarisi); set 1 RECON AYRISTIRMA (yolcusuz): C kontrol, H doMove+waypoint, I doStop+doMove, J SAFE/GREEN/isiksiz+doMove, K doStop+waypoint, L forceSpeed 9+doMove, M RECON tam;
 *   set 2 YOLCU AYRISTIRMA: C kontrol, N 4 yolcu, O 8 yolcu ELITE kapali, P 8 yolcu ayni grupta, Q 8 yolcu orderGetIn (gercek nakil yolu), R 1 yolcu, S 8 yolcu + 6 sn bekle.
 *   Her sette [SURUS-AB-OZET] sonunda BELIRTEC CIKARIMI: gitmeyen varyantlarin ORTAK belirteci - calisanlarda olmayan (otomatik suclu aday).
 * Cikarim (otomatik, set 0, [SURUS-AB-OZET]): A/B gidip C/D/E gitmiyorsa ELITE/LAMBS etkisi; hepsi gitmiyorsa arac sinifi / mod; yalniz doMove gitmiyorsa emir yolu; yalniz yolcuyla gitmiyorsa kargo/yolcu etkisi.
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

_a params ["_siniflar", "_poz", "_yon", "_elite", "_set", "_sure", "_bisect", "_sahip"];
if (_set isEqualType true) then { _set = [0, 0] select _set; };
private _yolcu = true;
private _mesafe = missionNamespace getVariable ["lambs_danger_surusABMesafe", 300];
private _hedef = _poz getPos [_mesafe, _yon];
private _satirlar = [];
private _yaz = {
    params ["_m"];
    diag_log _m;
    _satirlar pushBack _m;
};
private _tumArac = [];

// kod = [kod, ad, eliteAcik, tur ("+" ile birlesik komut dizisi), yolcuSayisi, yolcuModu ("CARGO" | "AYNI-GRUP" | "ORDERGETIN")]
//   tur belirtecleri: DOSTOP (doStop), SAFE (SAFE / GREEN / NORMAL + farlar kapali), FS9 (forceSpeed 9), DOMOVE (engineOn + doMove), WP (grup waypoint'i), RECON / RECON-HAFIF (fnc_reconArac sirasi)
private _kodlar = [];
switch (_set) do {
    case 1: {   // RECON AYRISTIRMA: yolcusuz; hangi komut recon'u bozuyor? (set 0'da F / G gitmemisti)
        _kodlar = [
            ["C", "kontrol: ELITE + doMove", true, "DOMOVE", 0, "CARGO"],
            ["H", "doMove + waypoint (doStop / SAFE yok)", true, "DOMOVE+WP", 0, "CARGO"],
            ["I", "doStop + doMove (waypoint yok)", true, "DOSTOP+DOMOVE", 0, "CARGO"],
            ["J", "SAFE / GREEN / isiksiz + doMove", true, "SAFE+DOMOVE", 0, "CARGO"],
            ["K", "doStop + waypoint (doMove yok)", true, "DOSTOP+WP", 0, "CARGO"],
            ["L", "forceSpeed 9 + doMove", true, "FS9+DOMOVE", 0, "CARGO"],
            ["M", "RECON profili tam, YOLCUSUZ", true, "RECON", 0, "CARGO"]
        ];
    };
    case 2: {   // YOLCU AYRISTIRMA: Stryker + kargo yolcusu (set 0'da E / F / G gitmemisti)
        _kodlar = [
            ["C", "kontrol: ELITE + doMove, yolcusuz", true, "DOMOVE", 0, "CARGO"],
            ["N", "4 yolcu (ayri grup, moveInCargo)", true, "DOMOVE", 4, "CARGO"],
            ["O", "8 yolcu, ELITE KAPALI", false, "DOMOVE", 8, "CARGO"],
            ["P", "8 yolcu AYNI grupta (murettebat grubu)", true, "DOMOVE", 8, "AYNI-GRUP"],
            ["Q", "8 yolcu orderGetIn (gercek nakil yolu)", true, "DOMOVE", 8, "ORDERGETIN"],
            ["R", "1 yolcu", true, "DOMOVE", 1, "CARGO"],
            ["S", "8 yolcu + 6 sn bekle sonra doMove", true, "BEKLE6+DOMOVE", 8, "CARGO"]
        ];
    };
    default {
        _kodlar = [["A", "SAF + waypoint", false, "WP", 0, "CARGO"], ["B", "SAF + doMove", false, "DOMOVE", 0, "CARGO"]];
        if (_elite) then {
            _kodlar pushBack ["C", "ELITE + doMove", true, "DOMOVE", 0, "CARGO"];
            _kodlar pushBack ["D", "ELITE + waypoint", true, "WP", 0, "CARGO"];
            _kodlar pushBack ["E", "ELITE + 8 yolcu + doMove", true, "DOMOVE", 8, "CARGO"];
            _kodlar pushBack ["F", "RECON profili (tam)", true, "RECON", 4, "CARGO"];
            _kodlar pushBack ["G", "RECON-HAFIF (SAFE/GREEN/isiksiz)", true, "RECON-HAFIF", 4, "CARGO"];
        };
    };
};

// ---- tek arac kur: [sinif, eliteAcik, yolcuVar, seritNo] -> kayit (HashMap)
private _kur = {
    params ["_cls", "_eliteAcik", "_yolcuVar", "_k", ["_yMod", "CARGO"]];
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
    private _pgDis = grpNull;
    if (_yolcuVar > 0) then {
        private _pg = if (_yMod isEqualTo "AYNI-GRUP") then {_g} else {createGroup (side _g)};
        if (_yMod isNotEqualTo "AYNI-GRUP") then { _pg setVariable ["lambs_danger_gorev", "HARIC"]; };
        if (!_eliteAcik) then {
            _pg setVariable ["lambs_danger_disableGroupAI", true];
        };
        private _pc = switch (side _g) do { case east: {"O_Soldier_F"}; case independent: {"I_Soldier_F"}; default {"B_Soldier_F"} };
        for "_i" from 1 to ((_v emptyPositions "cargo") min _yolcuVar) do {
            private _u = if (_yMod isEqualTo "ORDERGETIN") then { _pg createUnit [_pc, _p getPos [8, _yon + 180], [], 0, "NONE"] } else { _pg createUnit [_pc, _p, [], 0, "NONE"] };
            if (!_eliteAcik) then { _u setVariable ["lambs_danger_disableAI", true]; };
            if (_yMod isEqualTo "ORDERGETIN") then {
                _u assignAsCargo _v;
            } else {
                _u moveInCargo _v;
            };
            _yolcuSay = _yolcuSay + 1;
        };
        if (_yMod isEqualTo "ORDERGETIN") then { (units _pg) orderGetIn true; };
        _pgDis = _pg;
    };
    _tumArac pushBack _v;
    createHashMapFromArray [["sinif", _cls], ["arac", _v], ["grup", _g], ["bas", getPosATL _v], ["maks", 0], ["mesafe", 0], ["d5", 0], ["tani5", ""], ["yolcu", _yolcuSay], ["pg", _pgDis]]
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
    if (_tur in ["RECON", "RECON-HAFIF"]) then {
        // fnc_reconArac CALIS ile ayni sira: alma sonrasi doStop; bindirme; yolcu PATH kapali (yalniz TAM profil); sessiz surus ayarlari; doMove + 'ELITE RECON-ARAC' waypoint'i
        doStop _d;
        _g setBehaviour "SAFE";
        _g setCombatMode "GREEN";
        _g setSpeedMode "NORMAL";
        _v setPilotLight false;
        _v setCollisionLight false;
        if (_tur isEqualTo "RECON") then {
            _g setVariable ["lambs_danger_isExecutingTactic", true];
            _d setVariable ["lambs_danger_forceMove", true];
            _d setVariable ["lambs_danger_senkT", time + 900];
            _d disableAI "AUTOCOMBAT";
            { if (_x isNotEqualTo _d && {(group _x) isNotEqualTo _g}) then { _x disableAI "PATH"; }; } forEach (crew _v);
            _d forceSpeed 9;
        };
        _d enableAI "PATH"; _d enableAI "MOVE";
        _d action ["EngineOn", _v];
        _v engineOn true;
        _d doMove _hedef;
        private _w2 = _g addWaypoint [_hedef, 0];
        _w2 setWaypointType "MOVE";
        _w2 setWaypointName "ELITE RECON-ARAC";
        _w2 setWaypointBehaviour "SAFE";
        _w2 setWaypointCombatMode "GREEN";
        _w2 setWaypointSpeed "NORMAL";
        _g setCurrentWaypoint _w2;
    } else {
        private _t = _tur splitString "+";
        if ("BEKLE6" in _t) then { sleep 6; };
        if ("DOSTOP" in _t) then { doStop _d; };
        if ("SAFE" in _t) then {
            _g setBehaviour "SAFE";
            _g setCombatMode "GREEN";
            _g setSpeedMode "NORMAL";
            _v setPilotLight false;
            _v setCollisionLight false;
        };
        if ("FS9" in _t) then { _d forceSpeed 9; };
        if ("DOMOVE" in _t) then {
            _v engineOn true;
            _d doMove _hedef;
        };
        if ("WP" in _t) then {
            private _wp = _g addWaypoint [_hedef, 0];
            _wp setWaypointType "MOVE";
            _wp setWaypointSpeed "FULL";
            _wp setWaypointBehaviour "AWARE";
            _g setCurrentWaypoint _wp;
        };
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
                    // KOLTUK TANISI (hipotez: yolcu varken aracin etkin komutani yolcu grubundan olabilir): dolu murettebat koltuklari, etkin komutan + grubu, surucu aracta mi
                    private _ec = effectiveCommander _v;
                    private _roller = ((fullCrew [_v, "", false]) select {(toLower (_x select 1)) isNotEqualTo "cargo"}) apply { toLower (_x select 1) };
                    _r set ["koltuk", format ["koltuklar %1 | etkin komutan %2 (%3%4) | surucu aracta %5 | murettebat grubu %6", _roller joinString "/", if (isNull _ec) then {"yok"} else {typeOf _ec}, if (isNull _ec) then {"-"} else {groupId (group _ec)}, if (!isNull _ec && {(group _ec) isNotEqualTo (_r get "grup")}) then {" = YOLCU / BASKA GRUP"} else {""}, !isNull _d && {(vehicle _d) isEqualTo _v}, groupId (_r get "grup")]];
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
    private _r = [_cls, true, 0, -3] call _kur;   // serit -3: ana test seritlerinin disinda
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
        _x params ["_kod", "_ad", "_eliteAcik", "_tur", "_yolcuVar", "_yMod"];
        private _r = [_cls, _eliteAcik, _yolcuVar, _serit, _yMod] call _kur;
        _r set ["kod", _kod];
        _r set ["ad", _ad];
        _r set ["tur", _tur];
        _r set ["yolcuN", _yolcuVar];
        _r set ["yMod", _yMod];
        _r set ["eliteAcik", _eliteAcik];
        _kay pushBack _r;
        _serit = _serit + 1;
    } forEach _kodlar;
    _serit = _serit + 1;   // siniflar arasi bosluk
    _ozetler pushBack [_cls, _kay];
} forEach _siniflar;

sleep 4;   // murettebat otursun, izleyiciler (ELITE) gruplari alsin
private _hepsi = [];
{ _hepsi append (_x select 1); } forEach _ozetler;
// orderGetIn ile bindirilen yolcular binsin (en cok 12 sn)
private _tB = time + 12;
waitUntil {
    sleep 0.5;
    time > _tB || {
        private _bekleyen = 0;
        {
            private _rr = _x;
            if ((_rr get "yMod") isEqualTo "ORDERGETIN" && {!isNull (_rr get "pg")}) then {
                _bekleyen = _bekleyen + ({alive _x && {(vehicle _x) isNotEqualTo (_rr get "arac")}} count (units (_rr get "pg")));
            };
        } forEach _hepsi;
        _bekleyen isEqualTo 0
    }
};
{
    if ("BEKLE6" in ((_x get "tur") splitString "+")) then {
        // spawn yerel degiskenleri tasimaz: _emir kodu ve _hedef arguman olarak gecirilir
        [_emir, _x, _x get "tur", _hedef] spawn { params ["_f", "_r", "_t", "_h"]; private _hedef = _h; [_r, _t] call _f; };
    } else {
        [_x, _x get "tur"] call _emir;
    };
} forEach _hepsi;
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
        [format ["[SURUS-AB] %1 | %2 %3 | %4 | %5 sn: %6 m (5. sn %7 m) maks %8 km/s | %9 | yerel arac:%10 surucu:%11 | motor:%12 yakit:%13 canMove:%14 yolcu:%15%16 | %17",
            _cls, _r get "kod", _r get "ad", ["GITMEDI", "GITTI"] select _gitti, _sure, round (_r get "mesafe"), round (_r get "d5"), round (_r get "maks"), _r get "tani5",
            local _v, if (isNull _d) then {"yok"} else {local _d}, isEngineOn _v, (fuel _v) toFixed 2, canMove _v, _r get "yolcu", [format [" | NOT: %1", _r getOrDefault ["not", ""]], ""] select ((_r getOrDefault ["not", ""]) isEqualTo ""), _r getOrDefault ["koltuk", "-"]]] call _yaz;
    } forEach _kay;
    // cikarim
    private _g = { _sonuc getOrDefault [_this, false] };
    private _yorum = "";
    private _reconYorum = "";
    private _safVar = false;
    if (_set isEqualTo 0) then {
    if (_elite && {_yolcu} && {("F" in _sonuc) || {"G" in _sonuc}}) then {
        _reconYorum = switch (true) do {
            case (("C" call _g) && {!("F" call _g)} && {"G" call _g}): { " | RECON: tam profil GITMEDI, hafif GITTI -> forceSpeed 9 / yolcu PATH kapali / ELITE bayraklari (isExecutingTactic, forceMove, senkT) suclu aday." };
            case (("C" call _g) && {!("F" call _g)} && {!("G" call _g)}): { " | RECON: tam VE hafif GITMEDI, C gitti -> SAFE / GREEN / isiksiz / doStop-sonra-doMove sirasi / 4 yolcu suclu aday." };
            case (!("F" call _g) && {!("C" call _g)}): { " | RECON: F de gitmedi ama C de gitmedi -> recon'a ozgu degil, genel ELITE-acik sorunu (bisect)." };
            default { " | RECON: F ve G de GITTI -> recon ayarlari suclu degil; sorun recon'un secim / alma (pickup) asamasinda ya da Zeus'ta yerel yaratma." };
        };
    };
    _safVar = ("A" call _g) || {"B" call _g};
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
    _yorum = _yorum + _reconYorum;
    };
    // ---- belirtec cikarimi (tum setler): basarisiz varyantlarin ORTAK belirteci - calisanlarin hicbirinde olmayan
    private _belirtec = {
        params ["_r"];
        private _t = ((_r get "tur") splitString "+") + [["SAF", "ELITE"] select (_r get "eliteAcik")];
        if ((_r get "yolcuN") > 0) then { _t append [format ["PAX%1", _r get "yolcuN"], format ["PAX-%1", _r get "yMod"]]; };
        _t
    };
    private _basarisiz = _kay select {(_x get "mesafe") < 40};
    private _calisan = _kay select {(_x get "mesafe") >= 40};
    if (_basarisiz isNotEqualTo [] && {_calisan isNotEqualTo []}) then {
        private _ort = [_basarisiz select 0] call _belirtec;
        { _ort = _ort arrayIntersect ([_x] call _belirtec); } forEach _basarisiz;
        private _calT = [];
        { _calT append ([_x] call _belirtec); } forEach _calisan;
        private _suclu = _ort - _calT;
        _yorum = _yorum + format [" | BELIRTEC CIKARIMI: gitmeyenlerde ORTAK ve calisanlarda OLMAYAN = %1 (calisan: %2 | gitmeyen: %3)",
            if (_suclu isEqualTo []) then {"yok (tek bir belirtec acikmiyor, birden cok neden / etkilesim)"} else {_suclu joinString ", "},
            (_calisan apply {_x get "kod"}) joinString "", (_basarisiz apply {_x get "kod"}) joinString ""];
    } else {
        if (_basarisiz isEqualTo []) then { _yorum = _yorum + " | HEPSI GITTI"; };
        if (_calisan isEqualTo []) then { _yorum = _yorum + " | HICBIRI GITMEDI (arac sinifi / mod)"; };
    };
    private _oz = format ["[SURUS-AB-OZET] %1 | %2 | %3", _cls, (_kay apply { format ["%1:%2", _x get "kod", ["X", "G"] select ((_x get "mesafe") >= 40)] }) joinString " ", _yorum];
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
