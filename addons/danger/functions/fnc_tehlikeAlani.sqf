#include "script_component.hpp"
/*
 * Author: Cinar (ELITE fork)
 * TEHLIKE ALANI GECISI (v8.92) — YOL (acik cizgisel tehlike alani) gecisi: once gozetle, sonra ikili takimlarla sirayla gec (genel doktrin ilkesi: danger area crossing = once guvenlik / gozetleme, sonra bolum bolum; kaynakli degil).
 * Kullanici gozlemi: iki taraf da otoyolu kullandi / yoldan gecti.
 *
 * TESPIT (3 sn'de bir): yerel piyade grubu (>= 5, oyuncusuz), temas yok (>= 20 sn), taktik / retreat / bounding / IED / sniper / pusu isi yok, lider arac disinda ve YOLDA DEGIL; liderin beklenen hedefi
 *   (expectedDestination, ilk 20-70 m) dogrultusunda 15 m adimla orneklenir: roadAt var + yol uzerinde degil + cevre ACIK (80 m'de yapi < 6 ve 40 m'de agac < 6) -> gecis noktasi C.
 *   Ayni grup 120 sn bekler. Lider yoldaysa (yol boyunca yuruyus) tetiklenmez.
 * ICRA (spawn, en fazla 70 sn; temas / retreat / taktik baslarsa HEMEN serbest):
 *   (1) DUR + GOZETLE (8 sn): herkes doStop + comelir; yolun iki ucuna (yol ekseni +-) 2 gozetleyici (gozcu / nisanci / MG oncelik) doWatch; digerleri yol kenarini izler
 *   (2) TAKIM A (lider + yarisi): yol karsisina 18 m koşar, orada yola bakar; TAKIM B gozetler
 *   (3) TAKIM B gecer; en son gozetleyiciler
 *   (4) serbest: doFollow + stance AUTO + mevcut waypoint yeniden (setCurrentWaypoint)
 * Kapatma: lambs_danger_tehlikeAlaniOff = true.   Log: [TEHLIKE-ALANI] (ilk 60) + [TEHLIKE-ALANI-OZET] 90 sn
 * SINIR: yalniz YOL (roadAt); tepe sirti / acik tarla gecisi yok. Waypoint olmayan (expectedDestination bos) grup tetiklenmez.
 *
 * Arguments: None
 * Return Value: Baslatildi mi <BOOL>
 * Public: No
*/

if (!isNil "lambs_danger_tehlikeAlaniStarted") exitWith {false};
lambs_danger_tehlikeAlaniStarted = true;

diag_log "[TEHLIKE-ALANI] yol gecisi (gozetle + sirayla gec) watchdog'u baslatildi (v8.92)";

