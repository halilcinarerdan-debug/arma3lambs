#include "script_component.hpp"
/*
 * Author: Cinar (ELITE fork)
 * ARAC TAKSISI (v8.129) — kullanici: "apc transport olsun ama genel kullanima acik olsun, taksi gibi; doktrin ne diyorsa".
 * Sunucuda 10 sn'de bir: yaya AI grubu uzak bir hedefe gidiyorsa (aktif waypoint > 1200 m) ve 600 m icinde bos bir kara araci varsa (APC / IFV / kamyon; aracin AI grubu tamamen icinde),
 * grup araca biner, arac hedefin 500 m oncesinde (M16 etkili menzili 460 m + pay; kitapta inis mesafesi sayisi YOK -> TASARIM) iner, grup yuruyerek hedefine devam eder; arac biniş noktasina doner.
 * Alinmaz: temasta (son 60 sn), taktik / geri cekilme / medevac / plan icindeki, <2 asker, oyuncu iceren, plan waypoint'i ("ELITE PLAN:"), hedef 1200 m'den yakin, 180 sn icinde tasinmis gruplar.
 * Sinirlama: ayni anda en fazla 2 taksi gorevi (sunucu yuku). Kapatma: lambs_danger_taksiOff = true.  Log: [TAKSI] (+ [TASIMA]).
 *
 * Arguments: None
 * Return Value: Baslatildi mi <BOOL>
 * Public: No
*/

if (!isServer) exitWith {false};
if (!isNil "lambs_danger_taksiStarted") exitWith {false};
lambs_danger_taksiStarted = true;

diag_log "[TAKSI] arac taksisi watchdog'u baslatildi (v8.129)";

private _calis = {
    missionNamespace setVariable ["lambs_danger_taksiAdim", "basladi"];
    private _tasFn = missionNamespace getVariable ["lambs_danger_fnc_aracTasima", {0}];
    private _isler = [];
    private _logN = 0;
    while {true} do {
        sleep 10;
        if (missionNamespace getVariable ["lambs_danger_taksiOff", false]) then { continue };
        _isler = _isler select {!scriptDone _x};
        if (count _isler >= 2) then { continue };
        {
            private _g = _x;
            if (count _isler >= 2) exitWith {};
            private _l = leader _g;
            if (isNull _l || {isPlayer _l} || {!local _g} || {(side _g) isEqualTo civilian}) then { continue };
            private _us = (units _g) select {alive _x};
            if (count _us < 2 || {(_us findIf {isPlayer _x || {!isNull objectParent _x}}) >= 0}) then { continue };
            if ((time - (_g getVariable [QGVAR(taksiT), -999])) < 180) then { continue };
            if ((time - (_g getVariable [QGVAR(contact), -999])) < 60) then { continue };
            if (({_g getVariable ["lambs_danger_" + _x, false]} count ["planAktif", "isRetreating", "isEvading", "isBounding", "isExecutingTactic", "isBreakingContact", "isSonDirenis", "isAmbushing", "sniperTeam", "disableGroupAI"]) > 0) then { continue };
            if ((_g getVariable ["lambs_danger_gorev", ""]) in ["MEDEVAC", "TOPCU", "TOPCU_YOK", "KARAKOL_ARAC", "RECON"] || {(_g getVariable ["lambs_danger_garnizonAlt", ""]) isNotEqualTo ""}) then { continue };
            if ((_us findIf {_x getVariable [QGVAR(tcccBusy), false]}) >= 0) then { continue };
            private _wi = currentWaypoint _g;
            if (_wi <= 0 || {_wi >= count (waypoints _g)}) then { continue };
            private _w = (waypoints _g) select _wi;
            if (((waypointName _w) find "ELITE PLAN:") isEqualTo 0) then { continue };
            if !((waypointType _w) in ["MOVE", "SAD", "SCRIPTED", "GUARD", "DESTROY", "GETOUT"]) then { continue };
            private _wp = waypointPosition _w;
            if (_wp isEqualTo [0,0,0] || {(_l distance2D _wp) < 1200}) then { continue };
            _g setVariable [QGVAR(taksiT), time];
            private _B = _wp getDir (getPosATL _l);
            if (_logN < 60) then {
                _logN = _logN + 1;
                diag_log format ["[TAKSI] %1 (%2 asker) | hedefe %3 m -> arac araniyor (600 m icinde)", groupId _g, count _us, round (_l distance2D _wp)];
            };
            missionNamespace setVariable ["lambs_danger_taksiAdim", format ["grup %1", groupId _g]];
            _isler pushBack ([side _g, [_g], getPosATL _l, _wp, _B, 0, 600] spawn _tasFn);
        } forEach allGroups;
    };
};

[_calis] spawn {
    params ["_fn"];
    while {true} do {
        private _h = [] spawn _fn;
        waitUntil { sleep 5; scriptDone _h };
        diag_log format ["[WATCHDOG-YENIDEN] taksi betigi sonlandi (hata?), son adim: %1", missionNamespace getVariable ["lambs_danger_taksiAdim", "?"]];
        sleep 5;
    };
};

true
