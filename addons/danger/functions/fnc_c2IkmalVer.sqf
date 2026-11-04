#include "script_component.hpp"
/*
 * Author: Cinar (ELITE fork)
 * C2 SUNUCU: IKMAL DAGIT — helikopter pilotu / sofor lojistigi (v8.391; kullanici: 'helikopter pilotu olarak adamlara lojistik saglamak').
 * Ikmal veren oyuncunun (pilot) yakinindaki (CBA c2IkmalYaricap, varsayilan 60 m) AYNI TARAFTAKI BOT askerlerin yuklemesi, fnc_c2Baslat'in kaydettigi ILK yuklemeye (cephane + tibbi + esya) geri doner:
 *   setUnitLoadout [yukleme, true] (sarjorler dolu). Hava araci ise YERDE olmali (yukseklik < 4 m, hiz < 6 km/s); yayada / kara aracindaki oyuncu da dagitabilir.
 * v8.396: yakindaki AI murettebatli araclar (kara / hava / deniz, statik silah haric, pilotun kendi araci haric) setFuel 1 + setVehicleAmmo 1 alir (CBA c2IkmalArac, varsayilan acik).
 * Oyuncu basina 45 sn bekleme. Gonderen dogrulamasi: remoteExecutedOwner = oyuncunun sahibi. Log: [C2-IKMAL].
 * Not: setUnitLoadout elde tasinan yerden alinmis silahi da ilk yuklemeye cevirir; ilk yukleme kaydi botun ilk gorulusudur (kayit fnc_c2Baslat sunucu dongusunde).
 *
 * Arguments:
 * 0: Ikmal veren oyuncu <OBJECT>
 *
 * Return Value: None
 * Public: No
*/

params [["_p", objNull, [objNull]]];
if (!isServer) exitWith {};

private _gon = remoteExecutedOwner;
if (_gon isEqualTo 0) then { _gon = clientOwner; };

private _bildir = {
    params ["_m"];
    [format ["[C2] IKMAL: %1", _m]] remoteExecCall ["systemChat", _gon];
    diag_log format ["[C2-IKMAL] %1 | %2", name _p, _m];
};

if (isNull _p || {!isPlayer _p} || {!alive _p} || {(owner _p) isNotEqualTo _gon}) exitWith {
    diag_log format ["[C2-IKMAL] RED: gonderen / oyuncu uyusmuyor (gonderen %1)", _gon];
};
if (!(missionNamespace getVariable ["lambs_danger_c2Aktif", true])) exitWith { ["C2 sistemi kapali."] call _bildir; };

private _v = vehicle _p;
if (_v isKindOf "Air" && {(((getPosATL _v) select 2) > 4) || {(speed _v) > 6}}) exitWith { ["Helikopter / ucak yerde ve durmus olmali (yukseklik < 4 m, hiz < 6 km/s)."] call _bildir; };

private _bekle = 45 - (time - (_p getVariable [QGVAR(c2IkmalT), -999]));
if (_bekle > 0) exitWith { [format ["Bekleme: %1 sn", ceil _bekle]] call _bildir; };

private _yar = missionNamespace getVariable ["lambs_danger_c2IkmalYaricap", 60];
private _taraf = side (group _p);
private _hedefler = allUnits select {
    alive _x && {!isPlayer _x} && {(side (group _x)) isEqualTo _taraf} && {(_x distance2D _v) < _yar}
    && {(_x getVariable [QGVAR(c2Yukleme), []]) isNotEqualTo []}
};
// v8.396 UZUN OPERASYON: yakindaki ayni taraf AI murettebatli araclar da yakit + cephane ikmali alir (CBA c2IkmalArac); pilotun kendi araci haric
private _araclar = [];
if (missionNamespace getVariable ["lambs_danger_c2IkmalArac", true]) then {
    _araclar = ((getPosATL _v) nearEntities [["LandVehicle", "Air", "Ship"], _yar]) select {
        _x isNotEqualTo _v && {alive _x} && {!(_x isKindOf "StaticWeapon")}
        && {((crew _x) findIf {alive _x && {!isPlayer _x} && {(side (group _x)) isEqualTo _taraf}}) >= 0}
        && {((crew _x) findIf {isPlayer _x}) < 0}
    };
};
if (_hedefler isEqualTo [] && {_araclar isEqualTo []}) exitWith { [format ["Yakinda (%1 m) ikmal verilecek bot / arac yok (kayitli yuklemesi olan, ayni taraf).", round _yar]] call _bildir; };

private _gruplar = [];
{
    private _orig = _x getVariable [QGVAR(c2Yukleme), []];
    if (local _x) then {
        _x setUnitLoadout [_orig, true];
    } else {
        [_x, [_orig, true]] remoteExecCall ["setUnitLoadout", _x];
    };
    _gruplar pushBackUnique (group _x);
} forEach _hedefler;

{
    if (local _x) then { _x setFuel 1; _x setVehicleAmmo 1; } else { [_x, 1] remoteExecCall ["setFuel", _x]; [_x, 1] remoteExecCall ["setVehicleAmmo", _x]; };
} forEach _araclar;

_p setVariable [QGVAR(c2IkmalT), time];
[format ["%1 bot / %2 grup (cephane + tibbi), %3 arac (yakit + cephane) ikmal aldi (%4 m icinde).", count _hedefler, count _gruplar, count _araclar, round _yar]] call _bildir;
