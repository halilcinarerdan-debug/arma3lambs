#include "script_component.hpp"
/*
 * Author: Cinar (ELITE fork)
 * NAKIL V2 (v8.500, dal claude/nakil-v2) - personel nakli YENI CEKIRDEK. Eski fnc_aracTasima ile AYNI giris / cikis sozlesmesi (komutan plani ona gore yazildi), ama tek betik, tek dongu, acik durum makinesi.
 * Neden: eski sistemde her arac kendi betiginde ic ice bekleme dongusu, tek tek bayrak ve birbirine mudahale eden yamalar vardi (acikta kalan, erken kalkan, tekrar tekrar alinip inen asker, ayni grubun iki planda olmasi, konvoyda gecme yarisi).
 *
 * AKIS (hepsi bu betikte, siralı):
 *   1 HAVUZ      : AI suruculu, grubu aracta, plan / gorev disi kara araclari (oyuncu YOLCU ise arac kalir); gercek koltuk = ogrenilmis kapasite ya da cargo koltuk sayisi.
 *   2 MANIFEST   : birimler (oyuncu grubu EN ONDE, sonra buyuk gruplar) araclara KOLTUK SAYISINA gore, once grup butun olarak yerlestirilir; sigmayan yaya kalir (plan zaten yaya yuruyus ister).
 *   3 YUKLEME    : arac manifestteki askerlerin merkezine gider; 60 m'de durur, asker binmeye emir alir; 20 sn sonra kalan (<= 300 m) asker aracin DUZ koltuguna oturtulur (aciktta kalan olmaz).
 *                  Oyuncu varsa en cok 90 sn beklenir (sohbet bildirimi); binmezse ekibi de inerek oyuncuyla kalir. Arac gercek koltugu doldurursa kapasite ogrenilir.
 *   4 KAPI       : TUM araclar hazir olana (en cok 120 sn) + plan kapisi (tasimaCtl[1]: recon / tank) acilana (en cok 'nakilTutmaS') kadar tum konvoy yuklu BEKLER.
 *   5 SURUS      : konvoy BIRLIKTE kalkar. Sira inise yakinliga gore dinamik; arkadaki arac onundekinin hizini (+3 m/sn) asmaz, 12 m'den yaklasmaz (gecme yarisi biter). Yol zinciri (300 m ara nokta),
 *                  takilma kurtarma (yeniden emir -> itme -> 25 m ileri tasima -> en cok 120 sn), temasta ya da inis yakininda dur.
 *   6 INIS       : hepsi birlikte iner (doGetOut -> 6 sn -> moveOut), asker serbest birakilir, arac RP'ye doner, IFV'ler ates destegine (tasimaCtl[5]) eklenir.
 *
 * SOZLESME (eski ile ayni): _ctl = [iptal, kapi, binen asker, yuklenen arac, toplam arac, IFV grup listesi, ...]; plan _ctl[0] = true yapinca nakil iptal olur.
 * Diger sistemlerin kullandigi bayraklar: lambs_danger_tasimaMesgul (arac), lambs_danger_tasimaBekle (asker), lambs_danger_tasimaSonT / aracMedevacT (arac grubu), lambs_danger_durgunSn (arac).
 * Kapatma (eski sisteme don): lambs_danger_nakilV2 = false. Bilinen eksikler (V2 ilk surum): su gecidi / pusu / kurtarma nakli (yedek arac) YOK; temasta dogrudan iner.
 *
 * Arguments: eski aracTasima ile ayni
 * Return Value: tasinan asker sayisi <NUMBER>
 * Public: No
*/

params ["_taraf", "_gruplar", "_rp", "_obj", "_B", "_orpM", ["_menzil", 2500], ["_ctl", [false, true, 0]]];
if (missionNamespace getVariable ["lambs_danger_tasimaOff", false]) exitWith {0};

private _log = { params ["_m"]; diag_log format ["[NAKIL2] %1 | %2", _taraf, _m]; };
private _g0 = _gruplar param [0, grpNull];

// ===================================================================== 0 INIS NOKTASI
private _inisM = [_g0, "tasimaInisM", 500] call FUNC(dk);
private _dropM = if ([_g0, "tasimaOrpEk", true] call FUNC(dk)) then { _inisM max (_orpM + 150) } else { _inisM };
private _drop = _obj getPos [_dropM, _B];
if (surfaceIsWater _drop) then { _drop = _obj getPos [(_dropM + 100), _B]; };
private _yollar = (_drop nearRoads 250) select {((getPosATL _x) distance2D _obj) >= (_dropM - 40) && {!surfaceIsWater (getPosATL _x)}};
if (_yollar isNotEqualTo []) then {
    _yollar = ([_yollar, [], {_x distance2D _drop}, "ASCEND"] call BIS_fnc_sortBy) select [0, 25];
    private _eniY = _yollar select 0;
    private _eniS = -1e9;
    {
        private _yp = getPosATL _x;
        private _engel = (lineIntersectsSurfaces [(AGLToASL [_yp select 0, _yp select 1, 2]), (AGLToASL [_obj select 0, _obj select 1, 1.5]), objNull, objNull, true, 1, "VIEW", "FIRE"]) isNotEqualTo [];
        private _ob = count (nearestTerrainObjects [_yp, ["TREE", "ROCK", "WALL", "BUILDING", "HIDE", "BUSH"], 40, false, true]);
        private _sc = ([0, 30] select _engel) + ((_ob min 24) * 1.2) - 0.05 * (_yp distance2D _drop);
        if (_sc > _eniS) then { _eniS = _sc; _eniY = _x; };
    } forEach _yollar;
    _drop = getPosATL _eniY;
};

// ===================================================================== 1 PERSONEL + HAVUZ
private _yayaMi = { params ["_u"]; alive _u && {isNull objectParent _u} && {(lifeState _u) in ["HEALTHY", "INJURED"]} && {(_u distance2D _obj) > (_dropM + 150)} };
private _gListe = +_gruplar;
// oyuncu: yaya oyuncu + ekibi plan grubu olmasa da nakle alinir (en onde)
private _oyunG = [];
if (!(missionNamespace getVariable ["lambs_danger_tasimaOyuncuOff", false])) then {
    { if (alive _x && {isNull objectParent _x} && {(side (group _x)) isEqualTo _taraf} && {(_x distance2D _obj) > (_dropM + 150)}) then { _oyunG pushBackUnique (group _x); }; } forEach allPlayers;
};
private _tum = _oyunG + (_gListe select {!(_x in _oyunG)});
private _merkez = {
    params ["_ul"];
    private _sx = 0; private _sy = 0; private _n = 0;
    { _sx = _sx + ((getPosATL _x) select 0); _sy = _sy + ((getPosATL _x) select 1); _n = _n + 1; } forEach _ul;
    if (_n isEqualTo 0) then {[]} else {[_sx / _n, _sy / _n, 0]}
};
private _tumBirim = [];
{ _tumBirim append ((units _x) select {[_x] call _yayaMi}); } forEach _tum;
if (_tumBirim isEqualTo []) exitWith { ["tasinacak yaya asker yok"] call _log; 0 };
private _pickRef = [_tumBirim] call _merkez;

