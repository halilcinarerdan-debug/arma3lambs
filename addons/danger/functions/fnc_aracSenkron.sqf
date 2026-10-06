#include "script_component.hpp"
/*
 * Author: Cinar (ELITE fork)
 * ARAC - PIYADE SENKRONU (v8.111) — kullanici: "araclar piyade ile senkron ilerlesin".
 * Sorun: arac grubu (APC / tank / teknik) piyadeden bagimsiz tam hizla ilerler, piyadeyi geride birakir ve tek basina temasa girer.
 * Kural (2 sn'de bir, yerel AI arac gruplari; arac lideri kara araci, surucu AI, yalniz murettebat — icinde >= 2 piyade yolcu varsa yolcu tasiyici sayilir ve atlanir):
 *   ESKORT: arac lideri en yakin dost PIYADE grubunu (>= 3 yaya asker, lider yaya; oyuncu gruplari dahil) 300 m icinde bulur.
 *   'ONDE' mesafesi = (arac - piyade merkezi) vektorunun aracin yonune izdusumu:
 *     > 60 m   -> BEKLE: surucu forceSpeed 0 (piyade yetisene kadar)
 *     20..60 m -> piyade hizi + 1 m/sn (yavasla, geri dus)
 *     -40..20  -> SENKRON: piyade hizi x 1.1 (en az 1.4 m/sn = 5 km/s; piyade durursa arac da piyadenin yaninda durur)
 *     < -40 m  -> SERBEST (forceSpeed -1: piyadenin onune gec / yetis)
 *   SERBEST BIRAKMA (kural kapanir, forceSpeed -1): dusman 100 m icinde veya arac / surucu baski > 0.5, grup retreat / kacis / temas kes, eskort bulunamadi, arac tasiyici (>= 2 yolcu), aracli medevac gorevi.
 * mekanizeIzle'nin forceSpeed -1 duzeltmesi senkron suresince (senkT) atlanir. Doktrin anahtari aracSenkron (varsayilan true). Kapatma: lambs_danger_aracSenkronOff = true.
 * Log: [ARAC-SENKRON] durum degisimleri (ilk 80) + [ARAC-SENKRON-OZET] 90 sn
 *
 * Arguments: None
 * Return Value: Baslatildi mi <BOOL>
 * Public: No
*/

if (!isNil "lambs_danger_aracSenkronStarted") exitWith {false};
lambs_danger_aracSenkronStarted = true;

diag_log "[ARAC-SENKRON] arac - piyade senkronu watchdog'u baslatildi (v8.111)";

