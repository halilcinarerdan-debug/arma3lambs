#include "script_component.hpp"
/*
 * Author: Cinar (ELITE fork)
 * KOMUTAN PLANI (v8.113) — kullanici: "dinamik patrol / arazi tanima / harekat plani / garrison / rally point; waypoint otomatik, Zeus'ta gorunsun; Zeus objektif + 'duşmanda sunlar var / yok' versin; komutan kitaba gore hareket etsin".
 * Kitap (kaynaklar_doktrin/TC_3-21.76 Ranger Handbook, MCWP 3-11.1 / 3-11.2): Troop Leading Procedures (gorevi al, tahmini plan, harekete basla, kesif, plani tamamla, emir ver, denetle), rally point / objective rally point (ORP),
 *   destek (support by fire) + manevra (assault) + yedek (reserve), kanat saldirisi, toparlanma (consolidate and reorganize). SAYISAL ESIKLER: KAYNAKLI = ORP 200-400 m (sinirli gorusta 100-200 m), TC 3-21.76 s. 7-15 / 7-20; rally point nitelikleri (ortulu, yol / akin yolu disi, kisa sure savunulabilir) s. 7-14; DANGER CLOSE <= 600 m + RED mesafeleri (Tablo 3-3) topcu icin. Digerleri (RP mesafesi 450 m, kanat 110 m, SBF 160-300 m, keşif 40 sn, 150 sn bekleme) TASARIM tahminidir, kitapta sayi YOK.
 * ISLEYIS (ELE GECIR): TOPLAN (RP'ye) -> ORP (manevra: ORP, destek: destek noktasi) -> KESIF (40 sn guvenlik) -> SALDIRI (destek ates + manevra [>= 2 grupta kanat noktalari] + hqEmir SALDIRI) -> TOPLANMA (cevre savunmasi + fnc_toparlan) -> BITTI.
 *   SAVUN: TOPLAN -> MEVZI (objektif cevresinde sektorlu halka noktalari; binalar varsa tacticsGarrison) -> BEKLE (sure sinirli).
 * KOMUTAN: katilan gruplar arasinda en yuksek rutbeli lider (esitlikte buyuk grup); >= 3 grupta komutan destek noktasinda (gorus). Roller: DESTEK (MG / AT / nisanci puani en yuksek), MANEVRA, YEDEK.
 * DUSMAN BILGISI (Zeus): piyade / zirh / AT / MG / nisanci / bina + sayi. Kullanim: destek puani (MG, AT [zirh varsa x3]), kanat gerekliligi (MG, bina veya sayi >= 8), loglanan uyarilar (zirh var + AT'li grup yok). HILE YOK: gizli konum okunmaz.
 * CIKTI: gercek waypoint (addWaypoint; "ELITE PLAN: ..." adli; Zeus'ta gorunur ve degistirilebilir) + harita isaretleri (ELITE_PLAN_*). Zeus'un elle koydugu waypoint SILINMEZ (yalniz kendi waypoint'lerimiz).
 * Temas: grup temastaysa plan o grubu zorlamaz (LAMBS / komutan beyni yonetir); temas kesilince plan devam eder.
 * Kapatma: lambs_danger_komutanPlanOff = true.  Log: [PLAN] (KURULDU / FAZ / ROL / BITTI / IPTAL).
 *
 * Arguments:
 * 0: Taraf <SIDE>
 * 1: Objektif pozisyonu <ARRAY>
 * 2: Ayarlar <HASHMAP> (tip 0 ele gecir / 1 savun / 2 iptal, grupN, piyade, zirh, at, mg, nisanci, bina, sayi, rallyM, orpM)
 *
 * Return Value: Plan kuruldu mu <BOOL>
 * Public: No
*/

params [["_taraf", sideUnknown, [sideUnknown]], ["_obj", [0, 0, 0], [[]]], ["_ayar", createHashMap, [createHashMap]]];

if (missionNamespace getVariable ["lambs_danger_komutanPlanOff", false]) exitWith {false};
if (isNil "lambs_danger_planlar") then { lambs_danger_planlar = createHashMap; };

private _tip = _ayar getOrDefault ["tip", 0];

