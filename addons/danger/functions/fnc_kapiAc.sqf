#include "script_component.hpp"
/*
 * Author: Cinar (ELITE fork)
 * KAPI / GECIT ACMA (v8.506; kullanici RPT 2026-11-12: [DUVAR-KORUMA] NetFence_02 gate / rhs fence door gate / village_house_03 'icinden gecmeye calisti' + asker kapiya bakip kaliyor).
 * AI kapali kapi / kapiyi yol sayiyor ama acmiyor: kapida takilir, kapiya bakar, duvar korumasi geri alir. Bu fonksiyon yakin nesnenin KAPI / GECIT animasyon kaynaklarini (CfgVehicles >> AnimationSources:
 * adinda door / gate gecen, handle / lock / sound / trigger olmayan) acar. Kilitli kapiya (bis_disabled_<Door_N> = 1) dokunmaz. Evlerde yalniz askere yakin kapi (Door_N_trigger bellek noktasi <= menzil),
 * hafiza noktasi olmayan nesnede (cit kapisi) nesne merkezi <= 6 m ise acilir. Acilan kapi ~20 sn sonra, yakininda (6 m) asker yoksa kapanir (yoksa 10 sn ertelenir, en cok 6 kez).
 * Cagiranlar: fnc_kapiBekci (yuruyen askerin onu), fnc_moveAssist (duvar korumasi vurdugu nesne). Kapatma: lambs_danger_kapiAcOff = true.
 *
 * Arguments:
 * 0: Nesne <OBJECT>
 * 1: Asker <OBJECT>
 * 2: Menzil (m) <NUMBER> (varsayilan 2.5)
 *
 * Return Value: acilan kapi sayisi <NUMBER>
 * Public: No
*/

params [["_o", objNull, [objNull]], ["_u", objNull, [objNull]], ["_menzil", 2.5, [0]]];
if (isNull _o || {isNull _u} || {_o isKindOf "AllVehicles"} || {missionNamespace getVariable ["lambs_danger_kapiAcOff", false]}) exitWith {0};

if (isNil "lambs_danger_kapiTip") then { lambs_danger_kapiTip = createHashMap; };
private _tip = typeOf _o;
if (_tip isEqualTo "") exitWith {0};   // harita nesnesi (sinifi yok): animasyon kaynagi okunamaz
private _kaynaklar = lambs_danger_kapiTip get _tip;
if (isNil "_kaynaklar") then {
    _kaynaklar = [];
    private _cfg = configOf _o >> "AnimationSources";
    if (isClass _cfg) then {
        {
            private _ad = configName _x;
            private _l = toLower _ad;
            if (((_l find "door") >= 0 || {(_l find "gate") >= 0})
                && {(_l find "handle") < 0} && {(_l find "lock") < 0} && {(_l find "sound") < 0} && {(_l find "trigger") < 0} && {(_l find "nosound") < 0}) then {
                _kaynaklar pushBack _ad;
            };
        } forEach ("true" configClasses _cfg);
    };
    lambs_danger_kapiTip set [_tip, _kaynaklar];
};
if (_kaynaklar isEqualTo []) exitWith {0};

private _acilan = [];
{
    private _ad = _x;
    if ((_o animationSourcePhase _ad) < 0.3) then {
        private _taban = if (((count _ad) > 7) && {(toLower (_ad select [(count _ad) - 7])) isEqualTo "_source"}) then { _ad select [0, (count _ad) - 7] } else { _ad };
        if ((_o getVariable [format ["bis_disabled_%1", _taban], 0]) isNotEqualTo 1) then {
            private _np = _o selectionPosition [_taban + "_trigger", "Memory"];
            private _yakin = if (_np isNotEqualTo [0, 0, 0]) then {
                (_u distance2D (_o modelToWorld _np)) <= _menzil
            } else {
                (_u distance2D _o) <= 6
            };
            if (_yakin) then {
                _o animateSource [_ad, 1];
                _acilan pushBack _ad;
            };
        };
    };
} forEach _kaynaklar;

if (_acilan isNotEqualTo []) then {
    if (isNil "lambs_danger_kapiLogN") then { lambs_danger_kapiLogN = 0; };
    if (lambs_danger_kapiLogN < 30) then {
        lambs_danger_kapiLogN = lambs_danger_kapiLogN + 1;
        diag_log format ["[KAPI-AC] %1 | %2 | %3 acildi (%4)", groupId (group _u), name _u, _tip, _acilan joinString ","];
    };
    // kapat: ~20 sn sonra yakinda asker yoksa (fnc_kapiKapat; doluysa ertelenir)
    [FUNC(kapiKapat), [_o, _acilan, 0], 20] call CBA_fnc_waitAndExecute;
};
count _acilan
