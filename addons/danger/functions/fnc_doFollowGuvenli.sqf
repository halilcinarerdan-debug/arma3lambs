#include "script_component.hpp"
/*
 * Author: Cinar (ELITE fork)
 * KORUMALI doFollow (v8.681; kullanici: '1 2 6 yap'; hardening): 'serbest birakma' tipi doFollow cagrilarinin, grup duzeyinde tum askerlere SUREKLI emir veren taktiklerin (geri cekilme / temas kesme / kacis) emrini ezmesini onler.
 * [asker, (lider), (zorla)] call FUNC(doFollowGuvenli) -> doFollow verildi mi <BOOL>
 *
 * NEDEN (RPT 657502f7 / 0e8cb384): koşucu hedef modu 'LEADER PLANNED' = formasyon plani; haltKur, taktik zamanlayicilari, kacis, yakinHareket... gecikmeli 'doFollow' serbest birakmasi retreat'in yeni doMove emrini eziyordu.
 *   Serbest birakma noktalari doFollow'dan HEMEN ONCE kendi forceMove / taktikKilit bayraklarini sildigi icin ASKER duzeyinde bayrak kontrolu ise yaramaz; kapi GRUP duzeyindedir.
 * KURAL: asker olu / oyuncu ise atlanir; grup isRetreating / isBreakingContact / isEvading ise doFollow VERILMEZ (o taktik kendi dongusuyle tum askerlere emir yeniden verir; atlamak askeri donuk birakmaz).
 *   Bounding / kanat / hucum gibi taktiklerde ATLANMAZ (orada atlamak onceden doStop edilmis askeri taktik bitene kadar donuk birakabilir).
 *   zorla = true ise (cagiran bilincli olarak formasyona dondurmek istiyor) kontrol atlanir.
 * Log: [DOFOLLOW-ATLA] sayac (60 sn ozeti yok; ilk 15 olay).
 *
 * Arguments:
 * 0: Asker <OBJECT>
 * 1: Lider <OBJECT> (varsayilan: askerin grup lideri)
 * 2: Zorla <BOOL> (varsayilan false)
 *
 * Return Value: doFollow verildi mi <BOOL>
 * Public: No
*/

params [["_u", objNull, [objNull]], ["_l", objNull, [objNull]], ["_zorla", false, [false]]];
if (isNull _u || {!alive _u} || {isPlayer _u}) exitWith {false};
private _g = group _u;
if (isNull _l) then { _l = leader _g; };
if (isNull _l || {_u isEqualTo _l}) exitWith {false};
if (!_zorla && {(_g getVariable [QGVAR(isRetreating), false]) || {_g getVariable [QGVAR(isBreakingContact), false]} || {_g getVariable [QGVAR(isEvading), false]}}) exitWith {
    if ((missionNamespace getVariable ["lambs_danger_dfAtlaN", 0]) < 15) then {
        missionNamespace setVariable ["lambs_danger_dfAtlaN", (missionNamespace getVariable ["lambs_danger_dfAtlaN", 0]) + 1];
        diag_log format ["[DOFOLLOW-ATLA] %1 | %2 | grup retreat / temas kes / kacis yurutuyor: serbest birakma doFollow'u atlandi (koşu emri korunuyor)", groupId _g, name _u];
    };
    false
};
_u doFollow _l;
true
