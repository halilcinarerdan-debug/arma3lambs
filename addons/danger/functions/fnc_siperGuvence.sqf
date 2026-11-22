#include "script_component.hpp"
/*
 * Author: Cinar (ELITE fork)
 * COK ACILI SIPER GUVENCESI (v8.750; kullanici: 'siperi guclendir, elemanlar asiri iyi siper alsin, raycast hesaplasalar da acik bir yerden yiyorlar, amac oyuncularin vurmamasi'):
 * NEDEN: siper adayi yalniz BILINEN dusman konumundan (tek isin) ve yaklasik yon acikligindan sinaniyordu; oyuncu yandan / baska acidan ates ettiginde ayni siper acik kalabiliyordu (RPT 64b4517e: gercek siper %2-3,
 *   hareketsizken vurulan 5 / 4 / 2 asker her dakika). KURAL: aday nokta icin dusman yonunun +-35 ve +-70 derece SAPMASINDAKI 4 olasi atici konumundan (adayin dusmana mesafesi 30-120 m, goz 1.6 m) adayin KAFA noktasina (UP 1.6 / MIDDLE 1.0 / DOWN 0.4 m)
 *   gorus hatti (arazi + VIEW LOD) denenir; gorunen oran x siperCokAciliAg (6 puan) = CEZA (vurulduktan sonra 20 sn x2). Siper secimi onceden tek isinla kazanan adayi yalniz KAZANIRKEN bu sinava sokar (hesap maliyeti dusuk: kazanan basina 8 isin).
 *   Sonuc: dar agac / ince duvar / tek yonlu cukur yerine genis duvar / sokak arasi / arka kosesi kapali nesne tercih edilir.
 * OLCUM: [ACIK-SIPER-OZET] cokaci_n (sinanan aday) + cokaci_gor (gorunen atici konumu toplami; ortalama gorunen oran = cokaci_gor / (4 x cokaci_n)); karne SIPER COK ACILI GUVENCE.
 * CBA: lambs_danger_siperCokAcili (varsayilan ACIK), siperCokAciliAg (6).
 * SINIR: oyunda DENENMEDI; yalniz yer seviyesinden (yuksek zemin / cati yok), 4 konum; hareketli oyuncunun gercek konumunu bilmez (hile yok); acikta tum adaylar bir yonden gorunur -> yine en az gorunen secilir.
 *
 * Arguments:
 * 0: Aday nokta (AGL) <ARRAY>
 * 1: Bilinen dusman <OBJECT>
 * 2: Durus "UP" / "MIDDLE" / "DOWN" <STRING>
 * 3: Asker <OBJECT>
 *
 * Return Value: Ceza (puan, >= 0) <NUMBER>
 *
 * Public: No
*/

params ["_pt", "_en", ["_dn", "UP"], ["_u", objNull]];
if !(missionNamespace getVariable ["lambs_danger_siperCokAcili", true]) exitWith {0};
private _ag = ((missionNamespace getVariable ["lambs_danger_siperCokAciliAg", 6]) max 0) min 30;
if (_ag <= 0 || {isNull _en} || {!(_pt isEqualType [])} || {(count _pt) < 2}) exitWith {0};

private _hh = switch (_dn) do { case "DOWN": {0.4}; case "MIDDLE": {1.0}; default {1.6} };
private _hedef = [_pt select 0, _pt select 1, (getTerrainHeightASL [_pt select 0, _pt select 1]) + _hh];
private _b = _pt getDir _en;
private _D = ((_pt distance2D _en) max 30) min 120;
private _gor = 0;
{
    private _sp = _pt getPos [_D, _b + _x];
    private _eye = [_sp select 0, _sp select 1, (getTerrainHeightASL [_sp select 0, _sp select 1]) + 1.6];
    if (!(terrainIntersectASL [_eye, _hedef]) && {(lineIntersectsSurfaces [_eye, _hedef, _u, objNull, true, 1, "VIEW", "NONE"]) isEqualTo []}) then { _gor = _gor + 1; };
} forEach [-70, -35, 35, 70];

private _say = missionNamespace getVariable ["lambs_danger_acikSiperSay", createHashMap];
missionNamespace setVariable ["lambs_danger_acikSiperSay", _say];
_say set ["cokaci_n", (_say getOrDefault ["cokaci_n", 0]) + 1];
_say set ["cokaci_gor", (_say getOrDefault ["cokaci_gor", 0]) + _gor];

_ag * (_gor / 4) * ([1, 2] select ((time - (_u getVariable [QGVAR(vurulduT), -99])) < 20))
