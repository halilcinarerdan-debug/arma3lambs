#include "script_component.hpp"
/*
 * Author: Cinar (ELITE fork)
 * SILAHLI IHA: YERE ATILABILIR SILAHLARI BUL (v8.402; kullanici: 'dusman dronu araclara fuze yollamadi' - TB2 envanterde 'silah 0' gorunuyordu, silahlar pilon / dinamik yuk olarak calisma aninda yuklenir).
 * Calisma anindaki mühimmata (magazinesAllTurrets) bakar, sinif tablosu / ad GEREKTIRMEZ: ammo simulation shotMissile / shotRocket / shotBomb, hit >= 60, yalniz-hava fuzesi (airLock 2) ve karsi tedbir (shotCM) elenir.
 *
 * Arguments:
 * 0: IHA <OBJECT>
 *
 * Return Value: [[silah, taretYolu, magazin, mermi, tur ("FUZE" / "BOMBA"), hit], ...] (bos = yere atabilecegi silah yok; hit'e gore buyukten kucuge) <ARRAY>
 * Public: No
*/

params [["_uav", objNull, [objNull]]];
private _sonuc = [];
if (isNull _uav || {!alive _uav}) exitWith {_sonuc};
{
    _x params ["_mag", "_tp", "_say"];
    if (_say <= 0) then { continue };
    private _ammo = getText (configFile >> "CfgMagazines" >> _mag >> "ammo");
    if (_ammo isEqualTo "") then { continue };
    private _sim = toLower (getText (configFile >> "CfgAmmo" >> _ammo >> "simulation"));
    if !(_sim in ["shotmissile", "shotrocket", "shotbomb"]) then { continue };
    private _hit = getNumber (configFile >> "CfgAmmo" >> _ammo >> "hit");
    if (_hit < 60) then { continue };
    if ((getNumber (configFile >> "CfgAmmo" >> _ammo >> "airLock")) >= 2) then { continue };
    // silah: bu taretteki, bu magazini kullanan silah (pilon silahi: magazin 'pylonWeapon')
    private _pw = getText (configFile >> "CfgMagazines" >> _mag >> "pylonWeapon");
    private _w = "";
    {
        if (_w isEqualTo "" && {(_x isEqualTo _pw) || {_mag in (getArray (configFile >> "CfgWeapons" >> _x >> "magazines"))}}) then { _w = _x; };
    } forEach (_uav weaponsTurret _tp);
    if (_w isEqualTo "") then { continue };
    _sonuc pushBack [_w, _tp, _mag, _ammo, ["FUZE", "BOMBA"] select (_sim isEqualTo "shotbomb"), _hit];
} forEach (magazinesAllTurrets _uav);
_sonuc = [_sonuc, [], {-(_x select 5)}, "ASCEND"] call BIS_fnc_sortBy;
_sonuc
