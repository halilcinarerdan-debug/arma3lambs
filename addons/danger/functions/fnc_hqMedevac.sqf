#include "script_component.hpp"
/*
 * Author: Cinar (ELITE fork)
 * KUMANDA MODULU: MEDEVAC KOORDINASYONU (gruplar arasi yaralı yardimi; TCCC ile entegre).
 *
 * SORUN: grupta hekim yok / olu ise baygin yaralilar TCCC'de (fnc_tccc) sadece KENDI grubundan hekim aradigi icin sonsuza dek yerde kalir.
 * COZUM (ilkel, genel degil): yaralisi olan ve hekimi olmayan grup icin, ayni taraftan MUSAIT bir grubun hekimini yaraliya ATAR (yaralida lambs_danger_hqMedic = hekim).
 *   TCCC dongusu atanan hekimi kabul eder (yuruyus suresi mesafeye gore), tedaviyi (M / kanama, kenara cekme) kendi kurallariyla yapar, bitince hekim kendi grubuna doner (doFollow).
 *
 * YARALI ADAYI: grup uyesi, canli, baygin (INCAPACITATED / ACE_isUnconscious) ya da agir kanama; TCCC tarafindan alinmamis; hqMedic atanmamis (ya da atanan olu / 120 sn gecti).
 * GRUPTA HEKIM: bilinc yerinde bir uye hekim (trait Medic ya da sargi / turnike tasiyor).
 * YARDIM VEREN: tahta 'musait' grup, hekimi var, yaraliya 40 - hqMedevacM (600; v8.82: 350 -> 600) m, hekim meşgul degil.
 * GUVENLI MI: yardim isteyen grup son 8 sn temasta degil ve bilinen dusman yaraliya >= 70 m (cmdSit pozisyonu).  Degilse bekler (hekim tehlikeye atilmaz).
 * Turda en cok 1 atama. Log: [HQ-MEDEVAC] (ilk 120 satir).
 *
 * Kapatma: lambs_danger_hqMedevacV1 = false; doktrin anahtari hqMedevac (varsayilan true), hqMedevacM (varsayilan 600).
 *
 * Arguments:
 * 0: Taraf <SIDE>
 * 1: Durum tahtasi <ARRAY of HASHMAP>
 *
 * Return Value: Atama yapildi mi <BOOL>
 * Public: No
*/

params [["_taraf", sideUnknown, [sideUnknown]], ["_tahta", [], [[]]]];

private _bilincli = {
    params ["_u"];
    alive _u && {(lifeState _u) in ["HEALTHY", "INJURED"]} && {!(_u getVariable ["ACE_isUnconscious", false])}
};
private _hekimMi = {
    params ["_u"];
    ([_u] call _bilincli)
    && {
        (_u getUnitTrait "Medic")
        || {((items _u) findIf {(toLower _x) in ["ace_packingbandage", "ace_elasticbandage", "ace_fielddressing", "ace_quikclot", "ace_tourniquet", "firstaidkit", "medikit"]}) > -1}
    }
};

// yardim isteyen: yaralisi var, hekimi yok, guvenli
private _atandi = false;
{
    if (_atandi) exitWith {};
    private _istek = _x;
    private _g = _istek get "g";
    if (!([_g, "hqMedevac", true] call FUNC(dk))) then { continue };
    if ((_istek get "temasta") || {(_istek get "temasSure") < 8}) then { continue };
    if ((units _g) findIf {[_x] call _hekimMi} > -1) then { continue };

    private _yaralilar = (units _g) select {
        alive _x
        && {((lifeState _x) isEqualTo "INCAPACITATED") || {_x getVariable ["ACE_isUnconscious", false]}}
        && {isNull (_x getVariable [QGVAR(tcccBy), objNull])}
        && {(time - (_x getVariable [QGVAR(tcccDone), -999])) > 60}
        && {
            private _hm = _x getVariable [QGVAR(hqMedic), objNull];
            isNull _hm || {!alive _hm} || {(time - (_x getVariable [QGVAR(hqMedicT), -999])) > 120}
        }
    };
    if (_yaralilar isEqualTo []) then { continue };

    private _sit = _istek get "sit";
    private _enP = if (_sit isEqualType [] && {(count _sit) >= 8} && {(_sit select 7) isEqualType []}) then {_sit select 7} else {[0, 0, 0]};
    private _menzil = [_g, "hqMedevacM", 600] call FUNC(dk);

    {
        if (_atandi) exitWith {};
        private _c = _x;
        // bilinen dusman yaraliya cok yakinsa gonderme (hekimi harcama)
        if (_enP isNotEqualTo [0, 0, 0] && {((getPosATL _c) distance2D _enP) < 70}) then { continue };

        // aday hekimler: musait gruplardan
        private _hekimler = [];
        {
            private _y = _x;
            if ((_y get "g") isEqualTo _g) then { continue };
            if (!(_y get "musait")) then { continue };
            private _d = (_y get "poz") distance2D (getPosATL _c);
            if (_d < 40 || {_d > _menzil}) then { continue };
            {
                if ([_x] call _hekimMi && {isNull (_x getVariable [QGVAR(tcccBy), objNull])} && {time > (_x getVariable [QGVAR(tcccBusy), 0])}
                    && {((_x distance2D _c) <= _menzil)}) then {
                    _hekimler pushBack _x;
                };
            } forEach ((units (_y get "g")) select {local _x && {!isPlayer _x} && {isNull objectParent _x}});
        } forEach _tahta;
        if (_hekimler isEqualTo []) then { continue };

        // rol onceligi: asil hekim (trait) > sargi tasiyan; sonra yakinlik
        private _sirali = [_hekimler, [], { ([0, 100] select (_x getUnitTrait "Medic")) - (_x distance2D _c) }, "DESCEND"] call BIS_fnc_sortBy;
        private _m = _sirali select 0;

        _c setVariable [QGVAR(hqMedic), _m];
        _c setVariable [QGVAR(hqMedicT), time];
        _atandi = true;

        if (isNil "lambs_danger_hqMedevacN") then { lambs_danger_hqMedevacN = 0; };
        if (lambs_danger_hqMedevacN < 120) then {
            lambs_danger_hqMedevacN = lambs_danger_hqMedevacN + 1;
            diag_log format [
                "[HQ-MEDEVAC] %1 | yarali %2 (%3, grupta hekim yok) <- hekim %4 (%5) %6 m | aday hekim:%7 yarali:%8",
                _taraf, name _c, groupId _g, name _m, groupId (group _m), round (_m distance2D _c), count _hekimler, count _yaralilar
            ];
        };
        [group _m, "MEDEVAC", name _c] call FUNC(olayGonder);
    } forEach _yaralilar;
} forEach _tahta;

_atandi
