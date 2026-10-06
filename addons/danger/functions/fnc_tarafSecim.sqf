#include "script_component.hpp"
/*
 * Author: Cinar (ELITE fork)
 * TARAF SECIMI (v8.86) — kullanici: "LAMBS komutan hangi sidede aktif olacagini secebilelim; oyuncular BLUFOR ise istedikleri gibi BLUFOR'u dislayabilsin".
 *
 * CBA Addon Options > LAMBS Danger > ELITE taraf secimi (sunucu ayari): BLUFOR / OPFOR / INDEPENDENT / SIVIL icin "ELITE aktif" (varsayilan: ilk uc acik, sivil kapali).
 * Mission / Zeus script ile de: lambs_danger_aktifWest / aktifEast / aktifInd / aktifCiv = true | false.
 * KAPALI taraf: o taraftaki TUM AI gruplari (oyunculu grup icindeki botlar dahil) LAMBS FSM'den + fork'un tum izleyicilerinden cikarilir:
 *   grup lambs_danger_disableGroupAI = true, her birim lambs_danger_disableAI = true, grup lambs_danger_tarafKapali = true (fork izleyicileri bu grubu atlar; HQ tahtasina girmez).
 * Yalniz KENDI koydugumuz bayraklari geri alir (ayar tekrar acilinca ya da baska elle konmus disableAI'a dokunmaz). 3 sn'de bir, yalniz yerel gruplar.   Log: [TARAF] (degisim aninda)
 *
 * Arguments: None
 * Return Value: Baslatildi mi <BOOL>
 * Public: No
*/

if (!isNil "lambs_danger_tarafSecimStarted") exitWith {false};
lambs_danger_tarafSecimStarted = true;

diag_log "[TARAF] taraf secimi watchdog'u baslatildi (v8.86): CBA 'ELITE taraf secimi' / lambs_danger_aktifWest|East|Ind|Civ";

private _calis = {
    missionNamespace setVariable ["lambs_danger_tarafAdim", "basladi"];
    private _son = createHashMap;
    while {true} do {
        sleep 3;
        private _durum = [
            [west, missionNamespace getVariable ["lambs_danger_aktifWest", true]],
            [east, missionNamespace getVariable ["lambs_danger_aktifEast", true]],
            [independent, missionNamespace getVariable ["lambs_danger_aktifInd", true]],
            [civilian, missionNamespace getVariable ["lambs_danger_aktifCiv", false]]
        ];
        {
            _x params ["_taraf", "_aktif"];
            if (_aktif isNotEqualTo (_son getOrDefault [str _taraf, true])) then {
                _son set [str _taraf, _aktif];
                diag_log format ["[TARAF] %1 | ELITE %2", _taraf, ["KAPALI (dislandi)", "ACIK"] select _aktif];
            };
        } forEach _durum;
        {
            private _g = _x;
            if (isNull _g || {!local _g} || {(count (units _g)) isEqualTo 0}) then { continue };
            missionNamespace setVariable ["lambs_danger_tarafAdim", format ["grup %1", groupId _g]];
            private _aktif = true;
            { if ((_x select 0) isEqualTo (side _g)) exitWith { _aktif = _x select 1; }; } forEach _durum;
            private _kapali = _g getVariable [QGVAR(tarafKapali), false];
            if (!_aktif && {!_kapali}) then {
                _g setVariable [QGVAR(tarafKapali), true];
                _g setVariable [QGVAR(tarafGrupDAI), _g getVariable [QGVAR(disableGroupAI), false]];
                _g setVariable [QGVAR(disableGroupAI), true];
                { _x setVariable [QGVAR(tarafBirimDAI), _x getVariable [QGVAR(disableAI), false]]; _x setVariable [QGVAR(disableAI), true]; } forEach (units _g);
            };
            if (!_aktif && {_kapali}) then {
                // sonradan eklenen birimler (katilan / dogan)
                { if (isNil {_x getVariable QGVAR(tarafBirimDAI)}) then { _x setVariable [QGVAR(tarafBirimDAI), _x getVariable [QGVAR(disableAI), false]]; _x setVariable [QGVAR(disableAI), true]; }; } forEach (units _g);
            };
            if (_aktif && {_kapali}) then {
                _g setVariable [QGVAR(disableGroupAI), [nil, true] select (_g getVariable [QGVAR(tarafGrupDAI), false])];
                { _x setVariable [QGVAR(disableAI), [nil, true] select (_x getVariable [QGVAR(tarafBirimDAI), false])]; _x setVariable [QGVAR(tarafBirimDAI), nil]; } forEach (units _g);
                _g setVariable [QGVAR(tarafKapali), nil];
                _g setVariable [QGVAR(tarafGrupDAI), nil];
            };
        } forEach allGroups;
        missionNamespace setVariable ["lambs_danger_tarafAdim", "tur bitti"];
    };
};

// bekci: betik hata ile olurse yeniden baslat
[_calis] spawn {
    params ["_fn"];
    while {true} do {
        private _h = [] spawn _fn;
        waitUntil { sleep 5; scriptDone _h };
        diag_log format ["[WATCHDOG-YENIDEN] taraf secimi betigi sonlandi (hata?), son adim: %1", missionNamespace getVariable ["lambs_danger_tarafAdim", "?"]];
        sleep 5;
    };
};

true
