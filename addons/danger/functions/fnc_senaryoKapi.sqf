#include "script_component.hpp"
/*
 * Author: Cinar (ELITE fork)
 * SENARYO MODU KAPISI (v8.502; kullanici: 'senaryo modu ekle, acikken waypoint disi kararlar yok sayilsin, geri cekilme buna dahil olmasin; Blackfox senaryolari oynayip gozlemleyecegim').
 *
 * CBA 'Senaryo modu' (lambs_danger_senaryoModu, varsayilan KAPALI) acikken: tasarimcinin 3DEN'de verdigi WAYPOINT'i olan gruplarda ELITE'in HAREKET / TAKTIK karar katmanlari DEVRE DISI (grup waypoint'ini izler).
 * Kapsam (lambs_danger_senaryoKapsam): 0 = yalniz AKTIF tasarimci waypoint'i olan gruplar (varsayilan; waypoint'siz / bekleyen gruplarda ELITE tepkileri surer), 1 = TUM AI gruplari.
 * 'Tasarimci waypoint'i' = adi 'ELITE' ile BASLAMAYAN, indeksi >= 1 ve >= currentWaypoint olan waypoint (kalan aktif waypoint). ELITE'in kendi waypoint'leri (nakil, recon vb.) sayilmaz.
 * OYUNCULU gruplar etkilenmez.
 * KAPI DISINDA KALANLAR (bilincli): GERI CEKILME / PEEL / ZIRHTAN KACIS / TEMAS KESME (fnc_tactics karari WITHDRAW / PEEL / EVADE_ARMOR + < 4 asker temas kes), panik / felc, teslim, tibbi (TCCC), atis disiplini / sarjor, tank-arac guvenlik freni (ezme).
 * KAPI ICINDE (waypoint'li grupta yok sayilir): fnc_tactics'in assault / flank / bounding / hide / hold / suppress / garrison / AT karari + LAMBS tacticsAssess, ates-hareket (rush), CQB cevik, hat-formasyon (formSet; geri cekilme haric), rol istasyonu, buddy bagi, dagilma, yetim toplama / katilma, arac senkronu, mekanize hiz duzeltici, HQ emirleri.
 * Log: [SENARYO-MODU] acilis + 120 sn'de bir ozet (kapi sayilari).
 *
 * Arguments:
 * 0: Grup <GROUP>
 * 1: Etiket (log / sayac icin) <STRING>
 *
 * Return Value: ELITE karari yok sayilmali mi <BOOL>
 * Public: No
*/

params [["_g", grpNull, [grpNull]], ["_etiket", "?", [""]]];
if (isNull _g || {!(missionNamespace getVariable ["lambs_danger_senaryoModu", false])}) exitWith {false};
if (((units _g) findIf {isPlayer _x}) > -1) exitWith {false};
private _kapi = (missionNamespace getVariable ["lambs_danger_senaryoKapsam", 0]) isEqualTo 1;
if (!_kapi) then {
    private _cur = currentWaypoint _g;
    _kapi = ((waypoints _g) findIf {
        ((waypointName _x) find "ELITE") != 0 && {(_x select 1) > 0} && {(_x select 1) >= _cur}
    }) >= 0;
};
if (_kapi) then {
    private _tab = missionNamespace getVariable ["lambs_danger_senaryoSayac", createHashMap];
    _tab set [_etiket, (_tab getOrDefault [_etiket, 0]) + 1];
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
