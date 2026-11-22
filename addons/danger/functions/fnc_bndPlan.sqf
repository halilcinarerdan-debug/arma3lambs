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
// v8.735 2) ROTA RISKI (bounding bacaklari): findCover'in 4 adayi arasindan, bir onceki noktadan o adaya giden hattin dusman goz noktalarindan (hedef + olasi siper noktalari) EN GIZLI olani secilir (CBA rotaRiski); eskiden ilk aday
private _rotaOn = missionNamespace getVariable ["lambs_danger_rotaRiski", true];
private _rAg = (([_l, "rotaRiskAgirlik", 2] call FUNC(profilDeger)) max 0) min 8;   // v8.738: lider cevre profiline gore
private _eyes = [[AGLToASL [_hedef select 0, _hedef select 1, ((_hedef param [2, 0]) max 0) + 1.6], 1]];
if (_rotaOn) then { { _eyes pushBack [AGLToASL [_x select 0, _x select 1, 1.1], 0.5]; } forEach ([_hedef, _cur, 3, 15] call FUNC(dusmanSiperKumesi)); };
private _riskEski = 0;
private _riskYeni = 0;
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
        private _bestP = [];
        private _bestR = 1e9;
        private _ilkR = -1;
        {
            private _cp = _x select 0;
            if (!surfaceIsWater _cp && {(_cp distance2D _hedef) < ((_cur distance2D _hedef) - 6)}) then {
                private _risk = if (_rotaOn) then { [_cur, _cp, _eyes, objNull] call FUNC(rotaRiski) } else { 0 };
                if (_ilkR < 0) then { _ilkR = _risk; };
                if (_risk < _bestR) then { _bestR = _risk; _bestP = _cp; };
            };
        } forEach _cvr;
        if (_bestP isNotEqualTo []) then {
            _pt = _bestP; _ad = "SIPER"; _sipN = _sipN + 1;
            _riskEski = _riskEski + (_ilkR max 0) * _rAg;
            _riskYeni = _riskYeni + _bestR * _rAg;
        };
    };
    // v8.756 VARIS NOKTASINI SIPERE OTURT (kullanici: '1 yap'): bacak noktasi acikta kalmasin; R (12 m) icinde sert nesnenin dusmana gore ARKASI gizli + mermi durdurucu ise oraya kaydirilir (ilerleme >= 6 m korunur)
    if (missionNamespace getVariable ["lambs_danger_bndSiperSnap", true]) then {
        private _from = _cur;
        private _snR = ((missionNamespace getVariable ["lambs_danger_bndSiperSnapM", 12]) max 4) min 25;
        private _sn = [_pt, _hedef, _snR, { params ["_c"]; (_c distance2D _hedef) < ((_from distance2D _hedef) - 6) }] call FUNC(siperSnap);
        private _sy = missionNamespace getVariable ["lambs_danger_snapSay", createHashMap];
        missionNamespace setVariable ["lambs_danger_snapSay", _sy];
        _sy set ["bacak_aranan", (_sy getOrDefault ["bacak_aranan", 0]) + 1];
        if (_sn isNotEqualTo []) then {
            _sy set ["bacak_bulunan", (_sy getOrDefault ["bacak_bulunan", 0]) + 1];
            private _ln = missionNamespace getVariable ["lambs_danger_snapLogN", 0];
            if (_ln < 40) then { missionNamespace setVariable ["lambs_danger_snapLogN", _ln + 1]; diag_log format ["[SIPER-SNAP] bacak | %1 | %2 -> %3 | %4 m kaydirildi (%5)", groupId _g, _ad, "SIPER", round (_pt distance2D _sn), ["arazi", "siper"] select (_ad isEqualTo "SIPER")]; };
            if (_ad isNotEqualTo "SIPER") then { _sipN = _sipN + 1; }; _pt = _sn; _ad = "SIPER";
        };
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
    diag_log format ["[BND-PLAN] %1 | hedef %2 m | %3 bacak (siper %4 / arazi %5) | bitis %6 m | zincir xy %7 | rota riski (siper bacaklari, m-esdeger): ilk aday %8 -> secilen %9", groupId _g, round ((getPosATL _l) distance2D _hedef), count _plan, _sipN, (count _plan) - _sipN, round _bitis, _plan apply { (_x select 0) select [0, 2] apply { round _x } }, _riskEski toFixed 1, _riskYeni toFixed 1];
};
_plan