private _haric = ["HARIC", "MEDEVAC", "TOPCU", "TOPCU_YOK", "KARAKOL_ARAC", "RECON_ARAC"];
private _kapFn = {
    params ["_v"];
    private _ogr = missionNamespace getVariable [format ["lambs_danger_tasimaKap_%1", typeOf _v], -1];
    private _koltuk = count (fullCrew [_v, "cargo", true]);
    if (_ogr > 0) then { _ogr min _koltuk } else { _koltuk }
};
// su an BOS yolcu koltugu (icinde onceden yolcu varsa dusulur; ogrenilmis gercek kapasite tavandir)
private _bosFn = {
    params ["_v"];
    private _top = [_v] call _kapFn;
    private _dolu = (count (fullCrew [_v, "cargo", true])) - ([_v] call FUNC(aracDuzBos));
    ((_top - (_dolu max 0)) max 0) min ([_v] call FUNC(aracDuzBos))
};
private _otomatik = missionNamespace getVariable ["lambs_danger_tasimaOtomatik", true];
private _aday = vehicles select {
    private _v = _x;
    private _d = driver _v;
    private _vg = group _d;
    alive _v && {_v isKindOf "LandVehicle"} && {canMove _v} && {(fuel _v) > 0.1} && {!isNull _d} && {!isPlayer _d} && {local _d} && {(side _vg) isEqualTo _taraf}
    && {((units _vg) findIf {alive _x && {(vehicle _x) isNotEqualTo _v}}) isEqualTo -1}
    && {!(_vg getVariable [QGVAR(planAktif), false])} && {(time - (_vg getVariable [QGVAR(tasimaSonT), -999])) > 15}
    && {!(((_v getVariable ["lambs_danger_gorev", ""]) in _haric) || {((_vg getVariable ["lambs_danger_gorev", ""]) in _haric)})}
    && {((crew _v) findIf {isPlayer _x && {(toLower ((assignedVehicleRole _x) param [0, "cargo"])) isNotEqualTo "cargo"}}) isEqualTo -1}
    && {!(_v getVariable [QGVAR(tasimaMesgul), false])} && {!(_v getVariable [QGVAR(reconArac), false])} && {!(_v getVariable [QGVAR(medevacRezerv), false])}
    && {(getNumber (configOf _v >> "attendant")) isEqualTo 0}
    && {(_v distance2D _pickRef) <= _menzil}
    && {([_v] call _kapFn) >= 3}
};
private _atanan = _aday select {((_x getVariable ["lambs_danger_gorev", ""]) isEqualTo "TASIMA") || {((group (driver _x)) getVariable ["lambs_danger_gorev", ""]) isEqualTo "TASIMA"}};
private _araclar = if (_atanan isNotEqualTo []) then {_atanan} else { if (_otomatik) then {_aday} else {[]} };
// atanmis araclarin koltugu yetmiyorsa atanmamis uygun araclar eklenir
private _kapT = 0;
{ _kapT = _kapT + ([_x] call _kapFn); } forEach _araclar;
if (_atanan isNotEqualTo [] && {_kapT < count _tumBirim}) then {
    private _ek = [_aday - _araclar, [], {_x distance2D _pickRef}, "ASCEND"] call BIS_fnc_sortBy;
    { if (_kapT >= count _tumBirim) exitWith {}; _araclar pushBack _x; _kapT = _kapT + ([_x] call _kapFn); } forEach _ek;
};
if (_araclar isEqualTo []) exitWith { [format ["arac YOK (aday %1, atanmis %2, birim %3)", count _aday, count _atanan, count _tumBirim]] call _log; 0 };
_araclar = [_araclar, [], {_x distance2D _pickRef}, "ASCEND"] call BIS_fnc_sortBy;

// ===================================================================== 2 MANIFEST
private _kalan = _araclar apply { [_x, [_x] call _bosFn] };   // [arac, bos koltuk]
private _manifest = _araclar apply { [_x, []] };            // [arac, [birimler]]
private _yerle = {
    params ["_ul"];   // grubu BUTUN olarak en uygun (sigan en az bos koltuklu) araca
    private _i = -1; private _en = 1e6;
    { if ((_x select 1) >= count _ul && {(_x select 1) < _en}) then { _en = _x select 1; _i = _forEachIndex; }; } forEach _kalan;
    if (_i < 0) exitWith { false };
    (_kalan select _i) set [1, ((_kalan select _i) select 1) - count _ul];
    ((_manifest select _i) select 1) append _ul;
    true
};
private _yaya = [];
{
    private _ul = (units _x) select {[_x] call _yayaMi};
    if (_ul isEqualTo []) then { continue };
    if !([_ul] call _yerle) then {
        // butun sigmadi: en bos araclara bolerek yerlestir (grup birlikte binmeli; yoksa yaya)
        private _top = 0;
        { _top = _top + (_x select 1); } forEach _kalan;
        if (_top >= count _ul) then {
            private _rest = +_ul;
            while {_rest isNotEqualTo []} do {
                private _j = -1; private _mx = 0;
                { if ((_x select 1) > _mx) then { _mx = _x select 1; _j = _forEachIndex; }; } forEach _kalan;
                if (_j < 0) exitWith {};
                private _al = _rest select [0, _mx min (count _rest)];
                _rest = _rest select [count _al, count _rest];
                (_kalan select _j) set [1, ((_kalan select _j) select 1) - count _al];
                ((_manifest select _j) select 1) append _al;
            };
        } else { _yaya pushBack format ["%1 (%2 asker, bos koltuk %3: SIGMADI)", groupId _x, count _ul, _top]; };
    };
} forEach _tum;
// onceden aracta olan yolcular (oyuncunun bindirdigi dahil) manifeste eklenir: arac bunlarla birlikte gider (>= 2 yolcu varsa manifestsiz de gider)
{
    private _vv = _x select 0;
    private _vgg = group (driver _vv);
    private _yol = (crew _vv) select {alive _x && {(group _x) isNotEqualTo _vgg} && {(lifeState _x) in ["HEALTHY", "INJURED"]}};
    if (_yol isNotEqualTo [] && {((_x select 1) isNotEqualTo []) || {count _yol >= 2}}) then { (_x select 1) append (_yol - (_x select 1)); };
} forEach _manifest;
_manifest = _manifest select {(_x select 1) isNotEqualTo []};
if (_manifest isEqualTo []) exitWith { ["manifest bos (hicbir grup sigmadi)"] call _log; 0 };
private _nM = 0;
{ _nM = _nM + count (_x select 1); } forEach _manifest;
[format ["MANIFEST: %1 arac / %2 asker | yaya kalan grup: %3 | inis %4 (hedeften %5 m) | oyuncu nakli: %6", count _manifest, _nM, _yaya, mapGridPosition _drop, round (_drop distance2D _obj), _oyunG apply {groupId _x}]] call _log;
{ [format ["  %1 -> %2 (%3 koltuk): %4", getText (configOf (_x select 0) >> "displayName"), count (_x select 1), [_x select 0] call _kapFn, (_x select 1) apply {name _x}]] call _log; } forEach _manifest;

