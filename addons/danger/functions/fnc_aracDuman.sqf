#include "script_component.hpp"
/*
 * Author: Cinar (ELITE fork)
 * ARAC DUMAN ATICISI (v8.251) — AT atesi altindaki arac gorus kesmek icin duman atar (ATP 3-20.15 3-136: tank / arac duman: kendi gorus hattini kes, yer degistir).
 * Silah bulma: aracin tum taretlerinde (weaponsTurret) magazinin mermisi 'smoke' iceren (simulation ya da sinif adi) TUM silahlar; tip basina onbellek (lambs_danger_aracDumanCache = [[silah, taretYolu, magazinler]]).
 * v8.252 (RPT f39a5919: T-72 'rhs_weap_smokegen', T-14 'SmokeLauncher' BULUNDU ama hic atis yok): cephane kontrolu 'vehicle ammo silah' sifir donuyordu -> magazinesAllTurrets'ten (silahin magazinleri, tum taretler) sayilir.
 *   Atis: vehicle fireAtTarget [objNull, silah]; 1.2 sn sonra cephane AZALMADIYSA yedek: taret birimi forceWeaponFire [silah, ilk mod]. Sonuc [ARAC-DUMAN] logunda (ATILDI / YEDEK / ATILMADI). Sira: once firlatici, uretec ('smokegen') sonra.
 * Aracin taretin baktigi yone atar - cagiran once taret/gozcuyu tehdide cevirmeli. 30 sn bekleme / arac. Yerel olmayan arac / cephanesi bitmis -> false. Kapatma: lambs_danger_aracDumanOff = true.
 *
 * Arguments:
 * 0: Arac <OBJECT>
 *
 * Return Value: Atildi mi <BOOL>
 * Public: No
*/

params [["_v", objNull, [objNull]]];
if (isNull _v || {!alive _v} || {!local _v}) exitWith {false};
if (missionNamespace getVariable ["lambs_danger_aracDumanOff", false]) exitWith {false};
if ((time - (_v getVariable [QGVAR(aracDumanT), -999])) < 30) exitWith {false};

private _tip = typeOf _v;
if (isNil "lambs_danger_aracDumanCache") then { lambs_danger_aracDumanCache = createHashMap; };
private _liste = lambs_danger_aracDumanCache getOrDefault [_tip, []];
if (_liste isEqualTo []) then {
    private _yollar = [[-1]] + (allTurrets _v);
    {
        private _yol = _x;
        {
            private _w = _x;
            private _mags = getArray (configFile >> "CfgWeapons" >> _w >> "magazines");
            if (_mags isEqualTo []) then { continue };
            private _ammo = getText (configFile >> "CfgMagazines" >> (_mags select 0) >> "ammo");
            private _sim = toLower (getText (configFile >> "CfgAmmo" >> _ammo >> "simulation"));
            if (((_sim find "smoke") >= 0 || {((toLower _ammo) find "smoke") >= 0}) && {(_liste findIf {(_x select 0) isEqualTo _w}) < 0}) then {
                _liste pushBack [_w, _yol, _mags];
            };
        } forEach (_v weaponsTurret _yol);
    } forEach _yollar;
    // firlaticilar once, uretec ('smokegen') sonra
    _liste = [_liste, [], {if (((toLower (_x select 0)) find "smokegen") >= 0) then {1} else {0}}, "ASCEND"] call BIS_fnc_sortBy;
    lambs_danger_aracDumanCache set [_tip, _liste];
    diag_log format ["[ARAC-DUMAN] %1 (%2) duman silahlari: %3", getText (configOf _v >> "displayName"), _tip, if (_liste isEqualTo []) then {"YOK"} else {_liste apply {_x select 0}}];
};
if (_liste isEqualTo []) exitWith {false};

private _kalan = {
    params ["_arac", "_mags"];
    private _n = 0;
    { if ((_x select 0) in _mags) then { _n = _n + (_x select 2); }; } forEach (magazinesAllTurrets _arac);
    _n
};
if (isNil "lambs_danger_aracDumanLogN") then { lambs_danger_aracDumanLogN = 0; };

private _atildi = false;
{
    _x params ["_w", "_yol", "_mags"];
    private _once = [_v, _mags] call _kalan;
    if (_once <= 0) then { continue };
    _atildi = true;
    private _ok = _v fireAtTarget [objNull, _w];
    [{
        params ["_arac", "_w", "_yol", "_mags", "_once", "_ok", "_kalan"];
        if (isNull _arac || {!alive _arac}) exitWith {};
        private _sonra = [_arac, _mags] call _kalan;
        private _sonuc = "ATILDI";
        if (_sonra >= _once) then {
            // fireAtTarget etkisiz: taret biriminden dogrudan ates ettir
            private _u = _arac turretUnit _yol;
            if (!isNull _u && {alive _u}) then {
                _u forceWeaponFire [_w, (getArray (configFile >> "CfgWeapons" >> _w >> "modes")) param [0, "Single"]];
                _sonuc = "ATILMADI -> YEDEK forceWeaponFire";
            } else {
                _sonuc = "ATILMADI (taret birimi yok)";
            };
        };
        if (lambs_danger_aracDumanLogN < 40) then {
            lambs_danger_aracDumanLogN = lambs_danger_aracDumanLogN + 1;
            diag_log format ["[ARAC-DUMAN] %1 | %2 | %3 | fireAtTarget %4 | cephane %5 -> %6 | %7", groupId (group (driver _arac)), getText (configOf _arac >> "displayName"), _w, _ok, _once, _sonra, _sonuc];
        };
    }, [_v, _w, _yol, _mags, _once, _ok, _kalan], 1.2] call CBA_fnc_waitAndExecute;
} forEach _liste;
if (_atildi) then { _v setVariable [QGVAR(aracDumanT), time]; };
_atildi
