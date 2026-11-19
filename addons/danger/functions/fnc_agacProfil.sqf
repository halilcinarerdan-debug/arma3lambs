#include "script_component.hpp"
/*
 * Author: Cinar (ELITE fork)
 * AGAC MODEL PROFILI (v8.643; kullanici: 'cup objelerine ozel yapmanin bir yolu yok mu raycasti'; harita pmc_ukraine_donetsk, CUP / A2 agaclari t_picea / t_pinus / t_populus_ep1):
 * Agac MODELI basina (onbellek lambs_danger_agacProfilH) bir kez, 3 LOD'da yanal tarama (agac merkezi +-3 m, 0.1 m adim, merkezin 2 m'sindeki isabetler):
 *   FIRE LOD 1.1 m, GEOM LOD 1.1 m (A2 agaclarinda govde carpisma silindiri GEOM'dadir), VIEW LOD 0.4 / 1.0 / 1.6 m (yaprak / dal ortusunun genisligi)
 * Cikti (dizi): [0] govde yaricapi (FIRE, yoksa GEOM, yoksa VIEW 0.4 m; 0.1-1.0 m araligi, yoksa 0.4), [1] FIRE genislik, [2] GEOM genislik, [3] VIEW 0.4 m, [4] VIEW 1.0 m, [5] VIEW 1.6 m, [6] mermi durdurur mu (FIRE >= 0.15 m)
 * Kullanim: govde yaricapi (nesne arkasi noktasi), gizlenme yuksekligi (VIEW genisligi >= 0.3 m olan en yuksek durus; UP 1.6 / MIDDLE 1.0 / DOWN 0.4) - yan isin / tahmin yerine OLCUM.
 * CBA: lambs_danger_agacProfil (varsayilan ACIK; kapali = eski davranis).
 * Log: [AGAC-PROFIL] model | FIRE | GEOM | VIEW 0.4 / 1.0 / 1.6 | govde yaricapi | mermi durdurur (ilk 12 model)
 *
 * Arguments:
 * 0: Agac nesnesi <OBJECT>
 *
 * Return Value: Profil <ARRAY> [r, fire, geom, v04, v10, v16, durdurur]
 * Public: No
*/

params [["_o", objNull, [objNull]]];
if (isNull _o) exitWith {[0.4, 0, 0, 0, 0, 0, false]};
if (isNil "lambs_danger_agacProfilH") then { lambs_danger_agacProfilH = createHashMap; };
private _m = toLower ((getModelInfo _o) select 0);
// v8.643b CBA lambs_danger_agacProfil KAPALIYSA eski davranis: yalniz FIRE LOD 1.1 m taramasi (govde yaricapi 0.2-0.7 m, FIRE yoksa 0.5); VIEW / GEOM olcumu YOK
private _acik = missionNamespace getVariable ["lambs_danger_agacProfil", true];
private _anahtar = [_m + "|eski", _m] select _acik;
private _c = lambs_danger_agacProfilH get _anahtar;
if (!isNil "_c") exitWith {_c};

