#include "script_component.hpp"
/*
 * Author: Cinar (ELITE fork)
 * SENARYO MODU KAPISI (v8.502; kullanici: 'senaryo modu ekle, acikken waypoint disi kararlar yok sayilsin, geri cekilme buna dahil olmasin; Blackfox senaryolari oynayip gozlemleyecegim').
 *
 * v8.504 (sade-waypoint): kapi artik fnc_wpSahip'e bakar. LAMBS gorevi (lambs_wp: Garrison / Camp / Patrol / Hunt / CQB ...), 'LAMBS Danger: AI Kapat' ve kal-bekle turu vanilla waypoint (HOLD / SENTRY / GUARD / SCRIPTED ...)
 * HER ZAMAN ELITE hareket / taktik katmanlarini geri ceker. Hareket turu waypoint (MOVE / SAD / DESTROY / CYCLE) icin CBA 'Senaryo modu' (lambs_danger_senaryoModu, varsayilan ACIK) belirler.
 * Kapsam (lambs_danger_senaryoKapsam): 0 = yalniz tasarimci waypoint'i / LAMBS gorevi olan gruplar (varsayilan; waypoint'siz gruplarda ELITE tepkileri surer), 1 = TUM AI gruplari.
 * OYUNCULU gruplar etkilenmez.
 * v8.502b: BOUNDING / overwatch (HOLD), arka + yan emniyet, nokta elemani, ileri gozcu SERBEST (rota degistirmez); bounding'in rotadan sapmasi fnc_senaryoRota ile izlenir, bounding sonu hucum devri kapali. Yok sayilan karar: DELAY (hide), SUPPRESS_ASSAULT, FLANK, ASSAULT, AT_ENGAGE.
 * KAPI DISINDA KALANLAR (bilincli): GERI CEKILME / PEEL / ZIRHTAN KACIS / TEMAS KESME (fnc_tactics karari WITHDRAW / PEEL / EVADE_ARMOR + < 4 asker temas kes), panik / felc, teslim, tibbi (TCCC), atis disiplini / sarjor, tank-arac guvenlik freni (ezme).
 * KAPI ICINDE (waypoint'li grupta yok sayilir): fnc_tactics'in assault / flank / hide (DELAY) / suppress / AT karari + LAMBS tacticsAssess, ates-hareket (rush), CQB cevik, formasyon (formSet; geri cekilme haric), rol istasyonu, buddy bagi, dagilma, yetim toplama / katilma, arac senkronu, mekanize hiz duzeltici, tank araligi, acikta bekleme, HQ emirleri.
 * Log: [SENARYO-MODU] acilis + 120 sn'de bir ozet (kapi sayilari).
 *
 * Arguments:
 * 0: Grup <GROUP>
 * 1: Etiket (log / sayac) <STRING>
 * 2: Yalniz sabit (LAMBS gorevi / kal-bekle waypoint) sayilsin; hareket waypoint'i serbest <BOOL> (varsayilan false; v8.504)
 * 1: Etiket (log / sayac icin) <STRING>
 *
 * Return Value: ELITE karari yok sayilmali mi <BOOL>
 * Public: No
*/

params [["_g", grpNull, [grpNull]], ["_etiket", "?", [""]], ["_sadeceSabit", false, [false]]];
if (isNull _g) exitWith {false};
if (((units _g) findIf {isPlayer _x}) > -1) exitWith {false};
// v8.504 WAYPOINT UYUMU: kim yonetiyor? (fnc_wpSahip) - LAMBS gorevi / LAMBS AI-kapat / kal-bekle turu vanilla waypoint HER ZAMAN ELITE'i geri ceker;
// hareket turu (MOVE / SAD / DESTROY / CYCLE) yalniz 'Senaryo modu' aciksa (varsayilan ACIK; kapsam 1 = tum AI gruplari)
private _sahip = [_g] call FUNC(wpSahip);
private _kapi = if (_sahip in ["LAMBS", "TUTAN"]) then {true} else {
    if (_sadeceSabit || {!(missionNamespace getVariable ["lambs_danger_senaryoModu", true])}) then {false} else {
        ((missionNamespace getVariable ["lambs_danger_senaryoKapsam", 0]) isEqualTo 1) || {_sahip isEqualTo "HAREKET"}
    }
};
if (_kapi) then {
    private _tab = missionNamespace getVariable ["lambs_danger_senaryoSayac", createHashMap];
    private _ank = format ["%1/%2", _etiket, _sahip];
    _tab set [_ank, (_tab getOrDefault [_ank, 0]) + 1];
    missionNamespace setVariable ["lambs_danger_senaryoSayac", _tab];
    if (isNil "lambs_danger_senaryoLogT") then {
        missionNamespace setVariable ["lambs_danger_senaryoLogT", time + 120];
        diag_log "[SENARYO-MODU] ACIK: tasarimci waypoint'i olan gruplarda ELITE hareket / taktik kararlari yok sayilir (geri cekilme / panik / teslim / tibbi / atis disiplini haric)";
    };
    if (time > (missionNamespace getVariable ["lambs_danger_senaryoLogT", 0])) then {
        missionNamespace setVariable ["lambs_danger_senaryoLogT", time + 120];
        diag_log format ["[SENARYO-MODU-OZET] son 120 sn kapi (yok sayilan ELITE karari): %1", (_tab toArray false) apply { format ["%1=%2", _x select 0, _x select 1] }];
        missionNamespace setVariable ["lambs_danger_senaryoSayac", createHashMap];
    };
};
_kapi
