#include "script_component.hpp"
/*
 * Author: Cinar (ELITE fork)
 * KOMUTAN PLANI (v8.113) — kullanici: "dinamik patrol / arazi tanima / harekat plani / garrison / rally point; waypoint otomatik, Zeus'ta gorunsun; Zeus objektif + 'duşmanda sunlar var / yok' versin; komutan kitaba gore hareket etsin".
 * Kitap (kaynaklar_doktrin/TC_3-21.76 Ranger Handbook, MCWP 3-11.1 / 3-11.2): Troop Leading Procedures (gorevi al, tahmini plan, harekete basla, kesif, plani tamamla, emir ver, denetle), rally point / objective rally point (ORP),
 *   destek (support by fire) + manevra (assault) + yedek (reserve), kanat saldirisi, toparlanma (consolidate and reorganize). SAYISAL ESIKLER (mesafeler, sureler) TASARIM tahminidir, kaynakli degil.
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

// ---------------------------------------------------------------------------
// KATILAN GRUPLAR: taraf, yerel, AI lider, >= 3 asker, baska plana bagli degil, objektife <= 4000 m; en yuksek rutbe + buyuk grup + yakin
// ---------------------------------------------------------------------------
private _grupN = _ayar getOrDefault ["grupN", 4];
private _aday = allGroups select {
    private _l = leader _x;
    !isNull _l && {alive _l} && {local _x} && {!isPlayer _l} && {(side _x) isEqualTo _taraf}
    && {({isPlayer _x} count (units _x)) isEqualTo 0}
    && {({alive _x && {(lifeState _x) in ["HEALTHY", "INJURED"]}} count (units _x)) >= 3}
    && {!(_x getVariable ["lambs_danger_tarafKapali", false])} && {!(_x getVariable ["lambs_danger_planAktif", false])}
    && {isNull objectParent _l} && {(_l distance2D _obj) <= 4000}
};
if (_aday isEqualTo []) exitWith {
    diag_log format ["[PLAN] KURULAMADI: %1 icin uygun grup yok (>= 3 asker, AI, 4000 m icinde, baska planda degil)", _taraf];
    false
};
_aday = [_aday, [], { (rankId (leader _x)) * 1000 + ({alive _x} count (units _x)) * 10 - ((leader _x) distance2D _obj) / 100 }, "DESCEND"] call BIS_fnc_sortBy;
private _gruplar = _aday select [0, _grupN max 1];
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
private _orpM = _ayar getOrDefault ["orpM", 180];
private _rp = [_rallyM, [0, 12, -12, 24, -24, 36, -36]] call _konumSec;
private _orp = [_orpM, [0, 10, -10, 20, -20]] call _konumSec;

// grup rolleri
private _mg = _ayar getOrDefault ["mg", false];
private _bina = _ayar getOrDefault ["bina", false];
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

// kanat noktalari (>= 2 manevra grubu ve MG / bina / sayi >= 8): objektiften 110 m, eksenin +-75 derecesi
private _kanatGerek = _mg || _bina || (_sayi >= 8);
private _kanatNokta = [_obj getPos [110, _B + 75], _obj getPos [110, _B - 75]];

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
    ["SBF", _sbf, "mil_dot", format ["%1 SBF (destek)", _id]]
];

private _plan = createHashMapFromArray [
    ["id", _id], ["taraf", _taraf], ["obj", _obj], ["tip", _tip], ["gruplar", _gruplar], ["roller", _roller], ["komutan", _komutanG],
    ["rp", _rp], ["orp", _orp], ["sbf", _sbf], ["B", _B], ["kanatNokta", _kanatNokta], ["kanatGerek", _kanatGerek],
    ["ayar", _ayar], ["faz", "KUR"], ["fazT", time], ["t0", time], ["isaretler", _isaretler], ["notlar", createHashMap]
];
{ _x setVariable ["lambs_danger_planAktif", true, true]; _x setVariable ["lambs_danger_planId", _id]; } forEach _gruplar;
lambs_danger_planlar set [_id, _plan];

diag_log format ["[PLAN] %1 KURULDU | %2 | %3 | objektif %4 | komutan %5 (%6) | %7 grup: %8 | RP %9 (%10 m) | ORP %11 (%12 m) | SBF %13 | yaklasma ekseni %14 | duşman: piyade:%15 zirh:%16 AT:%17 MG:%18 nisanci:%19 bina:%20 sayi:%21 | kanat gerekli:%22",
    _id, _taraf, ["ELE GECIR", "SAVUN"] select (_tip isEqualTo 1), mapGridPosition _obj, groupId _komutanG, rank (leader _komutanG), _gn,
    _gruplar apply {format ["%1=%2 (%3)", groupId _x, _roller get (groupId _x), {alive _x} count (units _x)]},
    mapGridPosition _rp, round (_rp distance2D _obj), mapGridPosition _orp, round (_orp distance2D _obj), mapGridPosition _sbf, round _B,
    _ayar getOrDefault ["piyade", true], _zirh, _atVar, _mg, _ayar getOrDefault ["nisanci", false], _bina, _sayi, _kanatGerek];
if (_zirh && {!_atVar} && {({([_x] call _destekPuan) >= 3} count _gruplar) isEqualTo 0}) then {
    diag_log format ["[PLAN] %1 UYARI: duşmanda zirh / arac var ama katilan gruplarda AT gucu zayif", _id];
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
