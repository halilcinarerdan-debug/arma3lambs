#include "script_component.hpp"
/*
 * Author: Cinar (ELITE fork)
 * ARKA GUVENLIK (REAR SECURITY) — CQB ve YOGUN URBAN'da bir asker grubun ARKASINI kollar.
 *
 * DOKTRIN (FM 3-21.8 / urban operasyon): bina / sokak temizlerken ekibin arkasi acik kalir; son siradaki
 * asker "rear security" olarak geriye bakar, ekip ilerledikce arkada kalir (360 derece guvenlik).
 *
 * SECIM (ZORUNLU DEGIL — sadece EKSTRA KADRO varsa):
 *   - grupta >= 6 canli asker VE >= 3 SADE TUFEKLI aday (secilince gruptan en az 2 tufekli kalir)
 *   - aday: yerel bot, rol "RIFLE" (MG / AT / nisanci / saglikci DEGIL), bombaatar (UGL) DEGIL,
 *     lider DEGIL, takim lideri / astsubay (rank SERGEANT ve ustu) DEGIL, yarali degil
 *   - mevcut gorevli (stationPos / forceMove / baskida) askere dokunulmaz; secilen asker grupta kalici tutulur
 *
 * AKTIF OLMA: yogun urban (80 m'de >= 8 bina) veya lider bina icinde / dusman < 50 m + urban (>= 5 bina);
 *   VE (temasli son 90 sn ya da lider hareket halinde). Cekilme / evade / temas kes / sniper takimi: atlanir.
 *
 * DAVRANIS: liderin ARKASINDA (on yonun tersi) 9 m'de durur, MIDDLE stance, 30 m geriye BAKAR (doWatch);
 *   lider > 6 m kayinca (en az 8 sn arayla) yeni noktaya gider -> spam / dur-kalk yok.
 *   Aktiflik bitince (20 sn) doFollow ile gruba doner.
 *
 * Arguments:
 * None
 *
 * Return Value:
 * Baslatildi mi <BOOL>
 *
 * Public: No
*/

if (!isNil "lambs_danger_rearGuardStarted") exitWith {false};
lambs_danger_rearGuardStarted = true;

diag_log "[ARKA-GUVENLIK] arka guvenlik watchdog baslatildi (CQB / yogun urban, ekstra kadro varsa sade tufekli)";

