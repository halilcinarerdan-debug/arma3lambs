#include "script_component.hpp"
/*
 * Author: Cinar (ELITE fork)
 * DRON GOZLEMCISI (v8.336) — kullanici: 'dron saldirisi israrla tekrar edilirse gelis yonune dogru gozlem dronu gonderebilsinler, eger dron gozlemci varsa'. SUNUCU olay isleyicisi (fnc_dronGozlemTalep gonderir): tarafin GOZLEM dronu varsa onu operator bolgesine yollar.
 * GOZLEMCI ARAMA (sirayla):
 *   1) HAZIR IHA: tarafin AI muretttebatli / muretttebatsiz GOZLEM turu (fnc_ihaTip = GOZLEM; silahsiz) insansiz hava araci, gorevde degil (lambs_danger_ihaTok yok) -> tahmin bolgesine en yakin
 *   2) GOZLEMCI ASKER: sirt cantasi bir GOZLEM dronuna donusen (config assembleInfo >> assembleTo; Crocus FPV / Mavic bomba cantasi degil) askerli (yerel, oyuncusuz, temassiz, tahmin bolgesinden >= 250 m) -> canta tuketilir, dron askerin onunde 40 m'de yaratilir,
 *      asker operator (operator olunce dron kontrolu kaybeder / duser: fnc_ihaSorti opMod 1)
 *   Gozlemci yoksa hicbir sey yapilmaz (log).
 * GOREV: fnc_ihaSorti 'GOZLEM' modu: tahmin merkezi etrafinda (kesisim 300 m / tek dogru 450 m yaricap) 120 m'de devriye; gorulen dusman fnc_ihaGozlem ile ortak resme verilir (reveal 1.5) -> gruplar / dron avi devriyesi operatoru bilir.
 * Taraf basina tek aktif gozlem dronu; 240 sn bekleme (fnc_dronGozlemTalep). Kapatma: CBA 'Dron gozlemcisi' / lambs_danger_dronGozlemOff. Log: [DRON-GOZLEM].
 *
 * Arguments: None (acilista bir kez; yalniz sunucu)
 * Return Value: Baslatildi mi <BOOL>
 * Public: No
*/

if (!isServer || {!isNil "lambs_danger_dronGozlemciStarted"}) exitWith {false};
lambs_danger_dronGozlemciStarted = true;

