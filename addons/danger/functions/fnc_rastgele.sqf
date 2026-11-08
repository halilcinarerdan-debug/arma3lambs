#include "script_component.hpp"
/*
 * Author: Cinar (ELITE fork)
 * TOHUMLU RASTGELE (v8.501; Asama 7 adim 1): karar duzeyi rastgelelik icin 0..1 arasi sayi. Ayni (tohum, etiket, baglam [, sayac]) = ayni sayi; betik sirasindan BAGIMSIZ (global akis yok).
 * KULLANIM:
 *   [etiket, baglam]            -> 0..1; baglam bos / ayni ise sayac artar (ayni baglamda tekrarlanan cekimler farkli sayi verir)
 *   [etiket, baglam, false]     -> DURUMSUZ: ayni baglam her zaman ayni sayi (tercih: karar baglami = grup kimligi + hedef vb.)
 * HASH (24 bit guvenli): h = (h x 31 + karakter) mod 65537; sonra iki kez ZX81 uretecinden (x x 75 + 74) mod 65537; sonuc = (x1 + x2 / 65537) / 65537. Tohum 65537'e indirgenir.
 * Tohum yoksa (henuz baslamadiysa / istemcide) ya da lambs_danger_rastgeleEskiOff = true ise motorun random'una duser (tekrarlanabilir degil).
 *
 * Arguments:
 * 0: Etiket (sistem) <STRING>
 * 1: Baglam (grup kimligi, hedef vb.) <STRING>
 * 2: Sayac kullan <BOOL> (varsayilan true)
 *
 * Return Value: 0..1 <NUMBER>
 * Public: No
*/

params [["_etiket", "", [""]], ["_baglam", "", [""]], ["_say", true, [true]]];
private _tohum = missionNamespace getVariable ["lambs_danger_tohumDeger", -1];
if (_tohum < 0 || {missionNamespace getVariable ["lambs_danger_rastgeleEskiOff", false]}) exitWith { random 1 };

private _anahtar = _etiket + "|" + _baglam;
private _n = 0;
if (_say) then {
    private _tab = missionNamespace getVariable ["lambs_danger_rastgeleSayac", createHashMap];
    _n = _tab getOrDefault [_anahtar, 0];
    _tab set [_anahtar, _n + 1];
    missionNamespace setVariable ["lambs_danger_rastgeleSayac", _tab];
};
private _h = _tohum mod 65537;
{ _h = ((_h * 31) + _x) mod 65537; } forEach (toArray (_anahtar + "|" + str _n));
private _x1 = ((_h * 75) + 74) mod 65537;
private _x2 = ((_x1 * 75) + 74) mod 65537;
(_x1 + (_x2 / 65537)) / 65537
