#include "script_component.hpp"
/*
 * Author: Cinar (ELITE fork)
 * MEVZI KILIDI (v8.256) — kullanici (RPT e31bd8bd): "dusman gordugunde hendekten ayrildilar; karsilik veremeyeceklerse ayrilmasinlar; mevzilerden yuzlerce metre otedeki tanka karsi cikmaya calistilar".
 * Hendekteki piyadeyi hendekten cikaran KAYNAK birden cok (RPT: aracUzak 'dost arac (temas)' 29-37 m, fnc_contact lider siper arama, LAMBS tacticsAssess 'Hide (holding)' / 'Group Suppress (Move)', AT 'zirha karsi cik' hareketi);
 * her kaynak ayri kapatildi (aracUzak / contact / tactics) AMA kaynak ne olursa olsun son emniyet: bu bekci hendek grubundaki askeri alanin disina >= 6 m VE atanan noktasindan > 12 m uzaksa noktasina geri gonderir.
 * Kural (2 sn, yerel; grup hendekte + fnc_mevziDeMi; yerlesimden >= 100 sn sonra; kayip <= %60 degil [fnc_tactics ile ayni esik]; geri cekilme / temas kesme / evade bayragi yok):
 *   asker yayada, saglikli, TCCC / statik gorev / forceMove yok, atanan noktasi (hendekNokta) var -> alan dikdortgenine mesafe > 6 m ve noktaya > 12 m ise doMove noktaya (8 sn'de bir), noktaya <= 3 m'de doStop + comelme.
 * Plan sonu / karsi saldiri / kayip esigi (_kayipCekil) 'hendekte' bayragini siler -> bekci kapanir (serbest). Log: [MEVZI-KILIT] (ilk 60) + 60 sn ozeti. Kapatma: lambs_danger_mevziKilitOff = true.
 *
 * Arguments: None
 * Return Value: Baslatildi mi <BOOL>
 * Public: No
*/

if (!isNil "lambs_danger_mevziKilitStarted") exitWith {false};
lambs_danger_mevziKilitStarted = true;

diag_log "[MEVZI-KILIT] hendek bekcisi baslatildi (v8.256): hendek grubundaki asker alan disina > 6 m ve noktasindan > 12 m ciktiysa geri gonderilir";

private _calis = {
    private _logN = 0;
    private _say = createHashMap;
    private _ozetT = time + 60;
    while {true} do {
        sleep 2;
        if (!(missionNamespace getVariable ["lambs_danger_mevziKilitOff", false])) then {
            {
                private _g = _x;
                if (!local _g || {!(_g getVariable [QGVAR(hendekte), false])}) then { continue };
                if (!([_g] call FUNC(mevziDeMi))) then { continue };
                if ((_g getVariable [QGVAR(isRetreating), false]) || {_g getVariable [QGVAR(isBreakingContact), false]} || {_g getVariable [QGVAR(isEvading), false]}) then { continue };
                private _ilkM = _g getVariable [QGVAR(mevziIlk), 0];
                private _canM = {alive _x} count (units _g);
                if (_ilkM > 0 && {_canM <= (_ilkM * 0.4)}) then { continue };
                {
                    private _u = _x;
                    if (!alive _u || {isPlayer _u} || {!isNull objectParent _u}) then { continue };
                    private _np = _u getVariable [QGVAR(hendekNokta), []];
                    if (_np isEqualTo []) then { continue };
                    if (!((lifeState _u) in ["HEALTHY", "INJURED"]) || {_u getVariable ["ACE_isUnconscious", false]}) then { continue };
                    if (time < (_u getVariable [QGVAR(tcccBusy), 0]) || {_u getVariable [QGVAR(mevziStatikGorev), false]} || {_u getVariable [QGVAR(forceMove), false]}) then { continue };
                    if ((time - (_u getVariable [QGVAR(hendekYerlesT), -999])) < 100) then { continue };
                    private _pt = _np select 0;
                    private _dPt = _u distance2D _pt;
                    if (_dPt <= 3) then {
                        if ((currentCommand _u) isNotEqualTo "STOP" && {(time - (_u getVariable [QGVAR(mevziKilitDurT), -999])) > 10}) then {
                            _u setVariable [QGVAR(mevziKilitDurT), time];
                            doStop _u;
                            _u setUnitPos "MIDDLE";
                        };
                        continue
                    };
                    if (time < (_u getVariable [QGVAR(mevziKilitT), 0])) then { continue };
                    private _dAl = ["ICERDE", _np select 1, 0, sideUnknown, getPosATL _u] call FUNC(hendekAlani);
                    if (_dAl > 6 && {_dPt > 12}) then {
                        _u setVariable [QGVAR(mevziKilitT), time + 8];
                        _u enableAI "PATH"; _u enableAI "MOVE";
                        _u doMove _pt;
                        _say set [groupId _g, (_say getOrDefault [groupId _g, 0]) + 1];
                        if (_logN < 60) then {
                            _logN = _logN + 1;
                            diag_log format ["[MEVZI-KILIT] %1 | %2 | rol=%3 | alan_disi=%4 m | noktaya=%5 m | komut=%6 | -> noktasina geri | dusman=%7 m", groupId _g, name _u, [_u] call (missionNamespace getVariable ["lambs_danger_fnc_getUnitRole", {"?"}]), round _dAl, round _dPt, currentCommand _u,
                                if (isNull (_u findNearestEnemy _u)) then {"-"} else {round (_u distance2D (_u findNearestEnemy _u))}];
                        };
                    };
                } forEach (units _g);
            } forEach allGroups;
        };
        if (time > _ozetT) then {
            _ozetT = time + 60;
            if (count _say > 0) then {
                diag_log format ["[MEVZI-KILIT-OZET] son 60 sn geri cagrilan (grup: sayi): %1", _say toArray false];
                _say = createHashMap;
            };
        };
    };
};

[_calis] spawn {
    params ["_fn"];
    while {true} do {
        private _h = [] spawn _fn;
        waitUntil { sleep 5; scriptDone _h };
        diag_log "[WATCHDOG-YENIDEN] mevziKilit betigi sonlandi (hata?)";
        sleep 5;
    };
};

true
