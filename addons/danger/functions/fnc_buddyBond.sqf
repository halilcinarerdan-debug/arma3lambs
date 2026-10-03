#include "script_component.hpp"
/*
 * Author: Cinar (ELITE fork)
 * BUDDY BAGI — kalici es + "TEK BASINA UZAKTA DOLASMA" kontrolu.
 *
 * Sorun: Buddy ciftleri yalnizca Bounding / Retreat icinde GECICI hesaplaniyordu; kalici bir
 *        es atamasi ve mesafe kontrolu yoktu. LAMBS'in dogal akisi (CQB doAssault, doCover/dodge,
 *        flank, hide...) sirasinda biri kopup uzakta tek basina dolasabiliyordu.
 *
 * Bu watchdog (server / HC basina bir kez, 3 sn'de bir):
 *   1) KALICI ES: her grup icin buddyPairs (en guclu + en zayif) -> her askere QGVAR(buddy) atar
 *      (uclu ciftte ucuncu askerin esi = capa)
 *   2) COHESION:
 *        - IZOLASYON: en yakin dost > izo limiti (sakin 40 m / catisma 45 m) -> en yakin dostun yanina
 *        - ES KOPMASI: esine uzaklik > cift limiti (sakin 25 m / catisma 30 m) -> esinin 5-9 m yanina
 *      (buddy rush koşucusu ~25-30m uzaklasir; es onu gecince cift yeniden kurulur)
 *   3) ATLANIR: Bounding / Retreat / Evade / Temas kes / AT taarruz (kendi hareket duzenleri var),
 *      rol istasyonuna yeni gonderilen asker (fnc_roleStation, 25 sn),
 *      hareket eden (forceMove / hizli), binada (garrison), baski >= 0.5 (FSM siper alir),
 *      dusman 25m icinde (dovusur), oyuncu, arac
 *   - grup basina tikte en fazla 2 asker, asker basina 10 sn cooldown, doMove (kalici emir)
 *
 * Arguments:
 * None
 *
 * Return Value:
 * Baslatildi mi <BOOL>
 *
 * Public: No
*/

if (!isNil "lambs_danger_buddyBondStarted") exitWith {false};
lambs_danger_buddyBondStarted = true;

diag_log "[BUDDY] buddy bagi (cohesion) watchdog baslatildi";

