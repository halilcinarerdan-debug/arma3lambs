#include "script_component.hpp"
/*
 * Author: Cinar (ELITE fork)
 * DRONA ZORLA ATES: VURUS OLASILIGI (v8.340; kullanici: 'dronlar cok hizli vuruluyor, bunu isabet carpanina entegre et' + 'ama isabet carpani fazla ise yine vurulsun').
 * Zorla ates (fnc_dronTepki piyade, fnc_tankDron tank) dronun gercek konumu + hizindan hesaplanan NOKTAYA kusursuz nisan aliyordu; becerinin etkisi yoktu. Artik her kisa atis (3-4 mermi) bu olasilikla yapilir:
 *   taban  = (aimingAccuracy - 0.25) / 0.72, 0..1   (aimingAccuracy, CBA isabet ayarlarini (taban / carpan / tavan) ZATEN icerir -> 0.97 ve ustu ~1.0, 0.80 ~0.76, 0.70 ~0.62, 0.50 ~0.35)
 *   mesafe = 1 - (mesafe - 100) / 600, 0.5..1       (100 m'ye kadar tam; 400 m'de 0.5)
 *   hiz    = 1 - dron hizi (m/s) / 80, 0.5..1
 *   olasilik = taban x mesafe x hiz x CBA 'dronIsabetOran' (varsayilan 1; 2 = iki kat), en cok 1.
 * Isabet carpani yuksekse taban ~1 olur: yakin / yavas dron yine vurulur. Tasarim sayilari [T]; kitapta karsiligi yok (kucuk silahla hava hedefi vurma olasiligi dusuktur: ATP 3-01.8 satir 2435).
 * Kapatma: lambs_danger_dronIsabetOff = true (eski: kusursuz).
 *
 * Arguments:
 * 0: Atici (asker ya da nisanci) <OBJECT>
 * 1: Dron <OBJECT>
 *
 * Return Value: Olasilik 0..1 <NUMBER>
 * Public: No
*/

params [["_u", objNull, [objNull]], ["_dr", objNull, [objNull]]];
if (isNull _u || {isNull _dr} || {missionNamespace getVariable ["lambs_danger_dronIsabetOff", false]}) exitWith {1};
private _acc = _u skill "aimingAccuracy";
private _taban = (((_acc - 0.25) / 0.72) max 0) min 1;
private _fm = (1 - (((_u distance _dr) - 100) / 600)) max 0.5 min 1;
private _fh = (1 - ((speed _dr) / 3.6 / 80)) max 0.5 min 1;
private _p = (_taban * _fm * _fh * (missionNamespace getVariable ["lambs_danger_dronIsabetOran", 1])) min 1;
if (isNil "lambs_danger_dronPLogN") then { lambs_danger_dronPLogN = 0; };
if (lambs_danger_dronPLogN < 40 && {random 1 < 0.1}) then {
    lambs_danger_dronPLogN = lambs_danger_dronPLogN + 1;
    diag_log format ["[DRON-ISABET] %1 | beceri %2 | mesafe %3 m (x%4) | dron hizi %5 km/s (x%6) | olasilik %7", typeOf _u, _acc toFixed 2, round (_u distance _dr), _fm toFixed 2, round (speed _dr), _fh toFixed 2, _p toFixed 2];
};
_p
