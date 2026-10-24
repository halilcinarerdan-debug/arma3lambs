#include "script_component.hpp"
/*
 * Author: Cinar (ELITE fork)
 * ZIRH ATGM / FUZE UYARISI (v8.349; kullanici: 'ATGM uyarisi / temas ustunde duman'). Tank / IFV / APC'ye 'IncomingMissile' olay isleyicisi (fnc_zirhDronIzle her zirhli araca bir kez ekler): araca YONELMIS gudumlu fuze (ATGM, helikopter / UAV / uzaktan
 * atilan fuze, oyuncu atisi dahil) ates edildigi anda calisir — fnc_atAtisIzle yalniz AI'nin Fired olayini izler, oyuncu / hava / gudumlu kilit atislarini kacirir.
 *   1) fnc_aracAtTepki (temas isareti, karsi ates, DUMAN, korunakli konuma yer degistirme, yakin piyade korumasi) — 25 sn arac kilidi var, AI atesi icin atAtisIzle zaten tetiklemisse tekrar calismaz.
 *   2) UYARI PAYLASIMI: 500 m icindeki dost, yerel, oyuncusuz zirhli araclarin gruplari atici konumunu 1.2 ile ogrenir (reveal), temas isareti alir, nisancilar atici yonune bakar (fuze bir tanka atildiysa komsu tank da atici yonunu bilir).
 * Kitap: ATP 3-20.15 3-81..3-98 (temasta eylemler: bildir, karsi ates, duman, korunakli konuma yer degistir) + 3-136 (duman); uyari paylasimi bu 'bildir' adimidir [K]. 500 m [T]. TEST EDILMEDI (IncomingMissile yerellik: arac baska makineye gecerse olay isleyici yeniden eklenir mi, dogrulanmadi).
 * Kapatma: CBA zirhUyariAktif ya da lambs_danger_zirhUyariOff = true. Log: [ZIRH-UYARI] (ilk 40).
 *
 * Arguments (IncomingMissile olayi):
 * 0: Hedef arac <OBJECT>
 * 1: Mermi sinifi <STRING>
 * 2: Atan arac / birim <OBJECT>
 * 3: Atici <OBJECT>
 *
 * Return Value: Tepki verildi mi <BOOL>
 * Public: No
*/

params [["_hedef", objNull, [objNull]], ["_mermi", "", [""]], ["_atan", objNull, [objNull]], ["_kisi", objNull, [objNull]]];
if (missionNamespace getVariable ["lambs_danger_zirhUyariOff", false] || {!(missionNamespace getVariable ["lambs_danger_zirhUyariAktif", true])}) exitWith {false};
if (isNull _hedef || {!alive _hedef} || {!local _hedef}) exitWith {false};
private _hk = effectiveCommander _hedef;
if (isNull _hk || {!alive _hk} || {isPlayer _hk}) exitWith {false};
private _taraf = side (group _hk);
private _ak = if (!isNull _kisi && {alive _kisi}) then { _kisi } else { effectiveCommander _atan };
if (!isNull _ak && {(_taraf getFriend (side (group _ak))) >= 0.6}) exitWith {false};   // dost atesi / bos kilit: tepki yok

private _atici = if (!isNull _atan && {alive _atan}) then { _atan } else { _ak };
private _aPoz = if (isNull _atici) then { [] } else { getPosATL _atici };
private _tepki = [_hedef, _atici, "ROKET", _aPoz] call FUNC(aracAtTepki);

// uyari paylasimi
private _komsu = 0;
if (!isNull _ak) then {
    {
        private _kv = _x;
        private _kk = effectiveCommander _kv;
        if (_kv isNotEqualTo _hedef && {alive _kv} && {local _kv} && {!isNull _kk} && {!isPlayer _kk} && {(side (group _kk)) isEqualTo _taraf}) then {
            private _kg = group _kk;
            _kg reveal [_ak, 1.2];
            _kg setVariable [QGVAR(contact), ((time + 10) max (_kg getVariable [QGVAR(contact), 0]))];
            if (_aPoz isNotEqualTo []) then {
                private _bak = _aPoz getPos [random 20, random 360];
                { if (!isNull _x && {alive _x}) then { _x doWatch _bak; }; } forEach [gunner _kv, commander _kv];
            };
            _komsu = _komsu + 1;
        };
    } forEach ((_hedef nearEntities [["Tank", "Tracked_APC_F", "Wheeled_APC_F"], 500]) select {(crew _x) isNotEqualTo []});
};

if (isNil "lambs_danger_zirhUyariLogN") then { lambs_danger_zirhUyariLogN = 0; };
if (lambs_danger_zirhUyariLogN < 40) then {
    lambs_danger_zirhUyariLogN = lambs_danger_zirhUyariLogN + 1;
    diag_log format ["[ZIRH-UYARI] %1 (%2) <- gudumlu fuze %3 | atan %4 (%5 m) | arac tepkisi (duman / karsi ates / yer degistirme) %6 | uyarilan komsu zirhli arac %7",
        getText (configOf _hedef >> "displayName"), groupId (group _hk), _mermi, if (isNull _atici) then {"bilinmiyor"} else {typeOf _atici}, if (_aPoz isEqualTo []) then {"?"} else {round (_hedef distance2D _aPoz)}, _tepki, _komsu];
};
_tepki
