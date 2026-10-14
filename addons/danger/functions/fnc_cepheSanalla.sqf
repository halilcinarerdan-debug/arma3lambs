#include "script_component.hpp"
/*
 * Author: Cinar (ELITE fork)
 * CEPHE SANALLA (v8.237, Dilim A0) — FIZIKSEL (L1) profili SANAL (L0) yapar: her canli askerin durumu profile yazilir (loadout, yara, ACE tibbi, susuzluk / acllik),
 * grubun formasyon / davranis / savas / hiz modu saklanir, sonra askerler ve bos grup silinir. Olu asker 'canli = false' olarak kalir (CASREP / takviye ihtiyaci).
 * Sanallamadan once cagiran KILIT kosullarini (temas, plan, oyuncu, arac, baygin) kontrol etmelidir; bu fonksiyon yalniz zorla sanallar (kilitli profile dokunmaz: 'kilit' true ise reddeder).
 * Gruptaki baska profile ait / profilsiz birimlere dokunmaz (yetimKatil gibi birlesmeler): yalniz bu profilin kendi birimleri silinir.
 * Log: [CEPHE-SANALLA]
 *
 * Arguments:
 * 0: Profil <HASHMAP>
 * 1: Neden (log) <STRING> (default: "?")
 *
 * Return Value: Sanallandi mi <BOOL>
 * Public: No
*/

params [["_p", createHashMap, [createHashMap]], ["_neden", "?", [""]]];

if (!isServer || {count _p == 0} || {(_p get "seviye") isNotEqualTo "L1"} || {_p getOrDefault ["kilit", false]}) exitWith {false};

private _uyeler = _p get "uyeler";
private _birimler = _p get "birimler";
private _aceVar = !isNil "ace_medical_fnc_serializeState";
private _grp = _p getOrDefault ["grup", grpNull];
private _liderPoz = [];
private _liderYon = _p getOrDefault ["yon", 0];
private _canliSay = 0;

{
    private _u = _x;
    private _m = _uyeler select _forEachIndex;
    if (_m get "canli") then {
        if (isNull _u || {!alive _u}) then {
            _m set ["canli", false];
        } else {
            _m set ["loadout", getUnitLoadout _u];
            _m set ["hasar", getAllHitPointsDamage _u];
            if (_aceVar) then { _m set ["ace", [_u] call ace_medical_fnc_serializeState]; };
            private _su = _u getVariable ["lambs_danger_susuzluk", -1];
            private _ac = _u getVariable ["lambs_danger_acllik", -1];
            if (_su >= 0) then { _m set ["su", _su]; };
            if (_ac >= 0) then { _m set ["ac", _ac]; };
            if (_liderPoz isEqualTo []) then { _liderPoz = getPosATL _u; _liderYon = getDir _u; };
            _canliSay = _canliSay + 1;
        };
    };
} forEach _birimler;

if (!isNull _grp && {!isNull (leader _grp)}) then {
    _p set ["formasyon", formation _grp];
    _p set ["davranis", behaviour (leader _grp)];
    _p set ["savasModu", combatMode _grp];
    _p set ["hizModu", speedMode _grp];
};
if (_liderPoz isNotEqualTo []) then {
    _p set ["konum", _liderPoz];
    _p set ["yon", _liderYon];
};

{
    if (!isNull _x && {alive _x}) then { deleteVehicle _x; };   // olu bedenler yerinde kalir (cephede kayip izi)
} forEach _birimler;
if (!isNull _grp && {(count (units _grp)) isEqualTo 0}) then { deleteGroup _grp; };

_p set ["birimler", []];
_p set ["grup", grpNull];
_p set ["seviye", "L0"];
_p set ["tSanal", time];
if (_canliSay isEqualTo 0) then { _p set ["yok", true]; };
["SANALLA", format ["%1 (%2) | %3 canli / %4 | %5 | konum %6", _p get "ad", _p get "id", _canliSay, count _uyeler, _neden, mapGridPosition (_p get "konum")]] call FUNC(cepheLog);
true
