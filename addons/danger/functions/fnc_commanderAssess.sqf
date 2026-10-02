#include "script_component.hpp"
/*
 * Author: Cinar (ELITE fork)
 * Komutan Beyni v2 — rol agirlikli guc orani + zirh / MG / baski farkindaligi
 * + 6 faktorlu tehdit skoru (artik karara DAHIL) + NATO karar tablosu
 *
 * v2 degisiklikleri:
 *   - Dusman sayisi: grubun BILDIGI dusmanlar (knowsAbout) + 70m icindekiler
 *     (eski: 300m icindeki herkes = hile bilgisi)
 *   - Guc orani rol agirlikli: MG 2.0, nisanci 1.5, AT 1.4, tufekli 1.0, saglikci 0.6
 *   - Zirh farkindaligi: dusman Tank/APC varsa kendi AT sayisina gore karar
 *   - Dusman MG sayisi: 2+ MG acik arazide cepheden saldirmaz (FLANK)
 *   - Baski (getSuppression) ortalamasi: ezilen grup hareket etmez (HOLD)
 *   - Bina savunma avantaji
 *   - Tehdit skoru karar esiği olarak kullanilir
 *
 * Arguments:
 * 0: group <GROUP> or group leader <OBJECT>
 * 1: known enemy target <OBJECT> or position <ARRAY>
 *
 * Return Value:
 * Decision string <STRING>:
 *   "WITHDRAW" | "HOLD" | "DELAY" | "SUPPRESS_ASSAULT"
 *   | "FLANK" | "ASSAULT" | "BOUNDING" | "PEEL" | "EVADE_ARMOR" | "AT_ENGAGE"
 *
 * Debug HUD legend (systemChat):
 *   [CMD] <leader> [<own>v<enemy> P:<oran>] Cnt:Fir:Cas:Amm:Pos:Sup | THR:<score> | <decision> (<reason>)
 *
 * Example:
 * [bob, angryJoe] call lambs_danger_fnc_commanderAssess;
 *
 * Public: No
*/

params [
    ["_group", grpNull, [grpNull, objNull]],
    ["_target", objNull, [objNull, []]]
];

// ---------------------------------------------------------------------------
// Normalize ONCE — spam korumasi gruba yazmali, unite degil
// ---------------------------------------------------------------------------
if (_group isEqualType objNull) then {_group = group _group;};
if (isNull _group) exitWith {"BOUNDING"};
if ((units _group) isEqualTo []) exitWith {"BOUNDING"};

private _unit = leader _group;
// DOKTRIN PROFILI (fraksiyona gore ordu degerleri; GENEL = eski sabitler)
private _dkAssault = [_group, "assaultM", 45] call FUNC(dk);
private _dkCekilKayip = [_group, "cekilKayip", 0.4] call FUNC(dk);
private _dkPeelOran = [_group, "peelOran", 1.6] call FUNC(dk);
private _dkPeelKayip = [_group, "peelKayip", 0.1] call FUNC(dk);
private _dkKucuk = [_group, "kucukEkip", 3] call FUNC(dk);
private _dkYakin = [_group, "yakinM", 60] call FUNC(dk);
if (isNull _unit) exitWith {"BOUNDING"};

// Fonksiyon kayitli degilse (XEH_PREP eksik) hata vermeden her asker TUFEKLI sayilir
private _rolFn = missionNamespace getVariable ["lambs_danger_fnc_getUnitRole", {"RIFLE"}];
// AT: LAMBS bayraklariyla GERCEK anti-tank (AA / flare / AP launcher sayilmaz)
private _atFn = missionNamespace getVariable ["lambs_danger_fnc_isATUnit", {params ["_u"]; (secondaryWeapon _u) isNotEqualTo "" && {(_u ammo (secondaryWeapon _u)) > 0}}];

// ---------------------------------------------------------------------------
// HEDEF NORMALIZE
// ---------------------------------------------------------------------------
private _targetPos = _target call CBA_fnc_getPos;
if ((_targetPos select 2) > 6) then {_targetPos set [2, 0.5];};

