#include "script_component.hpp"
/*
 * Author: Cinar (ELITE fork)
 * ATES HATTI KONTROLU — dost unsur ates hattindaysa aci degistir, capraz atesta kalma.
 *
 * Yerel AI piyadeler icin 0.5 sn'de bir: hedefi olan (assignedTarget, yoksa 300 m'deki en yakin dusman) asker ile
 * hedef arasindaki 2B dogruya 1.6 m'den yakin, atici ile hedef arasinda (2 m .. mesafe-2 m) duran DOST varsa:
 *
 *   - Hareket eden = atici (MG / nisanci ise ENGELLEYEN dost; engelleyen kosuda ise atici).
 *   - Hareket eden, hatti ARTIK kesmeyen (yeni hatta dost yok) bos / engelsiz bir noktaya 4.5 m (olmazsa 7 m)
 *     hatta DIK yone adim atar; yolda ates kesilir (TARGET / AUTOTARGET kapali), 2.5 sn sonra geri acilir.
 *   - 4 sn bekleme suresi (titreme yok); forceMove'lu (baska taktigin kosucusu), el bombasi tepkisindeki,
 *     arac ve oyuncu atlanir.
 *
 * Arguments:
 * None
 *
 * Return Value:
 * Baslatildi mi <BOOL>
 *
 * Public: No
*/

if (!isNil "lambs_danger_fireLineStarted") exitWith {false};
lambs_danger_fireLineStarted = true;
lambs_danger_flLogN = 0;

diag_log "[ATES-HATTI] ates hatti kontrolu baslatildi (dost hatta ise aci degistir)";

