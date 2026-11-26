#include "script_component.hpp"
/*
 * Author: Cinar (ELITE fork)
 * YOL TARAMA / ERISILEBILIRLIK RAYCAST'I (v8.805; kullanici: 'raycast sisteminin hakkini son damlasina kadar ver'; RPT c69aff1e v8.804: [SIPER-VARIS] ULASILAMADI 25 kayit, siper noktasina 5-35 m kala 3 sn ilerleme yok,
 *   2 yeniden emir sonuc vermedi). NEDEN: siper adaylari dusmandan GIZLI mi / mermi durdurur mu / yandan acik mi diye cok iyi olculuyordu, ama askerin oraya GIDEBILIP GIDEMEYECEGI olculmuyordu
 *   (yalniz siperZorla ve yumusak kayma tek isinla bakiyordu). Nesnenin dusmana gore ARKA noktasi cogu zaman nesnenin ('duvar / cit / kaya / bina kosesi') diger yanindadir; asker duz hatta gidemez, AI yol bulucu
 *   uzun dolasir ya da hic bulamaz (cit / dar gecit / yamac) ve 'ilerleme yok' olur.
 * YONTEM (yalniz isin; yol bulucu / calculatePath YOK: senkron, ucuz, tekrarlanabilir):
 *   1) SU / DIK YAMAC: hat boyunca 4 m'de bir (en cok 10) yuzey suyu ve arazi egimi (adim basina > ~48 derece) ornegi. Su ya da ucurum varsa nokta erisilemez sayilir.
 *   2) DUZ HAT: askerden noktaya (son 0.7 m kisaltilarak: siper nesnesine siyirmasin) GEOM LOD hatti 3 yukseklikte (0.6 / 1.0 / 1.5 m: dizlik / bel / gogus) + govde genisligi icin +-0.3 m yan isinlar (1.0 m).
 *      Insan / hayvan engel sayilmaz. Arazi (nesnesiz) carpmasi engel sayilmaz. Duz hat acik ise [true, 1].
 *   3) DOLASMA: duz hat nesneyle kapaliysa orta noktadan hatta DIK iki yana (mesafenin %20 / %35 / %55 / %80 / %120'si, 3-30 m) iki bacakli kord denenir (her bacak 0.6 + 1.0 m GEOM); en kisa acik kord secilir.
 *      oran = (toplam kord boyu / duz mesafe). oran > yolDolasMaks (1.8) ya da kord yoksa nokta erisilemez sayilir (uzun duvarin arkasi, kapali avlu, iki cit arasi).
 * Arguments:
 * 0: Baslangic: Asker <OBJECT> ya da konum (AGL) <ARRAY>
 * 1: Varis noktasi (AGL) <ARRAY>
 * 2: En cok dolasma orani (0 = CBA lambs_danger_yolDolasMaks) <NUMBER>
 * 3: Log etiketi (bos = log yok) <STRING>
 *
 * Return Value: [erisilebilir <BOOL>, dolasma orani <NUMBER> (1 = duz, 99 = yok), sebep <STRING>, engel (sinif / model) <STRING>]
 * CBA: lambs_danger_yolTara (acik / kapali), lambs_danger_yolDolasMaks. Log: [YOL-TARA] (ilk 25 olumsuz / dolasma) + 60 sn [YOL-TARA-OZET]
 * Public: No
*/

params [["_bas", objNull, [objNull, []]], ["_hedef", [], [[]]], ["_maks", 0, [0]], ["_etiket", "", [""]]];
if ((count _hedef) < 2) exitWith {[true, 1, "param", ""]};
if !(missionNamespace getVariable ["lambs_danger_yolTara", true]) exitWith {[true, 1, "kapali", ""]};
if (_maks <= 0) then { _maks = ((missionNamespace getVariable ["lambs_danger_yolDolasMaks", 1.8]) max 1.1) min 4; };

