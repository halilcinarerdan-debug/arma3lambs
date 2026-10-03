#include "script_component.hpp"
/*
 * Author: Cinar (ELITE fork)
 * IED FARKINDALIGI (v8.47)
 *
 * Doktrin (MCWP 3-11.1 "IED or possible IED" drill): durma, bolgeyi tarama, supheli noktayi gozetleme, dagilma; molalarda IED taramasi.
 * Sayisal degerler yoktur (TASARIM):
 *   - TESPIT: lider grubun askerlerinden birinin <= 25 m'sinde (mayin dedektoru / explosiveSpecialist <= 40 m) ve gorus hatti acik supheli nesne
 *     (allMines + sinif adinda "ied" gecen nesneler, mod IED'leri dahil) -> taraf icin revealMine (AI yol planlamasi bunu otomatik atlar).
 *   - TEPKI: 50 m yaricapta askerler IED'den uzaklasir (55 m'ye), yatarak degil ortu / dagilma; grup 60 sn LIMITED hizda, AWARE.
 *   - IMHA: grupta explosiveSpecialist varsa ve temas YOKSA, vanilla mayinda (MineBase) 3 m'ye gidip "Deactivate" dener (45 sn zaman asimi).
 *     Uzaktan tetikli / mod IED'lerinde imha denenmez, yalnizca kacinilir.
 *   - Cooldown: ayni IED icin grup basina 5 dk. ATLANIR: oyuncu lider, arac, retreat / evade / breakContact.
 * Kapatma: lambs_danger_iedOff = true.
 *
 * Arguments:
 * None
 *
 * Return Value:
 * Baslatildi mi <BOOL>
 *
 * Public: No
*/

if (!isNil "lambs_danger_iedFarkStarted") exitWith {false};
lambs_danger_iedFarkStarted = true;

diag_log "[IED-FARK] IED farkindaligi watchdog baslatildi";

[] spawn {
    private _logN = 0;
    while {true} do {
        sleep 4;
        if (missionNamespace getVariable ["lambs_danger_iedOff", false]) then { continue };
        {
            private _g = _x;
            private _l = leader _g;
            if (isNull _l || {isPlayer _l} || {!local _l} || {!alive _l} || {!isNull objectParent _l}) then { continue };
            if (
                (_g getVariable [QGVAR(isRetreating), false]) || {_g getVariable [QGVAR(isEvading), false]} || {_g getVariable [QGVAR(isBreakingContact), false]}
            ) then { continue };
            private _lp = getPosATL _l;
            private _adaylar = (allMines select {(_x distance2D _lp) < 90}) + ((_lp nearObjects 90) select {(toLower (typeOf _x)) find "ied" >= 0 && {!(_x in allMines)}});
            if (_adaylar isEqualTo []) then { continue };
            private _bilinen = _g getVariable [QGVAR(iedBilinen), []];
            private _us = (units _g) select {alive _x && {isNull objectParent _x}};
            {
                private _m = _x;
                private _mp = getPosATL _m;
                if ((_bilinen findIf {(_x select 0) distance2D _mp < 3 && {(time - (_x select 1)) < 300}}) >= 0) then { continue };
                private _tespit = objNull;
                {
                    private _u = _x;
                    private _menzil = [25, 40] select ((_u getUnitTrait "explosiveSpecialist") || {"MineDetector" in (items _u)});
                    if ((_u distance2D _m) <= _menzil) then {
                        private _e = eyePos _u;
                        private _t = (getPosASL _m) vectorAdd [0, 0, 0.2];
                        if (!(lineIntersects [_e, _t, _u, _m]) && {!(terrainIntersectASL [_e, _t])}) exitWith { _tespit = _u; };
                    };
                } forEach _us;
                if (isNull _tespit) then { continue };

                _bilinen pushBack [_mp, time];
                _g setVariable [QGVAR(iedBilinen), _bilinen];
                (side _g) revealMine _m;

                // uzaklasma (50 m yaricap -> 55 m)
                private _uzaklasan = 0;
                {
                    if ((_x distance2D _m) < 50 && {isNil {_x getVariable QGVAR(taktikKilit)}}) then {
                        private _yon = _mp getDir _x;
                        _x doMove (_mp getPos [55 + (random 8), _yon + (random 40) - 20]);
                        _uzaklasan = _uzaklasan + 1;
                    };
                } forEach _us;
                _g setBehaviour "AWARE";
                _g setSpeedMode "LIMITED";
                [{ params ["_gg"]; if (!isNull _gg && {!(_gg getVariable [QGVAR(isExecutingTactic), false])}) then { _gg setSpeedMode "NORMAL"; }; }, [_g], 60] call CBA_fnc_waitAndExecute;

                // imha (yalniz vanilla mayin, temas yok)
                private _eod = _us findIf {_x getUnitTrait "explosiveSpecialist"};
                private _imha = "yok";
                if (_eod >= 0 && {(_g getVariable [QGVAR(contact), 0]) <= time} && {_m isKindOf "MineBase"}) then {
                    _imha = "deneniyor";
                    [_us select _eod, _m, _g] spawn {
                        params ["_u", "_mine", "_grp"];
                        private _t0 = time;
                        waitUntil {
                            sleep 1;
                            _u doMove (getPosATL _mine);
                            isNull _mine || {!alive _u} || {(_u distance2D _mine) < 3} || {(time - _t0) > 45} || {(_grp getVariable [QGVAR(contact), 0]) > time}
                        };
                        if (!isNull _mine && {alive _u} && {(_u distance2D _mine) < 3.5}) then {
                            _u action ["Deactivate", _u, _mine];
                            diag_log format ["[IED-FARK] %1 | imha denendi (%2)", name _u, typeOf _mine];
                        };
                    };
                };
                if (_logN < 100) then {
                    _logN = _logN + 1;
                    diag_log format ["[IED-FARK] %1 | %2 | %3 m | tespit:%4 | uzaklasan:%5 | imha:%6", groupId _g, typeOf _m, round (_lp distance2D _m), name _tespit, _uzaklasan, _imha];
                };
            } forEach _adaylar;
        } forEach (allGroups select {local _x && {!isNull leader _x}});
    };
};

true
