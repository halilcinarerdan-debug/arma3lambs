#include "script_component.hpp"
/*
 * Author: Cinar (ELITE fork)
 * ARAC DUMAN ATICISI (v8.251) — AT atesi altindaki arac gorus kesmek icin duman atar (ATP 3-20.15 3-136: tank / arac duman: kendi gorus hattini kes, yer degistir).
 * Silah bulma: aracin tum taretlerinde (weaponsTurret) magazinin mermisi 'smoke' iceren (simulation ya da sinif adi) TUM silahlar; tip basina onbellek (lambs_danger_aracDumanCache = [[silah, taretYolu, magazinler]]).
 * v8.252 (RPT f39a5919: T-72 'rhs_weap_smokegen', T-14 'SmokeLauncher' BULUNDU ama hic atis yok): cephane kontrolu 'vehicle ammo silah' sifir donuyordu -> magazinesAllTurrets'ten (silahin magazinleri, tum taretler) sayilir.
 *   Atis: vehicle fireAtTarget [objNull, silah]; 1.2 sn sonra cephane AZALMADIYSA yedek: taret birimi forceWeaponFire [silah, ilk mod]. Sonuc [ARAC-DUMAN] logunda (ATILDI / YEDEK / ATILMADI). Sira: once firlatici, uretec ('smokegen') sonra.
 * v8.256 (RPT e31bd8bd: T-14 'SmokeLauncher' cephane 2, T-72B 'rhs_weap_smokegen' 999 BULUNDU, fireAtTarget FALSE dondu, forceWeaponFire yedegi de cephaneyi azaltmadi - 10 / 10 ATILMADI): yontem KADEMESI, her yontem 1 sn sonra cephane azaldi mi diye dogrulanir:
 *   FAT = vehicle fireAtTarget [objNull, silah]; FWF = taret birimi selectWeapon + forceWeaponFire [silah, ilk mod]; ACT = taret birimi action ["UseWeapon", arac, birim, silah indeksi].
 *   Calisan yontem arac tipi basina hatirlanir (lambs_danger_aracDumanYontem) ve sonraki atista once denenir; hicbiri calismazsa [ARAC-DUMAN] 'HICBIRI CALISMADI' + taret birimi / yol bilgisi yazar.
 * Aracin taretin baktigi yone atar - cagiran once taret/gozcuyu tehdide cevirmeli. 30 sn bekleme / arac. Yerel olmayan arac / cephanesi bitmis -> false. Kapatma: lambs_danger_aracDumanOff = true.
 *
 * Arguments:
 * 0: Arac <OBJECT>
 *
 * Return Value: Atildi mi <BOOL>
 * Public: No
*/

params [["_v", objNull, [objNull]], ["_bekle", 30, [0]]];   // v8.318: _bekle = ayni arac icin bekleme (sn); dron savunmasi 14 sn kullanir
if (isNull _v || {!alive _v} || {!local _v}) exitWith {false};
if (missionNamespace getVariable ["lambs_danger_aracDumanOff", false]) exitWith {false};
if ((time - (_v getVariable [QGVAR(aracDumanT), -999])) < _bekle) exitWith {false};

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
if (isNil "lambs_danger_aracDumanYontem") then { lambs_danger_aracDumanYontem = createHashMap; };

private _atilacak = _liste select {([_v, _x select 2] call _kalan) > 0};
if (_atilacak isEqualTo []) exitWith {false};
_v setVariable [QGVAR(aracDumanT), time];

[_v, _atilacak, _kalan, _tip] spawn {
    params ["_v", "_liste", "_kalan", "_tip"];
    {
        _x params ["_w", "_yol", "_mags"];
        private _once = [_v, _mags] call _kalan;
        private _sira = ["FAT", "FWF", "ACT"];
        private _bilinen = lambs_danger_aracDumanYontem getOrDefault [_tip, ""];
        if (_bilinen isNotEqualTo "") then { _sira = [_bilinen] + (_sira - [_bilinen]); };
        private _u = _v turretUnit _yol;
        if (isNull _u || {!alive _u}) then {
            { if (isNull _u || {!alive _u}) then { _u = _x; }; } forEach [gunner _v, commander _v, driver _v];
        };
        private _sonuc = "HICBIRI CALISMADI";
        private _ok = "-";
        {
            private _y = _x;
            switch (_y) do {
                case "FAT": { _ok = _v fireAtTarget [objNull, _w]; };
                case "FWF": {
                    if (!isNull _u && {alive _u}) then {
                        _u selectWeapon _w;
                        _u forceWeaponFire [_w, (getArray (configFile >> "CfgWeapons" >> _w >> "modes")) param [0, "Single"]];
                    };
                };
                case "ACT": {
                    if (!isNull _u && {alive _u}) then {
                        _u action ["UseWeapon", _v, _u, (_v weaponsTurret _yol) find _w];
                    };
                };
            };
            sleep 1;
            if (isNull _v || {!alive _v}) exitWith { _sonuc = "ARAC YOK"; };
            if (([_v, _mags] call _kalan) < _once) exitWith {
                _sonuc = format ["ATILDI (%1)", _y];
                lambs_danger_aracDumanYontem set [_tip, _y];
            };
        } forEach _sira;
        if (lambs_danger_aracDumanLogN < 40) then {
            lambs_danger_aracDumanLogN = lambs_danger_aracDumanLogN + 1;
            diag_log format ["[ARAC-DUMAN] %1 | %2 | %3 | yol %4 | taret_birimi %5 | cephane %6 -> %7 | fireAtTarget %8 | %9", groupId (group (driver _v)), getText (configOf _v >> "displayName"), _w, _yol, if (isNull _u) then {"YOK"} else {name _u},
                _once, [_v, _mags] call _kalan, _ok, _sonuc];
        };
    } forEach _liste;
};
true
