#include "script_component.hpp"
/*
 * Author: Cinar (ELITE fork)
 * DRONA ATES IZNI (v8.345; kullanici: 'komutan niyeti sessiz olmasina ragmen drona ates actilar, opsiyonel drona ates etmeyi de eklemeliyiz'). Askerlerin / tank murettebatinin drona ZORLA atesi (fnc_dronTepki, fnc_tankDron, hava savunmasi AA) bu izne tabidir.
 * CBA 'dronAtesModu': 0 KAPALI (zorla ates yok; dagilma / siper / gizlenme surer), 1 SESSIZLIGE SAYGILI (varsayilan), 2 SERBEST (eski).
 * Mod 1: grup SESSIZ ise ates YOK; sessiz = combatMode GREEN / BLUE, davranis STEALTH, ya da plan tempo 'sessiz / gizli' ve faz TOPLAN / ORP / KESIF / TASIMA / MEVZI (yaklasma gizli: ates konumu ele verir).
 *   Istisna - OZ SAVUNMA (ATP 3-01.8 satir 1160-1170: 'hostile act or demonstrated hostile intent' karsisinda oz savunma hakki; satir 1378-1384: saldirmayan hava aracina ates etmeyip konumu gizlemek komutanin karari): dron saldiri tipi
 *   (FPV-AT / FPV-AP / BOMBA) VE <= 200 m VE gruba yaklasiyor (yaklasma hizi > 5 m/sn) ise ates serbest. Gozlem tipi (GOZLEM) dron icin sessizken asla.
 * Sayilar [T]; 'sessizken ates etme' kitapta konum gizleme ilkesi (ATP 3-01.8 pasif onlemler).
 *
 * Arguments:
 * 0: Grup <GROUP>
 * 1: Dron <OBJECT>
 * 2: Dronla grup lideri arasi mesafe (m) <NUMBER>
 *
 * Return Value: Zorla ates serbest mi <BOOL>
 * Public: No
*/

params [["_g", grpNull, [grpNull]], ["_dr", objNull, [objNull]], ["_dist", 9999, [0]]];
private _mod = missionNamespace getVariable ["lambs_danger_dronAtesModu", 1];
if (_mod <= 0) exitWith {false};
if (_mod >= 2 || {isNull _g} || {isNull _dr}) exitWith {true};

private _sessiz = (combatMode _g) in ["GREEN", "BLUE"] || {(behaviour (leader _g)) isEqualTo "STEALTH"};
if (!_sessiz) then {
    private _plan = (missionNamespace getVariable ["lambs_danger_planlar", createHashMap]) getOrDefault [_g getVariable ["lambs_danger_planId", ""], createHashMap];
    if (count _plan > 0) then {
        _sessiz = (((_plan getOrDefault ["ayar", createHashMap]) getOrDefault ["tempo", 0]) isEqualTo 1) && {(_plan getOrDefault ["faz", ""]) in ["TOPLAN", "ORP", "KESIF", "TASIMA", "MEVZI"]};
    };
};
if (!_sessiz) exitWith {true};

// sessiz: yalniz oz savunma
private _tip = [_dr] call FUNC(ihaTip);
if !(_tip in ["FPV-AT", "FPV-AP", "BOMBA"]) exitWith {false};
if (_dist > 200) exitWith {false};
private _l = leader _g;
private _yon = vectorNormalized ((getPosASL _l) vectorDiff (getPosASL _dr));
(((velocity _dr) vectorDotProduct _yon) > 5)