// ---------------------------------------------------------------------------
// IPTAL: bu taraftaki aktif planlari durdur
// ---------------------------------------------------------------------------
if (_tip isEqualTo 2) exitWith {
    private _n = 0;
    {
        private _p = _y;
        if ((_p get "taraf") isEqualTo _taraf) then {
            _p set ["faz", "IPTAL"];
            _n = _n + 1;
        };
    } forEach lambs_danger_planlar;
    diag_log format ["[PLAN] IPTAL: %1 tarafinin %2 plani durduruldu", _taraf, _n];
    _n > 0
};

// ONAY VER: Zeus onayi bekleyen plani baslat
if (_tip isEqualTo 3) exitWith {
    private _n = 0;
    {
        private _p = _y;
        if ((_p get "taraf") isEqualTo _taraf && {_p getOrDefault ["bekleOnay", false]}) then {
            _p set ["bekleOnay", false];
            _n = _n + 1;
        };
    } forEach lambs_danger_planlar;
    diag_log format ["[PLAN] ONAY: %1 tarafinin %2 plani onaylandi", _taraf, _n];
    _n > 0
};

// ---------------------------------------------------------------------------
// KATILAN GRUPLAR: taraf, yerel, AI lider, >= 3 asker, baska plana bagli degil, objektife <= 4000 m; en yuksek rutbe + buyuk grup + yakin
// ---------------------------------------------------------------------------
private _grupN = _ayar getOrDefault ["grupN", 4];
private _aday = allGroups select {
    private _l = leader _x;
    !isNull _l && {alive _l} && {!isPlayer _l} && {(side _x) isEqualTo _taraf}
    && {({isPlayer _x} count (units _x)) isEqualTo 0}
    && {({alive _x && {(lifeState _x) in ["HEALTHY", "INJURED"]}} count (units _x)) >= 3}
    && {!(_x getVariable ["lambs_danger_tarafKapali", false])} && {!(_x getVariable ["lambs_danger_planAktif", false])}
    && {!((_x getVariable ["lambs_danger_gorev", ""]) in ["HARIC", "MEDEVAC", "TOPCU", "TOPCU_YOK", "TASIMA", "KARAKOL_ARAC", "RECON"])}
    && {(_x getVariable ["lambs_danger_garnizonAlt", ""]) isEqualTo ""}
    && {isNull objectParent _l} && {(_l distance2D _obj) <= (_ayar getOrDefault ["grupMesafe", 4000])}
};
if (_aday isEqualTo []) exitWith {
    // v8.121 TANI: her gruptan hangi filtre ilk elediyse say (neden belli olsun)
    private _tum = allGroups select {(side _x) isEqualTo _taraf};
    private _red = createHashMap;
    private _enYakin = 1e9;
    {
        private _l = leader _x;
        private _n = ({alive _x && {(lifeState _x) in ["HEALTHY", "INJURED"]}} count (units _x));
        private _neden = if (isNull _l || {!alive _l}) then {"lider yok / olu"}
            else {if (!local _x) then {"grup bu makinede yerel degil (sahibi baska makine / HC)"}
            else {if (isPlayer _l) then {"lider oyuncu"}
            else {if (({isPlayer _x} count (units _x)) > 0) then {"grupta oyuncu var"}
            else {if (_n < 3) then {"3'ten az saglam asker"}
            else {if (_x getVariable ["lambs_danger_tarafKapali", false]) then {"ELITE bu taraf icin kapali"}
            else {if (_x getVariable ["lambs_danger_planAktif", false]) then {"baska planda"}
            else {if (!isNull objectParent _l) then {"lider aracta"}
            else {if ((_l distance2D _obj) > 4000) then {"objektife > 4000 m"} else {"?"}}}}}}}}};
        _red set [_neden, (_red getOrDefault [_neden, 0]) + 1];
        if (!isNull _l) then { _enYakin = _enYakin min (_l distance2D _obj); };
    } forEach _tum;
    diag_log format ["[PLAN] KURULAMADI: %1 icin uygun grup yok | taraftaki grup:%2 | elenme nedenleri: %3 | objektife en yakin lider: %4 m | sunucu: isServer=%5", _taraf, count _tum, _red toArray false, round _enYakin, isServer];
    false
};
// v8.127: Zeus 'ELITE Gorev Ata' ile MANEVRA / DESTEK / YEDEK atananlar once gelir ve grup sayisi sinirina bakilmaksizin plana girer
private _atanmis = _aday select {(_x getVariable ["lambs_danger_gorev", ""]) in ["MANEVRA", "DESTEK", "YEDEK"]};
_aday = [_aday, [], { ([0, 100000] select ((_x getVariable ["lambs_danger_gorev", ""]) in ["MANEVRA", "DESTEK", "YEDEK"])) + (rankId (leader _x)) * 1000 + ({alive _x} count (units _x)) * 10 - ((leader _x) distance2D _obj) / 100 }, "DESCEND"] call BIS_fnc_sortBy;
private _gruplar = _aday select [0, (_grupN max 1) max (count _atanmis)];
if (_atanmis isNotEqualTo []) then {
    diag_log format ["[PLAN-ATAMA] Zeus atamali gruplar plana alindi: %1", _atanmis apply {format ["%1=%2", groupId _x, _x getVariable ["lambs_danger_gorev", ""]]}];
};
// v8.131 RECON: Zeus 'Gorev Ata -> RECON' gruplari (>= 2 asker) planin KESIF unsuru olur: once gozlem noktasina (OP) sizip bilgi toplar (cogu gizlilik: STEALTH + GREEN), plana rapor verir
private _reconG = allGroups select {
    private _l = leader _x;
    (_x getVariable ["lambs_danger_gorev", ""]) isEqualTo "RECON" && {!isNull _l} && {alive _l} && {!isPlayer _l} && {(side _x) isEqualTo _taraf}
    && {({isPlayer _x} count (units _x)) isEqualTo 0} && {({alive _x} count (units _x)) >= 2} && {isNull objectParent _l}
    && {(_l distance2D _obj) <= (_ayar getOrDefault ["grupMesafe", 4000])} && {!(_x getVariable ["lambs_danger_planAktif", false])}
};
// v8.123: baska makinede (Zeus istemcisi / HC) duran AI gruplari sunucuya devredilir (RPT a5d90e6e: 4 grup yerel degil). Plan komutlari yerel grup ister.
// Oyuncu iceren grup zaten secilmez. Devir 6 sn icinde olmazsa o grup plandan cikar.
if (isServer) then {
    private _uzak = (_gruplar + _reconG) select {!local _x};
    {
        diag_log format ["[PLAN-DEVIR] %1 | sahip makine %2 -> sunucu (2)", groupId _x, groupOwner _x];
        _x setGroupOwner 2;
    } forEach _uzak;
    if (_uzak isNotEqualTo []) then {
        private _t0 = time;
        waitUntil {sleep 0.3; ((_uzak findIf {!local _x}) isEqualTo -1) || {(time - _t0) > 6}};
        private _kalan = _uzak select {!local _x};
        if (_kalan isNotEqualTo []) then {
            diag_log format ["[PLAN-DEVIR] DEVIR OLMADI (plandan cikarildi): %1", _kalan apply {groupId _x}];
            _gruplar = _gruplar - _kalan;
            _reconG = _reconG - _kalan;
        } else {
            diag_log format ["[PLAN-DEVIR] %1 grup sunucuya devredildi (%2 sn)", count _uzak, (time - _t0) toFixed 1];
        };
    };
};
if (_gruplar isEqualTo []) exitWith {
    diag_log "[PLAN] KURULAMADI: secilen gruplarin hicbiri sunucuya devredilemedi";
    false
};
private _komutanG = _gruplar select 0;