_ctl set [3, 0];
_ctl set [4, count _manifest];
_ctl set [2, _nM];   // plan: nakil gercekten yapiliyor (> 0)

// birimler araclar gelene kadar bekler (oyuncu haric)
{ { if (alive _x && {!isPlayer _x}) then { _x setVariable [QGVAR(tasimaBekle), true]; doStop _x; _x disableAI "PATH"; }; } forEach (_x select 1); } forEach _manifest;
{ (_x select 0) setVariable [QGVAR(nk2Zincir), []]; (_x select 0) setVariable [QGVAR(nk2ZincirDene), false]; (_x select 0) setVariable [QGVAR(nk2DurT), -1]; (_x select 0) setVariable [QGVAR(nk2PrgD), []]; } forEach _manifest;
{ (_x select 0) setVariable [QGVAR(tasimaMesgul), true]; (group (driver (_x select 0))) setVariable [QGVAR(aracMedevacT), time]; (_x select 0) setVariable [QGVAR(aracMedevacT), time]; } forEach _manifest;

// kayit: [arac, surucu, grup, birimler, durum, t0, binen, gercekKoltuk, yolcuOyuncular]
private _kayit = _manifest apply {
    _x params ["_v", "_ul"];
    [_v, driver _v, group (driver _v), _ul, "GEL", time, [], -1, _ul select {isPlayer _x}]
};

private _yuru = {
    // v8.500g (RPT 0bef7b5e: iptal olan aracin askeri (Manevra1) serbest kaldi ama emirsiz bekledi): binemeyen / arac iptal asker RP'ye yuruyerek gider (oyuncu grubu haric: oyuncuyla kalir)
    params ["_yl"];
    private _pg = allPlayers apply {group _x};
    { if (alive _x && {isNull objectParent _x} && {!isPlayer _x} && {!((group _x) in _pg)}) then { _x doMove (_rp getPos [random 25, random 360]); }; } forEach _yl;
};
private _mAraclar = _kayit apply {_x select 0};
private _yukMax = 240 + ((selectMax (_mAraclar apply {_x distance2D _pickRef})) / 6);
private _serbest = {
    params ["_ul"];
    { if (alive _x) then { _x setVariable [QGVAR(tasimaBekle), nil]; _x enableAI "PATH"; }; } forEach _ul;
};
private _kira = {
    // v8.500 HAKEM: surucunun hizi + hareketi nakil sahipligindedir (oncelik 60; ezme 90 ustte, tank-aralik 40 / mekanize 20 altta)
    params ["_dk"];
    if (!isNull _dk) then { [_dk, "HAREKET", "nakil", 60, 8] call FUNC(uzuvKirala); [_dk, "HIZ", "nakil", 60, 8] call FUNC(uzuvKirala); };
};
private _bitirAraclar = {
    // arac bayraklarini birak
    { [_x select 1, "HAREKET", "nakil"] call FUNC(uzuvBirak); [_x select 1, "HIZ", "nakil"] call FUNC(uzuvBirak); } forEach _kayit;
    { private _v = _x select 0; _v setVariable [QGVAR(tasimaMesgul), false]; _v setVariable [QGVAR(yolcuBirak), nil]; (_x select 2) setVariable [QGVAR(tasimaSonT), time]; } forEach _kayit;
};

