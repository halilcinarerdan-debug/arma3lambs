#include "script_component.hpp"
/*
 * Author: Cinar (ELITE fork)
 * UFUK CIZGISI TESTI — [gozlemciASL, pozAGL, yukseklik] -> pozisyon, gozlemciden bakildiginda UFUK / GOKYUZU ARKASINDA mi?
 *
 * Gozlemci gozunden pozisyondaki basa dogru isin devam ettirilir (300 m); arkada arazi / nesne yoksa asker gokyuzune karsi
 * siluet olur (ufuk cizgisi) = en gorunur durum (egimin tepesi, yamac sirti). Yatik (0.4 m) asker cogu zaman arazi arkaligina sahiptir.
 *
 * Arguments:
 * 0: Gozlemci gozu <ARRAY ASL>
 * 1: Pozisyon <ARRAY AGL>
 * 2: Yukseklik m (yatik 0.4 / comelmis 1.0 / ayakta 1.7) <NUMBER>
 *
 * Return Value:
 * Siluet mi <BOOL>
 *
 * Public: No
*/

params ["_goz", "_poz", ["_h", 1.7]];
private _bas = AGLToASL (_poz vectorAdd [0, 0, _h]);
private _dir = vectorNormalized (_bas vectorDiff _goz);
private _son = _bas vectorAdd (_dir vectorMultiply 300);
!(terrainIntersectASL [_bas, _son]) && {!(lineIntersects [_bas, _son, objNull, objNull])}