private _ign = if (_bas isEqualType objNull) then { _bas } else { objNull };
if ((_bas isEqualType objNull) && {isNull _bas}) exitWith {[true, 1, "param", ""]};
private _a = if (_bas isEqualType objNull) then { getPosASL _bas } else { AGLToASL [_bas select 0, _bas select 1, if ((count _bas) > 2) then { _bas select 2 } else { 0 }] };
private _hz = if ((count _hedef) > 2 && {(_hedef select 2) > 0.3}) then { _hedef select 2 } else { 0 };
private _b = AGLToASL [_hedef select 0, _hedef select 1, _hz];
private _d = _a distance2D _b;
if (_d < 2.5) exitWith {[true, 1, "yakin", ""]};

private _say = missionNamespace getVariable ["lambs_danger_yolSay", createHashMap];
missionNamespace setVariable ["lambs_danger_yolSay", _say];
_say set ["cagri", (_say getOrDefault ["cagri", 0]) + 1];
if (isNil "lambs_danger_yolOzetT") then { lambs_danger_yolOzetT = time + 60; };
if (time > lambs_danger_yolOzetT) then {
    lambs_danger_yolOzetT = time + 60;
    private _o = _say getOrDefault ["dolasma_n", 0];
    diag_log format ["[YOL-TARA-OZET] 60 sn: cagri=%1 duz=%2 dolasma=%3 (ort oran %4) kapali=%5 [su=%6 dik_yamac=%7 dolasma_yok=%8 dolasma_asildi=%9 bina_kose=%10]", _say getOrDefault ["cagri", 0], _say getOrDefault ["duz", 0], _o, if (_o > 0) then { ((_say getOrDefault ["dolasma_top", 0]) / _o) toFixed 2 } else { "-" }, _say getOrDefault ["kapali", 0], _say getOrDefault ["su", 0], _say getOrDefault ["dik_yamac", 0], _say getOrDefault ["dolasma_yok", 0], _say getOrDefault ["dolasma_asildi", 0], _say getOrDefault ["bina_kose", 0]];
    _say = createHashMap;
    missionNamespace setVariable ["lambs_danger_yolSay", _say];
};

private _log = {
    params ["_ok", "_oran", "_sebep", "_ad"];
    if (!_ok) then { _say set ["kapali", (_say getOrDefault ["kapali", 0]) + 1]; };
    private _n = missionNamespace getVariable ["lambs_danger_yolLogN", 0];
    if (_etiket isNotEqualTo "" && {_n < 25} && {(!_ok) || {_oran > 1.05}}) then {
        missionNamespace setVariable ["lambs_danger_yolLogN", _n + 1];
        diag_log format ["[YOL-TARA] %1 | %2 | mesafe %3 m | %4 | dolasma %5 | engel %6", _etiket, ["ERISILEMEZ", "ERISILEBILIR"] select _ok, round _d, _sebep, _oran toFixed 2, _ad];
    };
    [_ok, _oran, _sebep, _ad]
};

// 1) su / dik yamac ornekleri
private _n = ((ceil (_d / 4)) max 2) min 10;
private _adim = _d / _n;
private _sebep = "";
private _hOnc = getTerrainHeightASL [_a select 0, _a select 1];
for "_i" from 1 to _n do {
    private _f = _i / _n;
    private _sx = (_a select 0) + (((_b select 0) - (_a select 0)) * _f);
    private _sy = (_a select 1) + (((_b select 1) - (_a select 1)) * _f);
    if (surfaceIsWater [_sx, _sy]) exitWith { _sebep = "su"; };
    private _h = getTerrainHeightASL [_sx, _sy];
    if ((abs (_h - _hOnc)) > ((_adim * 1.1) + 0.3)) exitWith { _sebep = "dik_yamac"; };
    _hOnc = _h;
};
if (_sebep isNotEqualTo "") exitWith {
    _say set [_sebep, (_say getOrDefault [_sebep, 0]) + 1];
    [false, 99, _sebep, ""] call _log
};