// ===================================================================== 3 YUKLEME
private _piyDist = {
    params ["_r"];
    private _p = [(_r select 3) select {alive _x && {isNull objectParent _x}}] call _merkez;
    if (_p isEqualTo []) then {0} else { round ((_r select 0) distance2D _p) }
};
// v8.500i: yukleme durum satiri (RPT 4f140aaf: 'askerler binmedi' gozlemi log ile dogrulanamadi): kac asker iceride, disarida kalanlar ve oyuncu mesafesi
private _durumSatir = {
    params ["_r"];
    private _vv = _r select 0;
    private _ul = _r select 3;
    private _ic = count (_ul select {alive _x && {(vehicle _x) isEqualTo _vv}});
    private _dis = (_ul select {alive _x && {isNull objectParent _x}}) apply { format ["%1 %2m", name _x, round (_x distance2D _vv)] };
    private _oy = (_r select 8) apply { format ["%1 %2m", name _x, round (_x distance2D _vv)] };
    format ["%1:%2 piyadeye %3 m hiz %4 motor %5 | iceride %6/%7 | disarida %8 | oyuncu %9", groupId (_r select 2), _r select 4, [_r] call _piyDist, round (speed _vv), isEngineOn _vv, _ic, count _ul, _dis, _oy]
};
private _tYuk = time;
private _logT = time + 20;
private _hazirSay = 0;
waitUntil {
    sleep 1;
    private _hepsiHazir = true;
    {
        _x params ["_v", "_d", "_vg", "_ul", "_durum", "_t0", "_binen", "_gk", "_oyuncular"];
        private _idx = _forEachIndex;
        if (_durum in ["GEL", "BIN"]) then { [_d] call _kira; };
        if (_durum in ["GEL", "BIN"]) then {
            if (!alive _v || {!alive _d} || {!canMove _v}) then {
                (_kayit select _idx) set [4, "IPTAL"];
                [_ul] call _serbest;
                [_ul] call _yuru;
                _ctl set [3, (_ctl select 3) + 1];
                [format ["%1 | yuklemede arac / surucu kayip -> iptal", groupId _vg]] call _log;
            } else {
                private _bekleyen = _ul select {alive _x && {!isPlayer _x} && {(vehicle _x) isNotEqualTo _v} && {isNull objectParent _x}};
                private _ic = _ul select {alive _x && {(vehicle _x) isEqualTo _v}};
                private _pk = [_ul select {alive _x && {isNull objectParent _x}}] call _merkez;
                if (_durum isEqualTo "GEL") then {
                    // v8.500b: piyade <= 250 m ise arac YERINDE kalir, piyade araca yurur (eski sistemdeki gibi; RPT b79add31: park halindeki 4 arac 5 dk piyadeye gidemedi, konvoy tek aracla kalkti); 20 sn sonra kalan oturtulur
                    if (_pk isEqualTo [] || {(_v distance2D _pk) < 400}) then {
                        (_kayit select _idx) set [4, "BIN"];
                        (_kayit select _idx) set [5, time];
                        { if ((waypointName _x) find "ELITE NAKIL" isEqualTo 0) then { deleteWaypoint _x; }; } forEach ((waypoints _vg) call { reverse _this; _this });
                        doStop _d;
                        [_ul] call _serbest;
                        { _x assignAsCargo _v; } forEach (_ul select {!isPlayer _x});
                        (_ul select {!isPlayer _x}) orderGetIn true;
                        { if (isPlayer _x) then { [format ["[ELITE] %1 seni bekliyor: araca bin (en fazla 90 sn)", getText (configOf _v >> "displayName")]] remoteExec ["systemChat", _x]; }; } forEach _oyuncular;
                        [format ["%1 | arac yuklemeye hazir (%2 asker bekliyor)", groupId _vg, count _bekleyen]] call _log;
                    } else {
                        // RPT 4e09cbf6: 1134 / 490 / 271 / 253 m uzaktaki araclar dakikalarca 'hiz 0' (tek doMove uzak hedefte basarisiz; v8.245 yol zinciri bilgisi) -> 700 m'den uzakta 300 m'lik ara nokta zinciri + takilma kurtarma (surus ile ayni basamaklar)
                        private _gz = _v getVariable [QGVAR(nk2Zincir), []];
                        if (_gz isEqualTo [] && {(_v distance2D _pk) > 700} && {!(_v getVariable [QGVAR(nk2ZincirDene), false])}) then {
                            _v setVariable [QGVAR(nk2ZincirDene), true];
                            _gz = [_v, _pk, 300] call FUNC(yolZinciri);
                            _v setVariable [QGVAR(nk2Zincir), _gz];
                            _v setVariable [QGVAR(nk2ZI), 0];
                        };
                        private _hedefG = _pk;
                        if (_gz isNotEqualTo []) then {
                            private _zi = (_v getVariable [QGVAR(nk2ZI), 0]) min ((count _gz) - 1);
                            if ((_v distance2D (_gz select _zi)) < 60 && {_zi < ((count _gz) - 1)}) then { _zi = _zi + 1; _v setVariable [QGVAR(nk2ZI), _zi]; _vg setVariable [QGVAR(nk2MoveT), -99]; };
                            _hedefG = _gz select _zi;
                        };
                        // takilma izleme (arac hedefe gitmesi gerekirken < 1 km/sa)
                        if ((speed _v) < 1) then {
                            if ((_v getVariable [QGVAR(nk2DurT), -1]) < 0) then { _v setVariable [QGVAR(nk2DurT), time]; _v setVariable [QGVAR(nk2Adim), 0]; };
                            private _dg = time - (_v getVariable [QGVAR(nk2DurT), time]);
                            private _ad = _v getVariable [QGVAR(nk2Adim), 0];
                            if (_dg > 10 && {_ad < 1}) then { _v setVariable [QGVAR(nk2Adim), 1]; _v engineOn true; _d enableAI "PATH"; _d enableAI "MOVE"; _d forceSpeed -1; doStop _d; _vg setVariable [QGVAR(nk2MoveT), -99]; [format ["%1 | YUKLEME TAKILMA 1: 10 sn hareket yok -> emir yenilendi (piyadeye %2 m)", groupId _vg, round (_v distance2D _pk)]] call _log; };
                            if (_dg > 20 && {_ad < 2}) then { _v setVariable [QGVAR(nk2Adim), 2]; _v setVelocityModelSpace [0, 4, 0]; _vg setVariable [QGVAR(nk2MoveT), -99]; [format ["%1 | YUKLEME TAKILMA 2: itme", groupId _vg]] call _log; };
                            if (_dg > 40 && {_ad < 3}) then {
                                _v setVariable [QGVAR(nk2Adim), 3];
                                private _ip = (getPosATL _v) getPos [25, _v getDir _hedefG];
                                private _yr = _ip nearRoads 30;
                                if (_yr isNotEqualTo []) then { _ip = getPosATL (_yr select 0); };
                                if !(surfaceIsWater _ip) then { _v setVehiclePosition [_ip, [], 0, "NONE"]; _v setDir (_v getDir _hedefG); _v engineOn true; };
                                _vg setVariable [QGVAR(nk2MoveT), -99];
                                [format ["%1 | YUKLEME TAKILMA 3: 25 m ileri tasindi (piyadeye %2 m)", groupId _vg, round (_v distance2D _pk)]] call _log;
                            };
                        } else { _v setVariable [QGVAR(nk2DurT), -1]; };
                        // v8.500k ILERLEME BEKCISI (RPT 7aee03f9: Alpha 3-2 15 dk boyunca palmiyeler arasinda 0.1-0.3 m/sn sürünerek piyadeye 537 -> 477 m geldi; hiz hic 'sifir' olmadigi icin kademe sayaci surekli sifirlaniyor, kurtarma 1 kez calisip bitti):
        //   her 20 sn'de hedefe yaklasma < 8 m ise 'ilerleme yok' say; 1: emir yenile, 2: itme, >= 3: hedefe dogru ileri tasima (25 m + 15 m x tekrar, en fazla 80 m); ilerleme (>= 15 m) olursa sayac sifirlanir.
                        private _pw = _v getVariable [QGVAR(nk2PrgD), []];
                        if (_pw isEqualTo []) then { _v setVariable [QGVAR(nk2PrgD), [time, _v distance2D _hedefG, 0]]; } else {
                            if ((time - (_pw select 0)) >= 20) then {
                                private _dNow = _v distance2D _hedefG;
                                private _prg = (_pw select 1) - _dNow;
                                private _sN = _pw select 2;
                                if (_prg < 8 && {_dNow > 60}) then {
                                    _sN = _sN + 1;
                                    switch (true) do {
                                        case (_sN isEqualTo 1): { _v engineOn true; _d enableAI "PATH"; _d enableAI "MOVE"; _d forceSpeed -1; doStop _d; _vg setVariable [QGVAR(nk2MoveT), -99]; };
                                        case (_sN isEqualTo 2): { _v setVelocityModelSpace [0, 4, 0.2]; _vg setVariable [QGVAR(nk2MoveT), -99]; };
                                        default {
                                            private _adimM = (25 + 15 * (_sN - 3)) min 80;
                                            private _ip2 = (getPosATL _v) getPos [_adimM, _v getDir _hedefG];
                                            private _yr2 = _ip2 nearRoads 30;
                                            if (_yr2 isNotEqualTo []) then { _ip2 = getPosATL (_yr2 select 0); };
                                            if !(surfaceIsWater _ip2) then { _v setVehiclePosition [_ip2, [], 0, "NONE"]; _v setDir (_v getDir _hedefG); _v engineOn true; };
                                            _vg setVariable [QGVAR(nk2MoveT), -99];
                                        };
                                    };
                                    [format ["%1 | YUKLEME ILERLEME YOK: 20 sn'de %2 m yaklasti (kademe %3, piyadeye %4 m)", groupId _vg, round _prg, _sN, round (_v distance2D _pk)]] call _log;
                                } else { if (_prg >= 15) then { _sN = 0; }; };
                                _v setVariable [QGVAR(nk2PrgD), [time, _dNow, _sN]];
                            };
                        };
                        if ((time - (_vg getVariable [QGVAR(nk2MoveT), -99])) > 4) then {
                            _vg setVariable [QGVAR(nk2MoveT), time];
                            _d enableAI "PATH"; _d enableAI "MOVE"; _d forceSpeed -1; _vg setBehaviour "SAFE"; _vg setSpeedMode "FULL";
                            if !(isEngineOn _v) then { _d action ["EngineOn", _v]; _v engineOn true; };   // RPT dd9a9b85: motor kapaliyken arac MOVE emriyle de kipirdamadi
                            _d doMove _hedefG;
                            // RPT 2521b53c: eski kodda 'doMove'a EK olarak grup WAYPOINT'i tek calisan yol' (v8.181): ayni waypoint tek kez kurulur, sonra konumu guncellenir
                            private _nw = (waypoints _vg) select {(waypointName _x) find "ELITE NAKIL" isEqualTo 0};
                            if (_nw isEqualTo []) then {
                                private _w = _vg addWaypoint [_hedefG, 0];
                                _w setWaypointType "MOVE"; _w setWaypointName "ELITE NAKIL"; _w setWaypointSpeed "FULL"; _w setWaypointBehaviour "SAFE";
                                _vg setCurrentWaypoint _w;
                            } else { (_nw select 0) setWPPos _hedefG; };
                        };
                    };
                } else {
                    private _gecen = time - _t0;
                    // 20 sn sonra (ve her 3 sn'de bir) kalan askeri duz koltuga otur (<= 300 m)
                    if (_gecen > 20 && {(round _gecen) mod 3 isEqualTo 0}) then {
                        {
                            if ((_x distance2D _v) < 450 && {([_v] call FUNC(aracDuzBos)) > 0}) then { [_x, _v] call FUNC(aracYolcuKoy); };
                        } forEach _bekleyen;
                    };
                    // yakindaki asker binmeye devam: her 5 sn orderGetIn tekrar
                    if ((round _gecen) mod 5 isEqualTo 0) then { { if ((_x distance2D _v) < 80) then { _x assignAsCargo _v; }; } forEach _bekleyen; _bekleyen orderGetIn true; };
                    private _oyBekle = _oyuncular select {alive _x && {!((vehicle _x) in _mAraclar)}};
                    // v8.500k BINIS SURESI MESAFEYE GORE (RPT 7aee03f9: Alpha 2-6 14 askerden 4'u 120 sn'de binebildi, 10 asker yuruyerek kaldi): en uzak bekleyen asker ~1.3 m/sn yurur -> sinir 120 sn ile (60 + mesafe / 1.3) arasi buyuk olan, en fazla 300 sn
                    private _uzakM = 0;
                    { _uzakM = _uzakM max (_x distance2D _v); } forEach _bekleyen;
                    private _binLimit = (120 max (60 + (_uzakM / 1.3))) min 300;
                    private _bitti = (_bekleyen isEqualTo [] && {_oyBekle isEqualTo [] || {_gecen > 90}})
                        || {_gecen > _binLimit}
                        || {_ic isNotEqualTo [] && {([_v] call FUNC(aracDuzBos)) <= 0} && {_oyBekle isEqualTo [] || {_gecen > 90}}};
                    // arac gercekten doldu ama disarida kalan var -> kapasite ogren (emptyPositions / cargo sayisi yalan soyledi)
                    private _doluKoltuk = count (fullCrew [_v, "cargo", false]);   // gercekten oturan sayisi (taze)
                    if (_bitti && {_bekleyen isNotEqualTo []} && {([_v] call FUNC(aracDuzBos)) <= 0} && {_doluKoltuk >= 3}) then {
                        missionNamespace setVariable [format ["lambs_danger_tasimaKap_%1", typeOf _v], _doluKoltuk];
                        [format ["%1 | KAPASITE OGRENILDI: %2 gercek %3 koltuk", groupId _vg, typeOf _v, _doluKoltuk]] call _log;
                    };
                    if (_bitti) then {
                        private _bn = _ul select {alive _x && {(vehicle _x) isEqualTo _v}};
                        // oyuncu binmediyse ekibi de oyuncuyla kalsin
                        private _oyYok = _oyuncular select {alive _x && {!((vehicle _x) in _mAraclar)}};
                        if (_oyYok isNotEqualTo []) then {
                            private _pg = _oyYok apply {group _x};
                            { if (alive _x && {(group _x) in _pg}) then { unassignVehicle _x; moveOut _x; _x enableAI "PATH"; }; } forEach _bn;
                            _bn = _bn select {!((group _x) in _pg)};
                            [format ["%1 | OYUNCU BINMEDI: %2 -> ekibi araca alinmadi", groupId _vg, _oyYok apply {name _x}]] call _log;
                        };
                        // binemeyenler serbest (yuruyerek gider)
                        [_ul select {!(_x in _bn)}] call _serbest;
                        [_ul select {!(_x in _bn)}] call _yuru;
                        { if (alive _x && {(vehicle _x) isNotEqualTo _v}) then { unassignVehicle _x; }; } forEach (_ul select {!(_x in _bn)});
                        (_kayit select _idx) set [6, _bn];
                        (_kayit select _idx) set [4, ["HAZIR", "IPTAL"] select (_bn isEqualTo [])];
                        _ctl set [3, (_ctl select 3) + 1];
                        [format ["%1 | YUKLENDI %2 / %3 asker (%4) | disarida kalan %5 | koltuk: kargo toplam %6, bos %7 (emptyPositions %8), sure %9 sn", groupId _vg, count _bn, count _ul, getText (configOf _v >> "displayName"), count (_ul select {!(_x in _bn)}), count (fullCrew [_v, "cargo", true]), count ((fullCrew [_v, "cargo", true]) select {isNull (_x select 0)}), _v emptyPositions "cargo", round (time - _t0)]] call _log;
                    };
                };
            };
        };
        if ((_kayit select _idx) select 4 in ["GEL", "BIN"]) then { _hepsiHazir = false; };
    } forEach _kayit;
    if (time > _logT) then {
        _logT = time + 20;
        [format ["YUKLEME surerken: hazir %1 / %2 arac | durum: %3", _ctl select 3, count _kayit, _kayit apply { [_x] call _durumSatir }]] call _log;
    };
    (_ctl select 0) || {_hepsiHazir} || {(time - _tYuk) > _yukMax}
};

