#include "script_component.hpp"
/*
 * Author: Cinar (ELITE fork)
 * TANK KORUMA (v8.251, "koru" modu) — kullanici: "tank-piyade koruma". Dusman AT unsuru (roketatarli piyade / ATGM'li arac / ATGM statik) tanka yakin oldugunda ya da tank AT atesi aldiginda,
 * tankin yakinindaki DOST PIYADE gruplari AT avcisi gibi tehdide ates eder (tank-piyade ekibi: piyade tanki yakin AT tehdidinden korur, tank piyadeyi agir silahla destekler; FM 3-90-1 / ATP 3-20.15 yakin emniyet ilkesi — kitapta SAYI yok).
 * Kural (grup basina 20 sn bekleme; yerel, oyuncusuz gruplar; araca binmis lider / geri cekilen / temas kesen gruplar haric; lider tankin <= 400 m'sinde ya da tehdidin <= 350 m'sinde):
 *   - tehdit nesnesi biliniyorsa gruba reveal 1.2 (komsu gruplara 'bunu gorun'), 12 sn grup temas isareti
 *   - tehdit PIYADE ise <= 8 asker doWatch + doTarget + doFire; tehdit ZIRHLI arac ise yalniz AT'li askerler (isATUnit) hedefler, digerleri sadece bakar (tufekle tank dovulmez)
 *   - tehdit nesnesi yoksa (yalniz yon) 8 askere doSuppressiveFire (tehdit konumu); 8 sn sonra doWatch temizlenir
 * Bu surum piyadeyi tankin yanina HAREKET ETTIRMEZ (plan / buddy sistemiyle cakisma riski; "yakin emniyet konumu" ayri is). Kapatma: lambs_danger_tankKoruOff = true.  Log: [TANK-KORU] (ilk 60).
 *
 * Arguments:
 * 0: Korunan arac <OBJECT>
 * 1: Tehdit konumu <ARRAY> (bos olabilir)
 * 2: Tehdit nesnesi <OBJECT> (bos olabilir)
 *
 * Return Value: Tepki veren grup sayisi <NUMBER>
 * Public: No
*/

params [["_v", objNull, [objNull]], ["_poz", [], [[]]], ["_atici", objNull, [objNull]]];
if (isNull _v || {!alive _v} || {missionNamespace getVariable ["lambs_danger_tankKoruOff", false]}) exitWith {0};
private _d = driver _v;
if (isNull _d) exitWith {0};
private _tf = side (group _d);
if (!isNull _atici && {alive _atici}) then { _poz = getPosATL _atici; };
if (_poz isEqualTo []) exitWith {0};
private _zirhli = !isNull _atici && {!(_atici isKindOf "CAManBase")} && {(getNumber (configOf _atici >> "armor")) >= 120};
if (isNil "lambs_danger_tankKoruLogN") then { lambs_danger_tankKoruLogN = 0; };

private _grN = 0;
private _askN = 0;
{
    private _gr = _x;
    if (isNull _gr || {!local _gr} || {(side _gr) isNotEqualTo _tf} || {_gr isEqualTo (group _d)}) then { continue };
    private _l = leader _gr;
    if (isNull _l || {!alive _l} || {isPlayer _l} || {!isNull objectParent _l}) then { continue };
    if (((units _gr) findIf {isPlayer _x}) >= 0) then { continue };
    if ((_l distance2D _v) > 400 && {(_l distance2D _poz) > 350}) then { continue };
    if ((time - (_gr getVariable [QGVAR(tankKoruT), -999])) < 20) then { continue };
    if ((_gr getVariable [QGVAR(isRetreating), false]) || {_gr getVariable [QGVAR(isBreakingContact), false]}) then { continue };
    private _uy = (units _gr) select {alive _x && {isNull objectParent _x} && {(lifeState _x) in ["HEALTHY", "INJURED"]} && {(_x distance2D _poz) < 600}};
    if ((count _uy) < 2) then { continue };
    if ((count _uy) > 8) then { _uy = _uy select [0, 8]; };

    _gr setVariable [QGVAR(tankKoruT), time];
    _gr setVariable [QGVAR(contact), ((time + 12) max (_gr getVariable [QGVAR(contact), 0]))];
    if (!isNull _atici && {alive _atici}) then { _gr reveal [_atici, 1.2]; };
    {
        private _u = _x;
        if (!isNull _atici && {alive _atici}) then {
            _u doWatch _atici;
            if (!_zirhli || {[_u] call FUNC(isATUnit)}) then { _u doTarget _atici; _u doFire _atici; };
        } else {
            _u doWatch _poz;
            _u doSuppressiveFire _poz;
        };
    } forEach _uy;
    [{ params ["_us"]; { if (alive _x) then { _x doWatch objNull; }; } forEach _us; }, [_uy], 8] call CBA_fnc_waitAndExecute;
    _grN = _grN + 1;
    _askN = _askN + (count _uy);
} forEach allGroups;

if (_grN > 0 && {lambs_danger_tankKoruLogN < 60}) then {
    lambs_danger_tankKoruLogN = lambs_danger_tankKoruLogN + 1;
    diag_log format ["[TANK-KORU] %1 (%2) | tehdit %3 (%4 m, %5) | %6 piyade grubu / %7 asker tehdide ates / bakis | zirhli tehdit (yalniz AT'liler hedefler): %8",
        getText (configOf _v >> "displayName"), groupId (group _d), if (isNull _atici) then {"yon"} else {typeOf _atici}, round (_v distance2D _poz), mapGridPosition _poz, _grN, _askN, _zirhli];
};
_grN
