#include "script_component.hpp"
/*
 * Author: Cinar (ELITE fork)
 * TANK IZLEME + EKIP BECERISI (v8.279; kullanici: 'tank duellosu cok temkinli, tanklari guclendirebiliriz'; RPT 21-10 21:53: iki taraf tanklari 100-300 m arayla 8+ dk durdu, [TANK-ATES] hedef sectigi halde HIC tank imha / hareketsiz kalmadi
 *   ve tank topu atisi / hasari hicbir yerde loglanmiyordu -> neden olculemiyordu).
 *   1) TANI (arac basina bir kez eklenir): Fired -> ana top (shotShell / shotMissile) atislari [TANK-ATIS] (ilk 6 ve her 5.); Hit -> [TANK-HASAR] (2 sn'de bir; hasar, kaynak, hasarli parcalar > 0.3).
 *   2) EKIP BECERISI: oyuncu olmayan murettebat icin nisan / gozlem becerileri `lambs_danger_tankEkipSkill` (varsayilan 0.95; v8.279: 0.85; 0 = kapali) altindaysa o degere cikarilir (asla dusurulmez).
 * Kapatma: tani lambs_danger_tankIzleOff = true.
 *
 * Arguments:
 * 0: Tank <OBJECT>
 *
 * Return Value: Yok
 * Public: No
*/

params [["_v", objNull, [objNull]]];
if (isNull _v || {!local _v} || {_v getVariable ["lambs_danger_tankIzleEH", false]}) exitWith {};
_v setVariable ["lambs_danger_tankIzleEH", true];

private _sk = missionNamespace getVariable ["lambs_danger_tankEkipSkill", 0.95];   // v8.280: 0.85 -> 0.95 (kullanici: 'tanklari guclendir')
if (_sk > 0) then {
    {
        private _u = _x;
        if (!isPlayer _u && {local _u}) then {
            { if ((_u skill _x) < _sk) then { _u setSkill [_x, _sk]; }; } forEach ["aimingAccuracy", "aimingSpeed", "aimingShake", "spotDistance", "spotTime", "reloadSpeed"];
        };
    } forEach (crew _v);
    diag_log format ["[TANK-ATIS] %1 | ekip becerisi >= %2 yapildi (%3 kisi)", getText (configOf _v >> "displayName"), _sk, count (crew _v)];
};

// v8.280 TANK TOPU HASARI (kullanici: 'tanklari guclendir', 2 vs 3 duello 1 saat surmesin): bu tanka DUSMAN TANKI ana topu / fuzesi (shotShell / shotMissile) ile vurdugunda gelen hasar
//   lambs_danger_tankTopHasar (varsayilan 1.3) ile carpilir -> tank-tank cati engagement daha hizli sonuclanir. Piyade / AT / mayin hasari degismez. 1 = kapali.
if ((missionNamespace getVariable ["lambs_danger_tankTopHasar", 1.3]) != 1) then {
    _v addEventHandler ["HandleDamage", {
        params ["_u", "_sel", "_dmg", "_src", "_proj", "_hi", "_inst"];
        private _m = missionNamespace getVariable ["lambs_danger_tankTopHasar", 1.3];
        if (_m == 1 || {_proj isEqualTo ""}) exitWith { _dmg };
        private _kaynak = if (isNull _inst) then {_src} else {_inst};
        if (isNull _kaynak || {!((vehicle _kaynak) isKindOf "Tank")}) exitWith { _dmg };
        private _sim = toLower getText (configFile >> "CfgAmmo" >> _proj >> "simulation");
        if !(_sim in ["shotshell", "shotmissile"]) exitWith { _dmg };
        private _eski = if (_sel isEqualTo "") then { damage _u } else { _u getHitIndex _hi };
        if (_dmg <= _eski) exitWith { _dmg };
        (_eski + ((_dmg - _eski) * _m)) min 1
    }];
};

if (missionNamespace getVariable ["lambs_danger_tankIzleOff", false]) exitWith {};

_v addEventHandler ["Fired", {
    params ["_u", "_w", "_m", "_mode", "_ammo", "_mag", "_proj"];
    private _sim = toLower getText (configFile >> "CfgAmmo" >> _ammo >> "simulation");
    if !(_sim in ["shotshell", "shotmissile", "shotrocket"]) exitWith {};
    private _n = (_u getVariable ["lambs_danger_tankAtisN", 0]) + 1;
    _u setVariable ["lambs_danger_tankAtisN", _n];
    if (_n <= 6 || {(_n mod 5) isEqualTo 0}) then {
        private _gn = gunner _u;
        private _t = if (isNull _gn) then {objNull} else {assignedTarget _gn};
        diag_log format ["[TANK-ATIS] %1 | atis %2 | %3 | hedef %4 (%5 m) | konum %6", getText (configOf _u >> "displayName"), _n, _ammo, if (isNull _t) then {"-"} else {typeOf _t}, if (isNull _t) then {"-"} else {round (_u distance2D _t)}, mapGridPosition _u];
    };
}];
_v addEventHandler ["Hit", {
    params ["_u", "_src", "_dmg", "_inst"];
    if ((time - (_u getVariable ["lambs_danger_tankHasarT", -99])) < 2) exitWith {};
    _u setVariable ["lambs_danger_tankHasarT", time];
    (getAllHitPointsDamage _u) params ["_adlar", "_secim", "_deg"];
    private _hasarli = [];
    { if ((_deg select _forEachIndex) > 0.3) then { _hasarli pushBack format ["%1=%2", _x, (_deg select _forEachIndex) toFixed 2]; }; } forEach _adlar;
    diag_log format ["[TANK-HASAR] %1 | +%2 | toplam %3 | kaynak %4 (%5 m) | canMove %6 canFire %7 | parcalar >0.3: %8", getText (configOf _u >> "displayName"), _dmg toFixed 2, (damage _u) toFixed 2, if (isNull _src) then {"-"} else {typeOf _src}, if (isNull _src) then {"-"} else {round (_u distance2D _src)}, canMove _u, canFire _u, _hasarli];
}];
