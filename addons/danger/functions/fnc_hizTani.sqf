#include "script_component.hpp"
/*
 * Author: Cinar (ELITE fork)
 * EV ICI HIZ TANISI (v8.620; kullanici: 'tani ekle'; sikayet: 'ev icinde askerlerin animasyonlari cok yavas, LAMBS CQB mi etkiliyor?'):
 * Bina supurmesi / baskini (QGVAR(isSweeping)) suren her yerel gruptan 4 sn'de bir [HIZ-TANI] satiri yazar (toplam en cok 80 satir; kapatma: lambs_danger_hizTaniOff = true):
 *   grup: LAMBS gorevi (lambs_main_currentTactic), disableGroupAI, wpSahip, speedMode, behaviour, combatMode, formation, taskCQB calisiyor mu (sweep sinyalleri), ort / maks hiz km/sa
 *   asker: hiz (km/sa), durus (stance), unitPos, animasyon (kisa), currentCommand, hareket emri var mi (moveToCompleted), insideBuilding, kosu kilidi (forceMove), taktikKilit, AI kapatma (MOVE / ANIM / PATH / AUTOCOMBAT / SUPPRESSION), tahmini animSpeedCoef (CBA animHiz)
 * Yorum: hiz < 8 km/sa + durus CROUCH / unitPos MIDDLE + speedMode LIMITED -> yavaslik emir kaynakli (LAMBS / ELITE); hiz < 8 + durus STAND + speedMode FULL -> engel / yol; animasyon 'rcmwlk' = alcak silah yurume.
 *
 * Arguments: None
 * Return Value: Baslatildi mi <BOOL>
 * Public: No
*/

if (!isNil "lambs_danger_hizTaniStarted") exitWith {false};
lambs_danger_hizTaniStarted = true;

diag_log "[HIZ-TANI] ev ici hiz tanisi (bina supurmesinde hiz / durus / animasyon / LAMBS) baslatildi (v8.620)";

[] spawn {
    private _logN = 0;
    while {_logN < 80} do {
        sleep 4;
        if (missionNamespace getVariable ["lambs_danger_hizTaniOff", false]) then { continue };
        {
            private _g = _x;
            if (isNull _g || {!local _g} || {!(_g getVariable [QGVAR(isSweeping), false])} || {_logN >= 80}) then { continue };
            private _u = (units _g) select {alive _x && {isNull objectParent _x} && {!isPlayer _x}};
            if (_u isEqualTo []) then { continue };
            _logN = _logN + 1;
            private _hizlar = _u apply {speed _x};
            private _animKat = if (missionNamespace getVariable ["lambs_danger_animHizAktif", true]) then { 1 + (((missionNamespace getVariable ["lambs_danger_animHiz", 20]) max 0) min 60) / 100 } else { 1 };
            diag_log format ["[HIZ-TANI] GRUP %1 | LAMBS gorev '%2' | disableGroupAI %3 | wpSahip '%4' | speedMode %5 | beh %6 | cm %7 | form %8 | ort %9 / maks %10 km/sa | CBA animHiz katsayi %11 | cqbGirisHizi %12",
                groupId _g, _g getVariable ["lambs_main_currentTactic", ""], _g getVariable ["lambs_danger_disableGroupAI", false], [_g] call FUNC(wpSahip),
                speedMode _g, behaviour (leader _g), combatMode _g, formation _g,
                round ((_hizlar call BIS_fnc_arithmeticMean)), round (selectMax _hizlar), _animKat toFixed 2, missionNamespace getVariable ["lambs_danger_cqbGirisHizi", 2]];
            {
                private _x0 = _x;
                private _kapali = ["MOVE", "ANIM", "PATH", "AUTOCOMBAT", "SUPPRESSION", "TARGET", "AUTOTARGET"] select { !(_x0 checkAIFeature _x) };
                diag_log format ["[HIZ-TANI]   %1 | %2 | hiz %3 km/sa | durus %4 | unitPos %5 | anim %6 | komut %7 | hareket bitti %8 | binada %9 | forceMove %10 | taktikKilit %11 | KAPALI AI %12",
                    name _x0, [_x0] call (missionNamespace getVariable ["lambs_danger_fnc_getUnitRole", {"?"}]), round (speed _x0), stance _x0, unitPos _x0, animationState _x0,
                    currentCommand _x0, moveToCompleted _x0, (insideBuilding _x0) toFixed 1, _x0 getVariable [QGVAR(forceMove), false],
                    ((_x0 getVariable [QGVAR(taktikKilit), 0]) > time), _kapali];
            } forEach _u;
        } forEach allGroups;
    };
};
true
