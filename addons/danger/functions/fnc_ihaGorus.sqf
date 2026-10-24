#include "script_component.hpp"
/*
 * Author: Cinar (ELITE fork)
 * IHA GORUS KATSAYISI (v8.344; kullanici: 'termal kullanimina gore ve kamuflaja gore, hava durumuna gore AI dronlar da etkilensin').
 * AI dronun (kamera) bir hedefi fark etme / kilitleme kolayligi: 0.10 - 1.00 (1 = acik gunduz, belirgin hedef). Kullanimi: tespit / kilit menzili = temel menzil x katsayi; kilit suresi / katsayi.
 *   TERMAL: dron sinifi / adi '_ti', ' ti', 'thermal', 'flir' icerir ya da vanilla UAV (UAV_0x) ise termal VAR; elle: arac degiskeni lambs_danger_ihaTermal (true / false). Termal gece ve sis/yagmurda daha az etkilenir ve sicak hedefi (motoru acik arac, kosan asker) belirginlestirir.
 *   ISIK: sunOrMoon (0-1). Gunduz 1; alacakaranlik azalir; gece termalsiz 0.25, termalli 0.85.
 *   HAVA: sis (fog) ve yagmur (rain): termalsiz sis x(1 - 0.7 fog), yagmur x(1 - 0.35 rain); termalli yarisi. Bulut (overcast) etkisi kucuk (x(1 - 0.1 overcast)).
 *   HEDEF KAMUFLAJI: asker: camouflageCoef (KAMUFLAJ sistemi), durus (yatik x0.55, comelmis x0.8), ustu ortulu (agac / cati 15 m icinde nesne) x0.65, hareket (> 2 m/sn) x1.2; termalde gece x1.25.
 *     arac: motor acik x1.25 (termalde x1.5), hareketli x1.2, ustu ortulu x0.65.
 *   Duman perdesi ayri (fnc_dumanPerde). Kapatma: lambs_danger_ihaGorusOff = true (katsayi hep 1). Sayilar [T] (kitapta yok; ilke: gozlem kosullari TC 3-21.76 gorus / ortu / gizlenme).
 *
 * Arguments:
 * 0: IHA <OBJECT>
 * 1: Hedef <OBJECT>
 *
 * Return Value: Katsayi 0.10..1 <NUMBER>
 * Public: No
*/

params [["_uav", objNull, [objNull]], ["_h", objNull, [objNull]]];
if (isNull _uav || {isNull _h} || {missionNamespace getVariable ["lambs_danger_ihaGorusOff", false]}) exitWith {1};

private _term = _uav getVariable ["lambs_danger_ihaTermal", -1];
if (_term isEqualType true) then { _term = [0, 1] select _term; };
if (_term < 0) then {
    private _ad = toLower ((typeOf _uav) + " " + getText (configOf _uav >> "displayName"));
    _term = [0, 1] select ((["_ti", " ti", "thermal", "flir", "uav_0", "ugv_0", "mq9", "mq-9", "predator", "reaper", "pchela", "orlan", "eleron", "raven"] findIf {(_ad find _x) >= 0}) >= 0);
    _uav setVariable ["lambs_danger_ihaTermal", _term isEqualTo 1];
};
private _t = _term isEqualTo 1;

private _gunes = sunOrMoon;
private _isik = if (_gunes >= 0.6) then {1} else { if (_gunes >= 0.15) then { 0.4 + ((_gunes - 0.15) / 0.45) * 0.6 } else { 0.25 } };
private _gece = _gunes < 0.15;
if (_t) then { _isik = [_isik max 0.85, 1] select (_isik >= 0.85); };

private _fog = fog;
private _rain = rain;
private _hava = (1 - ((overcast) * 0.1)) * ((1 - ([0.7, 0.35] select _t) * _fog) max 0.2) * ((1 - ([0.35, 0.15] select _t) * _rain) max 0.4);

private _hedef = 1;
if (_h isKindOf "CAManBase") then {
    private _c = _h getUnitTrait "camouflageCoef";
    if (_c isEqualType 0) then { _hedef = _hedef * (_c max 0.4 min 1.2); };
    _hedef = _hedef * ([1, 0.8, 0.55] select ((["UP", "MIDDLE", "DOWN"] find (unitPos _h)) max 0));
    private _ds = stance _h;
    if (_ds isEqualTo "PRONE") then { _hedef = _hedef * 0.55; } else { if (_ds isEqualTo "CROUCH") then { _hedef = _hedef * 0.8; }; };
    if ((speed _h) > 7) then { _hedef = _hedef * 1.2; };
    if (_t && {_gece}) then { _hedef = _hedef * 1.25; };
} else {
    if (isEngineOn _h) then { _hedef = _hedef * ([1.25, 1.5] select _t); };
    if ((speed _h) > 7) then { _hedef = _hedef * 1.2; };
};
// ustu ortulu (agac / cati): 15 m yukari isin
private _p = (getPosASL _h) vectorAdd [0, 0, 1];
if (lineIntersects [_p, _p vectorAdd [0, 0, 15], _h, _uav]) then { _hedef = _hedef * 0.65; };

(((if (_t) then {_isik} else {_isik}) * _hava * _hedef) max 0.1) min 1
