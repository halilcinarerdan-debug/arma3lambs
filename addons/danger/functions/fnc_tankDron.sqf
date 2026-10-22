#include "script_component.hpp"
/*
 * Author: Cinar (ELITE fork)
 * TANK DRON SAVUNMASI (v8.280; kullanici: 'tanklar drona karsi tavir takinsin, daha koordine ve zeki olsunlar'). FPV-AT kamikaze dronlari (Crocus AT) zirhin motor / ust bolgesine dalar.
 * Mevzideki / hareket halindeki tank (fnc_planZirh, 3 sn'de bir):
 *   - tehdit: 700 m icinde, <= 200 m yukseklikte, DUSMAN (getFriend < 0.6) dron; grup lideri bilir (knowsAbout > 0.2) YA DA yakin dost tankin 20 sn icindeki dron uyarisi (koordinasyon)
 *   - 1) UYARI: yakindaki (<= 900 m) dost zirhli araclara dron konumu / zaman bildirilir (lambs_danger_tankDronUyari)
 *   - 2) YON: tehdit <= 600 m ise murettebat dronun gelis yonune doWatch (taret ve komutan dronu izler)
 *   - 3) ATES: <= 500 m ise taret disindaki (komutan / nisanci) MG'li murettebat doTarget + doFire (koaksiyel / komutan makineli); 3 sn'de bir
 *   - 4) DUMAN: kamikaze tur, <= 260 m ve yaklasiyor (kapanma hizi > 3 m/sn) ise taret donduktan 1.5 sn sonra fnc_aracDuman (gorus hattini keser; 30 sn bekleme zaten fnc_aracDuman'da)
 *   - 5) KACINMA: <= 130 m ve kapanma hizi > 8 m/sn ve tank hareket edebilir ise 30 m yana (dronun gelis yonune dik) atilir, 7 sn sonra durur (mevzi kilidi varsa yeniden kilitlenir). 25 sn bekleme.
 * Kapatma: lambs_danger_tankDronOff = true.  Log: [TANK-DRON]
 *
 * Arguments:
 * 0: Grup <GROUP>
 * 1: Arac <OBJECT>
 * 2: Surucu <OBJECT>
 *
 * Return Value: Tepki verildi mi <BOOL>
 * Public: No
*/

params ["_g", "_v", "_d"];
if (missionNamespace getVariable ["lambs_danger_tankDronOff", false]) exitWith {false};
if (isNull _v || {!alive _v} || {!local _v}) exitWith {false};
if ((time - (_v getVariable [QGVAR(tankDronT), -99])) < 3) exitWith {false};
_v setVariable [QGVAR(tankDronT), time];

private _l = leader _g;
private _taraf = side _g;
private _dronlar = (_v nearEntities ["Air", 700]) select {
    unitIsUAV _x && {alive _x} && {((getPosATL _x) select 2) <= 200}
    && {(_taraf getFriend (side (group (effectiveCommander _x)))) < 0.6}
    && {(!isNull _l && {(_l knowsAbout _x) > 0.2}) || {(time - (_v getVariable [QGVAR(tankDronUyari), [-99]] select 0)) < 20}}
};
// koordinasyon: dost tankin uyarisi (dron henuz bilinmiyor olsa da)
private _dr = objNull;
if (_dronlar isNotEqualTo []) then {
    _dr = ([_dronlar, [], {_x distance _v}, "ASCEND"] call BIS_fnc_sortBy) select 0;
};
if (isNull _dr) exitWith {false};

private _dist = _v distance _dr;
private _tip = [_dr] call FUNC(ihaTip);
private _kamikaze = _tip in ["FPV-AT", "FPV-AP", "BOMBA"] || {((_dr weaponsTurret [-1]) isNotEqualTo [])};
// kapanma hizi: dronun hizinin tanka dogru bileseni
private _yonT = (getPosASL _v) vectorDiff (getPosASL _dr);
private _kap = if ((vectorMagnitude _yonT) > 1) then { (velocity _dr) vectorDotProduct (vectorNormalized _yonT) } else {0};

