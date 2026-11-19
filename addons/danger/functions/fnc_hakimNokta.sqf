#include "script_component.hpp"
/*
 * Author: Cinar (ELITE fork)
 * HAKIM NOKTA SECICI — MG / nisanci / AT icin planli ates pozisyonu (v8.669; yol haritasi Asama 12 madde 12 + 7; kullanici: 'haritanin elevationuna gore manganin hakim noktalara gecmesini ekle').
 * [asker, tehdit, rol, (yaricap), (marj)] -> [nokta (AGL), durus, skor, yukseklikFarki, dusmanMesafe, kapsama (0..1), mevcutSkor] YA DA [] (tasinmaya degmez)
 *
 * ESKI: fnc_araziAnaliz 16 ornekte 'merkezden >= 2.5 m yuksek + tehdidi gorur + ufukta degil' ilk adayi veriyordu; RPT c6c1f3e6'da 'hakim nokta bulunan: 0'. Menzil, atis alani kapsami, siper ve
 *   'dusmana yaklasma' hic puanlanmiyordu; AT icin hic planlama yoktu.
 * SIMDI: 3 halka (yaricap x 0.4 / 0.7 / 1.0) x 12 yon + mevcut konum puanlanir (yuksek puan = iyi):
 *   + yukseklik avantaji (rol agirligi x en cok 12 m): MG / nisanci 3.0, AT 0.8
 *   + ATIS ALANI KAPSAMI (30 x oran): tehdit merkezi + yanal +-18 m + derinlik +-12 m = 5 noktadan kac tanesi YATIK goz (0.45 m) hizasindan gorunuyor; MERKEZ gorunmuyorsa aday ELENIR
 *   + yakinda sert nesne (agac govdesi / kaya / duvar / HIDE, 3 m): +10 (mermi korumasi, siluet)
 *   - UFUK CIZGISI: dusman -> nokta isini 300 m otesinde engel yoksa (gokyuzune karsi siluet) -22
 *   - MENZIL BANDI disi: MG 120-500 m, nisanci 200-700 m, AT 80-350 m; dar band disina 0.06-0.10 puan / m; rol alt siniri (60 / 100 / 50 m) ALTINDA elenir
 *   - HAREKET: 0.35 puan / m (gereksiz dolasma yok)
 *   ELENIR: su, bina yakini (5 m), egim (yuzey normali z < 0.8), 3 m'de baska asker, rezerv defterindeki (lambs_danger_hakimDolu, 5 m, 90 sn) nokta, tehdide mevcut konumdan
 *     lambs_danger_hakimYaklasma (15 m) fazla yaklasan nokta (MG one kosmaz).
 *   KABUL: en iyi puan >= mevcut konum puani + marj (8; yenilemede 14) VE (yukseklik >= 1 m YA DA kapsama mevcuttan >= 0.25 iyi).
 * CBA: lambs_danger_hakimNokta (acik / kapali), lambs_danger_hakimYaricap (45 m), lambs_danger_hakimYaklasma (15 m). Log: [MG-HAKIM] (ilk 25).
 *
 * Arguments:
 * 0: Asker <OBJECT>
 * 1: Tehdit pozisyonu <ARRAY AGL>
 * 2: Rol "MG" | "MARKSMAN" | "AT" <STRING> (varsayilan "MG")
 * 3: Yaricap m (-1: CBA) <NUMBER>
 * 4: Gerekli puan marji <NUMBER> (varsayilan 8)
 *
 * Return Value: [nokta, durus, skor, yukseklik, dusmanMesafe, kapsama, mevcutSkor] ya da [] <ARRAY>
 *
 * Public: No
*/

params [["_u", objNull, [objNull]], ["_t", [], [[]]], ["_rol", "MG", [""]], ["_yar", -1, [0]], ["_marj", 8, [0]]];
if (isNull _u || {!alive _u} || {(count _t) < 2} || {!(missionNamespace getVariable ["lambs_danger_hakimNokta", true])}) exitWith {[]};

private _R = if (_yar > 0) then { _yar } else { ((missionNamespace getVariable ["lambs_danger_hakimYaricap", 45]) max 20) min 80 };
private _maxYak = ((missionNamespace getVariable ["lambs_danger_hakimYaklasma", 15]) max 0) min 60;
private _c = getPosATL _u;
private _cH = getTerrainHeightASL _c;
private _d0 = _c distance2D _t;
private _eASL = AGLToASL [_t select 0, _t select 1, ((_t param [2, 0]) max 0) + 1.6];
private _dirT = _c getDir _t;

// rol parametreleri: [ideal alt, ideal ust, yukseklik agirligi, en kucuk dusman mesafesi, durus]
private _rp = switch (_rol) do {
    case "MARKSMAN": { [200, 700, 3.0, 100, "DOWN"] };
    case "AT": { [80, 350, 0.8, 50, "MIDDLE"] };
    default { [120, 500, 3.0, 60, "DOWN"] };
};
_rp params ["_bA", "_bU", "_hAg", "_dMin", "_durus"];

