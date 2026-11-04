#include "script_component.hpp"
/*
 * Author: Cinar (ELITE fork)
 * C2 SUNUCU: OYUNCU KOMUTANIN BOT GRUBUNA EMRI (v8.391) — dogrular (gonderen sahibi mi, yetki, grup ayni tarafta ve oyuncu liderli degil), sonra grubun sahibi makinede fnc_c2EmirUygula calisir.
 * Emirler: MOVE (hedef noktaya yuru), SAD (hedef noktaya git + dusman ara / imha et), TUT (yerinde dur), SERBEST (oyuncu komutasini birak, ELITE komutani yeniden karar verir).
 * MOVE / SAD / TUT grubu 'lambs_danger_oyuncuKomuta' (fnc_tarafSecim: oyuncu komutasi) yapar; ELITE komutan zihni / plan atlar, ama savas taktikleri (bounding, siper, TCCC, cephane paylasimi) calisir.
 * Log: [C2-EMIR].
 *
 * Arguments:
 * 0: Grup netId <STRING>
 * 1: Emir <STRING>
 * 2: Hedef konum (TUT / SERBEST icin []) <ARRAY>
 * 3: Gozlemci (komutan oyuncu) <OBJECT>
 *
 * Return Value: None
 * Public: No
*/

params [["_gNid", "", [""]], ["_emir", "", [""]], ["_poz", [], [[]]], ["_obs", objNull, [objNull]]];
if (!isServer) exitWith {};

private _gon = remoteExecutedOwner;
if (_gon isEqualTo 0) then { _gon = clientOwner; };

private _bildir = {
    params ["_m"];
    [format ["[C2] EMIR: %1", _m]] remoteExecCall ["systemChat", _gon];
    diag_log format ["[C2-EMIR] %1 | %2", name _obs, _m];
};

if (isNull _obs || {!isPlayer _obs} || {(owner _obs) isNotEqualTo _gon}) exitWith {
    diag_log format ["[C2-EMIR] RED: gonderen / gozlemci uyusmuyor (gonderen %1)", _gon];
};
if (!([_obs, false] call FUNC(c2Yetkili))) exitWith { ["Yetkin yok (grup lideri / komutan degiskeni)."] call _bildir; };
if !(_emir in ["MOVE", "SAD", "TUT", "SERBEST"]) exitWith { [format ["Gecersiz emir: %1", _emir]] call _bildir; };

private _g = groupFromNetId _gNid;
if (isNull _g || {isNull (leader _g)} || {({alive _x} count (units _g)) isEqualTo 0}) exitWith { ["Grup bulunamadi / hepsi olu."] call _bildir; };
if ((side _g) isNotEqualTo (side (group _obs))) exitWith { ["Bu grup senin tarafinda degil."] call _bildir; };
if (isPlayer (leader _g)) exitWith { ["Oyuncu liderli gruba emir verilmez."] call _bildir; };

private _hedef = [];
if (_emir in ["MOVE", "SAD"]) then {
    if (count _poz >= 2 && {(_poz select 0) isEqualType 0} && {(_poz select 1) isEqualType 0}) then {
        _hedef = [_poz select 0, _poz select 1, 0];
    };
};
if (_emir in ["MOVE", "SAD"] && {_hedef isEqualTo [] || {surfaceIsWater _hedef}}) exitWith { ["Hedef gecersiz ya da suda."] call _bildir; };

[_g, _emir, _hedef] remoteExecCall ["lambs_danger_fnc_c2EmirUygula", groupOwner _g];
[format ["%1 -> %2%3 (%4 kisi)", groupId _g, _emir, if (_hedef isEqualTo []) then {""} else {format [" GRID %1", mapGridPosition _hedef]}, {alive _x} count (units _g)]] call _bildir;