// ---------------------------------------------------------------------------
// SPAM KORUMASI — ayni grup icin 3 sn icinde 2. kez karar verme
// ---------------------------------------------------------------------------
private _sonZaman = _group getVariable [QGVAR(cmdLastEval), 0];
if (time - _sonZaman < 3) exitWith {
    _group getVariable [QGVAR(cmdLastDecision), "BOUNDING"]
};
_group setVariable [QGVAR(cmdLastEval), time];

// ---------------------------------------------------------------------------
// Temel veriler
// ---------------------------------------------------------------------------
private _aliveUnits = (units _group) select {alive _x};
private _ownCount = count _aliveUnits;
if (_ownCount <= 0) exitWith {"WITHDRAW"};

private _mySide = side _unit;
private _distance = _unit distance2D _targetPos;

// ---------------------------------------------------------------------------
// DUSMAN TESPITI — grubun BILDIGI (knowsAbout) + 70m icindeki dusmanlar
// ---------------------------------------------------------------------------
private _nearAll = _unit nearEntities ["CAManBase", 350];
private _enemies = _nearAll select {
    alive _x
    && {((side _x) != civilian)}
    && {(_mySide getFriend (side _x)) < 0.6}
    && {(lifeState _x) isNotEqualTo "INCAPACITATED"}
    // 70 m icindeki dusman da ancak az da olsa BILINIYORSA sayilir (eskiden duvar arkasini / gormedigi dusmani da sayiyordu = hile)
    && {((_group knowsAbout _x) >= 1.2) || {((_x distance2D _unit) < 70) && {(_group knowsAbout _x) >= 0.4}}}
};

// Hedef objeyse ve listede yoksa ekle
if (_enemies isEqualTo [] && {_target isEqualType objNull} && {!isNull _target} && {alive _target} && {_target isKindOf "CAManBase"}) then {
    _enemies = [_target];
};

private _enemyCount = count _enemies;

// En yakin dusman mesafesi (hedef pozisyondan daha gercekci)
private _closest = _distance;
{
    private _d = _unit distance2D _x;
    if (_d < _closest) then {_closest = _d;};
} forEach _enemies;

// ---------------------------------------------------------------------------
// KENDI GUCU — rol agirlikli
// ---------------------------------------------------------------------------
private _ownPower = 0;
private _ownMg = 0;
private _ownAT = 0;
{
    private _r = [_x] call _rolFn;
    _ownPower = _ownPower + (switch (_r) do {
        case "MG":       {2.0};
        case "MARKSMAN": {1.5};
        case "AT":       {1.4};
        case "MEDIC":    {0.6};
        default          {1.0};
    });
    if (_r isEqualTo "MG") then {_ownMg = _ownMg + 1;};
    if ([_x] call _atFn) then {_ownAT = _ownAT + 1;};
} forEach _aliveUnits;

// ---------------------------------------------------------------------------
// DUSMAN GUCU — ilk 12 dusmanin rolu, fazlasi orantilanir
// ---------------------------------------------------------------------------
private _enemyPower = 0;
private _enemyMg = 0;
private _enemyAT = 0;
private _enemySample = if (_enemyCount > 12) then {_enemies select [0, 12]} else {_enemies};
{
    private _r = [_x] call _rolFn;
    _enemyPower = _enemyPower + (switch (_r) do {
        case "MG":       {2.0};
        case "MARKSMAN": {1.5};
        case "AT":       {1.4};
        case "MEDIC":    {0.6};
        default          {1.0};
    });
    if (_r isEqualTo "MG") then {_enemyMg = _enemyMg + 1;};
    if ([_x] call _atFn) then {_enemyAT = _enemyAT + 1;};
} forEach _enemySample;
if (_enemyCount > 12) then {
    _enemyPower = _enemyPower * (_enemyCount / 12);
};

