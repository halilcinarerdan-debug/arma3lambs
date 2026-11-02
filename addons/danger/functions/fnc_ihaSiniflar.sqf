#include "script_component.hpp"
/*
 * Author: Cinar (ELITE fork)
 * IHA SINIF LISTESI (v8.363; kullanici: 'vanilla tum uav dronlar sistem uyumlu olsun, gozlem icin iha istiyorum') — Zeus 'ELITE IHA Gorevi' > 'Dron yarat' acilir listesi icin.
 * Yuklu TUM hava insansiz araclarini (CfgVehicles: scope 2, isUav = 1 ya da simulation UAV, Air sinifi, taraf BLUFOR / OPFOR / INDEP) sinif adina bakmadan config ailesinden bulur:
 *   vanilla Darter / Falcon / Greyhawk / Ababil / Sentinel / Pelican, RHS / CUP IHA'lari, Crocus FPV, Mavic... Siralama: once Crocus FPV'ler (eski liste), sonra taraf + gorunen ad.
 * Sonuc ilk cagrida hesaplanir ve onbellege alinir (lambs_danger_ihaSinifOnbellek).
 * Kara araclari (UGV) ve ozerk sabit taretler listeye KONMAZ (Zeus'ta yaratma ucucu IHA icindir); Eden'de yerlestirilmis UGV / tareti IHA modulune SYNC edebilirsin.
 *
 * Arguments: None
 * Return Value: [siniflar <ARRAY of STRING>, etiketler <ARRAY of STRING>, tur <ARRAY of STRING: "UCAK" / "HELI">]
 * Public: No
*/

private _onb = missionNamespace getVariable ["lambs_danger_ihaSinifOnbellek", []];
if (_onb isNotEqualTo []) exitWith {_onb};

private _cfg = configFile >> "CfgVehicles";
private _ham = [];
for "_i" from 0 to ((count _cfg) - 1) do {
    private _c = _cfg select _i;
    if (isClass _c && {(getNumber (_c >> "scope")) >= 2} && {((getNumber (_c >> "isUav")) isEqualTo 1) || {(toLower (getText (_c >> "simulation"))) isEqualTo "uav"}}) then {
        private _cn = configName _c;
        private _yon = getNumber (_c >> "side");
        if (_yon in [0, 1, 2] && {_cn isKindOf "Air"}) then {
            private _fpv = ((toLower _cn) find "crocus") >= 0;
            private _ad = getText (_c >> "displayName");
            private _etiket = format ["[%1] %2 (%3)%4", ["OPFOR", "BLUFOR", "INDEP"] select _yon, _ad, _cn, ["", " - ucak tipi"] select (_cn isKindOf "Plane")];
            // siralama anahtari: Crocus once (0), sonra taraf (BLUFOR 1, OPFOR 2, INDEP 3), sonra ad
            private _anahtar = format ["%1%2%3", [1, 0] select _fpv, [2, 1, 3] select _yon, toLower _ad];
            _ham pushBack [_anahtar, _cn, _etiket, ["HELI", "UCAK"] select (_cn isKindOf "Plane")];
        };
    };
};
_ham = [_ham, [], {_x select 0}, "ASCEND"] call BIS_fnc_sortBy;
private _sonuc = [_ham apply {_x select 1}, _ham apply {_x select 2}, _ham apply {_x select 3}];
missionNamespace setVariable ["lambs_danger_ihaSinifOnbellek", _sonuc];
diag_log format ["[IHA-ENVANTER] Zeus 'Dron yarat' listesi: %1 ucucu IHA sinifi (vanilla + modlar; ucak tipi %2)", count (_sonuc select 0), {_x isEqualTo "UCAK"} count (_sonuc select 2)];
_sonuc
