#include "script_component.hpp"
/*
 * Author: Cinar (ELITE fork)
 * SES / MUZZLE FLASH / DUMAN FARKINDALIGI — hile yok: sadece SES ve PARLAMA ile duyulan / gorulen atis,
 * mesafeye gore azalan bilgi seviyesiyle (reveal) verilir; kesin konum degil, yaklasik yon (doWatch + hata payi).
 *
 *   Duyulma menzili (taban):  tabanca 200 | tufek 5.56 450 | 7.62 650 | iri kalibre 900 | MG 900 | roketatar 1100 | 40mm 350
 *   SUSTURUCU: menzil x audibleFire katsayisi (min 0.1) x 1.3, en az 40 m. Supersonik mermi catlamasi (hizli kursun)
 *              yine duyulur (120 m) ama YON HATASI buyuk, bilgi seviyesi dusuk.
 *   PARLAMA (muzzle flash): gece 700 m / gun 120 m x visibleFire katsayisi (flas gizleyici / susturucu azaltir),
 *              hat gorusu (LOS) sart. Goren grup yuksek seviye (1.6) alir.
 *   DUMAN / ARKA ALEV: roketatar (backblast) gunduz 500 m / gece 800 m, LOS ile gorunur.
 *   SUREKLI ATES: 4 sn'de 6+ atis -> menzil x1.3 (toz / duman / ses).
 *
 *   Dinleyici: 5 sn'de bir degil, atis basina en fazla 6 DUSMAN grup (yerel olanlar). Zaten bu atici hakkinda
 *   yeterli bilgisi olan gruba dokunulmaz. Dinleyici grubun en yakin askeri: reveal + doWatch (hata payli yon);
 *   grup temasta degilse AWARE'e gecer.
 *
 * Arguments:
 * 0: atici <OBJECT>
 * 1: silah <STRING>
 * 2: muzzle <STRING>
 * 3: mermi <STRING>
 * 4: agir silah mi (roketatar / 40mm) <BOOL>
 *
 * Return Value:
 * Dinlenen grup sayisi <NUMBER>
 *
 * Public: No
*/

params [["_unit", objNull, [objNull]], ["_weapon", "", [""]], ["_muzzle", "", [""]], ["_ammo", "", [""]], ["_agir", false, [false]]];
if (isNull _unit || {!alive _unit}) exitWith {0};

private _tur = getNumber (configFile >> "CfgWeapons" >> _weapon >> "type");   // 1 tufek/MG, 2 tabanca, 4 roketatar
private _aCfg = configFile >> "CfgAmmo" >> _ammo;
private _kal = getNumber (_aCfg >> "caliber");
private _hizli = (getNumber (_aCfg >> "typicalSpeed")) > 340;
private _glMuzzle = [_unit] call (missionNamespace getVariable ["lambs_danger_fnc_hasUGL", {""}]);
private _glMi = (_glMuzzle isNotEqualTo "") && {_muzzle isEqualTo _glMuzzle};
private _launcher = _tur isEqualTo 4;

// Taban menzil
private _menzil = if (_launcher) then {1100} else {
    if (_glMi) then {350} else {
        if (_tur isEqualTo 2) then {200} else {
            if (_kal >= 1.9) then {900} else {
                if (_kal >= 1.25) then {650} else {450}
            }
        }
    }
};
// MG: yuksek kapasiteli sarjor / bilinen MG -> en yuksek ses
if (!_launcher && {_tur isEqualTo 1}) then {
    if (([_unit] call (missionNamespace getVariable ["lambs_danger_fnc_getUnitRole", {"RIFLE"}])) isEqualTo "MG") then {
        _menzil = _menzil max 900;
    };
};

// Namlu aksesuari katsayilari (susturucu / flas gizleyici)
private _muzzleItem = if (_tur isEqualTo 2) then {(handgunItems _unit) param [0, ""]} else {(primaryWeaponItems _unit) param [0, ""]};
private _audK = 1;
private _visK = 1;
if (_muzzleItem isNotEqualTo "") then {
    private _ic = configFile >> "CfgWeapons" >> _muzzleItem >> "ItemInfo" >> "AmmoCoef";
    if (isNumber (_ic >> "audibleFire")) then { _audK = getNumber (_ic >> "audibleFire"); };
    if (isNumber (_ic >> "visibleFire")) then { _visK = getNumber (_ic >> "visibleFire"); };
};
private _susturucu = _audK < 0.5;
if (_susturucu) then {
    _menzil = (_menzil * ((_audK max 0.1) * 1.3)) max 40;
};
// Supersonik catlama: susturucu olsa da yakin duyulur (yon kotu)
private _catlama = _susturucu && {_hizli};

