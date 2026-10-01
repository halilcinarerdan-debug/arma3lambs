#include "script_component.hpp"
/*
 * Author: diwako (ELITE fork: Cinar)
 * Returns position and stance of the best cover locations.
 *
 * ELITE v3 — "ilk bulunan" yerine PUANLAMA:
 *   + koruma seviyesi (DOWN / MIDDLE / UP gizli = 12 / 24 / 36)
 *   + yan acilardan (+-25 derece) de gizli olma (+8 / acilar) -> ikinci dusman / manevra
 *   + arazi (tepe/cukur) gizlemesi dahil (terrainIntersectASL)
 *   - uzaklik (0.5 / m)
 *   - dusmana yaklasma (DEFEND/OVERWATCH: -0.8 / m;  ADVANCE: yaklasma BONUS +0.5 / m)
 *   - yumusak obje (calı / kucuk agac: mermi durdurmaz) -10
 *   - baska askerin 8 sn icinde rezerve ettigi nokta -20
 *   - 2.2m icinde dost kalabaligi -8 / kisi
 *   OVERWATCH: ayakta gorus VARSA (+14) — MG/nisanci icin atis pozisyonu
 *
 * Arguments:
 * 0: Unit seeking cover <OBJECT>
 * 1: Enemy <OBJECT> or Enemy Position (AGL) <ARRAY>
 * 2: Range to find cover, default ELITE_COVER_RANGE <NUMBER>
 * 3: Sort mode <STRING>, default "ASCEND" (aday toplama sirasi): ASCEND, DESCEND, RANDOM
 * 4: Max Results <Number>, default ELITE_COVER_MAX_RESULTS, -1 for all
 * 5: Mode <STRING>, default "DEFEND": "DEFEND" | "ADVANCE" | "OVERWATCH"
 *
 * Return Value:
 * Array of format [[_posAGL, _stance], ...] SKORA GORE sirali (en iyi ilk);
 * bos dizi = siper yok. Stance "UP", "MIDDLE" or "DOWN" (gizli kalinan EN YUKSEK stance)
 *
 * Example:
 * [bob, angryJoe, 30, "ASCEND", 1, "ADVANCE"] call lambs_main_fnc_findCover
 *
 * Public: Yes
*/
params [
    ["_unit", objNull, [objNull]],
    ["_enemy", objNull, [objNull, []]],
    ["_range", ELITE_COVER_RANGE],
    ["_sortMode", "ASCEND", [""]],
    ["_maxResults", ELITE_COVER_MAX_RESULTS],
    ["_mode", "DEFEND", [""]]
];

_maxResults = floor _maxResults;
private _ret = [];

if (_maxResults isEqualTo 0) exitWith {_ret};

private _enemyPos = _enemy call CBA_fnc_getPos;
private _dangerPos = _enemyPos vectorAdd [0, 0, 1.8];

