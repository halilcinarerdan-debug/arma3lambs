#include "script_component.hpp"
/*
 * Author: Cinar (ELITE fork)
 * CATISMA POZISYONU ADAY URETICISI (v8.385) — kullanici: '3denden yerlestirilebilecek catisma pozisyon destekleyici, onem puanlanabilsin, botlar modulun ne ise yaradigini bilsin (ev ici falan),
 * kotu terrainlerde botlara yol gostersin, cover icin, mevzi ve karakol sistemi ile entegre olsun'.
 *
 * 3DEN 'ELITE Catisma Pozisyonu' modulleri (fnc_edenPozisyon) 'lambs_danger_cpListe' kaydina yazilir (publicVariable: AI hangi makinede yerelse orada okunur).
 * lambs_main_fnc_findCover bu fonksiyonu DOGAL siper adaylarinin yanina ek aday uretmek icin cagirir ([skor, pos, durus] — nesne adaylariyla ayni bicim, ayni siralama).
 * Modul bilgisi: [pos(AGL), yon, tip, puan, taraf, durus, kapasite, sektor, rol, garnizon, ad]
 *   tip   : 0 SIPER (genel) | 1 BINA ICI (pencere / kapi / oda) | 2 CATI - UST KAT gozetleme | 3 ATES MEVZII (MG / nisanci) | 4 GECIS - yol noktasi (kotu arazide ilerleme rotasi; yalniz ADVANCE)
 *   puan  : 1..10 onem (taban skor = 20 + puan x 6; nesne siperleri tipik 50-100 arasi)
 *   taraf : 0 hepsi | 1 BLUFOR | 2 OPFOR | 3 INDEP      durus: 0 otomatik | 1 yatarak | 2 comelerek | 3 ayakta
 *   sektor: ates / ilerleme sektoru (derece, 360 = her yon); modul yonu (rotasyon) sektorun merkezi. Dusman sektor disindaysa aday elenir (+20 derece tolerans: -10).
 *   rol   : 0 herkes | 1 MARKSMAN | 2 MG | 3 AT | 4 RIFLE (eslesen +16, eslesmeyen -14; rolsuz modulde AT'ye bina / cati -12 geri tepme guvenligi)
 *
 * Puanlama (cover'daki mermi geometrisiyle ayni olcut): taban + KORUNMA (3 yukseklikte FIRE geometri x6) + gizli durus sayisi x3 + sektor (+10) + tip / mod tablosu
 *   + tip 0: dusmandan gizli +8 / degil -15;  tip 1-3 (atis mevzii): hedefi gorebiliyor +12 (+6 hull-down: comelince gizli) / goremiyor -12 (OVERWATCH -25)
 *   - uzaklik (0.5 / m; gecis 0.25 / m) - yukseklik farki (3 m'den sonra 0.8 / m) +- dusmana yaklasma (nesne siperleriyle ayni) - kalabalik (kapasite dolu -45; her dolu yer -12).
 * Tip / mod tablosu [SIPER, BINA, CATI, ATES, GECIS]:  DEFEND [6,8,2,5,-]  ADVANCE [2,-4,-8,-6,18]  OVERWATCH [-6,6,14,14,-]  EVADE [6,12,-,-,-]  SURVIVE [6,8,-,-,-]   ('-' = aday olmaz).
 *   EVADE: en az 2, SURVIVE: en az 1 yukseklikte FIRE geometri engeli sart. Yukseklik farki siniri: bina ici / cati 10 m, digerleri 4 m. Dusmana min. mesafe: findCover'in alt siniri (CQB'de kisalir).
 * Kapatma: CBA 'ELITE catisma pozisyonu modulleri' (lambs_danger_cpAktif) ya da lambs_danger_cpKapali = true.
 *
 * Arguments:
 * 0: Asker <OBJECT>
 * 1: Dusman konumu (AGL) <ARRAY>
 * 2: Dusman gorus noktasi (ASL, bas yuksekligi) <ARRAY>
 * 3: Arama yaricapi m <NUMBER>
 * 4: Mod <STRING> (DEFEND / ADVANCE / OVERWATCH / EVADE / SURVIVE)
 * 5: Dusmana en az mesafe m <NUMBER>
 * 6: Rezerv defteri [[pos, zaman, asker], ...] <ARRAY>
 * 7: Asker - dusman mesafesi m <NUMBER>
 *
 * Return Value:
 * [[skor, posAGL, durus], ...] (en cok 10 aday; bos = uygun modul yok)
 *
 * Public: No
*/

