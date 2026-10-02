#include "script_component.hpp"
/*
 * Author: diwako (ELITE fork: Cinar)
 * Returns position and stance of the best cover locations.
 *
 * ELITE v4 — MERMI GEOMETRISINE dayali puanlama:
 *   Gizlenme (VIEW) ile KORUNMA (FIRE geometri = mermi durdurur) ayrimi: cali gizler ama
 *   mermi durdurmaz; duvar / bina / kaya / govde hem gizler hem korur.
 *
 *   + KORUNMA   : 0.1 / 0.75 / 1.45 m yukseklikte FIRE-geometri engel sayisi  x14
 *   + gizlenme  : DOWN / MIDDLE / UP gizli stance sayisi                       x8
 *   - sadece gizleme (mermi durdurmaz)                                         -20
 *   + omuz testi: +-0.35m yandan da gizli (govde genisligi)                   +4 / -6
 *   + yan acilar: dusman +-25 derece kayarsa da gizli                         +8 / aci
 *   + diger bilinen dusmanlara (en fazla 2) karsi da gizli                    +10 / -6
 *   + hull-down (DEFEND): MIDDLE gizli, UP acik = korunup ates edebilir        +6
 *   - uzaklik (0.5 / m; EVADE 0.25 / m)
 *   - dusmana yaklasma (DEFEND/OVERWATCH -0.8 / m;  ADVANCE bonus +0.9 / m;  EVADE: UZAKLASMA bonusu +0.9 / m)
 *   - yumusak obje (cali / kucuk agac) -6
 *   - baska askerin 8 sn icinde rezerve ettigi nokta (6m icinde) -20
 *   - 5m icinde dost kalabaligi -10 / kisi (tek el bombasi / RPG hepsini almasin)
 *   OVERWATCH: ayakta gorus VARSA +14 — MG/nisanci icin atis pozisyonu
 *   EVADE    : sadece SERT siper (en az 2 yukseklikte FIRE engel), dusmandan >= 40m, bina +12
 *              (zirhtan kacis: tank/APC mermisi ve HE'ye karsi cali / agac yetmez)
 *
 * Arguments:
 * 0: Unit seeking cover <OBJECT>
 * 1: Enemy <OBJECT> or Enemy Position (AGL) <ARRAY>
 * 2: Range to find cover, default ELITE_COVER_RANGE <NUMBER>
 * 3: Sort mode <STRING>, default "ASCEND" (aday toplama sirasi): ASCEND, DESCEND, RANDOM
 * 4: Max Results <Number>, default ELITE_COVER_MAX_RESULTS, -1 for all
 * 5: Mode <STRING>, default "DEFEND": "DEFEND" | "ADVANCE" | "OVERWATCH" | "EVADE" | "SURVIVE"
 *    SURVIVE: EN YAKIN sert siper (en az 1 yukseklikte mermi durduran engel), mesafe 0.9/m, uzaklasma bonusu / yaklasma cezasi 0.5/m (tek kalan asker / temas kesme)
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
    private _evade = _mode isEqualTo "EVADE";
    private _survive = _mode isEqualTo "SURVIVE";
    private _minDist = if (_evade) then {
        ELITE_COVER_MIN_DIST max 40
    } else {
        if (_survive) then {20} else {ELITE_COVER_MIN_DIST}
    };

    // ---------------------------------------------------------------------
    // Aday objeler: sert (agac/bina/HIDE) + yumusak (cali/kucuk agac) + araclar
    // ---------------------------------------------------------------------
    // Mesafeye gore SIRALI; sert / yumusak AYRI kesilir (yogun bitkide en yakin 40 obje hep cali olup
    // arkadaki sert siperi (agac / bina / kaya / duvar) disarida birakmasin)
    private _sert = nearestTerrainObjects [_unit, ["TREE", "HIDE", "BUILDING", "ROCK", "WALL"], _range, true, true];
    private _yumusak = nearestTerrainObjects [_unit, ["BUSH", "SMALL TREE"], _range, true, true];
    _sert = _sert select [0, 30];
    _yumusak = _yumusak select [0, 10];
    private _terrainObjects = _sert + _yumusak;
    private _uz = (getPosASL _unit) select 2;

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
    if ((count _allObjs) > 40) then {
        _allObjs = _allObjs select [0, 40];
    };

    // 8 sn'den eski rezervleri at
    private _claims = (_group getVariable [QGVAR(coverClaims), []]) select {(_simdi - (_x select 1)) < 8};

    // Gizli mi (GORUS): obje VEYA arazi hatti kesiyor
    private _gizli = {
        params ["_bas", "_son", "_u"];
        (lineIntersects [_bas, _son, _u]) || {terrainIntersectASL [_bas, _son]}
    };

    // Korunmus mu (MERMI): FIRE geometrisi hatti kesiyor (cali / yaprak mermi durdurmaz)
    private _korunmus = {
        params ["_bas", "_son", "_u"];
        (count (lineIntersectsSurfaces [_bas, _son, _u, objNull, true, 1, "FIRE", "NONE"])) > 0
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
        if (_degerlendirilen >= 60) exitWith {};

        private _obj = _x;
        private _yumusakMi = _obj in _yumusak;
        private _buildingPos = [_obj, ELITE_COVER_BUILDING_POS] call CBA_fnc_buildingPositions;
        private _binaMi = _buildingPos isNotEqualTo [];

        if (!_binaMi) then {
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

            // Su / ust kat / cati (> 4 m yukseklik farki) aday degil: ulasilamaz
            if (
                _degerlendirilen < 60
                && {(_dangerPos distance2D _pos) > _minDist}
                && {!surfaceIsWater _pos}
                && {abs (((AGLToASL _pos) select 2) - _uz) < 4}
            ) then {
                private _posASL = AGLToASL _pos;

                // DOWN gizli degilse aday degil
                if ([_dangerPos, _posASL vectorAdd [0, 0, 0.1], _unit] call _gizli) then {
                    _degerlendirilen = _degerlendirilen + 1;

                    // KORUNMA: 3 yukseklikte FIRE geometri engel sayisi
                    private _sertSayi = 0;
                    {
                        if ([_dangerPos, _posASL vectorAdd [0, 0, _x], _unit] call _korunmus) then {
                            _sertSayi = _sertSayi + 1;
                        };
                    } forEach [0.1, 0.75, 1.45];

                    // EVADE: sadece sert siper (en az 2 yukseklikte mermi durduran engel)
                    if ((!_evade || {_sertSayi >= 2}) && {!_survive || {_sertSayi >= 1}}) then {

                        private _stances = ["DOWN"];
                        if ([_dangerPos, _posASL vectorAdd [0, 0, 0.75], _unit] call _gizli) then {
                            _stances pushBack "MIDDLE";
                            if ([_dangerPos, _posASL vectorAdd [0, 0, 1.45], _unit] call _gizli) then {
                                _stances pushBack "UP";
                            };
                        };

                        private _enemyDist = _pos distance2D _enemyPos;
                        private _skor = ((count _stances) * 8) + (_sertSayi * 14);

                        // Sadece gizleme (cali): mermi durdurmaz
                        if (_sertSayi isEqualTo 0) then {
                            _skor = _skor - 20;
                        };

                        private _enemyDir = _pos getDir _enemyPos;

                        // Omuz testi: govde genisligi (+-0.35m) — kenardan vurulmasin
                        {
                            private _sp = _pos getPos [0.35, _enemyDir + _x];
                            _sp set [2, (_pos select 2) + 0.75];
                            private _omuz = AGLToASL _sp;
                            if ([_dangerPos, _omuz, _unit] call _gizli) then {
                                _skor = _skor + 4;
                            } else {
                                _skor = _skor - 6;
                            };
                        } forEach [90, -90];

                        // Yan acilar: dusman +-25 derece kayarsa / ikinci dusman varsa hala gizli mi
                        {
                            private _yan = AGLToASL ((_pos getPos [_enemyDist, _enemyDir + _x]) vectorAdd [0, 0, 1.8]);
                            if ([_yan, _posASL vectorAdd [0, 0, 0.75], _unit] call _gizli) then {
                                _skor = _skor + 8;
                            };
                        } forEach [-25, 25];

                        // Diger bilinen dusmanlara karsi da gizli mi
                        {
                            if ([_x, _posASL vectorAdd [0, 0, 0.75], _unit] call _gizli) then {
                                _skor = _skor + 10;
                            } else {
                                _skor = _skor - 6;
                            };
                        } forEach _digerTehditler;

                        // Uzaklik maliyeti
                        _skor = _skor - ((_unit distance2D _pos) * (if (_evade) then {0.25} else {if (_survive) then {0.9} else {0.5}}));

                        // Dusmana yaklasma: ADVANCE bonus, EVADE uzaklasma bonusu, digerleri ceza
                        private _yaklasma = _unitEnemyDist - _enemyDist;
                        if (_mode isEqualTo "ADVANCE") then {
                            _skor = _skor + (((_yaklasma min 30) max -30) * 0.9);
                        } else {
                            if (_evade) then {
                                _skor = _skor + ((((-_yaklasma) min 40) max -40) * 0.9);
                            } else {
                                if (_survive) then {
                                    // en yakin siper; dusmandan uzaklasan +, yaklasan - (0.5/m)
                                    _skor = _skor + ((((-_yaklasma) min 30) max -30) * 0.5);
                                } else {
                                    if (_yaklasma > 0) then {
                                        _skor = _skor - (_yaklasma * 0.8);
                                    };
                                };
                            };
                        };

                        // EVADE: bina en iyi (tank gorus hatti kirilir)
                        if (_evade && {_binaMi}) then {
                            _skor = _skor + 12;
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

                        // Yumusak obje (cali) mermi durdurmaz
                        if (_yumusakMi) then {
                            _skor = _skor - 6;
                        };

                        // Baska askerin rezervi / dost kalabaligi
                        if ((_claims findIf {
                            (((_x select 0) distance2D _pos) < 6) && {(_x select 2) isNotEqualTo _unit}
                        }) > -1) then {
                            _skor = _skor - 20;
                        };
                        _skor = _skor - ((count ((_pos nearEntities ["CAManBase", 5]) - [_unit])) * 10);

                        _adaylar pushBack [_skor, _pos, _stances select ((count _stances) - 1)];
                    };
                };
            };
        } forEach _buildingPos;
    } forEach _allObjs;

    // ---------------------------------------------------------------------
    // En iyiler (skora gore) + rezerv
    // ---------------------------------------------------------------------
    if (_adaylar isNotEqualTo []) then {
        _adaylar sort false;

        // -----------------------------------------------------------------
        // FAZ 2 — SIPER VE ATIS POZISYONU ANALIZI (v2, VBS4 "cover and firing position analysis" fikri)
        //   Yalniz ilk 6 aday (pahali isinlar az): tehdit YELPAZESI + ATIS EDEBILME
        //   + yelpaze: dusman +-10/20/40 derece kayarsa kac isin hala gizli  (0..6) -> +2 / isin   (sektor maruziyeti)
        //   + atis  : DEFEND / OVERWATCH / ADVANCE'de siper HEDEFI de gorebilmeli:
        //       - ayakta gorus varsa (UP acik)            : zaten atis edebilir                      +8
        //       - ayakta gizli ama yandan 0.6 m eğilip hedef gorulur (lean)                          +10
        //       - hicbir noktadan hedef gorulmuyor (siper kendi atisimizi da kesiyor)               -15
        //   Kapatma: lambs_main_coverV2 = false
        // -----------------------------------------------------------------
        if (missionNamespace getVariable ["lambs_main_coverV2", true]) then {
            private _k = 6 min (count _adaylar);
            private _bas = _adaylar select [0, _k];
            private _ilkPos = (_bas select 0) select 1;
            private _atisModu = _mode in ["DEFEND", "OVERWATCH", "ADVANCE"];
            {
                private _a = _x;
                private _pos = _a select 1;
                private _posASL = AGLToASL _pos;
                private _eDir = _pos getDir _enemyPos;
                private _eDist = _pos distance2D _enemyPos;

                // yelpaze
                private _gizliSay = 0;
                {
                    private _yan = AGLToASL ((_pos getPos [_eDist, _eDir + _x]) vectorAdd [0, 0, 1.8]);
                    if ([_yan, _posASL vectorAdd [0, 0, 0.75], _unit] call _gizli) then { _gizliSay = _gizliSay + 1; };
                } forEach [-40, -20, -10, 10, 20, 40];
                _a set [0, (_a select 0) + (_gizliSay * 2)];
                // UFUK CIZGISI (v8.12): siper gokyuzu / ufuk arkasinda ise (egim tepesi, sirt) silueti en gorunur olur -> -10 (yatik / comelmis yuksekligiyle)
                if (_eDist >= 60) then {
                    private _hh = [1.7, 1.0, 0.4] select ((["UP", "MIDDLE", "DOWN"] find (_a select 2)) max 0);
                    private _bsh = AGLToASL (_pos vectorAdd [0, 0, _hh]);
                    private _eg = AGLToASL (_enemyPos vectorAdd [0, 0, 1.6]);
                    private _d2 = vectorNormalized (_bsh vectorDiff _eg);
                    private _s2 = _bsh vectorAdd (_d2 vectorMultiply 300);
                    if (!(terrainIntersectASL [_bsh, _s2]) && {!(lineIntersects [_bsh, _s2, objNull, objNull])}) then {
                        _a set [0, (_a select 0) - 10];
                    };
                };

                // atis edebilme
                if (_atisModu) then {
                    if ((_a select 2) isNotEqualTo "UP") then {
                        _a set [0, (_a select 0) + 8];                    // ayakta acik = hedefi gorur
                    } else {
                        private _lean = false;
                        {
                            private _pp = _pos getPos [0.6, _eDir + _x];
                            _pp set [2, (_pos select 2) + 1.45];
                            if (!([_dangerPos, AGLToASL _pp, _unit] call _gizli)) exitWith { _lean = true; };
                        } forEach [90, -90];
                        _a set [0, (_a select 0) + ([-15, 10] select _lean)];
                    };
                };
            } forEach _bas;
            _bas sort false;
            _adaylar = _bas + (_adaylar select [_k, (count _adaylar) - _k]);

            // tani: ilk 40 cagri (RPT: [SIPER-ANALIZ])
            if (isNil "lambs_main_siperLogN") then { lambs_main_siperLogN = 0; };
            if (lambs_main_siperLogN < 40) then {
                lambs_main_siperLogN = lambs_main_siperLogN + 1;
                diag_log format ["[SIPER-ANALIZ] %1 | mod:%2 | aday:%3 | faz2:%4 | ilk secim %5 (%6 m)", name _unit, _mode, count _adaylar, _k, if (((_adaylar select 0) select 1) isEqualTo _ilkPos) then {"ayni"} else {"DEGISTI"}, round (_unit distance2D ((_adaylar select 0) select 1))];
            };
        };
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