// zaman asiminda hala GEL / BIN durumunda kalan araclar iptal: askerleri serbest
{
    if ((_x select 4) in ["GEL", "BIN"]) then {
        private _v = _x select 0;
        { if (alive _x && {(vehicle _x) isNotEqualTo _v}) then { unassignVehicle _x; }; } forEach (_x select 3);
        [_x select 3] call _serbest;
        [_x select 3] call _yuru;
        _x set [4, "IPTAL"];
        _ctl set [3, (_ctl select 3) + 1];
        [format ["%1 | yukleme zaman asimi -> arac iptal", groupId (_x select 2)]] call _log;
    };
} forEach _kayit;

// iptal (plan) ya da hic yuklenemedi
private _yukluKayit = _kayit select {(_x select 4) isEqualTo "HAZIR"};
if ((_ctl select 0) || {_yukluKayit isEqualTo []}) exitWith {
    { [_x select 3] call _serbest; } forEach _kayit;
    { private _k = _x; { if (alive _x && {(vehicle _x) isEqualTo (_k select 0)}) then { unassignVehicle _x; moveOut _x; }; } forEach (_k select 3); } forEach _kayit;
    call _bitirAraclar;
    _ctl set [2, 0];
    [["plan iptal", "hic arac yuklenemedi"] select (!(_ctl select 0))] call _log;
    0
};
private _tasinan = 0;
{ _tasinan = _tasinan + count (_x select 6); } forEach _yukluKayit;
_ctl set [2, _tasinan];

