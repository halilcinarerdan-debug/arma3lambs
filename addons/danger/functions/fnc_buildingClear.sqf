#include "script_component.hpp"
/*
 * Author: Cinar (ELITE fork)
 * CATISMA SONRASI CEVRE EMNIYETI + BINA TEMIZLEME — watchdog (tetikleyici).
 *
 * Her YEREL AI piyade grubu icin (4 sn'de bir): catisma bitti mi?
 *   - Catisma izi: bilinen dusman < 250 m, baski > 0.1 veya bir taktik (bounding / geri cekilme / evade /
 *     temas kes / AT taarruz / isExecutingTactic) aktif -> "catisma var" bayragi + zaman damgasi
 *   - Bayrak var ve 25 sn boyunca dusman / baski / taktik YOK -> fnc_buildingClearRun baslatilir
 *   - 7 dk'dan eski catisma icin supurme yapilmaz; supurme sonrasi 120 sn bekleme
 *
 * ATLANIR: oyuncu liderli / oyuncu iceren grup, keskin nisanci ekibi (SNIPER), arac, < 3 canli piyade.
 * KAPATMA ANAHTARI: lambs_danger_buildingClearOff = true
 *
 * RPT: [BINA-TEMIZLE] satirlari (detay fnc_buildingClearRun.sqf)
 *
 * Arguments:
 * None
 *
 * Return Value:
 * Baslatildi mi <BOOL>
 *
 * Public: No
*/

if (!isNil "lambs_danger_buildingClearStarted") exitWith {false};
lambs_danger_buildingClearStarted = true;

diag_log "[BINA-TEMIZLE] cevre emniyeti + bina temizleme watchdog baslatildi";

[] spawn {
    while {true} do {
        sleep 4;
        if (missionNamespace getVariable ["lambs_danger_buildingClearOff", false]) then { continue };

        {
            private _g = _x;
            if (isNull _g || {!local _g}) then { continue };
            if (_g getVariable [QGVAR(sniperTeam), false]) then { continue };
            if (_g getVariable [QGVAR(isSweeping), false]) then { continue };

            private _l = leader _g;
            if (isNull _l || {!alive _l} || {isPlayer _l} || {!isNull objectParent _l}) then { continue };
            if (((units _g) findIf {isPlayer _x}) > -1) then { continue };

            private _alive = (units _g) select {
                alive _x && {isNull objectParent _x} && {(lifeState _x) in ["HEALTHY", "INJURED"]}
            };
            if ((count _alive) < 3) then { continue };

            // Taktik calisiyorsa: catisma suruyor sayilir (sayac sifirlanir)
            private _taktik = (_g getVariable [QGVAR(isBounding), false])
                || {_g getVariable [QGVAR(isRetreating), false]}
                || {_g getVariable [QGVAR(isEvading), false]}
                || {_g getVariable [QGVAR(isBreakingContact), false]}
                || {_g getVariable [QGVAR(isATEngage), false]}
                || {_g getVariable [QGVAR(isExecutingTactic), false]};
            if (_taktik) then {
                _g setVariable [QGVAR(sweepFightTs), time];
                _g setVariable [QGVAR(sweepFight), true];
                continue;
            };

            // Dusman / baski izleme
            private _en = _l findNearestEnemy _l;
            private _yakin = !isNull _en && {alive _en} && {(_l distance2D _en) < 250};
            private _baski = (_alive findIf {(getSuppression _x) > 0.1}) > -1;
            if (_yakin || _baski) then {
                _g setVariable [QGVAR(sweepFightTs), time];
                _g setVariable [QGVAR(sweepFight), true];
                if (_yakin) then { _g setVariable [QGVAR(sweepDusmanPos), getPosATL _en]; };
                continue;
            };

            // Sakinlik kosullari
            if !(_g getVariable [QGVAR(sweepFight), false]) then { continue };
            private _sure = time - (_g getVariable [QGVAR(sweepFightTs), time]);
            if (_sure < 25) then { continue };
            if (_sure > 420) then {
                _g setVariable [QGVAR(sweepFight), false];   // cok gec: supurme yok
                continue;
            };
            if (time < (_g getVariable [QGVAR(sweepCooldown), 0])) then { continue };

            _g setVariable [QGVAR(sweepFight), false];
            diag_log format ["[BINA-TEMIZLE] %1 | catisma bitti (%2 sn sakin) -> cevre emniyeti + bina temizleme basliyor", groupId _g, round _sure];
            [_g] spawn (missionNamespace getVariable ["lambs_danger_fnc_buildingClearRun", {false}]);
        } forEach allGroups;
    };
};

true