// ---------------------------------------------------------------------------
// ARAZI TANIMA: yaklasma ekseni, rally point (RP), ORP, destek noktasi (SBF), kanat noktalari, cevre halkasi
// ---------------------------------------------------------------------------
private _araziFn = missionNamespace getVariable ["lambs_danger_fnc_araziAnaliz", {createHashMap}];
private _mx = 0; private _my = 0;
{ private _p = getPosATL (leader _x); _mx = _mx + (_p select 0); _my = _my + (_p select 1); } forEach _gruplar;
private _merkez = [_mx / (count _gruplar), _my / (count _gruplar), 0];
private _B = _obj getDir _merkez;   // objektiften dost gruplara yon (yaklasma ekseni)

// aday konumlar arasindan en ortulu (olu arazi) / kapali, yol disi, bina disi, su disi nokta
private _konumSec = {
    params ["_d", "_aciListesi"];
    private _en = []; private _enS = -1e9;
    {
        private _a = _x;
        {
            private _p = _obj getPos [_x, _B + _a];
            if (!surfaceIsWater _p && {!isOnRoad _p} && {(nearestObjects [_p, ["House"], 8]) isEqualTo []}) then {
                private _pr = [_p, 30, _obj] call _araziFn;
                private _s = 100 * (_pr getOrDefault ["olu", 0]);
                private _ac = _pr getOrDefault ["aciklik", "KARISIK"];
                _s = _s + ([0, 10, 20] select (((["ACIK", "KARISIK", "KAPALI"]) find _ac) max 0));
                if (_pr getOrDefault ["ufukRisk", false]) then { _s = _s - 25; };
                _s = _s - 0.05 * abs _a - 0.02 * (_p distance2D _merkez);
                if (_s > _enS) then { _enS = _s; _en = _p; };
            };
        } forEach [_d - 40, _d, _d + 40];
    } forEach _aciListesi;
    if (_en isEqualTo []) then { _en = _obj getPos [_d, _B]; };
    _en
};
private _rallyM = _ayar getOrDefault ["rallyM", 450];
private _orpM = _ayar getOrDefault ["orpM", 300];
private _rp = [_rallyM, [0, 12, -12, 24, -24, 36, -36]] call _konumSec;
private _orp = [_orpM, [0, 10, -10, 20, -20]] call _konumSec;

