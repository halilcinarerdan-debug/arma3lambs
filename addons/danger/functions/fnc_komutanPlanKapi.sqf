#include "script_component.hpp"
/*
 * Author: Cinar (ELITE fork)
 * KOMUTAN PLANI SUNUCU KAPISI (v8.116) — Zeus modulleri CURATOR'UN makinesinde calisir; gruplar ise SUNUCUDA yereldir. Planlayici yerel gruplari kullandigi icin
 * dedicated / listen (Zeus istemcide) sunucuda plan 'uygun grup yok' diyerek kurulamazdi. Moduller artik CBA sunucu olayi gonderir; bu kapi sunucuda dinler ve plani sunucuda kurar.
 *   lambs_danger_planIstegi      [taraf, objektif, ayar (HashMap -> [[anahtar, deger]])]
 *   lambs_danger_planNoktaIstegi [taraf, nokta adi, pozisyon ya da []]  (manuel plan noktasi ekle / sil)
 * Log: [PLAN-KAPI]
 *
 * Arguments: None
 * Return Value: Baslatildi mi <BOOL>
 * Public: No
*/

if (!isNil "lambs_danger_planKapiStarted") exitWith {false};
lambs_danger_planKapiStarted = true;

["lambs_danger_planIstegi", {
    params ["_taraf", "_obj", "_ayarCiftler"];
    if (!isServer) exitWith {};
    diag_log format ["[PLAN-KAPI] plan istegi alindi (sunucu): %1 | %2", _taraf, mapGridPosition _obj];
    // v8.121: sonuc tum makinelere bildirilir (Zeus ekraninda systemChat); istemci RPT'sinde de gorunur
    [_taraf, _obj, _ayarCiftler] spawn {
        params ["_taraf", "_obj", "_ayarCiftler"];
        private _ayar = createHashMapFromArray _ayarCiftler;
        private _r = [_taraf, _obj, _ayar] call (missionNamespace getVariable ["lambs_danger_fnc_komutanPlan", {false}]);
        ["lambs_danger_planYanit", [_taraf, _ayar getOrDefault ["tip", 0], _r isEqualTo true]] call CBA_fnc_globalEvent;
    };
}] call CBA_fnc_addEventHandler;

// v8.121: sunucudan donen yanit (her makinede; yalniz arayuzu olan gosterir)
["lambs_danger_planYanit", {
    params ["_taraf", "_tip", "_ok"];
    if (!hasInterface) exitWith {};
    private _m = switch (_tip) do {
        case 2: { ["IPTAL: aktif plan yok", "IPTAL: plan durduruldu"] select _ok };
        case 3: { ["ONAY: bekleyen plan yok", "ONAY: plan baslatildi"] select _ok };
        default { ["PLAN KURULAMADI: uygun grup yok (en az 3 canli AI asker, o taraf icin ELITE acik, objektife <= 4000 m, baska planda degil)", "PLAN KURULDU (haritada ELITE_PLAN isaretleri + grup waypoint'leri)"] select _ok };
    };
    diag_log format ["[PLAN-YANIT] %1 | %2", _taraf, _m];
    if (!isNull (getAssignedCuratorLogic player)) then { systemChat format ["[ELITE] %1", _m]; };
}] call CBA_fnc_addEventHandler;

["lambs_danger_planNoktaIstegi", {
    params ["_taraf", "_ad", "_poz"];
    if (!isServer) exitWith {};
    if (isNil "lambs_danger_planManuel") then { lambs_danger_planManuel = createHashMap; };
    private _anahtar = format ["%1|%2", _taraf, _ad];
    private _mn = format ["ELITE_MANUEL_%1_%2", _taraf, _ad];
    if (_poz isEqualTo []) then {
        lambs_danger_planManuel deleteAt _anahtar;
        deleteMarker _mn;
    } else {
        lambs_danger_planManuel set [_anahtar, _poz];
        deleteMarker _mn;
        createMarker [_mn, _poz];
        _mn setMarkerType "mil_destroy";
        _mn setMarkerColor (switch (_taraf) do { case west: {"ColorBLUFOR"}; case east: {"ColorOPFOR"}; default {"ColorIndependent"} });
        _mn setMarkerText format ["MANUEL %1", _ad];
    };
    diag_log format ["[PLAN-MANUEL] %1 | %2 | %3", _taraf, _ad, ["SILINDI", format ["konuldu: %1 (sonraki Objektif planinda kullanilir)", mapGridPosition _poz]] select (_poz isNotEqualTo [])];
}] call CBA_fnc_addEventHandler;

// v8.127: Zeus 'ELITE Gorev Ata' -> sunucu degiskeni yazar (grup + varsa arac)
["lambs_danger_gorevAta", {
    params ["_hedef", "_kod"];
    if (!isServer || {isNull _hedef}) exitWith {};
    private _g = if (_hedef isEqualType grpNull) then {_hedef} else {group (effectiveCommander _hedef)};
    private _nesneler = [];
    if (!(_hedef isEqualType grpNull) && {!(_hedef isKindOf "CAManBase")}) then { _nesneler pushBack _hedef; };
    if (_hedef isKindOf "CAManBase" && {!isNull objectParent _hedef}) then { _nesneler pushBack (vehicle _hedef); };
    if (!isNull _g) then { _nesneler pushBack _g; };
    { _x setVariable ["lambs_danger_gorev", _kod, true]; } forEach _nesneler;
    diag_log format ["[GOREV-ATAMA] %1 -> %2 (nesne: %3)", [groupId _g, "-"] select (isNull _g), ["TEMIZLENDI", _kod] select (_kod isNotEqualTo ""), count _nesneler];
}] call CBA_fnc_addEventHandler;

