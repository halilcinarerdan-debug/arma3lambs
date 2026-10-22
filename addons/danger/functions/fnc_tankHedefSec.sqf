#include "script_component.hpp"
/*
 * Author: Cinar (ELITE fork)
 * TANK HEDEF DAGITIMI (v8.251) — kullanici: "tank hedef dagitimi + AT atesine tepki" (RPT 4cceba48: tek T-14 19+ kisiyi vurdu; hedef secimi 'en pahali' siralamasiydi, tehdit onceligi / ates dagitimi yoktu).
 * Kitap: ATP 3-20.15 A-4 / A-5 / A-29 / A-31 (ates kontrolu: tehdit onceligi, ates dagitimi - ayni hedefe asiri yuklenmeme); sayilar TASARIM.
 * Verilen aday listesinden (nearTargets girdileri) bu arac icin EN ONEMLI hedefi secer:
 *   taban puan: dusman tanki (zirh >= 300) 100 | ATGM'li arac 95 | AT roketatarli piyade 90 | diger tank 85 | IFV 70 | statik silah 55 | APC 50 | MG 40 | AT disi roketatar 35 | topcu 30 | piyade 25 | diger 20 (hava hedefleri elenir)
 *   - mesafe / 40 | yakin (< 400 m) +15 | hedef son 8 sn ates etti +15
 *   - ates dagitimi: baska bir aracin 12 sn icindeki iddiasi -70 (dusman tanki icin v8.280: +20 = ODAKLI ATES, tum tanklar ayni dusman tankina yuklenir; kullanici: "tanklar daha koordine olsun") | kendi iddiasi +25 (histerezi)
 * Iddia tablosu: lambs_danger_tankIddia (hedef netId -> [arac netId, zaman]). Kapatma: lambs_danger_tankHedefDagitOff = true (planZirh eski 'en pahali' siralamaya doner).
 *
 * Arguments:
 * 0: Arac <OBJECT>
 * 1: Adaylar (nearTargets girdileri; [pos, tip, taraf, maliyet, nesne, dogruluk]) <ARRAY>
 *
 * Return Value: [hedef <OBJECT>, puan <NUMBER>] ya da []
 * Public: No
*/

params [["_v", objNull, [objNull]], ["_adaylar", [], [[]]]];
if (isNull _v || {_adaylar isEqualTo []}) exitWith {[]};
if (isNil "lambs_danger_tankIddia") then { lambs_danger_tankIddia = createHashMap; };
private _iddia = lambs_danger_tankIddia;
private _nid = netId _v;
private _rolFn = missionNamespace getVariable ["lambs_danger_fnc_getUnitRole", {"RIFLE"}];
// pahali sorgular (isATUnit / aracSinif) icin en yakin 16 aday
private _liste = [_adaylar, [], {(_x select 4) distance2D _v}, "ASCEND"] call BIS_fnc_sortBy;
if ((count _liste) > 16) then { _liste = _liste select [0, 16]; };

private _en = [];
private _enS = -1e9;
{
    private _o = _x select 4;
    if (isNull _o || {!alive _o} || {_o isKindOf "Air"}) then { continue };
    private _mesafe = _v distance2D _o;
    private _zirhTank = false;
    private _s = 20;
    if (_o isKindOf "CAManBase") then {
        _s = 25;
        if ((secondaryWeapon _o) isNotEqualTo "") then {
            _s = [35, 90] select ([_o] call FUNC(isATUnit));
        } else {
            if (([_o] call _rolFn) isEqualTo "MG") then { _s = 40; };
        };
    } else {
        private _sn = [_o] call FUNC(aracSinif);
        _zirhTank = _o isKindOf "Tank" && {(getNumber (configOf _o >> "armor")) >= 300};
        _s = switch (true) do {
            case (_zirhTank): {100};
            case (_sn select 3): {95};
            case ((_sn select 0) isEqualTo "TANK"): {85};
            case ((_sn select 0) isEqualTo "IFV"): {70};
            case (_o isKindOf "StaticWeapon"): {55};
            case ((_sn select 0) isEqualTo "APC"): {50};
            case ((_sn select 0) isEqualTo "TOPCU"): {30};
            default {20};
        };
    };
    _s = _s - (_mesafe / 40);
    if (_mesafe < 400) then { _s = _s + 15; };
    if ((time - (_o getVariable [QGVAR(sonAtisT), -999])) < 8) then { _s = _s + 15; };
    private _id = _iddia getOrDefault [netId _o, []];
    if (_id isNotEqualTo [] && {(time - (_id select 1)) < 12}) then {
        _s = _s + (if ((_id select 0) isEqualTo _nid) then {25} else { [-70, 20] select _zirhTank });
    };
    if (_s > _enS) then { _enS = _s; _en = _x; };
} forEach _liste;
if (_en isEqualTo []) exitWith {[]};

_iddia set [netId (_en select 4), [_nid, time]];
if ((count _iddia) > 80) then {
    { private _e = _iddia get _x; if (!isNil "_e" && {(time - (_e select 1)) > 30}) then { _iddia deleteAt _x; }; } forEach (keys _iddia);
};
[_en select 4, _enS]