// ---------------------------------------------------------------------------
// ZIRH — 450m icinde murettebatli dusman Tank / APC
// ---------------------------------------------------------------------------
private _armor = (_unit nearEntities [["Tank", "Wheeled_APC_F"], 450]) select {
    alive _x
    && {(_mySide getFriend (side _x)) < 0.6}
    && {((side _x) != civilian)}
    && {((_group knowsAbout _x) >= 1.2) || {(_x distance2D _unit) < 150}}
};
private _armorCount = count _armor;
private _armorDist = 9999;
{
    private _d = _unit distance2D _x;
    if (_d < _armorDist) then {_armorDist = _d;};
} forEach _armor;

// AT varsa zirh 3, yoksa 6 guc puani (AT'siz piyade zirha karsi cok zayif)
_enemyPower = _enemyPower + (_armorCount * (if (_ownAT > 0) then {3} else {6}));

private _pwrRatio = _enemyPower / (_ownPower max 0.5);

// ---------------------------------------------------------------------------
// FAKTOR 1 — GUC ORANI  (agirlik %22)
// ---------------------------------------------------------------------------
private _factorCount = linearConversion [0.5, 2.0, _pwrRatio, 0.2, 1.0, true];

// ---------------------------------------------------------------------------
// FAKTOR 2 — DUSMAN ATES GUCU  (agirlik %18)
// MG (kapasiteyle tespit) / launcher / zirh
// ---------------------------------------------------------------------------
private _firepower = _enemyMg + (_enemyAT * 1.5) + (_armorCount * 2);
private _hasHeavyWeapon = (_enemyMg + _enemyAT + _armorCount) > 0;
private _factorFirepower = linearConversion [0, 3, _firepower, 0.2, 1.0, true];

// ---------------------------------------------------------------------------
// FAKTOR 3 — KENDI KAYIP  (agirlik %18)
// ---------------------------------------------------------------------------
private _initialCount = _group getVariable [QGVAR(cmdInitialCount), -1];
if (isNil "_initialCount") then { _initialCount = -1; };
if !(_initialCount isEqualType 0) then { _initialCount = -1; };

// Baslangic sayisi taban cizgisi: grup buyudu (takviye / birlesme) ya da temas bitti ve uzun suredir
// degerlendirme yok -> yeni taban (eski kayip sonsuza kadar WITHDRAW uretmesin)
if (_initialCount >= 0 && {(_ownCount > _initialCount) || {((time - _sonZaman) > 300) && {time > (_group getVariable [QGVAR(contact), 0])}}}) then {
    _initialCount = _ownCount;
    _group setVariable [QGVAR(cmdInitialCount), _initialCount];
};

if (_initialCount < 0) then {
    _initialCount = _ownCount;
    _group setVariable [QGVAR(cmdInitialCount), _initialCount];
};

// ZEUS / SILINEN / GRUPTAN AYRILAN birimler KAYIP SAYILMAZ (sadece OLEN birim kayiptir): taban sayiyi dusur
private _bilinenEski = _group getVariable [QGVAR(cmdKnown), []];
if !(_bilinenEski isEqualType []) then { _bilinenEski = []; };
private _silinen = 0;
{
    if (!(_x in _aliveUnits) && {isNull _x || {alive _x}}) then { _silinen = _silinen + 1; };
} forEach _bilinenEski;
if (_silinen > 0) then {
    _initialCount = (_initialCount - _silinen) max _ownCount;
    _group setVariable [QGVAR(cmdInitialCount), _initialCount];
    diag_log format ["[KAYIP-DUZELT] %1 | %2 birim silindi/ayrildi (olu degil): taban %3", groupId _group, _silinen, _initialCount];
};
_group setVariable [QGVAR(cmdKnown), +_aliveUnits];

private _lossRatio = 0;
if (_initialCount > 0) then {
    _lossRatio = (_initialCount - _ownCount) / _initialCount;
};
private _factorCasualty = linearConversion [0, 0.5, _lossRatio, 0, 1, true];

