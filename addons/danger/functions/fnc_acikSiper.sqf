#include "script_component.hpp"
/*
 * Author: Cinar (ELITE fork)
 * ACIKTA KALAN ASKERI YAKINDAKI BINAYA SOK (v8.303; kullanici: 'arkada ev var adam acikta kaliyor ama evi siper olarak kullanmiyor').
 * Cagiran: fnc_coverHug — temasta, duran, acikta (3 yukseklikte dusmandan sert yuzey yok ya da 6 m'den uzak) asker icin.
 *   1) 28 m icindeki girilebilir binalarin (buildingPos) noktalari taranir
 *   2) aday: dusmanin gozunden o noktaya hat bina tarafindan KESILIYOR (lineIntersects) + dusmana 8 m'den fazla yaklasmaz + baska askere ayrilmis degil (1.8 m, 30 sn)
 *   3) en yakin aday: doMove, FULL hiz, 15 sn taktik kilidi (diger hareket arbitrajlari ezmesin); asker basina 25 sn'de bir
 * ATLANIR: bounding / taktik yurutenler (hucumda ilerlemek bilincli), CBA kapatma: lambs_danger_acikSiperOff = true
 * Log: [ACIK-SIPER]
 *
 * Arguments:
 * 0: Asker <OBJECT>
 * 1: En yakin bilinen dusman <OBJECT>
 *
 * Return Value: Yonlendirildi mi <BOOL>
 * Public: No
*/

params [["_u", objNull, [objNull]], ["_en", objNull, [objNull]]];
if (isNull _u || {isNull _en} || {missionNamespace getVariable ["lambs_danger_acikSiperOff", false]}) exitWith {false};
if (time < (_u getVariable [QGVAR(acikSiperT), 0])) exitWith {false};
_u setVariable [QGVAR(acikSiperT), time + 25];
private _g = group _u;
if ((_g getVariable [QGVAR(isBounding), false]) || {_g getVariable [QGVAR(isExecutingTactic), false]} || {_g getVariable [QGVAR(isRetreating), false]}) exitWith {false};

private _p = getPosATL _u;
private _eASL = eyePos _en;
private _ed = _u distance2D _en;
private _dolu = missionNamespace getVariable ["lambs_danger_acikSiperDolu", []];
_dolu = _dolu select {(time - (_x select 1)) < 30};

private _en_iyi = [];
private _enD = 1e9;
private _binaAd = "";
{
    private _b = _x;
    {
        private _bp = _x;
        private _d = _u distance2D _bp;
        if (_d <= 28 && {_d < _enD} && {(_bp distance2D _en) >= (_ed - 8)} && {(_dolu findIf {((_x select 0) distance2D _bp) < 1.8}) < 0}) then {
            if (lineIntersects [_eASL, (AGLToASL _bp) vectorAdd [0, 0, 1.3], _en, _u]) then {
                _enD = _d;
                _en_iyi = _bp;
                _binaAd = typeOf _b;
            };
        };
    } forEach (_b buildingPos -1);
} forEach ((nearestObjects [_p, ["House"], 30]) select {(count (_x buildingPos -1)) > 0});

if (_en_iyi isEqualTo []) exitWith {false};

_dolu pushBack [_en_iyi, time];
missionNamespace setVariable ["lambs_danger_acikSiperDolu", _dolu];
_u setVariable [QGVAR(taktikKilit), time + 15];
_u forceSpeed -1;
_u setSpeedMode "FULL";
_u setUnitPos "AUTO";
_u doMove _en_iyi;
if ((missionNamespace getVariable ["lambs_danger_acikSiperLogN", 0]) < 40) then {
    missionNamespace setVariable ["lambs_danger_acikSiperLogN", (missionNamespace getVariable ["lambs_danger_acikSiperLogN", 0]) + 1];
    diag_log format ["[ACIK-SIPER] %1 | %2 | dusman %3 m acikta -> bina %4 (%5 m, dusmandan gizli nokta)", groupId _g, name _u, round _ed, _binaAd, round _enD];
};
true
