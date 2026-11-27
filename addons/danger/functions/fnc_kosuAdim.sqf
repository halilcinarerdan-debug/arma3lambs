#include "script_component.hpp"
/*
 * Author: Cinar (ELITE fork)
 * SCRIPT KOSU (SON CARE; v8.823; kullanici: 'fixle'; RPT 01a3fcd2 (v8.822, 14 dk): [SIPER-VARIS] ULASILAMADI 10 (hareket kurtarma merdiveninin 4 adimi da sonuc vermedi; hepsi yol acik (yolTara 1.00), komut MOVE, baski ~0, siper noktasina 6-20 m kala, biri 55 m);
 *   merdiven adim basina yurudu %50-67. KOK NEDEN hala bilinmiyor (motor emri aliyor ama yurumuyor).
 * Merdiven (fnc_hareketKurtar) tukendikten sonra ve yalniz yakin (<= 30 m), DUZ ve acik (yolTara oran <= 1.05) hedef icin: asker AI'in yurumesi BEKLENMEDEN kosu animasyonuyla (AmovPercMrunSras...Df / AmovPknlMrunSras...Df; tufek / tabanca) hedefe BAKTIRILIP (setDir) ve hizi
 *   birim basina her karede setVelocityModelSpace [0, 4, z] ile surulur (en cok 8 sn, retreat 12 sn; hedefe < 2.5 m, token degisimi, retreat / kosucu, olum / baygin -> durur). Gorunur davranis normal kosu animasyonudur; yalniz yol / AI beyni atlanir (yolTara duz hatti dogruladi).
 *   Bittiginde hiz sifirlanir, asker kendi AI'ina doner (doMove hedefe yeniden). Yalniz yerel AI, arac disi, oyuncusuz, tufek / tabanca elde (diger silahta atlanir).
 * Arguments: 0: Asker <OBJECT> | 1: Hedef (AGL) <ARRAY> | 2: Kaynak <STRING> (varis)
 * Return Value: Baslatildi mi <BOOL>
 * CBA: lambs_danger_hareketKurtarKos (varsayilan acik). Log: [KOSU-ADIM] BASLA / BITTI (ilk 20, sonra 30 sn'de bir) + sayac.
 * Public: No
*/
params [["_u", objNull, [objNull]], ["_hedef", [], [[]]], ["_kaynak", "?", [""]]];
if (isNull _u || {!alive _u} || {isPlayer _u} || {!local _u} || {!isNull objectParent _u} || {(count _hedef) < 2}) exitWith {false};
if !(missionNamespace getVariable ["lambs_danger_hareketKurtarKos", true]) exitWith {false};
private _ret = ((_kaynak select [0, 7]) isEqualTo "retreat") || {(_kaynak select [0, 5]) isEqualTo "bomba"};   // v8.831: bombaci kosusu da (forceMove / isRetreating engeli yok)   // v8.825: geri cekilme kosucusu icin de (retreat bacagi): forceMove / isRetreating engeli yok (cagiran retreat dali kendisi istiyor)
if ((!_ret && {(_u getVariable [QGVAR(forceMove), false]) isEqualTo true || {(group _u) getVariable [QGVAR(isRetreating), false]}}) || {!((lifeState _u) in ["HEALTHY", "INJURED"])} || {_u getVariable ["ACE_isUnconscious", false]}) exitWith {false};
private _an = toLower (animationState _u);
private _w = ["wrfl", "wpst"] select { (_an find _x) >= 0 };
if (_w isEqualTo []) then { _w = if ((currentWeapon _u) isEqualTo (handgunWeapon _u) && {(handgunWeapon _u) isNotEqualTo ""}) then { ["wpst"] } else { ["wrfl"] }; };
if ((currentWeapon _u) isNotEqualTo "" && {(currentWeapon _u) isNotEqualTo (primaryWeapon _u)} && {(currentWeapon _u) isNotEqualTo (handgunWeapon _u)}) exitWith {false};   // yukleyici vb. elde: atla
private _kosAnim = format ["AmovP%1MrunSras%2Df", ["erc", "knl"] select ((stance _u) isEqualTo "CROUCH"), _w select 0];
private _tok = time + (random 0.001);
_u setVariable [QGVAR(kosuAdimTok), _tok];
_u setVariable [QGVAR(taktikKilit), time + ([10, 15] select _ret)];
_u setUnitPosWeak (["UP", "MIDDLE"] select ((stance _u) isEqualTo "CROUCH"));
_u enableAI "ANIM";
_u enableAI "MOVE";
private _p0 = getPosATL _u;
private _say = missionNamespace getVariable ["lambs_danger_kosuAdimSay", createHashMap];
missionNamespace setVariable ["lambs_danger_kosuAdimSay", _say];
_say set ["basla", (_say getOrDefault ["basla", 0]) + 1];
if (["kosuAdim", 20, 30] call FUNC(logIzin)) then {
    diag_log format ["[KOSU-ADIM] BASLA | %1 | %2 | %3 | hedefe %4 m | durus %5 | komut %6 | anim %7 -> %8", _kaynak, groupId (group _u), name _u, round (_p0 distance2D _hedef), stance _u, currentCommand _u, animationState _u, _kosAnim];
};
private _hiz = if ((_kaynak select [0, 5]) isEqualTo "bomba") then {5.5} else { if (_ret) then {4.5} else {4} };   // m/sn (bombaci 5.5, retreat 4.5, siper 4)
// v8.834 AKICI KOSU (kullanici: 'animasyon bazen oldugu yerde kaliyor, sipere zorlanirken engele takilabiliyor, zorlama cok iyi ama pek akici degil'; RPT 8dd900cd: 23 script kosunun 9'u 'sure doldu', 5'inde 8 sn'de 0-6 m, hedefe 3-6 m kala = siper nesnesine dayanma / engel yonlendirmenin yon degistirip titremesi):
//   (1) hedefe <= 3.5 m: engel yonlendirme KAPALI (siper nesnesine yaklasilir); (2) bakis yonu donus hizi sinirli (360 derece/sn), (3) hiz rampasi: ilk 0.6 sn'de 0 -> tam, hedefe 5 m kala yavaslar (min %45); (4) yonlendirme histerezisi: secilen sapma en az 0.7 sn tutulur;
//   (5) takilma: 1 sn'de < 0.5 m ilerleme -> 0.8 sn yan adim (+-70 derece), 3 takilmada kosu biter; (6) animasyon: kosu animasyonu baslangicta playMoveNow; switchMove YALNIZ 1.5 sn'den uzun bosta kalinca ve en cok 2 sn'de bir (animasyon sicramasi / donuk kare azalir).
private _durum = [time, getPosATL _u, time, 0, 0, 0, 0, 0];   // [son kare, son konum, son konum zamani, takilma sayisi, secilen sapma, sapma bitis, yonlendirme sayisi, yan adim sayisi]
[{
    params ["_args", "_h"];
    _args params ["_a", "_hd", "_tok", "_t0", "_kosAnim", "_ky", "_p0", "_ret", "_sureMax", "_hz", "_st"];
    private _bitir = {
        params ["_neden"];
        [_h] call CBA_fnc_removePerFrameHandler;
        if (!isNull _a && {alive _a}) then {
            _a setVelocityModelSpace [0, 0, (velocityModelSpace _a) select 2];
            _a setVariable [QGVAR(taktikKilit), nil];
            _a doMove _hd;
            private _s = missionNamespace getVariable ["lambs_danger_kosuAdimSay", createHashMap];
            private _k = if ((_a distance2D _hd) < 4) then {"vardi"} else {"varamadi"};
            _s set [_k, (_s getOrDefault [_k, 0]) + 1];
            missionNamespace setVariable ["lambs_danger_kosuAdimSay", _s];
            if (["kosuAdimBitti", 20, 30] call FUNC(logIzin)) then {
                diag_log format ["[KOSU-ADIM] BITTI | %1 | %2 | %3 | %4 | %5 sn | kat edilen %6 m | hedefe %7 m | takilma %8 yonlendirme %9 | anim %10 | hiz %11 km/sa | komut %12", _ky, groupId (group _a), name _a, _neden, (time - _t0) toFixed 1, round ((getPosATL _a) distance2D _p0), round ((getPosATL _a) distance2D _hd), _st select 3, _st select 6, animationState _a, round (speed _a), currentCommand _a];
            };
        };
    };
    if (isNull _a || {!alive _a}) exitWith { ["olu"] call _bitir; };
    if ((_a getVariable [QGVAR(kosuAdimTok), 0]) isNotEqualTo _tok) exitWith { ["yeni emir (token)"] call _bitir; };
    if (!((lifeState _a) in ["HEALTHY", "INJURED"]) || {_a getVariable ["ACE_isUnconscious", false]}) exitWith { ["yarali / baygin"] call _bitir; };
    if (!_ret && {(group _a) getVariable [QGVAR(isRetreating), false] || {(_a getVariable [QGVAR(forceMove), false]) isEqualTo true}}) exitWith { ["retreat / kosucu"] call _bitir; };
    if ((time - _t0) > _sureMax) exitWith { ["sure doldu"] call _bitir; };
    private _pa = getPosATL _a;
    private _kalan = _pa distance2D _hd;
    if (_kalan < 2.5) exitWith { ["hedefe vardi"] call _bitir; };
    private _dt = ((time - (_st select 0)) max 0.008) min 0.1;
    _st set [0, time];
    // takilma algilayici (1 sn'de < 0.5 m): yan adim, 3 takilmada bitir
    if ((time - (_st select 2)) >= 1) then {
        if ((_pa distance2D (_st select 1)) < 0.5 && {_kalan > 3.5} && {(time - _t0) > 1.2}) then {
            _st set [3, (_st select 3) + 1];
            if ((_st select 3) >= 3) exitWith { ["takildi (3 kez)"] call _bitir; };
            _st set [4, [70, -70] select ((_st select 3) mod 2)];
            _st set [5, time + 0.8];
            _st set [7, (_st select 7) + 1];
        };
        _st set [1, _pa];
        _st set [2, time];
    };
    if ((_st select 3) >= 3) exitWith {};
    // v8.831 ENGEL YONLENDIRME (+ v8.834: hedefe <= 3.5 m kapali, histerezis)
    private _hedefYon = _pa getDir _hd;
    private _yonSec = _hedefYon;
    if (time < (_st select 5)) then { _yonSec = _hedefYon + (_st select 4); } else {
        if (_kalan > 3.5) then {
            private _temiz = {
                params ["_dy"];
                private _p1 = (getPosASL _a) vectorAdd [0, 0, 0.7];
                private _p2 = _p1 vectorAdd [(sin _dy) * 1.6, (cos _dy) * 1.6, 0];
                ((lineIntersectsSurfaces [_p1, _p2, _a, objNull, true, 2, "GEOM", "NONE"]) findIf { private _o = _x select 2; (!isNull _o) && {!(_o isKindOf "CAManBase")} && {!(_o isKindOf "Animal")} }) < 0
            };
            if !([_hedefYon] call _temiz) then {
                private _on = _st select 4;
                private _bulundu = false;
                { if (!_bulundu && {[_hedefYon + _x] call _temiz}) then { _yonSec = _hedefYon + _x; _bulundu = true; if (_x isNotEqualTo _on) then { _st set [4, _x]; _st set [5, time + 0.7]; _st set [6, (_st select 6) + 1]; }; }; } forEach ([_on, 40, -40, 80, -80, 120, -120] arrayIntersect [_on, 40, -40, 80, -80, 120, -120]);
                if (!_bulundu) then { _st set [3, 3]; };
            };
        };
    };
    if ((_st select 3) >= 3) exitWith { ["engel (temiz yon yok)"] call _bitir; };
    // yumusak donus (en cok 360 derece/sn)
    private _cur = getDir _a;
    private _fark = (((_yonSec - _cur) + 540) mod 360) - 180;
    _a setDir (_cur + ((_fark max (-360 * _dt)) min (360 * _dt)));
    // animasyon
    if ((toLower (animationState _a)) find "mrun" < 0) then {
        if ((time - _t0) > 1.5 && {(speed _a) < 1.5} && {time > ((_a getVariable [QGVAR(kosuSwT), 0]) + 2)}) then { _a setVariable [QGVAR(kosuSwT), time]; _a switchMove _kosAnim; } else {
            if (time > ((_a getVariable [QGVAR(kosuPmT), 0]) + 0.4)) then { _a setVariable [QGVAR(kosuPmT), time]; _a playMoveNow _kosAnim; };
        };
    };
    // hiz profili (rampa + yavaslama)
    private _rampa = (((time - _t0) / 0.6) max 0.15) min 1;
    private _yav = if (_kalan < 5) then { ((_kalan / 5) max 0.45) min 1 } else { 1 };
    private _v = velocityModelSpace _a;
    _a setVelocityModelSpace [0, _hz * _rampa * _yav, _v select 2];
}, 0, [_u, _hedef, _tok, time, _kosAnim, _kaynak, _p0, _ret, (((_p0 distance2D _hedef) / 3) + 4) max ([8, 12] select _ret) min 18, _hiz, _durum]] call CBA_fnc_addPerFrameHandler;
true