// ===================================================================== 4 KAPI (hepsi hazir + plan kapisi)
private _tKapi = time;
private _tutS = missionNamespace getVariable ["lambs_danger_nakilTutmaS", 240];
private _logK = time + 20;
if !(_ctl select 1) then {
    [format ["KONVOY YUKLU: %1 arac / %2 asker - plan kapisi bekleniyor (en fazla %3 sn)", count _yukluKayit, _tasinan, _tutS]] call _log;
    [format ["NAKIL-YUKLENDI %1", count _yukluKayit], format ["%1 asker | kapi bekliyor (en fazla %2 sn)", _tasinan, _tutS]] call FUNC(planZaman);
    waitUntil {
        sleep 1;
        { [_x select 1] call _kira; } forEach _yukluKayit;
        if (time > _logK) then { _logK = time + 20; [format ["kapi hala kapali: %1 sn", round (time - _tKapi)]] call _log; };
        (_ctl select 1) || {_ctl select 0} || {(time - _tKapi) > _tutS} || {(_yukluKayit findIf {alive (_x select 0)}) < 0}
    };
};
if (_ctl select 0) exitWith {
    { private _k = _x; { if (alive _x && {(vehicle _x) isEqualTo (_k select 0)}) then { unassignVehicle _x; moveOut _x; _x enableAI "PATH"; }; } forEach (_k select 6); } forEach _yukluKayit;
    call _bitirAraclar;
    _ctl set [2, 0];
    ["plan iptal (kapi beklerken)"] call _log;
    0
};
[format ["NAKIL-KALKTI %1", count _yukluKayit], format ["%1 sn bekledi", round (time - _tKapi)]] call FUNC(planZaman);

// ===================================================================== 5 SURUS (konvoy birlikte)
// yol zinciri (uzak hedefte ~300 m ara noktalar)
// v8.500g KADEMELI VARIS NOKTALARI (kullanici: 'hepsi milimetrik ayni yere gitmeye calisiyor, ORP'ye yakinsa oldugu yerde dursun'; RPT 0bef7b5e: ayni noktaya varan araclar carpisti): konvoy sirasina gore (inise en yakin once) her arac inis noktasindan 26 m x sira GERIDE (objektiften uzaga), yola oturtulmus ayri nokta alir
private _idxV = []; for "_iv" from 0 to ((count _kayit) - 1) do { _idxV pushBack _iv; };
private _siraV = [_idxV, [], {((_kayit select _x) select 0) distance2D _drop}, "ASCEND"] call BIS_fnc_sortBy;
private _dropVs = _kayit apply { _drop };
{
    private _pt = _drop getPos [26 * _forEachIndex, _B];
    private _rd = _pt nearRoads 40;
    if (_rd isNotEqualTo []) then { _pt = getPosATL (([_rd, [], {_x distance2D _pt}, "ASCEND"] call BIS_fnc_sortBy) select 0); };
    if (surfaceIsWater _pt) then { _pt = _drop; };
    _dropVs set [_x, _pt];
} forEach _siraV;
private _yol = [];   // _kayit sirasiyla ara nokta listeleri
{
    private _v = _x select 0;
    private _dv = _dropVs select _forEachIndex;
    private _zn = [_dv];
    if (alive _v && {!(missionNamespace getVariable ["lambs_danger_nakilZincirOff", false])} && {(_v distance2D _dv) > 1200}) then { _zn = [_v, _dv, 300] call FUNC(yolZinciri); };
    _yol pushBack _zn;
} forEach _kayit;

// calisma durumu: [yolIdx, sonMoveT, durgunT, durgunBas, bitis]
private _cal = _kayit apply { [0, -99, -1, 0, ""] };
{
    _x params ["_v", "_d", "_vg"];
    if ((_x select 4) isEqualTo "HAZIR" && {alive _v} && {alive _d}) then {
        _d enableAI "PATH"; _d enableAI "MOVE"; _d forceSpeed -1;
        _vg setBehaviour "SAFE"; _vg setSpeedMode "FULL";
        if !(isEngineOn _v) then { _d action ["EngineOn", _v]; _v engineOn true; };
        { if (alive _x) then { _x disableAI "PATH"; }; } forEach (_x select 6);
        { if ((waypointName _x) find "ELITE NAKIL" isEqualTo 0) then { deleteWaypoint _x; }; } forEach ((waypoints _vg) call { reverse _this; _this });
        _v setVariable [QGVAR(yolcuBirak), false];
        _d doMove ((_yol select _forEachIndex) select 0);
        private _wp = _vg addWaypoint [((_yol select _forEachIndex) select 0), 0];
        _wp setWaypointType "MOVE"; _wp setWaypointName "ELITE NAKIL"; _wp setWaypointSpeed "FULL"; _wp setWaypointBehaviour "SAFE";
    };
} forEach _kayit;

