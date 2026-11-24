#include "script_component.hpp"
/*
 * Author: Cinar (ELITE fork)
 * EYP KOSU: CATISARAK (zikzak + ates ederek) hedefe yaklas, canliBombaTetikM'de patla (v8.777; kullanici: 'araclardada olsun' + 've direk kosmasinlar catisarak girsinler' + 'adam uzerimize kossun catisarak').
 * fnc_eypSistem (canli bomba) ve teslim-bomba dongusu cagirir; BLOKLAR (spawn icinden cagrilmali), sonuc metni doner.
 * PIYADE: hedef alma / nisan AI'si ACIK (TARGET, AUTOTARGET, WEAPONAIM) -> kosarken ates eder (doWatch + reveal; doFire / doTarget YOK, onlar doMove'u iptal eder); siper / bastirma / FSM / otomatik muharebe KAPALI (siper aramaz, durmaz); davranis AWARE, tam hiz DEGIL kosu hizi
 *   (sprintte AI ates edemez); hedefe DIREK degil: zikzak BACAKLARI (5 sn / 3 m kala yeni nokta, 3-6 m yan sapma); 14 m icinde dogrudan hedefe.
 * ARAC (araba / kamyon / MRAP; Tank sinifi degil): surucu hedefin ANLIK konumuna tam hizla surer, zikzak aynen; surucu disi murettebatin ates AI'si ACIK kalir (catisarak); arac hedefe tetik + 3 m kalinca patlar (arac + murettebat olur).
 * Patlama: fnc_eypPatlat (CBA eypPatlamaGucu; piyade / arac). Referans kodlardan (aral_canl_bomba / canl_bomba): SON AN HIZ ARTISI (piyade canliBombaAtilmaM 45 m, arac canliBombaAracAtilmaM 120 m ya da hasar > 0.1 -> sprint / tam hiz + bagirma sesi; oncesi kosu / sivil trafik hizi), allowFleeing 0, aracta allowCrewInImmobile (tekerlek patlasa inmez),
 *   hedefe varamadan VURULURSA canliBombaOlumSans (0.5) ihtimaliyle cihaz olunce patlar (arac: surucu olur / arac yok olursa).
 * Sonuc metni: "PATLADI" / "vuruldu / oldu" / "hedef yok" / "zaman asimi" / "arac durdu".
 * GRUP: piyade kosucu mangayla birlikteyse gecici ayri gruba alinir (grup duzeyi davranis / muharebe modu / hiz mangayi etkilemesin), bitince (hayattaysa) geri katilir.
 * ZEUS / 3DEN: birim ayarlari (eypTetikM, eypGizli: referans PBIED / VBIED 'gizli yaklasim' = CARELESS + BLUE + yuruyus / 45 km/s, son anda sprint; eypAtilmaM, eypOlumSans, eypGuc, eypVaril) fnc_eypBombaYap ile yazilir.
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
private _surge = false;
private _atilmaM = if (_arac) then { ((missionNamespace getVariable ["lambs_danger_canliBombaAracAtilmaM", 120]) max 30) min 300 } else { ((missionNamespace getVariable ["lambs_danger_canliBombaAtilmaM", 45]) max 10) min 150 };
// v8.777 ZEUS / 3DEN: birim (arac) basina ayar ezmeleri (fnc_eypBombaYap yazar): eypAtilmaM, eypOlumSans, eypGuc, eypGizli (referans PBIED: yurur, ates etmez, son anda sprint), eypVaril (arac ustu gorsel varil)
private _ovA = _v getVariable [QGVAR(eypAtilmaM), -1];
if (_ovA >= 0) then { _atilmaM = _ovA; };
private _ovT = _v getVariable [QGVAR(eypTetikM), -1];
if (_ovT > 0) then { _tetik = (_ovT max 2) min 25; };
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
    _v engineOn true;
    _v limitSpeed ([60, 45] select _gizli);
    _b setSpeedMode "NORMAL";
} else {
    _b setUnitPos "UP";
    _b forceSpeed (_b getSpeed (if (_gizli) then {"SLOW"} else {["FAST", "NORMAL"] select _catis}));
};

// v8.779 (RPT a4e1d6c8 / f82218cf; kullanici: 'zikzaki check et', 'araciada coz', 'menzile girdigi gibi patlasin'):
//   (1) ESKI HATA: her 0.4 sn'de doMove + doTarget + doFire. doFire komutu doMove'u iptal eder (asker durur / yavaslar); doMove'u her tikte degisen noktaya yenilemek yol hesabini surekli sifirlar (ARAC 0 km/s'de kaldi: [MEKANIZE-YAVAS] hiz 0).
//   (2) YENI: zikzak = BACAKLAR (her ~5 sn / 3 m kala yeni nokta: hedefe 10-16 m ilerleme + 3-6 m yan sapma, yon dongusu); arac ve gizli yaklasimda zikzak YOK (dogrudan, doMove 2 sn'de bir); 14 m icinde dogrudan hedefe (0.6 sn).
//   (3) ates: doFire / doTarget YOK; doWatch + reveal ile hedef gosterilir, TARGET / AUTOTARGET acik oldugu icin AI kosarken kendisi ates eder.
//   (4) PATLAMA: hedef YA DA tetik menzilindeki HERHANGI dusman (menzile girdigi gibi); yakinda (<30 m) 0.15 sn'de bir kontrol.
//   (5) arac takilma: 15 sn'den uzun hiz < 3 km/s -> 'arac durdu' (sonuc dongusu serbest kalir). Ilerleme logu: [EYP-KOS] (ilk 25 satir, 5 sn'de bir).
private _bacak = [];
private _bacakT = 0;
private _isaret = selectRandom [-1, 1];
private _dmT = 0;
private _durT = -1;
private _bitti = false;
private _taraf = side group _b;
private _izlenen = objNull;
private _tetikT = _tetik + ([0, 3] select _arac);
private _logT = 0;
while {alive _b && {!_bitti} && {time < (_t0 + _sure)}} do {
    private _dt = 0.4;
    if (isNull _h || {!alive _h}) then { _h = _b findNearestEnemy _b; };
    if (isNull _h) then {
        _sonuc = "hedef yok";
        _bitti = true;
    } else {
        private _m = _v distance _h;
        _dt = [0.4, 0.15] select (_m < 30);
        // PATLAMA: hedef ya da tetik menzilindeki HERHANGI dusman
        private _yakin = (_v nearEntities [["CAManBase", "LandVehicle"], _tetikT]) select {alive _x && {_x isNotEqualTo _v} && {!(_x in (crew _v))} && {!captive _x} && {(side _x) isNotEqualTo civilian} && {(_taraf getFriend (side _x)) < 0.6}};
        if (_m <= _tetikT || {_yakin isNotEqualTo []}) then {
            _sonuc = "PATLADI";
            _bitti = true;
            [getPosATL _v, ["piyade", "arac"] select _arac, _gucOv] call FUNC(eypPatlat);
            if (_arac) then { { _x setDamage 1; } forEach (crew _v); _v setDamage 1; } else { _b setDamage 1; };
        } else {
            if (_arac) then {
                if (!alive _v) then { _sonuc = "vuruldu / oldu"; _bitti = true; };
                if (!_bitti && {!canMove _v}) then { _sonuc = "arac durdu"; _bitti = true; };
                if (!_bitti) then {
                    if ((speed _v) < 3) then {
                        if (_durT < 0) then { _durT = time; };
                        if ((time - _durT) > 15) then { _sonuc = "arac durdu"; _bitti = true; };
                    } else { _durT = -1; };
                };
            };
            if (!_bitti) then {
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
                    };
                };
                private _hy = _v getDir _h;
                if (_catis && {!_arac} && {!(_h isEqualTo _izlenen)}) then {
                    _b doWatch _h;
                    _b reveal [_h, 4];
                    _izlenen = _h;
                };
                if (_catis && {!_arac} && {_m > 14}) then {
                    // zikzak bacaklari
                    if (_bacak isEqualTo [] || {time > _bacakT} || {(_b distance2D _bacak) < 3}) then {
                        _isaret = -_isaret;
                        private _ileri = (_m - 8) min (10 + (random 6));
                        _bacak = ((getPosATL _v) getPos [_ileri, _hy]) getPos [(3 + (random 3)) * _isaret, _hy + 90];
                        _bacakT = time + 5;
                        _b doMove _bacak;
                    };
                } else {
                    _bacak = [];
                    // dogrudan: doMove yalniz araliklarla yenilenir (her tikte yenilemek yol hesabini sifirlar)
                    if (time >= _dmT) then {
                        _b doMove (getPosATL _h);
                        _dmT = time + ([0.6, 2] select _arac);
                    };
                };
            };
        };
        if (time >= _logT) then {
            _logT = time + 5;
            private _kl = missionNamespace getVariable ["lambs_danger_eypKosLogN", 0];
            if (_kl < 25) then {
                missionNamespace setVariable ["lambs_danger_eypKosLogN", _kl + 1];
                diag_log format ["[EYP-KOS] %1 | %2 | hedef %3 %4 m | hiz %5 km/s | %6 | surge %7 | gecen %8 sn", name _b, typeOf _v, typeOf _h, round _m, round (speed _v), ["piyade zikzak", "piyade dogrudan", "arac dogrudan"] select (if (_arac) then {2} else {[1, 0] select (_catis && {_m > 14})}), _surge, round (time - _t0)];
            };
        };
    };
    if (!_bitti) then { sleep _dt; };
};
if (alive _b && {!_arac}) then { _b doWatch objNull; };
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
