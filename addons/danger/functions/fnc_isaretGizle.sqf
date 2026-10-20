#include "script_component.hpp"
/*
 * Author: Cinar (ELITE fork)
 * ELITE ISARETLERINI DUSMANDAN GIZLE (v8.271) — kullanici: "karsi tarafa dusmansak onlarin markerlari gozukmesin".
 * ELITE harita isaretleri (ELITE_PLAN_*, ELITE_MANUEL_*, ELITE_MEVZI_*, ELITE_KARAKOL_*, ELITE_HQ_*) sunucuda GLOBAL olusturulur (sunucu markerPos ile okur: gozetleme, hendek, objektif modulu);
 * bu istemci betigi 3 sn'de bir, oyuncunun tarafi isaretin tarafina (isaret rengi: ColorBLUFOR / ColorOPFOR / ColorIndependent) DUSMANSA (getFriend < 0.6) isareti YEREL olarak saydamlastirir (setMarkerAlphaLocal 0).
 * Zeus (curator) varsayilan olarak hepsini gorur (CBA 'Zeus tum ELITE isaretlerini gorur'). Kapatma: CBA 'Dusman ELITE isaretlerini gizle' (lambs_danger_isaretGizleV1 = false).
 * Not: yalniz istemci (hasInterface); sunucu / HC calismaz. Oyuncunun tarafi sivil / bilinmiyorsa gizleme yapilmaz.
 *
 * Arguments: None
 * Return Value: Baslatildi mi <BOOL>
 * Public: No
*/

if (!hasInterface) exitWith {false};
if (!isNil "lambs_danger_isaretGizleStarted") exitWith {false};
lambs_danger_isaretGizleStarted = true;

[] spawn {
    waitUntil { sleep 1; !isNull player };
    private _gizli = createHashMap;
    while {true} do {
        sleep 3;
        private _etkin = missionNamespace getVariable ["lambs_danger_isaretGizleV1", true];
        private _zeusGorur = missionNamespace getVariable ["lambs_danger_isaretZeusTum", true] && {!isNull (getAssignedCuratorLogic player)};
        private _ben = playerSide;
        private _isaretler = allMapMarkers select {(_x find "ELITE_") isEqualTo 0};
        {
            private _m = _x;
            private _ms = switch (markerColor _m) do {
                case "ColorBLUFOR": {west};
                case "ColorOPFOR": {east};
                case "ColorIndependent": {independent};
                default {sideUnknown};
            };
            private _dusman = _ms isNotEqualTo sideUnknown && {_ben in [west, east, independent]} && {(_ben getFriend _ms) < 0.6};
            private _gizle = _etkin && {_dusman} && {!_zeusGorur};
            if (_gizle) then {
                if !(_m in _gizli) then { _gizli set [_m, true]; _m setMarkerAlphaLocal 0; };
            } else {
                if (_m in _gizli) then { _gizli deleteAt _m; _m setMarkerAlphaLocal 1; };
            };
        } forEach _isaretler;
        // silinmis isaretleri kayittan dusur
        { if !(_x in _isaretler) then { _gizli deleteAt _x; }; } forEach (keys _gizli);
    };
};
true
