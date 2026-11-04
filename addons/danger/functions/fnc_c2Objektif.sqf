#include "script_component.hpp"
/*
 * Author: Cinar (ELITE fork)
 * C2 SUNUCU: MENUDEN OBJEKTIF VER (v8.392; kullanici: 'menuden objektif verebilelim'). Zeus 'ELITE Objektif' modulunun (fnc_moduleObjektif -> fnc_komutanPlan) sade karsiligi: oyuncu komutan haritadan objektif noktasi secer.
 *   ELE        : ELE GECIR plani. Komuta noktasi (HQ / US) ZORUNLU (planlayici kurali): komutanin tarafinda squad atanmis HQ varsa objektife EN YAKIN olani secilir; yoksa reddedilir (Zeus: 'ELITE HQ / US Kur' + squad ata).
 *                Katilan gruplar: o HQ'ya atanmis squadlar (sayi CBA c2ObjGrupN, rutbe + buyukluk + yakinlik), oyuncu komutasindaki / planli gruplar haric.
 *   SAVUN      : SAVUN plani (mevzilen); HQ gerekmez; gruplar otomatik (CBA c2ObjGrupN, objektife <= 4000 m).
 *   SECILI_SAVUN: haritada secilen TEK bot grubu objektifi savunur ('secili' grup; grup oyuncu komutasindaysa once serbest birakilir, C2 waypoint'leri silinir).
 *   IPTAL      : komutanin tarafindaki TUM aktif objektif planlari durdurulur (HQ'li planda gruplar HQ'ya doner).
 *   DURUM      : aktif planlar (id, tip, faz, grup sayisi, GRID).
 * Duşman bilgisi / H-saati / topcu / zincir gibi Zeus ayrintilari menude YOK (varsayilan: dengeli tempo, hemen basla, sinirsiz sure, topcu yok, dogrulama tam kesif); bunlar icin Zeus modulu kullanilir.
 * Cakisma: ayni noktada (150 m) ayni turde plan komutanPlan'da engellenir; plana alinan gruplar C2 emri almaz (fnc_c2Emir); C2 emri altindaki gruplar plana alinmaz (fnc_komutanPlan, v8.392).
 * Gonderen dogrulamasi: remoteExecutedOwner = gozlemci biriminin sahibi. Oyuncu basina 20 sn bekleme (kurma istekleri). Log: [C2-OBJ].
 *
 * Arguments:
 * 0: Kod <STRING> ("ELE" / "SAVUN" / "SECILI_SAVUN" / "IPTAL" / "DURUM")
 * 1: Objektif konumu <ARRAY> (IPTAL / DURUM icin [])
 * 2: Gozlemci (komutan oyuncu) <OBJECT>
 * 3: Grup netId <STRING> (yalniz SECILI_SAVUN)
 *
 * Return Value: None
 * Public: No
*/

params [["_kod", "", [""]], ["_poz", [], [[]]], ["_obs", objNull, [objNull]], ["_gNid", "", [""]]];
if (!isServer) exitWith {};

private _gon = remoteExecutedOwner;
if (_gon isEqualTo 0) then { _gon = clientOwner; };

private _bildir = {
    params ["_m"];
    [format ["[C2] OBJEKTIF: %1", _m]] remoteExecCall ["systemChat", _gon];
    diag_log format ["[C2-OBJ] %1 | %2", name _obs, _m];
};

if (isNull _obs || {!isPlayer _obs} || {(owner _obs) isNotEqualTo _gon}) exitWith {
    diag_log format ["[C2-OBJ] RED: gonderen / gozlemci uyusmuyor (gonderen %1)", _gon];
};
if (!([_obs, false] call FUNC(c2Yetkili))) exitWith { ["Yetkin yok (grup lideri / komutan degiskeni)."] call _bildir; };
if !(_kod in ["ELE", "SAVUN", "SECILI_SAVUN", "IPTAL", "DURUM"]) exitWith { [format ["Gecersiz kod: %1", _kod]] call _bildir; };

private _taraf = side (group _obs);
private _planlar = if (isNil "lambs_danger_planlar") then {[]} else {(values lambs_danger_planlar) select {(_x getOrDefault ["taraf", sideUnknown]) isEqualTo _taraf}};

if (_kod isEqualTo "DURUM") exitWith {
    private _aktif = _planlar select {!((_x getOrDefault ["faz", ""]) in ["BITTI", "IPTAL"])};
    if (_aktif isEqualTo []) then {
        ["Aktif objektif plani yok."] call _bildir;
    } else {
        {
            [format ["%1 | %2 | faz %3 | %4 grup | GRID %5", _x getOrDefault ["id", "?"], ["ELE GECIR", "SAVUN"] select ((_x getOrDefault ["tip", 0]) isEqualTo 1), _x getOrDefault ["faz", "?"], count (_x getOrDefault ["gruplar", []]), mapGridPosition (_x getOrDefault ["obj", [0, 0, 0]])]] call _bildir;
        } forEach (_aktif select [0, 6 min (count _aktif)]);
    };
};

if (_kod isEqualTo "IPTAL") exitWith {
    private _r = [_taraf, [0, 0, 0], createHashMapFromArray [["tip", 2]]] call FUNC(komutanPlan);
    [if (_r isEqualTo true) then {"Aktif objektif planlari durduruldu (HQ'li planda gruplar HQ'ya doner)."} else {"Iptal edilecek aktif plan yok."}] call _bildir;
};

