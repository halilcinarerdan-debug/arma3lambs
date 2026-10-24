#include "script_component.hpp"
/*
 * Author: Cinar (ELITE fork)
 * MOD UYUM TANISI (v8.344; kullanici: 'RHS ve CUP kullaniyorum, sistemin tamamini bu iki moda uyumlu hale getir; test ortaminda tek RHS var'). Acilista bir kez (sunucu + istemci), yuklenen modlari ve sistemin
 * dayandigi sinif ailelerinin (config tabanli, mod adindan bagimsiz) kac tanesi bulundugunu RPT'ye yazar: modun eksikligi ELITE'i bozmaz, yalniz ilgili ozellik "sinif yok" ile atlanir.
 * Taranan: RHS (rhs_main / rhsusf_main / rhsgref_main / rhssaf_main), CUP (CUP_Vehicles / CUP_Weapons / CUP_Creatures), ACE, ACRE / TFAR, CBA, ZEN / Zeus Enhanced, Crocus FPV, FPV_AI_Drones;
 * topcu (artilleryScanner > 0) arac sinifi sayisi, ucan IHA sinifi sayisi, tank (Tank), tekerlekli / paletli APC sayisi, lazer gudumlu mermi (adinda laser / guid) sayisi, mod basina.
 * Log: [MOD-UYUM] (bir kez). Kapatma: lambs_danger_modUyumOff = true.
 *
 * Arguments: None
 * Return Value: Calisti mi <BOOL>
 * Public: No
*/

if (!isNil "lambs_danger_modUyumStarted" || {missionNamespace getVariable ["lambs_danger_modUyumOff", false]}) exitWith {false};
lambs_danger_modUyumStarted = true;

[] spawn {
    sleep 10;
    private _yama = {
        params ["_adlar"];
        (_adlar findIf {isClass (configFile >> "CfgPatches" >> _x)}) >= 0
    };
    private _modlar = [
        ["RHS USAF", ["rhsusf_main", "rhsusf_c_weapons"]], ["RHS AFRF", ["rhs_main", "rhs_c_weapons"]], ["RHS GREF", ["rhsgref_main"]], ["RHS SAF", ["rhssaf_main"]],
        ["CUP Weapons", ["CUP_Weapons_LoadOrder", "CUP_Weapons_Ammunition"]], ["CUP Vehicles", ["CUP_Vehicles_LoadOrder"]], ["CUP Units", ["CUP_Creatures_People_LoadOrder", "CUP_Creatures_Military_LoadOrder"]],
        ["ACE", ["ace_main"]], ["ACE Medical", ["ace_medical"]], ["ACRE2", ["acre_main"]], ["TFAR", ["task_force_radio"]], ["CBA", ["cba_main"]], ["Zeus Enhanced", ["zen_main"]],
        ["Crocus FPV", ["ArmaFPV", "Crocus_FPV"]], ["FPV_AI_Drones", ["FPV_AI_Drones"]]
    ];
    private _yuklu = [];
    private _yok = [];
    { if ([_x select 1] call _yama) then { _yuklu pushBack (_x select 0); } else { _yok pushBack (_x select 0); }; } forEach _modlar;
    // sinif aileleri (config tabanli; etiket = sinifin addon'u: CfgVehicles >> sinif >> 'author' ya da sinif adi on eki)
    private _araclar = "getNumber (_x >> 'scope') >= 2" configClasses (configFile >> "CfgVehicles");
    private _say = createHashMap;
    {
        private _c = _x;
        private _ad = toLower (configName _c);
        private _mod = if ((_ad find "rhs") >= 0 && {(_ad find "rhs") < 3}) then {"RHS"} else { if ((_ad find "cup_") >= 0 && {(_ad find "cup_") < 3}) then {"CUP"} else { ["vanilla / diger"] select 0 } };
        private _k = _c >> "artilleryScanner";
        private _top = isNumber _k && {(getNumber _k) > 0};
        private _uav = (getNumber (_c >> "isUav")) isEqualTo 1;
        private _air = _ad isKindOf "Air";
        private _tank = _ad isKindOf "Tank";
        private _apc = (_ad isKindOf "APC_Tracked_01_base_F") || {_ad isKindOf "Wheeled_APC_F"} || {_ad isKindOf "APC_Wheeled_01_base_F"};
        if (_top) then { _say set [_mod + " topcu", (_say getOrDefault [_mod + " topcu", 0]) + 1]; };
        if (_uav) then { _say set [_mod + " UAV", (_say getOrDefault [_mod + " UAV", 0]) + 1]; };
        if (_tank) then { _say set [_mod + " tank", (_say getOrDefault [_mod + " tank", 0]) + 1]; };
        if (_apc) then { _say set [_mod + " APC", (_say getOrDefault [_mod + " APC", 0]) + 1]; };
    } forEach _araclar;
    private _lg = 0;
    { if (((toLower (configName _x)) find "laser") >= 0 || {((toLower (configName _x)) find "_lg") >= 0}) then { _lg = _lg + 1; }; } forEach ("true" configClasses (configFile >> "CfgMagazines"));
    diag_log format ["[MOD-UYUM] yuklu: %1 | yok: %2", _yuklu, _yok];
    diag_log format ["[MOD-UYUM] sinif aileleri (artilleryScanner / isUav / Tank / APC, mod basina): %1 | lazer gudumlu magazin sinifi: %2", (keys _say) apply {format ["%1=%2", _x, _say get _x]}, _lg];
    diag_log "[MOD-UYUM] ELITE sinif ADINA degil config ailesine dayanir (artilleryScanner, unitIsUAV, isKindOf Tank / APC, CfgWeapons turu): RHS / CUP / vanilla ayni yolu kullanir; ACE / FPV_AI_Drones / Crocus / ACRE / TFAR yoksa ilgili ozellik atlanir.";
};
true
