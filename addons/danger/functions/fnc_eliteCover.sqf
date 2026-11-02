#include "script_component.hpp"
/*
 * Author: Cinar (ELITE fork)
 * ELITE COVER — RAYCAST SIPER YEDEGI (v8.365'te CANLANDIRILDI; eski surum hicbir yerden cagrilmiyordu). lambs_main_fnc_findCover siper bulamayinca (bos dizi) onun ARKASINDAN cagrilir.
 *
 * NEDEN GEREKLI: findCover yalniz HARITA nesnelerini (nearestTerrainObjects: agac / kaya / duvar / bina / cali) ve bina / "Car" siniflarini tarar. Zeus / Eden'de KONAN nesneler
 *   (kum torbasi, H-bariyer, konteyner, sandik, enkaz, tirmik, kamyon kasasi ...) bu listelerin disinda kalabilir -> findCover bos doner -> asker acikta kalir. eliteCover sinif adina BAKMAZ:
 *   askerin cevresinde halka seklinde aday noktalar yoklar ve her adayda gercek MERMI GEOMETRISI (FIRE LOD) isinlariyla "burada ne var" diye olcer.
 *
 * OZELLIKLER
 *   1) HALKA ARAMA: askerin etrafinda yon x mesafe izgarasi (6 m adimli; <10 AI iken 4 m adimli). Adayin ayni yukseklikte (+-3 m) ve suda olmayan bir nokta olmasi sart.
 *   2) GERCEK SIPER TESTI (kullanici duzeltmesi 2026-10-01 korunur): (a) adayin 4 m onunde (dusman yonunde) mermi durduran bir engel olmali (FIRE LOD; cali / yaprak SAYILMAZ),
 *      (b) dusmanin gozune giden tam hat da kapali olmali (nesne VEYA arazi). Dusmanin 5 m onundeki agac "siper" sayilmaz.
 *   3) DURUS (stance): her aday UP (1.7 m) -> MIDDLE (1.0 m) -> DOWN (0.4 m) sirasiyla denenir; engelin KORUDUGU EN YUKSEK durus doner (findCover ile ayni sozlesme). Hicbir durus korunmuyorsa aday elenir.
 *   4) PUANLAMA: 100 + yakinlik (15 / halka) + aci uyumu (0.15 / derece) + durus (UP +6, MIDDLE +3) - dusmana YAKLASMA (3 / m; siper arayan ileri kosmasin)
 *      - YIGILMA: adayin 4 m'sinde her dost -45 (en fazla 3) ve grubun 8 sn icinde rezerve ettigi noktanin 6 m'si -20 (findCover'in rezerv defteriyle ORTAK; tek bina / enkazda herkes ayni noktaya dolmasin).
 *   5) DINAMIK KALITE (performans butcesi): AI sayisi (15 sn onbellek) < 10: 16 yon x 4 halka | < 30: 8 x 3 | < 60: 8 x 2 | < 150: 4 x 2 | >= 150: 4 x 1. Sayi arttikca aday azalir (cause: sunucu yuku).
 *      ESKI GLOBAL "THROTTLE" KALDIRILDI: tum askerler ayni zaman damgasini paylastigi icin bir asker cagirinca digerleri ayni 20-100 ms icinde [] aliyordu (aclik); butceyi cagiran taraflar zaten tutuyor.
 *   6) _forceMove = true ise asker dogrudan siper noktasina gonderilir (doMove + MIDDLE).
 *
 * KAPSAM DISI (bilincli): EVADE kipi (findCover zirhtan >= 40 m SERT siper ister; halka 6-24 m), bina ici kat pozisyonlari ve pencere / kose analizi (findCover'in isi).
 * Kapatma: lambs_main_eliteCoverYedek = false. Log: [ELIT-COVER] (ilk 40 cagri).
 *
 * Arguments:
 * 0: Asker <OBJECT>
 * 1: Dusman <OBJECT> ya da konum (AGL) <ARRAY>
 * 2: En fazla sonuc (varsayilan 1) <NUMBER>
 * 3: Arama menzili m (varsayilan 30; cagiranin findCover menzili: halka mesafesi bunu asmaz) <NUMBER>
 * 4: Dogrudan git (doMove) <BOOL> (varsayilan false)
 *
 * Return Value: [[posAGL <ARRAY>, stance <STRING "UP" / "MIDDLE" / "DOWN">], ...] en iyi ilk; bos dizi = siper yok
 * Public: No
*/

params [
    ["_unit", objNull, [objNull]],
    ["_enemy", objNull, [objNull, []]],
    ["_maxResults", 1, [0]],
    ["_range", 30, [0]],
    ["_forceMove", false, [false]]
];

if (isNull _unit || {!alive _unit}) exitWith {[]};
if (_enemy isEqualType objNull && {isNull _enemy}) exitWith {[]};
if (_enemy isEqualType [] && {_enemy isEqualTo []}) exitWith {[]};
private _enemyPos = _enemy call CBA_fnc_getPos;
if (_enemyPos isEqualTo [0, 0, 0]) exitWith {[]};
private _unitPos = getPosATL _unit;
if ((_unitPos select 2) > 50) exitWith {[]};

// AI SAYISI: 15 sn onbellek (her cagrida allUnits saymamak icin)
private _onb = missionNamespace getVariable [QGVAR(eliteCoverBot), [-1, -99]];
if ((diag_tickTime - (_onb select 1)) > 15) then {
    _onb = [count allUnits, diag_tickTime];
    missionNamespace setVariable [QGVAR(eliteCoverBot), _onb];
};
private _bot = _onb select 0;

