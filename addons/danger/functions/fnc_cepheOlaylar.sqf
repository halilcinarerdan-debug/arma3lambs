#include "script_component.hpp"
/*
 * Author: Cinar (ELITE fork)
 * CEPHE OLAYLARI (v8.237, Dilim A0) — Zeus paneli (istemci) <-> sunucu CBA olaylari. Her makinede acilista bir kez kaydedilir (tekrar cagrilirsa yok sayilir).
 *   lambs_danger_cepheFactionIstegi  [faction, adet, rezerv, poz, yaricap, varisYap]            (sunucu) fnc_cepheFaction
 *   lambs_danger_cepheTakvIstegi     [taraf(str side), [hiz, gecikme, minSquad, esZamanli, beceriPct, yakinPct, bitince, konvoyKayipPct]]  (sunucu) taraf ayari
 *   lambs_danger_cepheVarisIstegi    [taraf(str side), poz]                                     (sunucu) takviye varis noktasi
 *   lambs_danger_cepheSilIstegi      [faction ("" = tumu)]                                      (sunucu) profilleri + gruplari siler, rezervi sifirlar
 *   lambs_danger_cepheOlayIstegi     [poz, yaricap, sure(sn), tur]                              (sunucu) temas / ates / topcu darbesi alani: sure boyunca KESIN fiziksel alan
 *   lambs_danger_cepheDurumIstegi    [sahip]                                                    (sunucu) durum raporu -> sahibe 'cepheDurumYanit'
 *   lambs_danger_cepheDurumYanit     [satirlar]                                                 (istemci) sohbete yazar
 * Olay alani baska ELITE betiklerinden de cagrilabilir: ["lambs_danger_cepheOlayIstegi", [poz, 300, 120, "TOPCU"]] call CBA_fnc_serverEvent; (A0'da hicbir betige BAGLANMADI; Zeus / mission maker kullanir.)
 * Log: [CEPHE-AYAR] [CEPHE-FACTION] [CEPHE-OZET]
 *
 * Arguments: None
 * Return Value: Kaydedildi mi <BOOL>
 * Public: No
*/

if (!isNil "lambs_danger_cepheOlaylarStarted") exitWith {false};
lambs_danger_cepheOlaylarStarted = true;

["lambs_danger_cepheFactionIstegi", {
    params ["_f", "_adet", "_rezerv", "_poz", "_yaricap", "_varis"];
    if (!isServer) exitWith {};
    [_f, _adet, _rezerv, _poz, _yaricap, _varis] call FUNC(cepheFaction);
}] call CBA_fnc_addEventHandler;

["lambs_danger_cepheTakvIstegi", {
    params ["_taraf", "_d"];
    if (!isServer) exitWith {};
    call FUNC(cepheInit);
    _d params ["_hiz", "_gecikme", "_minSquad", "_esZamanli", "_beceri", "_yakin", "_bitince", "_kayip"];
    lambs_danger_cepheTakvAyar set [_taraf, createHashMapFromArray [
        ["hiz", _hiz], ["gecikme", _gecikme], ["minSquad", _minSquad], ["esZamanli", _esZamanli],
        ["beceri", _beceri], ["yakin", _yakin], ["bitince", _bitince], ["konvoyKayip", _kayip]
    ]];
    ["AYAR", format ["Personnel Replacement | taraf %1 | hiz %2 asker/saat, gecikme %3 sn, min squad %4, es zamanli paket %5, beceri %6 pct, yakin carpani %7 pct, havuz bitince %8 (0 devam 1 bitkin 2 cekil), konvoy zaiyat %9 pct", _taraf, _hiz, _gecikme, _minSquad, _esZamanli, _beceri, _yakin, _bitince, _kayip]] call FUNC(cepheLog);
}] call CBA_fnc_addEventHandler;

["lambs_danger_cepheVarisIstegi", {
    params ["_taraf", "_poz"];
    if (!isServer) exitWith {};
    call FUNC(cepheInit);
    lambs_danger_cepheVaris set [_taraf, +_poz];
    ["AYAR", format ["takviye varis noktasi | taraf %1 | %2", _taraf, mapGridPosition _poz]] call FUNC(cepheLog);
}] call CBA_fnc_addEventHandler;

