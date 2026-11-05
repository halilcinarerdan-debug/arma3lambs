#include "script_component.hpp"
/*
 * Author: Cinar (ELITE fork)
 * 3DEN: ELITE Objektif (komutan plani) modulu (v8.362). Modul konumu OBJEKTIF. Zeus 'ELITE Objektif' ile AYNI plan ayarlarini ve AYNI sunucu olayini (lambs_danger_planIstegi) kullanir.
 *   SYNC: (1) ELITE HQ / US (3DEN) modulu -> plan o HQ dan baslar (ele gecir icin zorunlu); (2) gruplar / askerler / araclar -> 'Grup secimi = Bagli gruplar' ise plan YALNIZ bunlari kullanir (elle secim, mesafe siniri yok).
 *   HQ modulu baglanmamis, ele gecir ve bagli grup varsa: bagli gruplar icin otomatik bir HQ kurulur (ilk bos kategori HQ1..HQ3, ilk grubun konumu). Tum HQ modlari icin HQ modulu gerekir.
 *   Mission basladiktan sonra 'Kurulum gecikmesi' sn bekler (varsayilan 10). Red nedeni RPT [PLAN-KAPI] / [PLAN] ve [EDEN] satirlarinda.
 * v8.404: 'ELITE Harekat' modulune SYNC'liyse plan harekat fazina kaydedilir ('Harekat fazi' niteligi), hemen kurulmaz.
 * Arguments: 0: modul <OBJECT>, 1: baglananlar (kullanilmaz), 2: etkin <BOOL>
 * Return Value: None
 * Public: No
*/

params ["_logic", "", "_activated"];
if (!_activated || {!isServer}) exitWith {};

