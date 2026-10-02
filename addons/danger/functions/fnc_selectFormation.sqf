#include "script_component.hpp"
/*
 * Author: Cinar (ELITE fork)
 * Arazi tipine ve duruma gore en uygun formasyonu secer.
 * LOS kontrolu kaldirildi (ceset/bodybag VIEW filtresini kirletiyordu).
 *
 * Arguments:
 * 0: lider birim <OBJECT> veya grup <GROUP>
 * 1: hedef <OBJECT> veya pozisyon <ARRAY>
 * 2: baglam <STRING> - "BOUNDING" | "ASSAULT" | "TRAVEL" | "DEFENSE"
 *
 * Return Value:
 * Formasyon ismi <STRING>
 *
 * Public: No
*/

params [
    ["_unit", objNull, [objNull, grpNull]],
    ["_target", [0, 0, 0], [objNull, []]],
    ["_context", "BOUNDING", [""]]
];

// ---------------------------------------------------------------------------
// Grup normalize
// ---------------------------------------------------------------------------
if (_unit isEqualType grpNull) then {_unit = leader _unit;};
if (isNull _unit) exitWith {"WEDGE"};

// ---------------------------------------------------------------------------
// PEEL KONTROLU — Peel aktifken FILE'dan baska formasyon secme
// ---------------------------------------------------------------------------
private _grpKontrol = group _unit;
if (!isNull _grpKontrol && {_grpKontrol getVariable [QGVAR(isPeeling), false]}) exitWith {
    if (EGVAR(main,debug_functions)) then {
        diag_log format ["[FORMASYON] %1 | PEEL AKTIF | FILE kilidi", name _unit];
    };
    "FILE"
};
// ---------------------------------------------------------------------------
// RETREAT KONTROLU — Geri cekilme sirasinda FILE'dan baska formasyon secme
// (yukaridaki ikinci/cift PEEL blogu kaldirildi)
// ---------------------------------------------------------------------------
if (!isNull _grpKontrol && {_grpKontrol getVariable [QGVAR(isRetreating), false]}) exitWith {
    "FILE"
};
// ---------------------------------------------------------------------------
// Hedef pozisyon (obje veya dizi olabilir)
// ---------------------------------------------------------------------------
private _targetPos = [0, 0, 0];
private _validTarget = true;

if (_target isEqualType objNull) then {
    if (isNull _target) then {
        _validTarget = false;
    } else {
        _targetPos = getPosATL _target;
    };
} else {
    if (_target isEqualType []) then {
        if (count _target < 2) then {
            _validTarget = false;
        } else {
            _targetPos = _target;
        };
    } else {
        _validTarget = false;
    };
};

// TRAVEL / DEFENSE hedefsiz da gecerli; sadece hedef gerektiren baglamlar WEDGE'e duser
if (!_validTarget && {_context in ["BOUNDING", "ASSAULT"]}) exitWith {"WEDGE"};

// ---------------------------------------------------------------------------
// ARAZI TESPIT POZISYONU — Lider degil, GRUP MERKEZI
// Bounding'de lider arkada kalabilir (suppress), bound kanadi one gider.
// Grup ortalama pozisyonu gercek "neredeyiz" sorusuna cevap verir.
// ---------------------------------------------------------------------------
private _grup = if (_unit isEqualType grpNull) then {_unit} else {group _unit};
private _birimler = (units _grup) select {alive _x};

private _leaderPos = [0, 0, 0];
if (_birimler isNotEqualTo []) then {
    private _toplam = [0, 0, 0];
    {
        _toplam = _toplam vectorAdd (getPosATL _x);
    } forEach _birimler;
    _leaderPos = _toplam vectorMultiply (1 / (count _birimler));
} else {
    _leaderPos = getPosATL _unit;
};

// ===========================================================================
// ARAZI TESPITI (LOS KONTROLU YOK)
// ===========================================================================


