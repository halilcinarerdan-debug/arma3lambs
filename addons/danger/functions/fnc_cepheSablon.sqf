#include "script_component.hpp"
/*
 * Author: Cinar (ELITE fork)
 * CEPHE SABLON (v8.237, Dilim A0) — bir faction'in piyade squad sablonlari (CfgGroups'tan, otomatik).
 * Kural (TASARIM DEGERI): yalniz yaya asker iceren (hepsi CAManBase) ve 4..14 uyeli gruplar sablon sayilir (arac / zirh / hava ekibi elenir).
 * Faction'in CfgGroups kaydi yoksa bos dondurur (cagiran fnc_cepheFaction o zaman faction'in yaya sinif havuzundan squad kurar).
 * Sonuc onbellege alinir (config degismez).
 *
 * Arguments:
 * 0: Faction sinifi (CfgFactionClasses) <STRING>
 *
 * Return Value: [[sinif, sinif, ...], ...] <ARRAY>
 * Public: No
*/

params [["_f", "", [""]]];

if (_f isEqualTo "") exitWith {[]};
if (isNil "lambs_danger_cepheSablonOnbellek") then { lambs_danger_cepheSablonOnbellek = createHashMap; };
if (_f in lambs_danger_cepheSablonOnbellek) exitWith { lambs_danger_cepheSablonOnbellek get _f };

private _sonuc = [];
private _sideNum = getNumber (configFile >> "CfgFactionClasses" >> _f >> "side");
if (_sideNum in [0, 1, 2]) then {
    private _kok = configFile >> "CfgGroups" >> (["East", "West", "Indep"] select _sideNum) >> _f;
    {
        {
            private _sinifler = (configProperties [_x, "isClass _x && {isText (_x >> 'vehicle')}", true]) apply { getText (_x >> "vehicle") };
            private _n = count _sinifler;
            if (_n >= 4 && {_n <= 14} && {(_sinifler findIf {!(_x isKindOf "CAManBase")}) < 0}) then {
                _sonuc pushBackUnique _sinifler;
            };
        } forEach (configProperties [_x, "isClass _x", true]);
    } forEach (configProperties [_kok, "isClass _x", true]);
};

lambs_danger_cepheSablonOnbellek set [_f, _sonuc];
_sonuc
