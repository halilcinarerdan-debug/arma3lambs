#include "script_component.hpp"
/*
 * Author: Cinar (ELITE fork)
 * BUDDY / KESKIN NISANCI GORSELLESTIRME (sadece istemci, 3D cizgi + etiket).
 *
 *   - Buddy cifti: asker -> buddy cizgisi (YESIL < 18 m, SARI < 30 m, KIRMIZI daha uzak) + "ROL | 12m"
 *   - Keskin nisanci takimi: MOR cizgi nisanci -> ana komutan + "SNIPER 85m"
 *   - Komutan: beyaz "KOMUTAN" etiketi
 *   Gorulur: yakindaki (350 m) yerel / paylasilmis buddy degiskenleri olan AI'lar.
 *   Acma / kapama: debug konsolunda  lambs_danger_buddyDebug = true / false
 *   Varsayilan: LAMBS debug fonksiyonlari aciksa (lambs_main_debug_Functions) acik.
 *
 * Arguments:
 * None
 *
 * Return Value:
 * Baslatildi mi <BOOL>
 *
 * Public: No
*/

if (!hasInterface) exitWith {false};
if (!isNil "lambs_danger_buddyDebugStarted") exitWith {false};
lambs_danger_buddyDebugStarted = true;

diag_log "[BUDDY-DEBUG] gorsellestirme hazir (lambs_danger_buddyDebug = true / false)";

addMissionEventHandler ["Draw3D", {
    private _acik = missionNamespace getVariable ["lambs_danger_buddyDebug", missionNamespace getVariable ["lambs_main_debug_Functions", false]];
    if (!(_acik isEqualTo true)) exitWith {};

    private _rolFn = missionNamespace getVariable ["lambs_danger_fnc_getUnitRole", {"RIFLE"}];
    private _yakin = (allUnits select {
        alive _x && {!isPlayer _x} && {isNull objectParent _x} && {(_x distance player) < 350}
    });
    if ((count _yakin) > 60) then { _yakin = _yakin select [0, 60]; };

    {
        private _u = _x;
        private _p = _u modelToWorldVisual [0, 0, 1.15];
        private _rol = [_u] call _rolFn;
        private _g = group _u;

        if (_g getVariable [QGVAR(sniperTeam), false]) then {
            private _pg = _g getVariable [QGVAR(sniperParent), grpNull];
            private _pl = if (isNull _pg) then {objNull} else {leader _pg};
            if (!isNull _pl && {alive _pl}) then {
                drawLine3D [_p, _pl modelToWorldVisual [0, 0, 1.15], [0.75, 0.25, 0.95, 0.9]];
                drawIcon3D ["", [0.75, 0.25, 0.95, 1], _p vectorAdd [0, 0, 0.45], 0, 0, 0, format ["SNIPER %1m", round (_u distance2D _pl)], 2, 0.034, "PuristaMedium"];
            };
        } else {
            private _b = _u getVariable [QGVAR(buddy), objNull];
            private _etiket = _rol;
            if (!isNull _b && {alive _b}) then {
                private _m = _u distance2D _b;
                private _renk = if (_m < 18) then {[0.2, 0.9, 0.2, 0.9]} else {
                    if (_m < 30) then {[0.95, 0.85, 0.1, 0.9]} else {[0.95, 0.15, 0.15, 0.95]}
                };
                drawLine3D [_p, _b modelToWorldVisual [0, 0, 1.15], _renk];
                _etiket = format ["%1 | %2m", _rol, round _m];
            } else {
                _etiket = format ["%1 | buddy YOK", _rol];
            };
            if (_u isEqualTo (leader _g)) then { _etiket = "KOMUTAN | " + _etiket; };
            drawIcon3D ["", [1, 1, 1, 0.9], _p vectorAdd [0, 0, 0.35], 0, 0, 0, _etiket, 2, 0.03, "PuristaMedium"];
        };
    } forEach _yakin;
}];

true