["lambs_danger_dronGozlemIstegi", {
    params ["_taraf", "_est", "_geri", "_kesisim", ["_nDron", 0], ["_nGoz", 0], ["_yarOv", 0]];   // v8.338: _yarOv > 0 ise gozlem yaricapi (dron gozlemli topcu istasyonu)
    if (!isServer || {missionNamespace getVariable ["lambs_danger_dronGozlemOff", false]}) exitWith {};
    private _kT = format ["lambs_danger_dronGozT_%1", _taraf];
    private _kI = format ["lambs_danger_dronGozIHA_%1", _taraf];
    if ((time - (missionNamespace getVariable [_kT, -999])) < 240) exitWith {};
    private _aktif = missionNamespace getVariable [_kI, objNull];
    if (!isNull _aktif && {alive _aktif} && {(diag_tickTime - (_aktif getVariable [QGVAR(ihaTok), -999])) < 650}) exitWith {};   // v8.338: gorevi biten (inmis) dron aktif sayilmaz (pil omru 600 sn)
    private _yar = [450, 300] select _kesisim;
    if (_yarOv > 0) then { _yar = _yarOv; };
    private _tarafNo = [east, west, independent, civilian] find _taraf;

    // 1) hazir GOZLEM IHA'si
    private _hazir = vehicles select {
        unitIsUAV _x && {alive _x} && {private _tk = _x getVariable [QGVAR(ihaTok), -1]; _tk < 0 || {(diag_tickTime - _tk) > 650}} && {([_x] call FUNC(ihaTip)) isEqualTo "GOZLEM"} && {(_x weaponsTurret [0]) isEqualTo []}
        && {
            private _mur = (crew _x) select {alive _x};
            if (_mur isEqualTo []) then { (getNumber (configOf _x >> "side")) isEqualTo _tarafNo } else { (side (group (_mur select 0))) isEqualTo _taraf }
        }
    };
    if (_hazir isNotEqualTo []) exitWith {
        _hazir = [_hazir, [], {_x distance2D _est}, "ASCEND"] call BIS_fnc_sortBy;
        private _u = _hazir select 0;
        missionNamespace setVariable [_kT, time];
        missionNamespace setVariable [_kI, _u];
        [_u, "GOZLEM", "GOZLEM", _taraf, _est, _yar, 3000, objNull, 0] spawn FUNC(ihaSorti);
        diag_log format ["[DRON-GOZLEM] %1 | HAZIR gozlem dronu gonderildi: %2 (%3) -> tahmin %4 (yaricap %5 m, %6) | %7 farkli dron / %8 gozlem", _taraf, typeOf _u, getText (configOf _u >> "displayName"), mapGridPosition _est, _yar, ["tek dogru", "kesisim"] select _kesisim, _nDron, _nGoz];
    };

    // 1b) v8.339: BEKLEYEN GOZLEM emri (Zeus 'ELITE IHA Gorevi' > Dron yarat; dusman tetik mesafesine girene kadar dron YARATILMAZ -> eskiden 'gozlemci YOK' cikiyordu): ayni tarafin
    //     bekleyen GOZLEM emri tahmin bolgesine <= 3500 m ise hemen serbest birakilir (fnc_ihaBekle dronu yaratir ve istasyona yollar).
    private _bekleyen = (missionNamespace getVariable ["lambs_danger_ihaBekleEmirleri", []]) select {
        (count _x) >= 5 && {!(_x select 1)} && {(_x select 4) isEqualTo []} && {(_x select 2) isEqualTo "GOZLEM"} && {(_x select 3) isEqualTo _taraf} && {((_x select 0) distance2D _est) <= 3500}
    };
    if (_bekleyen isNotEqualTo []) exitWith {
        _bekleyen = [_bekleyen, [], {(_x select 0) distance2D _est}, "ASCEND"] call BIS_fnc_sortBy;
        private _b = _bekleyen select 0;
        _b set [4, [_est, _yar]];
        missionNamespace setVariable [_kT, time];
        diag_log format ["[DRON-GOZLEM] %1 | BEKLEYEN gozlem emri serbest birakildi: firlatma %2 -> istasyon %3 (yaricap %4 m, %5) | %6 farkli dron / %7 gozlem", _taraf, mapGridPosition (_b select 0), mapGridPosition _est, _yar, ["tek dogru", "kesisim"] select _kesisim, _nDron, _nGoz];
    };

    // 2) gozlemci asker (GOZLEM dronuna donusen sirt cantasi)
    private _aday = [];
    {
        private _bp = backpack _x;
        if (_bp isNotEqualTo "") then {
            private _sn = getText (configFile >> "CfgVehicles" >> _bp >> "assembleInfo" >> "assembleTo");
            if (_sn isNotEqualTo "" && {isClass (configFile >> "CfgVehicles" >> _sn)} && {([_sn] call FUNC(ihaTip)) isEqualTo "GOZLEM"}
                && {((getNumber (configFile >> "CfgVehicles" >> _sn >> "isUav")) isEqualTo 1) || {(toLower (getText (configFile >> "CfgVehicles" >> _sn >> "simulation"))) in ["uav", "helicopterrtd", "helicopterx"]}}) then {
                _aday pushBack [_x, _sn];
            };
        };
    } forEach (allUnits select {
        alive _x && {(side (group _x)) isEqualTo _taraf} && {local _x} && {!isPlayer _x} && {isNull objectParent _x} && {(lifeState _x) in ["HEALTHY", "INJURED"]}
        && {((group _x) getVariable [QGVAR(contact), 0]) <= time} && {(_x distance2D _est) >= 250}
    });
    if (_aday isEqualTo []) exitWith {
        diag_log format ["[DRON-GOZLEM] %1 | gozlemci YOK: hazir GOZLEM dronu, bekleyen GOZLEM emri ve gozlem dronu cantali asker bulunamadi (tahmin %2, %3 farkli dron) - gozlem dronu gonderilemedi", _taraf, mapGridPosition _est, _nDron];
    };
    _aday = [_aday, [], {(_x select 0) distance2D _est}, "ASCEND"] call BIS_fnc_sortBy;
    (_aday select 0) params ["_op", "_sn"];
    private _bas = (getPosATL _op) getPos [4, getDir _op];
    private _iha = createVehicle [_sn, [_bas select 0, _bas select 1, 40], [], 0, "FLY"];
    _iha setPosATL [_bas select 0, _bas select 1, 40];
    removeBackpackGlobal _op;
    missionNamespace setVariable [_kT, time];
    missionNamespace setVariable [_kI, _iha];
    [_iha, "GOZLEM", "GOZLEM", _taraf, _est, _yar, 3000, _op, 1] spawn FUNC(ihaSorti);
    diag_log format ["[DRON-GOZLEM] %1 | GOZLEMCI ASKER %2 (%3) dron firlatti: %4 (%5) -> tahmin %6 (yaricap %7 m, %8) | operatore %9 m | %10 farkli dron / %11 gozlem", _taraf, name _op, groupId (group _op), _sn, getText (configFile >> "CfgVehicles" >> _sn >> "displayName"), mapGridPosition _est, _yar, ["tek dogru", "kesisim"] select _kesisim, round (_op distance2D _est), _nDron, _nGoz];
}] call CBA_fnc_addEventHandler;

diag_log "[DRON-GOZLEM] dron gozlemcisi baslatildi (v8.336): saldiri israrla tekrarlanirsa gelis yonune gozlem dronu (hazir GOZLEM IHA'si ya da gozlem dronu cantali asker)";
true
