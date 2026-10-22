#include "script_component.hpp"
/*
 * Author: Cinar (ELITE fork)
 * DRON GORUNCE DAGIL + SAKLAN (v8.288; kullanici: 'botlar dusman dronu gorunce mesafeyi arttirsinlar ve saklansinlar').
 * Kamikaze / silahli dron (FPV, bomba, silahli) <= 700 m: grup tek yigin olarak kalmaz (FPV kume uzerine dalar) - her asker AYRI bir noktaya dagilir ve saklanir:
 *   - once dronun bakisini kesen en yakin SERT SIPER (findCover SURVIVE, 35 m); yoksa dronden UZAGA (dron -> asker dogrultusu +-50 derece) 18-26 m acik nokta + yatar
 *   - atanan noktalar birbirine >= 10 m (mesafe artisi); su olmayan nokta
 *   - ates edecek 3 asker (dron ates menzilindeyse; fnc_dronTepki) yerinde kalir, yalniz comelir / yatar
 *   - 25 sn boyunca asker `taktikKilit` ile korunur (buddyBond / dispersion / roleStation geri cekmesin); sure bitince durus AUTO, kilit kalkar
 *   - 15 sn'de bir grup basina; retreat / evade, medik tedavisi, baygin, esir, forceMove askerleri atlanir. v8.291: bounding / taktik yurutenler yalniz dron <= 200 m (acil) iken: taktik bozulmadan 7 sn yere yatar
 * Doner: yonlendirilen asker sayisi <NUMBER>.  Log: [DRON-SAKLAN].  Kapatma: lambs_danger_dronSaklaOff = true.
 *
 * Arguments:
 * 0: Grup <GROUP>
 * 1: Dron <OBJECT>
 * 2: Dron ates menzilinde mi (3 nisanci yerinde kalir) <BOOL>
 *
 * Return Value: Yonlendirilen asker sayisi <NUMBER>
 * Public: No
*/

params [["_g", grpNull, [grpNull]], ["_dr", objNull, [objNull]], ["_ates", false, [false]], ["_acil", false, [false]]];
if (isNull _g || {isNull _dr} || {!alive _dr} || {missionNamespace getVariable ["lambs_danger_dronSaklaOff", false]}) exitWith {0};
if ((time - (_g getVariable [QGVAR(dronSaklaT), -99])) < 15) exitWith {0};
if ((_g getVariable [QGVAR(isRetreating), false]) || {_g getVariable [QGVAR(isEvading), false]}) exitWith {0};
// v8.291 ACIL (kullanici: 'ben combata aldim elemanlari hic tetiklenmedi'): bounding / LAMBS taktigi yurutenler eskiden tamamen atlaniyordu -> combat'taki grup dronda hic tepki vermiyordu.
//   Dron <= 200 m (acil) ise taktigi bozmadan HERKES 7 sn YERE YATAR (yurume emri verilmez); dagilma / siper yalniz taktik yurutmeyenlerde.
private _mesgul = (_g getVariable [QGVAR(isBounding), false]) || {_g getVariable [QGVAR(isExecutingTactic), false]};
if (_mesgul && {!_acil}) exitWith {0};

private _ud = (units _g) select {
    alive _x && {local _x} && {!isPlayer _x} && {isNull objectParent _x}
    && {(lifeState _x) in ["HEALTHY", "INJURED"]}
    && {!(_x getVariable [QGVAR(forceMove), false])} && {(_x getVariable [QGVAR(taktikKilit), 0]) <= time}
    && {!(_x getVariable [QGVAR(teslim), false])} && {time >= (_x getVariable [QGVAR(tcccBusy), 0])}
};
if (_ud isEqualTo []) exitWith {0};

// ates edecek en yakin 3 silahli asker yerinde kalir
private _atesci = [];
if (_ates) then {
    // v8.292: yerinde kalip ates eden sayisi 3 -> 2 (grup >= 4) / 1 (daha kucuk) - gerisi KACAR (kullanici: 'hala ayni, kacmadilar')
    _atesci = (([_ud select {(primaryWeapon _x) isNotEqualTo ""}, [], {_x distance _dr}, "ASCEND"] call BIS_fnc_sortBy)) select [0, [1, 2] select ((count _ud) >= 4)];
};

