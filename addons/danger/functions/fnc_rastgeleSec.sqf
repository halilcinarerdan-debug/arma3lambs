#include "script_component.hpp"
/*
 * Author: Cinar (ELITE fork)
 * TOHUMLU SECIM (v8.501): selectRandom'un tohumlu karsiligi; bkz. fnc_rastgele. Dizi bossa nil / [] donmez, objNull degil: bos dizide exitWith {nil} yerine yedek olarak selectRandom (hata vermez).
 *
 * Arguments:
 * 0: Dizi <ARRAY>
 * 1: Etiket (sistem) <STRING>
 * 2: Baglam (grup kimligi, hedef vb.) <STRING>
 * 3: Sayac kullan <BOOL> (varsayilan false: durumsuz, ayni baglam = ayni secim)
 *
 * Return Value: secilen eleman
 * Public: No
*/

params [["_dizi", [], [[]]], ["_etiket", "", [""]], ["_baglam", "", [""]], ["_say", false, [true]]];
private _n = count _dizi;
if (_n isEqualTo 0) exitWith { selectRandom _dizi };
_dizi select (floor (([_etiket, _baglam, _say] call FUNC(rastgele)) * _n) min (_n - 1))