["lambs_danger_cepheSilIstegi", {
    params [["_f", ""]];
    if (!isServer) exitWith {};
    call FUNC(cepheInit);
    private _silinen = 0;
    private _fiziksel = 0;
    {
        private _id = _x;
        private _p = lambs_danger_cepheProfiller get _id;
        if (_f isEqualTo "" || {(_p get "faction") isEqualTo _f}) then {
            if ((_p get "seviye") isEqualTo "L1") then {
                { if (!isNull _x) then { deleteVehicle _x; }; } forEach (_p get "birimler");
                private _g = _p getOrDefault ["grup", grpNull];
                if (!isNull _g) then { deleteGroup _g; };
                _fiziksel = _fiziksel + 1;
            };
            lambs_danger_cepheProfiller deleteAt _id;
            _silinen = _silinen + 1;
        };
    } forEach (keys lambs_danger_cepheProfiller);
    if (_f isEqualTo "") then { lambs_danger_cepheFactionlar = createHashMap; lambs_danger_cepheTakvTok = createHashMap; }
    else { lambs_danger_cepheFactionlar deleteAt _f; };
    ["FACTION", format ["SIL | %1 | %2 profil silindi (%3 fiziksel)", ["TUM CEPHE", _f] select (_f isNotEqualTo ""), _silinen, _fiziksel]] call FUNC(cepheLog);
}] call CBA_fnc_addEventHandler;

["lambs_danger_cepheOlayIstegi", {
    params ["_poz", ["_yaricap", 300], ["_sure", 120], ["_tur", "OLAY"]];
    if (!isServer) exitWith {};
    call FUNC(cepheInit);
    lambs_danger_cepheOlayAlani pushBack [+_poz, _yaricap, time + _sure, _tur];
    ["AYAR", format ["olay alani | %1 | %2 | yaricap %3 m | %4 sn", _tur, mapGridPosition _poz, _yaricap, _sure]] call FUNC(cepheLog);
}] call CBA_fnc_addEventHandler;

["lambs_danger_cepheDurumIstegi", {
    params ["_sahip"];
    if (!isServer) exitWith {};
    call FUNC(cepheInit);
    private _satirlar = [];
    private _tum = values lambs_danger_cepheProfiller;
    _satirlar pushBack format [
        "Cephe sistemi: %1 | profil %2 (sanal %3 / fiziksel %4 / takviye paketi %5)",
        ["KAPALI", "ACIK"] select (missionNamespace getVariable ["lambs_danger_cepheAktif", false]),
        count _tum,
        {(_x get "seviye") isEqualTo "L0" && {(_x get "tur") isEqualTo "SQUAD"}} count _tum,
        {(_x get "seviye") isEqualTo "L1"} count _tum,
        {(_x get "tur") isEqualTo "TAKVIYE"} count _tum
    ];
    {
        private _f = _x;
        private _fh = _y;
        private _pr = _tum select {(_x get "faction") isEqualTo _f && {(_x get "tur") isEqualTo "SQUAD"}};
        private _canli = 0;
        private _fiz = 0;
        { private _n = {_x get "canli"} count (_x get "uyeler"); _canli = _canli + _n; if ((_x get "seviye") isEqualTo "L1") then { _fiz = _fiz + _n; }; } forEach _pr;
        _satirlar pushBack format [
            "%1 [%2]: %3 squad, %4 asker canli (%5 fiziksel) | rezerv %6 | olu %7 | takviye gelen %8",
            _fh getOrDefault ["ad", _f], _fh getOrDefault ["taraf", sideUnknown], count _pr, _canli, _fiz,
            _fh getOrDefault ["rezerv", 0], _fh getOrDefault ["olu", 0], _fh getOrDefault ["takviyeGelen", 0]
        ];
    } forEach lambs_danger_cepheFactionlar;
    _satirlar pushBack format ["Tavan: %1 fiziksel asker | oyuncu yaricapi %2 m | temas %3 m | cephe seridi %4 m",
        missionNamespace getVariable ["lambs_danger_cepheFizikMaks", 300], missionNamespace getVariable ["lambs_danger_cepheFizikYaricap", 1500],
        missionNamespace getVariable ["lambs_danger_cepheTemasMesafe", 1200], missionNamespace getVariable ["lambs_danger_cepheSeritMesafe", 3000]];
    { diag_log format ["[CEPHE-DURUM] %1", _x]; } forEach _satirlar;
    ["lambs_danger_cepheDurumYanit", [_satirlar], _sahip] call CBA_fnc_ownerEvent;
}] call CBA_fnc_addEventHandler;

["lambs_danger_cepheDurumYanit", {
    params ["_satirlar"];
    if (!hasInterface) exitWith {};
    { systemChat format ["[ELITE Cephe] %1", _x]; } forEach _satirlar;
}] call CBA_fnc_addEventHandler;

diag_log "[CEPHE] olaylar kaydedildi (v8.237): cepheFactionIstegi / cepheTakvIstegi / cepheVarisIstegi / cepheSilIstegi / cepheOlayIstegi / cepheDurumIstegi";
true