private _tSur = time;
private _sureMax = 240 + ((_drop distance2D _pickRef) / 3.5);   // yaklasik 12 km/sa taban
private _logS = time + 20;
waitUntil {
    sleep 1;
    private _surende = 0;
    // inise yakinliga gore dinamik sira
    private _sira = [];
    { if ((_x select 4) isEqualTo "HAZIR" && {(_cal select _forEachIndex) select 4 isEqualTo ""}) then { _sira pushBack _forEachIndex; }; } forEach _kayit;
    _sira = [_sira, [], {(((_kayit select _x) select 0) distance2D _drop)}, "ASCEND"] call BIS_fnc_sortBy;
    {
        private _idx = _x;
        private _r = _kayit select _idx;
        private _c = _cal select _idx;
        _r params ["_v", "_d", "_vg", "_ul", "_durum", "_t0", "_binen"];
        _c params ["_yi", "_sonMoveT", "_durgunT", "_durgunBas", "_bitis"];
        private _zn = _yol select _idx;
        private _dm = _v distance2D (_dropVs select _idx);
        private _hz = (speed _v) / 3.6;
        if (!alive _v || {!alive _d}) then { _c set [4, "OLDU"]; }
        else {
            [_d] call _kira;
            // ara nokta ilerlet
            private _nokta = _zn select (_yi min ((count _zn) - 1));
            if ((_v distance2D _nokta) < ([60, 40] select (_yi >= ((count _zn) - 1))) && {_yi < ((count _zn) - 1)}) then { _yi = _yi + 1; _c set [0, _yi]; _nokta = _zn select _yi; _sonMoveT = -99; };
            if ((time - _sonMoveT) > 6) then { _c set [1, time]; _d doMove _nokta; };
            // hiz yonetimi: arkadaki, onundekinin hizini asmaz
            private _pi = _sira find _idx;
            private _fren = false;
            if (_pi > 0) then {
                private _p = (_kayit select (_sira select (_pi - 1))) select 0;
                private _gap = _v distance2D _p;
                private _ph = (speed _p) / 3.6;
                private _pDur = ((_p getVariable [QGVAR(durgunSn), 0]) >= 4);
                if (!_pDur) then {
                    if (_gap < 12) then { _d forceSpeed 0; _fren = true; }
                    else { if (_gap < 40) then { _d forceSpeed ((_ph * 0.9) max 2); _fren = true; }
                    else { if (_gap < 100 && {_hz > (_ph + 3)}) then { _d forceSpeed (_ph + 3); } else { _d forceSpeed -1; }; }; };
                } else { _d forceSpeed -1; };
            } else {
                // lider: en geride kalan 350 m'den uzaktaysa yavasla
                private _son = _sira select ((count _sira) - 1);
                if (_son isNotEqualTo _idx) then {
                    private _sv = (_kayit select _son) select 0;
                    if (((_sv distance2D _drop) - _dm) > 350 && {((_sv getVariable [QGVAR(durgunSn), 0]) < 4)}) then { _d forceSpeed (((speed _sv) / 3.6 * 1.15) max 9); } else { _d forceSpeed -1; };
                } else { _d forceSpeed -1; };
            };
            // RECON ONDE KALSIN: yolda hareket eden recon araci 500 m icindeyse ve ben objektife ondan yakinsam hizim recon'a sinirlanir, 40 m'den yaklasmam (kesif ana kolun onunde gider, gecilmez)
            private _rvl = vehicles select {alive _x && {_x getVariable [QGVAR(reconArac), false]} && {_x getVariable [QGVAR(tasimaMesgul), false]} && {(_x getVariable [QGVAR(durgunSn), 0]) < 4} && {(_x distance2D _v) < 500}};
            if (_rvl isNotEqualTo [] && {((_v distance2D _obj) < (((_rvl select 0) distance2D _obj) + 30))}) then {
                private _rvv = _rvl select 0;
                _fren = true;
                _d forceSpeed (if ((_v distance2D _rvv) < 40) then {0} else {(((speed _rvv) max 0) / 3.6) max 3});
            };
            // YAKLASMA HIZI (RPT 0bef7b5e: arac inise 92 km/sa ile girdi, inen askeri ezdi / carpisti): kendi varis noktasina 250 m'de <= 9 m/sn, 100 m'de <= 5 m/sn
            if (_dm < 250 && {!_fren}) then { _d forceSpeed (if (_dm < 100) then {5} else {9}); };
            // takilma izleme (kasitli fren degilse)
            if (_hz < 1 && {!_fren} && {_dm > 20}) then {
                if (_durgunT < 0) then { _c set [2, time]; _durgunT = time; _c set [3, 0]; };
                private _dg = time - _durgunT;
                _v setVariable [QGVAR(durgunSn), _dg];
                private _adim = _c select 3;
                if (_dg > 8 && {_adim < 1}) then { _c set [3, 1]; _v engineOn true; _d enableAI "PATH"; _d enableAI "MOVE"; _d forceSpeed -1; doStop _d; _d doMove _nokta; [format ["%1 | TAKILMA 1: 8 sn hareket yok -> emir yenilendi (inise %2 m)", groupId _vg, round _dm]] call _log; };
                if (_dg > 16 && {_adim < 2}) then { _c set [3, 2]; _v setVelocityModelSpace [0, 4, 0]; _d doMove _nokta; [format ["%1 | TAKILMA 2: itme", groupId _vg]] call _log; };
                if (_dg > 30 && {_adim < 3}) then {
                    _c set [3, 3];
                    private _ip = (getPosATL _v) getPos [25, _v getDir _nokta];
                    private _yr = (_ip nearRoads 30);
                    if (_yr isNotEqualTo []) then { _ip = getPosATL (_yr select 0); };
                    if !(surfaceIsWater _ip) then { _v setVehiclePosition [_ip, [], 0, "NONE"]; _v setDir (_v getDir _nokta); _v engineOn true; _d doMove _nokta; };
                    [format ["%1 | TAKILMA 3: 25 m ileri tasindi (inise %2 m)", groupId _vg, round _dm]] call _log;
                };
                if (_dg > 120) then { _c set [4, "TAKILDI"]; };
            } else { if (_hz >= 2 || {_fren}) then { _c set [2, -1]; _c set [3, 0]; _v setVariable [QGVAR(durgunSn), 0]; }; };
            // bitis kosullari
            if ((_c select 4) isEqualTo "") then {
                // v8.500e VARIS TOLERANSI (kullanici: 'nokta atisi durmasina gerek yok, birkac metre daha ilerleyeceklerdi'; RPT fd85e28a: recon araci inis yolunda park edince konvoy tikandi): 60 m'de ya da 150 m icinde 5 sn'den uzun durdurulduysa (onde park eden arac / yol tikali) bu arac oldugu yerde iner
                if (_dm < 60) then { _c set [4, "VARDI"]; };
                if (_dm < 150 && {_hz < 1.5} && {(_c select 2) > 0} && {(time - (_c select 2)) >= 5}) then { _c set [4, "VARDI"]; [format ["%1 | VARIS (TIKALI): inise %2 m kala 5 sn durdu -> burada iner", groupId _vg, round _dm]] call _log; };
                if (_dm < 220 && {(behaviour _d) isEqualTo "SAFE"}) then { _vg setBehaviour "AWARE"; _vg setSpeedMode "NORMAL"; };
                if (((_binen findIf {alive _x && {(time - ((group _x) getVariable [QGVAR(contact), -999])) < 5}}) >= 0) && {_dm > 120}) then { _c set [4, "TEMAS"]; };
                if ((time - _tSur) > _sureMax) then { _c set [4, "SURE"]; };
                if ((damage _v) > 0.8 || {!canMove _v}) then { _c set [4, "HASAR"]; };
            };
        };
        if ((_c select 4) isEqualTo "") then { _surende = _surende + 1; };
    } forEach _sira;
    if (time > _logS) then { _logS = time + 20; [format ["SURUS: %1 arac yolda | en yakin inise %2 m", _surende, round (selectMin ((_sira apply {(((_kayit select _x) select 0) distance2D _drop)}) + [99999]))]] call _log; };
    // temas ya da bir arac inmek zorunda ise tum konvoy iner (birlikte)
    private _bas = (_cal select {(_x select 4) in ["TEMAS", "HASAR"]}) isNotEqualTo [];
    (_ctl select 0) || {_surende isEqualTo 0} || {_bas}
};

