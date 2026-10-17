#include "script_component.hpp"
/*
 * Author: Cinar (ELITE fork)
 * MEVZIDE MI (v8.243) — grup su an HENDEKTE / mevzide mi? (SAVUN plani hendege yerlestirdiyse ya da hendek bilinci siginma durumundaysa)
 * Neden (RPT c7592408, kullanici: "trenchden cok ayriliyorlar"): LAMBS komutan beyni (DELAY -> hide / FLANK / ASSAULT / HOLD -> 'Hide (holding)'), buddy bagi, dagilma ve rol istasyonu
 * hendekteki gruplari da yeniden gorevlendirip hendekten cikariyordu. Bu fonksiyon o sistemlerin "mevzideki gruba dokunma" kosulunu tek yerde toplar.
 * Kapatma: lambs_danger_mevziTutOff = true (false doner -> eski davranis).
 *
 * Arguments:
 * 0: Grup <GROUP>
 *
 * Return Value: mevzide mi <BOOL>
 * Public: No
*/

params [["_g", grpNull, [grpNull]]];
if (isNull _g || {missionNamespace getVariable ["lambs_danger_mevziTutOff", false]}) exitWith {false};
(_g getVariable [QGVAR(hendekB), []]) isNotEqualTo []
|| {(_g getVariable [QGVAR(hendekte), false]) && {_g getVariable ["lambs_danger_planAktif", false]}}