// grup rolleri
private _mg = _ayar getOrDefault ["mg", false];
private _bina = _ayar getOrDefault ["bina", false];
// v8.128: hedef yakininda (200 m) bir KARAKOL kaydi varsa (Zeus 'ELITE Karakol') dusman binali / mevzili sayilir ve loglanir
private _karakolHedef = (missionNamespace getVariable ["lambs_danger_karakollar", []]) select {((_x select 1) distance2D _obj) < 200 && {(_x select 0) isNotEqualTo _taraf}};
if (_karakolHedef isNotEqualTo []) then {
    _bina = true;
    _ayar set ["bina", true];
    diag_log format ["[PLAN] hedef bir KARAKOL: %1 (yaricap %2 m) -> duşman binali / mevzili sayildi", (_karakolHedef select 0) select 3, (_karakolHedef select 0) select 2];
};
private _zirh = _ayar getOrDefault ["zirh", false];
private _atVar = _ayar getOrDefault ["at", false];
private _sayi = _ayar getOrDefault ["sayi", 0];
private _rolFn = missionNamespace getVariable ["lambs_danger_fnc_getUnitRole", {"RIFLE"}];
private _destekPuan = {
    params ["_g"];
    private _s = 0;
    {
        private _r = [_x] call _rolFn;
        if (_r isEqualTo "MG") then { _s = _s + 3; };
        if (_r isEqualTo "AT") then { _s = _s + ([1, 3] select _zirh); };
        if (_r isEqualTo "MARKSMAN") then { _s = _s + 2; };
    } forEach ((units _g) select {alive _x});
    _s
};
private _roller = createHashMap;
private _gn = count _gruplar;
if (_gn isEqualTo 1) then {
    _roller set [groupId _komutanG, "MANEVRA"];
} else {
    // destek: puani en yuksek grup; >= 3 grupta komutan destek noktasinda (gorus) — komutan grubunun puani yakinsa o
    private _sirali = [_gruplar, [], {[_x] call _destekPuan}, "DESCEND"] call BIS_fnc_sortBy;
    private _destekG = _sirali select 0;
    if (_gn >= 3 && {([_komutanG] call _destekPuan) >= (([_destekG] call _destekPuan) - 2)}) then { _destekG = _komutanG; };
    {
        private _g = _x;
        _roller set [groupId _g, ["MANEVRA", "DESTEK"] select (_g isEqualTo _destekG)];
    } forEach _gruplar;
    // 4+ grupta bir manevra grubu yedek
    if (_gn >= 4) then {
        private _manev = _gruplar select {(_roller get (groupId _x)) isEqualTo "MANEVRA"};
        if (count _manev >= 3) then { _roller set [groupId (_manev select -1), "YEDEK"]; };
    };
};

// v8.127: Zeus atamasi rolu ezer (MANEVRA / DESTEK / YEDEK)
{
    private _ga = _x getVariable ["lambs_danger_gorev", ""];
    if (_ga in ["MANEVRA", "DESTEK", "YEDEK"]) then {
        if ((_roller getOrDefault [groupId _x, ""]) isNotEqualTo _ga) then {
            diag_log format ["[PLAN-ATAMA] %1 rolu %2 -> %3 (Zeus atamasi)", groupId _x, _roller getOrDefault [groupId _x, "?"], _ga];
        };
        _roller set [groupId _x, _ga];
    };
} forEach _gruplar;

