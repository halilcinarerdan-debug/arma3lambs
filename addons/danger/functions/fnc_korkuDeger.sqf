#include "script_component.hpp"
/*
 * Author: Cinar (ELITE fork)
 * KORKU DEGERI (v8.835): askerin o anki korku (yakin mermi gecisi) degeri 0-1; her olayda artar (fnc_korku), 6 sn zaman sabitiyle ussel azalir.
 * Arguments: 0: Asker <OBJECT>
 * Return Value: Korku degeri (0-1) <NUMBER>
 * Public: No
*/
params [["_u", objNull, [objNull]]];
if (isNull _u) exitWith {0};
private _d = _u getVariable [QGVAR(korkuD), [0, 0]];
if ((_d select 0) <= 0.001) exitWith {0};
((_d select 0) * (exp (-((time - (_d select 1)) max 0) / 6))) min 1
