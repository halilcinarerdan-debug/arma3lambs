#include "script_component.hpp"
/*
 * Author: Cinar (ELITE fork)
 * SILAH GUCU (v8.541; kullanici: 'silah kalitesi ekle': VC bolt-action / SKS / eski silahlar karsisinda M16 (otomatik) ile ates hacmi cok farkli; komutan guc orani sadece sayi + rol sayiyordu).
 * Bir askerin BIRINCIL silahinin ates gucu carpani (1.0 = tipik modern otomatik tufek). config'ten okunur, silah sinifina gore onbellekli:
 *   - otomatik ates modu (modes[] icinde autoFire = 1) var mi: var 1.0, yok (yari otomatik / bolt / pompali) 0.65
 *   - sarjor kapasitesi (compatible magazines icinde en buyuk count): carpan 0.55 + 0.45 x min(kapasite, 30) / 30   (5 mermi = 0.625, 10 = 0.70, 20 = 0.85, 30+ = 1.0)
 *   - sonuc / 0.9 (M16 / AK sinifi ~0.95-1.1), [0.4, 1.3] ile sinirli; birincil silah yoksa (yalniz tabanca / hic) 0.3
 *   ornek (tahmin): Mosin bolt-action 5 mermi ~0.45 | SKS 10 mermi yari-otomatik ~0.5 | M16 20 mermi otomatik ~0.94 | AK 30 mermi otomatik ~1.1 | MG 100+ otomatik ~1.1 (MG rol agirligi ayri)
 * HILE YOK: silah gorunur; ancak sayilar tasarim degeri (balistik / hasar / menzil sayilmaz, yalniz ates hacmi). Kapatma: CBA silahGucu = false (carpan 1).  Log: [SILAH-GUCU] (ilk 20 farkli silah).
 *
 * Arguments:
 * 0: Asker <OBJECT>
 *
 * Return Value: Ates gucu carpani <NUMBER>
 *
 * Public: No
*/

params [["_u", objNull, [objNull]]];
if (isNull _u || {!(missionNamespace getVariable ["lambs_danger_silahGucu", true])}) exitWith {1};
private _w = primaryWeapon _u;
if (_w isEqualTo "") exitWith {0.3};
private _oc = missionNamespace getVariable ["lambs_danger_silahGucuOnbellek", createHashMap];
missionNamespace setVariable ["lambs_danger_silahGucuOnbellek", _oc];
private _o = _oc get _w;
if (!isNil "_o") exitWith {_o};

private _cfg = configFile >> "CfgWeapons" >> _w;
private _auto = false;
{
    private _m = _cfg >> _x;
    if (isClass _m && {(getNumber (_m >> "autoFire")) > 0}) exitWith { _auto = true; };
} forEach (getArray (_cfg >> "modes"));
private _kap = 0;
{
    private _c = getNumber (configFile >> "CfgMagazines" >> _x >> "count");
    if (_c > _kap) then { _kap = _c; };
} forEach (getArray (_cfg >> "magazines"));
if (_kap <= 0) then { _kap = 20; };
private _q = (([0.65, 1] select _auto) * (0.55 + (0.45 * ((_kap min 30) / 30)))) / 0.9;
_q = (_q max 0.4) min 1.3;
_oc set [_w, _q];
if (isNil "lambs_danger_silahGucuLogN") then { lambs_danger_silahGucuLogN = 0; };
if (lambs_danger_silahGucuLogN < 20) then {
    lambs_danger_silahGucuLogN = lambs_danger_silahGucuLogN + 1;
    diag_log format ["[SILAH-GUCU] %1 | otomatik ates:%2 | sarjor:%3 | guc carpani %4", _w, _auto, _kap, _q toFixed 2];
};
_q