_g setVariable [QGVAR(dronSaklaT), time];
private _atanan = [];
private _n = 0;
private _siperN = 0;
private _binaN = 0;
{
    private _u = _x;
    if (_mesgul) then {
        // taktik yurutuyor: yalniz yere yat (7 sn), yurume / kilit yok; ates edenler (3 nisanci) comelir
        _u setUnitPos (["DOWN", "MIDDLE"] select (_u in _atesci));
        [{ params ["_uu"]; if (alive _uu) then { _uu setUnitPos "AUTO"; }; }, [_u], 7] call CBA_fnc_waitAndExecute;
        _n = _n + 1;
        continue
    };
    _u setVariable [QGVAR(taktikKilit), time + 40];   // v8.292: 25 -> 40 sn
    [{ params ["_uu"]; if (alive _uu) then { _uu setUnitPos "AUTO"; _uu setVariable [QGVAR(taktikKilit), nil]; }; }, [_u], 40] call CBA_fnc_waitAndExecute;
    if (_u in _atesci) then {
        _u setUnitPos "MIDDLE";
        continue
    };
    private _hedef = [];
    private _durus = "DOWN";
    // v8.292: 1) 60 m icinde BINA varsa icine (FPV'ye karsi ust koruma), 2) 60 m icinde sert siper, 3) dronden uzaga 35-60 m acik nokta (eskiden 18-26 m)
    private _bina = nearestBuilding _u;
    if (!isNull _bina && {(_u distance2D _bina) < 60}) then {
        private _bps = (_bina buildingPos -1) select { private _c = _x; (_atanan findIf {(_x distance2D _c) < 1.5}) < 0 };
        if (_bps isNotEqualTo []) then {
            _hedef = selectRandom _bps;
            _durus = "AUTO";
            _binaN = _binaN + 1;
        };
    };
    private _cv = if (_hedef isEqualTo []) then { [_u, _dr, 60, "ASCEND", 1, "SURVIVE"] call EFUNC(main,findCover) } else {[]};
    if (_cv isNotEqualTo []) then {
        private _cp = (_cv select 0) select 0;
        if ((_atanan findIf {(_x distance2D _cp) < 10}) < 0) then {
            _hedef = _cp;
            _durus = (_cv select 0) select 1;
            _siperN = _siperN + 1;
        };
    };
    if (_hedef isEqualTo []) then {
        // acik nokta: dronden uzaga, +-50 derece, 18-26 m; atananlara >= 10 m
        private _yon = (_dr getDir _u);
        for "_k" from 0 to 5 do {
            private _p = (getPosATL _u) getPos [35 + random 25, _yon + ((random 100) - 50)];
            if (!surfaceIsWater _p && {(_atanan findIf {(_x distance2D _p) < 10}) < 0}) exitWith { _hedef = _p; };
        };
    };
    if (_hedef isNotEqualTo []) then {
        _atanan pushBack _hedef;
        // v8.297 (RPT 22-10 22:53: lider [10478,880] 23:00 -> 23:02 ayni yer; 'DOWN' + doMove = SUREKLI SURUNEREK 35-60 m, 40 sn'de ~10 m): kosarken AYAKTA (UP + FULL hiz), varinca / 15 sn sonra istenen durusa gecer
        _u doMove _hedef;
        _u setUnitPos "UP";
        _u setSpeedMode "FULL";
        [{ params ["_uu", "_hp"]; !alive _uu || {(_uu distance2D _hp) < 4} }, { params ["_uu", "_hp", "_ds"]; if (alive _uu) then { _uu setUnitPos _ds; }; }, [_u, _hedef, _durus], 15, { params ["_uu", "_hp", "_ds"]; if (alive _uu) then { _uu setUnitPos _ds; }; }] call CBA_fnc_waitUntilAndExecute;
        _n = _n + 1;
    };
} forEach _ud;

if ((time - (_g getVariable [QGVAR(dronSaklaLogT), -999])) > 20) then {
    _g setVariable [QGVAR(dronSaklaLogT), time];
    diag_log format ["[DRON-SAKLAN] %1 | %2 %3 m | %4 asker kacti (%5 binada, %6 siperde, %7 acikta yatar) | %8 nisanci yerinde | taktikKilit 40 sn", groupId _g, typeOf _dr, round (_dr distance2D (leader _g)), _n, _binaN, _siperN, _n - _binaN - _siperN, count _atesci];
};
_n
