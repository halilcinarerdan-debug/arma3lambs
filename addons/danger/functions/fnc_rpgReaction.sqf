#include "script_component.hpp"
/*
 * Author: Cinar (ELITE fork)
 * RPG / ROKETATAR ATESINE TEPKI (anti-tank launcher reaction drill) — formasyonu BOZMADAN ek onlem.
 *
 * DOKTRIN (FM 3-21.8 / ATP 3-21.8, "react to RPG / antiarmor fire"):
 *   1) Siper al (ALCAK dur) — roket tek atimlik, ikinci atis icin yeniden dolum 4-8 sn surer
 *   2) ONCELIKLI BASKI ATESI: roketatar ekibi birincil hedeftir -> tufek + MG o noktaya ates eder
 *      (yeniden doldurmasini engelle). Atici gorulmediyse son atis yonune bastir
 *   3) DAGIL: kume halinde durma (tek roket tum ekibi vurmasin); ~6-8 m yana acil, formasyonu terk ETME
 *      (MG'ler yerinde kalir ve ates sagladigi icin sadece kisa mesafe kayar)
 *   4) Gorus kes: atici 60 m'den uzaksa sis (BREAK_CONTACT) atilir
 *   5) 6 sn sonra normal formasyon takibine donulur (doFollow)
 *
 * Grup basina 20 sn cooldown. Oyuncu iceren / oyuncu liderli gruba dokunmaz.
 * KAPATMA ANAHTARI: lambs_danger_rpgReactionOff = true      RPT: [RPG-TEPKI]
 *
 * Arguments:
 * 0: roketatar atici <OBJECT>
 *
 * Return Value:
 * Tepki veren grup sayisi <NUMBER>
 *
 * Public: No
*/

params [["_atici", objNull, [objNull]]];
if (isNull _atici || {!alive _atici}) exitWith {0};
if (missionNamespace getVariable ["lambs_danger_rpgReactionOff", false]) exitWith {0};

private _aSide = side group _atici;
private _aPos = getPosATL _atici;
private _rolFn = missionNamespace getVariable ["lambs_danger_fnc_getUnitRole", {"RIFLE"}];
private _sayi = 0;

{
    private _g = _x;
    if (isNull _g || {!local _g}) then { continue };
    if ((_aSide getFriend (side _g)) >= 0.6) then { continue };
    private _l = leader _g;
    if (isNull _l || {!alive _l} || {isPlayer _l} || {!isNull objectParent _l}) then { continue };
    if (((units _g) findIf {isPlayer _x}) > -1) then { continue };
    if (time < (_g getVariable [QGVAR(rpgReactT), 0])) then { continue };

    private _uyeler = (units _g) select {
        alive _x && {isNull objectParent _x} && {(lifeState _x) in ["HEALTHY", "INJURED"]} && {(_x distance2D _aPos) < 450}
    };
    if (_uyeler isEqualTo []) then { continue };
    // gruba yeterince yakin ve atici gorus / bilgi icinde mi
    private _yakin = _uyeler findIf {
        (_x distance2D _aPos) < 180 || {(_x knowsAbout _atici) > 0.5}
    };
    if (_yakin < 0) then { continue };

    _g setVariable [QGVAR(rpgReactT), time + 20];
    _sayi = _sayi + 1;

    private _tehdit = _aPos;
    private _merkez = getPosATL _l;
    private _yon = _merkez getDir _tehdit;

    {
        private _u = _x;
        private _rol = [_u] call _rolFn;
        _u reveal [_atici, 1.5];   // tam bilgi (4) degil: roketin geldigi yon bilinir, kesin konum degil
        _u setVariable [QGVAR(hugT), time + 8];

        // 2) oncelikli baski: AT roketatar ekibine tufek + MG
        _u doWatch _atici;
        _u doTarget _atici;
        _u doFire _atici;

        // 1) alcal
        _u setUnitPosWeak "DOWN";

        // 3) dagil — yan yone kisa kayis (MG daha kisa)
        private _kayis = if (_rol isEqualTo "MG") then { 3.5 } else { 6 + (random 2) };
        private _taraf = selectRandom [90, -90];
        // en yakin dostun uzaginda olan tarafi sec
        private _yakinDost = (_u nearEntities ["CAManBase", 7]) select {_x isNotEqualTo _u && {alive _x} && {(group _x) isEqualTo _g}};
        if (_yakinDost isNotEqualTo []) then {
            private _dp = getPosATL (_yakinDost select 0);
            private _bir = _u getPos [3, _yon + 90];
            private _iki = _u getPos [3, _yon - 90];
            _taraf = [-90, 90] select ((_bir distance2D _dp) > (_iki distance2D _dp));
        };
        private _hedefYer = (getPosATL _u) getPos [_kayis, _yon + _taraf];
        if (!surfaceIsWater _hedefYer) then {
            // yeni nokta atici ile arada engel varsa (duvar / agac) zaten daha iyi; dosdogru dostun ustune binmesin
            _u doMove _hedefYer;
        };
    } forEach _uyeler;

    // 6 sn sonra normal formasyon takibi
    [{
        params ["_gr", "_uy"];
        {
            if (alive _x) then {
                _x setUnitPos "AUTO";
                _x doWatch objNull;
                _x doFollow (leader _gr);
            };
        } forEach _uy;
    }, [_g, _uyeler], 6] call CBA_fnc_waitAndExecute;

    // 4) gorus kes: atici uzaksa sis perdesi
    if ((_merkez distance2D _tehdit) > 60) then {
        [_g, _atici, "BREAK_CONTACT"] call (missionNamespace getVariable ["lambs_danger_fnc_tacticalSmoke", {false}]);
    };

    diag_log format ["[RPG-TEPKI] %1 | atici %2 (%3 m) | %4 asker: oncelikli ates + dagilma (formasyon korunuyor)", groupId _g, name _atici, round (_merkez distance2D _tehdit), count _uyeler];
} forEach allGroups;

_sayi
