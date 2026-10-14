#include "script_component.hpp"
/*
 * Author: Cinar (ELITE fork)
 * IHA ENVANTERI (v8.233) — yuklu modlardaki insansiz hava araclarini (CfgVehicles: isUav = 1 / simulation UAV, scope 2) acilista sinif adlariyla loglar: [IHA-ENVANTER].
 * Amac: Workshop modlari (FPV Drone Crocus, Mavic 3 + drop mod, RHS IHA'lari) hangi sinif adlarini kullaniyor? fnc_ihaTip bu listeye gore tur secer; yanlis siniflanirsa Zeus modulunde tur ELLE secilir.
 * Yalniz sunucuda, bir kez. Cikti ornegi: [IHA-ENVANTER] Crocus_AT_F | "FPV Drone Crocus AT" | taraf 1 | silah 2 | tip FPV-AT
 *
 * Arguments: None
 * Return Value: Baslatildi mi <BOOL>
 * Public: No
*/

if (!isServer || {!isNil "lambs_danger_ihaEnvanterStarted"}) exitWith {false};
lambs_danger_ihaEnvanterStarted = true;

[] spawn {
    sleep 8;
    private _liste = [];
    private _cfg = configFile >> "CfgVehicles";
    for "_i" from 0 to ((count _cfg) - 1) do {
        private _c = _cfg select _i;
        if (isClass _c && {(getNumber (_c >> "scope")) >= 2} && {((getNumber (_c >> "isUav")) isEqualTo 1) || {(toLower (getText (_c >> "simulation"))) isEqualTo "uav"}}) then {
            private _cn = configName _c;
            _liste pushBack _cn;
        };
    };
    private _n = 0;
    {
        private _tip = [_x] call FUNC(ihaTip);
        diag_log format ["[IHA-ENVANTER] %1 | \"%2\" | taraf %3 | silah %4 | model %5 | tip %6", _x, getText (configFile >> "CfgVehicles" >> _x >> "displayName"), getNumber (configFile >> "CfgVehicles" >> _x >> "side"), count (getArray (configFile >> "CfgVehicles" >> _x >> "weapons")), getText (configFile >> "CfgVehicles" >> _x >> "model"), _tip];
        _n = _n + 1;
    } forEach _liste;
    diag_log format ["[IHA-ENVANTER] toplam %1 IHA sinifi; FPV / bomba / gozlem turu otomatik tahmin edildi (yanlissa Zeus 'ELITE IHA Gorevi' modulunde turu elle sec)", _n];
};
true
