#include "script_component.hpp"
/*
 * Author: Cinar (ELITE fork)
 * GIRIS BOMBASI (v8.599; kullanici: 'el bombasi patlamadi, el bombasi ile giris yok, kapida yigilma var'; RPT 82df5647: saldiri modunda yigilma oldu ama patlayici izleyicisi bombayi atamadi:
 *   yay hedefin binasina / kapiya takildi (2/8), dost yaricapi (dost 17-33) ve donme siniri yuzunden; kapi kapaliydi).
 * Fnc_buildingClearRun SALDIRI modunda, kapi yigilmasindan sonra cagirir: giris takimindan (yoksa grubun) frag tasiyan ilk asker
 *   1) kapiyi AC (fnc_kapiAc), kapinin 2.6 m ONUNE (kapi ekseninde) gecer, 2) iceri hedef noktaya (kapidan 4-10 m, kapi ekseninde, ayni kat; yoksa 6 m ic) DUZ yayla (aci 12 / 18 / 25 / 33 / 42 / 52, hiz <= 24 m/sn) bomba atar:
 *   her aday GEOM yay kontrolu (ilk segment atlanir), ilk TEMIZ yay atilir. Dost guvenligi: hedef noktanin 8 m icinde dost varsa atilmaz. Atilinca QGVAR(bombaGT) yazilir (buildingClearRun ~3.5 sn fitil sonrasi girer).
 * Kapatma: CBA lambs_danger_binaGirisBomba. Log: [GIRIS-BOMBASI] (ilk 20).
 *
 * Arguments:
 * 0: Grup <GROUP>
 * 1: Aday aticilar (giris takimi once) <ARRAY>
 * 2: Bina <OBJECT>
 * 3: Kapi noktasi (AGL) <ARRAY>
 * 4: Kapinin disa bakan yonu (derece) <NUMBER>
 * 5: Bina pozisyonlari (buildingPos, AGL) <ARRAY>
 *
 * Return Value: Atildi mi <BOOL>
 * Public: No
*/

params [["_g", grpNull, [grpNull]], ["_adaylar", [], [[]]], ["_b", objNull, [objNull]], ["_kapiPos", [], [[]]], ["_disYon", 0, [0]], ["_poslar", [], [[]]]];
if (isNull _g || {isNull _b} || {_kapiPos isEqualTo []} || {!(missionNamespace getVariable ["lambs_danger_binaGirisBomba", true])}) exitWith {false};

private _fragMi = {
    params ["_m"];
    private _k = toLower _m;
    private _a = getText (configFile >> "CfgMagazines" >> _m >> "ammo");
    (toLower (getText (configFile >> "CfgAmmo" >> _a >> "simulation"))) isEqualTo "shotgrenade"
    && {(_k find "smoke") < 0} && {(_k find "flare") < 0} && {(_k find "chem") < 0} && {(_k find "illum") < 0} && {(_k find "flash") < 0} && {(_k find "stun") < 0} && {(_k find "m84") < 0}
};
private _atan = objNull;
private _mag = "";
{
    if (!isNull _atan) then { continue };
    private _u = _x;
    if (alive _u && {isNull objectParent _u} && {(lifeState _u) in ["HEALTHY", "INJURED"]}) then {
        private _fr = (magazines _u) select {[_x] call _fragMi};
        if (_fr isNotEqualTo []) then { _atan = _u; _mag = _fr select 0; };
    };
} forEach _adaylar;
if (isNull _atan) exitWith { diag_log format ["[GIRIS-BOMBASI] %1 | frag tasiyan asker yok", groupId _g]; false };

private _ammo = getText (configFile >> "CfgMagazines" >> _mag >> "ammo");
private _icYon = _disYon + 180;
private _ic = _kapiPos getPos [6, _icYon];
private _kand = _poslar select {(_x select 2) < 2.4 && {(_x distance2D _kapiPos) >= 4} && {(_x distance2D _kapiPos) <= 10} && {(abs ((((_kapiPos getDir _x) - _icYon) + 540) mod 360 - 180)) < 45}};
if (_kand isNotEqualTo []) then {
    _kand = [_kand, [], {_x distance2D _kapiPos}, "ASCEND"] call BIS_fnc_sortBy;
    _ic = _kand select 0;
};
if (((_ic nearEntities ["CAManBase", 8]) findIf {alive _x && {((side _g) getFriend (side (group _x))) >= 0.6}}) >= 0) exitWith {
    diag_log format ["[GIRIS-BOMBASI] %1 | iceride dost var (8 m) - atilmadi", groupId _g]; false
};

private _acilan = [_b, _atan, 6] call FUNC(kapiAc);
private _atisPoz = _kapiPos getPos [2.6, _disYon];
_atan setUnitPos "UP";
_atan doMove _atisPoz;
private _bit = time + 6;
waitUntil { sleep 0.3; (time > _bit) || {(_atan distance2D _atisPoz) < 1.5} || {!alive _atan} };
if (!alive _atan) exitWith { false };
_atan doWatch _ic;
sleep 0.5;
if (!alive _atan || {((magazines _atan) findIf {_x isEqualTo _mag}) < 0}) exitWith { false };   // v8.611: ThrowGrenade animasyonu yay temizlendikten SONRA (asagida)