// ===========================================================================
// ARAZI TESPITI — GENIS ALAN, DAR ESIK
// - BUSH'lar CIKARILDI (gorunmez, yaniltiyordu)
// - Yaricap 2x BUYUTULDU (50→80, 30→60)
// - Oncelik sirasi: URBAN > FOREST > OPEN
// - Urban esigi DUSURULDU (8→5)
// ===========================================================================

// 1) Bina yogunlugu — 80m yaricap (genis alan)
private _buildings = nearestTerrainObjects [
    _leaderPos,
    ["BUILDING", "HOUSE", "CHURCH", "FUELSTATION", "HOSPITAL"],
    80, false, true
];
private _buildingCount = count _buildings;

// 2) Agac yogunlugu — 60m yaricap, BUSH YOK
private _trees = nearestTerrainObjects [
    _leaderPos,
    ["TREE", "SMALL TREE"],   // BUSH CIKARILDI
    60, false, true
];
private _treeCount = count _trees;

// 3) Arazi tipi — ONCELIK SIRASI onemli
private _isUrban  = _buildingCount >= 5;    // 8 → 5 (koyu de yakalar)
private _isForest = !_isUrban && {_treeCount >= 20};   // 12 → 20, sadece urban degilse
private _isOpen   = !_isUrban && {!_isForest};

// Debug icin: yeni esikleri logla
if (EGVAR(main,debug_functions)) then {
    diag_log format [
        "[ARAZI-TARAMA] konum:%1 | bina:%2 (esik:5) | agac:%3 (esik:20) | urban:%4 forest:%5",
        _leaderPos, _buildingCount, _treeCount, _isUrban, _isForest
    ];
};

// 4) Yol yakinligi
private _roads = _leaderPos nearRoads 20;
private _onRoad = _roads isNotEqualTo [];

// ===========================================================================
// FORMASYON SECIMI
// ===========================================================================

private _formation = "WEDGE";
private _reason = "default";

