#include "script_component.hpp"
/*
 * Author: Cinar (ELITE fork)
 * HAREKAT BEKCISI (v8.404) - fnc_harekat'in durum makinesini 5 sn'de bir yurutur (yalniz sunucu); tum makinelerde harekat mesaj olayini ('lambs_danger_harekatMesaj') dinler (oyuncular kendi taraflarinin
 *   mesajlarini, Zeus'lar hepsini sohbette gorur) ve Zeus kontrol modulunun sunucu istegini ('lambs_danger_harekatIstegi': islem, id) karsilar.
 *   Betik hatayla olurse bekci yeniden baslatir ([WATCHDOG-YENIDEN]). Kapatma: lambs_danger_harekatOff = true.
 *
 * Arguments: None
 * Return Value: Baslatildi mi <BOOL>
 * Public: No
*/

if (!isNil "lambs_danger_harekatStarted") exitWith {false};
lambs_danger_harekatStarted = true;

["lambs_danger_harekatMesaj", {
    params ["_taraf", "_m"];
    if (!hasInterface) exitWith {};
    if (playerSide isEqualTo _taraf || {!isNull (getAssignedCuratorLogic player)}) then { systemChat _m; };
}] call CBA_fnc_addEventHandler;

["lambs_danger_harekatDurum", {
    params ["_t"];
    if (!hasInterface) exitWith {};
    { systemChat _x; } forEach (_t splitString (toString [10]));
}] call CBA_fnc_addEventHandler;

if (!isServer) exitWith {true};

["lambs_danger_harekatDurumIstegi", {
    params ["_sahip", "_id"];
    private _t = ["DURUM", [_id]] call lambs_danger_fnc_harekat;
    ["lambs_danger_harekatDurum", [_t], _sahip] call CBA_fnc_ownerEvent;
}] call CBA_fnc_addEventHandler;

["lambs_danger_harekatIstegi", {
    params ["_islem", "_id"];
    if !(_islem in ["BASLAT", "SONRAKI", "DURDUR"]) exitWith {};
    private _r = [_islem, [_id]] call lambs_danger_fnc_harekat;
    diag_log format ["[HAREKAT] Zeus istegi: %1 %2 -> %3", _islem, _id, _r];
}] call CBA_fnc_addEventHandler;

diag_log "[HAREKAT] harekat bekcisi baslatildi (v8.404): fazli harekat + oyuncu gorevleri (BIS gorev) + OPORD taslagi";

private _calis = {
    missionNamespace setVariable ["lambs_danger_harekatAdim", "basladi"];
    while {true} do {
        sleep 5;
        if (isNil "lambs_danger_harekatlar") then { continue };
        {
            missionNamespace setVariable ["lambs_danger_harekatAdim", format ["harekat %1", _x]];
            ["ADIM", [_x]] call lambs_danger_fnc_harekat;
        } forEach (keys lambs_danger_harekatlar);
        missionNamespace setVariable ["lambs_danger_harekatAdim", "tur bitti"];
    };
};

[_calis] spawn {
    params ["_fn"];
    while {true} do {
        private _h = [] spawn _fn;
        waitUntil { sleep 5; scriptDone _h };
        diag_log format ["[WATCHDOG-YENIDEN] harekat betigi sonlandi (hata?), son adim: %1", missionNamespace getVariable ["lambs_danger_harekatAdim", "?"]];
        sleep 5;
    };
};

true
