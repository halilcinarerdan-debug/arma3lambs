#include "script_component.hpp"
/*
 * Author: Cinar (ELITE fork)
 * SURUCU YENILEME (v8.244) — RPT c7592408: planZirh BTR-80'lerinin suruculeri oldu (Babenko DEAD) ve arac 'motor true canMove true' halde bos durdu ('bir apc oylece bekledi').
 * Her makinede 3 sn'de bir, YEREL kara araclarinda: son suruculu halinde kaydedilen surucu OLDUYSA ve surucu koltugu bos kaldiysa, araçtaki yasayan AI YOLCULARDAN (rol 'cargo';
 * oyuncu, baygin, FFV degil) biri surucu koltuguna gecer (moveInDriver + assignAsDriver). Mürettebat koltuklari (nisanci / komutan) yerinden oynatilmaz: tankta yedek surucu YOKTUR
 * (kargosuz arac = hareket kaybi sayilir, nisanci yerinde ates eder). Koşullar: arac hareket edebilir (canMove), yakit var, yanmiyor, hasar < 0.9, araçta oyuncu yok. Arac basina 15 sn'de bir.
 * Doktrin notu: ATP 3-20.15 yalniz 'komuta devri'ni provaya sokar (4-61); surucu yedegi TASARIM mantigidir (kitapta sayi / kural YOK).
 * Kapatma: lambs_danger_surucuYenileOff = true.  Log: [SURUCU-YENILE].
 *
 * Arguments: None
 * Return Value: Baslatildi mi <BOOL>
 * Public: No
*/

if (!isNil "lambs_danger_surucuYenileStarted") exitWith {false};
lambs_danger_surucuYenileStarted = true;

diag_log "[SURUCU-YENILE] surucu yenileme watchdog'u baslatildi (v8.244): surucu olunca yasayan AI yolcu surucu koltuguna gecer";

private _calis = {
    while {true} do {
        sleep 3;
        if (missionNamespace getVariable ["lambs_danger_surucuYenileOff", false]) then { continue };
        {
            private _v = _x;
            if (!local _v || {!alive _v} || {!(_v isKindOf "LandVehicle")}) then { continue };
            private _d = driver _v;
            if (!isNull _d && {alive _d}) then {
                _v setVariable [QGVAR(sonSurucu), _d];
                continue
            };
            private _son = _v getVariable [QGVAR(sonSurucu), objNull];
            if (isNull _son || {alive _son}) then { continue };
            if ((time - (_v getVariable [QGVAR(surucuYenileT), -999])) < 15) then { continue };
            if ((_v emptyPositions "driver") < 1) then { continue };
            if (!canMove _v || {(fuel _v) <= 0.01} || {isBurning _v} || {(damage _v) >= 0.9} || {(crew _v) findIf {isPlayer _x} >= 0}) then { continue };
            private _aday = (fullCrew [_v, "cargo", false]) select {
                private _u = _x select 0;
                alive _u && {local _u} && {!isPlayer _u} && {(lifeState _u) in ["HEALTHY", "INJURED"]} && {!(_u getVariable ["ACE_isUnconscious", false])}
            };
            _v setVariable [QGVAR(surucuYenileT), time];
            if (_aday isEqualTo []) then {
                if !(_v getVariable [QGVAR(surucuYenileLog), false]) then {
                    _v setVariable [QGVAR(surucuYenileLog), true];
                    diag_log format ["[SURUCU-YENILE] %1 | surucu %2 oldu, yedek surucu YOK (yolcu yok): arac hareket edemeyecek", getText (configOf _v >> "displayName"), name _son];
                };
                continue
            };
            // rutbesi en yuksek yolcu degil, en dusuk (asker) gecer: lider / nisanci / MG rolleri bozulmasin
            private _sirali = [_aday apply { _x select 0 }, [], { rankId _x }, "ASCEND"] call BIS_fnc_sortBy;
            private _u = _sirali select 0;
            moveOut _u;
            _u moveInDriver _v;
            _u assignAsDriver _v;
            _u enableAI "PATH"; _u enableAI "MOVE";
            _v engineOn true;
            _v setVariable [QGVAR(surucuYenileLog), nil];
            diag_log format ["[SURUCU-YENILE] %1 | surucu %2 oldu -> %3 (grup %4) surucu koltuguna gecti | yolcu %5 | surucu simdi %6", getText (configOf _v >> "displayName"), name _son, name _u, groupId (group _u), count _aday, name (driver _v)];
        } forEach vehicles;
    };
};

[_calis] spawn {
    params ["_fn"];
    while {true} do {
        private _h = [] spawn _fn;
        waitUntil { sleep 5; scriptDone _h };
        diag_log "[WATCHDOG-YENIDEN] surucuYenile betigi sonlandi (hata?)";
        sleep 5;
    };
};

true