private _gecis = {
    params ["_g", "_c", "_yonYol", "_hedefYon"];
    private _t0 = time;
    private _l = leader _g;
    private _bitir = {
        params ["_g", "_neden"];
        if (isNull _g) exitWith {};
        _g setVariable [QGVAR(isExecutingTactic), nil];
        _g setVariable [QGVAR(tehlikeAlaniT), time];
        {
            if (alive _x) then {
                _x setVariable [QGVAR(taktikKilit), nil];
                _x setUnitPos "AUTO";
                _x doWatch objNull;
                _x doFollow (leader _g);
            };
        } forEach (units _g);
        if (!isNull (leader _g) && {currentWaypoint _g > 0 || {(count (waypoints _g)) > 0}}) then { _g setCurrentWaypoint [_g, currentWaypoint _g]; };
        diag_log format ["[TEHLIKE-ALANI] %1 | SERBEST: %2", groupId _g, _neden];
    };
    private _us = (units _g) select {alive _x && {isNull objectParent _x} && {!isPlayer _x} && {(lifeState _x) in ["HEALTHY", "INJURED"]}};
    if ((count _us) < 5) exitWith {};
    private _iptalMi = { params ["_g"]; isNull _g || {(_g getVariable [QGVAR(contact), 0]) > time} || {_g getVariable [QGVAR(isRetreating), false]} || {_g getVariable [QGVAR(isEvading), false]} };

    _g setVariable [QGVAR(isExecutingTactic), true];
    { _x setVariable [QGVAR(taktikKilit), time + 75]; } forEach _us;
    // takimlar: lider + en yakin yarisi = A; kalan = B (gozetleyiciler B'den: gozcu / nisanci once)
    private _digerler = _us select {_x isNotEqualTo _l};
    _digerler = [_digerler, [], {_x distance2D _c}, "ASCEND"] call BIS_fnc_sortBy;
    private _nA = ceil ((count _digerler) / 2);
    private _A = [_l] + (_digerler select [0, _nA]);
    private _B = _digerler select [_nA, count _digerler];
    private _gz = _B select {(_x getVariable [QGVAR(gozcu), false]) || {_x isEqualTo (_g getVariable [QGVAR(gozcu), objNull])}};
    private _gozetleyen = (_gz + _B) arrayIntersect _B;
    private _gozetA = _gozetleyen select [0, 2 min (count _gozetleyen)];
    diag_log format ["[TEHLIKE-ALANI] %1 | YOL GECISI basladi | gecis noktasi %2 m ileride | takim A:%3 B:%4 | gozetleyen:%5", groupId _g, round (_l distance2D _c), count _A, count _B, _gozetA apply {name _x}];

    // (1) dur + gozetle
    { doStop _x; _x setUnitPos "MIDDLE"; } forEach _us;
    private _uc1 = _c getPos [100, _yonYol];
    private _uc2 = _c getPos [100, _yonYol + 180];
    { _x doWatch ([_uc1, _uc2] select (_forEachIndex mod 2)); } forEach _gozetA;
    { _x doWatch _c; } forEach (_us - _gozetA);
    private _bek = time + 8;
    waitUntil { sleep 0.5; time > _bek || {[_g] call _iptalMi} };
    if ([_g] call _iptalMi) exitWith { [_g, "temas / retreat / grup yok"] call _bitir; };

    // (2) takim A gecer
    private _hedefNokta = _c getPos [20, _hedefYon];
    { _x setUnitPos "UP"; _x forceSpeed -1; _x setSpeedMode "FULL"; _x doMove (_hedefNokta getPos [random 4, random 360]); } forEach _A;
    private _bitisA = time + 25;
    waitUntil { sleep 0.5; time > _bitisA || {[_g] call _iptalMi} || {(_A findIf {alive _x && {(_x distance2D _hedefNokta) > 10}}) < 0} };
    if ([_g] call _iptalMi) exitWith { [_g, "A gecerken temas / retreat"] call _bitir; };
    { _x setUnitPos "MIDDLE"; _x doWatch _c; } forEach _A;

    // (3) takim B gecer
    { _x setUnitPos "UP"; _x forceSpeed -1; _x setSpeedMode "FULL"; _x doMove (_hedefNokta getPos [random 5, random 360]); } forEach _B;
    private _bitisB = time + 25;
    waitUntil { sleep 0.5; time > _bitisB || {[_g] call _iptalMi} || {(_B findIf {alive _x && {(_x distance2D _hedefNokta) > 12}}) < 0} };
    [_g, ["TAMAM (" + str (round (time - _t0)) + " sn)", "temas / retreat (B gecerken)"] select ([_g] call _iptalMi)] call _bitir;
};
missionNamespace setVariable ["lambs_danger_tehlikeAlaniGecisFn", _gecis];

