#include "script_component.hpp"
/*
 * Author: Cinar (ELITE fork)
 * DEVRIYE AGI: HABERLESME + DESTEK (v8.400; kullanici: 'herkes herkesten haberdar ve iletisim halinde olsun').
 * fnc_karakolGarnizon her 15 sn turunun basinda BIR KEZ cagirir (tum karakollar icin). Kaynak gruplar: lambs_danger_devriyeAg'deki TUM devriyeler (herhangi karakol) + her karakolun NOBET grubu.
 *   HABER (CBA devHaber): kaynak grup son 15 sn'de temas yasadiysa (QGVAR(contact)) ve lideri bir dusman biliyorsa (findNearestEnemy: gercek algi, hile yok), o dusman devHaberYar m (telsiz menzili,
 *     varsayilan 2500) icindeki TUM dost devriyelere ve nobet gruplarina reveal 1.4 ile bildirilir; rapor (taraf, konum, zaman) ortak listeye (lambs_danger_devHaberler, en cok 12, 300 sn) girer ->
 *     devriyelerin sonraki sektor secimi bildirilen yere +400 puan verir (fnc_devriyeAg).
 *   DESTEK (CBA devDestek): rapor basina EN FAZLA BIR devriye (ayni taraf, TUR / DINLEN durumunda, kendisi temasta degil, karakolu alarmda degil, bildirilen yere <= devDestekMes) en yakin olan
 *     rapor konumuna 90 m dost tarafindan SAD ile yonlendirilir (240 sn; sonra karakole donup dinlenir; ayni devriye 300 sn icinde tekrar yonlendirilmez).
 *   TEMIZLIK: grubu olmayan kayitlar silinir; CBA devIsaret (varsayilan KAPALI - global isaret, PvP'de dusman devriyeyi gosterir) devriye lider konumuna harita isareti koyar.
 * Alarm (temas karakol yaricapi x2 icinde) eski davranisla DEVAM eder: karakolun tum devriyeleri cevre savunmasina gecer; destek yalniz alarmda olmayan devriyelere gider.
 * Log: [KARAKOL-DEVRIYE-HABER]
 *
 * Arguments: None
 * Return Value: None
 * Public: No
*/

if (!isServer) exitWith {};
if (isNil "lambs_danger_devriyeAg") exitWith {};
if (isNil "lambs_danger_devHaberler") then { lambs_danger_devHaberler = []; };

private _ag = lambs_danger_devriyeAg;
private _haberAktif = missionNamespace getVariable ["lambs_danger_devHaber", true];
private _destekAktif = missionNamespace getVariable ["lambs_danger_devDestek", true];
private _haberYar = missionNamespace getVariable ["lambs_danger_devHaberYar", 2500];
private _destekMes = missionNamespace getVariable ["lambs_danger_devDestekMes", 1200];
private _isaretAktif = missionNamespace getVariable ["lambs_danger_devIsaret", false];

// ---- temizlik: grubu olmayan / olu kayit ----
private _silinecek = [];
{
    private _g = groupFromNetId _x;
    if (isNull _g || {({alive _x} count (units _g)) isEqualTo 0}) then { _silinecek pushBack _x; };
} forEach (keys _ag);
{
    _ag deleteAt _x;
    deleteMarker format ["ELITE_DEV_%1", (_x splitString ":") joinString "_"];
} forEach _silinecek;

// taze olmayan raporlar
lambs_danger_devHaberler = lambs_danger_devHaberler select {(time - (_x select 2)) < 300};

