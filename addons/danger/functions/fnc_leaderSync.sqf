#include "script_component.hpp"
/*
 * Author: Cinar (ELITE fork)
 * KOMUTAN BEKLE — komutan timini geride birakip tek basina ilerlemesin.
 *
 * Catisma / taktik halindeki gruplarda (3 sn'de bir) komutanin hareket yonune gore
 * "arkada kalan" askerleri olcer. Komutan kosarken timin buyuk kismi >25 m geride ise:
 *   - KADEME 1 (yavasla): komutan yuruyus hizina duser (forceSpeed 1.8)
 *   - KADEME 2 (bekle)  : takim >45 m geride ise komutanin PATH'i max 20 sn kapatilir
 *     (emri iptal olmaz; tim yetisince PATH acilir ve ayni hedefe devam eder)
 *   - birakma: tim yetisti / komutan baskida veya dusman <40 m / sure doldu
 *   - bekleme sonrasi 25 sn cooldown (komutan sonsuza kadar donmasin)
 *
 * ATLANIR: komutan oyuncu / aracta, grup <3, retreat / evade / temas kes / AT taarruz,
 *          FLANK / ASSAULT (ayri manevra unsuru: komutan zaten ayri hareket eder)
 *
 * Arguments:
 * None
 *
 * Return Value:
 * Baslatildi mi <BOOL>
 *
 * Public: No
*/

if (!isNil "lambs_danger_leaderSyncStarted") exitWith {false};
lambs_danger_leaderSyncStarted = true;

diag_log "[KOMUTAN-BEKLE] komutan senkron watchdog baslatildi";

