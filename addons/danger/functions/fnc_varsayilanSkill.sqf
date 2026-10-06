#include "script_component.hpp"
/*
 * Author: Cinar (ELITE fork)
 * VARSAYILAN BECERI (spawn / editor / Zeus) — yeni olusan HER AI piyadesine taban beceri atar; ortam beceri dususu (fnc_ortamSkill) bunun USTUNDEN dusurur.
 *
 * Varsayilan tablo (lambs_danger_skillVarsayilan, [beceri, min, max]; deger min..max arasinda rastgele):
 *   commanding 1.00..1.00 | general 1.00..1.00 | aimingAccuracy 0.65..0.70
 *   (digerleri — spotDistance, spotTime, aimingSpeed, aimingShake, courage, reloadSpeed — misyonun verdigi gibi KALIR; tabloya eklenebilir)
 *
 * Calisma:
 *   - Baslangicta: CBA sinif olayi CAManBase "init" (editor birimleri retroaktif dahil, Zeus / script ile spawn olanlar dahil) -> 0.5 sn sonra uygula
 *     (editor init satirindaki setSkill'den SONRA gelir; kendi becerini korumak istersen birimin init'ine: this setVariable ["lambs_danger_skillElle", true]).
 *   - Atlanir: oyuncu, yerel olmayan birim, lambs_danger_skillElle = true, zaten ayarli.
 *   - Elle cagri (init.sqf / Zeus): [_birim] call lambs_danger_fnc_varsayilanSkill;  hepsini yeniden: { [_x] call lambs_danger_fnc_varsayilanSkill } forEach allUnits;
 *     (zorla yeniden ayar icin once _birim setVariable ["lambs_danger_skillAyarli", nil])
 *   - Kapatma: lambs_danger_skillVarsayilanV1 = false
 * Log: [SKILL-VARSAYILAN] (ilk 40 birim: onceki -> yeni), [SKILL-OZET] her 60 sn (toplam uygulanan / atlanan nedenler).
 *
 * Arguments:
 * 0: Birim (opsiyonel; yoksa sistem baslatilir) <OBJECT>
 *
 * Return Value:
 * Uygulandi / baslatildi mi <BOOL>
 *
 * Public: Yes
*/

params [["_u", objNull, [objNull]]];

if (isNull _u) exitWith {
    if (!isNil "lambs_danger_skillVarsayilanStarted") exitWith {false};
    lambs_danger_skillVarsayilanStarted = true;
    if (isNil "lambs_danger_skillVarsayilan") then {
        lambs_danger_skillVarsayilan = [["commanding", 1, 1], ["general", 1, 1], ["aimingAccuracy", 0.65, 0.70]];
    };
    lambs_danger_skillSay = createHashMapFromArray [["uygulandi", 0], ["oyuncu", 0], ["yerel_degil", 0], ["elle", 0], ["zaten", 0]];
    diag_log format ["[SKILL-VARSAYILAN] varsayilan beceri sistemi baslatildi | tablo:%1", lambs_danger_skillVarsayilan];

    ["CAManBase", "init", {
        params ["_birim"];
        [{ params ["_b"]; [_b] call (missionNamespace getVariable ["lambs_danger_fnc_varsayilanSkill", {false}]); }, [_birim], 0.5] call CBA_fnc_waitAndExecute;
    }, true, [], true] call CBA_fnc_addClassEventHandler;

    [] spawn {
        while {true} do {
            sleep 60;
            diag_log format ["[SKILL-OZET] %1", (keys lambs_danger_skillSay) apply {format ["%1=%2", _x, lambs_danger_skillSay get _x]}];
        };
    };
    true
};

if (!(missionNamespace getVariable ["lambs_danger_skillVarsayilanV1", true])) exitWith {false};
if (isNil "lambs_danger_skillSay") then { lambs_danger_skillSay = createHashMapFromArray [["uygulandi", 0], ["oyuncu", 0], ["yerel_degil", 0], ["elle", 0], ["zaten", 0]]; };
private _say = {
    params ["_k"];
    lambs_danger_skillSay set [_k, (lambs_danger_skillSay getOrDefault [_k, 0]) + 1];
};

if (isNull _u || {!alive _u}) exitWith {false};
if (isPlayer _u) exitWith { ["oyuncu"] call _say; false };
if (!local _u) exitWith { ["yerel_degil"] call _say; false };
if (_u getVariable ["lambs_danger_skillElle", false]) exitWith { ["elle"] call _say; false };
if (_u getVariable [QGVAR(skillAyarli), false]) exitWith { ["zaten"] call _say; false };

private _tablo = missionNamespace getVariable ["lambs_danger_skillVarsayilan", [["commanding", 1, 1], ["general", 1, 1], ["aimingAccuracy", 0.65, 0.70]]];
private _onceki = [];
private _yeni = [];
{
    _x params ["_ad", "_min", "_max"];
    private _v = _min + (random (_max - _min));
    _onceki pushBack format ["%1=%2", _ad, (_u skill _ad) toFixed 2];
    _u setSkill [_ad, _v];
    _yeni pushBack format ["%1=%2", _ad, _v toFixed 2];
} forEach _tablo;
// v8.90 OPTIK ETKISI (kalibrasyon arastirmasi: kaynaklar_doktrin/arastirma_gerceklik/): Arma AI optikten isabet KAZANMAZ (tarama: AI optik avantaji yok) -> USMC ACOG / reflex ile optiksiz AK ayni isabetle atiyordu.
//   Gercek veri (ARL AD1064518 + USMC ilk-atis calismasi; arama ozeti, GUVEN orta): 200 m acik nisangah ~%71 / optik >%90; 300 m ~%55 / ~%87; USMC 137-432 m ilk atis M16A2 acik %45 / ACOG %88 -> oran ~0.5-0.8.
//   Optigi (primaryWeaponItems[2]) OLMAYAN birimin aimingAccuracy'si x0.75 (kapatma: lambs_danger_optikSkillOff = true). ACE yukluyken dusuk skill isabeti beklenenden az dusurur (ACE3 #6948) -> etki kucuk olabilir, [SKILL-VARSAYILAN] ile ölc.
if (!(missionNamespace getVariable ["lambs_danger_optikSkillOff", false]) && {(_tablo findIf {(_x select 0) isEqualTo "aimingAccuracy"}) >= 0}) then {
    private _optik = ((primaryWeaponItems _u) param [2, ""]) isNotEqualTo "";
    if (!_optik && {(primaryWeapon _u) isNotEqualTo ""}) then {
        private _aa = (_u skill "aimingAccuracy") * 0.75;
        _u setSkill ["aimingAccuracy", _aa];
        _yeni pushBack format ["optiksiz x0.75 -> %1", _aa toFixed 2];
    };
};
_u setVariable [QGVAR(skillAyarli), true];
["uygulandi"] call _say;

if (isNil "lambs_danger_skillLogN") then { lambs_danger_skillLogN = 0; };
if (lambs_danger_skillLogN < 40) then {
    lambs_danger_skillLogN = lambs_danger_skillLogN + 1;
    diag_log format ["[SKILL-VARSAYILAN] %1 | %2 | %3 | onceki: %4 | yeni: %5", name _u, side group _u, typeOf _u, _onceki joinString " ", _yeni joinString " "];
};
true
