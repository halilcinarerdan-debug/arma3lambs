#include "script_component.hpp"
/*
 * Author: Cinar (ELITE fork)
 * CEPHE FIZIKLE (v8.237, Dilim A0) — SANAL (L0) profili FIZIKSEL (L1) yapar: grup + askerler yaratilir, saklanan durum (loadout, yara, ACE tibbi, susuzluk / acllik,
 * formasyon / davranis, hedef) geri yuklenir. Yalniz sunucuda. Ayni profil zaten L1 ise hicbir sey yapmaz.
 * Yerlestirme: profil konumu etrafinda yan yana dizilir (1.6 m aralik, yon = profil yonu), su uzerine denk gelirse konuma konur.
 * Grup yan etkisi: yeni grup LAMBS / ELITE katmanlari tarafindan normal AI grubu olarak alinir (config fsmDanger + izleyiciler); grup 'lambs_danger_cepheProfilId' ile isaretlenir.
 * Log: [CEPHE-FIZIKLE]
 *
 * Arguments:
 * 0: Profil <HASHMAP>
 * 1: Neden (log) <STRING> (default: "?")
 *
 * Return Value: Fiziksel yapildi mi <BOOL>
 * Public: No
*/

params [["_p", createHashMap, [createHashMap]], ["_neden", "?", [""]]];

if (!isServer || {count _p == 0} || {(_p get "seviye") isEqualTo "L1"}) exitWith {false};

private _id = _p get "id";
private _uyeler = _p get "uyeler";
private _konum = _p get "konum";
private _yon = _p getOrDefault ["yon", 0];
private _grp = createGroup [_p get "taraf", true];
private _birimler = [];
private _sira = 0;
private _aceVar = !isNil "ace_medical_fnc_deserializeState";
private _beceri = _p getOrDefault ["beceri", -1];
if (_beceri >= 0 && {_p getOrDefault ["bitkin", false]}) then { _beceri = _beceri * 0.85; };

{
    private _m = _x;
    if (!(_m get "canli")) then {
        _birimler pushBack objNull;
    } else {
        private _poz = _konum getPos [1.6 * _sira, _yon + 90];
        _sira = _sira + 1;
        if (surfaceIsWater _poz) then { _poz = +_konum; };
        _poz resize 3;
        _poz set [2, 0];
        private _u = _grp createUnit [_m get "sinif", _poz, [], 0, "NONE"];
        if (isNull _u) then {
            _m set ["canli", false];
            _birimler pushBack objNull;
            ["HATA", format ["%1 | %2 olusturulamadi (createUnit bos dondu)", _id, _m get "sinif"]] call FUNC(cepheLog);
        } else {
            _u setDir _yon;
            if ((_m getOrDefault ["loadout", []]) isNotEqualTo []) then { _u setUnitLoadout (_m get "loadout"); };
            private _ace = _m getOrDefault ["ace", ""];
            if (_aceVar && {_ace isNotEqualTo ""}) then {
                [_u, _ace] call ace_medical_fnc_deserializeState;
            } else {
                private _h = _m getOrDefault ["hasar", []];
                if ((count _h) >= 3) then { { _u setHitIndex [_forEachIndex, _x]; } forEach (_h select 2); };
            };
            if (_beceri >= 0) then { _u setSkill _beceri; };
            private _su = _m getOrDefault ["su", -1];
            private _ac = _m getOrDefault ["ac", -1];
            if (_su >= 0) then { _u setVariable ["lambs_danger_susuzluk", _su]; };
            if (_ac >= 0) then { _u setVariable ["lambs_danger_acllik", _ac]; };
            _u setVariable ["lambs_danger_cepheProfilId", _id];
            _birimler pushBack _u;
        };
    };
} forEach _uyeler;

private _canli = _birimler select {!isNull _x};
if (_canli isEqualTo []) exitWith {
    deleteGroup _grp;
    _p set ["yok", true];
    false
};

_grp selectLeader (_canli select 0);
_grp setFormation (_p getOrDefault ["formasyon", "WEDGE"]);
_grp setBehaviour (_p getOrDefault ["davranis", "AWARE"]);
_grp setCombatMode (_p getOrDefault ["savasModu", "YELLOW"]);
_grp setSpeedMode (_p getOrDefault ["hizModu", "NORMAL"]);
_grp setVariable ["lambs_danger_cepheProfilId", _id];
_grp setGroupIdGlobal [_p get "ad"];

private _hedef = _p getOrDefault ["hedef", []];
if (_hedef isNotEqualTo []) then {
    private _wp = _grp addWaypoint [_hedef, 0];
    _wp setWaypointType "MOVE";
    _wp setWaypointCompletionRadius 25;
};

_p set ["birimler", _birimler];
_p set ["grup", _grp];
_p set ["seviye", "L1"];
_p set ["tFizik", time];
_p set ["tSon", time];
_p set ["tetik", _neden];
["FIZIKLE", format ["%1 (%2) | %3 asker | %4 | konum %5", _p get "ad", _id, count _canli, _neden, mapGridPosition _konum]] call FUNC(cepheLog);
true
