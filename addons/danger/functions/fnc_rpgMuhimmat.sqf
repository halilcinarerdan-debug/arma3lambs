#include "script_component.hpp"
/*
 * Author: Cinar (ELITE fork)
 * RPG MUHIMMAT SISTEMI (v8.748; kullanici: 'b yap, cba opsiyonel ekle, envanterinde yer yoksa 1 adet AT'yi AP ile yer degistirsin'):
 * NEDEN: RPT 64b4517e [RPG-MERMI-TANI]: RHS RPG-7 PG-7VL (AT) allowAgainstInfantry 0, aiAmmoUsageFlags 896 (arac / zirh), airLock 1 -> motor / LAMBS RPG roketatari yalniz araca / helikoptere atar; piyadeye uygun (allowAgainstInfantry > 0
 *   ya da aiAmmoUsageFlags 64 biti) mermiler (OG-7V, TBG-7V, RShG-2, SMAW / MAAWS HEDP / HE, SPG-9 HE ...) LAMBS RPG yamali ama atici ENVANTERINDE bulunmuyor -> karar katmani 0 karar. Bu fonksiyon atici icin piyadeye uygun roket tasimayi (ve gerekirse yuklemeyi) saglar.
 * MODLAR:
 *   "apMi"  : [_u, "apMi", mermi sinifi (CfgAmmo)] -> BOOL: gudumsuz shotRocket + (allowAgainstInfantry > 0 ya da aiAmmoUsageFlags 64 biti) = AP (piyadeye uygun)
 *   "var"   : [_u, "var"] -> envanterinde (yuklu degil) AP sarjor sinifi, yoksa ""
 *   "yukle" : [_u, "yukle"] -> eklenen AP sarjor sayisi: roketatarin uyumlu sarjorlerinden en guclu (indirectHit x yaricap) AP sinifi rpgMuhimmatAdet (1) adede tamamlanir;
 *             envanterde YER YOKSA bir adet AT sarjoru cikarilip yerine AP konur (yine sigmazsa AT geri konur, eklenmez). Tek atimliklar / AP uyumlusu olmayanlar etkilenmez. Birim basina bir kez (rpgMuhOk).
 *   "degis" : [_u, "degis"] -> BOOL: yuklu AT mermisini AP ile degistirir (removeWeapon -> uyumlu sarjorler cikarilir -> yalniz AP + addWeapon (AP yuklenir) -> diger sarjorler + eski yuklu AT geri; sigmayan yere dusurulur).
 *             Yalniz karar katmani piyade / bina / kume emri vermeden hemen once (fnc_rpgSistem; CBA rpgMuhimmatDegis).
 * OLCUM: [RPG-MUHIMMAT] (ilk 40: eklenen / AT-AP yer degisimi / yer yok) + [RPG-MERMI-DEGIS] (ilk 30: yuklu AT -> AP) + [RPG-OZET] sayaclari (muhimmat_eklendi / muhimmat_yer_degis / muhimmat_yok / mermi_degis / mermi_degis_hata).
 * CBA: lambs_danger_rpgMuhimmat (varsayilan ACIK), rpgMuhimmatAdet (1), rpgMuhimmatDegis (ACIK).
 * SINIR: oyunda DENENMEDI; envanter / yuklu mermi degistirme ACE / modlu yuklerde sigmama riski tasir (sigmayan mermi yere dusurulur); AP atildiktan sonra motor siradaki sarjoru (cogu AT) kendisi yukler, AT'ye geri donus ayrica yapilmaz.
 *
 * Arguments:
 * 0: Birim (apMi modunda onemsiz) <OBJECT>
 * 1: Mod <STRING>
 * 2: Mermi sinifi (yalniz apMi) <STRING>
 *
 * Return Value: moda gore (BOOL / NUMBER / STRING)
 *
 * Public: No
*/

params ["_u", "_mod", ["_arg", ""]];

private _apAmmo = {
    params ["_a"];
    private _c = configFile >> "CfgAmmo" >> _a;
    (toLower (getText (_c >> "simulation"))) isEqualTo "shotrocket"
    && {(getNumber (_c >> "weaponLockSystem")) isEqualTo 0} && {(getNumber (_c >> "maxControlRange")) isEqualTo 0}
    && {((getNumber (_c >> "allowAgainstInfantry")) > 0) || {((floor ((getNumber (_c >> "aiAmmoUsageFlags")) / 64)) mod 2) isEqualTo 1}}
};
private _apMag = { params ["_m"]; [getText (configFile >> "CfgMagazines" >> _m >> "ammo")] call _apAmmo };
private _skor = {
    params ["_m"];
    private _c = configFile >> "CfgAmmo" >> (getText (configFile >> "CfgMagazines" >> _m >> "ammo"));
    ((getNumber (_c >> "indirectHit")) * ((getNumber (_c >> "indirectHitRange")) max 1)) + ((getNumber (_c >> "hit")) * 0.1)
};
private _say = missionNamespace getVariable ["lambs_danger_rpgSay", createHashMap];
missionNamespace setVariable ["lambs_danger_rpgSay", _say];
private _art = { params ["_k"]; _say set [_k, (_say getOrDefault [_k, 0]) + 1]; };

if (_mod isEqualTo "apMi") exitWith { [_arg] call _apAmmo };

