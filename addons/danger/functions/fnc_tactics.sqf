#include "script_component.hpp"
/*
 * Author: nkenny
 * Group leadership handler -- leads to profiles, assessments, contact state and other responses
 *
 * Arguments:
 * 0: group leader <OBJECT>
 * 1: known enemy <OBJECT>
 *
 * Return Value:
 * bool
 *
 * Example:
 * [bob, angryJoe] call lambs_danger_fnc_tactics;
 *
 * Public: No
 *
 * ===========================================================================
 * NE BULACAKSIN — BOUNDING DEVRALMA KONTROLU
 * ===========================================================================
 *
 * Bu dosya artik bounding icin "kapi bekcisi" gorevi gorur.
 * Asagidaki kosullar SAGLANDIGINDA bounding tetiklenir:
 *
 *   [1] _target null degil
 *   [2] Grupta >= 4 birlik var
 *   [3] Hedef 25m'den uzak
 *   [4] Hedef 200m'den yakin
 *   [5] %85 sans (random)  <- %50'den yukseltildi
 *   [6] isBounding == false
 *
 * NOT: isExecutingTactic kontrolu KALDIRILDI. Bounding oncelikli taktiktir.
 *      Eski taktik flag'leri bounding baslarken temizlenir.
 *
 * ===========================================================================
*/
params [["_unit", objNull, [objNull]], ["_target", objNull, [objNull]]];

private _group = group _unit;

// Keskin nisanci takimi (fnc_sniperTeam): komutan beyni / temas kes / tum bu taktikler uygulanmaz
if (_group getVariable [QGVAR(sniperTeam), false]) exitWith {false};

// ARAC EKIBI: lider (ya da surucu / nisanci / komutan) aracin icindeyse komutan beyni / piyade taktikleri
// uygulanmaz (allowGetIn false / doMove / cekilme araci terk ettiriyordu); arac davranisi LAMBS'a kalir
if (!isNull objectParent (leader _group)) exitWith {false};
if (((units _group) findIf {
    alive _x && {!isNull objectParent _x}
    && {((assignedVehicleRole _x) param [0, ""]) in ["driver", "gunner", "commander", "Turret"]}
}) > -1) exitWith {false};

// Gecersiz tehdit (olu / dost / sivil / bos): komutan beyni calismaz
private _tehditGecerli = _target isEqualType objNull
    && {!isNull _target}
    && {alive _target}
    && {((side _group) getFriend (side _target)) < 0.6};

// Dagilma bilinci watchdog'u (yigilma = tek el bombasi / RPG hepsini oldurur) — ilk cagrida bir kez baslar
if (isNil "lambs_danger_dispersionStarted") then {
    [] call (missionNamespace getVariable ["lambs_danger_fnc_dispersion", {false}]);
};

// Buddy bagi (kalici es + "tek basina uzaklarda dolasma" kontrolu) — ilk cagrida bir kez baslar
if (isNil "lambs_danger_buddyBondStarted") then {
    [] call (missionNamespace getVariable ["lambs_danger_fnc_buddyBond", {false}]);
};

// Rol istasyonu (formasyon sirasi + MG / nisanci / UGL / AT / saglikci gorev yeri) — ilk cagrida bir kez baslar
if (isNil "lambs_danger_roleStationStarted") then {
    [] call (missionNamespace getVariable ["lambs_danger_fnc_roleStation", {false}]);
};

// El bombasi farkindaligi (yere at -> yaricaptan uzaklas) — ilk cagrida bir kez baslar
if (isNil "lambs_danger_grenadeAwareStarted") then {
    [] call (missionNamespace getVariable ["lambs_danger_fnc_grenadeAwareness", {false}]);
};

// Sarjor korumasi (once siper / buddy korur / peek-reload-peek) — ilk cagrida bir kez baslar
if (isNil "lambs_danger_reloadCoverStarted") then {
    [] call (missionNamespace getVariable ["lambs_danger_fnc_reloadCover", {false}]);
};

