#include "script_component.hpp"
/*
 * Author: Cinar (ELITE fork)
 * SIPERDEN KALK-NISAN-ALCAL (v8.660; kullanici: 'cover ve piyade manevralari icin 10 uzerinden 10'; egitimli askerin siperden ates etme yontemi: peek / pop-up):
 * Alcak duruslu (yatma / comelme) siperdeki asker dusmani GOREMIYORSA (siper nesnesi goz hattini kesiyor) ama bir kademe kalkinca (goz +0.5 m) hat ACILIYORSA:
 *   kisa sureligine (1.4-2.0 sn) bir kademe kalkar, dusmana doWatch + doTarget + doFire (ates), sonra eski duruşa ALCALIR; 4-8 sn bekler.
 *   Kosullar: temasli grup (30 sn), yerel AI, durmus (< 1.5 m/sn), bina disi, yakin zamanda sipere yapismis (hugAt 25 sn / acikSiperHedef 40 sn), bilinen dusman 40-350 m (>= SUPHE), baski < 0.6, mermi var, sarjor degistirmiyor,
 *   oyuncu / oyuncu komutasi / bayginlik / teslim / forceMove / taktikKilit / kose temkini / pusu atlanir. Ayni anda en cok 6 asker (tur basina); siperMikro ile uyumlu (o kalici kalkis, bu gecici).
 * CBA: lambs_danger_siperPeek (varsayilan ACIK). Log: [SIPER-PEEK] (ilk 15) + [SIPER-PEEK-OZET] 60 sn.
 *
 * Arguments: None
 * Return Value: Baslatildi mi <BOOL>
 * Public: No
*/

if (!isNil "lambs_danger_siperPeekStarted") exitWith {false};
lambs_danger_siperPeekStarted = true;

diag_log "[SIPER-PEEK] siperden kalk-nisan-alcal (peek) katmani baslatildi (v8.660)";

[] spawn {
    private _logN = 0;
    private _say = createHashMapFromArray [["kontrol", 0], ["peek", 0], ["gorus_acik", 0], ["kilit", 0]];
    private _ozetT = time + 60;
    while {true} do {
        sleep ([1.2, true, true, "siperPeek"] call FUNC(dusunSure));
        if !(missionNamespace getVariable ["lambs_danger_siperPeek", true]) then { continue };
        private _esik = ["SUPHE"] call FUNC(bilgiEsik);
        private _n = 0;
        {
            private _u = _x;
            if (_n >= 6) exitWith {};
            if (
                !local _u || {isPlayer _u} || {!alive _u} || {!isNull objectParent _u} || {!((lifeState _u) in ["HEALTHY", "INJURED"])}
                || {captive _u} || {_u getVariable [QGVAR(teslim), false]} || {(speed _u) > 1.5} || {(insideBuilding _u) > 0.5}
                || {time < (_u getVariable [QGVAR(peekNext), 0])}
                || {([(group _u)] call FUNC(temasSeviye)) > 1}
                || {_u getVariable [QGVAR(forceMove), false]} || {(_u getVariable [QGVAR(taktikKilit), 0]) > time} || {!isNil {_u getVariable QGVAR(koseAktif)}}
                || {(_u getVariable [QGVAR(reloadState), []]) isNotEqualTo []}
                || {([_u] call FUNC(baskiSeviye)) >= 4}
                || {(primaryWeapon _u) isEqualTo ""} || {(_u ammo (primaryWeapon _u)) < 3}
                || {((time - (_u getVariable [QGVAR(hugAt), -999])) > 25) && {(time - ((_u getVariable [QGVAR(acikSiperHedef), [0, -999]]) param [1, -999])) > 40}}
                || {[_u] call FUNC(oyuncuKomutaMi)}
            ) then { continue };
            private _st = stance _u;
            if !(_st in ["PRONE", "CROUCH"]) then { continue };
            private _e = _u findNearestEnemy _u;
            if (isNull _e || {!alive _e} || {!(_e isKindOf "CAManBase")} || {(_u distance _e) < 40} || {(_u distance _e) > 350} || {(_u knowsAbout _e) < _esik}) then { continue };
            _n = _n + 1;
            _say set ["kontrol", (_say get "kontrol") + 1];
            private _eye = eyePos _u;
            private _tgt = aimPos _e;
            private _ht = lineIntersectsSurfaces [_eye, _tgt, _u, _e, true, 1, "VIEW", "NONE"];
            // zaten goruyor: kalkmaya gerek yok (motor ates eder)
            if (_ht isEqualTo [] || {((_ht select 0) select 0) distance _eye > 3.5}) then { _say set ["gorus_acik", (_say get "gorus_acik") + 1]; _u setVariable [QGVAR(peekNext), time + 2]; continue };
            // kalkinca hat aciliyor mu (+0.5 m goz)
            if ((lineIntersectsSurfaces [_eye vectorAdd [0, 0, 0.5], _tgt, _u, _e, true, 1, "VIEW", "NONE"]) isNotEqualTo []) then { _u setVariable [QGVAR(peekNext), time + 3]; _say set ["kilit", (_say get "kilit") + 1]; continue };
            private _yeni = ["MIDDLE", "UP"] select (_st isEqualTo "CROUCH");
            private _eski = ["DOWN", "MIDDLE"] select (_st isEqualTo "CROUCH");
            _u setUnitPosWeak _yeni;
            _u doWatch _e;
            _u doTarget _e;
            _u doFire _e;
            _u setVariable [QGVAR(peekNext), time + 4 + (random 4)];
            _say set ["peek", (_say get "peek") + 1];
            if (_logN < 15) then { _logN = _logN + 1; diag_log format ["[SIPER-PEEK] %1 | %2 | dusman %3 m | %4 -> %5 (1.4-2.0 sn), sonra %6", groupId (group _u), name _u, round (_u distance _e), _st, _yeni, _eski]; };
            [{ params ["_a", "_ds"]; if (alive _a && {(lifeState _a) in ["HEALTHY", "INJURED"]}) then { _a setUnitPosWeak _ds; }; }, [_u, _eski], 1.4 + (random 0.6)] call CBA_fnc_waitAndExecute;
        } forEach allUnits;
        if (time > _ozetT) then {
            _ozetT = time + 60;
            if ((_say get "kontrol") > 0) then {
                diag_log format ["[SIPER-PEEK-OZET] 60 sn: kontrol %1 | peek (kalk-ates-alcal) %2 | zaten goruyor %3 | kalkinca da kapali %4", _say get "kontrol", _say get "peek", _say get "gorus_acik", _say get "kilit"];
            };
            { _say set [_x, 0]; } forEach ["kontrol", "peek", "gorus_acik", "kilit"];
        };
    };
};
true
