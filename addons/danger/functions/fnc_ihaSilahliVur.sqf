#include "script_component.hpp"
/*
 * Author: Cinar (ELITE fork)
 * SILAHLI IHA SALDIRI DONGUSU (v8.402; kullanici: 'dusman dronu araclara fuze yollamadi', 'dronlar asiri kolay vuruluyor'). fnc_ihaSorti GOZLEM devriyesindeki SILAHLI IHA (yere atabilen fuze / roket / bomba, bkz fnc_ihaSilah) icin
 *   paralel calisir: 4 sn'de bir BILINEN dusman hedef arar (zirhli arac > hafif arac > personel kumesi; hile yok: IHA'nin ya da IHA tarafinin herhangi grubunun bilgisi), 12 sn aralikla fuze atar.
 *   ATIS: once motorun kendi atisi (fireAtTarget; mühimmat azalirsa gercek atis sayilir); azalmazsa (AI IHA'lari tarama yapmadan atmaz) betikle ayni mermi sinifi hedefe yonlendirilir (setMissileTarget, sadece FUZE / roket).
 *   KORUMA: dost <= 40 m (danger close), sivil, yakin dostu olan kume, ilk 20 sn (kamera tespit suresi) hedef sayilmaz; bomba yalniz motorun kendi atisiyla (betik yonlendirmez).
 *   TEHDIT: IHA'ya fuze gelirse / vurulursa (IncomingMissile / Hit) irtifa +600 m (en cok 3000 m) cikar; yakin dusman AA (SPAAG / STATIK / MANPADS) bilinirse 2500 m yaricapindan kacinmak icin yine tirmanir.
 *   Kapatma: CBA 'ihaSilahliSaldiri'. Log: [IHA-SILAH]. UYARI: oyunda dogrulanmadi; mod silahlarinin (TMT TB2 vb.) atis davranisi bilinmiyor.
 *
 * Arguments:
 * 0: IHA <OBJECT>
 * 1: IHA tarafi <SIDE>
 * 2: Gorev merkezi <ARRAY>
 * 3: Menzil (merkezden, m) <NUMBER>
 * 4: Gorev belirteci (ihaTok) <NUMBER>
 * 5: Gorev suresi (sn) <NUMBER>
 * 6: Taban irtifa (m; tehdit tirmanisi bunun uzerine eklenir) <NUMBER>
 *
 * Return Value: None
 * Public: No
*/

params [["_uav", objNull, [objNull]], ["_taraf", west, [west]], ["_merkez", [0, 0, 0], [[]]], ["_men", 3000, [0]], ["_tok", -1, [0]], ["_sureS", 1200, [0]], ["_irtTaban", 1200, [0]]];
if (isNull _uav) exitWith {};
private _t0 = time;
private _aktif = { alive _uav && {!isNull (driver _uav)} && {alive (driver _uav)} && {(_uav getVariable [QGVAR(ihaTok), -1]) isEqualTo _tok} && {(time - _t0) < _sureS} };

private _sonAtis = time + 20;
private _logT = -999;
private _atisSay = 0;
private _irt = _irtTaban;
private _tehditT = -999;
private _gorusM = missionNamespace getVariable ["lambs_danger_ihaGorusMenzil", 2500];

// vurulma / fuze tehdidi -> tirman
_uav setVariable [QGVAR(ihaTehditT), -999];
if !(_uav getVariable [QGVAR(ihaTehditEH), false]) then {
    _uav setVariable [QGVAR(ihaTehditEH), true];
    _uav addEventHandler ["IncomingMissile", { params ["_u"]; _u setVariable [QGVAR(ihaTehditT), time]; }];
    _uav addEventHandler ["Hit", { params ["_u"]; _u setVariable [QGVAR(ihaTehditT), time]; }];
};