private _rel = (eyePos _atan) vectorAdd [0, 0, -0.1];
private _hedef = AGLToASL (_ic vectorAdd [0, 0, 0.3]);
private _D = sqrt ((((_rel select 0) - (_hedef select 0)) ^ 2) + (((_rel select 1) - (_hedef select 1)) ^ 2));
private _dh = (_hedef select 2) - (_rel select 2);
private _yon = _rel getDir _hedef;
private _v = -1;
private _th = 0;
private _vel = [];
private _engelAd = "";
{
    if (_v >= 0) then { continue };
    private _a = _x;
    private _payda = (_D * (tan _a)) - _dh;
    if (_payda > 0.3) then {
        private _vv = sqrt ((9.81 * _D * _D) / (2 * ((cos _a) ^ 2) * _payda));
        if (_vv <= 24) then {
            private _vl = [(sin _yon) * (cos _a) * _vv, (cos _yon) * (cos _a) * _vv, (sin _a) * _vv];
            private _tTop = _D / ((cos _a) * _vv max 1);
            private _onceki = _rel;
            private _engel = false;
            for "_i" from 1 to 8 do {
                private _tt = _tTop * (_i / 8);
                private _nokta = _rel vectorAdd [(_vl select 0) * _tt, (_vl select 1) * _tt, ((_vl select 2) * _tt) - (4.905 * _tt * _tt)];
                private _ht = if (_i >= 2) then { lineIntersectsSurfaces [_onceki, _nokta, _atan, objNull, true, 1, "GEOM", "NONE"] } else { [] };
                if (_ht isNotEqualTo []) exitWith {
                    _engel = true;
                    private _eo = (_ht select 0) select 2;
                    if (_engelAd isEqualTo "") then { _engelAd = if (isNull _eo) then {"arazi / nesne"} else { [typeOf _eo, (getModelInfo _eo) select 0] select ((typeOf _eo) isEqualTo "") }; };
                };
                _onceki = _nokta;
            };
            if (!_engel) then { _v = _vv; _th = _a; _vel = _vl; };
        };
    };
} forEach [12, 18, 25, 33, 42, 52];

private _sonuc = "";
if (_v < 0) then {
    _sonuc = format ["yay engelli (%1)", _engelAd];
    // v8.613 HILE (kullanici: 'evin icine tuttursun, hileye basvurabilirsin'): fiziksel yay yoksa animasyon + ucus suresi sonra bomba ic hedef noktaya (_ic) dogrudan yaratilir (sifir hiz, fitil yanar)
    if (missionNamespace getVariable ["lambs_danger_bombaHile", true]) then {
        _atan playActionNow "ThrowGrenade";
        sleep 0.8;
        if (!alive _atan || {((magazines _atan) findIf {_x isEqualTo _mag}) < 0}) then { _sonuc = "atici oldu / bomba kayboldu (hile: animasyon sirasinda)"; } else {
            sleep ((_D / 14) min 1.6);
            private _hp2 = AGLToASL (_ic vectorAdd [0, 0, 0.3]);
            private _gr = createVehicle [_ammo, ASLToAGL _hp2, [], 0, "CAN_COLLIDE"];
            _gr setPosASL _hp2;
            _gr setVelocity [0, 0, 0];
            _gr setShotParents [_atan, _atan];
            _atan removeMagazine _mag;
            _g setVariable [QGVAR(bombaGT), time];
            _v = 0;
            _sonuc = format ["ATILDI (HILE: yay engelli, bomba ic hedefe yaratildi; kapidan %1 m)", round (_ic distance2D _kapiPos)];
        };
    };
} else {
    _atan playActionNow "ThrowGrenade";
    sleep 0.8;
    if (!alive _atan || {((magazines _atan) findIf {_x isEqualTo _mag}) < 0}) then { _sonuc = "atici oldu / bomba kayboldu (animasyon sirasinda)"; _v = -1; } else {
        private _gr = createVehicle [_ammo, ASLToAGL _rel, [], 0, "CAN_COLLIDE"];
        _gr setPosASL _rel;
        _gr setVelocity _vel;
        _gr setShotParents [_atan, _atan];
        _atan removeMagazine _mag;
        _g setVariable [QGVAR(bombaGT), time];
        _sonuc = format ["ATILDI (kapidan %1 m iceri, aci %2, hiz %3 m/sn)", round (_ic distance2D _kapiPos), _th, _v toFixed 1];
    };
};
if ((missionNamespace getVariable ["lambs_danger_girisBombaLogN", 0]) < 20) then {
    missionNamespace setVariable ["lambs_danger_girisBombaLogN", (missionNamespace getVariable ["lambs_danger_girisBombaLogN", 0]) + 1];
    diag_log format ["[GIRIS-BOMBASI] %1 | %2 | bina %3 | %4 | kapi acilan %5 | disari yon %6 | atis noktasi kapidan %7 m (atici varis %8 m) | ic hedef %9 m", groupId _g, name _atan, typeOf _b, _sonuc, _acilan, round _disYon, 2.6, round (_atan distance2D _atisPoz), round (_ic distance2D _kapiPos)];
};
_v >= 0