if (_dangerPos isNotEqualTo [0, 0, 1.8]) then {
    _dangerPos = AGLToASL _dangerPos;

    private _unitEnemyDist = _unit distance2D _enemyPos;
    private _group = group _unit;
    private _simdi = time;

    // ---------------------------------------------------------------------
    // Aday objeler: sert (agac/bina/HIDE) + yumusak (calı/kucuk agac) + araclar
    // ---------------------------------------------------------------------
    private _sert = nearestTerrainObjects [_unit, ["TREE", "HIDE", "BUILDING"], _range, false, true];
    private _yumusak = nearestTerrainObjects [_unit, ["BUSH", "SMALL TREE"], _range, false, true];
    private _terrainObjects = _sert + _yumusak;

    // Murettebatli (hareketli / dost) arac siper sayilmaz; "building" cift sayilmaz
    private _vehicles = (nearestObjects [_unit, ["building", "Car"], _range]) select {
        !(_x in _terrainObjects)
        && {((crew _x) findIf {alive _x}) isEqualTo -1}
    };

    private _allObjs = [];
    if (_sortMode in ["ASCEND", "DESCEND"]) then {
        _allObjs = [_terrainObjects + _vehicles, [], {_unit distance2D _x}, _sortMode] call BIS_fnc_sortBy;
    } else {
        _allObjs = (_terrainObjects + _vehicles) call BIS_fnc_arrayShuffle;
    };
    if ((count _allObjs) > 28) then {
        _allObjs = _allObjs select [0, 28];
    };

    // 8 sn'den eski rezervleri at
    private _claims = (_group getVariable [QGVAR(coverClaims), []]) select {(_simdi - (_x select 1)) < 8};

    // Gizli mi: obje VEYA arazi hattı kesiyor
    private _gizli = {
        params ["_bas", "_son", "_u"];
        (lineIntersects [_bas, _son, _u]) || {terrainIntersectASL [_bas, _son]}
    };

    // Birimin bildigi DIGER dusmanlar (en fazla 2): siper hepsine karsi korumali olmali
    private _hedefObj = if (_enemy isEqualType objNull) then {_enemy} else {objNull};
    private _digerTehditler = [];
    {
        if ((count _digerTehditler) < 2 && {_x isNotEqualTo _hedefObj} && {alive _x}) then {
            _digerTehditler pushBack (eyePos _x);
        };
    } forEach (_unit targets [true, 250]);

    private _adaylar = [];
    private _degerlendirilen = 0;

    {
        if (_degerlendirilen >= 50) exitWith {};

        private _obj = _x;
        private _yumusakMi = _obj in _yumusak;
        private _buildingPos = [_obj, ELITE_COVER_BUILDING_POS] call CBA_fnc_buildingPositions;

        if (_buildingPos isEqualTo []) then {
            // Bina pozisyonu yok (bitki / kucuk obje): dusmana gore objenin ARKASI,
            // bbox disina +0.8m (eskiden rastgele bbox kosesi seciliyordu).
            private _objPos = getPosATL _obj;
            private _awayDir = _enemyPos getDir _objPos;
            private _farPos = _objPos getPos [50, _awayDir];
            private _loc = _obj worldToModel _farPos;
            private _dx = _loc select 0;
            private _dy = _loc select 1;
            private _len = (sqrt ((_dx * _dx) + (_dy * _dy))) max 0.001;
            _dx = _dx / _len;
            _dy = _dy / _len;
            (boundingBoxReal _obj) params ["_bbMin", "_bbMax"];
            private _ex = if (_dx >= 0) then {_bbMax select 0} else {abs (_bbMin select 0)};
            private _ey = if (_dy >= 0) then {_bbMax select 1} else {abs (_bbMin select 1)};
            private _t = 15;
            if ((abs _dx) > 0.01) then {_t = _t min (_ex / (abs _dx));};
            if ((abs _dy) > 0.01) then {_t = _t min (_ey / (abs _dy));};
            private _golge = _objPos getPos [_t + 0.8, _awayDir];
            _golge set [2, 0.1];
            _buildingPos = [_golge];
        };

        {
            private _pos = _x;

            if (_degerlendirilen < 50 && {(_dangerPos distance2D _pos) > ELITE_COVER_MIN_DIST}) then {
                private _posASL = AGLToASL _pos;

                // DOWN gizli degilse aday degil
                if ([_dangerPos, _posASL vectorAdd [0, 0, 0.1], _unit] call _gizli) then {
                    _degerlendirilen = _degerlendirilen + 1;

                    private _stances = ["DOWN"];
                    if ([_dangerPos, _posASL vectorAdd [0, 0, 0.75], _unit] call _gizli) then {
                        _stances pushBack "MIDDLE";
                        if ([_dangerPos, _posASL vectorAdd [0, 0, 1.45], _unit] call _gizli) then {
                            _stances pushBack "UP";
                        };
                    };

                    private _enemyDist = _pos distance2D _enemyPos;
                    private _skor = (count _stances) * 12;

                    // Yan acilar: dusman +-25 derece kayarsa / ikinci dusman varsa hala gizli mi
                    private _enemyDir = _pos getDir _enemyPos;
                    {
                        private _yan = AGLToASL ((_pos getPos [_enemyDist, _enemyDir + _x]) vectorAdd [0, 0, 1.8]);
                        if ([_yan, _posASL vectorAdd [0, 0, 0.75], _unit] call _gizli) then {
                            _skor = _skor + 8;
                        };
                    } forEach [-25, 25];

                    // Diger bilinen dusmanlara karsi da gizli mi (jilet gibi siper)
                    {
                        if ([_x, _posASL vectorAdd [0, 0, 0.75], _unit] call _gizli) then {
                            _skor = _skor + 10;
                        } else {
                            _skor = _skor - 6;
                        };
                    } forEach _digerTehditler;

                    // Uzaklik maliyeti
                    _skor = _skor - ((_unit distance2D _pos) * 0.5);

                    // Dusmana yaklasma: ADVANCE bonus, digerleri ceza
                    private _yaklasma = _unitEnemyDist - _enemyDist;
                    if (_mode isEqualTo "ADVANCE") then {
                        _skor = _skor + (((_yaklasma min 25) max -25) * 0.5);
                    } else {
                        if (_yaklasma > 0) then {
                            _skor = _skor - (_yaklasma * 0.8);
                        };
                    };

                    // OVERWATCH: ayakta gorus VARSA atis pozisyonu (MG / nisanci)
                    if (_mode isEqualTo "OVERWATCH") then {
                        if ("UP" in _stances) then {
                            _skor = _skor - 10;
                        } else {
                            _skor = _skor + 14;
                        };
                    };

                    // Siper-arkasi atis (hull-down): MIDDLE gizli, UP acik = korunup ates edebilir
                    if (_mode isEqualTo "DEFEND" && {"MIDDLE" in _stances} && {!("UP" in _stances)}) then {
                        _skor = _skor + 6;
                    };

                    // Yumusak obje (calı) mermi durdurmaz
                    if (_yumusakMi) then {
                        _skor = _skor - 10;
                    };

                    // Baska askerin rezervi / dost kalabaligi
                    if ((_claims findIf {
                        (((_x select 0) distance2D _pos) < 3) && {(_x select 2) isNotEqualTo _unit}
                    }) > -1) then {
                        _skor = _skor - 20;
                    };
                    _skor = _skor - ((count ((_pos nearEntities ["CAManBase", 2.2]) - [_unit])) * 8);

                    _adaylar pushBack [_skor, _pos, _stances select ((count _stances) - 1)];
                };
            };
        } forEach _buildingPos;
    } forEach _allObjs;

    // ---------------------------------------------------------------------
    // En iyiler (skora gore) + rezerv
    // ---------------------------------------------------------------------
    if (_adaylar isNotEqualTo []) then {
        _adaylar sort false;
        private _adet = if (_maxResults isEqualTo -1) then {
            count _adaylar
        } else {
            _maxResults min (count _adaylar)
        };
        for "_i" from 0 to (_adet - 1) do {
            private _a = _adaylar select _i;
            _ret pushBack [_a select 1, _a select 2];
        };

        _claims pushBack [(_ret select 0) select 0, _simdi, _unit];
        _group setVariable [QGVAR(coverClaims), _claims];
    };
};

if (GVAR(debug_functions) && {(_ret isNotEqualTo [])}) then {
    ["Found %1 cover positions", count _ret] call FUNC(debugLog);
    {
        "Sign_Arrow_Large_F" createVehicleLocal ((_enemy call CBA_fnc_getPos) vectorAdd [0, 0, 1.8]);
        private _add = if ((_x select 1) isEqualTo "UP") then {
            2
        } else {
            [0.2, 1] select (_x select 1 isEqualTo "MIDDLE");
        };
        "Sign_Arrow_Large_Blue_F" createVehicleLocal ((_x select 0) vectorAdd [0, 0, _add]);
    } forEach _ret;
};

_ret