// destek noktasi (SBF): dusman gozetlenen, objektife arazi gorusu olan, dost eksenin yanlarinda yuksek nokta
private _sbf = [];
private _sbfS = -1e9;
private _hObj = getTerrainHeightASL _obj;
private _gozObj = AGLToASL (_obj vectorAdd [0, 0, 1.5]);
{
    private _a = _x;
    {
        private _p = _obj getPos [_x, _B + _a];
        if (!surfaceIsWater _p && {(nearestObjects [_p, ["House"], 8]) isEqualTo []}) then {
            if (!(terrainIntersectASL [AGLToASL (_p vectorAdd [0, 0, 1.2]), _gozObj])) then {
                private _s = ((getTerrainHeightASL _p) - _hObj) + 40 - 0.03 * (_p distance2D _rp) - ([0, 15] select (abs _a < 40));
                if (_s > _sbfS) then { _sbfS = _s; _sbf = _p; };
            };
        };
    } forEach [160, 230, 300];
} forEach [35, 55, 80, 105, -35, -55, -80, -105];
if (_sbf isEqualTo []) then { _sbf = _obj getPos [220, _B + 70]; };

// v8.131 RECON gozlem noktasi (OP): objektife 450-600 m (tufek etkili menzili 460 m civari: gozlem, temas degil), objektifi gorebilen, yuksek, bitki / kaya orten
private _op = [];
if (_reconG isNotEqualTo []) then {
    private _opS = -1e9;
    {
        private _a = _x;
        {
            private _p = _obj getPos [_x, _B + _a];
            if (!surfaceIsWater _p && {!isOnRoad _p} && {(nearestObjects [_p, ["House"], 12]) isEqualTo []}) then {
                if (!(terrainIntersectASL [AGLToASL (_p vectorAdd [0, 0, 0.8]), _gozObj])) then {
                    private _s = 1.5 * ((getTerrainHeightASL _p) - _hObj) + 2 * (count (nearestTerrainObjects [_p, ["TREE", "BUSH", "ROCK", "ROCKS"], 14])) - 0.2 * abs _a - 0.02 * (_x - 450);
                    if (_s > _opS) then { _opS = _s; _op = _p; };
                };
            };
        } forEach [450, 520, 600];
    } forEach [-45, -25, 0, 25, 45];
    if (_op isEqualTo []) then { _op = _obj getPos [500, _B]; };
};

// kanat noktalari (>= 2 manevra grubu ve MG / bina / sayi >= 8): objektiften 110 m, eksenin +-75 derecesi
private _kanatGerek = _mg || _bina || (_sayi >= 8);
private _kanatNokta = [_obj getPos [110, _B + 75], _obj getPos [110, _B - 75]];