// ---------------------------------------------------------------------------
// FAKTOR 4 — KENDI MUHIMMAT  (agirlik %12)
// magazinesAmmo: TUM sarjorler (>1: el bombasi/roket/fume sayilmaz)
// ---------------------------------------------------------------------------
private _toplamMermi = 0;
{
    private _asker = _x;
    {
        _x params ["_magClass", "_ammoCount"];
        if (_ammoCount > 1) then {
            _toplamMermi = _toplamMermi + _ammoCount;
        };
    } forEach (magazinesAmmo _asker);
} forEach _aliveUnits;

private _mermiPerKisi = _toplamMermi / (_ownCount max 1);

private _factorAmmo = switch (true) do {
    case (_mermiPerKisi < 10):  { 1.00 };
    case (_mermiPerKisi < 30):  { 0.85 };
    case (_mermiPerKisi < 60):  { 0.60 };
    case (_mermiPerKisi < 90):  { 0.40 };
    default                     { 0.20 };
};

// 0.0 = bitti, 1.0 = dolu
private _ammoOran = switch (true) do {
    case (_mermiPerKisi < 10):  { 0.05 };
    case (_mermiPerKisi < 30):  { 0.20 };
    case (_mermiPerKisi < 60):  { 0.50 };
    case (_mermiPerKisi < 90):  { 0.75 };
    default                     { 1.00 };
};

// ---------------------------------------------------------------------------
// FAKTOR 5 — POZISYON  (agirlik %15)
// ---------------------------------------------------------------------------
private _leaderPos = getPosATL _unit;
private _buildings = nearestTerrainObjects [
    _leaderPos,
    ["BUILDING", "HOUSE", "CHURCH", "FUELSTATION", "HOSPITAL"],
    50, false, true
];
private _trees = nearestTerrainObjects [
    _leaderPos, ["TREE", "SMALL TREE", "BUSH"], 30, false, true
];
private _isUrban  = (count _buildings) >= 8;
private _isForest = (count _trees) >= 12 && {!_isUrban};
private _isOpen   = !_isUrban && {!_isForest};
private _inBuilding = (insideBuilding _unit) > 0.5;

private _factorPosition = if (_isUrban) then {0.2} else {
    if (_isForest) then {0.5} else {0.8}
};

// ---------------------------------------------------------------------------
// FAKTOR 6 — BASKI  (agirlik %15)
// Grubun ortalama getSuppression degeri (0..1)
// ---------------------------------------------------------------------------
private _suppAvg = 0;
{ _suppAvg = _suppAvg + (getSuppression _x); } forEach _aliveUnits;
_suppAvg = _suppAvg / _ownCount;
private _factorSupp = linearConversion [0, 0.8, _suppAvg, 0, 1, true];

// ---------------------------------------------------------------------------
// AGIRLIKLI TEHDIT SKORU — artik karara dahil (DELAY esigi)
// ---------------------------------------------------------------------------
private _threatScore =
    (_factorCount     * 0.22) +
    (_factorFirepower * 0.18) +
    (_factorCasualty  * 0.18) +
    (_factorAmmo      * 0.12) +
    (_factorPosition  * 0.15) +
    (_factorSupp      * 0.15);

// ---------------------------------------------------------------------------
// KONTROL: Dusman binada mi?
// ---------------------------------------------------------------------------
private _enemyInBuilding = false;
{
    if ((_x distance2D _targetPos) < 30) then {
        private _b = nearestTerrainObjects [getPosATL _x, ["BUILDING", "HOUSE"], 5, false, true];
        if ((count _b) > 0) exitWith { _enemyInBuilding = true; };
    };
} forEach _enemies;

