#include "script_component.hpp"
/*
 * Author: Cinar (ELITE fork)
 * TANI PAKETI (v8.255) — kullanici: "net bir tani icin loglamayi genislet, aklimizda soru isareti kalmasin". DAVRANIS DEGISTIRMEZ; yalniz olay aninda durum kaydeder. Her makinede bir kez kurulur (olay yalniz birim / arac o makinede yerelse tetiklenir).
 *   [TANI-TOPCU]  topcu mermisi (artilleryScanner > 0 bir aractan; duman / aydinlatma haric) dustugu nokta: atici, mermi, dusme grid, 40 m icindeki canli birimler taraf basina, hendek alanina mesafe (ilk 80)
 *   [OLUM-TANI]   her AI olumunde (oyuncu haric, ilk 300): taraf, grup, rol, durus + animasyon, grup hendekte mi, olum noktasinin hendek ALANINA mesafesi (<= 1.2 m = icinde), aracta mi, en yakin topcu dususu (|zaman farki| <= 3 s => TOPCU olasi; yoksa 60 sn icindeki en yakin),
 *                 oldurenin tipi / mesafesi. Eslesme 1.5 sn gecikmeyle yapilir (mermi dusus kaydi olumden sonra yazilir). Sonuc 'neden' bir ESTIRIM (kesin degil): topcu = dusus <= 35 m ve <= 3 s.
 *   [OLUM-OZET]   60 sn'de bir (degisim varsa): taraf basina toplam / hendek grubu / hendek icinde / hendek grubu ama hendek disinda / topcu olasi
 *   [ARAC-TERK]   kara aracindan murettebat (surucu / nisanci / komutan / taret; kargo haric) INDIGINDE: arac hasari, canMove, canFire, motor, yakit, hiz, yanma, hasarli parcalar (>= 0.25), son 5 parca hasari (zaman, parca, deger, atan, mermi), koltuk doluluk, birimin komutu / atamasi, grup temas yasi, en yakin dusman, ELITE bayraklari (tasimaMesgul, planZirh, tankManevraT, atTepkiT, zirhKacT yaslari) (ilk 150)
 *   [ARAC-BINDI]  tank sinifi araca murettebat BINDIGINDE (geri donus dogrulamasi) (ilk 100)
 * Kapatma: lambs_danger_taniOff = true. Okuma: python tools/rpt_ozet.py --tani <rpt>.
 *
 * Arguments: None
 * Return Value: Kuruldu mu <BOOL>
 * Public: No
*/

if (!isNil "lambs_danger_taniStarted") exitWith {false};
lambs_danger_taniStarted = true;
lambs_danger_taniVurus = [];
lambs_danger_taniOlumN = 0;
lambs_danger_taniOlumSay = createHashMap;
lambs_danger_taniTopcuLogN = 0;
lambs_danger_taniTerkN = 0;
lambs_danger_taniBindiN = 0;

diag_log "[TANI] tani paketi kuruldu (v8.255): [TANI-TOPCU] [OLUM-TANI] [OLUM-OZET] [ARAC-TERK] [ARAC-BINDI]";

