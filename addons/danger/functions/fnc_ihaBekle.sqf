#include "script_component.hpp"
/*
 * Author: Cinar (ELITE fork)
 * IHA BILINCLI FIRLATMA (v8.267) — kullanici: "dron sadece dusmana yakinken bilincli bir sekilde spawnlansin". Zeus 'Dron yarat' artik dronu hemen yaratmaz: fnc_ihaBekle bir FIRLATMA EMRI kaydeder ve
 * 5 sn'de bir firlatma noktasinin (modul konumu) tetik mesafesi (varsayilan 1200 m) icinde, IHA'nin tarafinin BILDIGI (taraf gruplarindan biri knowsAbout >= 0.4; hile yok) GERCEK dusman olup olmadigina bakar:
 *   FPV-AT : zirhli (zirh >= 100 / Tank / APC) ya da murettebatli arac; FPV-AP / BOMBA / GOZLEM: yaya dusman (sivil degil).
 * Dusman gorulunce dron firlatma noktasinda 40 m irtifada (FLY, sunucu-yerel) YARATILIR ve fnc_ihaSorti ile gorev baslar. Tetik 0 = hemen yarat (eski davranis). Emir omru 1800 sn (sonra iptal).
 * Emri iptal: Zeus 'ELITE IHA Gorevi' > Gorevi KALDIR (modulu firlatma noktasinin 60 m icine birak). Kapatma: lambs_danger_ihaBekleOff = true (hemen yaratir).  Log: [IHA-BEKLEME]
 *
 * Arguments:
 * 0: Arac sinifi <STRING>
 * 1: Taraf <SIDE>
 * 2: Firlatma noktasi <ARRAY>
 * 3: Tur ("" = otomatik) <STRING>
 * 4: Gozlem yaricapi <NUMBER>
 * 5: Menzil <NUMBER>
 * 6: Tetik mesafesi (m, 0 = hemen) <NUMBER>
 * 7: Operator <OBJECT> (v8.268; olu / silinmis operator ile firlatma yapilmaz, bekleyen emir iptal olur)
 * 8: Operator olunce: 0 bagsiz / 1 duser / 2 son hedefe dalar <NUMBER> (fnc_ihaSorti'ye iletilir)
 * 9: Canta kaynagi <OBJECT> (v8.272; Crocus cantasi tasiyan asker ya da yerdeki canta: firlatma noktasi askeri takip eder, firlatmada canta tuketilir, asker olurse emir iptal olur)
 *
 * Return Value: Emir kaydedildi mi <BOOL>
 * Public: No
*/

if (!isServer) exitWith {false};
if (!canSuspend) exitWith { _this spawn FUNC(ihaBekle); true };

params [["_sn", "", [""]], ["_taraf", west, [west]], ["_poz", [0, 0, 0], [[]]], ["_turE", "", [""]], ["_yar", 300, [0]], ["_men", 3000, [0]], ["_tetik", 1200, [0]], ["_op", objNull, [objNull]], ["_opMod", 0, [0]], ["_canta", objNull, [objNull]]];
private _cantaAsker = !isNull _canta && {_canta isKindOf "CAManBase"};
private _opVar = _opMod > 0 && {!isNull _op};
private _opOldu = { _opVar && {isNull _op || {!alive _op}} };
if (_sn isEqualTo "" || {!isClass (configFile >> "CfgVehicles" >> _sn)}) exitWith {false};

private _tur = if (_turE isNotEqualTo "") then {_turE} else { [_sn] call FUNC(ihaTip) };
private _hemen = _tetik <= 0 || {missionNamespace getVariable ["lambs_danger_ihaBekleOff", false]};

private _emirler = missionNamespace getVariable ["lambs_danger_ihaBekleEmirleri", []];
private _emir = [_poz, false];   // [firlatma noktasi, iptal]
if (!_hemen) then {
    _emirler pushBack _emir;
    missionNamespace setVariable ["lambs_danger_ihaBekleEmirleri", _emirler];
    diag_log format ["[IHA-BEKLEME] %1 (%2) | firlatma emri kaydedildi: %3 | tetik %4 m (dusman bu mesafeye girince yaratilir) | omur 1800 sn | operator %5 (%6)", _sn, _tur, mapGridPosition _poz, round _tetik, ["yok", name _op] select _opVar, ["bagsiz", "olunce dron duser", "olunce hedefe dalar"] select (_opMod max 0 min 2)];
};

