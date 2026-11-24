#include "script_component.hpp"
/*
 * Author: Cinar (ELITE fork)
 * EYP KOSU: CATISARAK (ates ederek) hedefe yaklas, canliBombaTetikM'de patla (v8.777; kullanici: 'araclardada olsun' + 've direk kosmasinlar catisarak girsinler' + 'adam uzerimize kossun catisarak').
 * fnc_eypSistem (canli bomba) ve teslim-bomba dongusu cagirir; BLOKLAR (spawn icinden cagrilmali), sonuc metni doner.
 * PIYADE: hedef alma / nisan AI'si ACIK (TARGET, AUTOTARGET, WEAPONAIM) -> kosarken ates eder (doWatch + reveal; doFire / doTarget YOK, onlar doMove'u iptal eder); siper / bastirma / FSM / otomatik muharebe KAPALI (siper aramaz, durmaz); davranis AWARE, tam hiz DEGIL kosu hizi
 *   (sprintte AI ates edemez); hedefe DOGRUDAN (zikzak v8.780'de kullanici istegiyle KALDIRILDI).
 * ARAC (araba / kamyon / MRAP; Tank sinifi degil): surucu hedefin ANLIK konumuna tam hizla surer (dogrudan); surucu disi murettebatin ates AI'si ACIK kalir (catisarak); arac hedefe tetik + 3 m kalinca patlar (arac + murettebat olur).
 * Patlama: fnc_eypPatlat (CBA eypPatlamaGucu; piyade / arac). Referans kodlardan (aral_canl_bomba / canl_bomba): SON AN HIZ ARTISI (piyade canliBombaAtilmaM 45 m, arac canliBombaAracAtilmaM 120 m ya da hasar > 0.1 -> sprint / tam hiz + bagirma sesi; oncesi kosu / sivil trafik hizi), allowFleeing 0, aracta allowCrewInImmobile (tekerlek patlasa inmez),
 *   hedefe varamadan VURULURSA canliBombaOlumSans (0.5) ihtimaliyle cihaz olunce patlar (arac: surucu olur / arac yok olursa).
 * Sonuc metni: "PATLADI" / "vuruldu / oldu" / "hedef yok" / "zaman asimi" / "arac durdu".
 * GRUP: piyade kosucu mangayla birlikteyse gecici ayri gruba alinir (grup duzeyi davranis / muharebe modu / hiz mangayi etkilemesin), bitince (hayattaysa) geri katilir.
 * ZEUS / 3DEN: birim ayarlari (eypTetikM, eypMenzil, eypHedefTaraf, eypGizli: referans PBIED / VBIED 'gizli yaklasim' = CARELESS + BLUE + yuruyus / 45 km/s, son anda sprint; eypAtilmaM, eypOlumSans, eypGuc, eypVaril) fnc_eypBombaYap ile yazilir.
 * SINIR: oyunda DENENMEDI; aracta 15 sn'den uzun hiz < 3 km/s olursa 'arac durdu' sayilir.
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

// v8.783 (RPT 19bff8dc: piyade 40-81 m'de duruyor / yan adim atiyor): fnc_yakinHareket (oyuncu icin 45 x 1.8 = 81 m) ve fnc_acikBekleme emri eziyordu.
//   birim TAKTIK KILIDI (74 ELITE fonksiyonu saygi duyar) + grup HARIC / disableGroupAI (LAMBS cekirdegi + ELITE grup katmani) kosu boyunca; bitince eski deger geri
private _grp = group _b;
private _gDAI0 = _grp getVariable [QGVAR(disableGroupAI), false];
private _gGorev0 = _grp getVariable [QGVAR(gorev), ""];
_grp setVariable [QGVAR(disableGroupAI), true];
_grp setVariable [QGVAR(gorev), "HARIC"];
_b setVariable [QGVAR(taktikKilit), time + _sure + 5];
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
    if (_gizli) then {
        _v limitSpeed 45;
        _b setSpeedMode "NORMAL";
    } else {
        // v8.781 (kullanici: 'arac hic durmasin direk gitsin'): arac en bastan TAM HIZ (kademeli yaklasma yalniz gizli modda)
        _v limitSpeed 300;
        _b setSpeedMode "FULL";
        (group _b) setSpeedMode "FULL";
        _v forceSpeed -1;
        _surge = true;
    };
} else {
    _b setUnitPos "UP";
    _b forceSpeed (_b getSpeed (if (_gizli) then {"SLOW"} else {["FAST", "NORMAL"] select _catis}));
};

// v8.779 (RPT a4e1d6c8 / f82218cf; kullanici: 'zikzaki check et', 'araciada coz', 'menzile girdigi gibi patlasin'):
//   (1) ESKI HATA: her 0.4 sn'de doMove + doTarget + doFire. doFire komutu doMove'u iptal eder (asker durur / yavaslar); doMove'u her tikte degisen noktaya yenilemek yol hesabini surekli sifirlar (ARAC 0 km/s'de kaldi: [MEKANIZE-YAVAS] hiz 0).
//   (2) [v8.780: zikzak bacaklari kullanici istegiyle KALDIRILDI] hedefe dogrudan; doMove araliklarla yenilenir (arac 2 sn, piyade 0.6-1 sn).
//   (3) ates: doFire / doTarget YOK; doWatch + reveal ile hedef gosterilir, TARGET / AUTOTARGET acik oldugu icin AI kosarken kendisi ates eder.
//   (4) PATLAMA: hedef YA DA tetik menzilindeki HERHANGI dusman (menzile girdigi gibi); yakinda (<30 m) 0.15 sn'de bir kontrol.
//   (5) arac takilma: 15 sn'den uzun hiz < 3 km/s -> 'arac durdu' (sonuc dongusu serbest kalir). Ilerleme logu: [EYP-KOS] (ilk 25 satir, 5 sn'de bir).
private _sonEmir = [];
private _dmT = 0;
private _isaretli = !isNil {_v getVariable QGVAR(eypBomba)};
private _yokT = -1;
private _durT = -1;
private _bitti = false;
private _taraf = side group _b;
private _izlenen = objNull;
private _tetikT = _tetik + ([0, 3] select _arac);
private _logT = 0;
private _sonPoz = getPosATL _v;
while {alive _b && {!_bitti} && {time < (_t0 + _sure)}} do {
    private _dt = 0.4;
    if (!isNull _v) then { _sonPoz = getPosATL _v; };
    if (isNull _h || {!alive _h}) then {
        _h = _b findNearestEnemy _b;
        // v8.781: isaretli (Zeus / 3DEN / init) bomba bilgi aramaz, tespit menzilindeki en yakin dusmani yeniden bulur
        if (isNull _h && {_isaretli}) then { _h = [_v, _v getVariable [QGVAR(eypMenzil), 400], _v getVariable [QGVAR(eypHedefTaraf), 0]] call FUNC(eypHedefBul); };
    };
    if (isNull _h) then {
        // isaretli bomba 8 sn boyunca hedef bekler (cikmaz: AI geri acilip arac durmasin); digerleri hemen cikar
        if (_isaretli && {_yokT < 0}) then { _yokT = time; };
        if (!_isaretli || {(time - _yokT) > 8}) then {
            _sonuc = "hedef yok";
            _bitti = true;
        };
    } else {
        _yokT = -1;
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
                        if ((time - _durT) > 15) then { _sonuc = "arac durdu"; _bitti = true; } else {
                            // 4 sn'den uzun duruyorsa emri hemen yenile (takilmis / plan bitmis olabilir)
                            if ((time - _durT) > 4 && {time >= _dmT}) then { _b doMove (getPosATL _h); _sonEmir = getPosATL _h; _dmT = time + 3; };
                        };
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
                if (_catis && {!_arac} && {!(_h isEqualTo _izlenen)}) then {
                    _b doWatch _h;
                    _b reveal [_h, 4];
                    _izlenen = _h;
                };
                // v8.780 (kullanici: 'zikzakta cok bekliyor, zikzaki kaldir'): ZIKZAK YOK, hedefe dogrudan. doMove yalniz hedef 6 m'den fazla kaydiysa ya da araliktan sonra yenilenir (her tikte yenilemek yol hesabini sifirlar)
                // ARAC: doMove NADIREN (hedef 60 m / yakinda 25 m kaydiysa, en az 3 sn arayla; hedef sabitse 8 sn'de bir): her yeni emir yol hesabini sifirlar, arac durup yeniden planliyordu (RPT 0689d2a0: hiz 47 -> 0)
                private _hp = getPosATL _h;
                private _esik = if (_arac) then {[60, 25] select (_m < 80)} else {6};
                private _zorS = [1, 8] select _arac;
                if (time >= _dmT && {_sonEmir isEqualTo [] || {(_hp distance2D _sonEmir) > _esik} || {time >= (_dmT + _zorS)}}) then {
                    _b doMove _hp;
                    _sonEmir = _hp;
                    _dmT = time + ([0.6, 3] select _arac);
                };
            };
        };
        if (time >= _logT) then {
            _logT = time + 5;
            private _kl = missionNamespace getVariable ["lambs_danger_eypKosLogN", 0];
            if (_kl < 25) then {
                missionNamespace setVariable ["lambs_danger_eypKosLogN", _kl + 1];
                diag_log format ["[EYP-KOS] %1 | %2 | hedef %3 %4 m | hiz %5 km/s | %6 | surge %7 | gecen %8 sn", name _b, typeOf _v, typeOf _h, round _m, round (speed _v), ["piyade dogrudan", "arac dogrudan"] select _arac, _surge, round (time - _t0)];
            };
        };
    };
    if (!_bitti) then { sleep _dt; };
};
if (alive _b && {!_arac}) then { _b doWatch objNull; };
// v8.782 (RPT 53423fd4: birim silinince 'Error: No vehicle' + patlama xy [0,0]): silinen (null) birim patlamaz; olum patlamasi son bilinen konumda
if (isNull _b) then {
    _sonuc = "silindi";
} else {
    if (!alive _b && {_sonuc isNotEqualTo "PATLADI"}) then { _sonuc = "vuruldu / oldu"; };
};
if (_sonuc isEqualTo "PATLADI" || {isNull _v} || {!alive _v}) then { deleteVehicle (_v getVariable [QGVAR(eypVaril), objNull]); };

// referans (canl_bomba / aral_canl_bomba): hedefe varamadan vurulursa cihaz olunce patlayabilir
if (_sonuc isEqualTo "vuruldu / oldu") then {
    private _ovO = _v getVariable [QGVAR(eypOlumSans), -1];
    private _ol = (((if (_ovO >= 0) then {_ovO} else {missionNamespace getVariable ["lambs_danger_canliBombaOlumSans", 0.5]})) max 0) min 1;
    if ((random 1) < _ol) then {
        sleep 0.3;
        [_sonPoz, ["piyade", "arac"] select _arac, _gucOv] call FUNC(eypPatlat);
        private _sy = missionNamespace getVariable ["lambs_danger_eypKosSay", createHashMap];
        missionNamespace setVariable ["lambs_danger_eypKosSay", _sy];
        _sy set ["olum_patlama", (_sy getOrDefault ["olum_patlama", 0]) + 1];
        diag_log format ["[EYP-KOS] OLUM PATLAMASI | %1 | %2 | sans %3", name _b, ["piyade", "arac"] select _arac, _ol];
    };
};

if (!isNull _grp) then {
    _grp setVariable [QGVAR(disableGroupAI), [nil, true] select _gDAI0];
    _grp setVariable [QGVAR(gorev), [nil, _gGorev0] select (_gGorev0 isNotEqualTo "")];
};
if (!isNull _b) then { _b setVariable [QGVAR(taktikKilit), time]; };
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
