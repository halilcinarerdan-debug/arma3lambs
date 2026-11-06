#include "script_component.hpp"
/*
 * Author: Cinar (ELITE fork)
 * UZUV KIRALAMA (v8.500) - "ses yonlendirmesi": bir birimin bir UZVUNA (HIZ / HAREKET / ...) ayni anda yalniz BIR sahip yazar.
 * Sahip uzvu kiralar (oncelik + sure); baska sahip ancak daha YUKSEK oncelikle ya da sure dolunca alir. Reddedilen istek [UYUM] olarak loglanir (sayilir) - hata degil, hakemin calistigi kanit.
 * Oncelik tablosu (tasarim degeri): 90 GUVENLIK (ezme fren) | 60 NAKIL (konvoy / yukleme) | 40 TANK-ARALIK (park / dagilma) | 20 MEKANIZE (hiz sifirlama). Esit oncelikte yeni gelen REDDEDILIR (kararlilik).
 * Yaziciyi tasimak = yazmadan once bu fonksiyonu (ya da fnc_uzuvIzin) cagirmak; kiralama suresi yenilenmezse kendiliginden biter (sahip olurse kilit kalmaz).
 *
 * Arguments:
 * 0: Birim (surucu / asker) <OBJECT>
 * 1: Uzuv ("HIZ", "HAREKET", ...) <STRING>
 * 2: Sahip adi <STRING>
 * 3: Oncelik (varsayilan 50) <NUMBER>
 * 4: Sure sn (varsayilan 5) <NUMBER>
 *
 * Return Value: kiralandi / yenilendi mi <BOOL>
 * Public: No
*/

params [["_u", objNull, [objNull]], ["_uzuv", "HIZ", [""]], ["_sahip", "", [""]], ["_oncelik", 50, [0]], ["_ttl", 5, [0]]];
if (isNull _u) exitWith {false};
private _k = format ["lambs_danger_uzuv_%1", _uzuv];
private _m = _u getVariable [_k, []];
if (_m isNotEqualTo [] && {(_m select 2) > time} && {(_m select 0) isNotEqualTo _sahip} && {(_m select 1) >= _oncelik}) exitWith {
    missionNamespace setVariable ["lambs_danger_uyumRet", (missionNamespace getVariable ["lambs_danger_uyumRet", 0]) + 1];
    private _lk = format ["lambs_danger_uyumLogT_%1_%2_%3", _uzuv, _sahip, _m select 0];
    if ((time - (_u getVariable [_lk, -999])) > 30 && {(missionNamespace getVariable ["lambs_danger_uyumLogN", 0]) < 60}) then {
        _u setVariable [_lk, time];
        missionNamespace setVariable ["lambs_danger_uyumLogN", (missionNamespace getVariable ["lambs_danger_uyumLogN", 0]) + 1];
        diag_log format ["[UYUM] RET | %1 | uzuv %2 | istek: %3 (oncelik %4) | mevcut sahip: %5 (oncelik %6, %7 sn kaldi)", typeOf (vehicle _u), _uzuv, _sahip, _oncelik, _m select 0, _m select 1, round ((_m select 2) - time)];
    };
    false
};
_u setVariable [_k, [_sahip, _oncelik, time + _ttl]];
true