[] spawn {
    private _rolFn = missionNamespace getVariable ["lambs_danger_fnc_getUnitRole", {"RIFLE"}];

    // Hat uzerinde dost var mi? [atici pozisyon, hedef pozisyon, atici, yoksayilan]
    private _hatDost = {
        params ["_a", "_t", "_shooter"];
        private _d = _a distance2D _t;
        private _dir = _a getDir _t;
        private _res = objNull;
        {
            if (!isNull _res) exitWith {};
            if (
                (_x isNotEqualTo _shooter) && {alive _x}
                && {((side group _shooter) getFriend (side group _x)) >= 0.6}
            ) then {
                private _ad = _a distance2D _x;
                if (_ad > 2 && {_ad < (_d - 2)}) then {
                    private _ang = ((_a getDir _x) - _dir + 540) mod 360 - 180;
                    if ((abs (_ad * sin _ang)) < 1.6 && {abs _ang < 40}) then { _res = _x; };
                };
            };
        } forEach (_a nearEntities ["CAManBase", ((_d - 2) min 200) max 3]);
        _res
    };

    while {true} do {
        sleep 0.5;

        // geri acma: adim bitti
        {
            if (alive _x && {time > (_x getVariable [QGVAR(flUntil), 0])} && {(_x getVariable [QGVAR(flUntil), 0]) > 0}) then {
                _x setVariable [QGVAR(flUntil), 0];
                _x enableAI "TARGET";
                _x enableAI "AUTOTARGET";
            };
        } forEach (allUnits select {local _x && {(_x getVariable [QGVAR(flUntil), 0]) > 0}});

        {
            private _u = _x;
            // VARSAYILAN KAPALI: RPT'de 13 kisilik grubun hemen herkesi temasta surekli yan adim atiyordu (formasyon / taktik felci). Motor zaten
            // dost atesinden kacinir. Acmak icin: lambs_danger_fireLineOn = true
            if (!(missionNamespace getVariable ["lambs_danger_fireLineOn", false])) then { continue };
            if (time < (_u getVariable [QGVAR(flLast), 0])) then { continue };
            if (_u getVariable [QGVAR(forceMove), false]) then { continue };
            if ((_u getVariable [QGVAR(grState), []]) isNotEqualTo []) then { continue };
            if (((group _u) getVariable [QGVAR(contact), 0]) < time) then { continue };
            // FELC ONLEME: taktik (bounding / cekilme / temas kesme / herhangi taktik), komutan, baskida olan veya hareket halindeki asker
            // yan adim ATMAZ (yan adim asil emri eziyor, takimi durduruyordu)
            private _fg = group _u;
            if (
                (_fg getVariable [QGVAR(isBounding), false]) || {_fg getVariable [QGVAR(isExecutingTactic), false]}
                || {_fg getVariable [QGVAR(isRetreating), false]} || {_fg getVariable [QGVAR(isBreakingContact), false]}
                || {_u isEqualTo (leader _u)} || {(getSuppression _u) >= 0.25} || {(speed _u) > 2}
            ) then { continue };

            private _t = assignedTarget _u;
            if (isNull _t || {!alive _t}) then {
                _t = _u findNearestEnemy _u;
                if (isNull _t || {(_u distance2D _t) > 300}) then { continue };
            };
            if ((_u distance2D _t) < 8) then { continue };

            private _aPos = getPosATL _u;
            private _tPos = getPosATL _t;
            private _blk = [_aPos, _tPos, _u] call _hatDost;
            if (isNull _blk) then { continue };

            // kim hareket eder?
            private _mover = _u;
            private _rol = [_u] call _rolFn;
            if (
                (_rol in ["MG", "MARKSMAN"]) && {isNull objectParent _blk} && {isNull (_blk getVariable [QGVAR(flBlk), objNull])}
                && {!(_blk getVariable [QGVAR(forceMove), false])} && {local _blk} && {!isPlayer _blk}
            ) then { _mover = _blk; };

            private _mPos = getPosATL _mover;
            private _dir = _aPos getDir _tPos;
            private _secildi = [];
            {
                private _off = _x;
                {
                    if (_secildi isNotEqualTo []) exitWith {};
                    private _c = _mPos getPos [_off, _dir + _x];
                    if (
                        !surfaceIsWater _c
                        && {((_c nearEntities ["CAManBase", 1.3]) select {(_x isNotEqualTo _mover)}) isEqualTo []}
                        && {!(lineIntersects [AGLToASL (_mPos vectorAdd [0, 0, 0.9]), AGLToASL (_c vectorAdd [0, 0, 0.9]), _mover])}
                        && {(nearestTerrainObjects [_c, ["TREE", "WALL", "FENCE", "BUILDING", "HOUSE", "ROCK"], 0.9, false, true]) isEqualTo []}
                    ) then {
                        // hareket eden atici ise yeni hatta dost kalmamali; engelleyen ise artik atici hattinda olmamali
                        private _temiz = if (_mover isEqualTo _u) then {
                            isNull ([_c, _tPos, _u] call _hatDost)
                        } else {
                            isNull ([_aPos, _tPos, _u] call _hatDost) || {true}
                        };
                        if (_temiz) then { _secildi = _c; };
                    };
                } forEach (selectRandom [[90, -90], [-90, 90]]);
                if (_secildi isNotEqualTo []) exitWith {};
            } forEach [4.5, 7];

            if (_secildi isNotEqualTo []) then {
                _u setVariable [QGVAR(flLast), time + 20];
                _mover setVariable [QGVAR(flLast), time + 20];
                _mover setVariable [QGVAR(flUntil), time + 2.5];
                _mover doMove _secildi;
                if (lambs_danger_flLogN < 30) then {
                    lambs_danger_flLogN = lambs_danger_flLogN + 1;
                    diag_log format [
                        "[ATES-HATTI] %1 | %2 -> hedef %3 m | hatta dost: %4 | hareket eden: %5 (%6 m yana)",
                        groupId (group _u), name _u, round (_aPos distance2D _tPos), name _blk, name _mover, round (_mPos distance2D _secildi)
                    ];
                };
            } else {
                _u setVariable [QGVAR(flLast), time + 8];
            };
        } forEach (allUnits select {
            local _x && {alive _x} && {!isPlayer _x} && {isNull objectParent _x} && {(lifeState _x) in ["HEALTHY", "INJURED"]}
        });
    };
};

true
