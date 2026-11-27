#include "script_component.hpp"
/*
 * Author: Cinar (ELITE fork)
 * YUMUSAK SIPER OTURMA (v8.647; kullanici: 'siper oturtma baya yumusasin'; eskiden 0.3-1.2 sn'de 6-24 sabit adimli setPosATL: gorunur sicrama / kayma):
 * Askeri verilen noktaya (ATL) DOGAL yurutup son kismi yumusak kaydirir. Bir kez cagrilir: [_unit, _hedefATL] spawn FUNC(yumusakKay).
 *   1) kalan > 0.9 m ise: doMove (gercek yuruyus animasyonu, forceSpeed -1) hedefe 0.9 m kalana ya da en cok 5 sn
 *   2) kalan 0.1-1.6 m ise: son kisim 'smoothstep' (yavas basla / yavas bitir) egrisiyle setPosATL, hiz ~1.0 m/sn (en az 0.45 sn, en cok 1.6 sn), ~50 Hz adimlar
 *   3) kalan > 1.6 m ise (varamadi): kaydirma YOK (isinlanma gorunmez)
 * Baska bir emirle yer degistiriyorsa (hiz > 2.5 m/sn kaydirma sirasinda) kaydirma iptal.
 *
 * Arguments:
 * 0: Asker <OBJECT>
 * 1: Hedef nokta (ATL) <ARRAY>
 *
 * Return Value: Yok
 * Public: No
*/