// ---- kurma istekleri ----
private _bekle = 20 - (time - (_obs getVariable [QGVAR(c2ObjT), -999]));
if (_bekle > 0) exitWith { [format ["Bekleme: %1 sn", ceil _bekle]] call _bildir; };
if (count _poz < 2 || {!((_poz select 0) isEqualType 0)} || {!((_poz select 1) isEqualType 0)}) exitWith { ["Gecersiz objektif konumu."] call _bildir; };
_poz = [_poz select 0, _poz select 1, 0];
if (surfaceIsWater _poz) exitWith { ["Objektif suda; konum gecersiz."] call _bildir; };

private _tip = if (_kod isEqualTo "ELE") then {0} else {1};
private _hqId = "";
if (_tip isEqualTo 0) then {
    private _hqL = (missionNamespace getVariable ["lambs_danger_hqListe", []]) select {(_x select 1) isEqualTo (str _taraf) && {(_x select 5) > 0}};
    if (_hqL isNotEqualTo []) then {
        _hqL = [_hqL, [], {(_x select 3) distance2D _poz}, "ASCEND"] call BIS_fnc_sortBy;
        _hqId = (_hqL select 0) select 0;
    };
};
if (_tip isEqualTo 0 && {_hqId isEqualTo ""}) exitWith {
    ["ELE GECIR icin komuta noktasi (HQ / US) gerekir ve squad atanmis olmali (Zeus: 'ELITE HQ / US Kur' + squad ata). Alternatif: SAVUN."] call _bildir;
};

private _ayar = createHashMapFromArray [
    ["hqId", _hqId], ["tip", _tip], ["grupN", missionNamespace getVariable ["lambs_danger_c2ObjGrupN", 3]], ["tumHQ", false], ["tumHQGuvenlik", false],
    ["piyade", true], ["zirh", false], ["at", false], ["mg", false], ["nisanci", false], ["bina", false], ["sayi", 0],
    ["rallyM", 450], ["orpM", 300], ["baskin", 0], ["guven", 1], ["dogrulama", 0], ["tempo", 0], ["basla", 0], ["sure", 0], ["tehditY", 0],
    ["sivil", false], ["agirYasak", false], ["topcu", 0], ["topcuN", 4], ["topcuBasit", 0], ["zincir", false], ["reconEk", false], ["tut", 1], ["dronAvi", 0], ["otoGarnizon", 0],
    ["rpIsaret", ""], ["mevziYar", 500], ["oranEsik", 2]
];

private _secAd = "otomatik";
if (_kod isEqualTo "SECILI_SAVUN") then {
    private _g = groupFromNetId _gNid;
    if (isNull _g || {isNull (leader _g)} || {({alive _x} count (units _g)) isEqualTo 0}) exitWith { ["Secilen grup bulunamadi / hepsi olu."] call _bildir; };
    if ((side _g) isNotEqualTo _taraf) exitWith { ["Secilen grup senin tarafinda degil."] call _bildir; };
    if (_g getVariable ["lambs_danger_planAktif", false]) exitWith { [format ["%1 zaten bir objektif planinda (%2).", groupId _g, _g getVariable ["lambs_danger_planId", "?"]]] call _bildir; };
    // oyuncu komutasindan cikar (planlayici bu gruplari almaz); C2 waypoint'leri grup sahibinde silinir
    _g setVariable ["lambs_danger_oyuncuKomuta", nil, true];
    [_g, "SERBEST", []] remoteExecCall ["lambs_danger_fnc_c2EmirUygula", groupOwner _g];
    _ayar set ["secili", [netId _g]];
    _ayar set ["grupN", 1];
    _secAd = groupId _g;
};
if (_kod isEqualTo "SECILI_SAVUN" && {(_ayar getOrDefault ["secili", []]) isEqualTo []}) exitWith {};

_obs setVariable [QGVAR(c2ObjT), time];
[format ["%1 istegi: %2 | GRID %3 | grup: %4%5", ["ELE GECIR", "SAVUN"] select (_tip isEqualTo 1), _kod, mapGridPosition _poz, _secAd, if (_hqId isEqualTo "") then {""} else {format [" | HQ %1", _hqId]}]] call _bildir;

[_taraf, _poz, _ayar, _gon, _kod] spawn {
    params ["_t", "_p", "_a", "_o", "_k"];
    private _r = [_t, _p, _a] call (missionNamespace getVariable ["lambs_danger_fnc_komutanPlan", {false}]);
    private _neden = if (_r isEqualTo true) then {""} else { missionNamespace getVariable ["lambs_danger_planRedNeden", ""] };
    missionNamespace setVariable ["lambs_danger_planRedNeden", ""];
    private _m = if (_r isEqualTo true) then {
        format ["PLAN KURULDU (%1, GRID %2): haritada ELITE_PLAN isaretleri + grup waypoint'leri; durum icin menuden 'Durum'", _k, mapGridPosition _p]
    } else {
        format ["KURULAMADI: %1", if (_neden isNotEqualTo "") then {_neden} else {"uygun grup yok (en az 3 canli AI asker, ELITE bu taraf icin acik, objektife <= 4000 m, baska planda ya da oyuncu komutasinda degil)"}]
    };
    [format ["[C2] OBJEKTIF: %1", _m]] remoteExecCall ["systemChat", _o];
    diag_log format ["[C2-OBJ] sonuc | %1 | %2 | %3", _k, mapGridPosition _p, _m];
};
