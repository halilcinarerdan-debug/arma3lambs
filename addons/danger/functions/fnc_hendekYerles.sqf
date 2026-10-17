#include "script_component.hpp"
/*
 * Author: Cinar (ELITE fork)
 * HENDEKTE YERLESME (v8.229) — SAVUN planinda bir grubun askerleri secilen hendek alaninin UZUN ekseni boyunca dagilir (her asker ayri nokta), vardiginda comelir (MIDDLE: 1.4 m hendekte siperde)
 * ve dis cevreye (tehdit yonu / objektife ters degil, objektife DOGRU degil: merkezden disa) bakar. doStop + comelme; plan bitince fnc_komutanPlanDongu cleanup'i birakir.
 * Kaynak ilkesi: ATP 3-21.8 / FM 3-21.10 mevzi: askerler hendege aralikli yerlesir, ates sektorlerine bakar (kitapta mesafe / sayi YOK; aralik = hendek uzunlugu / asker sayisi).
 * v8.243: grup 'mevziIlk' sayisini yazar; hendekteki grup LAMBS komutan beyni / buddy / dagilma / rol istasyonundan muaf (fnc_mevziDeMi); plan sonunda fnc_komutanPlanDongu 'hendekte' bayragini siler.
 * Log: [HENDEK-YERLES]
 *
 * Arguments:
 * 0: Grup <GROUP>
 * 1: Hendek indeksi (fnc_hendekAlani LISTE) <NUMBER>
 * 2: Bakis yonu (derece; tehdit / sektor) <NUMBER>
 *
 * Return Value: Yerlestirilen asker sayisi <NUMBER>
 * Public: No
*/

params [["_g", grpNull, [grpNull]], ["_idx", -1, [0]], ["_dirB", 0, [0]]];
if (isNull _g || {!local _g}) exitWith {0};
private _us = (units _g) select {alive _x && {isNull objectParent _x} && {!isPlayer _x} && {(lifeState _x) in ["HEALTHY", "INJURED"]}};
if (_us isEqualTo []) exitWith {0};
private _pts = ["NOKTALAR", _idx, count _us] call FUNC(hendekAlani);
if (_pts isEqualTo []) exitWith {0};
diag_log format ["[HENDEK-YERLES] %1 | %2 asker hendege (alan %3, %4 nokta) | bakis %5", groupId _g, count _us, _idx, count _pts, round _dirB];
{
    private _u = _x;
    private _pt = _pts select (_forEachIndex min ((count _pts) - 1));
    _u enableAI "PATH"; _u enableAI "MOVE";
    _u doMove _pt;
    [_u, _pt, _dirB] spawn {
        params ["_u", "_pt", "_dirB"];
        private _bit = time + 90;
        waitUntil { sleep 1; !alive _u || {(_u distance2D _pt) < 2.5} || {time > _bit} };
        if (alive _u) then {
            doStop _u;
            _u setUnitPos "MIDDLE";
            _u doWatch (_pt getPos [120, _dirB]);
        };
    };
} forEach _us;
_g setVariable [QGVAR(hendekte), true];
_g setVariable [QGVAR(mevziIlk), (_g getVariable [QGVAR(mevziIlk), 0]) max (count _us)];   // v8.243: fnc_tactics mevzi tutma kayip esigi (>= %60 kayipta serbest) bu sayiya gore
count _us
