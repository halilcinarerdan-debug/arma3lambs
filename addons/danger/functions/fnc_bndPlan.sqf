#include "script_component.hpp"
/*
 * Author: Cinar (ELITE fork)
 * PLANLI BOUNDING (v8.658; kullanici: 'boundingi kesinlikle planli yap'): bounding basinda ve hedef degisince grubun hedefe dogru SIPER ZINCIRI onceden planlanir.
 *   - Lider konumundan hedefe (ortulu rota sapma acisi ile) en cok 8 bacak: her bacak ~40 m (en cok), bitis mesafesinden (bndBitisM) once durur
 *   - Her bacak merkezi icin findCover (ADVANCE, 22 m, bacak merkezi cevresinde): bulunursa o SIPER noktasi, yoksa bacak merkezi (arazi); noktalar hedefe >= 6 m yaklasmali
 *   - Plan grup degiskeninde (QGVAR(bndPlan) = [[poz, 'SIPER' / 'ARAZI'], ...], QGVAR(bndPlanI) = gecerli bacak): fnc_tacticsBounding _kosanHareket kosucuyu BU noktaya gonderir (kosucu ciftinde yanal +-2.5 m); gecerli degilse (menzil / kazanc) eski dinamik secim
 *   - Yenileme: hedef 40 m'den fazla oynarsa ya da plan 90 sn'den eskiyse; bacak noktasina 8 m yaklasan kosucu bir sonraki bacaga gecer
 *   Log: [BND-PLAN] bacak sayisi / siper-arazi / xy zinciri; [BND-PLAN-ADIM] her planli sicrama.
 *   CBA: lambs_danger_bndPlanli (varsayilan ACIK)
 *
 * Arguments:
 * 0: Grup <GROUP>
 * 1: Hedef konumu <ARRAY>
 * 2: Rota sapma acisi (derece) <NUMBER> (varsayilan 0)
 *
 * Return Value: Plan <ARRAY>
 * Public: No
*/

params [["_g", grpNull, [grpNull]], ["_hedef", [], [[]]], ["_rota", 0, [0]]];
if (isNull _g || {_hedef isEqualTo []}) exitWith {[]};
private _l = leader _g;
if (isNull _l || {!alive _l}) exitWith {[]};
private _bitis = [_g, "bndBitisM", 40] call FUNC(dk);
private _legMax = 40;
private _cur = getPosATL _l;
// v8.660 ILERLEME KALICI (RPT c46fdbc6: hedef kaydikca plan sifirlaniyor, grup ilerlemiyordu): grubun EN ILERI ulastigi bacak noktasi (QGVAR(bndPlanSon)) lider noktasindan hedefe >= 15 m yakin ve 250 m icindeyse plan oradan baslar
private _son = _g getVariable [QGVAR(bndPlanSon), []];
if (_son isNotEqualTo [] && {(_son distance2D _hedef) < ((_cur distance2D _hedef) - 15)} && {(_son distance2D _cur) < 250}) then { _cur = +_son; };
private _plan = [];
private _sipN = 0;
for "_i" from 1 to 8 do {
    private _kal = _cur distance2D _hedef;
    if (_kal <= (_bitis + 12)) exitWith {};
    private _adim = _legMax min (_kal - _bitis - 5);
    if (_adim < 10) exitWith {};
    private _dir = (_cur getDir _hedef) + (_rota max -45 min 45);
    private _merkez = _cur getPos [_adim, _dir];
    if (surfaceIsWater _merkez) then { _merkez = _cur getPos [_adim * 0.6, _cur getDir _hedef]; };
    private _pt = _merkez;
    private _ad = "ARAZI";
    private _cvr = [_l, _hedef, 22, "ASCEND", 4, "ADVANCE", _merkez] call EFUNC(main,findCover);
    if (_cvr isNotEqualTo []) then {
        private _cp = (_cvr select 0) select 0;
        if (!surfaceIsWater _cp && {(_cp distance2D _hedef) < ((_cur distance2D _hedef) - 6)}) then { _pt = _cp; _ad = "SIPER"; _sipN = _sipN + 1; };
    };
    if (surfaceIsWater _pt) exitWith {};
    _plan pushBack [_pt, _ad];
    _cur = _pt;
};
_g setVariable [QGVAR(bndPlan), _plan];
_g setVariable [QGVAR(bndPlanI), 0];
_g setVariable [QGVAR(bndPlanHedef), +_hedef];
_g setVariable [QGVAR(bndPlanT), time];
if ((missionNamespace getVariable ["lambs_danger_bndPlanLogN", 0]) < 25) then {
    missionNamespace setVariable ["lambs_danger_bndPlanLogN", (missionNamespace getVariable ["lambs_danger_bndPlanLogN", 0]) + 1];
    diag_log format ["[BND-PLAN] %1 | hedef %2 m | %3 bacak (siper %4 / arazi %5) | bitis %6 m | zincir xy %7", groupId _g, round ((getPosATL _l) distance2D _hedef), count _plan, _sipN, (count _plan) - _sipN, round _bitis, _plan apply { (_x select 0) select [0, 2] apply { round _x } }];
};
_plan
