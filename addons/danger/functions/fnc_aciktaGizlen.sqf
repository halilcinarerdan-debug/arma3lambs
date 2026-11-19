#include "script_component.hpp"
/*
 * Author: Cinar (ELITE fork)
 * ACIKTA GIZLEN: BOS HARITADA ARAZI ORTUSU / YATIS (v8.595; kullanici: 'bunun gibi bos haritada daha iyi gizlensinler'; RPT 38287827 pmc_ukraine_donetsk: acikta 100-225 ornek / dk, 'hic yok' %97; sert siper / agac / cali yok).
 * Cagiran: fnc_coverHug — temasta, duran, ACIKTA ve 20 m icinde HICBIR siper sinifi (sert / agac / cali / bina) yok olan asker icin.
 *   1) ARAZI ORTUSU (yer sirti / cukur / mevzi): dusmandan 8 / 14 / 22 m yaricapta, dusmana 4 m'den fazla yaklasmayan 10 aday nokta; dusmanin gozunden o noktanin YATIK yuksekligine (0.45 m) hat ARAZI tarafindan kesiliyorsa
 *      (terrainIntersectASL) aday; en yakin aday: doMove (taktikKilit 8 sn). Varinca fnc_coverHug arazi dali (terrainIntersect) yatik / comelik durusu uygular.
 *   2) Arazi ortusu yoksa dusman >= 70 m ise oldugu yerde YAT (setUnitPosWeak DOWN: yatik durus siluet / gorulme olasiligini azaltir; ates gerekirse motor kalkar).
 * Asker basina 6 sn'de bir. ATLANIR: teslim / esir, hareket (>= 1.5 km/s), forceMove, taktikKilit. Kapatma: CBA lambs_danger_aciktaGizlen. Log: [ACIKTA-GIZLEN] (ilk 25).
 *
 * Arguments:
 * 0: Asker <OBJECT>
 * 1: En yakin bilinen dusman <OBJECT>
 *
 * Return Value: Yonlendirildi / yatirildi mi <BOOL>
 * Public: No
*/

params [["_u", objNull, [objNull]], ["_en", objNull, [objNull]]];
if (isNull _u || {isNull _en} || {!(missionNamespace getVariable ["lambs_danger_aciktaGizlen", true])}) exitWith {false};
if (captive _u || {_u getVariable [QGVAR(teslim), false]} || {(speed _u) > 1.5} || {_u getVariable [QGVAR(forceMove), false]} || {(_u getVariable [QGVAR(taktikKilit), 0]) > time}) exitWith {false};
if (time < (_u getVariable [QGVAR(gizlenT), 0])) exitWith {false};
_u setVariable [QGVAR(gizlenT), time + 6];

private _eASL = eyePos _en;
private _ed = _u distance2D _en;
private _yonE = _u getDir _en;
private _aday = [];
{
    _x params ["_r", "_ofs"];
    private _p = _u getPos [_r, _yonE + _ofs];
    if (!surfaceIsWater _p && {(_p distance2D _en) >= (_ed - 4)}) then {
        if (terrainIntersectASL [_eASL, (ATLToASL _p) vectorAdd [0, 0, 0.45]]) then { _aday pushBack [_r, _p]; };
    };
} forEach [[8, 90], [8, -90], [8, 180], [14, 90], [14, -90], [14, 135], [14, -135], [22, 90], [22, -90], [22, 180]];
// v8.665 UZAK DUSMAN = DAHA GENIS ARAZI ARAMASI (RPT 5b2735f6 lythium: dusman 316-361 m, 8 / 14 / 22 m'de arazi ortusu yok -> 'yat (arazi ortusu yok)' 8 / 8; uzak dusmanda sure var, 45 m'ye kadar cukur / sirt aranabilir): dusman >= 200 m ise 32 / 45 m halkalari, 8 yonlu
if (_aday isEqualTo [] && {_ed >= 200}) then {
    {
        _x params ["_r", "_ofs"];
        private _p = _u getPos [_r, _yonE + _ofs];
        if (!surfaceIsWater _p && {(_p distance2D _en) >= (_ed - 6)}) then {
            if (terrainIntersectASL [_eASL, (ATLToASL _p) vectorAdd [0, 0, 0.45]]) then { _aday pushBack [_r, _p]; };
        };
    } forEach [[32, 90], [32, -90], [32, 135], [32, -135], [32, 180], [45, 90], [45, -90], [45, 135], [45, -135], [45, 180], [45, 45], [45, -45]];
};
private _sonuc = "";
if (_aday isNotEqualTo []) then {
    _aday sort true;
    private _p = (_aday select 0) select 1;
    // yakinda dost yigilmasin
    if (((_p nearEntities ["CAManBase", 2]) findIf {_x isNotEqualTo _u && {alive _x}}) < 0) then {
        _u setVariable [QGVAR(taktikKilit), time + 8];
        _u doMove _p;
        _sonuc = format ["arazi ortusu %1 m", round ((_aday select 0) select 0)];
    };
};
if (_sonuc isEqualTo "" && {_ed >= 70}) then {
    _u setUnitPosWeak "DOWN";
    _sonuc = "yat (arazi ortusu yok)";
};
if (_sonuc isEqualTo "") exitWith {false};
if ((missionNamespace getVariable ["lambs_danger_gizlenLogN", 0]) < 25) then {
    missionNamespace setVariable ["lambs_danger_gizlenLogN", (missionNamespace getVariable ["lambs_danger_gizlenLogN", 0]) + 1];
    diag_log format ["[ACIKTA-GIZLEN] %1 | %2 | dusman %3 m | %4", groupId (group _u), name _u, round _ed, _sonuc];
};
true
