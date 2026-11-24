#include "script_component.hpp"
/*
 * Author: Cinar (ELITE fork)
 * EYP KOSU: CATISARAK (zikzak + ates ederek) hedefe yaklas, canliBombaTetikM'de patla (v8.777; kullanici: 'araclardada olsun' + 've direk kosmasinlar catisarak girsinler' + 'adam uzerimize kossun catisarak').
 * fnc_eypSistem (canli bomba) ve teslim-bomba dongusu cagirir; BLOKLAR (spawn icinden cagrilmali), sonuc metni doner.
 * PIYADE: hedef alma / nisan AI'si ACIK (TARGET, AUTOTARGET, WEAPONAIM) -> kosarken ates eder (doTarget + doFire her turda); siper / bastirma / FSM / otomatik muharebe KAPALI (siper aramaz, durmaz); davranis AWARE, tam hiz DEGIL kosu hizi
 *   (sprintte AI ates edemez); hedefe DIREK degil, uzakta yan sapmali zikzak (en cok 8 m, mesafeyle azalir); 12 m icinde dogrudan hedefe.
 * ARAC (araba / kamyon / MRAP; Tank sinifi degil): surucu hedefin ANLIK konumuna tam hizla surer, zikzak aynen; surucu disi murettebatin ates AI'si ACIK kalir (catisarak); arac hedefe tetik + 3 m kalinca patlar (arac + murettebat olur).
 * Patlama: fnc_eypPatlat (CBA eypPatlamaGucu; piyade / arac). Referans kodlardan (aral_canl_bomba / canl_bomba): SON AN HIZ ARTISI (piyade canliBombaAtilmaM 45 m, arac canliBombaAracAtilmaM 120 m ya da hasar > 0.1 -> sprint / tam hiz + bagirma sesi; oncesi kosu / sivil trafik hizi), allowFleeing 0, aracta allowCrewInImmobile (tekerlek patlasa inmez),
 *   hedefe varamadan VURULURSA canliBombaOlumSans (0.5) ihtimaliyle cihaz olunce patlar (arac: surucu olur / arac yok olursa).
 * Sonuc metni: "PATLADI" / "vuruldu / oldu" / "hedef yok" / "zaman asimi" / "arac durdu".
 * GRUP: piyade kosucu mangayla birlikteyse gecici ayri gruba alinir (grup duzeyi davranis / muharebe modu / hiz mangayi etkilemesin), bitince (hayattaysa) geri katilir.
 * ZEUS / 3DEN: birim ayarlari (eypGizli: referans PBIED / VBIED 'gizli yaklasim' = CARELESS + BLUE + yuruyus / 45 km/s, son anda sprint; eypAtilmaM, eypOlumSans, eypGuc, eypVaril) fnc_eypBombaYap ile yazilir.
 * SINIR: oyunda DENENMEDI; zikzak AI'nin yol bulmasina bagli (dar sokakta sapma kisalir); aracta surucu olmadan once durursa 'arac durdu' sayilir.
 *
 * Arguments:
 * 0: Kosucu (piyade ya da arac surucusu) <OBJECT>
 * 1: Hedef <OBJECT>
 * 2: Sure siniri (sn) <NUMBER> (varsayilan 40)
 * 3: Ates ederek mi (CBA canliBombaCatis) <BOOL> (varsayilan CBA)
 *
 * Return Value: Sonuc metni <STRING>
 *
 * Public: No
*/

params [["_b", objNull, [objNull]], ["_h", objNull, [objNull]], ["_sure", 40, [0]], ["_catis", missionNamespace getVariable ["lambs_danger_canliBombaCatis", true], [true]]];
if (isNull _b || {!alive _b}) exitWith {"vuruldu / oldu"};
private _tetik = ((missionNamespace getVariable ["lambs_danger_canliBombaTetikM", 5]) max 3) min 12;
private _arac = !isNull objectParent _b;
private _v = vehicle _b;
private _t0 = time;
private _sonuc = "zaman asimi";
private _faz = random 360;
private _surge = false;
private _atilmaM = if (_arac) then { ((missionNamespace getVariable ["lambs_danger_canliBombaAracAtilmaM", 120]) max 30) min 300 } else { ((missionNamespace getVariable ["lambs_danger_canliBombaAtilmaM", 45]) max 10) min 150 };
// v8.777 ZEUS / 3DEN: birim (arac) basina ayar ezmeleri (fnc_eypBombaYap yazar): eypAtilmaM, eypOlumSans, eypGuc, eypGizli (referans PBIED: yurur, ates etmez, son anda sprint), eypVaril (arac ustu gorsel varil)
private _ovA = _v getVariable [QGVAR(eypAtilmaM), -1];
if (_ovA >= 0) then { _atilmaM = _ovA; };
private _gizli = (_v getVariable [QGVAR(eypGizli), false]) isEqualTo true;
if (_gizli) then { _catis = false; };
private _gucOv = _v getVariable [QGVAR(eypGuc), -1];
private _bh0 = behaviour _b;
private _cm0 = combatMode _b;
// piyade grubuyla birlikteyse (editor / Zeus ile isaretlenen asker) grup duzeyi ayarlar (davranis / muharebe modu / hiz) tum mangayi etkilemesin diye gecici ayri gruba alinir
private _g0 = group _b;
private _izole = !_arac && {(count (units _g0)) > 1};
if (_izole) then { private _gn = createGroup [side _g0, true]; [_b] joinSilent _gn; };