private _calis = {
    missionNamespace setVariable ["lambs_danger_tehlikeAdim", "basladi"];
    private _gecisFn = missionNamespace getVariable "lambs_danger_tehlikeAlaniGecisFn";
    private _say = createHashMap;
    private _ozetT = time + 90;
    while {true} do {
        sleep 3;
        if (missionNamespace getVariable ["lambs_danger_tehlikeAlaniOff", false]) then { continue };
        {
            private _g = _x;
            private _l = leader _g;
            if (isNull _l || {!local _g} || {isPlayer _l} || {!alive _l} || {!isNull objectParent _l}) then { continue };
            if ((time - (_g getVariable [QGVAR(tehlikeAlaniT), -999])) < 120) then { continue };
            if ((_g getVariable [QGVAR(contact), 0]) > (time - 20)) then { continue };
            if (({_g getVariable [_x, false]} count [QGVAR(isRetreating), QGVAR(isEvading), QGVAR(isBounding), QGVAR(isExecutingTactic), QGVAR(isBreakingContact), QGVAR(isAmbushing), QGVAR(sniperTeam), QGVAR(isSonDirenis), QGVAR(disableGroupAI)]) > 0) then { continue };
            if ((_g getVariable [QGVAR(iedIs), []]) isNotEqualTo []) then { continue };
            if (((units _g) select {alive _x && {isNull objectParent _x}}) isEqualTo [] || {(count ((units _g) select {alive _x && {isNull objectParent _x}})) < 5}) then { continue };
            if ((speed _l) < 2) then { continue };
            missionNamespace setVariable ["lambs_danger_tehlikeAdim", format ["grup %1", groupId _g]];
            private _lp = getPosATL _l;
            if (isOnRoad _lp) then { continue };
            private _ed = expectedDestination _l;
            private _hedef = _ed select 0;
            if (!(_hedef isEqualType []) || {_hedef isEqualTo [0,0,0]} || {(_l distance2D _hedef) < 40}) then { continue };
            private _yon = _lp getDir _hedef;
            private _bulunan = [];
            for "_d" from 20 to 70 step 15 do {
                private _p = _lp getPos [_d, _yon];
                private _yol = roadAt _p;
                if (!isNull _yol) exitWith { _bulunan = [_p, _yol, _d]; };
            };
            if (_bulunan isEqualTo []) then { continue };
            _bulunan params ["_c", "_yolObj", "_d"];
            // cevre ACIK mi
            private _bina = count (nearestTerrainObjects [_c, ["BUILDING", "HOUSE"], 80, false, true]);
            private _agac = count (nearestTerrainObjects [_c, ["TREE", "SMALL TREE", "BUSH"], 40, false, true]);
            if (_bina >= 6 || {_agac >= 6}) then { _say set ["kapali cevre", (_say getOrDefault ["kapali cevre", 0]) + 1]; continue };
            // yol ekseni
            private _bagli = roadsConnectedTo _yolObj;
            private _yonYol = if (_bagli isEqualTo []) then { _yon + 90 } else { (getPosATL _yolObj) getDir (getPosATL (_bagli select 0)) };
            _g setVariable [QGVAR(tehlikeAlaniT), time];
            _say set ["gecis", (_say getOrDefault ["gecis", 0]) + 1];
            [_g, _c, _yonYol, _yon] spawn _gecisFn;
        } forEach (allGroups select {local _x && {!isNull leader _x} && {!(_x getVariable ["lambs_danger_tarafKapali", false])}});
        if (time > _ozetT) then {
            _ozetT = time + 90;
            if (count _say > 0) then { diag_log format ["[TEHLIKE-ALANI-OZET] son 90 sn: %1", (keys _say) apply {format ["%1:%2", _x, _say get _x]}]; };
            _say = createHashMap;
        };
        missionNamespace setVariable ["lambs_danger_tehlikeAdim", "tur bitti"];
    };
};

// bekci: betik hata ile olurse yeniden baslat
[_calis] spawn {
    params ["_fn"];
    while {true} do {
        private _h = [] spawn _fn;
        waitUntil { sleep 5; scriptDone _h };
        diag_log format ["[WATCHDOG-YENIDEN] tehlike alani betigi sonlandi (hata?), son adim: %1", missionNamespace getVariable ["lambs_danger_tehlikeAdim", "?"]];
        sleep 5;
    };
};

true