// ---------------------------------------------------------------------------
// MANUEL NOKTALAR (Zeus 'ELITE Plan Noktasi'): komutan hesapladigi noktalar yerine Zeus'un sectigini KULLANIR (emri uygular, itiraz etmez); sistem yalniz [PLAN-UYARI] loglar (tarihsel canlandirma: 'ne olurdu?')
// ---------------------------------------------------------------------------
private _manuel = missionNamespace getVariable ["lambs_danger_planManuel", createHashMap];
private _uyarilar = [];
private _manuelAd = [];
private _uyar = {
    params ["_ad", "_metin"];
    _uyarilar pushBack format ["%1: %2", _ad, _metin];
    diag_log format ["[PLAN-UYARI] %1 | %2", _ad, _metin];
};
private _gorunur = { params ["_p"]; !(terrainIntersectASL [AGLToASL (_p vectorAdd [0, 0, 1.2]), AGLToASL (_obj vectorAdd [0, 0, 1.5])]) };
private _ccp = _rp getPos [25, _B + 90];
{
    private _tip2 = _x;
    private _p = _manuel getOrDefault [format ["%1|%2", _taraf, _tip2], []];
    if (_p isNotEqualTo []) then {
        _manuelAd pushBack _tip2;
        private _d = _p distance2D _obj;
        switch (_tip2) do {
            case "RP": {
                _rp = _p;
                if (_d < 250) then { ["RP", format ["objektife cok yakin (%1 m < 250 m): ates / gorus altinda toplanma", round _d]] call _uyar; };
                if ([_p] call _gorunur) then { ["RP", "objektiften GORUNUR (arazi gorusu var)"] call _uyar; };
                if (isOnRoad _p) then { ["RP", "yol uzerinde (pusu / IED riski)"] call _uyar; };
                private _pr = [_p, 30, _obj] call _araziFn;
                if ((_pr getOrDefault ["olu", 1]) < 0.3) then { ["RP", format ["acik arazide (olu arazi orani %1)", (_pr getOrDefault ["olu", 0]) toFixed 2]] call _uyar; };
            };
            case "ORP": {
                _orp = _p;
                // KAYNAK TC 3-21.76 s. 7-15 / 7-20: ORP tipik 200-400 m (sinirli gorusta 100-200 m); ses ve gorus disinda
                private _sinirliGorus = (sunOrMoon < 0.15) || {fog > 0.4};
                private _alt = [200, 100] select _sinirliGorus;
                if (_d < _alt) then { ["ORP", format ["kitap ORP mesafesinin altinda (%1 m < %2 m, %3)", round _d, _alt, ["iyi gorus", "sinirli gorus"] select _sinirliGorus]] call _uyar; };
                if (_d > 400) then { ["ORP", format ["kitap ORP mesafesinin ustunde (%1 m > 400 m): objektife gec yetisilir / baglanti kopar", round _d]] call _uyar; };
                if ([_p] call _gorunur) then { ["ORP", "objektiften GORUNUR"] call _uyar; };
            };
            case "SBF": {
                _sbf = _p;
                if !([_p] call _gorunur) then { ["SBF", "destek noktasinin objektife arazi GORUSU YOK (ates veremez)"] call _uyar; };
                if (_d < 100) then { ["SBF", format ["objektife cok yakin (%1 m)", round _d]] call _uyar; };
                if (_d > 460) then { ["SBF", format ["tufek etkili menzili disinda (%1 m > 460 m, MCWP 3-11.2: M16 etkili menzil 460 m; MG 600-1100 m ayri)", round _d]] call _uyar; };
            };
            case "KANAT1": { _kanatNokta set [0, _p]; if (_d < 60) then { ["KANAT1", format ["objektife cok yakin (%1 m)", round _d]] call _uyar; }; };
            case "KANAT2": { _kanatNokta set [1, _p]; if (_d < 60) then { ["KANAT2", format ["objektife cok yakin (%1 m)", round _d]] call _uyar; }; };
            case "CCP": {
                _ccp = _p;
                if ([_p] call _gorunur) then { ["CCP", "yarali toplama noktasi objektiften GORUNUR"] call _uyar; };
            };
        };
        _manuel deleteAt (format ["%1|%2", _taraf, _tip2]);
        deleteMarker (format ["ELITE_MANUEL_%1_%2", _taraf, _tip2]);
        diag_log format ["[PLAN-MANUEL] %1 | %2 = MANUEL nokta kullanildi (%3, objektife %4 m)", _taraf, _tip2, mapGridPosition _p, round _d];
    };
} forEach ["RP", "ORP", "SBF", "KANAT1", "KANAT2", "CCP"];
if !("CCP" in _manuelAd) then { _ccp = _rp getPos [25, _B + 90]; };
// destek noktasi ile kanat noktasi ayni hat uzerinde ise dost atesi riski
if ("SBF" in _manuelAd || {"KANAT1" in _manuelAd} || {"KANAT2" in _manuelAd}) then {
    {
        private _kn = _x;
        if (abs ((((_obj getDir _sbf) - (_obj getDir _kn)) + 540) mod 360 - 180) < 25) then {
            ["SBF/KANAT", "destek noktasi ile kanat noktasi AYNI ates hattinda (dost atesi riski, < 25 derece)"] call _uyar;
        };
    } forEach _kanatNokta;
};