// 2) duz hat (GEOM; insan / hayvan / arazi sayilmaz)
private _dx = ((_b select 0) - (_a select 0)) / _d;
private _dy = ((_b select 1) - (_a select 1)) / _d;
private _b1 = [(_b select 0) - (_dx * 0.7), (_b select 1) - (_dy * 0.7), _b select 2];
private _engel = {
    params ["_p", "_q", "_yk"];
    private _blk = objNull;
    {
        private _yy = _x;
        private _r = lineIntersectsSurfaces [_p vectorAdd [0, 0, _yy], _q vectorAdd [0, 0, _yy], _ign, objNull, true, 3, "GEOM", "NONE"];
        // v8.826 INCE NESNE (RPT 0c1269e0: yolTara ERISILEMEZ 89 / 444 (%20), 'dolasma kordu yok' 84; ilk olumsuz engeller t_poplar2f_dead_f (agac govdesi) / city_8m_f): yatay boyutu < 1.5 m olan nesne (agac govdesi, diregi, tabela) engel SAYILMAZ - AI yurur / dolasir
        private _i = _r findIf { private _o = _x select 2; (!isNull _o) && {!(_o isKindOf "CAManBase")} && {!(_o isKindOf "Animal")} && {private _bb = boundingBoxReal _o; (((_bb select 1) select 0) - ((_bb select 0) select 0)) >= 1.5 || {(((_bb select 1) select 1) - ((_bb select 0) select 1)) >= 1.5}} };
        if (_i >= 0) exitWith { _blk = (_r select _i) select 2; };
    } forEach _yk;
    _blk
};
private _px = -_dy * 0.3;
private _py = _dx * 0.3;
private _blk = [_a, _b1, [0.6, 1.0, 1.5]] call _engel;
if (isNull _blk) then { _blk = [_a vectorAdd [_px, _py, 0], _b1 vectorAdd [_px, _py, 0], [1.0]] call _engel; };
if (isNull _blk) then { _blk = [_a vectorAdd [-_px, -_py, 0], _b1 vectorAdd [-_px, -_py, 0], [1.0]] call _engel; };
if (isNull _blk) exitWith {
    _say set ["duz", (_say getOrDefault ["duz", 0]) + 1];
    [true, 1, "duz hat acik", ""]
};
private _ad = typeOf _blk;
if (_ad isEqualTo "") then { _ad = (getModelInfo _blk) select 0; };

