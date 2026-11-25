#include "script_component.hpp"
/*
 * Author: Cinar (ELITE fork)
 * ISARETLI BOMBACI ATES TEPKISI (v8.795; kullanici: 'bombaci uzakta durdu, yanindan mermi gecince').
 * fnc_eypBombaYap'in isaretli askere / araca bagladigi 'Suppressed' (mermi yanindan gecti), 'Hit' (vuruldu) ve 'FiredNear' (yakinda atis) olay isleyicileri cagirir.
 * Ates eden DUSMANSA: (1) birimde lambs_danger_eypAtesT = simdi, lambs_danger_eypAtesKaynak = atici yazilir -> bombaci dongusu tespit menzilini 30 sn boyunca >= 2500 m'ye genisletir ve hic hedef yoksa ATICIYA kosar (eskiden hedef tespit menzilinin disindaysa
 *   bombaci kosuya BASLAMADAN siradan AI gibi baski / siper tepkisiyle duruyordu: 'uzakta durdu'); (2) piyadede motor baski tepkisi (SUPPRESSION AI) kapatilir, ELITE katmanlari 6 sn geri cekilir (taktikKilit).
 * Log: [EYP-ISARET] ATES ALTINDA (ilk 15).
 *
 * Arguments:
 * 0: Bombaci (asker / arac) <OBJECT>
 * 1: Ates eden <OBJECT>
 *
 * Return Value: None
 * Public: No
*/

params [["_u", objNull, [objNull]], ["_f", objNull, [objNull]]];
if (isNull _u || {!alive _u} || {isNull _f} || {!alive _f} || {_f isEqualTo _u} || {_f isEqualTo (vehicle _u)}) exitWith {};
private _us = side group ([_u, driver _u] select (!(_u isKindOf "CAManBase") && {!isNull driver _u}));
private _fs = side group (effectiveCommander _f);
if (_fs isEqualTo civilian || {_us getFriend _fs >= 0.6}) exitWith {};
private _ilk = (time - (_u getVariable [QGVAR(eypAtesT), -999])) > 30;
_u setVariable [QGVAR(eypAtesT), time];
_u setVariable [QGVAR(eypAtesKaynak), _f];
if (_u isKindOf "CAManBase") then {
    _u disableAI "SUPPRESSION";
    _u setVariable [QGVAR(taktikKilit), time + 6];
};
if (_ilk) then {
    private _n = missionNamespace getVariable ["lambs_danger_eypAtesLogN", 0];
    if (_n < 15) then {
        missionNamespace setVariable ["lambs_danger_eypAtesLogN", _n + 1];
        diag_log format ["[EYP-ISARET] ATES ALTINDA | %1 | atici %2 | %3 m | tespit menzili 30 sn >= 2500 m, hedef yoksa aticiya kosar", typeOf _u, typeOf _f, round (_u distance _f)];
    };
};