[] spawn {
    private _rolFn = missionNamespace getVariable ["lambs_danger_fnc_getUnitRole", {"RIFLE"}];
    private _glFn  = missionNamespace getVariable ["lambs_danger_fnc_hasUGL", {""}];

    private _birak = {
        params ["_g", "_u"];
        if (!isNull _u && {alive _u}) then {
            _u setVariable [QGVAR(stationPos), nil];
            _u doWatch objNull;
            _u setUnitPos "AUTO";
            _u doFollow (leader _u);
        };
        _g setVariable [QGVAR(rearGuardU), objNull];
        _g setVariable [QGVAR(rearGuardPos), nil];
    };

    while {true} do {
        sleep 3;
        {
            private _g = _x;
            if (isNull _g || {!local _g}) then { continue };
            private _l = leader _g;
            private _u = _g getVariable [QGVAR(rearGuardU), objNull];

            private _gec = isNull _l || {!alive _l} || {isPlayer _l} || {!isNull objectParent _l}
                || {_g getVariable [QGVAR(isRetreating), false]} || {_g getVariable [QGVAR(isEvading), false]}
                || {_g getVariable [QGVAR(isBreakingContact), false]} || {_g getVariable [QGVAR(sniperTeam), false]}
                || {_g getVariable [QGVAR(disableGroupAI), false]};
            private _canli = (units _g) select {alive _x && {isNull objectParent _x}};
            if (_gec || {!([_g, "arkaGuvenlik", true] call FUNC(dk))} || {(count _canli) < ([_g, "arkaGuvenlikMinKisi", 6] call FUNC(dk))}) then {
                if (!isNull _u) then { [_g, _u] call _birak; };
                continue;
            };

            // --- aktiflik: yogun urban + (temas veya hareket) ---
            private _lPos = getPosATL _l;
            private _bina = count (nearestTerrainObjects [_lPos, ["BUILDING", "HOUSE", "CHURCH", "FUELSTATION", "HOSPITAL"], 80, false, true]);
            private _en = _l findNearestEnemy _l;
            private _yakinDusman = !isNull _en && {(_en distance2D _l) < 50};
            private _urban = (_bina >= 8) || {(insideBuilding _l) > 0.5} || {_yakinDusman && {_bina >= 5}};
            private _hareketVar = ((speed _l) > 1) || {(_g getVariable [QGVAR(contact), 0]) > (time - 90)};
            if (_urban && {_hareketVar} && {time > (_g getVariable [QGVAR(rearBekle), 0])}) then {
                _g setVariable [QGVAR(rearAktifT), time];
            };
            private _aktif = (time - (_g getVariable [QGVAR(rearAktifT), -999])) < 20;
            if (!_aktif) then {
                if (!isNull _u) then { [_g, _u] call _birak; };
                continue;
            };

            // --- aday sec (yoksa / oldu / gecersizse) ---
            if (isNull _u || {!alive _u} || {!((lifeState _u) in ["HEALTHY", "INJURED"])} || {_u getVariable [QGVAR(forceMove), false]} || {(_u getVariable [QGVAR(taktikKilit), 0]) > time}) then {
                if (!isNull _u && {alive _u}) then { [_g, _u] call _birak; };
                _u = objNull;
                private _adaylar = _canli select {
                    local _x && {!isPlayer _x} && {_x isNotEqualTo _l}
                    && {(lifeState _x) isEqualTo "HEALTHY"} && {(damage _x) < 0.2}
                    && {([_x] call _rolFn) isEqualTo "RIFLE"}
                    && {([_x] call _glFn) isEqualTo ""}
                    && {(rankId _x) < 3}                                   // 3 = SERGEANT; takim lideri / astsubay / subay degil
                    && {(secondaryWeapon _x) isEqualTo ""}
                    && {(_x getVariable [QGVAR(stationPos), []]) isEqualTo []}
                    && {!(_x getVariable [QGVAR(forceMove), false])} && {(_x getVariable [QGVAR(taktikKilit), 0]) <= time}
                    && {(getSuppression _x) < 0.5}
                };
                if ((count _adaylar) >= 3) then {
                    // lidere en uzak (zaten arkada olan) aday
                    _adaylar = [_adaylar, [], {_x distance2D _l}, "DESCEND"] call BIS_fnc_sortBy;
                    _u = _adaylar select 0;
                    _g setVariable [QGVAR(rearGuardU), _u];
                    _g setVariable [QGVAR(rearGuardPos), nil];
                    diag_log format ["[ARKA-GUVENLIK] %1 | %2 arkayi kollamaya atandi (bina:%3, kadro:%4)", groupId _g, name _u, _bina, count _canli];
                };
            };
            if (isNull _u) then { continue };
            // lidere > 45 m uzaksa (lider hucumda hizli gitti) arka guvenlik DEGIL, kopuk: gruba don, 60 sn yeniden secilme
            if ((_u distance2D _l) > 45) then {
                [_g, _u] call _birak;
                _g setVariable [QGVAR(rearAktifT), -999];
                _g setVariable [QGVAR(rearBekle), time + 60];
                continue
            };
            if ((getSuppression _u) >= 0.6) then { continue };   // ezilen siper alir, FSM yonetsin

            // --- on yon: dusman > lider hareket yonu > lider bakis yonu ---
            private _on = if (!isNull _en && {(_en distance2D _l) < 400}) then {
                _l getDir _en
            } else {
                if ((speed _l) > 1) then { direction _l } else { getDir _l }
            };
            private _arka = _on + 180;
            private _hedef = _lPos getPos [9, _arka];
            private _sonH = _g getVariable [QGVAR(rearGuardPos), []];
            private _sonZ = _g getVariable [QGVAR(rearGuardZ), -999];
            if (_sonH isEqualTo [] || {((_sonH distance2D _hedef) > 6 && {(time - _sonZ) > 8})}) then {
                if (!surfaceIsWater _hedef) then {
                    _g setVariable [QGVAR(rearGuardPos), _hedef];
                    _g setVariable [QGVAR(rearGuardZ), time];
                    _u doMove _hedef;
                    diag_log format ["[ARKA-GUVENLIK] %1 | %2 arkaya gecti (%3 m lidere, yon %4)", groupId _g, name _u, round (_u distance2D _l), round _arka];
                };
            };
            // gorev bayragi: dispersion / buddyBond / roleStation diger birimleri yonetirken buna dokunmaz; sure dolmasin
            _u setVariable [QGVAR(stationPos), [_g getVariable [QGVAR(rearGuardPos), _hedef], "MIDDLE", _lPos getPos [40, _arka], time, true]];
            _u setVariable [QGVAR(stationDirty), true];
            if ((_u distance2D (_g getVariable [QGVAR(rearGuardPos), _hedef])) < 5) then {
                _u setUnitPosWeak "MIDDLE";
                _u doWatch (_lPos getPos [30, _arka]);
            };
        } forEach (allGroups select {!isNull leader _x});
    };
};

true