private _ls = secondaryWeapon _u;
if (_ls isEqualTo "") exitWith { if (_mod isEqualTo "degis") then {false} else { if (_mod isEqualTo "yukle") then {0} else {""} } };
private _uyumC = compatibleMagazines _ls;
private _uyum = _uyumC apply {toLower _x};

if (_mod isEqualTo "var") exitWith {
    private _k = (magazines _u) select {(toLower _x) in _uyum && {[_x] call _apMag}};
    if (_k isEqualTo []) then {""} else { _k select 0 }
};

if (_mod isEqualTo "yukle") exitWith {
    private _ap = _uyumC select {[_x] call _apMag};
    if (_ap isEqualTo []) then { _u setVariable [QGVAR(rpgMuhOk), true]; 0 } else {
        private _adet = ((missionNamespace getVariable ["lambs_danger_rpgMuhimmatAdet", 1]) max 1) min 3;
        private _yukluAp = ((secondaryWeaponMagazine _u) findIf {[_x] call _apMag}) >= 0;
        private _var = ({[_x] call _apMag} count ((magazines _u) select {(toLower _x) in _uyum})) + ([0, 1] select _yukluAp);
        private _eklenen = 0;
        private _degis = 0;
        private _yok = 0;
        if (_var < _adet) then {
            private _en = ([_ap, [], {[_x] call _skor}, "DESCEND"] call BIS_fnc_sortBy) select 0;
            for "_i" from 1 to (_adet - _var) do {
                if (_u canAdd _en) then { _u addMagazine _en; _eklenen = _eklenen + 1; } else {
                    private _atl = (magazines _u) select {(toLower _x) in _uyum && {!([_x] call _apMag)}};
                    if (_atl isNotEqualTo []) then {
                        private _at = _atl select 0;
                        _u removeMagazine _at;
                        if (_u canAdd _en) then { _u addMagazine _en; _eklenen = _eklenen + 1; _degis = _degis + 1; } else { _u addMagazine _at; _yok = _yok + 1; };
                    } else { _yok = _yok + 1; };
                };
            };
            if (_eklenen > 0) then { ["muhimmat_eklendi"] call _art; };
            if (_degis > 0) then { ["muhimmat_yer_degis"] call _art; };
            if (_yok > 0) then { ["muhimmat_yok"] call _art; };
            private _n = missionNamespace getVariable ["lambs_danger_rpgMuhLogN", 0];
            if (_n < 40) then {
                missionNamespace setVariable ["lambs_danger_rpgMuhLogN", _n + 1];
                diag_log format ["[RPG-MUHIMMAT] %1 | %2 | %3 | AP sarjor %4 | tasinan AP %5 -> hedef %6 | eklenen %7 (AT -> AP yer degisimi %8, yer yok %9)", groupId group _u, name _u, _ls, _en, _var, _adet, _eklenen, _degis, _yok];
            };
        };
        _u setVariable [QGVAR(rpgMuhOk), true];
        _eklenen
    };
};

// "degis": yuklu AT -> AP
private _yuklu = (secondaryWeaponMagazine _u) param [0, ""];
private _yukluAmmo = _u ammo _ls;
private _env = (magazinesAmmo _u) select {(toLower (_x select 0)) in _uyum};
private _apK = _env select {[_x select 0] call _apMag};
if (_apK isEqualTo [] || {_yuklu isEqualTo ""} || {[_yuklu] call _apMag}) exitWith { _yuklu isNotEqualTo "" && {[_yuklu] call _apMag} };
private _apSec = ([_apK, [], {[_x select 0] call _skor}, "DESCEND"] call BIS_fnc_sortBy) select 0;
_u removeWeapon _ls;
{ _u removeMagazines _x; } forEach ((_env apply {_x select 0}) arrayIntersect (_env apply {_x select 0}));
_u addMagazine [_apSec select 0, _apSec select 1];
_u addWeapon _ls;
private _yeni = (secondaryWeaponMagazine _u) param [0, ""];
private _hep = +_env;
_hep deleteAt (_hep find _apSec);
if (_yukluAmmo > 0) then { _hep pushBack [_yuklu, _yukluAmmo]; };
private _dusen = 0;
{
    _x params ["_c", "_a"];
    if (_u canAdd _c) then { _u addMagazine [_c, _a]; } else {
        private _h = createVehicle ["GroundWeaponHolder", getPosATL _u, [], 0, "CAN_COLLIDE"];
        _h addMagazineAmmoCargo [_c, 1, _a];
        _dusen = _dusen + 1;
    };
} forEach _hep;
private _ok = (toLower _yeni) isEqualTo (toLower (_apSec select 0));
[["mermi_degis_hata", "mermi_degis"] select _ok] call _art;
private _n = missionNamespace getVariable ["lambs_danger_rpgDegisLogN", 0];
if (_n < 30) then {
    missionNamespace setVariable ["lambs_danger_rpgDegisLogN", _n + 1];
    diag_log format ["[RPG-MERMI-DEGIS] %1 | %2 | %3 | yuklu AT %4 (%5) -> AP %6 | yeni yuklu: %7 | basarili: %8 | yere dusen %9", groupId group _u, name _u, _ls, _yuklu, _yukluAmmo, _apSec select 0, _yeni, _ok, _dusen];
};
_ok