[_logic] spawn {
    params ["_logic"];
    if !(["BEKLE"] call FUNC(edenOrtak)) exitWith { diag_log "[EDEN] Objektif: ELITE hazir olmadi (180 sn)" };
    private _n = { params ["_ad", "_v"]; ["SAYI", [_logic, "lambs_danger_" + _ad, _v]] call FUNC(edenOrtak) };
    private _b = { params ["_ad", "_v"]; ["BOOL", [_logic, "lambs_danger_" + _ad, _v]] call FUNC(edenOrtak) };
    private _gecikme = ["edObGecikme", 10] call _n;
    sleep (_gecikme max 0);

    private _obj = getPosATL _logic;
    ["DEGISKENLER", [_logic]] call FUNC(edenOrtak);
    private _gruplar = ["GRUPLAR", [_logic]] call FUNC(edenOrtak);
    private _hqM = ["MODUL", [_logic, QGVAR(EdenHQ)]] call FUNC(edenOrtak);

    // ---- HQ kimligi ----
    private _hqId = "";
    if (_hqM isNotEqualTo []) then {
        private _t = diag_tickTime + 90;
        private _m0 = _hqM select 0;
        waitUntil { sleep 0.5; ((_m0 getVariable ["lambs_danger_edenHqId", ""]) isNotEqualTo "") || {diag_tickTime > _t} };
        _hqId = _m0 getVariable ["lambs_danger_edenHqId", ""];
    };

    // ---- taraf ----
    private _tarafA = round (["edObTaraf", 0] call _n);
    private _taraf = west;
    if (_tarafA > 0) then {
        _taraf = [west, east, independent] select ((_tarafA - 1) min 2);
    } else {
        if (_gruplar isNotEqualTo []) then {
            _taraf = side (_gruplar select 0);
        } else {
            if (_hqId isNotEqualTo "") then {
                private _s = (_hqId splitString "_") param [1, ""];
                private _i = [west, east, independent] findIf {(str _x) isEqualTo _s};
                if (_i >= 0) then { _taraf = [west, east, independent] select _i; };
            };
        };
    };

    private _tip = ((round (["edObTip", 0] call _n)) max 0) min 1;
    // v8.407: sade modul turleri tipi kendisi belirler (Saldiri = ele gecir, Savunma = savun); eski 'ELITE Objektif' modulu 'Gorev tipi' ayarini kullanir
    if ((typeOf _logic) isEqualTo QGVAR(EdenSaldiri)) then { _tip = 0; };
    if ((typeOf _logic) isEqualTo QGVAR(EdenSavunma)) then { _tip = 1; };
    private _secimModu = (round (["edObGrupSec", 1] call _n)) max 0 min 3;
    private _secili = [];
    if (_secimModu isEqualTo 1) then {
        _secili = (_gruplar select {(side _x) isEqualTo _taraf}) apply {netId _x};
        if (_secili isEqualTo []) then {
            ["MESAJ", [format ["Objektif (3DEN) %1: 'Bagli gruplar' secili ama module bagli %2 grubu yok - OTOMATIK secime geciliyor", mapGridPosition _obj, str _taraf]]] call FUNC(edenOrtak);
            _secimModu = 0;
        };
    };

    // ---- HQ yoksa: ele gecir + bagli gruplar -> otomatik HQ ----
    private _tamam = true;
    if (_hqId isEqualTo "" && {_tip isEqualTo 0}) then {
        // v8.407 (kullanici: 'mapte 3 farkli HQ markeri var'; RPT: 1 HQ modulu + her Objektif icin otomatik HQ2 / HQ3): SYNC'siz Objektif once ayni taraftaki haritada VAR OLAN HQ modulunu kullanir; yoksa otomatik HQ kurulur
        private _mevHQ = (allMissionObjects QGVAR(EdenHQ)) select {((_x getVariable ["lambs_danger_edenHqId", ""]) find format ["_%1", _taraf]) > 0};
        if (_mevHQ isNotEqualTo []) then {
            _hqId = (_mevHQ select 0) getVariable ["lambs_danger_edenHqId", ""];
            diag_log format ["[EDEN] Objektif (3DEN) %1 | HQ modulune SYNC yok - haritadaki %2 HQ modulu kullanildi: %3 (yeni HQ kurulmadi)", mapGridPosition _obj, _taraf, _hqId];
        };
        if (_hqId isEqualTo "" && {_secimModu isEqualTo 1} && {_secili isNotEqualTo []}) then {
            private _kat = -1;
            {
                private _id = format ["%1_%2", _x, _taraf];
                if ((lambs_danger_hqlar findIf {(_x select 0) isEqualTo _id}) < 0) exitWith { _kat = _forEachIndex; };
            } forEach ["HQ1", "HQ2", "HQ3"];
            if (_kat >= 0) then {
                private _g0 = groupFromNetId (_secili select 0);
                ["lambs_danger_hqIstegi", [_taraf, getPosATL (leader _g0), _kat, 100]] call CBA_fnc_serverEvent;
                _hqId = format ["%1_%2", ["HQ1", "HQ2", "HQ3"] select _kat, _taraf];
                ["lambs_danger_hqAtama", [_hqId, _secili]] call CBA_fnc_serverEvent;
                diag_log format ["[EDEN] Objektif (3DEN): HQ modulu baglanmamis - otomatik HQ kuruldu: %1 (%2 grup)", _hqId, count _secili];
            };
        };
        if (_hqId isEqualTo "") then {
            _tamam = false;
            ["MESAJ", [format ["Objektif (3DEN) %1: ELE GECIR icin 'ELITE HQ / US Kur (3DEN)' modulunu bu module SYNC edin. Plan kurulmadi.", mapGridPosition _obj]]] call FUNC(edenOrtak);
        };
    };
    if (!_tamam) exitWith {};
    if (_secimModu >= 2 && {_hqId isEqualTo ""}) exitWith {
        ["MESAJ", [format ["Objektif (3DEN) %1: 'HQ tamami' icin HQ modulu baglanmali. Plan kurulmadi.", mapGridPosition _obj]]] call FUNC(edenOrtak);
    };

    private _grupN = (round (["edObGrupN", 4] call _n)) max 1;
    private _ayar = createHashMapFromArray [
        ["hqId", _hqId], ["tip", _tip], ["grupN", _grupN], ["tumHQ", _secimModu in [2, 3]], ["tumHQGuvenlik", _secimModu isEqualTo 2],
        ["piyade", ["edObPiy", true] call _b], ["zirh", ["edObZirh", false] call _b], ["at", ["edObAt", false] call _b], ["mg", ["edObMg", false] call _b],
        ["nisanci", ["edObNis", false] call _b], ["bina", ["edObBina", false] call _b], ["sayi", round (["edObSay", 0] call _n)],
        ["rallyM", round (["edObRally", 450] call _n)], ["orpM", round (["edObOrp", 300] call _n)], ["baskin", round (["edObBaskin", 0] call _n)],
        ["guven", round (["edObGuven", 1] call _n)], ["dogrulama", round (["edObDogr", 0] call _n)], ["tempo", round (["edObTempo", 0] call _n)],
        ["basla", round (["edObBasla", 0] call _n)], ["sure", round (["edObSure", 0] call _n)], ["tehditY", round (["edObTehdit", 0] call _n)],
        ["sivil", ["edObSivil", false] call _b], ["agirYasak", ["edObAgir", false] call _b], ["topcu", round (["edObTopcu", 0] call _n)],
        ["topcuN", round (["edObTopcuN", 4] call _n)], ["topcuBasit", round (["edObTopcuBasit", 0] call _n)], ["zincir", (round (["edObZincir", 0] call _n)) isEqualTo 1],
        ["reconEk", (round (["edObRecon", 0] call _n)) isEqualTo 1], ["tut", round (["edObTut", 1] call _n)], ["dronAvi", round (["edObDron", 0] call _n)],
        ["ihaListe", ((["BAGLI", [_logic]] call FUNC(edenOrtak)) select {unitIsUAV _x}) apply {netId _x}], ["ihaMod", round (["edObIha", 0] call _n)],
        ["otoGarnizon", round (["edObOtoGar", 0] call _n)], ["rpIsaret", ""], ["mevziYar", round (["edObMevziYar", 500] call _n)], ["oranEsik", ["edObOran", 2] call _n]
    ];
    if (_secimModu isEqualTo 1) then {
        _ayar set ["secili", _secili];
        _ayar set ["grupN", count _secili];
    };
    // v8.404 HAREKAT: bu modul bir 'ELITE Harekat' modulune SYNC'liyse plan HEMEN kurulmaz; faz numarasiyla harekata kaydedilir (harekat fazi baslayinca plan istenir)
    private _harM = ["MODUL", [_logic, QGVAR(EdenHarekat)]] call FUNC(edenOrtak);
    if (_harM isNotEqualTo []) exitWith {
        private _hm = _harM select 0;
        private _tH = diag_tickTime + 60;
        waitUntil { sleep 0.5; ((_hm getVariable ["lambs_danger_harekatId", ""]) isNotEqualTo "") || {diag_tickTime > _tH} };
        private _hid = _hm getVariable ["lambs_danger_harekatId", ""];
        private _fazNo = ((round (["edObFaz", 0] call _n)) max 1) min 6;
        // v8.407: 3DEN nitelik okunamiyorsa (RPT: HIC YOK) modulun DEGISKEN ADINDAki 'faz2' / 'faz3' ... fazi belirler (3DEN: modul > Degisken adi, ornek: faz2_hedef)
        if (isNil {_logic getVariable "lambs_danger_edObFaz"}) then {
            private _vn = toLower (vehicleVarName _logic);
            private _fi = _vn find "faz";
            if (_fi >= 0) then {
                private _fd = parseNumber (_vn select [_fi + 3, 1]);
                if (_fd >= 1 && {_fd <= 6}) then { _fazNo = _fd; diag_log format ["[EDEN] Objektif (3DEN) %1 | faz modul degisken adindan alindi ('%2' -> faz %3)", mapGridPosition _obj, vehicleVarName _logic, _fd]; };
            };
        };
        private _ok = ["KAYIT", [_hid, _fazNo, _taraf, _obj, _ayar toArray false, [format ["OBJ %1", mapGridPosition _obj], _logic getVariable ["lambs_danger_edObAd", ""]] select ((_logic getVariable ["lambs_danger_edObAd", ""]) isEqualType "" && {(_logic getVariable ["lambs_danger_edObAd", ""]) isNotEqualTo ""})]] call lambs_danger_fnc_harekat;
        diag_log format ["[EDEN] Objektif (3DEN) %1 | HAREKAT '%2' faz %3'e kaydedildi: %4 (plan harekat fazi baslayinca kurulur)", mapGridPosition _obj, _hid, _fazNo, _ok];
    };
    // 'tut' / 'dronAvi' / 'otoGarnizon' Zeus ile ayni degerleri bekler (indeks)
    ["lambs_danger_planIstegi", [_taraf, _obj, _ayar toArray false]] call CBA_fnc_serverEvent;
    diag_log format ["[EDEN] Objektif (3DEN) plan istegi gonderildi | %1 | tip %2 | %3 | HQ '%4' | grup secimi %5 (%6 grup)", _taraf, ["ELE GECIR", "SAVUN"] select _tip, mapGridPosition _obj, _hqId, _secimModu, count _secili];
};