if (_haberAktif) then {
    // ---- kaynaklar: devriyeler + nobet gruplari ----
    private _kaynaklar = [];
    {
        private _g = groupFromNetId _x;
        if (!isNull _g) then { _kaynaklar pushBack _g; };
    } forEach (keys _ag);
    {
        private _ng = _y getOrDefault ["nobetG", grpNull];
        if (!isNull _ng && {({alive _x} count (units _ng)) > 0}) then { _kaynaklar pushBack _ng; };
    } forEach lambs_danger_garnizonDurum;

    {
        private _g = _x;
        private _l = leader _g;
        if (isNull _l || {!alive _l} || {(time - (_g getVariable [QGVAR(contact), -999])) > 15} || {(time - (_g getVariable ["lambs_danger_devHaberT", -999])) < 20}) then { continue };
        private _e = _l findNearestEnemy _l;
        if (isNull _e) then { continue };
        _g setVariable ["lambs_danger_devHaberT", time];
        private _ep = getPosATL _e;
        private _taraf = side _g;
        lambs_danger_devHaberler pushBack [_taraf, _ep, time, netId _g, false];
        if ((count lambs_danger_devHaberler) > 12) then { lambs_danger_devHaberler deleteAt 0; };
        private _sayi = 0;
        {
            private _h = _x;
            if (_h isNotEqualTo _g && {(side _h) isEqualTo _taraf} && {local _h} && {!isNull (leader _h)} && {alive (leader _h)} && {((leader _h) distance2D _l) <= _haberYar}) then {
                _h reveal [_e, 1.4];
                _sayi = _sayi + 1;
            };
        } forEach _kaynaklar;
        diag_log format ["[KARAKOL-DEVRIYE-HABER] %1 (%2) temas bildirdi: %3 | konum %4 | %5 dost grup haberdar edildi (<= %6 m)", groupId _g, _taraf, typeOf _e, mapGridPosition _ep, _sayi, round _haberYar];
    } forEach _kaynaklar;

    // ---- destek: rapor basina en yakin BIR devriye ----
    if (_destekAktif) then {
        {
            private _rapor = _x;
            _rapor params ["_rt", "_rp", "_rz", "_rk", "_rd"];
            if (_rd || {(time - _rz) > 60}) then { continue };
            _rapor set [4, true];
            private _enG = grpNull;
            private _enK = "";
            private _enD = 1e9;
            {
                private _gk = _x;
                private _gg = groupFromNetId _gk;
                private _kayit = _y;
                if (_gk isNotEqualTo _rk && {!isNull _gg} && {(_kayit select 0) isEqualTo _rt} && {!isNull (leader _gg)} && {local (leader _gg)}) then {
                    private _dd = (leader _gg) distance2D _rp;
                    private _alarmK = (lambs_danger_garnizonDurum getOrDefault [_kayit select 1, createHashMap]) getOrDefault ["alarm", false];
                    if (_dd <= _destekMes && {_dd < _enD} && {!_alarmK} && {(_gg getVariable ["lambs_danger_devDurum", ""]) in ["TUR", "DINLEN"]}
                        && {(time - (_gg getVariable [QGVAR(contact), -999])) > 60} && {(time - (_gg getVariable ["lambs_danger_devDestekT", -999])) > 300}) then {
                        _enD = _dd; _enG = _gg; _enK = _gk;
                    };
                };
            } forEach _ag;
            if (!isNull _enG) then {
                private _kayit = _ag getOrDefault [_enK, [_rt, "", -1, []]];
                { deleteWaypoint ((waypoints _enG) select 0); } forEach (waypoints _enG);
                private _hp = _rp getPos [90, _rp getDir (leader _enG)];
                if (surfaceIsWater _hp) then { _hp = getPosATL (leader _enG); };
                private _w = _enG addWaypoint [_hp, 30];
                _w setWaypointType "SAD";
                _w setWaypointName "ELITE DEVRIYE: destek (temas raporu)";
                _w setWaypointBehaviour "COMBAT";
                _w setWaypointCombatMode "RED";
                _w setWaypointSpeed "NORMAL";
                _w setWaypointCompletionRadius 80;
                _enG setVariable ["lambs_danger_devDurum", "DESTEK"];
                _enG setVariable ["lambs_danger_devDestekBitis", time + 240];
                _enG setVariable ["lambs_danger_devDestekT", time];
                _ag set [_enK, [_kayit select 0, _kayit select 1, -1, []]];
                diag_log format ["[KARAKOL-DEVRIYE-HABER] %1 devriyesi DESTEGE gonderildi: temas %2 | %3 m | 240 sn (karakol %4)", groupId _enG, mapGridPosition _rp, round _enD, _kayit select 1];
            };
        } forEach lambs_danger_devHaberler;
    };
};

// ---- harita isareti (hata ayiklama; varsayilan kapali) ----
if (_isaretAktif) then {
    {
        private _g = groupFromNetId _x;
        private _kayit = _y;
        if (isNull _g || {isNull (leader _g)}) then { continue };
        private _mi = format ["ELITE_DEV_%1", (_x splitString ":") joinString "_"];
        if ((getMarkerPos _mi) isEqualTo [0, 0, 0]) then {
            createMarker [_mi, getPosATL (leader _g)];
            _mi setMarkerType "mil_triangle";
            _mi setMarkerSize [0.6, 0.6];
            _mi setMarkerColor (switch (_kayit select 0) do { case west: {"ColorBLUFOR"}; case east: {"ColorOPFOR"}; default {"ColorIndependent"} });
        };
        _mi setMarkerPos (getPosATL (leader _g));
        _mi setMarkerText format ["%1 %2 S%3", groupId _g, _g getVariable ["lambs_danger_devDurum", "?"], _kayit select 2];
    } forEach _ag;
};
