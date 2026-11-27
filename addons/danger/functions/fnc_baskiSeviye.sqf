#include "script_component.hpp"
/*
 * Author: Cinar (ELITE fork)
 * BASKI SEVIYESI (v8.838; kullanici: 'smooth olsun, celismesin, sizofren olmasin, proje tutarli olsun'; mimari tarama: getSuppression 82 dosyada 154 yerde 17 FARKLI esikle okunuyordu -> ayni asker bir yerde 'bastirilmis', baska yerde degil):
 * TEK TANIM: etkin baski (fnc_baskiEf = motor baskisi + yakin mermi korkusu x0.7) 0..4 SEVIYEYE cevrilir:
 *   0 YOK (< 0.15) | 1 HAFIF (0.15-0.35) | 2 ORTA (0.35-0.5) | 3 AGIR (0.5-0.7) | 4 ASIRI (>= 0.7)
 * Tuketici kurali: '[_u] call FUNC(baskiSeviye) >= N' (N = 1..4). Eski ham esikler en yakin sinira tasindi: 0.05-0.2 -> 1, 0.25-0.4 -> 2, 0.45-0.6 -> 3, >= 0.7 -> 4 (tasarim; DURUM_SOZLESMESI.md).
 * Birim basina 0.3 sn onbellek (cok cagrida kararlar ayni kareyi gorur: tutarlilik + ucuz).
 * Arguments: 0: Asker <OBJECT> | Return Value: Seviye (0-4) <NUMBER> | Public: No
*/
params [["_u", objNull, [objNull]]];
if (isNull _u) exitWith {0};
private _c = _u getVariable [QGVAR(baskiSevC), [-99, 0]];
if ((time - (_c select 0)) < 0.3) exitWith {_c select 1};
private _b = [_u] call FUNC(baskiEf);
private _l = if (_b >= 0.7) then {4} else { if (_b >= 0.5) then {3} else { if (_b >= 0.35) then {2} else { if (_b >= 0.15) then {1} else {0} } } };
_u setVariable [QGVAR(baskiSevC), [time, _l]];
_l