// ---------------------------------------------------------------------------
// KARAR TABLOSU — oncelik sirali (en tepeden asagi)
// call {} + exitWith: duz (ic ice `if then` YOK) — ic ice exitWith sadece
// ic blogu bitirir, call'u degil.
// ---------------------------------------------------------------------------
private _result = call {

    // =======================================================================
    // 0) ZIRH + AT YOK -> KACIS (en yuksek oncelik): AT'siz piyade tank/APC'ye karsi
    //    acikta savasmaz; SERT siper + gorus hatti kirma (tacticsEvadeArmor)
    // =======================================================================
    if (_armorCount > 0 && {_ownAT <= 0}) exitWith {
        ["EVADE_ARMOR", format ["zirh %1m, AT yok - sert siperden kac", round _armorDist]]
    };

    // =======================================================================
    // 1) CEPHANE — doktrin: mermisi olmayan asker cekilir
    // =======================================================================
    if (_ammoOran <= 0.1) exitWith {
        ["WITHDRAW", format ["cephane bitti (mermi/kisi: %1)", round _mermiPerKisi]]
    };
    if (_ammoOran <= 0.25 && {_closest > 40}) exitWith {
        ["HOLD", format ["cephane kritik (mermi/kisi: %1)", round _mermiPerKisi]]
    };

    // =======================================================================
    // 1b) PUSH — sayica / gucce USTUNUZ, kayip agir ama yeterli kisi var -> CEKILME, BASKI + HUCUM
    //     "cok az degilsek": >= 4 kisi, kayip < %80, cephane yeterli (yukarida), zirh yok.
    //     (WITHDRAW / PEEL kurallarindan ONCE: ustunken kayip verince kacmak yerine bitir.)
    // =======================================================================
    // cekilme sonrasi temas kopunca gorunen dusman sayisi DUSER (6v10 -> 6v4): "ustunuz" yanilgisi -> son cekilme sebebi olan sayi 180 sn hatirlanir
    private _cekilDusman = if ((time - (_group getVariable [QGVAR(cmdCekilZaman), -999])) < 180) then {_group getVariable [QGVAR(cmdCekilDusman), 0]} else {0};
    if (_enemyCount > 0
        && {_ownCount >= 4}
        && {_ownCount > (_enemyCount max _cekilDusman)}
        && {_pwrRatio <= 1.0}
        && {_lossRatio >= 0.15}
        && {_lossRatio < 0.8}
        && {_armorCount isEqualTo 0}) exitWith {
        [
            ["SUPPRESS_ASSAULT", "ASSAULT"] select (_closest < 120),
            format ["PUSH: ustun guc (%1v%2, oran %3) kayip %4%% - cekilme, bastir + hucum", _ownCount, _enemyCount, _pwrRatio toFixed 2, round (_lossRatio * 100)]
        ]
    };

    // =======================================================================
    // 2) AGIR KAYIP / BASKIN GUC
    // =======================================================================
    if (_lossRatio >= _dkCekilKayip) exitWith {
        ["WITHDRAW", format ["agir kayip %1%%", round (_lossRatio * 100)]]
    };
    if (_pwrRatio >= 2.5 && {_lossRatio >= 0.2}) exitWith {
        ["WITHDRAW", format ["%1x guc dezavantaji + kayip %2%%", _pwrRatio toFixed 1, round (_lossRatio * 100)]]
    };

    // =======================================================================
    // 3) ZIRH TEHDIDI
    // =======================================================================
    if (_armorCount > 0 && {_armorDist > 70} && {_armorDist <= 400}) exitWith {
        ["AT_ENGAGE", format ["zirh %1m, AT taarruz + piyade korumasi", round _armorDist]]
    };
    if (_armorCount > 0 && {_armorDist > 70}) exitWith {
        ["FLANK", format ["zirh %1m, uzak - kanat", round _armorDist]]
    };
    if (_armorCount > 0) exitWith {
        ["HOLD", "zirh yakin, AT siperde"]
    };

    // =======================================================================
    // 4) PEEL — 1.6x guc dezavantaji + %10 kayip + yakin temas (NATO doktrini)
    // =======================================================================
    if (_pwrRatio >= _dkPeelOran
        && {_lossRatio >= _dkPeelKayip}
        && {_closest <= 250}
        && {_closest >= 25}) exitWith {
        ["PEEL", format ["%1x guc dezavantaji + kayip %2%%", _pwrRatio toFixed 1, round (_lossRatio * 100)]]
    };
    if (_lossRatio >= 0.15 && {_lossRatio < 0.4}
        && {_closest >= 25} && {_closest <= 250}
        && {_enemyCount > 0}) exitWith {
        ["PEEL", format ["kayip %1%% temas %2m", round (_lossRatio * 100), round _closest]]
    };

    // =======================================================================
    // 5) TEHDIT SKORU + BASKI
    // =======================================================================
    if (_threatScore >= 0.62 && {_closest > 40}) exitWith {
        ["DELAY", format ["tehdit skoru yuksek (%1)", _threatScore toFixed 2]]
    };
    if (_suppAvg >= 0.6) exitWith {
        // ACIKTA (15 m'de siper / agac / bina / duvar yok) ve dusman > 60 m: HOLD = acikta durup olmek (RPT: 8 -> 3 kisi).
        // Siper al + sis (DELAY: tacticsHide + BREAK_CONTACT sisi); siper varsa HOLD kalir.
        private _acikta = (nearestTerrainObjects [getPosATL _unit, ["TREE", "ROCK", "WALL", "BUILDING", "HOUSE", "BUSH", "FENCE"], 15, false, true]) isEqualTo [];
        if (_acikta && {_closest > 60}) then {
            ["DELAY", format ["baski altinda (%1), ACIKTA: durmak yerine siper al + sis", _suppAvg toFixed 2]]
        } else {
            ["HOLD", format ["baski altinda (%1) - hareket yok", _suppAvg toFixed 2]]
        }
    };

    // =======================================================================
    // 6) SAVUNMA AVANTAJI — binadayiz, esit/ustun guc, dusman yakin ama kapida degil
    // =======================================================================
    if (_inBuilding && {_isUrban} && {_pwrRatio >= 0.9} && {_closest > 45} && {_closest < 200}) exitWith {
        ["HOLD", "binada savunma avantaji"]
    };

    // =======================================================================
    // 7) HAREKET / TAARRUZ
    // =======================================================================
    // 250-500 m: acik arazide hizli FLANK yuruyusu yerine BOUNDING (RPT: iki grup 391 m'de FLANK + LINE ile acikta yurudu, biri 60 sn'de 8 -> 1'e dustu);
    // 500 m ustu: FLANK (yaklasma / kanat)
    if (_distance > 250) exitWith {
        if (_distance <= 500) then {
            ["BOUNDING", format ["uzak mesafe %1m: ates-manevra ile yaklas (acikta duz yuruyus yok)", round _distance]]
        } else {
            ["FLANK", format ["cok uzak mesafe %1m", round _distance]]
        }
    };
    if (_enemyMg >= 2 && {_isOpen}) exitWith {
        ["FLANK", format ["%1 MG acik arazide - cepheden saldirma", _enemyMg]]
    };
    if (_enemyMg >= 1 && {_ownMg > 0} && {_closest > 60}) exitWith {
        ["SUPPRESS_ASSAULT", "MG ustunlugu: bizim MG baski + hucum"]
    };
    if (_enemyInBuilding) exitWith {
        ["SUPPRESS_ASSAULT", "dusman binada"]
    };
    if (_enemyMg >= 1 || {_enemyAT >= 2}) exitWith {
        ["FLANK", "dusman MG/AT"]
    };
    // DOKTRIN: ustun olsak bile 60 m'den UZAKTA duz hucum yok (ates-manevra: BOUNDING ile yaklas); ASSAULT yalniz son 60 m
    if (_enemyCount > 0 && {_pwrRatio <= 0.67}) exitWith {
        if (_closest < _dkAssault) then {
            ["ASSAULT", format ["biz ustun (guc orani %1), mesafe %2m", _pwrRatio toFixed 2, round _closest]]
        } else {
            ["BOUNDING", format ["biz ustun (guc orani %1), mesafe %2m: ates-manevra ile yaklas", _pwrRatio toFixed 2, round _closest]]
        }
    };
    if (_closest < _dkAssault && {_pwrRatio < 1.4}) exitWith {
        ["ASSAULT", format ["yakin mesafe %1m", round _closest]]
    };
    if (_pwrRatio >= 1.4) exitWith {
        ["DELAY", format ["dusman ustun (guc orani %1)", _pwrRatio toFixed 2]]
    };
    ["BOUNDING", "standart"]
};

