#include "script_component.hpp"
/*
 * Author: Cinar (ELITE fork)
 * SIPERE ZORLA (v8.510; kullanici: 'botlar ates etmekten cover alamiyor, catisma bitince kazanan taraf yeni cover aliyor; FSM cover istediginde onu sipere forceleyecek bir sistem, raycast destegiyle').
 * Neden: AI hedefi gorup ates ederken doMove / moveTo emrini ertelenir (ates 'dur' gibi davranir): fnc_doCover (LAMBS FSM 'cover') yalniz moveTo + yuruyus animasyonu veriyordu, asker catisma bitene kadar yerinde
 * ates edip siperi sonra aliyordu. Bu fonksiyon kisa (1.2 - 3.5 sn, RISK CARPANI ile) bir SIPERE ATILIS uygular:
 *   1) RAYCAST DOGRULAMA: (a) siper noktasi dusman gozunden GIZLI olmali (FIRE LOD hatti ya da arazi keser; durus yuksekligi 1.5 / 1.0 / 0.4), (b) askerden siper noktasina 0.6 m yukseklikte hat (GEOM) engelsiz
 *      (duvar / cit icinden gecilmez), (c) siper dusmana ilk konumdan >= 4 m daha yaklasmamali.
 *   2) ATILIS: hedef secimi (AUTOTARGET + TARGET) kapatilir (asker nisan alip durmaz); v8.512: zor durumda / oranla KOSARKEN BASTIRMA ATESI (hedef secimi acik, atis hatti acik sartiyla), forceSpeed -1, FULL hiz, ayakta (UP), doMove; varinca ya da 3.5 sn sonra HER DURUMDA geri acilir,
 *      varista durus (MIDDLE / DOWN) + dusmana bakis; ates serbest.
 *   RISK (v8.511): tehdit (bilinen dusman sayisi + agir silah / arac) x baski x mesafe -> 0-1; esik altinda (tek hafif dusman, yakin mesafe) atilis yok; sure 1.2 + 2.3 x risk. Mesafe 8 m 0, 25 m 0.6, 50 m+ 1.
 *   3) KORUMA: dusman <= 8 m (yakin dovus: fnc_yakinAtes ates etsin), asker forceMove / teslim / baygin, LAMBS gorevi / kal-bekle waypoint (fnc_senaryoKapi 'sabit'), 5 sn tekrar siniri.
 * Cagiranlar: fnc_doCover (FSM cover istegi; main), fnc_acikSiper (acikta kalan). Kapatma: lambs_danger_siperZorla = false.  Log: [SIPER-ZORLA] (ilk 40).
 *
 * Arguments:
 * 0: Asker <OBJECT>
 * 1: Siper noktasi (AGL) <ARRAY>
 * 2: Dusman <OBJECT> (opsiyonel; yoksa en yakin bilinen)
 * 3: Varis durusu "UP" / "MIDDLE" / "DOWN" <STRING> (opsiyonel, varsayilan MIDDLE)
 * 4: Risk esigini atla <BOOL> (v8.522; sarjor degistirme siperi icin true)
 *
 * Return Value: Atilis baslatildi mi <BOOL>
 * Public: No
*/

params [["_u", objNull, [objNull]], ["_pos", [], [[]]], ["_e", objNull, [objNull]], ["_ds", "MIDDLE", [""]], ["_riskAtla", false, [false]]];
if (!(missionNamespace getVariable ["lambs_danger_siperZorla", true])) exitWith {false};
if (isNull _u || {!alive _u} || {_pos isEqualTo []} || {!local _u} || {isPlayer _u} || {!isNull objectParent _u}) exitWith {false};
if ((lifeState _u) in ["INCAPACITATED", "UNCONSCIOUS"] || {captive _u} || {_u getVariable [QGVAR(teslim), false]} || {_u getVariable [QGVAR(forceMove), false]}) exitWith {false};
if (time < (_u getVariable [QGVAR(zorlaT), 0])) exitWith {false};
if ((_u getVariable [QGVAR(zorlaBitis), 0]) > time) exitWith {false};   // atilis suruyor
if ([group _u, "siperZorla", true] call FUNC(senaryoKapi)) exitWith {false};
if (isNull _e || {!alive _e}) then { _e = _u findNearestEnemy _u; };
if (isNull _e || {!alive _e}) exitWith {false};

private _uPos = getPosATL _u;
private _mes = _uPos distance2D _pos;
if (_mes < 1.2 || {_mes > (20 / (((missionNamespace getVariable ["lambs_danger_siperUzaklik", 2]) max 1) min 4))}) exitWith {false};   // v8.513: 20 m / siperUzaklik (2) = 10 m
private _ed = _u distance2D _e;
if (_ed <= 8) exitWith {false};   // yakin dovus: kacma, ates et (fnc_yakinAtes)
if ((_pos distance2D _e) < (_ed - 4)) exitWith {false};   // dusmana 4 m'den fazla yaklastirmaz
if ((_pos distance2D _e) > (_ed + ([3, 10] select ((getSuppression _u) >= 0.5)))) exitWith {false};   // v8.521: geri siniri (git-gel): siper en fazla 3 m (ciddi baskida 10 m) daha uzak

