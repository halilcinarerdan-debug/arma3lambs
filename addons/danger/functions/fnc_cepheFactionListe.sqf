#include "script_component.hpp"
/*
 * Author: Cinar (ELITE fork)
 * CEPHE FACTION LISTESI (v8.237, Dilim A0) — kullanici karari: "factionlar OTOMATIK taninir (RHS / GM / vb.)".
 * CfgVehicles'ta scope 2 + simulation "soldier" olan yaya siniflari faction'a gore sayar; >= 4 sinifi olan, BLUFOR / OPFOR / INDEP factionlari listeler.
 * Yan urun: lambs_danger_cepheAdamSinif (HashMap faction -> yaya sinif listesi; squad sablonu olmayan factionlar icin yedek havuz).
 * Zeus paneli (istemci) ve fnc_cepheFaction (sunucu) kullanir; sonuc onbellege alinir. Tarama bir kez ~1-3 sn surebilir (sunucu RPT'sine yazilir).
 *
 * Arguments: None
 * Return Value: [[faction, gorunenAd, taraf(0 east 1 west 2 indep), sablonSayisi, yayaSinifSayisi], ...] <ARRAY> (taraf, ad siralı)
 * Public: No
*/

if (!isNil "lambs_danger_cepheFactionOnbellek") exitWith { lambs_danger_cepheFactionOnbellek };

private _t0 = diag_tickTime;
private _havuz = createHashMap;
{
    private _f = getText (_x >> "faction");
    if (_f isNotEqualTo "") then {
        private _l = _havuz getOrDefault [_f, []];
        _l pushBack (configName _x);
        _havuz set [_f, _l];
    };
} forEach ("(getNumber (_x >> 'scope') isEqualTo 2) && {getText (_x >> 'simulation') isEqualTo 'soldier'}" configClasses (configFile >> "CfgVehicles"));

private _liste = [];
{
    private _f = _x;
    private _sinifler = _y;
    private _sideNum = getNumber (configFile >> "CfgFactionClasses" >> _f >> "side");
    if (_sideNum in [0, 1, 2] && {(count _sinifler) >= 4}) then {
        private _ad = getText (configFile >> "CfgFactionClasses" >> _f >> "displayName");
        if (_ad isEqualTo "") then { _ad = _f; };
        _liste pushBack [_sideNum, toLower _ad, _f, _ad, count ([_f] call FUNC(cepheSablon)), count _sinifler];
    };
} forEach _havuz;
_liste sort true;
_liste = _liste apply { [_x select 2, _x select 3, _x select 0, _x select 4, _x select 5] };

lambs_danger_cepheAdamSinif = _havuz;
lambs_danger_cepheFactionOnbellek = _liste;
private _toplam = 0;
{ _toplam = _toplam + (count _y); } forEach _havuz;
diag_log format ["[CEPHE-FACTION-TARAMA] %1 faction bulundu (%2 yaya sinif), %3 ms", count _liste, _toplam, round ((diag_tickTime - _t0) * 1000)];
_liste
