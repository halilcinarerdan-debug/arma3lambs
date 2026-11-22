#include "script_component.hpp"
/*
 * Author: Cinar (ELITE fork)
 * ONGORU OLCUM KAYDI (v8.730; kullanici: 'on gorunun gercekten ise yarayip yaramayacagini olcecek sistem ekle'): fnc_acikSiper nesne arkasi siper SECILDIGINDE cagirir.
 * Secilen noktanin HAM ongoru cezasini (senaryolarin hangisine acik; kontrol grubunda ceza uygulanmamis olsa da) hesaplar ve olcum kuyruguna (lambs_danger_ogKayit, en cok 80) kayit ekler;
 * fnc_ongoruOlcum bu kayitlari sureye bagli puanlar (tahmin hatasi, gercek goz hatti acikligi, hasar / olum).
 *
 * Arguments:
 * 0: Asker <OBJECT>
 * 1: Dusman <OBJECT>
 * 2: Secilen siper noktasi (AGL) <ARRAY>
 * 3: Senaryolar [[goz ASL, agirlik, etiket ("ileri" / "kanat")], ...] <ARRAY>
 * 4: Kontrol grubu mu (ceza uygulanmadi) <BOOL>
 * 5: Ileri senaryo suresi (sn) <NUMBER>
 *
 * Return Value: Kaydedildi mi <BOOL>
 * Public: No
*/

params [["_u", objNull, [objNull]], ["_en", objNull, [objNull]], ["_cp", [], [[]]], ["_sen", [], [[]]], ["_kon", false, [false]], ["_sure", 4, [0]]];
if (isNull _u || {isNull _en} || {!alive _en} || {(count _cp) < 2} || {_sen isEqualTo []}) exitWith {false};
private _list = missionNamespace getVariable ["lambs_danger_ogKayit", []];
if ((count _list) >= 80) exitWith {false};
private _pa = (AGLToASL [_cp select 0, _cp select 1, 0]) vectorAdd [0, 0, 1.0];
private _ham = 0;
{
    _x params ["_ge", "_w"];
    if (((lineIntersectsSurfaces [_ge, _pa, objNull, _u, true, 1, "FIRE", "NONE"]) isEqualTo []) && {!(terrainIntersectASL [_ge, _pa])}) then { _ham = _ham + _w; };
} forEach _sen;
private _s1 = _sen select {(_x param [2, ""]) isEqualTo "ileri"};
private _s1p = if (_s1 isEqualTo []) then {[]} else {(_s1 select 0) select 0};
// kayit: [t0, asker, dusman, dusman konumu t0 (ASL), ileri senaryo konumu, siper (AGL), ham ceza, kontrol, hasar0, sure, durum [tahminYapildi, acikSay, ornekSay, sonrakiOrnek], asker konumu t0 (ASL)]
_list pushBack [time, _u, _en, getPosASL _en, _s1p, +_cp, _ham, _kon, damage _u, _sure, [false, 0, 0, 0], getPosASL _u];
missionNamespace setVariable ["lambs_danger_ogKayit", _list];
true