// ---------------------------------------------------------------------------
// PLAN KAYDI
// ---------------------------------------------------------------------------
if (isNil "lambs_danger_planSay") then { lambs_danger_planSay = 0; };
lambs_danger_planSay = lambs_danger_planSay + 1;
private _id = format ["P%1", lambs_danger_planSay];
private _renk = switch (_taraf) do { case west: {"ColorBLUFOR"}; case east: {"ColorOPFOR"}; default {"ColorIndependent"} };
private _isaretler = [];
{
    _x params ["_ad", "_pos", "_tur", "_metin"];
    private _m = createMarker [format ["ELITE_PLAN_%1_%2", _id, _ad], _pos];
    _m setMarkerType _tur;
    _m setMarkerColor _renk;
    _m setMarkerText _metin;
    _isaretler pushBack _m;
} forEach [
    ["OBJ", _obj, "mil_objective", format ["%1 OBJ", _id]],
    ["RP", _rp, "mil_start", format ["%1 RP", _id]],
    ["ORP", _orp, "mil_triangle", format ["%1 ORP", _id]],
    ["SBF", _sbf, "mil_dot", format ["%1 SBF (destek)", _id]],
    ["CCP", _ccp, "mil_pickup", format ["%1 CCP (yarali toplama)", _id]]
];
// yarali toplama noktasi (CCP): rally point'in yaninda; araçli medevac buraya tasir
if (isNil "lambs_danger_planCCPlar") then { lambs_danger_planCCPlar = []; };
lambs_danger_planCCPlar pushBack [_id, _taraf, _ccp];

if (_reconG isNotEqualTo []) then {
    diag_log format ["[PLAN-RECON] %1 | recon %2 grup: %3 | gozlem noktasi OP %4 (objektiften %5 m)", _id, count _reconG, _reconG apply {groupId _x}, mapGridPosition _op, round (_op distance2D _obj)];
    { _x setVariable ["lambs_danger_planAktif", true, true]; } forEach _reconG;
};
private _plan = createHashMapFromArray [
    ["id", _id], ["taraf", _taraf], ["obj", _obj], ["tip", _tip], ["gruplar", _gruplar], ["roller", _roller], ["komutan", _komutanG],
    ["rp", _rp], ["orp", _orp], ["sbf", _sbf], ["B", _B], ["kanatNokta", _kanatNokta], ["kanatGerek", _kanatGerek],
    ["ayar", _ayar], ["tempo", ([_ayar getOrDefault ["tempo", 0], 1] select (((_ayar getOrDefault ["baskin", 0]) > 0 || {(_ayar getOrDefault ["guven", 1]) isEqualTo 0}) && {(_ayar getOrDefault ["tempo", 0]) isEqualTo 0}))], ["baslaT", time + ([0, 30, 60, 120, 300, 0] select ((_ayar getOrDefault ["basla", 0]) min 5))], ["bekleOnay", (_ayar getOrDefault ["basla", 0]) isEqualTo 5],
    ["sureSn", [0, 600, 1200, 1800, 2700] select ((_ayar getOrDefault ["sure", 0]) min 4)], ["tehditB", [-1, 0, 45, 90, 135, 180, 225, 270, 315] select ((_ayar getOrDefault ["tehditY", 0]) min 8)],
    ["baskinS", [0, 300, 600] select ((_ayar getOrDefault ["baskin", 0]) min 2)], ["sivil", _ayar getOrDefault ["sivil", false]], ["agirYasak", _ayar getOrDefault ["agirYasak", false]], ["topcu", _ayar getOrDefault ["topcu", 0]], ["topcuN", _ayar getOrDefault ["topcuN", 4]],
    ["guven", _ayar getOrDefault ["guven", 1]], ["dogrulama", _ayar getOrDefault ["dogrulama", 0]], ["iddiaSayi", _ayar getOrDefault ["sayi", 0]], ["atislar", []], ["reconG", _reconG], ["op", _op], ["faz", "KUR"], ["fazT", time], ["t0", time], ["isaretler", _isaretler], ["notlar", createHashMap], ["uyarilar", _uyarilar], ["manuelNoktalar", _manuelAd]
];
{
    _x setVariable ["lambs_danger_planAktif", true, true];
    _x setVariable ["lambs_danger_planId", _id];
    _x setVariable ["lambs_danger_agirYasak", _ayar getOrDefault ["agirYasak", false]];
} forEach _gruplar;
lambs_danger_planlar set [_id, _plan];