// v8.511 RISK CARPANI (kullanici: 'risk carpani ekle, yakin mesafede bu sure kissin, tehdite gore; karsida 1 kisi varsa gerek yok'):
//   tehdit = bilinen (nearTargets 200 m) dusman sayisi + agir silah (arac x2, roketatar / MG x1.5) ; baz: 1 kisi 0 / 2 kisi 0.4 / 3 kisi 0.6 / 4+ 0.8; + baski x 0.4 (asker) ; x mesafe carpani
//   (8 m 0, 25 m 0.6, 50 m+ 1.0). risk < esik (CBA lambs_danger_zorlaRisk, 0.25) ise atilis YOK (dovus et); atilis suresi = 1.2 + 2.3 x risk (1.2 - 3.5 sn).
//   Tek dusman: yalniz ates ustunlugu kuruyorsa (asker baskisi >= 0.3 ya da grup >= 0.4) ya da dusman zirhli / agir silahliysa.
private _sideU = side group _u;
private _rolFn = missionNamespace getVariable ["lambs_danger_fnc_getUnitRole", {"RIFLE"}];
private _tehdit = 0;
private _agir = false;
{
    private _o = _x select 4;
    if (!isNull _o && {alive _o} && {((_x select 2) isNotEqualTo civilian)} && {(_sideU getFriend (_x select 2)) < 0.6}) then {
        if (_o isKindOf "CAManBase") then {
            private _r = [_o] call _rolFn;
            if (_r in ["MG", "AT", "MARKSMAN"] || {(secondaryWeapon _o) isNotEqualTo ""}) then { _tehdit = _tehdit + 1.5; _agir = true; } else { _tehdit = _tehdit + 1; };
        } else {
            if (!(_o isKindOf "StaticWeapon") || {true}) then { _tehdit = _tehdit + 2; _agir = true; };
        };
    };
} forEach (_u nearTargets 200);
private _bask = getSuppression _u;
// ATES USTUNLUGU: dusman bizi (asker ya da grubundan biri) bastiriyorsa = ates ustunlugu kuruyor (asker >= 0.3 / grup >= 0.4)
private _grupBask = selectMax ((units group _u) apply {if (alive _x) then {getSuppression _x} else {0}});
private _atesUst = (_bask >= 0.3) || {_grupBask >= 0.4};
private _baz = [0, 0.4, 0.6, 0.8] select ((round _tehdit) max 0 min 3);
if (_tehdit < 1.5 && {!_agir}) then { _baz = [0, 0.4] select _atesUst; };   // tek (hafif) dusman: ates ustunlugu kurmuyorsa risk yok; kuruyorsa 2 kisi gibi
private _mesF = ((((_ed - 8) / 42) max 0) min 1) * 0.4 + 0.6 * ((((_ed - 8) / 17) max 0) min 1);
_mesF = (_mesF min 1);
private _risk = (((_baz + (_bask * 0.4)) min 1) * _mesF) min 1;
if (_tehdit < 1.5 && {!_agir} && {!_atesUst}) then { _risk = 0; };   // 1 kisi ve ates ustunlugu kurmuyor (bastirmiyor): savas, kacma
if (!_riskAtla && {_risk < (missionNamespace getVariable ["lambs_danger_zorlaRisk", 0.25])}) exitWith {false};   // v8.522: _riskAtla (sarjor degistirme siperi): acikta reload tehlikeli, risk esigi aranmaz
private _sure = (1.2 + (2.3 * _risk)) max ([0, 1.8] select _riskAtla);

// RAYCAST (a): siper dusman gozunden gizli mi
private _eASL = eyePos _e;
private _pASL = AGLToASL [_pos select 0, _pos select 1, 0];
private _gizli = ([1.5, 1.0, 0.4] findIf {
    (lineIntersectsSurfaces [_eASL, _pASL vectorAdd [0, 0, _x], _e, _u, true, 1, "FIRE", "NONE"]) isNotEqualTo [] || {terrainIntersectASL [_eASL, _pASL vectorAdd [0, 0, _x]]}
}) > -1;
if (!_gizli) exitWith {false};
// RAYCAST (b): yol engelsiz mi (0.6 m yukseklikte GEOM)
private _uASL = (getPosASL _u) vectorAdd [0, 0, 0.6];
private _pATL = _pASL vectorAdd [0, 0, 0.6];
if ((lineIntersectsSurfaces [_uASL, _pATL, _u, objNull, true, 1, "GEOM", "NONE"]) isNotEqualTo []) exitWith {false};

