#include "script_component.hpp"
/*
 * Author: Cinar (ELITE fork)
 * YEDEK SIPER / IKI SICRAMALI BIREYSEL ON PLAN (v8.735; kullanici: '1 2 3 yap'; madde 3): asker siper A'ya gonderilirken, A'nin 4-12 m cevresinde dusmandan ayni sekilde gizli ikinci bir nesne arkasi (B) onceden secilir ve
 * askerin degiskenine yazilir (acikSiperYedek, 60 sn). Asker tekrar siper aramak zorunda kalirsa (dusman acti / hat degisti) once B kontrol edilir (hala gizli, dolu degil, yakin): gecerliyse dogrudan oraya gider
 * (yeniden secim / hesap gidip-gelmesi azalir). B: nesnenin dusmandan uzak tarafi (0.05 m arka), A'dan en az 4 m uzak, dusmana A'dan 4 m'den fazla yaklasmaz; en yakin (A'dan) aday.
 *
 * Arguments:
 * 0: Asker <OBJECT>
 * 1: Dusman <OBJECT>
 * 2: Secilen siper A (AGL) <ARRAY>
 *
 * Return Value: B konumu (AGL) ya da [] <ARRAY>
 * Public: No
*/

params [["_u", objNull, [objNull]], ["_en", objNull, [objNull]], ["_a", [], [[]]]];
if (isNull _u || {isNull _en} || {(count _a) < 2}) exitWith {[]};
private _eASL = eyePos _en;
private _dA = _a distance2D _en;
private _best = [];
private _bestD = 1e9;
{
    private _o = _x;
    private _op = getPosATL _o;
    private _bb = boundingBoxReal _o;
    private _yk = ((_bb select 1) select 2) - ((_bb select 0) select 2);
    if (_yk < 0.8) then { continue };
    private _rr = (((((_bb select 1) select 0) - ((_bb select 0) select 0)) max (((_bb select 1) select 1) - ((_bb select 0) select 1))) / 2) min 2.5;
    private _bp = _op getPos [_rr + 0.05, _en getDir _o];
    private _dAB = _bp distance2D _a;
    if (surfaceIsWater _bp || {_dAB < 4} || {_dAB > 12} || {(_bp distance2D _en) < (_dA - 4)}) then { continue };
    private _gA = AGLToASL [_bp select 0, _bp select 1, 0];
    if ((lineIntersectsSurfaces [_eASL, _gA vectorAdd [0, 0, 1.0], _en, _u, true, 1, "FIRE", "NONE"]) isEqualTo []) then { continue };
    if (_dAB < _bestD) then { _bestD = _dAB; _best = _bp; };
} forEach (nearestTerrainObjects [_a, ["TREE", "ROCK", "ROCKS", "WALL", "HIDE"], 14, true, true]);
_best
