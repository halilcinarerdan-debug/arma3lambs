#include "script_component.hpp"
/*
 * Author: Cinar (ELITE fork)
 * EMIR KILITLI Mi (v8.838; mimari tarama: doMove 96 dosyada 265 cagri, 25 dosya taktik kilidine / forceMove'a hic bakmiyordu -> refleks / kozmetik katmanlar hayatta kalma ya da komutan emrini eziyordu):
 * HAKEM KURALI (oncelik): HAYATTA KALMA (korku / retreat / temas kes / kacis / forceMove) > KOMUTAN (taktik kilidi) > REFLEKS > KOZMETIK. Refleks / kozmetik katmanlar emir vermeden once bunu sorar.
 * true = bu askere simdi refleks / kozmetik EMIR VERILMEZ: forceMove, taktik kilidi (taktikKilit > time), grup retreat / evade / temas kes, hekim isi (tcccBusy), disableAI, bombaci kosusu, korku alcalmasi (korku >= 0.55 ve < 3 sn).
 * Arguments: 0: Asker <OBJECT> | Return Value: Kilitli mi <BOOL> | Public: No
*/
params [["_u", objNull, [objNull]]];
if (isNull _u) exitWith {true};
private _g = group _u;
((_u getVariable [QGVAR(forceMove), false]) isEqualTo true)
|| {time < (_u getVariable [QGVAR(taktikKilit), 0])}
|| {_g getVariable [QGVAR(isRetreating), false]} || {_g getVariable [QGVAR(isEvading), false]} || {_g getVariable [QGVAR(isBreakingContact), false]}
|| {time < (_u getVariable [QGVAR(tcccBusy), 0])} || {_u getVariable [QGVAR(disableAI), false]} || {(_u getVariable [QGVAR(bombaKosuyor), false]) isEqualTo true}
|| {([_u] call FUNC(korkuDeger)) >= 0.55}