params [
    ["_unit", objNull, [objNull]],
    ["_enemyPos", [0, 0, 0], [[]]],
    ["_dangerPos", [0, 0, 0], [[]]],
    ["_range", 30, [0]],
    ["_mode", "DEFEND", [""]],
    ["_minDist", 25, [0]],
    ["_claims", [], [[]]],
    ["_unitEnemyDist", 0, [0]]
];

private _liste = missionNamespace getVariable ["lambs_danger_cpListe", []];
if (
    _liste isEqualTo [] || {isNull _unit}
    || {missionNamespace getVariable ["lambs_danger_cpKapali", false]}
    || {!(missionNamespace getVariable ["lambs_danger_cpAktif", true])}
) exitWith {[]};

private _taraf = side (group _unit);
private _upos = getPosATL _unit;
private _uz = (getPosASL _unit) select 2;

// en yakin 10 modul (yaricap icinde)
private _yakin = [];
{
    private _d = _upos distance2D (_x select 0);
    if (_d <= _range) then { _yakin pushBack [_d, _x]; };
} forEach _liste;
if (_yakin isEqualTo []) exitWith {[]};
_yakin = [_yakin, [], {_x select 0}, "ASCEND"] call BIS_fnc_sortBy;
_yakin = _yakin select [0, 10];

// findCover ile ayni gorus / mermi olcutleri
private _gizli = {
    params ["_bas", "_son", "_u"];
    (lineIntersects [_bas, _son, _u]) || {terrainIntersectASL [_bas, _son]}
};
private _korunmus = {
    params ["_bas", "_son", "_u"];
    (count (lineIntersectsSurfaces [_bas, _son, _u, objNull, true, 1, "FIRE", "NONE"])) > 0
};