[] spawn {
    private _birak = {
        params ["_g", "_l", "_neden"];
        if (!isNull _l) then {
            if (_g getVariable [QGVAR(syncHold), false]) then { _l enableAI "PATH"; };
            if (_g getVariable [QGVAR(syncSlow), false]) then { _l forceSpeed -1; };
        };
        if ((_g getVariable [QGVAR(syncHold), false]) || {_g getVariable [QGVAR(syncSlow), false]}) then {
            diag_log format ["[KOMUTAN-BEKLE] %1 | birak: %2", groupId _g, _neden];
        };
        _g setVariable [QGVAR(syncHold), false];
        _g setVariable [QGVAR(syncSlow), false];
    };

    while {true} do {
        sleep 3;
        {
            private _g = _x;
            if (isNull _g || {!local _g}) then { continue };
            private _l = leader _g;
            private _tutuyor = (_g getVariable [QGVAR(syncHold), false]) || {_g getVariable [QGVAR(syncSlow), false]};

            // --- gecerlilik ---
            private _gecersiz = isNull _l || {!alive _l} || {isPlayer _l} || {!isNull objectParent _l}
                || {_tutuyor && {(_g getVariable [QGVAR(syncLeader), objNull]) isNotEqualTo _l}};
            private _kendiDuzen = (_g getVariable [QGVAR(isRetreating), false])
                || {_g getVariable [QGVAR(isEvading), false]}
                || {_g getVariable [QGVAR(isBreakingContact), false]}
                || {_g getVariable [QGVAR(isATEngage), false]}
                || {((_g getVariable [QGVAR(cmdLastDecision), ""]) in ["FLANK", "ASSAULT", "SUPPRESS_ASSAULT"]) && {(time - (_g getVariable [QGVAR(cmdSonKararZaman), -999])) < 30}};
            private _aktif = ((_g getVariable [QGVAR(contact), 0]) > time)
                || {_g getVariable [QGVAR(isBounding), false]}
                || {(time - (_g getVariable [QGVAR(cmdSonKararZaman), -999])) < 45};

            if (_gecersiz || {_kendiDuzen} || {!_aktif} || {(count (units _g)) < 3}) then {
                if (_tutuyor) then {
                    private _eski = _g getVariable [QGVAR(syncLeader), objNull];
                    [_g, _eski, "gecersiz/duzen/temas bitti"] call _birak;
                };
                continue;
            };

            // --- olcum: komutanin hareket yonune gore geride kalanlar ---
            private _v = velocity _l;
            _v set [2, 0];
            private _hiz = vectorMagnitude _v;
            private _pL = getPosATL _l;
            private _geri = [];
            private _takim = (units _g) select {
                alive _x && {_x isNotEqualTo _l} && {isNull objectParent _x}
                && {(lifeState _x) in ["HEALTHY", "INJURED"]}
                && {(_x distance2D _l) < 300}
                && {(_x getVariable [QGVAR(stationPos), []]) isEqualTo []}
            };
            if (_takim isEqualTo []) then { continue };

            private _yon = if (_hiz > 0.4) then { _v vectorMultiply (1 / _hiz) } else { [0, 0, 0] };
            private _gerideSayi = 0;
            private _gerideMesafe = [];
            {
                private _fark = (getPosATL _x) vectorDiff _pL;
                private _arka = -((_fark select 0) * (_yon select 0) + (_fark select 1) * (_yon select 1));
                // yon yoksa (komutan duruyor) mesafe kullan
                if (_hiz <= 0.4) then { _arka = _x distance2D _l; };
                if (_arka > 25) then { _gerideSayi = _gerideSayi + 1; _gerideMesafe pushBack _arka; };
            } forEach _takim;
            private _oran = _gerideSayi / (count _takim);
            private _enGeri = if (_gerideMesafe isEqualTo []) then {0} else {selectMax _gerideMesafe};

            // --- birakma kosullari (zaten tutuyorsa) ---
            if (_tutuyor) then {
                private _bitis = (_oran < 0.2)
                    || {(getSuppression _l) > 0.4}
                    || {private _en = _l findNearestEnemy _l; !isNull _en && {(_en distance2D _l) < 40}}
                    || {(_g getVariable [QGVAR(syncHold), false]) && {(time - (_g getVariable [QGVAR(syncBasla), time])) > 20}};
                if (_bitis) then {
                    private _sureDoldu = (_g getVariable [QGVAR(syncHold), false]) && {(time - (_g getVariable [QGVAR(syncBasla), time])) > 20};
                    [_g, _l, format ["oran:%1 enGeri:%2m", _oran toFixed 2, round _enGeri]] call _birak;
                    if (_sureDoldu) then { _g setVariable [QGVAR(syncSoguma), time + 25]; };
                } else {
                    // yavastan beklemeye yukselt
                    if ((_oran >= 0.5) && {_enGeri > 45} && {!(_g getVariable [QGVAR(syncHold), false])} && {time > (_g getVariable [QGVAR(syncSoguma), 0])}) then {
                        _l disableAI "PATH";
                        _g setVariable [QGVAR(syncHold), true];
                        _g setVariable [QGVAR(syncBasla), time];
                        diag_log format ["[KOMUTAN-BEKLE] %1 | BEKLE (PATH kapali) | geride:%2/%3 enGeri:%4m", groupId _g, _gerideSayi, count _takim, round _enGeri];
                    };
                };
                continue;
            };

            // --- tetik ---
            if (_hiz > 0.8 && {_oran >= 0.4} && {time > (_g getVariable [QGVAR(syncSoguma), 0])}) then {
                _g setVariable [QGVAR(syncLeader), _l];
                if ((_oran >= 0.5) && {_enGeri > 45}) then {
                    _l disableAI "PATH";
                    _g setVariable [QGVAR(syncHold), true];
                    _g setVariable [QGVAR(syncBasla), time];
                    diag_log format ["[KOMUTAN-BEKLE] %1 | BEKLE (PATH kapali) | geride:%2/%3 enGeri:%4m", groupId _g, _gerideSayi, count _takim, round _enGeri];
                } else {
                    _l forceSpeed 1.8;
                    _g setVariable [QGVAR(syncSlow), true];
                    diag_log format ["[KOMUTAN-BEKLE] %1 | YAVASLA | geride:%2/%3 enGeri:%4m", groupId _g, _gerideSayi, count _takim, round _enGeri];
                };
            };
        } forEach allGroups;
    };
};

true