// 3) dolasma kordu (orta noktadan iki yana; en kisa acik kord)
private _en = 1e9;
{
    private _yan = (((_d * _x) min 30) max 3);
    {
        if (_en < 1e9) then { continue };
        private _mx = (((_a select 0) + (_b select 0)) / 2) + (-_dy * _x * _yan);
        private _my = (((_a select 1) + (_b select 1)) / 2) + (_dx * _x * _yan);
        if (!(surfaceIsWater [_mx, _my])) then {
            private _m = [_mx, _my, getTerrainHeightASL [_mx, _my]];
            if (isNull ([_a, _m, [0.6, 1.0]] call _engel) && {isNull ([_m, _b1, [0.6, 1.0]] call _engel)}) then {
                _en = (_a distance2D _m) + (_m distance2D _b);
            };
        };
    } forEach [1, -1];
} forEach [0.2, 0.35, 0.55, 0.8, 1.2];   // v8.807: 3 -> 5 kord yanal orani (RPT d03615e7: 32 reddin 31'i 'dolasma kordu yok', koy evleri / duvar; dar gecit / avlu icin daha fazla aday)
// v8.828 BINA KOSESI DOLASMASI (RPT a4a03ba1: yolTara ERISILEMEZ 390 / 1328 (%29), 'dolasma kordu yok' 388; ilk engel land_ffaa_casa_af_3 = EV; coverOlcum: gercek siper (<= 4 m nesne) %0, bina arkasi (<= 8 m) 0 / 119 -> evin arkasi gibi EN IYI siper adaylari eleniyordu): dar iki bacakli kord (orta noktadan yana)
//   evi dolasamiyor (cit / duvar / komsu ev kordu keser). Engel BINA / ev ise sinir kutusunun 4 koseli (2.5 m dis pay) uzerinden a -> kose -> b ve (komsu iki kose) a -> k1 -> k2 -> b yollari denenir; bacaklar o binayi yok sayar (kosede 2.5 m bosluk); en kisa acik yol oran sinirinda kabul edilir.
if (_en >= 1e9 && {_blk isKindOf "House" || {_blk isKindOf "Building"}}) then {
    private _bb = boundingBoxReal _blk;
    private _mn = _bb select 0;
    private _mx = _bb select 1;
    private _kos = [[(_mn select 0) - 2.5, (_mn select 1) - 2.5], [(_mx select 0) + 2.5, (_mn select 1) - 2.5], [(_mx select 0) + 2.5, (_mx select 1) + 2.5], [(_mn select 0) - 2.5, (_mx select 1) + 2.5]] apply {
        private _w = _blk modelToWorld [_x select 0, _x select 1, 0];
        [_w select 0, _w select 1, getTerrainHeightASL [_w select 0, _w select 1]]
    };
    private _ignB = _blk;
    private _acik2 = {
        params ["_p", "_q"];
        private _ok = true;
        { private _yy = _x; if ((lineIntersectsSurfaces [_p vectorAdd [0, 0, _yy], _q vectorAdd [0, 0, _yy], _ign, _ignB, true, 3, "GEOM", "NONE"]) findIf { private _o = _x select 2; (!isNull _o) && {!(_o isKindOf "CAManBase")} && {!(_o isKindOf "Animal")} && {private _b2 = boundingBoxReal _o; (((_b2 select 1) select 0) - ((_b2 select 0) select 0)) >= 1.5 || {(((_b2 select 1) select 1) - ((_b2 select 0) select 1)) >= 1.5}} } >= 0) then { _ok = false; }; } forEach [0.6, 1.0];
        _ok
    };
    private _kor = count _kos;
    for "_i" from 0 to (_kor - 1) do {
        private _k1 = _kos select _i;
        if (!(surfaceIsWater _k1) && {[_a, _k1] call _acik2} && {[_k1, _b1] call _acik2}) then {
            private _u = (_a distance2D _k1) + (_k1 distance2D _b);
            if (_u < _en) then { _en = _u; };
        };
        private _k2 = _kos select ((_i + 1) % _kor);
        if (!(surfaceIsWater _k1) && {!(surfaceIsWater _k2)} && {[_a, _k1] call _acik2} && {[_k1, _k2] call _acik2} && {[_k2, _b1] call _acik2}) then {
            private _u2 = (_a distance2D _k1) + (_k1 distance2D _k2) + (_k2 distance2D _b);
            if (_u2 < _en) then { _en = _u2; };
        };
    };
    if (_en < 1e9) then { _say set ["bina_kose", (_say getOrDefault ["bina_kose", 0]) + 1]; };
};
if (_en >= 1e9) exitWith {
    _say set ["dolasma_yok", (_say getOrDefault ["dolasma_yok", 0]) + 1];
    [false, 99, "dolasma kordu yok", _ad] call _log
};
private _oran = _en / _d;
_say set ["dolasma_n", (_say getOrDefault ["dolasma_n", 0]) + 1];
_say set ["dolasma_top", (_say getOrDefault ["dolasma_top", 0]) + _oran];
if (_oran > _maks) exitWith {
    _say set ["dolasma_asildi", (_say getOrDefault ["dolasma_asildi", 0]) + 1];
    [false, _oran, format ["dolasma orani > %1", _maks toFixed 1], _ad] call _log
};
[true, _oran, "dolasma", _ad] call _log