private _rol = "";
private _cikti = [];
{
    _x params ["_d", "_m"];
    _m params ["_pos", "_dir", "_tip", "_puan", "_tr", "_dur", "_kap", "_sek", "_rolT"];

    // taraf
    private _trSide = [sideUnknown, west, east, independent] select ((round _tr) max 0 min 3);
    if (_trSide isNotEqualTo sideUnknown && {_trSide isNotEqualTo _taraf}) then { continue };

    // mod uygunlugu: gecis noktasi yalniz ilerlemede; EVADE / SURVIVE yalniz siper + bina ici
    private _uygun = switch (_mode) do {
        case "ADVANCE": {true};
        case "EVADE": {_tip in [0, 1]};
        case "SURVIVE": {_tip in [0, 1]};
        default {_tip < 4};
    };
    if (!_uygun) then { continue };

    private _p = +_pos;
    if (surfaceIsWater _p) then { continue };
    if ((_dangerPos distance2D _p) <= _minDist) then { continue };
    private _pASL = AGLToASL _p;
    private _dz = abs ((_pASL select 2) - _uz);
    if (_dz > ([4, 10] select (_tip in [1, 2]))) then { continue };

    private _skor = 20 + (_puan * 6);

    // sektor (modul yonu = ates / ilerleme yonu)
    if (_sek < 360) then {
        private _ang = abs ((((_p getDir _enemyPos) - _dir) + 540) % 360 - 180);
        private _yarim = _sek / 2;
        if (_ang <= _yarim) then {
            _skor = _skor + 10;
        } else {
            if (_ang <= (_yarim + 20)) then { _skor = _skor - 10; } else { continue };
        };
    };

    // korunma (mermi geometrisi) + gizlenme
    private _sert = 0;
    { if ([_dangerPos, _pASL vectorAdd [0, 0, _x], _unit] call _korunmus) then { _sert = _sert + 1; }; } forEach [0.1, 0.75, 1.45];
    if (_mode isEqualTo "EVADE" && {_sert < 2}) then { continue };
    if (_mode isEqualTo "SURVIVE" && {_sert < 1}) then { continue };
    private _gDown = [_dangerPos, _pASL vectorAdd [0, 0, 0.1], _unit] call _gizli;
    private _gMid = [_dangerPos, _pASL vectorAdd [0, 0, 0.75], _unit] call _gizli;
    private _gUp = [_dangerPos, _pASL vectorAdd [0, 0, 1.45], _unit] call _gizli;
    private _stances = [];
    if (_gDown) then {
        _stances pushBack "DOWN";
        if (_gMid) then {
            _stances pushBack "MIDDLE";
            if (_gUp) then { _stances pushBack "UP"; };
        };
    };
    _skor = _skor + (_sert * 6) + ((count _stances) * 3);

    // tip: siper dusmandan gizli olmali; atis mevzii hedefi gorebilmeli
    if (_tip isEqualTo 0) then {
        _skor = _skor + ([-15, 8] select _gDown);
    } else {
        if (_tip < 4) then {
            if (!_gUp) then {
                _skor = _skor + 12 + ([0, 6] select _gMid);
            } else {
                _skor = _skor - ([12, 25] select (_mode isEqualTo "OVERWATCH"));
            };
        };
    };

    // tip x mod tablosu
    _skor = _skor + (switch (_mode) do {
        case "ADVANCE": { [2, -4, -8, -6, 18] select (_tip min 4) };
        case "OVERWATCH": { [-6, 6, 14, 14, 0] select (_tip min 4) };
        case "EVADE": { [6, 12, 0, 0, 0] select (_tip min 4) };
        case "SURVIVE": { [6, 8, 0, 0, 0] select (_tip min 4) };
        default { [6, 8, 2, 5, 0] select (_tip min 4) };
    });

    // rol
    if (_tip < 4 && {(_rolT > 0) || {_tip in [1, 2]}}) then {
        if (_rol isEqualTo "") then { _rol = [_unit] call (missionNamespace getVariable ["lambs_danger_fnc_getUnitRole", {"RIFLE"}]); };
        if (_rolT > 0) then {
            _skor = _skor + ([-14, 16] select (_rol isEqualTo (["", "MARKSMAN", "MG", "AT", "RIFLE"] select ((round _rolT) min 4))));
        } else {
            if (_rol isEqualTo "AT") then { _skor = _skor - 12; };
        };
    };

    // uzaklik + yukseklik farki + dusmana yaklasma
    _skor = _skor - (_d * ([0.5, 0.25] select (_tip isEqualTo 4))) - (((_dz - 3) max 0) * 0.8);
    private _yak = _unitEnemyDist - (_p distance2D _enemyPos);
    switch (_mode) do {
        case "ADVANCE": { _skor = _skor + (((_yak min 30) max -30) * 0.9); };
        case "EVADE": { _skor = _skor + ((((-_yak) min 40) max -40) * 0.9); };
        case "SURVIVE": { _skor = _skor + ((((-_yak) min 30) max -30) * 0.5); };
        default { if (_yak > 0) then { _skor = _skor - (_yak * 0.8); }; };
    };

    // kapasite: pozisyondaki / rezerv eden diger askerler
    private _dolu = count ((_p nearEntities ["CAManBase", 2.5]) select {alive _x && {_x isNotEqualTo _unit}});
    _dolu = _dolu + ({((_x select 0) distance2D _p) < 3 && {(_x select 2) isNotEqualTo _unit}} count _claims);
    if (_dolu >= _kap) then { _skor = _skor - 45; } else { _skor = _skor - (_dolu * 12); };

    // durus: modulde sabitse o; otomatik = gizli kalinan en yuksek durus (hic gizli degilse atis tipi comelmis, siper yatik)
    private _st = switch (round _dur) do {
        case 1: {"DOWN"};
        case 2: {"MIDDLE"};
        case 3: {"UP"};
        default { if (_stances isEqualTo []) then { ["MIDDLE", "DOWN"] select (_tip isEqualTo 0) } else { _stances select -1 } };
    };

    _cikti pushBack [_skor, _p, _st];
} forEach _yakin;

_cikti
