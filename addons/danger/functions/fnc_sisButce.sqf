#include "script_component.hpp"
/*
 * Author: Cinar (ELITE fork)
 * SIS (DUMAN) BUTCESI (v8.330) — kullanici: 'askerler cok fazla smoke atiyorlar, gomuyorlar, bunun onune gec'. Bir saldirida sis uc ayri yerden atiliyordu: fnc_tacticalSmoke (COVER_MOVE / BREAK_CONTACT) + fnc_tacticsAssault (lider sis + 40mm sis)
 * + fnc_tacticsFlank (lider sis) + bounding basi + geri cekilme / AT / zirhtan kacis; hepsinin kendi cooldown'u vardi, birbirini bilmiyordu. Bu kapi TUM askeri sis atislarinin ortak butcesidir:
 *   TARAF butcesi : 120 sn'de en cok N sis OLAYI (CBA lambs_danger_sisButceMax, varsayilan 2; 0 = hic sis atilmaz) ve iki olay arasi en az 25 sn
 *   GRUP aralik   : ayni grup en az 90 sn (CBA lambs_danger_sisGrupAralik; temas kesmede 60 sn)
 *   GERCEK TEHDIT : grup temasta (contact) ya da lider baski altinda olmali (temassiz bounding / manevra sis atmaz)
 *   OLAY          : olay basina 1 kayit; temas kesmedeki 2-3 atislik derin perde TEK olay sayilir
 * Izin verilirse kayit duser (taraf listesi + grup zamani). Log: [SIS-BUTCE] (ilk 40 ret).
 *
 * Arguments:
 * 0: Grup ya da lider <GROUP|OBJECT>
 * 1: Mod "COVER_MOVE" | "BREAK_CONTACT" | "DIGER" <STRING>
 *
 * Return Value: Sis atilabilir mi (kayit dustu) <BOOL>
 * Public: No
*/

params [["_g", grpNull, [grpNull, objNull]], ["_mod", "COVER_MOVE", [""]]];
if (_g isEqualType objNull) then { _g = group _g; };
if (isNull _g) exitWith {false};

private _maks = round (missionNamespace getVariable ["lambs_danger_sisButceMax", 2]);
private _ret = {
    params ["_neden"];
    lambs_danger_sisButceRetN = (missionNamespace getVariable ["lambs_danger_sisButceRetN", 0]) + 1;
    if (lambs_danger_sisButceRetN <= 40) then {
        diag_log format ["[SIS-BUTCE] %1 | mod:%2 | sis ATILMADI: %3 | toplam ret %4", groupId _g, _mod, _neden, lambs_danger_sisButceRetN];
    };
    false
};
if (_maks <= 0) exitWith { ["sis kapali (butce 0)"] call _ret };

private _taraf = side _g;
private _anahtar = format ["lambs_danger_sisButce_%1", _taraf];
private _liste = (missionNamespace getVariable [_anahtar, []]) select {(time - _x) < 120};
if ((count _liste) >= _maks) exitWith { [format ["taraf butcesi dolu (%1 / 120 sn)", count _liste]] call _ret };
if (_liste isNotEqualTo [] && {(time - (_liste select -1)) < 25}) exitWith { ["taraf araligi (< 25 sn)"] call _ret };

private _grupAralik = missionNamespace getVariable ["lambs_danger_sisGrupAralik", 90];
if (_mod isEqualTo "BREAK_CONTACT") then { _grupAralik = _grupAralik * 0.67; };
if ((time - (_g getVariable [QGVAR(sisButceT), -999])) < _grupAralik) exitWith { [format ["grup araligi (< %1 sn)", round _grupAralik]] call _ret };

private _l = leader _g;
private _temas = (_g getVariable [QGVAR(contact), 0]) > time;
private _baski = (!isNull _l) && {(getSuppression _l) > 0.15};
if (!_temas && {!_baski}) exitWith { ["gercek tehdit yok (temas / baski yok)"] call _ret };

_liste pushBack time;
missionNamespace setVariable [_anahtar, _liste];
_g setVariable [QGVAR(sisButceT), time];
true
