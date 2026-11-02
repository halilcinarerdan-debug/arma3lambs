#include "script_component.hpp"
/*
 * Author: Cinar (ELITE fork)
 * ISINLANMA KORUMASI (v8.368; kullanici: 'tankta olen bir asker geriye isinlandi').
 *
 * KANIT (RPT 21:50:45-51): T-14K Armata isabet aldi (canMove / canFire false), komutan Khalili 'GET OUT' ile inerken [HIZ-ANOMALI] 42 km/s (anim getoutlow), 3 sn sonra [DURUM] ayni asker
 *   Incapacitated, aractan (diger murettebat [7281,4096]) ~360 m ileri-geri [7040,4360]'te. Kodumuzda murettebata setPos / setVelocity yok (aracTasima / aracMedevac yalniz kendi sahalarinda);
 *   tipik Arma / ACE fizik hatasi: arac isabeti + inis sirasinda ACE bayilma (ragdoll) kaynak / eski konuma firliyor. NEDEN KESIN DEGIL -> bu modul hem KORUR hem TESPIT LOGU yazar.
 *
 * ISLEYIS (0.4 sn'de bir, yalniz IZLENEN askerler): kara aracinda olan yerel AI askerler 2 sn'de bir 25 sn izlemeye alinir (aractan indikten sonra da 25 sn izlenir).
 *   Son guvenli konum: aracta iken ARACIN konumu, yayada iken askerin konumu. Iki ihlal:
 *   (a) tek tikte > 20 m (50 m/sn) yatay sicrama   (b) inisten sonra 8 sn icinde guvenli konumdan > 60 m uzakta, arac hala yakinda (< 40 m)
 *   -> askerin konumu SON GUVENLI KONUMA geri alinir (setPosASL), hizi sifirlanir; [ISINLANMA] satiri: asker / grup / arac / mesafe / lifeState / animasyon / hiz / arac hasari / ACE bayilma.
 *   Paraşut / havada (yukseklik > 15 m) askere dokunulmaz. Kapatma: CBA 'ELITE siper' > Isinlanma korumasi (lambs_danger_isinlanmaAktif).
 *
 * Arguments: None
 * Return Value: Baslatildi mi <BOOL>
 * Public: No
*/

if (!isNil "lambs_danger_isinlanmaStarted") exitWith {false};
lambs_danger_isinlanmaStarted = true;

diag_log "[ISINLANMA] isinlanma korumasi baslatildi (v8.368): aractan inen / aracta olan askerin > 20 m/tik sicramasi geri alinir";

[] spawn {
    private _taraT = 0;
    private _logN = 0;
    private _toplam = 0;
    while {true} do {
        sleep 0.4;
        if (!(missionNamespace getVariable ["lambs_danger_isinlanmaAktif", true])) then { continue };
        // 2 sn'de bir: aracta olan yerel AI askerleri izlemeye al
        if (time > _taraT) then {
            _taraT = time + 2;
            {
                _x setVariable [QGVAR(isinIzle), time + 25];
            } forEach (allUnits select {local _x && {!isPlayer _x} && {alive _x} && {!isNull objectParent _x} && {(objectParent _x) isKindOf "LandVehicle"}});
        };
        {
            private _u = _x;
            private _v = objectParent _u;
            private _aracta = !isNull _v;
            private _p = getPosASL _u;
            private _son = _u getVariable [QGVAR(isinSon), []];       // [posASL, zaman, aracPos (cikis noktasi), cikisT]
            if (_aracta) then {
                // aracta: guvenli konum = aracin konumu; cikis anini hatirla
                _u setVariable [QGVAR(isinSon), [getPosASL _v, time, getPosASL _v, -1]];
            } else {
                if (_son isNotEqualTo [] && {((getPosATL _u) select 2) < 15}) then {
                    _son params ["_sp", "_st", "_cp", "_ct"];
                    if (_ct < 0) then { _ct = time; _cp = _sp; };
                    private _atlama = (_p distance2D _sp) > 20 && {(time - _st) < 1.5};
                    private _uzak = (time - _ct) < 8 && {(_p distance2D _cp) > 60};
                    if (_atlama || _uzak) then {
                        _toplam = _toplam + 1;
                        if (_logN < 40) then {
                            _logN = _logN + 1;
                            diag_log format ["[ISINLANMA] %1 (%2) | %3 | %4 m sicrama (%5 sn, cikistan %6 sn sonra, cikis noktasindan %7 m) -> SON GUVENLI KONUMA GERI ALINDI | lifeState:%8 | ACE bayilma:%9 | anim:%10 | hiz:%11 km/s | grup %12 | toplam %13",
                                name _u, typeOf _u, ["tek tik", "cikis sonrasi uzak"] select (!_atlama), round (_p distance2D _sp), (time - _st) toFixed 1, (time - _ct) toFixed 1, round (_p distance2D _cp),
                                lifeState _u, _u getVariable ["ACE_isUnconscious", false], animationState _u, round (speed _u), groupId (group _u), _toplam];
                        };
                        _u setPosASL _sp;
                        _u setVelocity [0, 0, 0];
                        _u setVariable [QGVAR(isinSon), [_sp, time, _cp, _ct]];
                    } else {
                        _u setVariable [QGVAR(isinSon), [_p, time, _cp, _ct]];
                    };
                };
            };
        } forEach (allUnits select {local _x && {(_x getVariable [QGVAR(isinIzle), 0]) > time} && {!isPlayer _x} && {alive _x}});
    };
};

true