switch (_context) do {
    // BOUNDING
    case "BOUNDING": {
        // 2026-10-01: DIAMOND/FILE sikisik ve LAMBS brainEngage bu formasyonlarda bastirmayi kapatiyor
        if (_isUrban) then {
            _formation = "STAG COLUMN";
            _reason = "meskun mahal - sokak/bina kenari sasirtmali kolon (doktrin)";
        } else {
            if (_isForest) then {
                _formation = "VEE";
                _reason = "orman - esnek V";
            } else {
                _formation = "LINE";
                _reason = "acik arazi - genis cephe";
            };
        };
    };

    // COMBAT — KOMUTAN ZEKASI: durum analizine (mesafe / dusman gucu / MG / zirh / kayip / arazi) gore formasyon
    case "COMBAT": {
        private _sit = _grup getVariable [QGVAR(cmdSit), []];
        private _closest = 9999;
        private _eCnt = 0;
        private _eMg = 0;
        private _arm = 0;
        private _ratio = 1;
        private _loss = 0;
        if (_sit isNotEqualTo [] && {(time - (_sit select 0)) < 25}) then {
            _closest = _sit select 1;
            _eCnt = _sit select 2;
            _eMg = _sit select 3;
            _arm = _sit select 4;
            _ratio = _sit select 5;
            _loss = _sit select 6;
        } else {
            if (_validTarget && {_targetPos isNotEqualTo [0,0,0]}) then { _closest = _leaderPos distance2D _targetPos; };
        };

        if (_arm > 0 && {_closest < 300}) then {
            _formation = "VEE";
            _reason = "zirh - dagilmis V (tek patlama hepsini almasin)";
        } else {
            if (_loss >= 0.4 || {_ratio >= 1.6}) then {
                _formation = "WEDGE";
                _reason = "kayip / ustun dusman - toplu, karsilikli destek";
            } else {
                if (_eMg >= 1 && {_closest > 60}) then {
                    _formation = ["VEE", "STAG COLUMN"] select _isUrban;
                    _reason = "dusman MG - dagilmis (MG tek seritle kirmasin)";
                } else {
                    if (_closest < 50) then {
                        _formation = ["LINE", "STAG COLUMN"] select _isUrban;
                        _reason = "yakin temas - maksimum ates / bina kenari";
                    } else {
                        if (_closest < 150) then {
                            _formation = if (_isUrban) then {"STAG COLUMN"} else {if (_isForest) then {"VEE"} else {"LINE"}};
                            _reason = "orta mesafe temas - arazi + cephe";
                        } else {
                            _formation = if (_isUrban) then {"STAG COLUMN"} else {if (_isForest) then {"VEE"} else {"WEDGE"}};
                            _reason = "uzak temas - esnek intikal";
                        };
                    };
                };
            };
        };

        // Formasyon yonu: dusmana
        if (_sit isNotEqualTo [] && {(_sit select 7) isEqualType []} && {(_sit select 7) isNotEqualTo [0,0,0]}) then {
            _grup setFormDir (_leaderPos getDir (_sit select 7));
        } else {
            if (_validTarget && {_targetPos isNotEqualTo [0,0,0]}) then { _grup setFormDir (_leaderPos getDir _targetPos); };
        };
        _reason = format ["%1 | d:%2 m e:%3 MG:%4 zirh:%5 oran:%6 kayip:%7", _reason, round _closest, _eCnt, _eMg, _arm, _ratio toFixed 2, round (_loss * 100)];
    };

    // ASSAULT
    case "ASSAULT": {
        if (_isUrban) then {
            _formation = "STAG COLUMN";
            _reason = "CQB - sasirtmali kolon, bina kenari (doktrin)";
        } else {
            _formation = "LINE";
            _reason = "acik arazi - ates gucu";
        };
    };

    // TRAVEL
    case "TRAVEL": {
        if (_onRoad) then {
            _formation = "COLUMN";
            _reason = "yol - konvoy duzeni";
        } else {
            if (_isForest) then {
                _formation = "STAG COLUMN";
                _reason = "orman - konvoy";
            } else {
                _formation = "WEDGE";
                _reason = "acik arazi intikal";
            };
        };
    };

    // DEFENSE
    case "DEFENSE": {
        if (_isUrban) then {
            _formation = "WEDGE";
            _reason = "meskun savunma - esnek";
        } else {
            _formation = "VEE";
            _reason = "acik savunma - agir silah merkezde";
        };
    };

    default {
        _formation = "WEDGE";
        _reason = "bilinmeyen baglam";
    };
};

// ===========================================================================
// DEBUG
// ===========================================================================
if (EGVAR(main,debug_functions)) then {
    ["[FORMASYON] %1 | baglam:%2 | secim:%3 | sebep:%4 | bina:%5 agac:%6 yol:%7",
        name _unit, _context, _formation, _reason,
        _buildingCount, _treeCount,
        ["yok", "var"] select _onRoad
    ] call EFUNC(main,debugLog);
};

// HISTEREZIS: formasyon degisimi en az 60 sn arayla (VEE <-> LINE <-> WEDGE dongusunu onler; agac / bina sayimi yuruyuste oynar)
private _histGrp = group _unit;
if (!isNull _histGrp) then {
    private _sonF = _histGrp getVariable [QGVAR(selFormSon), ""];
    private _sonT = _histGrp getVariable [QGVAR(selFormT), -999];
    if (_sonF isNotEqualTo "" && {_sonF isNotEqualTo _formation} && {time < (_sonT + ([60, 25] select (_context isEqualTo "COMBAT")))}) then {
        _formation = _sonF;
    } else {
        if (_sonF isNotEqualTo _formation) then {
            _histGrp setVariable [QGVAR(selFormSon), _formation];
            _histGrp setVariable [QGVAR(selFormT), time];
        };
    };
};

_formation