// ===================================================================== 6 INIS (birlikte)
{ private _r = _x; if ((_r select 4) isEqualTo "HAZIR") then { (_r select 0) setVariable [QGVAR(yolcuBirak), true]; }; } forEach _kayit;
// v8.500g FREN: inmeden once tum araclar durur (RPT 0bef7b5e: 92 km/sa'te inen asker ezildi); en cok 12 sn
{ if ((_x select 4) isEqualTo "HAZIR" && {alive (_x select 0)} && {alive (_x select 1)}) then { (_x select 1) forceSpeed 0; doStop (_x select 1); }; } forEach _kayit;
private _tFr = time + 12;
waitUntil { sleep 0.5; time > _tFr || {(_kayit findIf {(_x select 4) isEqualTo "HAZIR" && {alive (_x select 0)} && {(speed (_x select 0)) > 4}}) < 0} };
{
    _x params ["_v", "_d", "_vg", "_ul", "_durum", "_t0", "_binen"];
    if (_durum isEqualTo "HAZIR" && {alive _v}) then {
        { if ((waypointName _x) find "ELITE NAKIL" isEqualTo 0) then { deleteWaypoint _x; }; } forEach ((waypoints _vg) call { reverse _this; _this });
        doStop _d;
        { if (alive _x) then { _x enableAI "PATH"; if ((vehicle _x) isEqualTo _v && {_x isNotEqualTo _d}) then { unassignVehicle _x; doGetOut _x; }; }; } forEach _binen;
    };
} forEach _kayit;
sleep 6;
{
    _x params ["_v", "_d", "_vg", "_ul", "_durum", "_t0", "_binen"];
    { if (alive _x && {(vehicle _x) isEqualTo _v} && {_x isNotEqualTo _d}) then { unassignVehicle _x; moveOut _x; }; } forEach _binen;
} forEach _kayit;
sleep 2;
private _inen = 0;
{
    _x params ["_v", "_d", "_vg", "_ul", "_durum", "_t0", "_binen"];
    { if (alive _x) then { _x setVariable [QGVAR(tasimaBekle), nil]; _x enableAI "PATH"; _x doFollow (leader (group _x)); if ((vehicle _x) isEqualTo _x) then { _inen = _inen + 1; }; }; } forEach _binen;
    if (alive _v && {_durum isEqualTo "HAZIR"}) then {
        // IFV: indirdikten sonra ates destegi (planZirh; piyadenin 40 m'den fazla onune gecmez) - gerisi "savas taksisi": GERIDE REZERV
        if (alive _d) then { _d forceSpeed -1; };
        private _ifvMi = (([_v] call FUNC(aracSinif)) select 0) isEqualTo "IFV" && {count _ctl > 5};
        if (_ifvMi) then {
            private _ifvL = _ctl select 5;
            if (_ifvL isEqualType []) then { _ifvL pushBackUnique _vg; };
        } else {
            // v8.500f (kullanici: 'askerler geride iniyor, savunmasiz araclar one geciyor'): eskiden _rp'ye (objektife 500 m = inis noktasinin ONU) donuyordu; artik inis noktasindan 700 m GERIDE (objektiften uzaga) rezerv noktasina, aracin kendi yan kaymasiyla
            private _gYon = _obj getDir _drop;
            private _geri = _obj getPos [((_obj distance2D _drop) + 700), _gYon];
            private _gYol = (_geri nearRoads 250) select {!surfaceIsWater (getPosATL _x) && {((getPosATL _x) distance2D _obj) >= ((_obj distance2D _drop) + 450)}};
            if (_gYol isNotEqualTo []) then { _geri = getPosATL (([_gYol, [], {_x distance2D _geri}, "ASCEND"] call BIS_fnc_sortBy) select 0); } else { if (surfaceIsWater _geri) then { _geri = _drop getPos [300, _gYon]; }; };
            _geri = _geri getPos [40 * _forEachIndex, _gYon + 90];
            if (surfaceIsWater _geri) then { _geri = _drop getPos [300, _gYon]; };
            _v setVariable [QGVAR(rezervNokta), _geri];
            [format ["%1 | inis sonrasi GERIDE rezerv: objektiften %2 m (inis noktasi %3 m)", groupId _vg, round (_geri distance2D _obj), round (_drop distance2D _obj)]] call _log;
            if (alive _d) then { _d enableAI "PATH"; _d forceSpeed -1; _vg setBehaviour "AWARE"; _vg setSpeedMode "NORMAL"; _d doMove _geri; };
        };
    };
} forEach _kayit;
call _bitirAraclar;
[format ["INIS TAMAM: %1 / %2 asker indi | kayit: %3", _inen, _tasinan, _cal apply {_x select 4}]] call _log;
_inen
