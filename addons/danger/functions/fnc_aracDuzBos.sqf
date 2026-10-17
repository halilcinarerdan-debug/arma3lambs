#include "script_component.hpp"
/*
 * Author: Cinar (ELITE fork)
 * ARAC DUZ BOS KOLTUK (v8.240) — bir kara aracindaki BOS DUZ cargo koltuk sayisi (FFV / personTurret koltuklari SAYILMAZ).
 * Neden (A/B testi, kullanici RPT eb4c3abb): RHS Stryker'da yolcu FFV (turret) koltuguna oturunca arac (ELITE kapaliyken de) SURUCUYE VERILEN EMRE UYMUYOR (0 m, motor kapanabiliyor);
 * yolcu yalniz DUZ cargo koltugundaysa (1 ya da 4 yolcu) normal gidiyor. emptyPositions "cargo" FFV koltuklarini da sayar (Stryker: 9 = 6 duz + 3 FFV) ve moveInCargo ilk FFV koltuguna oturtur.
 * FFV'si olmayan araclarda emptyPositions "cargo" ile ayni deger doner.
 *
 * Arguments:
 * 0: Arac <OBJECT>
 *
 * Return Value: bos duz cargo koltuk sayisi <NUMBER>
 * Public: No
*/

params [["_v", objNull, [objNull]]];

if (isNull _v) exitWith {0};
{ ((toLower (_x select 1)) isEqualTo "cargo") && {isNull (_x select 0)} } count (fullCrew [_v, "", true])