[] spawn {
    private _pairFn = missionNamespace getVariable ["lambs_danger_fnc_buddyPairs", {[_this select 0]}];

    while {true} do {
        sleep 3;

        {
            private _g = _x;
            if (isNull _g) then { continue };
            if (_g getVariable [QGVAR(sniperTeam), false]) then { continue };
            if ((count (units _g)) < 2) then { continue };

            private _leader = leader _g;
            if (isNull _leader || {isPlayer _leader}) then { continue };

            // Kendi hareket duzeni olan taktikler: atla
            if (
                (_g getVariable [QGVAR(isBounding), false])
                || {_g getVariable [QGVAR(isRetreating), false]}
                || {_g getVariable [QGVAR(isEvading), false]}
                || {_g getVariable [QGVAR(isBreakingContact), false]}
                || {_g getVariable [QGVAR(isATEngage), false]}
                || {_g getVariable [QGVAR(isExecutingTactic), false]}
                || {((_g getVariable [QGVAR(cmdLastDecision), ""]) in ["FLANK", "ASSAULT", "SUPPRESS_ASSAULT"]) && {(time - (_g getVariable [QGVAR(cmdSonKararZaman), -999])) < 30}}
            ) then { continue };

            private _savasta = (_g getVariable [QGVAR(contact), 0]) > time;
            // v8.20b: kama formasyonu 10 m aralik doktrini (FM 3-21.8) -> sakin halde 25 m (v8.19 gevsetmesi geri alindi; spawn hareketinin asil nedeni roleStation siralamasiydi)
            private _ciftLimit = [25, 30] select _savasta;
            private _izoLimit  = [40, 45] select _savasta;

            // Tum canli piyade + hareket edebilir (uygun) olanlar
            private _tum = (units _g) select {alive _x && {isNull objectParent _x}};
            if ((count _tum) < 2) then { continue };

            // Sunucuda ACE Medical AI var: saglikci yaralisina gidiyor, "tek basina dolasiyor" gibi
            // gorunur -> saglikcilar ve bayilmis/yarali-yatan askerler cohesion'dan muaf
            private _u = _tum select {
                local _x
                && {_x isNotEqualTo _leader}
                && {!isPlayer _x}
                && {!(_x getUnitTrait "medic")}
                && {(lifeState _x) in ["HEALTHY", "INJURED"]}
                && {!(_x getVariable [QGVAR(forceMove), false])} && {(_x getVariable [QGVAR(taktikKilit), 0]) <= time}
                && {(speed _x) < 1.5}
                && {(getSuppression _x) < 0.5}
                && {(insideBuilding _x) < 0.5}
                && {(time - (_x getVariable [QGVAR(stationLast), -999])) > 25}
                && {(_x getVariable [QGVAR(stationPos), []]) isEqualTo []}
                && {(_x getVariable [QGVAR(reloadState), []]) isEqualTo []}
                && {(_x getVariable [QGVAR(grState), []]) isEqualTo []}
            };
            if (_u isEqualTo []) then { continue };

            // 1) KALICI ES ATAMASI (STABIL): saglam ciftlere DOKUNULMAZ; sadece esi olmayan (olmus / ayrilmis /
            //    yeni katilan) YETIM askerler yeniden eslesir. Tek yetim -> en yakin dostun yanina (3'lu) baglanir.
            private _yetim = _tum select {
                private _bb = _x getVariable [QGVAR(buddy), objNull];
                isNull _bb || {!alive _bb} || {!(_bb in _tum)} || {_bb isEqualTo _x}
            };
            if ((count _yetim) >= 2) then {
                private _ciftler = [_yetim] call _pairFn;
                {
                    private _c = _x;
                    private _anchor = _c select 0;
                    {
                        if (_x isEqualTo _anchor) then {
                            _x setVariable [QGVAR(buddy), _c param [1, objNull]];
                        } else {
                            _x setVariable [QGVAR(buddy), _anchor];
                        };
                    } forEach _c;
                } forEach _ciftler;
            } else {
                if ((count _yetim) isEqualTo 1) then {
                    private _y = _yetim select 0;
                    private _yEs = objNull;
                    private _yMes = 99999;
                    {
                        if (_x isNotEqualTo _y) then {
                            private _dd = _y distance2D _x;
                            if (_dd < _yMes) then { _yMes = _dd; _yEs = _x; };
                        };
                    } forEach _tum;
                    if (!isNull _yEs) then { _y setVariable [QGVAR(buddy), _yEs]; };
                };
            };
            if (_yetim isNotEqualTo [] && {_savasta}) then {
                diag_log format ["[BUDDY] %1 | yetim %2 asker yeniden eslesti (es oldu / ayrildi): %3", groupId _g, count _yetim, _yetim apply {name _x}];
            };

            // 2) COHESION
            private _tasinan = 0;
            {
                private _m = _x;
                if (_tasinan < 2 && {_m in _u} && {(time - (_m getVariable [QGVAR(bondLast), -999])) > (10 max (_m getVariable [QGVAR(bondBekle), 0]))}) then {

                    // en yakin dost
                    private _enYakin = objNull;
                    private _enMes = 99999;
                    {
                        if (_x isNotEqualTo _m) then {
                            private _d = _m distance2D _x;
                            if (_d < _enMes) then {
                                _enMes = _d;
                                _enYakin = _x;
                            };
                        };
                    } forEach _tum;

                    private _es = _m getVariable [QGVAR(buddy), objNull];
                    private _esMes = if (!isNull _es && {alive _es}) then {_m distance2D _es} else {_enMes};

                    private _hedefDost = objNull;
                    private _mes = 0;
                    private _limit = 0;
                    if (_enMes > _izoLimit) then {
                        _hedefDost = _enYakin;
                        _mes = _enMes;
                        _limit = _izoLimit;
                    } else {
                        if (_esMes > _ciftLimit && {!isNull _es} && {alive _es}) then {
                            _hedefDost = _es;
                            _mes = _esMes;
                            _limit = _ciftLimit;
                        };
                    };

                    if (!isNull _hedefDost && {alive _hedefDost}) then {
                        // dusman 25m icindeyse dovusur, yanina kosmaz
                        private _dusman = _m findNearestEnemy _m;
                        private _yakinDusman = !isNull _dusman && {(_m distance2D _dusman) < 25};
                        if (!_yakinDusman) then {
                            // Dusman biliniyorsa dostun dusmana DONUK degil ARKA / yan tarafina (+-60 derece) don
                            private _yonB = if (isNull _dusman) then {random 360} else {((_dusman getDir _hedefDost) + ((random 120) - 60))};
                            private _p = (getPosATL _hedefDost) getPos [5 + (random 4), _yonB];
                            if (!surfaceIsWater _p) then {
                                // v8.43: ILERLEME KONTROLU — onceki emirden beri >= 10 m yaklasmadiysa (takili / mission'in sabitledigi / ulasilamayan asker)
                                //   3. denemeden sonra 120 sn beklet + bir kez logla (RPT 5ef891c1: ayni asker cifti 2.5 saat 119 m'de, 4214 BUDDY satiri, her 10 sn doMove)
                                private _oncekiMes = _m getVariable [QGVAR(bondOncekiMes), -1];
                                if (_oncekiMes >= 0 && {(time - (_m getVariable [QGVAR(bondLast), -999])) < 90} && {_mes > (_oncekiMes - 10)}) then {
                                    _m setVariable [QGVAR(bondBasarisiz), (_m getVariable [QGVAR(bondBasarisiz), 0]) + 1];
                                } else {
                                    _m setVariable [QGVAR(bondBasarisiz), 0];
                                    _m setVariable [QGVAR(bondBekle), 0];
                                };
                                _m setVariable [QGVAR(bondOncekiMes), _mes];
                                if ((_m getVariable [QGVAR(bondBasarisiz), 0]) >= 3) then {
                                    _m setVariable [QGVAR(bondBekle), 120];
                                    _m setVariable [QGVAR(bondBasarisiz), 0];
                                    _m setVariable [QGVAR(bondLast), time];
                                    diag_log format ["[BUDDY-TAKILI] %1 | %2 | 3 emirde ilerleme yok (%3 m) -> 120 sn beklet", groupId _g, name _m, round _mes];
                                    continue
                                };
                                _m setVariable [QGVAR(bondLast), time];
                                _g setVariable [QGVAR(buddyLast), time];
                                _tasinan = _tasinan + 1;
                                _m doMove _p;
                                diag_log format [
                                    "[BUDDY] %1 | %2 | %3 %4m (limit %5m) -> %6 yanina donuyor",
                                    groupId _g, name _m,
                                    ["es kopmasi", "izole"] select (_limit isEqualTo _izoLimit),
                                    round _mes, _limit, name _hedefDost
                                ];
                            };
                        };
                    };
                };
            } forEach _tum;
        } forEach allGroups;
    };
};

true
