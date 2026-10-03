#include "script_component.hpp"
/*
 * Author: Cinar (ELITE fork)
 * TEHDIT YONUNE BAKIS (v8.47) — askerler bos duvara / rastgele yone degil, olasi tehdit yonune bakar.
 *
 * Doktrin (MCWP 3-11.2 Ch.3): bireysel gozlem sektorleri ortusur; ileri / sol kanat / sag kanat + arkada bir kisi (cevre gorusu).
 * Tehdit yonu (oncelik): komutan durum raporundaki son dusman konumu (<= 300 sn) -> grubun son dusman bilgisi -> hareket yonu (liderin bakisi).
 * Asker basina sektor: 0 = tehdit yonu, 1 = -50, 2 = +50, 3 = -100, 4 = +100; grubun SON askeri arka gozcu (+180, sadece tehdit yonu bilinmiyorsa).
 * Bos duvar kontrolu: bakis yonunda 8 m icinde engel varsa +-30 / +-60 / +-90 derece kayar; hepsi kapaliysa o askere dokunulmaz.
 * ATLANIR: oyuncu, arac, temas (catisma kendi hedefini secer), retreat / evade / breakContact / bounding / peel / sniper, forceMove, taktikKilit,
 *   disableAI, baski > 0, yaralilar (yatan: bakis serbest degil). Kapatma: lambs_danger_tehditBakisOff = true.
 *
 * Arguments:
 * None
 *
 * Return Value:
 * Baslatildi mi <BOOL>
 *
 * Public: No
*/

if (!isNil "lambs_danger_tehditBakisStarted") exitWith {false};
lambs_danger_tehditBakisStarted = true;

diag_log "[TEHDIT-BAKIS] tehdit yonu gozlem watchdog baslatildi";

[] spawn {
    private _logN = 0;
    while {true} do {
        sleep 6;
        if (missionNamespace getVariable ["lambs_danger_tehditBakisOff", false]) then { continue };
        {
            private _g = _x;
            private _l = leader _g;
            if (isNull _l || {isPlayer _l} || {!local _l}) then { continue };
            private _us = (units _g) select {alive _x && {isNull objectParent _x} && {!isPlayer _x}};
            if ((count _us) < 2) then { continue };
            if ((_g getVariable [QGVAR(contact), 0]) > time) then { continue };
            if (
                (_g getVariable [QGVAR(isRetreating), false]) || {_g getVariable [QGVAR(isPeeling), false]}
                || {_g getVariable [QGVAR(isEvading), false]} || {_g getVariable [QGVAR(isBreakingContact), false]}
                || {_g getVariable [QGVAR(isBounding), false]} || {_g getVariable [QGVAR(sniperTeam), false]}
            ) then { continue };

            // tehdit yonu
            private _yon = -1;
            private _kaynak = "hareket";
            private _sit = _g getVariable [QGVAR(cmdSit), []];
            if (_sit isNotEqualTo [] && {(time - (_sit select 0)) < 300} && {(_sit select 7) isEqualType []} && {(_sit select 7) isNotEqualTo [0,0,0]}) then {
                _yon = _l getDir (_sit select 7);
                _kaynak = "son dusman";
            } else {
                _yon = getDir _l;
            };
            private _bilinen = _kaynak isEqualTo "son dusman";

            private _sektorler = [0, -50, 50, -100, 100];
            {
                private _u = _x;
                private _i = _forEachIndex;
                if (
                    (_u getVariable [QGVAR(forceMove), false]) || {!isNil {_u getVariable QGVAR(taktikKilit)}} || {_u getVariable [QGVAR(disableAI), false]}
                    || {(getSuppression _u) > 0} || {(lifeState _u) isEqualTo "INCAPACITATED"} || {(_u getVariable ["ACE_isUnconscious", false])}
                    || {(time - (_u getVariable [QGVAR(tbSon), -999])) < 8}
                ) then { continue };

                private _ofs = if (!_bilinen && {_i == (count _us) - 1} && {(count _us) >= 3}) then {180} else {_sektorler select (_i mod 5)};
                private _eye = eyePos _u;
                private _secildi = -1;
                {
                    private _b = _yon + _ofs + _x;
                    private _p = _eye vectorAdd [(sin _b) * 8, (cos _b) * 8, 0];
                    if (!(lineIntersects [_eye, _p, _u, objNull]) && {!(terrainIntersectASL [_eye, _p])}) exitWith { _secildi = _b; };
                } forEach [0, 30, -30, 60, -60, 90, -90];
                if (_secildi < 0) then { continue };
                _u setVariable [QGVAR(tbSon), time];
                _u doWatch (_eye getPos [150, _secildi]);
            } forEach _us;
        } forEach (allGroups select {local _x && {!isNull leader _x}});
    };
};

true
