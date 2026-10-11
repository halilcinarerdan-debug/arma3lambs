#include "script_component.hpp"
/*
 * Author: Cinar (ELITE fork)
 * MEVZI KUR (v8.171) — SAVUN plani: grup sektor noktasinda en yakin binaya girer (garrison), bos STATIK silahlari (MG / GMG / AT / havan) kullanir,
 * COMBAT durusu + comelme / siper.
 * Kullanici: "mevzilen dedigim opfor en yakin yerlere gecsin garrison alsin statik silahlari kullansin ve combata gecis cover alsin".
 *
 * Adimlar (tasarim; kitapta sayi yok — MCWP 3-11.1 savunma: MG / AT mevzileri, ates sektoru, bina savunmasi genel ilke):
 *   1) 120 m icinde bos statik silah (gunner yok, kilitli degil, kendi taraf / sivil / bos) -> en yakin MG tipli asker (yoksa en yakin tufekci) yurur ve gunner olur (en cok 2 statik / grup)
 *   2) kalan askerler: sektor noktasinin 150 m icindeki en yakin kapali bina (>= 2 bina pozisyonu) -> tacticsGarrison; bina yoksa sektor yonune bakan comelmis halka
 *   3) grup COMBAT + YELLOW; yaya birimler comelmis (MIDDLE)
 *
 * Arguments:
 * 0: Grup <GROUP>
 * 1: Sektor noktasi <ARRAY>
 * 2: Sektor yonu (derece) <NUMBER>
 *
 * Return Value:
 * [bina <BOOL>, statik <NUMBER>]
 * Public: No
*/

params [["_g", grpNull, [grpNull]], ["_poz", [0, 0, 0], [[]]], ["_yon", 0, [0]]];
if (isNull _g || {!local _g}) exitWith {[false, 0]};
private _taraf = side _g;
private _rolFn = missionNamespace getVariable ["lambs_danger_fnc_getUnitRole", {"RIFLE"}];
private _yaya = (units _g) select {alive _x && {isNull objectParent _x} && {!(time < (_x getVariable [QGVAR(tcccBusy), 0]))}};
if (_yaya isEqualTo []) exitWith {[false, 0]};

// ---- 1) statik silahlar
private _statikler = (_poz nearEntities [["StaticWeapon"], 120]) select {
    alive _x && {isNull (gunner _x)} && {(locked _x) < 2} && {(side _x) in [_taraf, civilian, sideEmpty]}
    && {!(_x getVariable [QGVAR(mevziStatik), false])} && {(_x emptyPositions "gunner") > 0}
};
_statikler = [_statikler, [], {_x distance2D _poz}, "ASCEND"] call BIS_fnc_sortBy;
private _stSay = 0;
{
    if (_stSay >= 2) exitWith {};
    private _st = _x;
    private _aday = _yaya select {!(_x getVariable [QGVAR(mevziStatikGorev), false]) && {_x isNotEqualTo (leader _g)}};
    if (_aday isEqualTo []) exitWith {};
    private _mgler = _aday select {(([_x] call _rolFn) in ["MG", "AMG", "MACHINEGUNNER"]) || {((toLower (primaryWeapon _x)) find "mg") >= 0}};
    if (_mgler isEqualTo []) then { _mgler = _aday; };
    _mgler = [_mgler, [], {_x distance2D _st}, "ASCEND"] call BIS_fnc_sortBy;
    private _u = _mgler select 0;
    _u setVariable [QGVAR(mevziStatikGorev), true];
    _st setVariable [QGVAR(mevziStatik), true];
    _yaya = _yaya - [_u];
    _stSay = _stSay + 1;
    diag_log format ["[MEVZI] %1 | %2 -> statik silah %3 (%4 m)", groupId _g, name _u, getText (configOf _st >> "displayName"), round (_u distance2D _st)];
    [_u, _st, _yon] spawn {
        params ["_u", "_st", "_yon"];
        _u assignAsGunner _st;
        _u doMove (getPosATL _st);
        private _t = time + 60;
        waitUntil { sleep 1; !alive _u || {!alive _st} || {(_u distance2D _st) < 7} || {time > _t} };
        if (alive _u && {alive _st} && {isNull (gunner _st)} && {(_u distance2D _st) < 25}) then {
            _u moveInGunner _st;
            _u disableAI "PATH";
            _st setDir _yon;
        } else {
            _u setVariable [QGVAR(mevziStatikGorev), nil];
            _u doFollow (leader (group _u));
        };
    };
} forEach _statikler;

// ---- 2) en yakin kapali bina
private _binalar = (nearestObjects [_poz, ["House"], 150]) select {(count (_x buildingPos -1)) >= 2};
_binalar = [_binalar, [], {_x distance2D _poz}, "ASCEND"] call BIS_fnc_sortBy;
private _bina = false;
if (_binalar isNotEqualTo [] && {_yaya isNotEqualTo []}) then {
    _bina = [_g, getPosATL (_binalar select 0), _yaya] call FUNC(tacticsGarrison);
    if (isNil "_bina") then { _bina = false; };
};
if (!_bina) then {
    // v8.175: bina yok -> her asker sektor noktasina en yakin AYRI siper objesine (agac / kaya / duvar / bina / cali / enkaz) gider, objenin tehdit yonune GORE ARKASINA (kullanici: "objelere cover yok"); obje yoksa sektor yonune bakan comelmis halka
    private _adayObj = nearestTerrainObjects [_poz, ["TREE", "ROCK", "WALL", "BUILDING", "HIDE", "BUSH", "SMALL TREE"], 60, true, true];
    _adayObj = _adayObj + ((_poz nearEntities [["Car", "Tank", "Wreck"], 50]) select {!(alive _x) || {(count (crew _x)) isEqualTo 0}});
    _adayObj = [_adayObj, [], {_x distance2D _poz}, "ASCEND"] call BIS_fnc_sortBy;
    private _kullanilan = [];
    {
        private _u = _x;
        private _o = objNull;
        { if !(_x in _kullanilan) exitWith { _o = _x; }; } forEach _adayObj;
        if (!isNull _o) then {
            _kullanilan pushBack _o;
            private _tp = (getPosATL _o) getPos [2.0, _yon + 180];
            if (!surfaceIsWater _tp) then {
                _u setVariable [QGVAR(tasimaBekle), nil];
                _u enableAI "PATH";
                _u doMove _tp;
                [_u, _yon, _poz] spawn {
                    params ["_u", "_yon", "_poz"];
                    private _t = time + 25;
                    waitUntil { sleep 1; !alive _u || {unitReady _u} || {time > _t} };
                    if (alive _u) then {
                        doStop _u;
                        _u setUnitPos "MIDDLE";
                        _u doWatch (_poz getPos [150, _yon]);
                    };
                };
            } else {
                doStop _u;
                _u doWatch (_poz getPos [150, _yon + (_forEachIndex * 25) - 40]);
            };
        } else {
            doStop _x;
            _x doWatch (_poz getPos [150, _yon + (_forEachIndex * 25) - 40]);
        };
    } forEach _yaya;
};

// ---- 3) COMBAT + comelme (garrison enableAttack'i kapatir; gecikmeli geri alinir)
_g setBehaviour "COMBAT";
_g setCombatMode "YELLOW";
{ if (alive _x && {isNull objectParent _x}) then { _x setUnitPos "MIDDLE"; }; } forEach (units _g);
diag_log format ["[MEVZI] %1 | mevzi kuruldu: bina %2 (%3 aday) | statik %4 | COMBAT", groupId _g, _bina, count _binalar, _stSay];
[_bina, _stSay]