private _t0 = time;
private _logT = time + 60;
private _hedef = objNull;
while {!_hemen && {!(_emir select 1)} && {(time - _t0) < 1800} && {isNull _hedef} && {!(call _opOldu)} && {!(_cantaAsker && {!alive _canta})}} do {
    sleep 5;
    // v8.272: cantali asker hareket ediyorsa firlatma noktasi onu izler
    if (_cantaAsker && {alive _canta}) then { _poz = getPosATL _canta; _emir set [0, _poz]; };
    private _bilen = allGroups select {(side _x) isEqualTo _taraf && {!isNull (leader _x)}};
    private _bilinen = {
        params ["_t"];
        (_bilen findIf {_x knowsAbout _t >= 0.4}) >= 0
    };
    private _adaylar = if (_tur isEqualTo "FPV-AT") then {
        (_poz nearEntities [["LandVehicle"], _tetik]) select {alive _x && {(crew _x) findIf {alive _x} >= 0} && {(_taraf getFriend (side (group (driver _x)))) < 0.6} && {((getNumber (configOf _x >> "armor")) >= 100) || {_x isKindOf "Tank"} || {_x isKindOf "APC_Tracked_01_base_F"}}}
    } else {
        (_poz nearEntities [["CAManBase"], _tetik]) select {alive _x && {isNull objectParent _x} && {(side _x) isNotEqualTo civilian} && {(_taraf getFriend (side _x)) < 0.6}}
    };
    _adaylar = _adaylar select {([_x] call FUNC(gercekHedef)) && {[_x] call _bilinen}};
    if (_adaylar isNotEqualTo []) then {
        _adaylar = [_adaylar, [], {_x distance2D _poz}, "ASCEND"] call BIS_fnc_sortBy;
        _hedef = _adaylar select 0;
    } else {
        if (time > _logT) then {
            _logT = time + 60;
            diag_log format ["[IHA-BEKLEME] %1 (%2) | bekliyor (%3 sn): tetik mesafesinde (%4 m) bilinen dusman yok", _sn, _tur, round (time - _t0), round _tetik];
        };
    };
};
// emir listesinden cik
_emirler = (missionNamespace getVariable ["lambs_danger_ihaBekleEmirleri", []]) - [_emir];
missionNamespace setVariable ["lambs_danger_ihaBekleEmirleri", _emirler];
if (_cantaAsker && {!alive _canta} && {isNull _hedef}) exitWith {
    diag_log format ["[IHA-BEKLEME] %1 (%2) | cantali asker OLDU (%3): firlatma emri iptal (canta kayboldu, dron yaratilmadi)", _sn, _tur, name _canta];
    false
};
if ((call _opOldu) && {isNull _hedef}) exitWith {
    diag_log format ["[IHA-BEKLEME] %1 (%2) | OPERATOR OLDU (%3): firlatma emri iptal (dron yaratilmadi)", _sn, _tur, ["", name _op] select (!isNull _op)];
    false
};
if (!_hemen && {isNull _hedef}) exitWith {
    diag_log format ["[IHA-BEKLEME] %1 (%2) | emir bitti: %3 (dron yaratilmadi)", _sn, _tur, ["omur doldu (1800 sn)", "Zeus iptal etti"] select (_emir select 1)];
    false
};

private _iha = createVehicle [_sn, [_poz select 0, _poz select 1, 40], [], 0, "FLY"];
_iha setPosATL [_poz select 0, _poz select 1, 40];
diag_log format ["[IHA-BEKLEME] %1 (%2) | FIRLATMA: %3 | tetik hedefi %4 (%5 m) | %6 sn bekledi", _sn, _tur, mapGridPosition _iha, if (isNull _hedef) then {"-"} else {typeOf _hedef}, if (isNull _hedef) then {0} else {round (_hedef distance2D _poz)}, round (time - _t0)];
// v8.272: canta tuketilir
if (!isNull _canta) then {
    if (_cantaAsker) then {
        if ([backpack _canta, true] call FUNC(ihaCantaSinif)) then { removeBackpackGlobal _canta; };
    } else {
        private _bp = getBackpackCargo _canta;
        private _ci = (_bp select 0) findIf {[_x, true] call FUNC(ihaCantaSinif)};
        if (_ci >= 0) then {
            clearBackpackCargoGlobal _canta;
            { private _n = (_bp select 1) select _forEachIndex; if (_forEachIndex isEqualTo _ci) then { _n = _n - 1; }; if (_n > 0) then { _canta addBackpackCargoGlobal [_x, _n]; }; } forEach (_bp select 0);
        };
    };
    diag_log format ["[IHA-BEKLEME] %1 | canta tuketildi (%2)", _sn, ["yerdeki canta", name _canta] select _cantaAsker];
};
[_iha, "SORTI", _turE, _taraf, _poz, _yar, _men, _op, _opMod] call FUNC(ihaSorti);
true