private _decision = _result select 0;
private _reason   = _result select 1;

// PUSH kararlari hafiza / koordinasyon ile alternatife CEVRILMEZ (israrla bastir + hucum)
private _push = (_reason select [0, 5]) isEqualTo "PUSH:";
// Mesafe / zirh kaynakli kararlar da hafiza-koordinasyon ile degistirilmez (sebebi bu kararin kendisi)
// KARAR ISTIKRARI: "alternatif / farkli grup" degisimi KAPALI (ayni durumda taktik surekli degisiyordu) -> _noSwap hep true
private _noSwap = true;

// ---------------------------------------------------------------------------
// TAKTIK HAFIZASI + GRUP KOORDINASYONU
// 1. Ayni grup son 30 sn icinde ayni taktigi tekrarlarsa -> alternatif
// 2. Ayni tarafta baska grup ayni taktigi kullaniyorsa -> alternatif
// WITHDRAW/HOLD/DELAY/SUPPRESS_ASSAULT/PEEL korunur (kritik kararlar)
// ---------------------------------------------------------------------------
private _sonKarar = _group getVariable [QGVAR(cmdSonKarar), ""];
private _sonKararZaman = _group getVariable [QGVAR(cmdSonKararZaman), 0];
private _tekrarMi = (_sonKarar isEqualTo _decision) && {(time - _sonKararZaman) < 30};

