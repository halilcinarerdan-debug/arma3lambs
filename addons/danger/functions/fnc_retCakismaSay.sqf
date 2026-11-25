#include "script_component.hpp"
/*
 * Author: Cinar (ELITE fork)
 * RETREAT CAKISMA SAYACI (v8.806; kullanici: 'retreattami cakisan bir sey var'; RPT c69aff1e v8.804: retreat kosucu orneklerinin %71'i DURUYOR (%84'unda acikSiper tutucusu hala aktif), 3 retreat'in 2'si 'ilerleme yok (2 sicrama 0 varis)' ile bitti):
 * Geri cekilen grubun askerine, retreat BASLAMADAN ONCE zamanlanmis bir siper komutunun (siperZorla gecikmeli geri cagrilari, yumusakKay yuruyusu / kaydirmasi, moveAssist yan adim donusu) retreat emrini ezmesi
 * ENGELLENDIGINDE sayar ve ilk 20'yi loglar: [RET-CAKISMA] kaynak | asker. 60 sn'de bir [RET-CAKISMA-OZET] (kaynak basina sayi). Karne: 'GERCEKCILIK: RETREAT CAKISMASI'.
 *
 * Arguments:
 * 0: Asker <OBJECT>
 * 1: Kaynak <STRING> (siperZorla / yumusakKay / moveAssist)
 *
 * Return Value: Yok
 * Public: No
*/

params [["_u", objNull, [objNull]], ["_kaynak", "?", [""]]];
private _say = missionNamespace getVariable ["lambs_danger_retCakSay", createHashMap];
missionNamespace setVariable ["lambs_danger_retCakSay", _say];
_say set [_kaynak, (_say getOrDefault [_kaynak, 0]) + 1];
private _n = missionNamespace getVariable ["lambs_danger_retCakLogN", 0];
if (_n < 20) then {
    missionNamespace setVariable ["lambs_danger_retCakLogN", _n + 1];
    diag_log format ["[RET-CAKISMA] %1 | %2 | %3 | retreat / kosucu iken eski siper komutu atlandi (emir ezilmedi)", _kaynak, groupId (group _u), name _u];
};
if (isNil "lambs_danger_retCakOzetT") then { lambs_danger_retCakOzetT = time + 60; };
if (time > lambs_danger_retCakOzetT) then {
    lambs_danger_retCakOzetT = time + 60;
    diag_log format ["[RET-CAKISMA-OZET] 60 sn: %1", (_say toArray false) apply { format ["%1=%2", _x select 0, _x select 1] }];
    _say = createHashMap;
    missionNamespace setVariable ["lambs_danger_retCakSay", _say];
};
