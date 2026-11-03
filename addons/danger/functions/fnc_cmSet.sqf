#include "script_component.hpp"
/*
 * Author: Cinar (ELITE fork)
 * GRUP SAVAS MODU DEGISTIR (v8.386; kullanici: ''free to engage' diyip duruyor'): grubun savas modunu (setCombatMode) YALNIZ degisecekse ayarlar ve degisimi RPT'ye yazar.
 * NEDEN: bounding / geri cekilme / temas kes / pusu gibi taktikler her baslangicta ve bitiste setCombatMode cagiriyordu (RED <-> YELLOW); motor mod degisiminde lider telsiz mesaji
 *   verebilir ('Free to engage' / 'Hold fire' tipi satirlar yalniz EKRAN / telsiz metnidir, RPT'ye YAZILMAZ). Ayni degeri tekrar atamak artik hic cagrilmaz; her gercek degisim
 *   [CM-DEGIS] satiri olarak zamanla yazilir (ilk 120): ekrandaki mesajla saat eslestirilince kaynak (hangi taktik) bulunur.
 *
 * Arguments:
 * 0: Grup <GROUP>
 * 1: Savas modu <STRING> ("BLUE" | "GREEN" | "WHITE" | "YELLOW" | "RED")
 * 2: Kaynak (log icin) <STRING>
 *
 * Return Value: Degisti mi <BOOL>
 * Public: No
*/

params [["_g", grpNull, [grpNull]], ["_mod", "YELLOW", [""]], ["_kaynak", "", [""]]];
if (isNull _g) exitWith {false};
private _eski = combatMode _g;
if (_eski isEqualTo _mod) exitWith {false};
_g setCombatMode _mod;
if (isNil "lambs_danger_cmLogN") then { lambs_danger_cmLogN = 0; };
if (lambs_danger_cmLogN < 120) then {
    lambs_danger_cmLogN = lambs_danger_cmLogN + 1;
    diag_log format ["[CM-DEGIS] %1 | %2 -> %3 | kaynak: %4", groupId _g, _eski, _mod, _kaynak];
};
true
