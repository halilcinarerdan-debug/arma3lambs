#include "script_component.hpp"
/*
 * Author: Cinar (ELITE fork)
 * C2 SUNUCU: OYUNCU KOMUTANIN BOT GRUBUNA EMRI (v8.391; v8.392: ROTA + objektif cakisma kurallari) — dogrular (gonderen sahibi mi, yetki, grup ayni tarafta ve oyuncu liderli degil), sonra grubun sahibi makinede fnc_c2EmirUygula calisir.
 * Emirler: MOVE (hedef noktaya yuru), SAD (hedef noktaya git + dusman ara / imha et), ROTA (hedef noktayi ROTAYA ekle: birden cok waypoint sirayla), TUT (yerinde dur), SERBEST (oyuncu komutasini birak, ELITE komutani yeniden karar verir).
 * MOVE / SAD / ROTA / TUT grubu 'lambs_danger_oyuncuKomuta' (fnc_tarafSecim: oyuncu komutasi) yapar; ELITE komutan zihni / plan atlar (v8.392: komutanPlan oyuncu komutasindaki grubu plana ALMAZ), ama savas taktikleri (bounding, siper, TCCC, cephane) calisir.
 * OBJEKTIF CAKISMASI (v8.392): (1) plana bagli (lambs_danger_planAktif) gruba C2 emri VERILMEZ (tek sahip; once 'Objektif > Iptal' ya da plan bitsin); (2) MOVE / SAD / ROTA noktasi ayni tarafin aktif objektif planinin
 * onemli noktalarina (objektif / RP / ORP / CCP / SBF) CBA c2PlanYaricap icindeyse reddedilir (fnc_c2PlanCakisma). SERBEST her zaman serbesttir.
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
if !(_emir in ["MOVE", "SAD", "ROTA", "TUT", "SERBEST"]) exitWith { [format ["Gecersiz emir: %1", _emir]] call _bildir; };

private _g = groupFromNetId _gNid;
if (isNull _g || {isNull (leader _g)} || {({alive _x} count (units _g)) isEqualTo 0}) exitWith { ["Grup bulunamadi / hepsi olu."] call _bildir; };
if ((side _g) isNotEqualTo (side (group _obs))) exitWith { ["Bu grup senin tarafinda degil."] call _bildir; };
if (isPlayer (leader _g)) exitWith { ["Oyuncu liderli gruba emir verilmez."] call _bildir; };

// tek sahip: objektif planindaki gruba C2 emri verilmez (SERBEST haric: zaten plan sahibi)
if (_emir isNotEqualTo "SERBEST" && {_g getVariable ["lambs_danger_planAktif", false]}) exitWith {
    [format ["%1 bir OBJEKTIF planinda (%2); plan grubun sahibi. Once 'Objektif > Iptal' ya da plan bitsin.", groupId _g, _g getVariable ["lambs_danger_planId", "?"]]] call _bildir;
};

private _hedef = [];
if (_emir in ["MOVE", "SAD", "ROTA"]) then {
    if (count _poz >= 2 && {(_poz select 0) isEqualType 0} && {(_poz select 1) isEqualType 0}) then {
        _hedef = [_poz select 0, _poz select 1, 0];
    };
};
if (_emir in ["MOVE", "SAD", "ROTA"] && {_hedef isEqualTo [] || {surfaceIsWater _hedef}}) exitWith { ["Hedef gecersiz ya da suda."] call _bildir; };

if (_hedef isNotEqualTo []) then {
    private _cak = [side _g, _hedef] call FUNC(c2PlanCakisma);
    if (_cak select 0) then {
        [format ["REDDEDILDI - nokta objektif planiyla cakisiyor: %1. Baska nokta sec ya da plani iptal et.", _cak select 1]] call _bildir;
        _hedef = [];
        _emir = "RED";
    };
};
if (_emir isEqualTo "RED") exitWith {};

[_g, _emir, _hedef] remoteExecCall ["lambs_danger_fnc_c2EmirUygula", groupOwner _g];
[format ["%1 -> %2%3 (%4 kisi)", groupId _g, _emir, if (_hedef isEqualTo []) then {""} else {format [" GRID %1", mapGridPosition _hedef]}, {alive _x} count (units _g)]] call _bildir;