_u setVariable [QGVAR(zorlaT), time + 5];
_u setVariable [QGVAR(zorlaBitis), time + _sure];
_u setVariable [QGVAR(taktikKilit), time + _sure];
// v8.512 KOSARKEN ATES ('b' sikki, fnc_atesHareket ile ayni olcu): ZOR DURUM (risk >= 0.6 ya da baski > 0.5) ya da CBA orani (lambs_danger_atesHareketOran) kadar sansla, atis hatti ACIKSA
//   hedef secimi kapatilmaz, hedefe BASTIRMA ATESI (doSuppressiveFire) verilerek kosulur (dusmanin nisanini bozar); aksi halde saf kosu (hedef secimi kapali).
//   Gercek atis sayisi atilisin basinda / sonunda mermi farkindan olculur ([KOSU-ATES] log + [ATES-HAREKET-OZET] 'b' sayaci).
private _ateseKos = false;
if ([_u, _e] call FUNC(atesHatiAcik)) then {
    _ateseKos = (_risk >= 0.6) || {_bask > 0.5} || {(["zorlaKosuAtes", [_u] call FUNC(birimId)] call FUNC(rastgele)) < (missionNamespace getVariable ["lambs_danger_atesHareketOran", 0.25])};
};
private _atVar = _u checkAIFeature "AUTOTARGET";
private _tVar = _u checkAIFeature "TARGET";
private _m0 = _u ammo (currentMuzzle _u);
if (_ateseKos) then {
    _u doSuppressiveFire _e;
    // v8.517: RPT 13:36 [KOSU-ATES] kosarken atilan mermi: 0 -> doSuppressiveFire hareket halinde yutuluyor; kosu boyunca 0.45 sn'de bir forceWeaponFire (atis hatti acik, asker gercekten kosuyorsa) kisa seri
    [_u, _e, _sure] spawn {
        params ["_uu", "_ee", "_sr"];
        private _bit = time + _sr;
        while {alive _uu && {time < _bit}} do {
            sleep 0.45;
            if (isNull _ee || {!alive _ee}) exitWith {};
            if ((speed _uu) < 0.5) then { continue };
            if !([_uu, _ee] call FUNC(atesHatiAcik)) then { continue };
            private _mz = currentMuzzle _uu;
            if (_mz isEqualTo "" || {(_uu ammo _mz) <= 0}) then { continue };
            _uu doWatch _ee;
            _uu forceWeaponFire [_mz, currentWeaponMode _uu];
        };
    };
    if (!isNil "lambs_danger_atesHareketSay") then { lambs_danger_atesHareketSay set ["b_mod", (lambs_danger_atesHareketSay getOrDefault ["b_mod", 0]) + 1]; };
} else {
    if (_atVar) then { _u disableAI "AUTOTARGET"; };
    if (_tVar) then { _u disableAI "TARGET"; };
};
_u forceSpeed -1;
_u setSpeedMode "FULL";
_u setUnitPosWeak "UP";
_u doMove _pos;
if ((missionNamespace getVariable ["lambs_danger_zorlaLogN", 0]) < 40) then {
    missionNamespace setVariable ["lambs_danger_zorlaLogN", (missionNamespace getVariable ["lambs_danger_zorlaLogN", 0]) + 1];
    diag_log format ["[SIPER-ZORLA] %1 | %2 | dusman %3 m | siper %4 m (raycast: gizli + yol acik) | varis durus %5 | RISK %6 (tehdit %7, baski %8) | %10 | sure %9 sn", groupId (group _u), name _u, round _ed, round _mes, _ds, _risk toFixed 2, _tehdit toFixed 1, _bask toFixed 2, _sure toFixed 1, ["saf kosu (hedef secimi kapali)", "KOSARKEN BASTIRMA ATESI"] select _ateseKos];
};
[{
    params ["_uu", "_pp"];
    !alive _uu || {(_uu distance2D _pp) < 1.2}
}, {
    params ["_uu", "_pp", "_dd", "_ee", "_a1", "_t1", "_ak", "_mm0"];
    if (alive _uu) then {
        if (_a1) then { _uu enableAI "AUTOTARGET"; };
        if (_t1) then { _uu enableAI "TARGET"; };
        _uu setVariable [QGVAR(zorlaBitis), 0];
        _uu setUnitPosWeak _dd;
        [_uu] call FUNC(siperTut);   // v8.521: varinca siperde bekle (formasyon slotuna geri yuruyup git-gel yapmasin)
        if (_ak && {(missionNamespace getVariable ["lambs_danger_kosuAtesLogN", 0]) < 30}) then {
            missionNamespace setVariable ["lambs_danger_kosuAtesLogN", (missionNamespace getVariable ["lambs_danger_kosuAtesLogN", 0]) + 1];
            diag_log format ["[KOSU-ATES] %1 | %2 | kosarken atilan mermi: %3 (muzzle %4)", groupId (group _uu), name _uu, (_mm0 - (_uu ammo (currentMuzzle _uu))) max 0, currentMuzzle _uu];
        };
        if (!isNull _ee && {alive _ee}) then { _uu doWatch _ee; };
    };
}, [_u, _pos, _ds, _e, _atVar && {!_ateseKos}, _tVar && {!_ateseKos}, _ateseKos, _m0], _sure, {
    params ["_uu", "_pp", "_dd", "_ee", "_a1", "_t1", "_ak", "_mm0"];
    if (alive _uu) then {
        if (_a1) then { _uu enableAI "AUTOTARGET"; };
        if (_t1) then { _uu enableAI "TARGET"; };
        _uu setVariable [QGVAR(zorlaBitis), 0];
    };
}] call CBA_fnc_waitUntilAndExecute;
true