// Surekli ates
private _burst = _unit getVariable [QGVAR(sesBurst), [0, 0]];
if ((time - (_burst select 0)) > 4) then { _burst = [time, 0]; };
_burst set [1, (_burst select 1) + 1];
_unit setVariable [QGVAR(sesBurst), _burst];
if ((_burst select 1) >= 6) then { _menzil = _menzil * 1.3; };

// Parlama / duman gorunurlugu
private _gece = (sunOrMoon < 0.35);
private _parlamaMenzil = ([120, 700] select _gece) * _visK;
if (_launcher) then { _parlamaMenzil = [500, 800] select _gece; };   // arka alev + toz / duman her kosulda gorunur
if (_glMi) then { _parlamaMenzil = _parlamaMenzil max 80; };

private _maks = (_menzil max _parlamaMenzil) min 1200;
if (_catlama) then { _maks = _maks max 120; };

private _taraf = side (group _unit);
private _pos = getPosATL _unit;
private _eP = eyePos _unit;

// Dinleyici adaylari: yerel, dusman, canli
private _adaylar = (_pos nearEntities ["CAManBase", _maks]) select {
    alive _x && {local _x} && {!isPlayer _x} && {isNull objectParent _x}
    && {(side (group _x)) isNotEqualTo civilian}
    && {_taraf getFriend (side (group _x)) < 0.6}
};
if (_adaylar isEqualTo []) exitWith {0};

private _gruplar = [];
private _say = 0;
{
    private _g = group _x;
    if (!(_g in _gruplar) && {_say < 6}) then {
        _gruplar pushBack _g;
        private _k = _x;
        // grubun atici ile en yakin askeri
        private _grupUye = (units _g) select {alive _x && {local _x} && {isNull objectParent _x}};
        if (_grupUye isNotEqualTo []) then {
            _k = ([_grupUye, [], {_x distance _unit}, "ASCEND"] call BIS_fnc_sortBy) select 0;
        };
        private _d = _k distance _unit;

        // Zaten iyi biliyorsa dokunma
        if ((_k knowsAbout _unit) < 1.5) then {
            private _duyuldu = _d < _menzil || {_catlama && {_d < 120}};
            private _gorulur = false;
            if (_d < _parlamaMenzil) then {
                // LOS: parlama / backblast duman gorulebilir mi
                _gorulur = !(terrainIntersectASL [eyePos _k, _eP]) && {!(lineIntersects [eyePos _k, _eP, _k, _unit])};
            };

            if (_duyuldu || {_gorulur}) then {
                private _lvl = if (_gorulur) then {
                    1.2 + (0.6 * (1 - (_d / (_parlamaMenzil max 1))))
                } else {
                    0.25 + (0.9 * (1 - (_d / (_menzil max 1))))
                };
                if (_catlama && {!_gorulur}) then { _lvl = _lvl min 0.5; };
                _lvl = (_lvl max 0.2) min 1.8;

                if (_lvl > (_k knowsAbout _unit)) then {
                    _k reveal [_unit, _lvl];
                };

                // Yaklasik yon: hata payi = mesafenin %12'si (gorulurse %4), catlamada +25 m
                private _hata = (_d * ([0.12, 0.04] select _gorulur)) + ([0, 25] select _catlama);
                private _tahmin = _pos getPos [random _hata, random 360];
                if (((_g getVariable [QGVAR(contact), 0]) < time) && {isNull (assignedTarget _k)}) then {
                    _k doWatch _tahmin;
                    [{ params ["_c"]; if (alive _c) then { _c doWatch objNull; }; }, [_k], 6] call CBA_fnc_waitAndExecute;
                    if (_lvl >= 0.8 && {(behaviour _k) in ["SAFE", "CARELESS"]}) then { _g setBehaviour "AWARE"; };
                };

                _g setVariable [QGVAR(sesSonZaman), time];
                _g setVariable [QGVAR(sesSonPos), _tahmin];

                // Gozlem logu (atici basina 10 sn'de bir)
                if ((time - (_unit getVariable [QGVAR(sesLog), -999])) > 10) then {
                    _unit setVariable [QGVAR(sesLog), time];
                    diag_log format [
                        "[SES] %1 -> %2 | %3 m | %4%5%6 | bilgi:%7 | %8",
                        name _unit, groupId _g, round _d,
                        ["", "ses "] select _duyuldu,
                        ["", "PARLAMA/DUMAN "] select _gorulur,
                        ["", "(susturucu)"] select _susturucu,
                        _lvl toFixed 2, _ammo
                    ];
                };
                _say = _say + 1;
            };
        };
    };
} forEach _adaylar;

_say