// 1) UYARI: yakin dost zirhli araclar
{
    if (_x isNotEqualTo _v && {local _x}) then {
        _x setVariable [QGVAR(tankDronUyari), [time, getPosATL _dr]];
    };
} forEach ((_v nearEntities [["Tank", "Wheeled_APC_F", "Tracked_APC_F"], 900]) select {(side (group (effectiveCommander _x))) isEqualTo _taraf});

private _eylem = [];
// 2) YON: murettebat dronu izler
if (_dist <= 600) then {
    { if (alive _x) then { _x doWatch _dr; }; } forEach (crew _v);
    _eylem pushBack "YON";
};
// 3) ATES: komutan / nisanci makineli (taret ana topu disinda MG)
if (_dist <= 500) then {
    private _n = 0;
    {
        private _u = _x;
        if (alive _u && {!isPlayer _u}) then {
            private _yol = _v unitTurret _u;
            private _silahlar = (_v weaponsTurret _yol) select {
                private _a = getText (configFile >> "CfgAmmo" >> getText (configFile >> "CfgMagazines" >> ((getArray (configFile >> "CfgWeapons" >> _x >> "magazines")) param [0, ""]) >> "ammo") >> "simulation");
                (toLower _a) in ["shotbullet", "shotsubmunitions", "shotbullet"]
            };
            if (_silahlar isNotEqualTo []) then {
                (group _u) reveal [_dr, 4];
                _u doTarget _dr;
                _u doFire _dr;
                _n = _n + 1;
            };
        };
    } forEach ([(commander _v), (gunner _v)] select {!isNull _x});
    if (_n > 0) then { _eylem pushBack format ["ATES(%1)", _n]; };
};
// 4) DUMAN
if (_kamikaze && {_dist <= 260} && {_kap > 3}) then {
    if ((time - (_v getVariable [QGVAR(tankDronDumanT), -99])) > 30) then {
        _v setVariable [QGVAR(tankDronDumanT), time];
        [{ params ["_vv"]; if (!isNull _vv && {alive _vv}) then { [_vv] call FUNC(aracDuman); }; }, [_v], 1.5] call CBA_fnc_waitAndExecute;
        _eylem pushBack "DUMAN";
    };
};
// 5) KACINMA
if (_kamikaze && {_dist <= 130} && {_kap > 8} && {canMove _v} && {(time - (_v getVariable [QGVAR(tankDronKacT), -99])) > 25}) then {
    _v setVariable [QGVAR(tankDronKacT), time];
    private _gelisDir = _v getDir _dr;
    private _yan = _v getPos [30, _gelisDir + (selectRandom [90, -90])];
    if (!surfaceIsWater _yan) then {
        _d enableAI "PATH"; _d enableAI "MOVE"; _d forceSpeed -1;
        _d doMove _yan;
        _v setVariable [QGVAR(tankManevraT), time];   // planZirh yeniden yonlendirmesi 20 sn susar
        _eylem pushBack "KACINMA";
        [{
            params ["_vv", "_dd", "_g2"];
            if (isNull _vv || {!alive _vv} || {isNull _dd} || {!alive _dd}) exitWith {};
            doStop _dd;
            if (_g2 getVariable ["lambs_danger_planZirhKilit", false]) then { _dd disableAI "MOVE"; };
        }, [_v, _d, _g], 7] call CBA_fnc_waitAndExecute;
    };
};

if (_eylem isNotEqualTo [] && {(time - (_v getVariable [QGVAR(tankDronLogT), -99])) > 8}) then {
    _v setVariable [QGVAR(tankDronLogT), time];
    diag_log format ["[TANK-DRON] %1 | %2 | dron %3 (%4) %5 m | kapanma %6 m/sn | yukseklik %7 m | tepki: %8", groupId _g, getText (configOf _v >> "displayName"), typeOf _dr, _tip, round _dist, _kap toFixed 1, round ((getPosATL _dr) select 2), _eylem joinString "+"];
};
_eylem isNotEqualTo []
