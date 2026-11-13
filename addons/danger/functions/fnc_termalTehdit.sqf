#include "script_component.hpp"
/*
 * Author: Cinar (ELITE fork)
 * TERMAL ARAC TEHDIDI (v8.536; kullanici: 'kamuflaj sistemi arac termallerinde aktif de olmasin').
 * Birimin cevresinde (<= 1500 m) DUSMAN, murettebatli, termal gorus modlu (fnc_termalAraci) bir kara / hava araci var mi? Varsa renk kamuflaji (palet uyumu: gizlenme ve uyumsuzluk) UYGULANMAZ:
 * termal goruntude renk anlamsiz. Birim basina 4 sn onbellekli. Kapatma: CBA paletTermalMuaf = false (muafiyet yok; renk etkisi her zaman).
 *
 * Arguments:
 * 0: Birim <OBJECT>
 *
 * Return Value: Termal arac tehdidi var mi <BOOL>
 *
 * Public: No
*/

params [["_u", objNull, [objNull]]];
if (isNull _u || {!(missionNamespace getVariable ["lambs_danger_paletTermalMuaf", true])}) exitWith {false};
private _on = _u getVariable [QGVAR(termalT), [-99, false]];
if ((time - (_on select 0)) < 4) exitWith {_on select 1};
private _tf = side group _u;
private _r = ((_u nearEntities [["LandVehicle", "Air"], 1500]) findIf {
    alive _x && {_x isNotEqualTo _u} && {(crew _x) findIf {alive _x && {(_tf getFriend (side group _x)) < 0.6} && {(side group _x) isNotEqualTo civilian}} >= 0}
    && {[_x] call FUNC(termalAraci)}
}) >= 0;
_u setVariable [QGVAR(termalT), [time, _r]];
_r