// ---- 1) topcu mermisi dusme izleyici ----
[
    "LandVehicle",
    "Fired",
    {
        params ["_veh", "_weapon", "_muzzle", "_mode", "_ammo", "_mag", "_proj"];
        if (isNull _proj || {missionNamespace getVariable ["lambs_danger_taniOff", false]}) exitWith {};
        if (isNil "lambs_danger_taniTopcuTip") then { lambs_danger_taniTopcuTip = createHashMap; };
        private _tip = typeOf _veh;
        private _tp = lambs_danger_taniTopcuTip getOrDefault [_tip, -1];
        if (_tp isEqualTo -1) then {
            _tp = [0, 1] select ((getNumber (configOf _veh >> "artilleryScanner")) > 0);
            lambs_danger_taniTopcuTip set [_tip, _tp];
        };
        if (_tp isEqualTo 0) exitWith {};
        private _sim = toLower (getText (configFile >> "CfgAmmo" >> _ammo >> "simulation"));
        if ((_sim find "smoke") >= 0 || {(_sim find "illum") >= 0} || {(_sim find "flare") >= 0}) exitWith {};
        private _kmt = effectiveCommander _veh;
        [_proj, _ammo, [side (group _kmt), sideUnknown] select (isNull _kmt), getText (configOf _veh >> "displayName")] spawn {
            params ["_p", "_ammo", "_taraf", "_ad"];
            private _pos = getPosATL _p;
            while {!isNull _p} do { _pos = getPosATL _p; sleep 0.1; };
            lambs_danger_taniVurus pushBack [time, _pos, _ammo, _taraf];
            if ((count lambs_danger_taniVurus) > 200) then { lambs_danger_taniVurus deleteAt 0; };
            if (lambs_danger_taniTopcuLogN < 80) then {
                lambs_danger_taniTopcuLogN = lambs_danger_taniTopcuLogN + 1;
                private _yak = (_pos nearEntities [["CAManBase"], 40]) select {alive _x};
                private _hd = ["EN-YAKIN", _pos, 40, sideUnknown] call lambs_danger_fnc_hendekAlani;
                diag_log format ["[TANI-TOPCU] atici=%1 | taraf=%2 | mermi=%3 | dusme=%4 | 40m_icinde: WEST=%5 EAST=%6 GUER=%7 | hendek_alani_mesafe=%8", _ad, _taraf, _ammo, mapGridPosition _pos,
                    {(side (group _x)) isEqualTo west} count _yak, {(side (group _x)) isEqualTo east} count _yak, {(side (group _x)) isEqualTo independent} count _yak,
                    if (_hd isEqualTo []) then {"yok(>40m)"} else {round (_hd select 2)}];
            };
        };
    },
    true,
    [],
    true
] call CBA_fnc_addClassEventHandler;

// ---- 2) olum tanisi ----
[
    "CAManBase",
    "Killed",
    {
        params ["_u", "_killer", "_instigator"];
        if (missionNamespace getVariable ["lambs_danger_taniOff", false] || {isPlayer _u}) exitWith {};
        lambs_danger_taniOlumN = lambs_danger_taniOlumN + 1;
        private _g = group _u;
        private _taraf = [side _g, sideUnknown] select (isNull _g);
        private _pos = getPosATL _u;
        private _hn = ["EN-YAKIN", _pos, 60, _taraf] call lambs_danger_fnc_hendekAlani;
        private _hdD = [(_hn select 2), -1] select (_hn isEqualTo []);
        private _bilgi = createHashMapFromArray [
            ["t", time], ["taraf", _taraf], ["grup", [groupId _g, "?"] select (isNull _g)], ["rol", [_u] call (missionNamespace getVariable ["lambs_danger_fnc_getUnitRole", {"?"}])],
            ["durus", stance _u], ["anim", animationState _u], ["pos", _pos], ["hdD", _hdD],
            ["hendekGrup", !isNull _g && {_g getVariable ["lambs_danger_hendekte", false]}],
            ["aracta", [typeOf (objectParent _u), "-"] select (isNull objectParent _u)],
            ["oldurenTip", [typeOf (if (!isNull _instigator) then {_instigator} else {_killer}), "-"] select (isNull _instigator && {isNull _killer})],
            ["oldurenMes", [round (_pos distance2D (if (!isNull _instigator) then {_instigator} else {_killer})), -1] select (isNull _instigator && {isNull _killer})],
            ["ad", name _u]
        ];
        [{
            params ["_b"];
            private _t0 = _b get "t";
            private _pos = _b get "pos";
            // en yakin topcu dususu: |zaman farki| <= 3 sn; yoksa 60 sn icindeki en yakin
            private _enD = 1e9; private _enZ = 0; private _enM = "-"; private _eslesen = false;
            {
                _x params ["_ti", "_ip", "_mm"];
                private _dz = _ti - _t0;
                private _d = _ip distance2D _pos;
                if ((abs _dz) <= 3) then {
                    if (!_eslesen || {_d < _enD}) then { _eslesen = true; _enD = _d; _enZ = _dz; _enM = _mm; };
                } else {
                    if (!_eslesen && {_dz < 0} && {_dz >= -60} && {_d < _enD}) then { _enD = _d; _enZ = _dz; _enM = _mm; };
                };
            } forEach lambs_danger_taniVurus;
            private _topcuOlasi = _eslesen && {_enD <= 35};
            private _hdD = _b get "hdD";
            private _icinde = _hdD >= 0 && {_hdD <= 1.2};
            private _taraf = _b get "taraf";
            private _hg = _b get "hendekGrup";
            private _k = str _taraf;
            private _s = lambs_danger_taniOlumSay getOrDefault [_k, [0, 0, 0, 0, 0]];
            _s set [0, (_s select 0) + 1];
            if (_hg) then { _s set [1, (_s select 1) + 1]; };
            if (_icinde) then { _s set [2, (_s select 2) + 1]; };
            if (_hg && {!_icinde}) then { _s set [3, (_s select 3) + 1]; };
            if (_topcuOlasi) then { _s set [4, (_s select 4) + 1]; };
            lambs_danger_taniOlumSay set [_k, _s];
            if (lambs_danger_taniOlumN <= 300) then {
                diag_log format ["[OLUM-TANI] taraf=%1 | grup=%2 | ad=%3 | rol=%4 | durus=%5 | anim=%6 | hendek_grubu=%7 | hendek_alani_mesafe=%8 | hendek_icinde=%9 | aracta=%10 | topcu_olasi=%11 | topcu_mesafe=%12 | topcu_zaman_farki=%13 | topcu_mermi=%14 | olduren=%15 | olduren_mesafe=%16 | nokta=%17",
                    _taraf, _b get "grup", _b get "ad", _b get "rol", _b get "durus", _b get "anim", _hg, if (_hdD < 0) then {"yok(>60m)"} else {round _hdD}, _icinde, _b get "aracta", _topcuOlasi,
                    if (_enD > 1e8) then {"-"} else {round _enD}, if (_enD > 1e8) then {"-"} else {_enZ toFixed 1}, _enM, _b get "oldurenTip", _b get "oldurenMes", mapGridPosition _pos];
            };
        }, [_bilgi], 1.5] call CBA_fnc_waitAndExecute;
    },
    true,
    [],
    true
] call CBA_fnc_addClassEventHandler;