private _calis = {
    missionNamespace setVariable ["lambs_danger_aracSenkronAdim", "basladi"];
    private _logN = 0;
    private _say = createHashMap;
    private _ozetT = time + 90;
    while {true} do {
        sleep 2;
        if (missionNamespace getVariable ["lambs_danger_aracSenkronOff", false]) then { continue };
        {
            private _g = _x;
            private _l = leader _g;
            if (isNull _l || {!local _g} || {isPlayer _l} || {!alive _l} || {(side _g) isEqualTo civilian}) then { continue };
            private _veh = vehicle _l;
            if (_veh isEqualTo _l || {!(_veh isKindOf "LandVehicle")}) then { continue };
            private _d = driver _veh;
            if (isNull _d || {isPlayer _d} || {!alive _d}) then { continue };
            if (_g getVariable ["lambs_danger_tarafKapali", false]) then { continue };
            missionNamespace setVariable ["lambs_danger_aracSenkronAdim", format ["grup %1", groupId _g]];

            private _serbest = {
                params ["_neden"];
                if ((_d getVariable [QGVAR(senkDurum), ""]) isNotEqualTo "") then {
                    _d forceSpeed -1;
                    _d setVariable [QGVAR(senkDurum), ""];
                    _d setVariable [QGVAR(senkT), 0];
                    _say set ["serbest", (_say getOrDefault ["serbest", 0]) + 1];
                    if (_logN < 80) then { _logN = _logN + 1; diag_log format ["[ARAC-SENKRON] %1 | arac %2 | SERBEST (%3)", groupId _g, typeOf _veh, _neden]; };
                };
            };

            if !([_g, "aracSenkron", true] call FUNC(dk)) then { ["doktrin kapali"] call _serbest; continue };
            private _yolcuPiyade = ({alive _x && {(group _x) isNotEqualTo _g}} count (crew _veh)) + ({alive _x && {_x isKindOf "CAManBase"} && {(assignedVehicleRole _x) select 0 isEqualTo "cargo"}} count (units _g));
            if (_yolcuPiyade >= 2) then { ["tasiyici (yolcu >= 2)"] call _serbest; continue };
            if ((_g getVariable [QGVAR(isRetreating), false]) || {_g getVariable [QGVAR(isEvading), false]} || {_g getVariable [QGVAR(isBreakingContact), false]} || {_g getVariable [QGVAR(isSonDirenis), false]}) then { ["cekilme / kacis"] call _serbest; continue };
            if ((time - (_veh getVariable [QGVAR(aracMedevacT), -999])) < 120 || {(time - (_g getVariable [QGVAR(aracMedevacT), -999])) < 120} || {_veh getVariable [QGVAR(tasimaMesgul), false]}) then { ["aracli medevac / nakil"] call _serbest; continue };   // v8.130: grup degiskeni + nakil (RPT 5ebe2e37: Stryker nakil yolunda 1.4 m/s'e kisildi)

            // tehdit: dusman yakin / baski
            private _en = _d findNearestEnemy _d;
            if ((!isNull _en && {(_d distance2D _en) < 100}) || {(getSuppression _d) > 0.5}) then { ["dusman < 100 m / baski"] call _serbest; continue };

            // eskort piyade grubu
            private _vp = getPosATL _veh;
            private _adaylar = allGroups select {
                (side _x) isEqualTo (side _g) && {_x isNotEqualTo _g} && {!isNull (leader _x)} && {isNull objectParent (leader _x)} && {alive (leader _x)}
                && {((units _x) findIf {alive _x && {isNull objectParent _x}}) >= 0} && {((leader _x) distance2D _vp) < 300}
                && {({alive _x && {isNull objectParent _x}} count (units _x)) >= 3}
            };
            if (_adaylar isEqualTo []) then { ["eskort piyade yok"] call _serbest; continue };
            _adaylar = [_adaylar, [], {(leader _x) distance2D _vp}, "ASCEND"] call BIS_fnc_sortBy;
            private _pg = _adaylar select 0;
            private _yaya = (units _pg) select {alive _x && {isNull objectParent _x}};
            private _mx = 0; private _my = 0;
            { private _p = getPosATL _x; _mx = _mx + (_p select 0); _my = _my + (_p select 1); } forEach _yaya;
            private _merkez = [_mx / (count _yaya), _my / (count _yaya), 0];
            private _pHiz = (speed (leader _pg)) / 3.6;   // m/sn
            private _yon = getDir _veh;
            private _fark = _vp vectorDiff _merkez;
            private _onde = ((_fark select 0) * (sin _yon)) + ((_fark select 1) * (cos _yon));

            private _durum = "";
            private _hiz = -1;
            if (_onde > 60) then { _durum = "BEKLE"; _hiz = 0; }
            else { if (_onde > 20) then { _durum = "YAVASLA"; _hiz = (_pHiz + 1) max 1.4; }
            else { if (_onde > -40) then { _durum = "SENKRON"; _hiz = ((_pHiz * 1.1) max 1.4) min 8; }
            else { _durum = "SERBEST-GERIDE"; _hiz = -1; }; }; };

            private _eski = _d getVariable [QGVAR(senkDurum), ""];
            if (_durum isEqualTo "SERBEST-GERIDE") then {
                ["piyadenin gerisinde (yetis)"] call _serbest;
            } else {
                _d forceSpeed _hiz;
                _d setVariable [QGVAR(senkT), time + 5];
                _d setVariable [QGVAR(senkDurum), _durum];
                _say set [_durum, (_say getOrDefault [_durum, 0]) + 1];
                if (_eski isNotEqualTo _durum && {_logN < 80}) then {
                    _logN = _logN + 1;
                    diag_log format ["[ARAC-SENKRON] %1 | arac %2 | %3 | piyade %4 (%5 kisi, %6 km/s) | aracin onunde %7 m | hiz siniri %8 m/sn", groupId _g, typeOf _veh, _durum, groupId _pg, count _yaya, round (_pHiz * 3.6), round _onde, _hiz toFixed 1];
                };
            };
        } forEach (allGroups select {local _x && {!isNull leader _x}});
        if (time > _ozetT) then {
            _ozetT = time + 90;
            if (count _say > 0) then { diag_log format ["[ARAC-SENKRON-OZET] son 90 sn (tur sayaci): %1", (keys _say) apply {format ["%1:%2", _x, _say get _x]}]; };
            _say = createHashMap;
        };
        missionNamespace setVariable ["lambs_danger_aracSenkronAdim", "tur bitti"];
    };
};

// bekci: betik hata ile olurse yeniden baslat
[_calis] spawn {
    params ["_fn"];
    while {true} do {
        private _h = [] spawn _fn;
        waitUntil { sleep 5; scriptDone _h };
        diag_log format ["[WATCHDOG-YENIDEN] aracSenkron betigi sonlandi (hata?), son adim: %1", missionNamespace getVariable ["lambs_danger_aracSenkronAdim", "?"]];
        sleep 5;
    };
};

true