// atis alani ornekleri: tehdit merkezi + yanal +-18 m + derinlik +-12 m (gogus yuksekligi)
private _tz = (_t param [2, 0]) max 0;
private _ornek = [
    [_t select 0, _t select 1, _tz],
    (_t getPos [18, _dirT + 90]) vectorAdd [0, 0, _tz],
    (_t getPos [18, _dirT - 90]) vectorAdd [0, 0, _tz],
    (_t getPos [12, _dirT]) vectorAdd [0, 0, _tz],
    (_t getPos [12, _dirT + 180]) vectorAdd [0, 0, _tz]
] apply { AGLToASL (_x vectorAdd [0, 0, 1.0]) };

private _sertSinif = ["TREE", "ROCK", "ROCKS", "WALL", "HIDE"];
private _dolu = (missionNamespace getVariable ["lambs_danger_hakimDolu", []]) select { (time - (_x select 1)) < 90 };

// [skor, yukseklik, kapsama, dusmanMesafe] ya da skor = -999 (elendi)
private _skor = {
    params ["_pt", "_hareketM", "_yakinKontrol"];
    private _dc = _pt distance2D _t;
    if (_dc < _dMin) exitWith { [-999, 0, 0, _dc] };
    if (_yakinKontrol && {_dc < (_d0 - _maxYak)}) exitWith { [-999, 0, 0, _dc] };
    private _pA = ATLToASL (_pt vectorAdd [0, 0, 0.45]);
    if ((terrainIntersectASL [_pA, _eASL]) || {lineIntersects [_pA, _eASL, _u, objNull]}) exitWith { [-999, 0, 0, _dc] };
    private _g = 0;
    {
        if (!(terrainIntersectASL [_pA, _x]) && {!(lineIntersects [_pA, _x, _u, objNull])}) then { _g = _g + 1; };
    } forEach _ornek;
    private _kap = _g / (count _ornek);
    private _h = ((getTerrainHeightASL _pt) - _cH) max -3 min 12;
    private _s = (_hAg * _h) + (30 * _kap) - (0.35 * _hareketM);
    if ((nearestTerrainObjects [_pt, _sertSinif, 3, false, true]) isNotEqualTo []) then { _s = _s + 10; };
    private _dd = vectorNormalized (_pA vectorDiff _eASL);
    private _ileri = _pA vectorAdd (_dd vectorMultiply 300);
    if (!(terrainIntersectASL [_pA, _ileri]) && {!(lineIntersects [_pA, _ileri, _u, objNull])}) then { _s = _s - 22; };
    if (_dc < _bA) then { _s = _s - ((_bA - _dc) * 0.10); } else { if (_dc > _bU) then { _s = _s - ((_dc - _bU) * 0.06); }; };
    [_s, _h, _kap, _dc]
};

private _s0a = [_c, 0, false] call _skor;
private _s0 = if ((_s0a select 0) < -900) then { -60 } else { _s0a select 0 };
private _kap0 = _s0a select 2;

private _en = [];
private _enS = -1e9;
{
    private _r = _R * _x;
    for "_k" from 0 to 11 do {
        private _pt = _c getPos [_r, _k * 30];
        if (surfaceIsWater _pt) then { continue };
        if (((surfaceNormal _pt) select 2) < 0.8) then { continue };
        if ((nearestTerrainObjects [_pt, ["BUILDING", "HOUSE"], 5, false, true]) isNotEqualTo []) then { continue };
        if (((_pt nearEntities ["CAManBase", 3]) findIf {_x isNotEqualTo _u && {alive _x}}) >= 0) then { continue };
        if ((_dolu findIf {((_x select 0) distance2D _pt) < 5}) >= 0) then { continue };
        private _res = [_pt, _r, true] call _skor;
        if ((_res select 0) > _enS) then { _enS = _res select 0; _en = [_pt, _res]; };
    };
} forEach [0.4, 0.7, 1.0];

if (_en isEqualTo []) exitWith {[]};
(_en select 1) params ["_bs", "_bh", "_bk", "_bd"];
if (_bs < (_s0 + _marj)) exitWith {[]};
if (!(_bh >= 1 || {(_bk - _kap0) >= 0.25})) exitWith {[]};

private _pt = _en select 0;
_dolu pushBack [_pt, time];
missionNamespace setVariable ["lambs_danger_hakimDolu", _dolu];

if ((missionNamespace getVariable ["lambs_danger_hakimLogN", 0]) < 25) then {
    missionNamespace setVariable ["lambs_danger_hakimLogN", (missionNamespace getVariable ["lambs_danger_hakimLogN", 0]) + 1];
    diag_log format [
        "[MG-HAKIM] %1 | %2 | rol %3 | mevcut skor %4 (kapsama %5 %%) -> hakim nokta skor %6 | %7 m hareket | yukseklik %8 m | dusman %9 m | atis alani kapsami %10 %% | yaricap %11 m",
        groupId (group _u), name _u, _rol, round _s0, round (_kap0 * 100), round _bs, round (_c distance2D _pt), _bh toFixed 1, round _bd, round (_bk * 100), _R
    ];
};

[_pt, _durus, _bs, _bh, _bd, _bk, _s0]
