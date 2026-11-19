#include "script_component.hpp"
/*
 * Author: Cinar (ELITE fork)
 * ZAMANLI KANAT: BASKI EKIBI KAPISI (v8.669; yol haritasi Asama 12 madde 3; kullanici: '2.dekilerin hepsini yap'): manevra ekibi kanada, BASKI EKIBI ATES KURMADAN cikmaz.
 *
 * ESKI: fnc_tacticsFlank 2-10 sn rastgele gecikmeyle LAMBS doGroupFlank'i baslatiyordu; baski ekibi (MG / AT / saglikci / nisanci ya da hazir olmayanlar) icin hicbir emir ve kapi yoktu,
 *   manevra ekibi dusman bastirilmadan kalkabiliyordu.
 * SIMDI (fnc_tacticsFlank cagirir; CBA lambs_danger_kanatZamanli, varsayilan ACIK):
 *   1) BASKI EKIBI = manevra disinda kalan canli piyadeler (rol disiplini MG / AT / saglikci / nisanciyi kanatta kosturmaz); yoksa ve >= 4 kisilik manevra ekibi varsa dusmana EN YAKIN 1/3'u (liderden haric) baski ekibi olur.
 *   2) KURULUM: baski ekibi comelir, hedefe bakar, ates hatti ACIKSA (fnc_atesHatiAcik; duvara atmaz) fnc_doSuppress ile hedef alanini bastirir; manevra ekibi BEKLER.
 *      KAPI: baski ekibinin >= %50'si son 5 sn'de ates ettiyse (sonAtisT) ya da lambs_danger_kanatBaskiBekleS (14 sn) dolduysa; hicbir baskici atis hatti bulamiyorsa 3 sn'den fazla beklenmez.
 *   3) MANEVRA: doGroupFlank baslar. Manevra suresince (en cok 90 sn) baski 8 sn'de bir TAZELENIR; baski ekibine taktikKilit konur (siper / bekleme katmanlari yerlerinden oynatmasin).
 *   4) BITIS: tactic bayragi kalkinca / 90 sn dolunca kilitler (yalniz kendi koydugumuz) temizlenir.
 * SINIR / T: doGroupFlank'in icine (LAMBS ana eklentisi bu depoda yok) mudahale edilmez; baski ekibi kaybolursa manevra DURDURULMAZ (yalniz log). Oyunda DENENMEDI.
 * Log: [KANAT-BASKI] (kurulum / bitis).
 *
 * Arguments:
 * 0: Grup <GROUP>
 * 1: Hedef <ARRAY AGL>
 * 2: Baski ekibi <ARRAY of OBJECT>
 * 3: doGroupFlank argumanlari [grup, birimler, araclar, posList, overwatch] <ARRAY>
 *
 * Return Value: Baslatildi mi <BOOL>
 * Public: No
*/

params [["_group", grpNull, [grpNull]], ["_target", [], [[]]], ["_destek", [], [[]]], ["_dgf", [], [[]]]];
if (isNull _group || {(count _target) < 2} || {_destek isEqualTo []} || {(count _dgf) < 5}) exitWith {false};

[_group, _target, _destek, _dgf] spawn {
    params ["_group", "_target", "_destek", "_dgf"];
    private _t0 = time;
    private _tASL = AGLToASL _target;
    private _bekleMax = ((missionNamespace getVariable ["lambs_danger_kanatBaskiBekleS", 14]) max 3) min 40;

    // baski ver: ates hatti acik olan, mermisi yeten baskici hedefe doSuppress; kac kisi emir aldi dondurur
    private _bastir = {
        private _ates = 0;
        {
            private _u = _x;
            if (
                alive _u && {isNull objectParent _u} && {(lifeState _u) in ["HEALTHY", "INJURED"]} && {!captive _u}
                && {(currentWeapon _u) isNotEqualTo ""} && {(needReload _u) < 0.7}
            ) then {
                _u setVariable [QGVAR(taktikKilit), time + 14];
                if ([_u, _target] call FUNC(atesHatiAcik)) then {
                    _u doWatch _target;
                    [_u, _tASL] call EFUNC(main,doSuppress);
                    _ates = _ates + 1;
                };
            };
        } forEach _destek;
        _ates
    };

    // 1) kurulum
    {
        if (alive _x && {isNull objectParent _x}) then {
            _x setVariable [QGVAR(taktikKilit), time + 20];
            _x setUnitPosWeak "MIDDLE";
            _x enableAI "TARGET";
            _x enableAI "AUTOTARGET";
        };
    } forEach _destek;
    private _emir = call _bastir;
    private _bekle = [3, _bekleMax] select (_emir > 0);
    waitUntil {
        sleep 0.5;
        private _canli = _destek select {alive _x};
        private _atan = {(time - (_x getVariable [QGVAR(sonAtisT), -999])) < 5} count _canli;
        isNull _group || {!(_group getVariable [QGVAR(isExecutingTactic), false])}
        || {time > (_t0 + _bekle)}
        || {(_canli isNotEqualTo []) && {_atan >= (ceil (0.5 * (count _canli)))}}
    };
    private _canli0 = _destek select {alive _x};
    private _atan0 = {(time - (_x getVariable [QGVAR(sonAtisT), -999])) < 5} count _canli0;
    diag_log format [
        "[KANAT-BASKI] %1 | KURULDU: baski ekibi %2 (emir alan %3, son 5 sn'de ates eden %4) | manevra %5 | bekleme %6 sn%7",
        groupId _group, count _canli0, _emir, _atan0, count (_dgf select 1), (time - _t0) toFixed 1, ["", " (ates hatti acik baskici yok: kisa bekleme)"] select (_emir <= 0)
    ];
    if (isNull _group || {!(_group getVariable [QGVAR(isExecutingTactic), false])}) exitWith {};

    // 2) manevra
    _dgf call EFUNC(main,doGroupFlank);

    // 3) baski manevra boyunca tazelenir
    private _bitis = time + 90;
    private _kayipLog = false;
    while {!isNull _group && {_group getVariable [QGVAR(isExecutingTactic), false]} && {time < _bitis}} do {
        sleep 8;
        if (({alive _x} count _destek) isEqualTo 0 && {!_kayipLog}) then {
            _kayipLog = true;
            diag_log format ["[KANAT-BASKI] %1 | baski ekibi KAYIP (manevra suruyor, durdurulmaz)", groupId _group];
        };
        call _bastir;
    };

    // 4) kilitleri temizle (yalniz kendi koydugumuz: kalan sure <= 16 sn)
    {
        if (alive _x && {((_x getVariable [QGVAR(taktikKilit), 0]) - time) <= 16}) then { _x setVariable [QGVAR(taktikKilit), nil]; };
    } forEach _destek;
    diag_log format ["[KANAT-BASKI] %1 | BITTI: %2 sn", groupId _group, round (time - _t0)];
};
true
