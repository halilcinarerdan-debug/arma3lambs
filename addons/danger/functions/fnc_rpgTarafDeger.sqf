#include "script_component.hpp"
/*
 * Author: Cinar (ELITE fork)
 * RPG TARAF BAZLI AYAR OKUYUCU (v8.802; kullanici: 'blufor opfor ve independent icin ayri ayri cba ayari ekle').
 * Tarafa ozel CBA ayari lambs_danger_<anahtar><West|East|Ind> degerini okur (BLUFOR = West, OPFOR = East, INDEPENDENT = Ind); ayar yoksa verilen varsayilan doner.
 * Sayisal ayarlarda -1 = 'genel ayari kullan' (cagiran taraf -1'i genel degere cevirir); onay kutularinda dogrudan true / false.
 * Kullanan: fnc_rpgSistem (rpgAktif, rpgMuhimmat, rpgMaxM), fnc_rpgGuvenli (rpgYedek).
 *
 * Arguments:
 * 0: Taraf <SIDE> ya da grup / birim (v8.845; doktrin bazli modda grup gerekir)
 * 1: Ayar anahtari (onek yok, taraf eki yok) <STRING> (ornek "rpgMaxM")
 * 2: Varsayilan <ANY>
 *
 * Return Value: Ayar degeri <ANY>
 *
 * Public: No
*/

params ["_taraf", "_anahtar", "_varsayilan"];
private _ek = [_taraf] call FUNC(ayarEk);   // v8.845: taraf / grup / birim (doktrin bazli modda DUZENSIZ = East profili)
if (_ek isEqualTo "") then { _ek = "Ind"; };
missionNamespace getVariable [format ["lambs_danger_%1%2", _anahtar, _ek], _varsayilan]
