#include "script_component.hpp"
/*
 * Author: Cinar (ELITE fork)
 * AI GRUBU SUNUCUYA DEVIR (v8.124) — kullanici: Zeus ile konan AI curator'un PC'sinde kalip onu kasiyor, sunucu 160 FPS bos.
 * Arma'da AI hesabi grubun SAHIBI makinede yapilir; Zeus'la olusturulan gruplar cogu zaman Zeus istemcisinde yerel kalir. Sahip dusuk FPS'teyse
 * AI karar / yuruyus kalitesi duser. Bu bekci SUNUCUDA calisir, istemcide yerel kalan AI gruplarini sunucuya devreder (setGroupOwner 2).
 * Devredilmez: oyuncu iceren grup, curator'un uzaktan kontrol ettigi birim, headless client'a ait grup, olu / bos grup, sivil, son devirden 60 sn gecmemis grup.
 * Hizlilik: 10 sn'de bir, tur basina en fazla 4 grup. v8.155: yeni yaratilan grup 120 sn (lambs_danger_sunucuDevirBekleS) beklenir (yoksa envanter / kiyafet kaybi). Kapatma: lambs_danger_sunucuDevirOff = true.   Log: [SUNUCU-DEVIR]
 *
 * Arguments: None
 * Return Value: Baslatildi mi <BOOL>
 * Public: No
*/

if (!isServer) exitWith {false};
if (!isNil "lambs_danger_sunucuDevirStarted") exitWith {false};
lambs_danger_sunucuDevirStarted = true;

diag_log "[SUNUCU-DEVIR] istemcide kalan AI gruplarini sunucuya devir bekcisi baslatildi (v8.124)";

private _calis = {
    missionNamespace setVariable ["lambs_danger_sunucuDevirAdim", "basladi"];
    private _devirT = createHashMap;   // grup -> son devir zamani (ping-pong onleme)
    private _ilkT = createHashMap;     // v8.155: grup -> ilk gorulme zamani (Zeus yeni yarattiysa devir ERTELENIR)
    private _bekLog = 0;
    private _toplam = 0;
    private _ozetT = time + 120;
    while {true} do {
        sleep 10;
        if (missionNamespace getVariable ["lambs_danger_sunucuDevirOff", false]) then { continue };
        // headless client sahipleri (devredilmez)
        private _hcSahip = (entities "HeadlessClient_F") apply {owner _x};
        private _tur = 0;
        {
            if (_tur >= 4) exitWith {};
            private _g = _x;
            if (isNull _g) then { continue };
            // v8.155 (RPT 7ab83653): Zeus'un yeni yarattigi grup 5-8 sn icinde setGroupOwner ile devredilince askerlerin kiyafet / yelek / canta / silahi sunucuya GECMEDI
            // ("Server: Object 4:xx not found" mesajlari; AT / MG asistan (cantali) bos: kiyafet '' silah '' sarjor 0) -> grup en az 120 sn "yerlessin" sonra devredilir
            if !(netId _g in _ilkT) then { _ilkT set [netId _g, time]; _g setVariable [QGVAR(gorulduT), time]; };
            if ((time - (_ilkT getOrDefault [netId _g, time])) < (missionNamespace getVariable ["lambs_danger_sunucuDevirBekleS", 120])) then {
                if (!local _g && {_bekLog < 20}) then { _bekLog = _bekLog + 1; diag_log format ["[SUNUCU-DEVIR] %1 yeni yaratildi (%2 sn), devir %3 sn sonra", groupId _g, round (time - (_ilkT getOrDefault [netId _g, time])), round ((missionNamespace getVariable ["lambs_danger_sunucuDevirBekleS", 120]) - (time - (_ilkT getOrDefault [netId _g, time])))]; };
                continue
            };
            if (local _g || {isNull (leader _g)} || {(side _g) isEqualTo civilian}) then { continue };
            private _us = units _g;
            if (_us isEqualTo [] || {({alive _x} count _us) isEqualTo 0}) then { continue };
            if ((_us findIf {isPlayer _x}) >= 0) then { continue };
            if ((_us findIf {!isNull (_x getVariable ["bis_fnc_moduleRemoteControl_owner", objNull])}) >= 0) then { continue };
            if ((groupOwner _g) in _hcSahip) then { continue };
            if ((time - (_devirT getOrDefault [netId _g, -999])) < 60) then { continue };
            missionNamespace setVariable ["lambs_danger_sunucuDevirAdim", format ["grup %1", groupId _g]];
            private _eski = groupOwner _g;
            _devirT set [netId _g, time];
            _g setGroupOwner 2;
            _tur = _tur + 1;
            _toplam = _toplam + 1;
            if (_toplam <= 40) then {
                diag_log format ["[SUNUCU-DEVIR] %1 (%2, %3 asker) sahip %4 -> sunucu", groupId _g, side _g, count _us, _eski];
            };
        } forEach allGroups;
        if (time > _ozetT) then {
            _ozetT = time + 120;
            if (_toplam > 0 && {_toplam isNotEqualTo (missionNamespace getVariable ["lambs_danger_sunucuDevirSonOzet", -1])}) then {
                missionNamespace setVariable ["lambs_danger_sunucuDevirSonOzet", _toplam];
                diag_log format ["[SUNUCU-DEVIR-OZET] bugune kadar %1 grup devredildi", _toplam];
            };
        };
        missionNamespace setVariable ["lambs_danger_sunucuDevirAdim", "tur bitti"];
    };
};

[_calis] spawn {
    params ["_fn"];
    while {true} do {
        private _h = [] spawn _fn;
        waitUntil { sleep 5; scriptDone _h };
        diag_log format ["[WATCHDOG-YENIDEN] grupSunucuDevir betigi sonlandi (hata?), son adim: %1", missionNamespace getVariable ["lambs_danger_sunucuDevirAdim", "?"]];
        sleep 5;
    };
};

true
