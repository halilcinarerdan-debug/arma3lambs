#include "script_component.hpp"
/*
 * Author: Cinar (ELITE fork)
 * Askerin taktik rolunu doner.
 *
 * NOT: CfgWeapons >> type tum birincil silahlarda 1'dir (MG dahil), 4 = launcher.
 *      Eski kodlardaki `_wpnType in [4, 5]` MG'yi hic yakalamiyordu.
 *      Burada MG, takili sarjor kapasitesi (>= 75: kayis/kutu/davul) veya
 *      bilinen MG ad kaliplariyla tespit edilir. Sonuc silah basina onbelleklenir.
 *
 * Arguments:
 * 0: unit <OBJECT>
 * 1: gercek rol <BOOL> (true: v8.64 'baski tufekcisi' atamasi YOK SAYILIR; dusman gucu hesabi icin) default false
 *
 * Return Value:
 * "MG" | "AT" | "MARKSMAN" | "MEDIC" | "RIFLE"   (oncelik: MG > AT > MARKSMAN > MEDIC)
 *
 * Example:
 * [bob] call lambs_danger_fnc_getUnitRole;
 *
 * Public: No
*/

params [["_unit", objNull, [objNull]], ["_gercek", false, [false]]];
if (isNull _unit) exitWith {"RIFLE"};

private _primary = primaryWeapon _unit;
private _launcher = secondaryWeapon _unit;

// ---------------------------------------------------------------------------
// Silah bazli rol (config okumasi pahali -> birim uzerinde onbellek)
// ---------------------------------------------------------------------------
private _onbellek = _unit getVariable [QGVAR(roleCache), ["", "RIFLE"]];
private _silahRol = "RIFLE";

if ((_onbellek select 0) isEqualTo _primary) then {
    _silahRol = _onbellek select 1;
} else {
    if (_primary isNotEqualTo "") then {
        private _ad = toUpper _primary;

        private _mag = (primaryWeaponMagazine _unit) param [0, ""];
        if (_mag isEqualTo "") then {
            _mag = (getArray (configFile >> "CfgWeapons" >> _primary >> "magazines")) param [0, ""];
        };
        private _kapasite = getNumber (configFile >> "CfgMagazines" >> _mag >> "count");

        private _mgAd = (["LMG", "MG3", "MG4", "M249", "M60", "PKM", "PKP", "MK200", "ZAFIR", "NEGEV", "SPMG", "RPK", "MG42", "_MG_", "MINIMI"] findIf {
            (_ad find _x) >= 0
        }) > -1;

        private _nisanciAd = (["SRIFLE", "DMR", "EBR", "MK14", "SVD", "MAR10", "_LRR", "GM6", "M200", "AS50"] findIf {
            (_ad find _x) >= 0
        }) > -1;

        _silahRol = if (_kapasite >= 75 || _mgAd) then {
            "MG"
        } else {
            if (_nisanciAd) then {"MARKSMAN"} else {"RIFLE"}
        };
    };
    _unit setVariable [QGVAR(roleCache), [_primary, _silahRol]];
};

// ---------------------------------------------------------------------------
// Dinamik katman: AT (mermisi VAR mi?) / MEDIC
// ---------------------------------------------------------------------------
private _rol = _silahRol;
if (_silahRol isNotEqualTo "MG") then {
    // AT = LAMBS bayraklariyla GERCEK anti-tank (AA / flare / AP launcher AT sayilmaz)
    private _atFn = missionNamespace getVariable ["lambs_danger_fnc_isATUnit", {params ["_u"]; (secondaryWeapon _u) isNotEqualTo "" && {(_u ammo (secondaryWeapon _u)) > 0}}];
    if (_launcher isNotEqualTo "" && {[_unit] call _atFn}) then {
        _rol = "AT";
    } else {
        if (_silahRol isEqualTo "RIFLE" && {_unit getUnitTrait "medic"}) then {
            _rol = "MEDIC";
        };
    };
};

// v8.64: BASKI TUFEKCISI — squad'da gercek MG yoksa fnc_baskiTufekci bir tufekliyi (QGVAR(baskiTuf) = true) otomatik tufekci / MG rolune atar; kendi birimler MG sayilir.
//   Dusman gucu hesabinda (gercek = true) bu atama yok sayilir (dusmanin tufeklisini MG sanmayalim).
if (!_gercek && {_rol isEqualTo "RIFLE"} && {_unit getVariable [QGVAR(baskiTuf), false]}) then { _rol = "MG"; };

_rol