params [["_a", objNull, [objNull]], ["_hedef", [], [[]]]];
if (isNull _a || {isPlayer _a}) exitWith {};   // v8.749: oyuncu birimi setPos ile kaydirilmaz (siper oturtma / yapistirma yalniz AI)
// v8.653: baygin / yarali dusen (vanilla revive INCAPACITATED / ACE) asker kaydirilmaz (RPT 27f2781f: 'oturtuldu 12-22 m' satirlari 'unconsciousfacedown' / 'ousrevivedefault' animasyonlu askerlerdi)
private _saglam = { alive _a && {(lifeState _a) in ["HEALTHY", "INJURED"]} && {!(_a getVariable ["ACE_isUnconscious", false])} };
if (isNull _a || {!alive _a} || {_hedef isEqualTo []} || {!(call _saglam)}) exitWith {};
// v8.806 RETREAT CAKISMASI (RPT c69aff1e: retreat kosucularinin %71'i duruyor; yumusakKay'in ilk adimi 'doMove siper noktasi' (5-9 sn yuruyus) + son kaydirma setPosATL retreat emrini ezebiliyordu): retreat / kosucu ise HICBIR sey yapma;
//   yuruyus sirasinda retreat baslarsa bekleme ve per-frame kaydirma da iptal.
private _retM = { ((group _a) getVariable [QGVAR(isRetreating), false]) || {(_a getVariable [QGVAR(forceMove), false]) isEqualTo true} };
if (call _retM) exitWith { [_a, "yumusakKay"] call FUNC(retCakismaSay); };
private _p1 = +_hedef;
_p1 set [2, (getPosATL _a) select 2];
if ((getPosATL _a) distance2D _p1 > 0.9) then {
    _a forceSpeed -1;
    _a setVariable [QGVAR(oturDoMoveT), time];   // v8.708: ters donus kaynak atfi (durumLog): siper noktasina OTUR adiminin kendi doMove'u (RPT 1e81987e: 62 ters donusun 49'u 'belirsiz', ornek SIPER-OTUR 1.93 m ile ayni saniyede MOVE)
    _a doMove _p1;
    private _bit = time + ((((getPosATL _a) distance2D _p1) / 3) max 5) min 9;   // v8.649: uzak siperde sure mesafeye gore (5-9 sn)
    waitUntil { sleep 0.2; !(call _saglam) || {time > _bit} || {((getPosATL _a) distance2D _p1) < 0.9} || {call _retM} };
};
if (!(call _saglam)) exitWith {};
if (call _retM) exitWith { [_a, "yumusakKay"] call FUNC(retCakismaSay); };
// v8.709 SIPER BEKLEMESINI GERI KOY (RPT 1e81987e, Alpha 1-1 Nikolayev: 7:31:12 [SIPER-TUT] doStop -> 7:31:13 [SIPER-OTUR 1.93 m kaldi] ve AYNI SANIYE MOVE): bu fonksiyonun doMove'u siperTut'un doStop beklemesini eziyordu; oturma bitince asker formasyon slotuna donebiliyordu (siperTut'un yazilma nedeni 'git-gel').
//   siperTut beklemesi hala gecerliyse (siperTutBit > time) ve asker kosucu / geri cekilmede degilse doStop yeniden verilir; bitis ve cikis kosullari siperTut'ta (temas bitince / 45 sn) aynen kalir.
if ((_a getVariable [QGVAR(siperTutBit), 0]) > time && {!((_a getVariable [QGVAR(forceMove), false]) isEqualTo true)} && {!((group _a) getVariable [QGVAR(isRetreating), false])}) then { doStop _a; };
_p1 set [2, (getPosATL _a) select 2];
private _p0 = getPosATL _a;
private _d = _p0 distance2D _p1;
if (_d < 0.1 || {_d > 1.6} || {surfaceIsWater _p1}) exitWith {};
private _sure = ((_d / 1.0) max 0.45) min 1.6;
private _t0 = time;
// v8.674 PER-FRAME KAYDIRMA (kullanici: 'siper duzeltme asiri stutterli'; RPT 8f8a8871: 169-175 eszamanli zamanlanmis betik): eskiden 'while + sleep 0.02' ZAMANLANMIS (scheduled) betikte kosuyordu;
//   yuk altinda her betik birkac karede bir sira aldigi icin adimlar duzensiz atliyor (gorunur tirtilma / sicrama). Simdi UNSCHEDULED per-frame handler: her karede bir adim, scheduler'dan bagimsiz.
// v8.834 KAYMA ANIMASYONU (kullanici: 'animasyon bazen oldugu yerde kaliyor ... zorlama cok iyi ama pek akici degil'): son 0.15-1.6 m setPos ile kayarken asker bosta (durus) animasyonuyla KAYIYORDU (yerinde duran animasyon + hareket); simdi kayma suresince yuruyus / emekleme animasyonu oynatilir ve bakis kayma yonune cevrilir
private _kayAn = toLower (animationState _a);
private _kayW = if ((_kayAn find "wrfl") >= 0) then {"Wrfl"} else { if ((_kayAn find "wpst") >= 0) then {"Wpst"} else {""} };
if (_kayW isNotEqualTo "") then {
    _a setDir (_p0 getDir _p1);
    _a playMoveNow (switch (stance _a) do { case "PRONE": {"AmovPpneMrunSras" + _kayW + "Df"}; case "CROUCH": {"AmovPknlMwlkSras" + _kayW + "Df"}; default {"AmovPercMwlkSras" + _kayW + "Df"} });
};
[{
    params ["_args", "_h"];
    _args params ["_a", "_p0", "_p1", "_t0", "_sure"];
    if (isNull _a || {!alive _a} || {!((lifeState _a) in ["HEALTHY", "INJURED"])} || {_a getVariable ["ACE_isUnconscious", false]} || {(group _a) getVariable [QGVAR(isRetreating), false]} || {(_a getVariable [QGVAR(forceMove), false]) isEqualTo true}) exitWith { [_h] call CBA_fnc_removePerFrameHandler; };   // v8.806: retreat baslarsa kaydirma iptal
    private _k = ((time - _t0) / _sure) min 1;
    private _e = _k * _k * (3 - (2 * _k));
    _a setPosATL (_p0 vectorAdd ((_p1 vectorDiff _p0) vectorMultiply _e));
    if (_k >= 1) then { [_h] call CBA_fnc_removePerFrameHandler; };
}, 0, [_a, _p0, _p1, _t0, _sure]] call CBA_fnc_addPerFrameHandler;