// v7.5 katmanlari (acilista baslamadiysa ilk cagrida)
{
    if (isNil format ["lambs_danger_%1Started", _x]) then {
        [] call (missionNamespace getVariable [format ["lambs_danger_fnc_%1", _x], {false}]);
    };
} forEach ["leaderSync", "cqbReflex", "sniperTeam", "firedHub", "buddyDebug"];

if (EGVAR(main,debug_functions)) then {
    diag_log format ["[TACTICS-CAGRI] unit: %1 | target: %2 | contact: %3", _unit, _target, _group getVariable ["lambs_danger_contact", 0]];
};

// CQB mode ~ disabled awaiting polish ~ nkenny
//if (formation _unit in GVAR(cqb_formations)) exitWith {
//    _unit call FUNC(tacticsCQB);
//};

// check if group AI disabled
if (_group getVariable [QGVAR(disableGroupAI), false]) exitWith {false};

// ELITE HOTFIX: geri cekilme / temas kesme / evade sirasinda taban LAMBS taktikleri (ASSAULT/FLANK/sempatik) birimleri yeniden gorevlendirmesin
if (_group getVariable [QGVAR(isRetreating), false] || {_group getVariable [QGVAR(isEvading), false]} || {_group getVariable [QGVAR(isBreakingContact), false]}) exitWith {false};

// Initated contact?
private _contactState = _group getVariable [QGVAR(contact), 0];
if (_contactState < time) exitWith {[_unit, _target] call FUNC(contact)};

// KILIT KURTARMA: isBounding 200 sn'den eskiyse sifirla (cycle'lar siper omru + cift yakinlasma ile uzadi)
private _bndTime = _group getVariable [QGVAR(boundingStartTime), 0];
if (_group getVariable [QGVAR(isBounding), false] && {time - _bndTime > 200}) then {
    if (EGVAR(main,debug_functions)) then {
        diag_log format ["[BND] KILIT KURTARMA: %1 (200 sn asildi)", _group];
    };
    _group setVariable [QGVAR(isBounding), nil];
    _group setVariable [QGVAR(isExecutingTactic), nil];
};