// v8.128: Zeus 'ELITE Karakol / HQ' — karakol kaydi + harita isareti + savunma plani (hemen / alarm)
if (isNil "lambs_danger_karakollar") then { lambs_danger_karakollar = []; };
["lambs_danger_karakolIstegi", {
    params ["_taraf", "_poz", "_adI", "_yar", "_sav"];
    if (!isServer) exitWith {};
    private _adlar = ["KARAKOL", "MEVZI", "HQ", "GOZETLEME", "USSU"];
    private _ad = _adlar select (_adI max 0 min 4);
    // ayni noktada (60 m) mevcut kayit: once sil
    private _eski = lambs_danger_karakollar select {((_x select 1) distance2D _poz) < 60 && {(_x select 0) isEqualTo _taraf}};
    { deleteMarker (_x select 5); lambs_danger_karakollar deleteAt (lambs_danger_karakollar find _x); } forEach _eski;
    if (_sav isEqualTo 3) exitWith {
        diag_log format ["[KARAKOL] %1 | %2 KALDIRILDI (%3 kayit)", _taraf, mapGridPosition _poz, count _eski];
    };
    private _mn = format ["ELITE_KARAKOL_%1_%2", _taraf, round (_poz select 0)];
    deleteMarker _mn;
    createMarker [_mn, _poz];
    _mn setMarkerType (["mil_flag", "mil_triangle", "b_hq", "mil_dot", "mil_flag"] select (_adI max 0 min 4));
    _mn setMarkerColor (switch (_taraf) do { case west: {"ColorBLUFOR"}; case east: {"ColorOPFOR"}; default {"ColorIndependent"} });
    _mn setMarkerText format ["%1 (%2 m)", _ad, _yar];
    private _kayit = [_taraf, _poz, _yar, _ad, _sav, _mn, false];
    lambs_danger_karakollar pushBack _kayit;
    diag_log format ["[KARAKOL] %1 | %2 | %3 | yaricap %4 m | savunma %5", _taraf, _ad, mapGridPosition _poz, _yar, ["YOK", "HEMEN", "ALARM"] select (_sav min 2)];
    if (_sav isEqualTo 1) then {
        _kayit set [6, true];
        [_taraf, _poz, createHashMapFromArray [["tip", 1], ["grupN", 8], ["grupMesafe", _yar * 1.5], ["bina", true], ["piyade", true], ["rallyM", 250], ["orpM", 150], ["basla", 0]]] spawn (missionNamespace getVariable ["lambs_danger_fnc_komutanPlan", {false}]);
    };
}] call CBA_fnc_addEventHandler;

// ALARM bekcisi: duşman karakolun 800 m icinde savunanlarca bilinirse savunma plani kurulur
if (isServer) then {
    [] spawn {
        while {true} do {
            sleep 5;
            if (missionNamespace getVariable ["lambs_danger_karakolOff", false]) then { continue };
            {
                private _k = _x;
                _k params ["_taraf", "_poz", "_yar", "_ad", "_sav", "_mn", "_tetik"];
                if (_sav isNotEqualTo 2 || {_tetik}) then { continue };
                private _sav_gr = allGroups select {(side _x) isEqualTo _taraf && {!isNull leader _x} && {((leader _x) distance2D _poz) < (_yar * 1.5)} && {!isPlayer (leader _x)}};
                if (_sav_gr isEqualTo []) then { continue };
                private _dus = (_poz nearEntities ["CAManBase", 800]) select {alive _x && {(_taraf getFriend (side _x)) < 0.6} && {(side _x) isNotEqualTo civilian}};
                private _bilinen = _dus select {private _d = _x; (_sav_gr findIf {(_x knowsAbout _d) >= 0.5}) >= 0};
                if (_bilinen isNotEqualTo []) then {
                    _k set [6, true];
                    diag_log format ["[KARAKOL] ALARM: %1 %2 | duşman %3 m icinde bilindi (%4 kisi) -> savunma plani", _taraf, _ad, round (_poz distance2D (_bilinen select 0)), count _bilinen];
                    [_taraf, _poz, createHashMapFromArray [["tip", 1], ["grupN", 8], ["grupMesafe", _yar * 1.5], ["bina", true], ["piyade", true], ["rallyM", 250], ["orpM", 150], ["basla", 0], ["tehditY", 0]]] spawn (missionNamespace getVariable ["lambs_danger_fnc_komutanPlan", {false}]);
                };
            } forEach lambs_danger_karakollar;
        };
    };
};

diag_log "[PLAN-KAPI] komutan plani sunucu kapisi baslatildi (v8.116)";
true