_b setVariable [QGVAR(disableAI), true];
_b allowFleeing 0;
{ _b disableAI _x; } forEach ["AUTOCOMBAT", "COVER", "SUPPRESSION", "FSM"];
{ _b enableAI _x; } forEach ["MOVE", "PATH", "ANIM"];
if (_catis && {!_arac}) then {
    { _b enableAI _x; } forEach ["TARGET", "AUTOTARGET", "WEAPONAIM"];
    _b setCombatMode "RED";
} else {
    if (!_arac) then { { _b disableAI _x; } forEach ["TARGET", "AUTOTARGET"]; };
};
_b setBehaviour (["AWARE", "CARELESS"] select _gizli);
if (_arac) then {
    _v allowCrewInImmobile true;
    _v limitSpeed ([60, 45] select _gizli);
    _b setSpeedMode "NORMAL";
} else {
    _b setUnitPos "UP";
    _b forceSpeed (_b getSpeed (if (_gizli) then {"SLOW"} else {["FAST", "NORMAL"] select _catis}));
};

while {alive _b && {time < (_t0 + _sure)}} do {
    if (isNull _h || {!alive _h}) then { _h = _b findNearestEnemy _b; };
    if (isNull _h) exitWith { _sonuc = "hedef yok"; };
    private _m = _v distance _h;
    if (_m <= (_tetik + ([0, 3] select _arac))) exitWith {
        _sonuc = "PATLADI";
        [getPosATL _v, ["piyade", "arac"] select _arac, _gucOv] call FUNC(eypPatlat);
        if (_arac) then { { _x setDamage 1; } forEach (crew _v); _v setDamage 1; } else { _b setDamage 1; };
    };
    if (_arac && {!alive _v}) exitWith { _sonuc = "vuruldu / oldu"; };
    if (_arac && {!canMove _v}) exitWith { _sonuc = "arac durdu"; };
    // SON AN: mesafe ya da hasar -> sprint / tam hiz (referans: terminal surge)
    if (!_surge && {_m <= _atilmaM || {(damage _v) > 0.1} || {(damage _b) > 0.1}}) then {
        _surge = true;
        if (_arac) then {
            _v limitSpeed 300;
            _b setSpeedMode "FULL";
            (group _b) setSpeedMode "FULL";
            _v forceSpeed -1;
        } else {
            _b forceSpeed (_b getSpeed "FAST");
            if (_gizli) then { _b setBehaviour "AWARE"; };
            playSound3D ["A3\sounds_f\characters\human-sfx\P01\Hit_Max_1.wss", _b, false, getPosASL _b, 3, 1, 100];
        };
    };
    // zikzak: hedefe dik yonde sinus sapma (uzakta genis, yakinda 0)
    private _yan = ((_m - 12) max 0) min 8;
    private _hp = getPosATL _h;
    private _hy = _v getDir _h;
    private _yp = _hp getPos [_yan * (sin ((time * 90) + _faz)), _hy + 90];
    _b doMove _yp;
    if (_catis && {!_arac} && {!_surge}) then {
        _b doTarget _h;
        _b doFire _h;
    };
    sleep 0.4;
};
if (!alive _b && {_sonuc isNotEqualTo "PATLADI"}) then { _sonuc = "vuruldu / oldu"; };
if (_sonuc isEqualTo "PATLADI" || {!alive _v}) then { deleteVehicle (_v getVariable [QGVAR(eypVaril), objNull]); };

// referans (canl_bomba / aral_canl_bomba): hedefe varamadan vurulursa cihaz olunce patlayabilir
if (_sonuc isEqualTo "vuruldu / oldu") then {
    private _ovO = _v getVariable [QGVAR(eypOlumSans), -1];
    private _ol = (((if (_ovO >= 0) then {_ovO} else {missionNamespace getVariable ["lambs_danger_canliBombaOlumSans", 0.5]})) max 0) min 1;
    if ((random 1) < _ol) then {
        sleep 0.3;
        [getPosATL _v, ["piyade", "arac"] select _arac, _gucOv] call FUNC(eypPatlat);
        private _sy = missionNamespace getVariable ["lambs_danger_eypKosSay", createHashMap];
        missionNamespace setVariable ["lambs_danger_eypKosSay", _sy];
        _sy set ["olum_patlama", (_sy getOrDefault ["olum_patlama", 0]) + 1];
        diag_log format ["[EYP-KOS] OLUM PATLAMASI | %1 | %2 | sans %3", name _b, ["piyade", "arac"] select _arac, _ol];
    };
};

if (alive _b) then {
    { _b enableAI _x; } forEach ["TARGET", "AUTOTARGET", "AUTOCOMBAT", "COVER", "SUPPRESSION", "FSM"];
    _b forceSpeed -1;
    if (_izole) then {
        if (!isNull _g0 && {(count (units _g0)) > 0}) then { [_b] joinSilent _g0; };
    } else {
        _b setBehaviour _bh0;
        _b setCombatMode _cm0;
    };
    _b setVariable [QGVAR(disableAI), false];
    if (_arac && {alive _v}) then { _v limitSpeed 1000; _v allowCrewInImmobile false; };
};
_sonuc