// ---------------------------------------------------------------------------
// ELITE: Basit+ Bounding Overwatch devralma
// Kosullar: >= 4 birlik, hedef 25-200m arasinda, %85 sans
// isExecutingTactic kontrolu KALDIRILDI (bounding oncelikli)
// ---------------------------------------------------------------------------
// ---------------------------------------------------------------------------
// ELITE: KOMUTAN BEYNI — 5 faktor tehdit analizi + NATO karar tablosu
// Eski "random 1 < 0.85" zar atma KALDIRILDI.
// Karar fnc_commanderAssess.sqf'te verilir, burada sadece dispatch.
// ---------------------------------------------------------------------------
if (
    _tehditGecerli
    && {count (units _group) >= 4}
    && {!(_group getVariable [QGVAR(isBounding), false])}
    && {!(_group getVariable [QGVAR(isExecutingTactic), false])}
) exitWith {
    // Onceki taktik kilitlerini temizle
    _group setVariable [QGVAR(isExecutingTactic), nil];

    private _karar = [_group, _target] call FUNC(commanderAssess);

        switch (_karar) do {
        case "WITHDRAW": {
            [_group, _target] call FUNC(tacticsRetreat);
        };
                case "PEEL": {
            // Peel gecici olarak Retreat'e yonlendirildi
            // (Peel dosyasi korunuyor, ileride geri acilabilir)
            [_group, _target] call FUNC(tacticsRetreat);
        };
        case "EVADE_ARMOR": {
            // AT'siz grup zirhtan sert siperlere kacar (fonksiyon kayitli degilse Retreat)
            [_group, _target] call (missionNamespace getVariable ["lambs_danger_fnc_tacticsEvadeArmor", FUNC(tacticsRetreat)]);
        };
        case "AT_ENGAGE": {
            // AT zirha taarruz eder, piyadeler AT'nin yaninda dusman piyadeye karsi ortu verir
            [_group, _target] call (missionNamespace getVariable ["lambs_danger_fnc_tacticsATEngage", FUNC(tacticsFlank)]);
        };
        case "HOLD": {
            // tacticsHold(_group, _delay): 2. parametre SURE (sn); kilidi ve enableAttack'i kendisi geri verir
            _group setVariable [QGVAR(isExecutingTactic), true];
            [_group, 20] call FUNC(tacticsHold);
        };
        case "DELAY": {
            // tacticsHide(_group, _target, _antiTank, _delay): varsayilan 240 sn combatMode WHITE (ates yok) tutardi ->
            // 25 sn; kilidi, combatMode / formasyon / enableAttack'i sure sonunda kendisi geri verir
            // 30 sn'de BIR KEZ: LAMBS tacticsHide her cagrida "TakeCover!" bagirip herkesi yeniden saklanma noktasina yolluyor;
            // RPT'de 5 sn arayla tekrarlaniyordu (take cover spam'i + hareket felci)
            if ((time - (_group getVariable [QGVAR(delayBasT), -999])) > 30) then {
                _group setVariable [QGVAR(delayBasT), time];
                _group setVariable [QGVAR(isExecutingTactic), true];
                [_group, _target, false, 25] call FUNC(tacticsHide);
                [_group, _target, "BREAK_CONTACT"] call (missionNamespace getVariable ["lambs_danger_fnc_tacticalSmoke", {false}]);
            };
        };
        case "SUPPRESS_ASSAULT": {
            [_group, _target, "COVER_MOVE"] call (missionNamespace getVariable ["lambs_danger_fnc_tacticalSmoke", {false}]);
            [_group, _target] call FUNC(tacticsSuppress);
            [{
                params ["_g", "_t"];
                if (!isNull _g && {(units _g) isNotEqualTo []}) then {
                    [_g, _t] call FUNC(tacticsAssault);
                };
            }, [_group, _target], 4] call CBA_fnc_waitAndExecute;
        };
        case "FLANK": {
            [_group, _target, "COVER_MOVE"] call (missionNamespace getVariable ["lambs_danger_fnc_tacticalSmoke", {false}]);
            [_group, _target] call FUNC(tacticsFlank);
        };
        case "ASSAULT": {
            [_group, _target, "COVER_MOVE"] call (missionNamespace getVariable ["lambs_danger_fnc_tacticalSmoke", {false}]);
            [_group, _target] call FUNC(tacticsAssault);
        };
        default {
            [_group, _target] call FUNC(tacticsBounding);
        };
    };
    

    true
};

// ---------------------------------------------------------------------------
// KUCUK GRUP / TEK KALAN ASKER (< 4): komutan beyni yok -> TEMAS KES
// (eskiden LAMBS'in duz akisina dusup catismaya devam ediyordu)
// ---------------------------------------------------------------------------
private _temasKes = false;
if (
    _tehditGecerli
    && {((units _group) select {alive _x}) isNotEqualTo []}
    && {count ((units _group) select {alive _x}) < 4}
    && {!(_group getVariable [QGVAR(isExecutingTactic), false]) || {count ((units _group) select {alive _x}) isEqualTo 1}}   // tek kalan: eski taktik kilidi kacisi engellemesin
    && {!isPlayer (leader _group)}
) then {
    _temasKes = [_group, _target] call (missionNamespace getVariable ["lambs_danger_fnc_tacticsBreakContact", {false}]);
};
if (_temasKes) exitWith {true};

// ai profiles ~ here is where AI profiles will be extrapolated - nkenny
// if (_unit call FUNC(tacticsProfiles)) exitWith {true};

// Leader assessment
if (!isPlayer (leader _unit)) then {_unit call FUNC(tacticsAssess);};

// end
true