private _digerAyni = false;
if (!_tekrarMi && {!_noSwap} && {_decision in ["BOUNDING", "FLANK", "ASSAULT"]}) then {
    {
        if (
            _x isNotEqualTo _group
            && {side _x isEqualTo _mySide}
            && {count units _x >= 4}
            && {!isNull (leader _x)}
            && {(leader _x) distance2D _unit < 400}
        ) then {
            private _k = _x getVariable [QGVAR(cmdSonKarar), ""];
            private _z = _x getVariable [QGVAR(cmdSonKararZaman), 0];
            if ((time - _z) < 25 && {_k isEqualTo _decision}) exitWith {
                _digerAyni = true;
            };
        };
    } forEach allGroups;
};

if ((_tekrarMi || _digerAyni) && {!_noSwap} && {_decision in ["BOUNDING", "FLANK", "ASSAULT"]}) then {
    _decision = switch (_decision) do {
        case "BOUNDING": { "FLANK" };
        case "FLANK":    { "SUPPRESS_ASSAULT" };
        case "ASSAULT":  { "BOUNDING" };
        default          { _decision };
    };
    _reason = if (_tekrarMi) then {
        "hafiza: alternatif"
    } else {
        "koord: farkli grup"
    };
};

// KUCUK EKIP / YAKIN TEMAS: cekilme (koşarak kacma) ONERILMEZ — 60 m'den yakin dusmana sirt cevirmek olum; <= 3 kisi acikta kosamaz.
// Cephane bitmedikce WITHDRAW / PEEL yerine DELAY (siper al + sis + temas kes) uygulanir.
if (_decision in ["WITHDRAW", "PEEL"] && {(_closest < _dkYakin) || {_ownCount <= _dkKucuk}} && {(_reason select [0, 7]) isNotEqualTo "cephane"} && {_ownCount > 0}) then {
    _reason = format ["%1 -> DELAY (%2 kisi, dusman %3m: kosarak kacilmaz, siper al + sis)", _decision, _ownCount, round _closest];
    _decision = "DELAY";
};

// CEKILME SONRASI KILIT: cekilme biteli 90 sn dolmadan hucum ailesine GERI DONME (cekil -> hemen dusmana kos -> olum dongusu);
// guc ustunlugu (PUSH) disinda DELAY (siper al, temas kes) uygulanir
// (v8.31: PUSH da KILITLI — RPT a1852a2f: cekilme biteli 34 sn sonra 6v4 "PUSH" ile hucum, oysa cekilme sebebi 6v10'du)
if (_decision in ["BOUNDING", "FLANK", "ASSAULT", "SUPPRESS_ASSAULT"]
    && {(time - (_group getVariable [QGVAR(retreatEndTime), -999])) < 90}) then {
    _push = false;
    _decision = "DELAY";
    _reason = "cekilme sonrasi: 90 sn hucum yok, siper al";
};

