#include "script_component.hpp"
/*
 * Author: Cinar (ELITE fork)
 * EYP PATLAMA (ortak) (v8.777; kullanici referans kodlari: aral_canl_bomba / canl_bomba / eyp_deme -> patlama siniflari).
 * Verilen konumda, tur ve CBA eypPatlamaGucu (0-2) seviyesine gore senaryo patlayici nesneleri / mermi siniflari olusturur (createVehicle; gercek yapim / tetik bilgisi YOKTUR, oyun efekti).
 *   Seviye 0 (hafif)  : her tur DemoCharge_Remote_Ammo_Scripted
 *   Seviye 1 (orta, varsayilan): piyade = DemoCharge + R_TBG32V_F; arac = Bo_Mk82; ied = DemoCharge + R_TBG32V_F
 *   Seviye 2 (referans): piyade = DemoCharge + R_TBG32V_F; arac = Bo_GBU12_LGB + HelicopterExploBig; ied = Bo_GBU12_LGB
 * Mermi siniflari (Bo_ / R_) olusturulunca triggerAmmo ile patlatilir; DemoCharge setDamage 1 ile.
 * Log: [EYP-PATLAT] (ilk 20: tur, seviye, siniflar).
 * SINIR: oyunda DENENMEDI; yuksek seviyede olum yaricapi buyuk (kendi tarafa da zarar verir); mermi sinifinin createVehicle'da aninda patlamasi surume / modlara bagli olabilir.
 *
 * Arguments:
 * 0: Konum (AGL) <ARRAY>
 * 1: Tur "piyade" / "arac" / "ied" <STRING> (varsayilan "piyade")
 * 2: Guc secimi 0-2 <NUMBER> (varsayilan -1 = CBA eypPatlamaGucu; editor / Zeus modulleri birim basina verir)
 *
 * Return Value: Olusturulan nesne sayisi <NUMBER>
 *
 * Public: No
*/

params [["_poz", [0, 0, 0], [[]]], ["_tur", "piyade", [""]], ["_gucOv", -1, [0]]];
private _guc = round (((if (_gucOv >= 0) then {_gucOv} else {missionNamespace getVariable ["lambs_danger_eypPatlamaGucu", 1]}) max 0) min 2);
private _D = "DemoCharge_Remote_Ammo_Scripted";
private _siniflar = switch (_guc) do {
    case 0: { [_D] };
    case 2: { switch (_tur) do { case "arac": {["Bo_GBU12_LGB", "HelicopterExploBig", _D]}; case "ied": {["Bo_GBU12_LGB", _D]}; default {[_D, "R_TBG32V_F"]} } };
    default { switch (_tur) do { case "arac": {["Bo_Mk82", _D]}; case "ied": {[_D, "R_TBG32V_F"]}; default {[_D, "R_TBG32V_F"]} } };
};
private _n = 0;
{
    private _c = _x;
    private _pp = +_poz;
    _pp resize 3;
    if (_c isNotEqualTo _D) then { _pp set [2, ((_pp select 2) max 0) + 0.3]; };
    private _o = createVehicle [_c, _pp, [], 0, "CAN_COLLIDE"];
    if (!isNull _o) then {
        _n = _n + 1;
        if (_c isEqualTo _D) then { _o setDamage 1; } else { triggerAmmo _o; };
    };
} forEach _siniflar;
private _ln = missionNamespace getVariable ["lambs_danger_eypPatlatLogN", 0];
if (_ln < 20) then {
    missionNamespace setVariable ["lambs_danger_eypPatlatLogN", _ln + 1];
    diag_log format ["[EYP-PATLAT] tur %1 | guc %2 | siniflar %3 | olusan %4 | xy %5", _tur, _guc, _siniflar joinString "+", _n, _poz select [0, 2] apply { round _x }];
};
_n
