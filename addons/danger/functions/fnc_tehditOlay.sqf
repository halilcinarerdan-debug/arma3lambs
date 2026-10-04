#include "script_component.hpp"
/*
 * Author: Cinar (ELITE fork)
 * ROKET DUSTU / DUMAN ATILDI TEPKISI (v8.83) — kullanici: "araci icindeki personel rokete tepki vermedi, yanina roket dustu ama kimse COMBAT'a gecmedi" + "smoke'u tehdit saymiyorlar".
 *
 * ROKET (roketatar / fuze dustugu nokta, yerel dusman gruplari): 70 m icindeki herhangi bir asker (ARAC MURETTEBATI DAHIL) -> grup COMBAT, grup temas isareti (15 sn), aticiya kismi bilgi (reveal 0.5 / yakin 0.8),
 *   25 m icindeki piyade 3 sn yere yatar, aracin silahcisi / komutani atici yone doWatch (hata payi 25 m).
 * DUMAN (dusman tarafin duman bombasi / 40 mm duman): 250 m icindeki gruplarin lideri -> grup AWARE ise COMBAT (savas haline gec: duman = gorus kesme / yaklasma / hareket ortusu isareti), temas isareti (10 sn), aticiya reveal 0.4.
 *   Doktrin (genel ilke, kaynakli degil): duman gorus kesmenin ya da ilerlemenin onsinyalidir -> tehdit sayilir. YANGIN / yanan arac farkindaligi BU surumde YOK (guvenilir komut dogrulanamadi).
 * Grup basina 8 sn bekleme. Oyuncu liderli gruba dokunmaz. Kapatma: lambs_danger_tehditOlayOff = true.   Log: [TEHDIT-OLAY] (ilk 80)
 *
 * Arguments:
 * 0: Mod <STRING> "ROKET" | "DUMAN"
 * 1: Konum <ARRAY>
 * 2: Atici tarafi <SIDE>
 * 3: Atici <OBJECT>
 *
 * Return Value: Tepki veren grup sayisi <NUMBER>
 * Public: No
*/

params [["_mod", "", [""]], ["_poz", [0,0,0], [[]]], ["_taraf", sideUnknown, [sideUnknown]], ["_atici", objNull, [objNull]]];
if (missionNamespace getVariable ["lambs_danger_tehditOlayOff", false]) exitWith {0};
if (_poz isEqualTo [0,0,0] || {_taraf isEqualTo sideUnknown}) exitWith {0};
if (isNil "lambs_danger_tehditLogN") then { lambs_danger_tehditLogN = 0; };

private _sayi = 0;
{
    private _g = _x;
    if (isNull _g || {!local _g}) then { continue };
    if ((_taraf getFriend (side _g)) >= 0.6 || {(side _g) isEqualTo civilian}) then { continue };
    private _l = leader _g;
    if (isNull _l || {!alive _l} || {isPlayer _l}) then { continue };
    if ((time - (_g getVariable [QGVAR(tehditT), -999])) < 8) then { continue };

    private _yakin = 9999;
    {
        if (alive _x) then { _yakin = _yakin min (_x distance2D _poz); };
    } forEach (units _g);
    private _esik = [70, 250] select (_mod isEqualTo "DUMAN");
    private _mesafe = [_yakin, _l distance2D _poz] select (_mod isEqualTo "DUMAN");
    if (_mesafe > _esik) then { continue };

    _g setVariable [QGVAR(tehditT), time];
    _sayi = _sayi + 1;
    private _eskiBeh = behaviour _l;
    if (_eskiBeh in ["SAFE", "CARELESS", "AWARE", "STEALTH"]) then { _g setBehaviour "COMBAT"; };
    _g setVariable [QGVAR(contact), ((time + ([15, 10] select (_mod isEqualTo "DUMAN"))) max (_g getVariable [QGVAR(contact), 0]))];
    private _yakinHit = _mod isEqualTo "ROKET" && {_yakin <= 25};
    if (!isNull _atici && {alive _atici}) then {
        _g reveal [_atici, [[0.5, 0.8] select _yakinHit, 0.4] select (_mod isEqualTo "DUMAN")];
    };
    if (_mod isEqualTo "ROKET") then {
        private _tp = if (!isNull _atici && {alive _atici}) then { (getPosATL _atici) getPos [random 25, random 360] } else { [0,0,0] };
        {
            private _u = _x;
            if (!alive _u) then { continue };
            if (!isNull objectParent _u) then {
                if (_tp isNotEqualTo [0,0,0] && {(_u isEqualTo (gunner (vehicle _u))) || {_u isEqualTo (commander (vehicle _u))}}) then { _u doWatch _tp; };
            } else {
                if ((_u distance2D _poz) <= 25 && {!(_u getVariable [QGVAR(forceMove), false])} && {(_u getVariable [QGVAR(taktikKilit), 0]) <= time}) then {
                    _u setUnitPos "DOWN";
                    [{ params ["_p"]; if (alive _p) then { _p setUnitPos "AUTO"; }; }, [_u], 3] call CBA_fnc_waitAndExecute;
                };
            };
        } forEach (units _g);
    };
    if (lambs_danger_tehditLogN < 80) then {
        lambs_danger_tehditLogN = lambs_danger_tehditLogN + 1;
        diag_log format ["[TEHDIT-OLAY] %1 | %2 | %3 | en yakin asker %4 m | arac muretttebati:%5 | beh %6 -> COMBAT | atici:%7", _mod, groupId _g, _taraf, round _yakin, ((units _g) findIf {alive _x && {!isNull objectParent _x}}) > -1, _eskiBeh, if (isNull _atici) then {"?"} else {name _atici}];
    };
} forEach allGroups;
_sayi