// KARAR TAAHHUDU: hucum ailesi (BOUNDING / FLANK / ASSAULT / SUPPRESS_ASSAULT) arasinda karar en az 20 sn SABIT kalir;
// kritik kararlar (WITHDRAW / HOLD / DELAY / PEEL / zirh vb.) ve PUSH aninda gecer
private _aile = ["BOUNDING", "FLANK", "ASSAULT", "SUPPRESS_ASSAULT"];
private _karBas = _group getVariable [QGVAR(cmdKarBas), -999];
if (_decision isNotEqualTo _sonKarar) then {
    if (!_push && {_decision in _aile} && {_sonKarar in _aile} && {(time - _karBas) < 20}) then {
        _decision = _sonKarar;
        _reason = "taahhut: karar korunuyor";
    } else {
        _group setVariable [QGVAR(cmdKarBas), time];
    };
};

// cekilme sebebi olan dusman sayisini kaydet (PUSH yanilgisini onler)
if (_decision in ["WITHDRAW", "PEEL"] && {_enemyCount > 0}) then {
    _group setVariable [QGVAR(cmdCekilDusman), _enemyCount];
    _group setVariable [QGVAR(cmdCekilZaman), time];
};

// Karari kaydet (hafiza + koordinasyon icin)
_group setVariable [QGVAR(cmdSonKarar), _decision];
_group setVariable [QGVAR(cmdSonKararZaman), time];

// ---------------------------------------------------------------------------
// DEBUG — systemChat + diag_log
// ---------------------------------------------------------------------------
// Ayni karar tekrar ediyorsa 25 sn'de bir yaz (systemChat + RPT spami olmasin)
private _sonLogKarar = _group getVariable [QGVAR(cmdSonLogKarar), ""];
private _sonLogZaman = _group getVariable [QGVAR(cmdSonLogZaman), -999];
private _logYaz = (_decision isNotEqualTo _sonLogKarar) || {(time - _sonLogZaman) > 25};
if (_logYaz) then {
    _group setVariable [QGVAR(cmdSonLogKarar), _decision];
    _group setVariable [QGVAR(cmdSonLogZaman), time];
};
if (EGVAR(main,debug_functions) && {_logYaz}) then {
    private _msg = format [
        "[CMD] %1 [%2v%3 P:%4] Cnt:%5 Fir:%6 Cas:%7 Amm:%8 Pos:%9 Sup:%10 | THR:%11 | %12 (%13)",
        name _unit,
        _ownCount, _enemyCount, _pwrRatio toFixed 2,
        _factorCount     toFixed 2,
        _factorFirepower toFixed 2,
        _factorCasualty  toFixed 2,
        _factorAmmo      toFixed 2,
        _factorPosition  toFixed 2,
        _factorSupp      toFixed 2,
        _threatScore     toFixed 2,
        _decision, _reason
    ];
    systemChat _msg;
    diag_log _msg;
};

// ---------------------------------------------------------------------------
// Grup degiskenleri — diger fonksiyonlar / test icin
// ---------------------------------------------------------------------------
_group setVariable [QGVAR(cmdLastThreat),   _threatScore];
_group setVariable [QGVAR(cmdLastDecision), _decision];
// Durum raporu: formasyon zekasi (selectFormation "COMBAT" / fnc_commanderFormation) bunu okur
_group setVariable [QGVAR(cmdSit), [time, _closest, _enemyCount, _enemyMg, _armorCount, _pwrRatio, _lossRatio, _targetPos]];
_group setVariable [QGVAR(cmdFactors), [
    _factorCount, _factorFirepower, _factorCasualty, _factorAmmo, _factorPosition, _factorSupp
]];

_decision
