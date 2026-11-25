#include "script_component.hpp"
/*
 * Author: Cinar (ELITE fork)
 * SCRIPT KOSU (SON CARE; v8.823; kullanici: 'fixle'; RPT 01a3fcd2 (v8.822, 14 dk): [SIPER-VARIS] ULASILAMADI 10 (hareket kurtarma merdiveninin 4 adimi da sonuc vermedi; hepsi yol acik (yolTara 1.00), komut MOVE, baski ~0, siper noktasina 6-20 m kala, biri 55 m);
 *   merdiven adim basina yurudu %50-67. KOK NEDEN hala bilinmiyor (motor emri aliyor ama yurumuyor).
 * Merdiven (fnc_hareketKurtar) tukendikten sonra ve yalniz yakin (<= 30 m), DUZ ve acik (yolTara oran <= 1.05) hedef icin: asker AI'in yurumesi BEKLENMEDEN kosu animasyonuyla (AmovPercMrunSras...Df / AmovPknlMrunSras...Df; tufek / tabanca) hedefe BAKTIRILIP (setDir) ve hizi
 *   birim basina her karede setVelocityModelSpace [0, 4, z] ile surulur (en cok 8 sn; hedefe < 2.5 m, token degisimi, retreat / kosucu, olum / baygin -> durur). Gorunur davranis normal kosu animasyonudur; yalniz yol / AI beyni atlanir (yolTara duz hatti dogruladi).
 *   Bittiginde hiz sifirlanir, asker kendi AI'ina doner (doMove hedefe yeniden). Yalniz yerel AI, arac disi, oyuncusuz, tufek / tabanca elde (diger silahta atlanir).
 * Arguments: 0: Asker <OBJECT> | 1: Hedef (AGL) <ARRAY> | 2: Kaynak <STRING> (varis)
 * Return Value: Baslatildi mi <BOOL>
 * CBA: lambs_danger_hareketKurtarKos (varsayilan acik). Log: [KOSU-ADIM] BASLA / BITTI (ilk 20, sonra 30 sn'de bir) + sayac.
 * Public: No
*/
params [["_u", objNull, [objNull]], ["_hedef", [], [[]]], ["_kaynak", "?", [""]]];
if (isNull _u || {!alive _u} || {isPlayer _u} || {!local _u} || {!isNull objectParent _u} || {(count _hedef) < 2}) exitWith {false};
if !(missionNamespace getVariable ["lambs_danger_hareketKurtarKos", true]) exitWith {false};
if ((_u getVariable [QGVAR(forceMove), false]) isEqualTo true || {(group _u) getVariable [QGVAR(isRetreating), false]} || {!((lifeState _u) in ["HEALTHY", "INJURED"])} || {_u getVariable ["ACE_isUnconscious", false]}) exitWith {false};
private _an = toLower (animationState _u);
private _w = ["wrfl", "wpst"] select { (_an find _x) >= 0 };
if (_w isEqualTo []) then { _w = if ((currentWeapon _u) isEqualTo (handgunWeapon _u) && {(handgunWeapon _u) isNotEqualTo ""}) then { ["wpst"] } else { ["wrfl"] }; };
if ((currentWeapon _u) isNotEqualTo "" && {(currentWeapon _u) isNotEqualTo (primaryWeapon _u)} && {(currentWeapon _u) isNotEqualTo (handgunWeapon _u)}) exitWith {false};   // yukleyici vb. elde: atla
private _kosAnim = format ["AmovP%1MrunSras%2Df", ["erc", "knl"] select ((stance _u) isEqualTo "CROUCH"), _w select 0];
private _tok = time + (random 0.001);
_u setVariable [QGVAR(kosuAdimTok), _tok];
_u setVariable [QGVAR(taktikKilit), time + 10];
_u setUnitPosWeak (["UP", "MIDDLE"] select ((stance _u) isEqualTo "CROUCH"));
_u enableAI "ANIM";
_u enableAI "MOVE";
private _p0 = getPosATL _u;
private _say = missionNamespace getVariable ["lambs_danger_kosuAdimSay", createHashMap];
missionNamespace setVariable ["lambs_danger_kosuAdimSay", _say];
_say set ["basla", (_say getOrDefault ["basla", 0]) + 1];
if (["kosuAdim", 20, 30] call FUNC(logIzin)) then {
    diag_log format ["[KOSU-ADIM] BASLA | %1 | %2 | %3 | hedefe %4 m | durus %5 | komut %6 | anim %7 -> %8", _kaynak, groupId (group _u), name _u, round (_p0 distance2D _hedef), stance _u, currentCommand _u, animationState _u, _kosAnim];
};
[{
    params ["_args", "_h"];
    _args params ["_a", "_hd", "_tok", "_t0", "_kosAnim", "_ky", "_p0"];
    private _bitir = {
        params ["_neden"];
        [_h] call CBA_fnc_removePerFrameHandler;
        if (!isNull _a && {alive _a}) then {
            _a setVelocityModelSpace [0, 0, (velocityModelSpace _a) select 2];
            _a setVariable [QGVAR(taktikKilit), nil];
            _a doMove _hd;
            private _s = missionNamespace getVariable ["lambs_danger_kosuAdimSay", createHashMap];
            private _k = if ((_a distance2D _hd) < 4) then {"vardi"} else {"varamadi"};
            _s set [_k, (_s getOrDefault [_k, 0]) + 1];
            missionNamespace setVariable ["lambs_danger_kosuAdimSay", _s];
            if (["kosuAdimBitti", 20, 30] call FUNC(logIzin)) then {
                diag_log format ["[KOSU-ADIM] BITTI | %1 | %2 | %3 | %4 | %5 sn | kat edilen %6 m | hedefe %7 m", _ky, groupId (group _a), name _a, _neden, (time - _t0) toFixed 1, round ((getPosATL _a) distance2D _p0), round ((getPosATL _a) distance2D _hd)];
            };
        };
    };
    if (isNull _a || {!alive _a}) exitWith { ["olu"] call _bitir; };
    if ((_a getVariable [QGVAR(kosuAdimTok), 0]) isNotEqualTo _tok) exitWith { ["yeni emir (token)"] call _bitir; };
    if (!((lifeState _a) in ["HEALTHY", "INJURED"]) || {_a getVariable ["ACE_isUnconscious", false]}) exitWith { ["yarali / baygin"] call _bitir; };
    if ((group _a) getVariable [QGVAR(isRetreating), false] || {(_a getVariable [QGVAR(forceMove), false]) isEqualTo true}) exitWith { ["retreat / kosucu"] call _bitir; };
    if ((time - _t0) > 8) exitWith { ["sure doldu"] call _bitir; };
    private _pa = getPosATL _a;
    if ((_pa distance2D _hd) < 2.5) exitWith { ["hedefe vardi"] call _bitir; };
    _a setDir (_pa getDir _hd);
    if ((toLower (animationState _a)) find "mrun" < 0) then { _a playMoveNow _kosAnim; };
    private _v = velocityModelSpace _a;
    _a setVelocityModelSpace [0, 4, _v select 2];
}, 0, [_u, _hedef, _tok, time, _kosAnim, _kaynak, _p0]] call CBA_fnc_addPerFrameHandler;
true