// ---- 3) arac mürettebat inisi / binisi + parca hasar halkasi ----
[
    "LandVehicle",
    "Dammaged",
    {
        params ["_v", "_sel", "_dmg", "_hi", "_hp", ["_shooter", objNull], ["_proj", objNull]];
        _v setVariable [QGVAR(taniHasarT), time];
        if (_dmg >= 0.25 && {_hp isEqualType ""} && {_hp isNotEqualTo ""}) then {
            private _r = _v getVariable [QGVAR(taniHasarR), []];
            _r pushBack [time, _hp, _dmg, [typeOf _shooter, "?"] select (isNull _shooter), [typeOf _proj, "?"] select (isNull _proj)];
            if ((count _r) > 8) then { _r deleteAt 0; };
            _v setVariable [QGVAR(taniHasarR), _r];
        };
    },
    true,
    [],
    true
] call CBA_fnc_addClassEventHandler;

[
    "LandVehicle",
    "GetOut",
    {
        params ["_v", "_rol", "_u", "_tur"];
        if (missionNamespace getVariable ["lambs_danger_taniOff", false] || {lambs_danger_taniTerkN >= 150}) exitWith {};
        if (isNull _u || {isPlayer _u} || {_v isKindOf "StaticWeapon"} || {_v isKindOf "Air"} || {(toLower _rol) isEqualTo "cargo"}) exitWith {};
        if ((crew _v) findIf {isPlayer _x} >= 0) exitWith {};
        lambs_danger_taniTerkN = lambs_danger_taniTerkN + 1;
        private _g = group _u;
        private _hpA = getAllHitPointsDamage _v;
        private _hpL = [];
        if (count _hpA >= 3) then {
            {
                private _dv = (_hpA select 2) select _forEachIndex;
                if (_x isNotEqualTo "" && {_dv isEqualType 0} && {_dv >= 0.25}) then { _hpL pushBack format ["%1=%2", _x, _dv toFixed 2]; };
            } forEach (_hpA select 0);
        };
        private _son = (_v getVariable [QGVAR(taniHasarR), []]) apply { format ["%1s:%2=%3 (%4/%5)", round (time - (_x select 0)), _x select 1, (_x select 2) toFixed 2, _x select 3, _x select 4] };
        private _ks = {
            params ["_arac", "_ad"];
            private _w = switch (_ad) do { case "driver": {driver _arac}; case "gunner": {gunner _arac}; default {commander _arac}; };
            if (isNull _w) then {"-"} else { format ["%1%2", name _w, ["(OLU)", ""] select (alive _w)] }
        };
        private _en = _u findNearestEnemy _u;
        diag_log format ["[ARAC-TERK] arac=%1 | grup=%2 | inen=%3 | rol=%4 | arac_hasar=%5 | canMove=%6 | canFire=%7 | motor=%8 | yakit=%9 | hiz=%10 | yaniyor=%11 | hasarli_parca=%12 | son_hasar_yasi=%13 | son_hasarlar=%14 | surucu=%15 | nisanci=%16 | komutan=%17 | birim_komutu=%18 | atama=%19 | durum=%20 | temas_yasi=%21 | en_yakin_dusman=%22 | tasimaMesgul=%23 | planZirh=%24 | tankManevra_yasi=%25 | atTepki_yasi=%26 | zirhKac_yasi=%27 | nokta=%28",
            getText (configOf _v >> "displayName"), groupId _g, name _u, _rol, (damage _v) toFixed 2, canMove _v, canFire _v, isEngineOn _v, (fuel _v) toFixed 2, round (speed _v), isBurning _v,
            _hpL, round (time - (_v getVariable [QGVAR(taniHasarT), -999])), _son, [_v, "driver"] call _ks, [_v, "gunner"] call _ks, [_v, "commander"] call _ks,
            currentCommand _u, typeOf (assignedVehicle _u), lifeState _u, round (time - (_g getVariable [QGVAR(contact), -999])),
            if (isNull _en) then {"-"} else {round (_u distance2D _en)}, _v getVariable [QGVAR(tasimaMesgul), false], _g getVariable ["lambs_danger_planZirh", false],
            round (time - (_v getVariable [QGVAR(tankManevraT), -999])), round (time - (_v getVariable [QGVAR(atTepkiT), -999])), round (time - (_v getVariable [QGVAR(zirhKacT), -999])), mapGridPosition _v];
    },
    true,
    [],
    true
] call CBA_fnc_addClassEventHandler;

