#include "script_component.hpp"
/*
 * Author: Cinar (ELITE fork)
 * SIHA LAZER ISARETLEME (v8.344 kanca; v8.365'te CANLANDIRILDI): hedefin ustunde, ISARETLEYEN tarafin LaserTarget nesnesini (LaserTargetW / E / C) yaratir ve hedefe baglar;
 * lazer gudumlu mermi (vanilla Sh_155mm_AMOS_LG, 82 mm LG; RHS / CUP lazer gudumlu) bu nesneyi kendisi bulur. Isaretleme 'sure' sn surer, sonra silinir.
 * KULLANAN: fnc_dronTopcuMisyon 1b (dron gozlemli atis: gozlemci GERCEK IHA + kumede dusman arac + taraf bataryasinda LG mermisi -> isaretle, tek LG mermisi at; fnc_topcuLG bataryayi bulur).
 * fnc_topcuListe lazer-gudumlu mermileri genel HE atisi icin bilerek disarida tutar. Kapatma: lambs_danger_sihaLazerOff / CBA 'SIHA lazer isaretleme'.
 *   Kayit: lambs_danger_sihaHedefler_<taraf> = [[hedef, bitis zamani], ...].
 * DOGRULANMADI: LaserTarget nesnesinin createVehicle ile yaratilip LG mermiyi yonlendirmesi oyunda denenmedi ([SIHA-LAZER] BDA logu sonucu gosterir).
 *
 * Arguments:
 * 0: Isaretleyen IHA <OBJECT>
 * 1: Hedef <OBJECT>
 * 2: Sure (sn, varsayilan 40) <NUMBER>
 *
 * Return Value: LaserTarget nesnesi (yoksa objNull) <OBJECT>
 * Public: No
*/

params [["_uav", objNull, [objNull]], ["_h", objNull, [objNull]], ["_sure", 40, [0]]];
if (isNull _uav || {isNull _h} || {!alive _h} || {!alive _uav}) exitWith {objNull};
private _taraf = side (group (driver _uav));
private _cls = [east, west, independent] find _taraf;
_cls = ["LaserTargetE", "LaserTargetW", "LaserTargetC"] select (_cls max 0);
if !(isClass (configFile >> "CfgVehicles" >> _cls)) exitWith {objNull};
private _lz = createVehicle [_cls, getPosATL _h, [], 0, "CAN_COLLIDE"];
_lz attachTo [_h, [0, 0, 1.2]];
private _k = format ["lambs_danger_sihaHedefler_%1", _taraf];
private _l = (missionNamespace getVariable [_k, []]) select {(_x select 1) > time};
_l pushBack [_h, time + _sure];
missionNamespace setVariable [_k, _l];
[{ params ["_o"]; if (!isNull _o) then { detach _o; deleteVehicle _o; }; }, [_lz], _sure] call CBA_fnc_waitAndExecute;
diag_log format ["[SIHA-LAZER] ISARETLEME: %1 -> %2 (%3) %4 sn", typeOf _uav, typeOf _h, mapGridPosition _h, _sure];
_lz
