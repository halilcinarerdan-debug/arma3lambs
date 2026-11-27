#include "script_component.hpp"
/*
 * Author: Cinar (ELITE fork)
 * TEMAS SEVIYESI (v8.838; mimari tarama: temas yasi 13 FARKLI sn esigiyle (6-600) okunuyordu): grubun temas damgasindan (QGVAR(contact); gelecek zaman = su an temasta) TEK TANIM:
 *   0 TAZE (temasta ya da <= 8 sn once) | 1 SICAK (<= 30 sn) | 2 ILIK (<= 120 sn) | 3 SOGUK (> 120 sn / hic)
 * Tuketici kurali: '[_g] call FUNC(temasSeviye) <= N' (N = 0..2 = temasli say). Eski sn esikleri: <= 12 -> 0, 15-45 -> 1, 60-120 -> 2, > 120 -> 3.
 * Arguments: 0: Grup | Return Value: Seviye (0-3) <NUMBER> | Public: No
*/
params [["_g", grpNull, [grpNull, objNull]]];
if (_g isEqualType objNull) then { _g = group _g; };
if (isNull _g) exitWith {3};
private _y = time - (_g getVariable [QGVAR(contact), -9999]);
if (_y <= 8) exitWith {0};
if (_y <= 30) exitWith {1};
if (_y <= 120) exitWith {2};
3
