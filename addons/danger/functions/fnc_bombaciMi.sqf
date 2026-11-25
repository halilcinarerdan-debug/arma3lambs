#include "script_component.hpp"
/*
 * Author: Cinar (ELITE fork)
 * PIYADE BOMBACI MI? (v8.798; kullanici: 'baski atesini daha akilli yapsinlar, bombada azalt' + 'arac haric' + 'siperde de check et').
 * Bastirma atesi (doSuppressiveFire) kaynaklari bu yardimciyla piyade bombaciyi iki yonden ayirir:
 *   ATICI olarak: kosan bombaci duvara / konuma bastirma atesi acmaz (RPT 44282768: bombaci 23 m'de [PENETRE-ATES] ile duvari tariyordu, kosusu durdu).
 *   HEDEF olarak: kosan piyade bombaciya konum bastirmasi YAPILMAZ (kosan hedefe alan atesi bos mermi ve bombaciyi yerinde dondurur); AI'nin kendi nisanli atesi normal calisir.
 * ARAC HARIC: arac bombasi (VBIED) ve aracin icindeki herkes icin her zaman false (eski davranis).
 * Piyade bombaci = (kosu sirasinda fnc_eypKos'un koydugu 'bombaKosuyor' bayragi) YA DA (Zeus / 3DEN / init ile isaretli: 'eypBomba'). CBA kapatma: lambs_danger_baskiBombaci.
 *
 * Arguments:
 * 0: Birim <OBJECT>
 *
 * Return Value: Piyade bombaci mi <BOOL>
 *
 * Public: No
*/

params [["_o", objNull, [objNull]]];
if (isNull _o || {!alive _o} || {!(_o isKindOf "CAManBase")} || {!isNull objectParent _o}) exitWith {false};
if !(missionNamespace getVariable ["lambs_danger_baskiBombaci", true]) exitWith {false};
(_o getVariable [QGVAR(bombaKosuyor), false]) isEqualTo true || {!isNil {_o getVariable QGVAR(eypBomba)}}
