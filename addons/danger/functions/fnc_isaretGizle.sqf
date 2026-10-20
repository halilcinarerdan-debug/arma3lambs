#include "script_component.hpp"
/*
 * Author: Cinar (ELITE fork)
 * ELITE ISARETLERINI DUSMANDAN GIZLE (v8.271) — kullanici: "karsi tarafa dusmansak onlarin markerlari gozukmesin".
 * ELITE harita isaretleri (ELITE_PLAN_*, ELITE_MANUEL_*, ELITE_MEVZI_*, ELITE_KARAKOL_*, ELITE_HQ_*) sunucuda GLOBAL olusturulur (sunucu markerPos ile okur: gozetleme, hendek, objektif modulu);
 * bu istemci betigi 3 sn'de bir, oyuncunun tarafi isaretin tarafina (isaret rengi: ColorBLUFOR / ColorOPFOR / ColorIndependent) DUSMANSA (getFriend < 0.6) isareti YEREL olarak saydamlastirir (setMarkerAlphaLocal 0).
 * Zeus (curator) varsayilan olarak (v8.274) hepsini GORMEZ; hepsini gormek icin CBA 'ELITE isaret gorunumu' = Hepsi ya da 'Zeus tum ELITE isaretlerini gorur'. Kapatma: CBA 'Dusman ELITE isaretlerini gizle' (lambs_danger_isaretGizleV1 = false).
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
    private _sonLog = "";
    private _sonLogT = -999;
    while {true} do {
        sleep 3;
        private _etkin = missionNamespace getVariable ["lambs_danger_isaretGizleV1", true];
        // v8.274: Zeus varsayilan artik hepsini GORMEZ (kullanici: 'hala dusman markerlari gozukuyor' - Zeus oyuncu olarak varsayilan 'hepsini gor' bunu gizliyordu); eski davranis icin CBA 'Zeus tum ELITE isaretlerini gorur'
        private _zeusGorur = missionNamespace getVariable ["lambs_danger_isaretZeusTum", false] && {!isNull (getAssignedCuratorLogic player)};
        // gorunum: 0 otomatik (oyuncunun tarafi) / 1 BLUFOR / 2 OPFOR / 3 INDEP / 4 hepsi (CBA 'ELITE isaret gorunumu'); sivil / sanal (Zeus yalniz) oyuncuda otomatik = hepsi
        private _gorunum = missionNamespace getVariable ["lambs_danger_isaretGorunum", 0];
        private _ben = switch (_gorunum) do { case 1: {west}; case 2: {east}; case 3: {independent}; case 4: {sideUnknown}; default {playerSide} };
        private _tekTaraf = _gorunum in [1, 2, 3];
        private _isaretler = allMapMarkers select {(_x find "ELITE_") isEqualTo 0};
        private _gizSay = 0;
        {
            private _m = _x;
            private _ms = switch (markerColor _m) do {
                case "ColorBLUFOR": {west};
                case "ColorOPFOR": {east};
                case "ColorIndependent": {independent};
                default {sideUnknown};
            };
            private _benGecerli = _ben in [west, east, independent];
            private _dusman = _ms isNotEqualTo sideUnknown && {_benGecerli} && {if (_tekTaraf) then {_ms isNotEqualTo _ben} else {(_ben getFriend _ms) < 0.6}};
            private _gizle = _etkin && {_dusman} && {!_zeusGorur};
            if (_gizle) then { _gizSay = _gizSay + 1; };
            if (_gizle) then {
                if !(_m in _gizli) then { _gizli set [_m, true]; };
                _m setMarkerAlphaLocal 0;   // her turda yeniden uygulanir (baska betik / sunucu alfa degistirirse)
            } else {
                if (_m in _gizli) then { _gizli deleteAt _m; _m setMarkerAlphaLocal 1; };
            };
        } forEach _isaretler;
        { if !(_x in _isaretler) then { _gizli deleteAt _x; }; } forEach (keys _gizli);
        // tani: durum degisince ya da 120 sn'de bir
        private _log = format ["taraf %1 | gorunum %2 | curator %3 | zeusTum %4 | etkin %5 | ELITE isaret %6 | gizlenen %7", _ben, _gorunum, !isNull (getAssignedCuratorLogic player), _zeusGorur, _etkin, count _isaretler, _gizSay];
        if (_log isNotEqualTo _sonLog || {(time - _sonLogT) > 120}) then {
            _sonLog = _log;
            _sonLogT = time;
            diag_log format ["[ISARET-GIZLE] %1", _log];
        };
    };
};
true
