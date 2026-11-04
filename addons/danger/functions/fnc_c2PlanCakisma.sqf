#include "script_component.hpp"
/*
 * Author: Cinar (ELITE fork)
 * C2: OYUNCU WAYPOINT'I OBJEKTIF PLANIYLA CAKISIYOR MU (v8.392; kullanici: 'tum waypointler objektif ile cakismasin').
 * Verilen nokta, AYNI TARAFIN aktif (faz BITTI / IPTAL degil) objektif planlarinin onemli noktalarina (objektif, toplanma RP, ORP, CCP, destek ates noktasi SBF) CBA c2PlanYaricap (varsayilan 150 m)
 * icindeyse cakisma sayilir: plan gruplari ve plan topcusu orada calisiyordur (dost ates / yigilma / emir cakismasi). 0 = kontrol kapali.
 * (Gruplarin kendisi icin ayri kural: plana bagli grup (lambs_danger_planAktif) C2 emri almaz - fnc_c2Emir.)
 *
 * Arguments:
 * 0: Taraf <SIDE>
 * 1: Nokta <ARRAY>
 *
 * Return Value: [cakisma <BOOL>, aciklama <STRING>]
 * Public: No
*/

params [["_taraf", sideUnknown, [sideUnknown]], ["_poz", [], [[]]]];

private _yar = missionNamespace getVariable ["lambs_danger_c2PlanYaricap", 150];
if (_yar <= 0 || {_poz isEqualTo []} || {isNil "lambs_danger_planlar"}) exitWith {[false, ""]};

private _sonuc = [false, ""];
{
    private _pl = _x;
    if ((_pl getOrDefault ["taraf", sideUnknown]) isEqualTo _taraf && {!((_pl getOrDefault ["faz", ""]) in ["BITTI", "IPTAL"])}) then {
        {
            _x params ["_anahtar", "_ad"];
            private _v = _pl getOrDefault [_anahtar, []];
            private _liste = [];
            if (_v isEqualType [] && {count _v > 0}) then {
                if ((_v select 0) isEqualType []) then { _liste = _v; } else { if (count _v >= 2 && {(_v select 0) isEqualType 0}) then { _liste = [_v]; }; };
            };
            {
                if (!(_sonuc select 0) && {(_x isEqualType [])} && {count _x >= 2} && {(_x distance2D _poz) < _yar}) then {
                    _sonuc = [true, format ["%1 plani (%2) %3: %4 m (sinir %5 m)", _pl getOrDefault ["id", "?"], ["ELE GECIR", "SAVUN"] select ((_pl getOrDefault ["tip", 0]) isEqualTo 1), _ad, round (_x distance2D _poz), round _yar]];
                };
            } forEach _liste;
        } forEach [["obj", "objektifi"], ["rp", "toplanma noktasi (RP)"], ["orp", "ORP"], ["ccp", "CCP"], ["sbf", "destek ates noktasi"]];
    };
} forEach (values lambs_danger_planlar);

_sonuc
