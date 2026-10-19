#include "script_component.hpp"
/*
 * Author: Cinar (ELITE fork)
 * MEVZI STATIK SILAH (v8.256) — kullanici (RPT e31bd8bd): "statik silahlari (DShK) kullanmadilar". SAVUN planinda gruplar hendege yerlesince (fnc_hendekYerles) bos statik silahlara bakilmiyordu; yalniz bina / siper modu (fnc_mevziKur) bakiyordu.
 * Kural (SAVUN plani MEVZI -> BEKLE gecisinde grup basina, sonra BEKLE'de 45 sn'de bir doldurma): objektife <= yaricap (plan 'mevziYar', yoksa 300 m) icindeki BOS, kilitsiz, ayni taraf / sivil / bos StaticMGWeapon / StaticGrenadeLauncher / StaticATWeapon
 *   (topcu / SAM / radar / tasarlayici haric), grubun liderine <= 250 m ise en yakin MG tipli (yoksa tufekci; lider ve hekim haric) asker yurur ve nisanci olur (grup basina en cok 2 statik; her statige tek asker). Asker oldugunde ya da gunner'i yoksa
 *   (statik 'mevziStatikU' = atanan asker) baska bir asker doldurur. Silah tehdit yonune cevrilir, nisanci PATH kapatir; 25 m icindeki hendek noktasindan ayrilmak mevzi kilidince (fnc_mevziKilit) 'statik gorev' bayragiyla muaf.
 * Log: [MEVZI-STATIK] (ilk 40). Kapatma: lambs_danger_mevziStatikOff = true.
 *
 * Arguments:
 * 0: Grup <GROUP>
 * 1: Objektif / mevzi merkezi <ARRAY>
 * 2: Bakis yonu (derece) <NUMBER>
 * 3: Arama yaricapi (m) <NUMBER>
 *
 * Return Value: Atanan statik sayisi <NUMBER>
 * Public: No
*/

params [["_g", grpNull, [grpNull]], ["_poz", [0, 0, 0], [[]]], ["_yon", 0, [0]], ["_yar", 300, [0]]];
if (isNull _g || {!local _g} || {missionNamespace getVariable ["lambs_danger_mevziStatikOff", false]}) exitWith {0};
private _taraf = side _g;
private _rolFn = missionNamespace getVariable ["lambs_danger_fnc_getUnitRole", {"RIFLE"}];
private _lider = leader _g;
if (isNull _lider) exitWith {0};
private _tumSt = _poz nearEntities [["StaticMGWeapon", "StaticGrenadeLauncher", "StaticATWeapon"], _yar + 50];
// tani: yaricapta baska turde statik silah var mi (RHS statik sinifi beklenen turlerden degilse burada gorunur) - 120 sn'de bir
if (_tumSt isEqualTo [] && {(time - (missionNamespace getVariable ["lambs_danger_mevziStatikTaniT", -999])) > 120}) then {
    lambs_danger_mevziStatikTaniT = time;
    private _digSt = (_poz nearEntities [["StaticWeapon"], _yar + 50]) apply { format ["%1 (%2)", typeOf _x, [_x isKindOf "StaticMGWeapon", _x isKindOf "StaticAAWeapon"] joinString "/"] };
    if (_digSt isNotEqualTo []) then { diag_log format ["[MEVZI-STATIK] %1 | yaricapta (%2 m) StaticMG / GL / AT YOK ama baska statik var: %3 (MG/AA bayragi)", groupId _g, round (_yar + 50), _digSt select [0, 6]]; };
};
// olu nisanci cesedi koltugu tikamasin
{ private _gu = gunner _x; if (!isNull _gu && {!alive _gu}) then { moveOut _gu; }; } forEach _tumSt;
// bu grubun hala yasayan statik nisancilari (grup basina en cok 2)
private _verilen = {
    private _uu = _x getVariable [QGVAR(mevziStatikU), objNull];
    !isNull _uu && {alive _uu} && {(group _uu) isEqualTo _g}
} count _tumSt;
if (_verilen >= 2) exitWith {0};

private _statikler = (_tumSt select {_x distance2D _poz <= _yar}) select {
    alive _x && {isNull (gunner _x)} && {(locked _x) < 2} && {(side _x) in [_taraf, civilian, sideEmpty]}
    && {(_x emptyPositions "gunner") > 0} && {(getNumber (configOf _x >> "artilleryScanner")) <= 0}
    && {((_x distance2D _lider) <= 250)}
    && {(isNull (_x getVariable [QGVAR(mevziStatikU), objNull])) || {!alive (_x getVariable [QGVAR(mevziStatikU), objNull])}}
};
if (_statikler isEqualTo []) exitWith {0};
_statikler = [_statikler, [], {_x distance2D _lider}, "ASCEND"] call BIS_fnc_sortBy;

private _yaya = (units _g) select {
    alive _x && {isNull objectParent _x} && {!isPlayer _x} && {(lifeState _x) in ["HEALTHY", "INJURED"]}
    && {!(_x getVariable [QGVAR(mevziStatikGorev), false])} && {_x isNotEqualTo _lider} && {(([_x] call _rolFn) isNotEqualTo "MEDIC")}
};
private _say = 0;
if (isNil "lambs_danger_mevziStatikLogN") then { lambs_danger_mevziStatikLogN = 0; };
{
    if ((_verilen + _say) >= 2 || {_yaya isEqualTo []}) exitWith {};
    private _st = _x;
    private _mgler = _yaya select {(([_x] call _rolFn) in ["MG", "AMG", "MACHINEGUNNER"]) || {((toLower (primaryWeapon _x)) find "mg") >= 0}};
    private _aday = if (_mgler isEqualTo []) then {_yaya} else {_mgler};
    _aday = [_aday, [], {_x distance2D _st}, "ASCEND"] call BIS_fnc_sortBy;
    private _u = _aday select 0;
    _u setVariable [QGVAR(mevziStatikGorev), true];
    _st setVariable [QGVAR(mevziStatikU), _u];
    _yaya = _yaya - [_u];
    _say = _say + 1;
    if (lambs_danger_mevziStatikLogN < 40) then {
        lambs_danger_mevziStatikLogN = lambs_danger_mevziStatikLogN + 1;
        diag_log format ["[MEVZI-STATIK] %1 | %2 (%3) -> %4 (%5 m, grup liderine %6 m)", groupId _g, name _u, [_u] call _rolFn, getText (configOf _st >> "displayName"), round (_u distance2D _st), round (_st distance2D _lider)];
    };
    [_u, _st, _yon] spawn {
        params ["_u", "_st", "_yon"];
        _u enableAI "PATH"; _u enableAI "MOVE";
        _u assignAsGunner _st;
        _u doMove (getPosATL _st);
        private _t = time + 75;
        waitUntil { sleep 1; !alive _u || {!alive _st} || {(_u distance2D _st) < 6} || {time > _t} };
        if (alive _u && {alive _st} && {isNull (gunner _st)} && {(_u distance2D _st) < 30}) then {
            _u moveInGunner _st;
            _u disableAI "PATH";
            _st setDir _yon;
        } else {
            _u setVariable [QGVAR(mevziStatikGorev), nil];
            _st setVariable [QGVAR(mevziStatikU), nil];
            if (alive _u) then { _u doFollow (leader (group _u)); };
        };
    };
} forEach _statikler;
_say
