#include "script_component.hpp"
/*
 * Author: Cinar (ELITE fork)
 * MERMI DISIPLINI FARKINDALIGI (v8.104) — kullanici: "mermi disiplini farkindaligi".
 * Her asker kendi birincil silah cephanesini (envanter + takili sarjor, 40 mm haric) 'sarjor esdegeri' olarak bilir ve ona gore davranir:
 *   TASARRUF  : sarjor esdegeri < 2.0 (MG: < 1.5)  -> baski atesi / alana atis gorevlerinden cikarilir (destek ateşi, MG olmayanlar); histerezis: >= 3.0 (MG 2.5) olunca biter
 *   KRITIK    : sarjor esdegeri < 0.8 (MG < 0.6)   -> tabanca varsa ve mermisi varsa tabanca secilir (uzun tufek acikta bos kalmasin); cephane istegi (cephanePaylas esigi zaten < 3 sarjor)
 *   GRUP      : >= %50 askerde TASARRUF -> grup degiskeni lambs_danger_mermiKriz = true (moral / komutan okuyabilir; moral zaten dusuk cephane sayar); olay 'MermiAz'
 * Okunan degiskenler: unit lambs_danger_mermiTasarruf / mermiKritik / mermiSayi (sarjor esdegeri).  Yerel AI piyadeler, 3 sn'de bir.
 * Kapatma: lambs_danger_mermiDisiplinOff = true.   Log: [MERMI] (ilk 60) + [MERMI-OZET] 90 sn
 *
 * Arguments: None
 * Return Value: Baslatildi mi <BOOL>
 * Public: No
*/

if (!isNil "lambs_danger_mermiDisiplinStarted") exitWith {false};
lambs_danger_mermiDisiplinStarted = true;

diag_log "[MERMI] mermi disiplini farkindaligi watchdog'u baslatildi (v8.104)";

private _calis = {
    missionNamespace setVariable ["lambs_danger_mermiAdim", "basladi"];
    private _rolFn = missionNamespace getVariable ["lambs_danger_fnc_getUnitRole", {"RIFLE"}];
    private _gonder = missionNamespace getVariable ["lambs_danger_fnc_olayGonder", {false}];
    private _logN = 0;
    private _say = createHashMap;
    private _ozetT = time + 90;
    while {true} do {
        sleep 3;
        if (missionNamespace getVariable ["lambs_danger_mermiDisiplinOff", false]) then { continue };
        {
            private _g = _x;
            if (!local _g || {isNull (leader _g)} || {(side _g) isEqualTo civilian}) then { continue };
            private _us = (units _g) select {alive _x && {isNull objectParent _x} && {!isPlayer _x} && {(lifeState _x) in ["HEALTHY", "INJURED"]}};
            if (_us isEqualTo []) then { continue };
            missionNamespace setVariable ["lambs_danger_mermiAdim", format ["grup %1", groupId _g]];
            private _tas = 0;
            {
                private _u = _x;
                private _w = primaryWeapon _u;
                if (_w isEqualTo "") then { continue };
                private _uyum = (compatibleMagazines _w) apply {toLower _x};
                private _top = 0;
                private _kap = 30;
                {
                    _x params ["_m", "_n"];
                    private _mk = toLower _m;
                    if (_mk in _uyum) then {
                        private _c = getNumber (configFile >> "CfgMagazines" >> _m >> "count");
                        if (_c > 3) then { _top = _top + _n; _kap = _kap max _c; };   // 40 mm / tek atim mermiler (<= 3) haric
                    };
                } forEach (magazinesAmmo _u);
                // takili sarjor da magazinesAmmo icinde; kapasite en buyuk sarjor sinifi
                private _sayi = _top / (_kap max 1);
                private _mg = ([_u] call _rolFn) isEqualTo "MG";
                private _esikT = [2.0, 1.5] select _mg;
                private _esikTBit = [3.0, 2.5] select _mg;
                private _esikK = [0.8, 0.6] select _mg;
                private _eskiT = _u getVariable [QGVAR(mermiTasarruf), false];
                private _yeniT = _eskiT;
                if (_sayi < _esikT) then { _yeniT = true; };
                if (_sayi >= _esikTBit) then { _yeniT = false; };
                private _yeniK = _sayi < _esikK;
                _u setVariable [QGVAR(mermiSayi), _sayi];
                if (_yeniT isNotEqualTo _eskiT) then {
                    _u setVariable [QGVAR(mermiTasarruf), _yeniT];
                    _say set [["bitti", "basladi"] select _yeniT, (_say getOrDefault [["bitti", "basladi"] select _yeniT, 0]) + 1];
                    if (_logN < 60) then {
                        _logN = _logN + 1;
                        diag_log format ["[MERMI] %1 | %2 (%3) | TASARRUF %4 | sarjor esdegeri %5 (esik %6)", groupId _g, name _u, [_u] call _rolFn, ["bitti", "basladi"] select _yeniT, _sayi toFixed 2, _esikT];
                    };
                };
                if (_yeniT) then { _tas = _tas + 1; };
                if (_yeniK isNotEqualTo (_u getVariable [QGVAR(mermiKritik), false])) then {
                    _u setVariable [QGVAR(mermiKritik), _yeniK];
                    if (_yeniK) then {
                        private _h = handgunWeapon _u;
                        if (_h isNotEqualTo "" && {((magazines _u) findIf {(toLower _x) in ((compatibleMagazines _h) apply {toLower _x})}) >= 0}) then {
                            _u selectWeapon _h;
                            _say set ["tabanca", (_say getOrDefault ["tabanca", 0]) + 1];
                        };
                        _say set ["kritik", (_say getOrDefault ["kritik", 0]) + 1];
                        if (_logN < 60) then {
                            _logN = _logN + 1;
                            diag_log format ["[MERMI] %1 | %2 (%3) | KRITIK | sarjor esdegeri %4 | tabanca %5", groupId _g, name _u, [_u] call _rolFn, _sayi toFixed 2, _h isNotEqualTo ""];
                        };
                    };
                };
            } forEach _us;
            private _kriz = (_tas / (count _us)) >= 0.5 && {(count _us) >= 3};
            if (_kriz isNotEqualTo (_g getVariable [QGVAR(mermiKriz), false])) then {
                _g setVariable [QGVAR(mermiKriz), _kriz];
                if (_kriz) then { [_g, "MermiAz", _tas] call _gonder; };
                if (_logN < 60) then {
                    _logN = _logN + 1;
                    diag_log format ["[MERMI] %1 | GRUP %2 | tasarruf eden %3/%4", groupId _g, ["KRIZ BITTI", "KRIZ"] select _kriz, _tas, count _us];
                };
            };
        } forEach allGroups;
        if (time > _ozetT) then {
            _ozetT = time + 90;
            if (count _say > 0) then { diag_log format ["[MERMI-OZET] son 90 sn: %1", (keys _say) apply {format ["%1:%2", _x, _say get _x]}]; };
            _say = createHashMap;
        };
        missionNamespace setVariable ["lambs_danger_mermiAdim", "tur bitti"];
    };
};

// bekci: betik hata ile olurse yeniden baslat
[_calis] spawn {
    params ["_fn"];
    while {true} do {
        private _h = [] spawn _fn;
        waitUntil { sleep 5; scriptDone _h };
        diag_log format ["[WATCHDOG-YENIDEN] mermiDisiplin betigi sonlandi (hata?), son adim: %1", missionNamespace getVariable ["lambs_danger_mermiAdim", "?"]];
        sleep 5;
    };
};

true