while {call _aktif} do {
    sleep 4;
    if (!alive _uav) exitWith {};

    // ---- tehdit: tirman ----
    private _tehdit = (time - (_uav getVariable [QGVAR(ihaTehditT), -999])) < 20;
    private _aa = [];
    if (!_tehdit) then {
        _aa = (_uav nearEntities [["LandVehicle", "StaticWeapon"], 2500]) select {
            private _o = _x;
            alive _o && {!isNull (effectiveCommander _o)} && {(_taraf getFriend (side (group (effectiveCommander _o)))) < 0.6} && {([_o] call FUNC(aaSinif)) in ["SPAAG", "STATIK"]}
            && {((allGroups select {(side _x) isEqualTo _taraf && {!isNull leader _x}}) findIf {_x knowsAbout _o >= (['ISARET'] call FUNC(bilgiEsik))}) >= 0}
        };
    };
    if (_tehdit || {_aa isNotEqualTo []}) then {
        private _yeni = (_irtTaban + 600) min 3000;
        if (_yeni > _irt && {(time - _tehditT) > 10}) then {
            _tehditT = time;
            _irt = _yeni;
            _uav flyInHeight _irt;
            diag_log format ["[IHA-SILAH] %1 | TEHDIT (%2) -> irtifa %3 m'ye cikiyor", typeOf _uav, ["yakin dusman AA", "fuze / isabet"] select _tehdit, round _irt];
        };
    } else {
        if (_irt > _irtTaban && {(time - _tehditT) > 90}) then { _irt = _irtTaban; _uav flyInHeight _irt; };
    };

    if (time < _sonAtis) then { continue };
    private _silah = [_uav] call FUNC(ihaSilah);
    if (_silah isEqualTo []) then {
        if ((time - _logT) > 60) then { _logT = time; diag_log format ["[IHA-SILAH] %1 | yere atabilecek mühimmat yok (hepsi bitti ya da silahsiz): atis yok", typeOf _uav]; };
        continue;
    };

    // ---- hedef: zirhli arac > arac > personel kumesi (bilinen, gorulebilir, dost yakin degil) ----
    private _bilinen = {
        params ["_t"];
        ((_uav knowsAbout _t) >= (["SEZILDI"] call FUNC(bilgiEsik))) || {((allGroups select {(side _x) isEqualTo _taraf && {!isNull leader _x}}) findIf {_x knowsAbout _t >= (["SUPHE"] call FUNC(bilgiEsik))}) >= 0}
    };
    private _en = objNull;
    private _enS = -1e9;
    {
        private _t = _x;
        private _arac = !(_t isKindOf "CAManBase");
        private _o = if (_arac) then {effectiveCommander _t} else {_t};
        if (!alive _t || {isNull _o} || {!alive _o} || {(_taraf getFriend (side (group _o))) >= 0.6} || {(side (group _o)) isEqualTo civilian}) then { continue };
        if (_arac && {!(_t isKindOf "LandVehicle")}) then { continue };
        if (!_arac && {!isNull objectParent _t}) then { continue };
        if ((_t distance2D _merkez) > _men || {(_t distance2D _uav) > (_gorusM * ([_uav, _t] call FUNC(ihaGorus)) * 1.6)}) then { continue };
        if !([_t] call _bilinen) then { continue };
        // danger close: dost <= 40 m
        if (((_t nearEntities [["CAManBase", "LandVehicle"], 40]) findIf {alive _x && {_x isNotEqualTo _t} && {(_taraf getFriend (side (group (effectiveCommander _x)))) >= 0.6}}) >= 0) then { continue };
        private _kume = if (_arac) then {0} else {{alive _x && {(_taraf getFriend (side _x)) < 0.6} && {(side _x) isNotEqualTo civilian}} count (_t nearEntities ["CAManBase", 15])};
        private _s = if (_arac) then { 1000 + (getNumber (configOf _t >> "armor")) } else { _kume * 80 };
        _s = _s - (_t distance2D _uav) * 0.05;
        if (!_arac && {_kume < 3}) then { _s = _s - 400; };   // tek tuk piyadeye fuze israf edilmez (yalnizca baska hedef yoksa)
        if (_s > _enS) then { _enS = _s; _en = _t; };
    } forEach ((vehicles select {alive _x && {_x isKindOf "LandVehicle"} && {!isNull (driver _x)}}) + (allUnits select {alive _x && {isNull objectParent _x} && {(_taraf getFriend (side _x)) < 0.6}}));
    if (isNull _en || {_enS < -300}) then { continue };

    // ---- atis ----
    private _sec = _silah select 0;
    private _hedefArac = !(_en isKindOf "CAManBase");
    // zirhli hedefe fuze, personele bomba / roket tercih (varsa)
    private _tercih = _silah select {(_x select 4) isEqualTo (["BOMBA", "FUZE"] select (_hedefArac || {(count (_silah select {(_x select 4) isEqualTo "BOMBA"})) isEqualTo 0}))};
    if (_tercih isNotEqualTo []) then { _sec = _tercih select 0; };
    _sec params ["_w", "_tp", "_mag", "_ammo", "_tur"];
    private _once = _uav ammo _w;
    private _usr = _uav turretUnit _tp;
    if (isNull _usr) then { _usr = driver _uav; };
    _uav reveal [_en, 4];
    _usr doTarget _en;
    _usr doWatch _en;
    _uav selectWeaponTurret [_w, _tp];
    private _ok = _usr fireAtTarget [_en, _w];
    sleep 2.5;
    private _sonra = _uav ammo _w;
    private _gercek = _sonra < _once;
    if (!_gercek && {_tur isEqualTo "FUZE"} && {alive _uav} && {alive _en}) then {
        // betikle ayni mermi: IHA'nin onunden, hedefe yonlenir (AI IHA fireAtTarget'i kabul etmediyse)
        private _bp = _uav modelToWorld [0, 3, -1.5];
        private _hp = (getPosASL _en) vectorAdd [0, 0, 1.2];
        private _dir = (_hp vectorDiff (AGLToASL _bp));
        private _mg = vectorMagnitude _dir;
        if (_mg > 5) then {
            _dir = _dir vectorMultiply (1 / _mg);
            private _m = createVehicle [_ammo, _bp, [], 0, "CAN_COLLIDE"];
            _m setVectorDirAndUp [_dir, [0, 0, 1]];
            _m setVelocity (_dir vectorMultiply 140);
            _m setMissileTarget [_en, true];
            _m setShotParents [_uav, driver _uav];
            _uav setAmmo [_w, (_sonra - 1) max 0];
            _gercek = true;
            diag_log format ["[IHA-SILAH] %1 | motor atis yapmadi (fireAtTarget %2, mühimmat %3 -> %4): BETIKLE %5 yonlendirildi", typeOf _uav, _ok, _once, _sonra, _ammo];
        };
    };
    if (_gercek) then {
        _atisSay = _atisSay + 1;
        _sonAtis = time + 12;
        diag_log format ["[IHA-SILAH] %1 | ATIS #%2 | %3 (%4) -> %5 %6 | mesafe %7 m | irtifa %8 m | kalan %9", typeOf _uav, _atisSay, _w, _tur, typeOf _en, mapGridPosition _en, round (_uav distance2D _en), round ((getPosATL _uav) select 2), _uav ammo _w];
    } else {
        _sonAtis = time + 20;
        if ((time - _logT) > 30) then { _logT = time; diag_log format ["[IHA-SILAH] %1 | ATIS YAPILAMADI: silah %2 (%3) hedef %4 | fireAtTarget %5 | mühimmat %6", typeOf _uav, _w, _tur, typeOf _en, _ok, _sonra]; };
    };
};
