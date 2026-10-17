#include "script_component.hpp"
/*
 * Author: Cinar (ELITE fork)
 * ARAC YOLCU KOY (v8.240) — askeri aracin bos DUZ cargo koltuguna (arkadan baslayarak) oturtur; FFV koltuguna ASLA oturtmaz (moveInCargo _v ilk FFV koltugunu secerdi; bkz. fnc_aracDuzBos).
 * Duz koltuk yoksa hicbir sey yapmaz ve false doner.
 *
 * Arguments:
 * 0: Asker <OBJECT>
 * 1: Arac <OBJECT>
 *
 * Return Value: oturtuldu mu <BOOL>
 * Public: No
*/

params [["_u", objNull, [objNull]], ["_v", objNull, [objNull]]];

if (isNull _u || {isNull _v}) exitWith {false};
private _bos = (fullCrew [_v, "", true]) select { ((toLower (_x select 1)) isEqualTo "cargo") && {isNull (_x select 0)} };
if (_bos isEqualTo []) exitWith {false};
_u moveInCargo [_v, (_bos select ((count _bos) - 1)) select 2];
true