private _yonMax = [3, [7, 15] select (_bot < 10)] select (_bot < 60);          // en yuksek yon indeksi (yon sayisi = indeks + 1)
private _halkaMax = [[1, 2] select (_bot < 150), [[2, 3] select (_bot < 30), 4] select (_bot < 10)] select (_bot < 60);
private _adim = [6, 4] select (_bot < 10);
// findCover ile ayni alt sinir: dusman >= 70 m ise adaylar dusmandan en az 25 m; yakin temasta (< 70 m) mesafenin %30'u (en az 5 m)
private _minD = [25, ((_unitPos distance2D _enemyPos) * 0.3) max 5] select ((_unitPos distance2D _enemyPos) < 70);
private _yonAdim = 360 / (_yonMax + 1);

private _unitYer = getTerrainHeightASL _unitPos;
private _dusmanGoz = AGLToASL (_enemyPos vectorAdd [0, 0, 1.2]);
private _bakis = _unitPos getDir _enemyPos;
private _dEn = _unitPos distance2D _enemyPos;

// YIGILMA: 40 m icindeki dost askerlerin konumu + grubun 8 sn icindeki rezervleri (findCover ile ortak defter)
private _dostlar = ((_unit nearEntities ["CAManBase", 40]) select {_x isNotEqualTo _unit && {alive _x} && {(side group _x) isEqualTo (side group _unit)}}) apply {getPosATL _x};
private _rezerv = ((group _unit) getVariable [QEGVAR(main,coverClaims), []]) select {(time - (_x select 1)) < 8 && {(_x select 2) isNotEqualTo _unit}};

private _adaylar = [];
for "_i" from 0 to _yonMax do {
    private _yon = _i * _yonAdim;
    for "_m" from 1 to _halkaMax do {
        private _mesafe = _m * _adim;
        private _aday = _unitPos getPos [_mesafe, _yon];
        if (_mesafe <= _range && {(_aday distance2D _enemyPos) >= _minD} && {!surfaceIsWater _aday} && {(abs ((getTerrainHeightASL _aday) - _unitYer)) <= 3}) then {
            _aday set [2, _unitPos select 2];
            // en yuksek korunan durus: UP -> MIDDLE -> DOWN
            private _durus = "";
            {
                _x params ["_ad", "_h"];
                private _goz = AGLToASL (_aday vectorAdd [0, 0, _h]);
                private _v = vectorNormalized (_dusmanGoz vectorDiff _goz);
                // (a) 4 m onunde mermi durduran engel (FIRE LOD)
                private _onde = (count (lineIntersectsSurfaces [_goz, _goz vectorAdd (_v vectorMultiply 4), _unit, objNull, true, 1, "FIRE", "NONE"])) > 0;
                // (b) dusman gozune giden hat kapali (nesne ya da arazi)
                if (_onde && {(lineIntersects [_goz, _dusmanGoz, _unit, objNull]) || {terrainIntersectASL [_goz, _dusmanGoz]}}) exitWith { _durus = _ad; };
            } forEach [["UP", 1.7], ["MIDDLE", 1.0], ["DOWN", 0.4]];

            if (_durus isNotEqualTo "") then {
                private _aci = abs (_bakis - (_aday getDir _enemyPos));
                if (_aci > 180) then { _aci = 360 - _aci; };
                private _puan = 100 + ((_halkaMax - _m + 1) * 15) + ((180 - _aci) * 0.15) + ([0, 3, 6] select (["DOWN", "MIDDLE", "UP"] find _durus));
                // dusmana YAKLASAN adaylari cezalandir
                private _yaklasma = _dEn - (_aday distance2D _enemyPos);
                if (_yaklasma > 0) then { _puan = _puan - (_yaklasma * 3); };
                // yigilma
                private _yigil = {(_x distance2D _aday) < 4} count _dostlar;
                if (_yigil > 0) then { _puan = _puan - ((_yigil min 3) * 45); };
                if ((_rezerv findIf {((_x select 0) distance2D _aday) < 6}) >= 0) then { _puan = _puan - 20; };
                _adaylar pushBack [_puan, +_aday, _durus, _mesafe];
            };
        };
    };
};

if (_adaylar isEqualTo []) exitWith {[]};
_adaylar sort false;
private _ret = (_adaylar select [0, (_maxResults max 1) min (count _adaylar)]) apply {[_x select 1, _x select 2]};

if (_forceMove) then {
    _unit doMove ((_ret select 0) select 0);
    _unit setUnitPosWeak "MIDDLE";
};

// tani: ilk 40 cagri (RPT: [ELIT-COVER]); sonrasi yalniz lambs_main debug
if (isNil "lambs_danger_eliteCoverLogN") then { lambs_danger_eliteCoverLogN = 0; };
if (lambs_danger_eliteCoverLogN < 40 || {EGVAR(main,debug_functions)}) then {
    lambs_danger_eliteCoverLogN = lambs_danger_eliteCoverLogN + 1;
    private _en = _adaylar select 0;
    diag_log format ["[ELIT-COVER] %1 | AI:%2 (%3 yon x %4 halka) | dusman %5 m | aday:%6 | en iyi: puan %7, %8 m, durus %9 | zaman %10", name _unit, _bot, _yonMax + 1, _halkaMax, round _dEn, count _adaylar, round (_en select 0), round (_en select 3), _en select 2, round time];
};

_ret