diag_log format ["[PLAN] %1 KURULDU | %2 | %3 | objektif %4 | komutan %5 (%6) | %7 grup: %8 | RP %9 (%10 m) | ORP %11 (%12 m) | SBF %13 | yaklasma ekseni %14 | duşman: piyade:%15 zirh:%16 AT:%17 MG:%18 nisanci:%19 bina:%20 sayi:%21 | kanat gerekli:%22 | tempo:%23 | H-saati:%24 | sure sinir:%25 sn | tehdit yonu:%26 | siviller:%27 agir silah yasak:%28 | topcu:%29",
    _id, _taraf, ["ELE GECIR", "SAVUN"] select (_tip isEqualTo 1), mapGridPosition _obj, groupId _komutanG, rank (leader _komutanG), _gn,
    _gruplar apply {format ["%1=%2 (%3)", groupId _x, _roller get (groupId _x), {alive _x} count (units _x)]},
    mapGridPosition _rp, round (_rp distance2D _obj), mapGridPosition _orp, round (_orp distance2D _obj), mapGridPosition _sbf, round _B,
    _ayar getOrDefault ["piyade", true], _zirh, _atVar, _mg, _ayar getOrDefault ["nisanci", false], _bina, _sayi, _kanatGerek,
    ["dengeli", "sessiz / gizli", "hizli / agresif"] select ((_ayar getOrDefault ["tempo", 0]) min 2),
    ["hemen", "30 sn", "60 sn", "120 sn", "300 sn", "ZEUS ONAYI BEKLENIYOR"] select ((_ayar getOrDefault ["basla", 0]) min 5),
    _plan get "sureSn", [_plan get "tehditB", "bilinmiyor"] select ((_plan get "tehditB") < 0), _plan get "sivil", _plan get "agirYasak",
    ["yok", "hazirlik", "cagri", "hazirlik + cagri"] select ((_ayar getOrDefault ["topcu", 0]) min 3)];
if (_zirh && {!_atVar} && {({([_x] call _destekPuan) >= 3} count _gruplar) isEqualTo 0}) then {
    diag_log format ["[PLAN] %1 UYARI: duşmanda zirh / arac var ama katilan gruplarda AT gucu zayif", _id];
};
// v8.131: topcu envanteri (kullanici: "artilleryden tik yok") — plan kurulurken tarafin topcu araclarini ve atisa uygunlugunu logla
if ((_ayar getOrDefault ["topcu", 0]) > 0) then {
    private _tAr = vehicles select {(side (group _x)) isEqualTo _taraf || {(side _x) isEqualTo _taraf}} select {(getNumber (configOf _x >> "artilleryScanner")) > 0};
    if (_tAr isEqualTo []) then {
        diag_log format ["[PLAN-TOPCU] %1 | ENVANTER: %2 tarafinda artilleryScanner'li arac YOK (topcu / havan araci eksik ya da taraf farkli; Zeus'ta tarafi kontrol edin)", _id, _taraf];
    } else {
        {
            private _v = _x;
            private _m = (getArtilleryAmmo [_v]) param [0, ""];
            diag_log format ["[PLAN-TOPCU] %1 | ENVANTER: %2 | gunner:%3 (oyuncu:%4) | yerel:%5 | canFire:%6 | mermi:%7 | hedef menzilde:%8 | Zeus:%9",
                _id, typeOf _v, [name (gunner _v), "YOK"] select (isNull (gunner _v)), isPlayer (gunner _v), local _v, canFire _v, _m,
                ["?", _obj inRangeOfArtillery [[_v], _m]] select (_m isNotEqualTo ""), _v getVariable ["lambs_danger_gorev", ""]];
        } forEach _tAr;
    };
};
if (_zirh && {_tip isEqualTo 0}) then { diag_log format ["[PLAN] %1 NOT: zirh var -> saldirida AT'li grup destek tarafina oncelik verildi (destek puani AT x3)", _id]; };

// dongu (bir kez baslar, hata olursa bekci yeniden baslatir)
if (isNil "lambs_danger_planDonguStarted") then {
    lambs_danger_planDonguStarted = true;
    private _dongu = missionNamespace getVariable ["lambs_danger_fnc_komutanPlanDongu", {}];
    [_dongu] spawn {
        params ["_fn"];
        while {true} do {
            private _h = [] spawn _fn;
            waitUntil { sleep 5; scriptDone _h };
            diag_log format ["[WATCHDOG-YENIDEN] komutanPlan dongusu sonlandi (hata?), son adim: %1", missionNamespace getVariable ["lambs_danger_planAdim", "?"]];
            sleep 5;
        };
    };
};

true
