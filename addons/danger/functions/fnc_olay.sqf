#include "script_component.hpp"
/*
 * Author: Cinar (ELITE fork)
 * GRUP OLAY SISTEMI — uretici watcher + yerlesik dinleyici (fnc_olayGonder ile birlikte).
 *
 * URETICILER (bu dosya):
 *   InContact : grup temasa girdi (lambs_danger_contact > time, onceki durum temas yok)
 *   AllClear  : temas bitti 20 sn (grup kendini guvende sayar)
 *   Casualty  : grupta bir asker oldu (CBA Killed sinif olayi) | veri = [olenAd, oldurenAd]
 *
 * YERLESIK DINLEYICI (guvenlik agi):
 *   AllClear'da retreat / evade / temas kes / bounding bayragi YOKSA kalan taktik kilitlerini ve retreat'in actigi birim duzeyi
 *   lambs_danger_disableAI bayragini temizler (retreat anormal bittiyse AI kapali kalmasin).
 *
 * Diger sistemler "lambs_danger_grupOlayi" olayini dinleyerek (CBA_fnc_addEventHandler) polling'siz tepki verebilir.
 *
 * Arguments:
 * None
 *
 * Return Value:
 * Baslatildi mi <BOOL>
 *
 * Public: No
*/

if (!isNil "lambs_danger_olayStarted") exitWith {false};
lambs_danger_olayStarted = true;

diag_log "[OLAY] grup olay sistemi baslatildi (InContact / AllClear / Casualty + guvenlik agi)";

// --- Casualty: sinif olayi (olen birimin grubu) ---
["CAManBase", "Killed", {
    params ["_u", "_killer"];
    private _g = group _u;
    if (isNull _g || {(side _g) isEqualTo civilian}) exitWith {};
    [_g, "Casualty", [name _u, if (isNull _killer) then {"?"} else {name _killer}]] call (missionNamespace getVariable ["lambs_danger_fnc_olayGonder", {false}]);
}] call CBA_fnc_addClassEventHandler;

// --- YERLESIK DINLEYICI: AllClear guvenlik agi ---
["lambs_danger_grupOlayi", {
    params ["_g", "_ad"];
    if (_ad isNotEqualTo "AllClear" || {isNull _g}) exitWith {};
    if (
        (_g getVariable [QGVAR(isRetreating), false]) || {_g getVariable [QGVAR(isEvading), false]}
        || {_g getVariable [QGVAR(isBreakingContact), false]} || {_g getVariable [QGVAR(isBounding), false]}
    ) exitWith {};
    private _temiz = 0;
    {
        if ((_x getVariable [QGVAR(taktikKilit), 0]) > 0) then { _x setVariable [QGVAR(taktikKilit), nil]; _temiz = _temiz + 1; };
        private _eski = _x getVariable [QGVAR(retreatEskiDAI), -1];
        if (_eski isNotEqualTo -1) then {
            _x setVariable [QGVAR(disableAI), [nil, true] select _eski];
            _x setVariable [QGVAR(retreatEskiDAI), nil];
            _temiz = _temiz + 1;
        };
    } forEach (units _g);
    if (_temiz > 0) then {
        diag_log format ["[OLAY] %1 | AllClear guvenlik agi: %2 asker bayragi temizlendi", groupId _g, _temiz];
    };
}] call CBA_fnc_addEventHandler;

// --- URETICI WATCHER: temas gecisleri (2 sn) ---
[] spawn {
    private _gonder = missionNamespace getVariable ["lambs_danger_fnc_olayGonder", {false}];
    while {true} do {
        sleep 2;
        {
            private _g = _x;
            if (isNull _g || {!local _g} || {isPlayer (leader _g)}) then { continue };
            private _c = _g getVariable [QGVAR(contact), 0];
            private _temasta = _c > time;
            private _durum = _g getVariable [QGVAR(olayDurum), "AllClear"];
            if (_temasta && {_durum isNotEqualTo "InContact"}) then {
                _g setVariable [QGVAR(olayDurum), "InContact"];
                [_g, "InContact", round (time - _c)] call _gonder;
            } else {
                if (!_temasta && {_durum isEqualTo "InContact"} && {(time - _c) > 20}) then {
                    _g setVariable [QGVAR(olayDurum), "AllClear"];
                    [_g, "AllClear", round (time - _c)] call _gonder;
                };
            };
        } forEach allGroups;
    };
};

true
