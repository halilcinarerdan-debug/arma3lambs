#include "script_component.hpp"
/*
 * Author: Cinar (ELITE fork)
 * OYUNCU KOMUTASINDA MI (v8.602; kullanici: 'oyuncu komutasindaki botlar sapitmasin, komutlara uysun'): asker / grup oyuncu komutasindaysa true: grup LIDERI oyuncu ya da Zeus / otomatik 'oyuncu komutasi' bayragi (QGVAR(oyuncuKomutaAktif)).
 * Bot komutasinda oynayis (lider bot, oyuncu ast) true DEGILDIR: ELITE o grubu yonetmeye devam eder. Emir veren izleyiciler bu fonksiyonla oyuncunun AI takimini disarida birakir (hareket / durus / bakis / ates emirlerini ezmesin).
 *
 * Arguments:
 * 0: Asker ya da Grup <OBJECT / GROUP>
 *
 * Return Value: Oyuncu komutasinda mi <BOOL>
 * Public: No
*/

params [["_x", objNull, [objNull, grpNull]]];
private _g = if (_x isEqualType grpNull) then {_x} else {group _x};
if (isNull _g) exitWith {false};
private _l = leader _g;
(!isNull _l && {isPlayer _l}) || {_g getVariable [QGVAR(oyuncuKomutaAktif), false]}
