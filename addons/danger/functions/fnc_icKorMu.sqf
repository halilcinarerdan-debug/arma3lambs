#include "script_component.hpp"
/*
 * Author: Cinar (ELITE fork)
 * BINA ICI KOR MU (v8.617): asker bina ICINDE ve dusmana gorus hatti (FIRE LOD) kapaliysa (duvar / kapi / zemin arada) TRUE.
 * Bu durumda namlu dusmana / sese cevrilmez, hedef alma / ates komutu verilmez (kullanici: 'bakis yonu kusursuz olsun').
 * CBA lambs_danger_icBakisKose kapaliysa daima FALSE (eski davranis).
 *
 * Arguments:
 * 0: Asker <OBJECT>
 * 1: Dusman <OBJECT>
 *
 * Return Value: Bina ici ve duvar arkasi mi <BOOL>
 * Public: No
*/

params [["_u", objNull, [objNull]], ["_e", objNull, [objNull]]];
if (isNull _u || {isNull _e}) exitWith {false};
(missionNamespace getVariable ["lambs_danger_icBakisKose", true])
    && {(insideBuilding _u) > 0.5}
    && {(lineIntersectsSurfaces [eyePos _u, aimPos _e, _u, _e, true, 1, "FIRE", "NONE"]) isNotEqualTo []}
