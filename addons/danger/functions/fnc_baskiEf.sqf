#include "script_component.hpp"
/*
 * Author: Cinar (ELITE fork)
 * ETKIN BASKI (v8.835; kullanici: 'bunun gibi calismayan her seyi duzelt'; RPT 5057c18e / 8dd900cd: grup baskisi en cok 0.25, baski esikli korku davranislari (siper duruşu > 0.35, panik, moral) hic tetiklenmedi): motorun baskisi (getSuppression) ile
 * YAKIN MERMI KORKUSUNUN (fnc_korku) 0.7 ile carpilmis degerinin BUYUGU. Motor baskisi yetersiz kaldiginda (dusman ates edip isabet ettirmiyor / yakindan geciriyor) korku bunun yerine gecer; en cok 0.7.
 * Kullanan: fnc_acikSiper (siper duruşu / zorlama), fnc_panikFelc, fnc_moral.
 * Arguments: 0: Asker <OBJECT>
 * Return Value: Etkin baski (0-1) <NUMBER>
 * Public: No
*/
params [["_u", objNull, [objNull]]];
if (isNull _u) exitWith {0};
(getSuppression _u) max (([_u] call FUNC(korkuDeger)) * 0.7)
