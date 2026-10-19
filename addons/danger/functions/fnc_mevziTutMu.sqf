#include "script_component.hpp"
/*
 * Author: Cinar (ELITE fork)
 * MEVZI TUTULSUN MU (v8.257) — hendekte / mevzideki grup LAMBS taktiklerine (Suppress / Hide / Flank / Assault / ATEngage / EvadeArmor / Hold / Bounding) girmemeli.
 * RPT e31bd8bd: fnc_tactics'taki MEVZI TUT korumasi varken bile hendek gruplari 'Leader Suppress' + 'Group Suppress (Move)' (Alpha 1-5, 10:11:51; 8 asker hendekten 40-70 m cikti) ve 'Hide (holding)' (Alpha 1-3) gorevlerini aldi;
 * cagri yolu kesin bulunamadi -> koruma TAKTIK FONKSIYONLARININ GIRISINE de konuldu (hangi yoldan cagrilirsa cagrilsin).
 * Kural: fnc_mevziDeMi && (mevziIlk bilinmiyor ya da yasayan > mevziIlk x 0.4; fnc_tactics ile ayni esik) && mevziTutOff kapali. Plan karsi saldirisi / geri cekilme 'hendekte' bayragini once siler -> false doner.
 *
 * Arguments:
 * 0: Grup <GROUP>
 *
 * Return Value: tutulsun mu (taktik uygulanmasin) <BOOL>
 * Public: No
*/

params [["_g", grpNull, [grpNull, objNull]]];
if (_g isEqualType objNull) then { _g = group _g; };
if (isNull _g || {!([_g] call FUNC(mevziDeMi))}) exitWith {false};
private _ilk = _g getVariable [QGVAR(mevziIlk), 0];
(_ilk <= 0) || {({alive _x} count (units _g)) > (_ilk * 0.4)}