[
    "LandVehicle",
    "GetIn",
    {
        params ["_v", "_rol", "_u", "_tur"];
        if (missionNamespace getVariable ["lambs_danger_taniOff", false] || {lambs_danger_taniBindiN >= 100}) exitWith {};
        if (isNull _u || {isPlayer _u} || {_v isKindOf "StaticWeapon"} || {_v isKindOf "Air"} || {(toLower _rol) isEqualTo "cargo"}) exitWith {};
        if ((([_v] call lambs_danger_fnc_aracSinif) select 0) isNotEqualTo "TANK") exitWith {};
        lambs_danger_taniBindiN = lambs_danger_taniBindiN + 1;
        diag_log format ["[ARAC-BINDI] arac=%1 | grup=%2 | binen=%3 | rol=%4 | arac_hasar=%5 | canMove=%6 | nokta=%7", getText (configOf _v >> "displayName"), groupId (group _u), name _u, _rol, (damage _v) toFixed 2, canMove _v, mapGridPosition _v];
    },
    true,
    [],
    true
] call CBA_fnc_addClassEventHandler;

// ---- 4) olum ozeti (60 sn'de bir, degisim varsa) ----
[] spawn {
    private _son = -1;
    while {true} do {
        sleep 60;
        if (lambs_danger_taniOlumN isNotEqualTo _son) then {
            _son = lambs_danger_taniOlumN;
            {
                private _s = lambs_danger_taniOlumSay get _x;
                diag_log format ["[OLUM-OZET] taraf=%1 | toplam=%2 | hendek_grubundan=%3 | hendek_icinde=%4 | hendek_grubu_ama_disinda=%5 | topcu_olasi=%6", _x, _s select 0, _s select 1, _s select 2, _s select 3, _s select 4];
            } forEach (keys lambs_danger_taniOlumSay);
        };
    };
};

true
