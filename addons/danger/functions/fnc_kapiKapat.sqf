#include "script_component.hpp"
/*
 * Author: Cinar (ELITE fork)
 * KAPI KAPAT (v8.506): fnc_kapiAc'in actigi kapiyi kapatir; kapinin 6 m yakininda hala asker varsa 10 sn erteler (en cok 6 kez), yoksa kapatir.
 *
 * Arguments:
 * 0: Nesne <OBJECT>
 * 1: Animasyon kaynaklari <ARRAY>
 * 2: Deneme sayisi <NUMBER>
 *
 * Return Value: Yok
 * Public: No
*/

params [["_nesne", objNull, [objNull]], ["_liste", [], [[]]], ["_deneme", 0, [0]]];
if (isNull _nesne) exitWith {};
if (((_nesne nearEntities ["CAManBase", 6]) isNotEqualTo []) && {_deneme < 6}) exitWith {
    [FUNC(kapiKapat), [_nesne, _liste, _deneme + 1], 10] call CBA_fnc_waitAndExecute;
};
{ _nesne animateSource [_x, 0]; } forEach _liste;