private _tp = getPosASL _o;
private _tara = {
    params ["_lod", "_h"];
    private _bas = _tp vectorAdd [0, 0, _h];
    // v8.646: IKI eksende tara (RPT c528674a: ayni model t_pinuss2s_f FIRE 0.4 m / 0.0 m, t_pinuss2s_b_f 0.0 m / 0.7 m: tek eksenli tarama ornege / yone gore govdeyi kaciriyordu); en buyuk genislik
    private _nA = 0;
    private _nB = 0;
    for "_i" from -30 to 30 do {
        private _ofs = _i * 0.1;
        private _hA = lineIntersectsSurfaces [_bas vectorAdd [_ofs, -6, 0], _bas vectorAdd [_ofs, 6, 0], objNull, objNull, true, 3, _lod, "NONE"];
        if ((_hA findIf {(((_x select 0) distance2D _tp) < 3) && {(((_x select 2) isEqualTo _o) || {!isNull (_x select 2) && {(toLower ((getModelInfo (_x select 2)) select 0)) isEqualTo _m}})}}) > -1) then { _nA = _nA + 1; };
        private _hB = lineIntersectsSurfaces [_bas vectorAdd [-6, _ofs, 0], _bas vectorAdd [6, _ofs, 0], objNull, objNull, true, 3, _lod, "NONE"];
        if ((_hB findIf {(((_x select 0) distance2D _tp) < 3) && {(((_x select 2) isEqualTo _o) || {!isNull (_x select 2) && {(toLower ((getModelInfo (_x select 2)) select 0)) isEqualTo _m}})}}) > -1) then { _nB = _nB + 1; };
    };
    (_nA max _nB) * 0.1
};
private _fire = ["FIRE", 1.1] call _tara;
private _geom = 0;
private _v04 = 0;
private _v10 = 0;
private _v16 = 0;
if (_acik) then {
    _geom = ["GEOM", 1.1] call _tara;
    _v04 = ["VIEW", 0.4] call _tara;
    _v10 = ["VIEW", 1.0] call _tara;
    _v16 = ["VIEW", 1.6] call _tara;
};
// v8.651 BIRLESTIR (RPT aff9b168 / d6ee1c87: ayni model kosudan kosuya 0.0 <-> 0.7 m: tek ornekten olcum guvenilmez): ayni modelin ilk 3 ornegi olculur, her alanin EN BUYUK degeri alinir; 3. ornekte onbellege yazilir
private _acc = lambs_danger_agacProfilH getOrDefault [_anahtar + "#acc", [0, 0, 0, 0, 0]];
_fire = _fire max (_acc select 0);
_geom = _geom max (_acc select 1);
_v04 = _v04 max (_acc select 2);
_v10 = _v10 max (_acc select 3);
_v16 = _v16 max (_acc select 4);
lambs_danger_agacProfilH set [_anahtar + "#acc", [_fire, _geom, _v04, _v10, _v16]];
private _r = 0.4;
if (_acik) then {
    {
        private _rr = _x / 2;
        if (_rr >= 0.1 && {_rr <= 1.0}) exitWith { _r = _rr; };
    } forEach [_fire, _geom, _v04];
} else {
    _r = if (_fire <= 0) then {0.5} else { ((_fire / 2) max 0.2) min 0.7 };
};
// v8.655 GENIS GEOMETRILI AGAC (ladin t_picea2s: RPT 77e57bce FIRE 5.6 m / GEOM 3.0 m / VIEW 0.0 m; ekran goruntusu: asker dal etegi geometrisinin ~1 m DISINDA yatiyor - geometriye giremiyor): GEOM genisligi >= 1.5 m ise hedef govde degil GEOMETRI KENARI: yaricap = GEOM / 2 + 0.1 (<= 2.5 m)
if (_acik && {_geom >= 1.5}) then { _r = ((_geom / 2) + 0.1) min 2.5; };
private _p = [_r, _fire, _geom, _v04, _v10, _v16, _fire >= 0.45];   // v8.672: 0.15 -> 0.45 m (ince govde mermi durdurmaz)
private _n = (lambs_danger_agacProfilH getOrDefault [_anahtar + "#n", 0]) + 1;
lambs_danger_agacProfilH set [_anahtar + "#n", _n];
if (_n < 3) exitWith { _p };
lambs_danger_agacProfilH set [_anahtar, _p];
if ((count lambs_danger_agacProfilH) <= 40) then {
    diag_log format ["[AGAC-PROFIL] %1 | FIRE %2 m | GEOM %3 m | VIEW 0.4 m %4 / 1.0 m %5 / 1.6 m %6 | govde yaricapi %7 m | mermi durdurur %8 | 3 ornegin en buyugu", _m, _fire toFixed 1, _geom toFixed 1, _v04 toFixed 1, _v10 toFixed 1, _v16 toFixed 1, _r toFixed 2, _fire >= 0.15];
};
_p
