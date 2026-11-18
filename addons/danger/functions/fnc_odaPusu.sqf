#include "script_component.hpp"
/*
 * Author: Cinar (ELITE fork)
 * ODA PUSUSU (v8.598; kullanici: 'odalari arastirip onlarda pusabilsinler'): fnc_buildingClearRun bir binayi temizledikten sonra giris takimindan en cok 2 asker (lider / saglikci haric) binanin
 * EN DERIN (giristen en uzak, ayni kat) oda noktalarinda KALIR: yerine gider, comelir (MIDDLE), girise doWatch ile bakar, pusu suresi (CBA lambs_danger_binaPusu, varsayilan 90 sn) boyunca bekler.
 * Erken birakma (savas): bilinen dusman 25 m icinde (knowsAbout >= SUPHE) / baski > 0.7 / geri cekilme / olum - sonra gruba doner (doFollow). Sure bitince de gruba doner.
 * UYUM: LAMBS Garrison / CQB gorevi ya da kal-bekle waypoint'li gruplarda pusu atamasi yapilmaz (buildingClearRun senaryoKapi kontrolu). taktikKilit pusu suresince diger izleyicileri uzak tutar.
 * Log: [ODA-PUSU] (ilk 20).
 *
 * Arguments: None
 * Return Value: Baslatildi mi <BOOL>
 * Public: No
*/

if (!isNil "lambs_danger_odaPusuStarted") exitWith {false};
lambs_danger_odaPusuStarted = true;

diag_log "[ODA-PUSU] oda pususu (temizlenen binanin derin odasinda bekle) izleyicisi baslatildi (v8.598)";

[] spawn {
    private _logN = 0;
    while {true} do {
        sleep ([2, false, true] call FUNC(dusunSure));
        {
            private _u = _x;
            private _bit = _u getVariable [QGVAR(odaPusuBit), 0];
            private _g = group _u;
            private _poz = _u getVariable [QGVAR(odaPusuPoz), []];
            private _sebep = "";
            if (!alive _u || {!((lifeState _u) in ["HEALTHY", "INJURED"])}) then { _sebep = "asker dustu"; } else {
                if (time > _bit) then { _sebep = "sure doldu"; } else {
                    if (_poz isEqualTo [] || {_g getVariable [QGVAR(isRetreating), false]} || {_g getVariable [QGVAR(isEvading), false]}) then { _sebep = "grup cekiliyor"; } else {
                        if ((getSuppression _u) > 0.7) then { _sebep = "baski"; } else {
                            private _en = _u findNearestEnemy _u;
                            if (!isNull _en && {alive _en} && {(_u distance _en) < 25} && {(_u knowsAbout _en) >= (["SUPHE"] call FUNC(bilgiEsik))}) then { _sebep = "dusman yakin (pusu tetigi)"; };
                        };
                    };
                };
            };
            if (_sebep isNotEqualTo "") then {
                _u setVariable [QGVAR(odaPusuBit), nil];
                _u setVariable [QGVAR(odaPusuPoz), nil];
                _u setVariable [QGVAR(odaPusuKapi), nil];
                _u setVariable [QGVAR(taktikKilit), nil];
                if (alive _u) then {
                    _u setUnitPos "AUTO";
                    _u doWatch objNull;
                    if (_sebep isNotEqualTo "dusman yakin (pusu tetigi)" && {!isNull (leader _g)} && {_u isNotEqualTo (leader _g)}) then { _u doFollow (leader _g); };
                };
                if (_logN < 20) then { _logN = _logN + 1; diag_log format ["[ODA-PUSU] %1 | %2 | pususu bitti: %3", groupId _g, name _u, _sebep]; };
                continue
            };
            if ((_u distance _poz) > 2.5) then {
                if (time > (_u getVariable [QGVAR(odaPusuMoveT), 0])) then {
                    _u setVariable [QGVAR(odaPusuMoveT), time + 5];
                    _u setUnitPos "UP";
                    _u doMove _poz;
                };
            } else {
                _u setUnitPos "MIDDLE";
                private _kp = _u getVariable [QGVAR(odaPusuKapi), []];
                if (_kp isNotEqualTo []) then { _u doWatch _kp; };
            };
        } forEach (allUnits select {local _x && {(_x getVariable [QGVAR(odaPusuBit), 0]) > 0}});
    };
};

true
