#include "script_component.hpp"
/*
 * Author: Cinar (ELITE fork)
 * MODUL OLAY KAPISI (sade-waypoint v8.503): Zeus / 3DEN modulleri CURATOR'UN makinesinde calisir, gruplar SUNUCUDA yereldir; moduller CBA sunucu olayi yollar, bu kapi dinler.
 *   lambs_danger_gorevAta / ihaGorev / topcuTestIstegi (+ Yanit) / garnizonYanit (3DEN ortak bildirim). Plan / objektif / karakol / garnizon / HQ katmani KALDIRILDI.
 * Log: [PLAN-KAPI]
 *
 * Arguments: None
 * Return Value: Baslatildi mi <BOOL>
 * Public: No
*/

if (!isNil "lambs_danger_planKapiStarted") exitWith {false};
lambs_danger_planKapiStarted = true;

// v8.127: Zeus 'ELITE Gorev Ata' -> sunucu degiskeni yazar (grup + varsa arac)
["lambs_danger_gorevAta", {
    params ["_hedef", "_kod"];
    if (!isServer || {isNull _hedef}) exitWith {};
    private _g = if (_hedef isEqualType grpNull) then {_hedef} else {group (effectiveCommander _hedef)};
    private _nesneler = [];
    if (!(_hedef isEqualType grpNull) && {!(_hedef isKindOf "CAManBase")}) then { _nesneler pushBack _hedef; };
    if (!(_hedef isEqualType grpNull) && {_hedef isKindOf "CAManBase"} && {!isNull objectParent _hedef}) then { _nesneler pushBack (vehicle _hedef); };   // v8.407: grup nesnesinde isKindOf hata veriyordu (RPT b95a6bae: Type Group, expected String,Object)
    if (!isNull _g) then { _nesneler pushBack _g; };
    // v8.151: oyuncu komutasi bayragi (gorev degiskenine yazilmaz): OYUNCU = true, ELITE_TAM = false, Otomatik = silinir (oyunculu grup otomatik)
    if (_kod in ["OYUNCU", "ELITE_TAM"]) exitWith {
        if (!isNull _g) then { _g setVariable ["lambs_danger_oyuncuKomuta", _kod isEqualTo "OYUNCU", true]; };
        diag_log format ["[OYUNCU-KOMUTA] %1 -> %2", [groupId _g, "-"] select (isNull _g), ["ELITE TAM ACIK (zorla)", "OYUNCU KOMUTASI (ELITE taktik kapali)"] select (_kod isEqualTo "OYUNCU")];
    };
    if (_kod isEqualTo "" && {!isNull _g}) then { _g setVariable ["lambs_danger_oyuncuKomuta", nil, true]; };
    { _x setVariable ["lambs_danger_gorev", _kod, true]; } forEach _nesneler;
    // v8.141: arac atamasinda ekip grubu kaydi (surucu araci terk ederse yeniden binmesi icin)
    if (!(_hedef isEqualType grpNull) && {!(_hedef isKindOf "CAManBase")} && {!isNull _g}) then { _hedef setVariable ["lambs_danger_ekipGrup", _g, true]; };
    diag_log format ["[GOREV-ATAMA] %1 -> %2 (nesne: %3)", [groupId _g, "-"] select (isNull _g), ["TEMIZLENDI", _kod] select (_kod isNotEqualTo ""), count _nesneler];
}] call CBA_fnc_addEventHandler;

// v8.233: Zeus 'ELITE IHA Gorevi' -> fnc_ihaSorti (sunucu)
["lambs_danger_ihaGorev", {
    params ["_nid", "_mod", "_tur", "_tarafI", "_poz", "_yar", "_men", ["_yaratSn", ""], ["_tetik", 0], ["_opNid", ""], ["_opMod", 0], ["_cantaNid", ""], ["_sure", 0]];
    private _op = objectFromNetId _opNid;
    private _canta = objectFromNetId _cantaNid;
    if (!isServer) exitWith {};
    private _iha = objectFromNetId _nid;
    private _tf = [west, east, independent] select (_tarafI max 0 min 2);
    // v8.267: KALDIR + dron yok -> firlatma noktasinin 60 m icindeki bekleyen firlatma emirleri iptal edilir
    if (isNull _iha && {_mod isEqualTo "KALDIR"}) exitWith {
        private _n = 0;
        { if (((_x select 0) distance2D _poz) <= 60 && {!(_x select 1)}) then { _x set [1, true]; _n = _n + 1; }; } forEach (missionNamespace getVariable ["lambs_danger_ihaBekleEmirleri", []]);
        diag_log format ["[IHA-BEKLEME] Zeus KALDIR: %1 bekleyen firlatma emri iptal edildi (%2)", _n, mapGridPosition _poz];
        private _cu = (allCurators apply {getAssignedCuratorUnit _x}) select {!isNull _x};
        if (_cu isNotEqualTo []) then { [format ["[ELITE] IHA firlatma emri iptal: %1", _n]] remoteExec ["systemChat", _cu]; };
    };
    // v8.267 BILINCLI FIRLATMA: 'Dron yarat' dronu hemen degil, firlatma noktasinin tetik mesafesinde BILINEN dusman gorulunce yaratir (fnc_ihaBekle); tetik 0 = hemen (eski)
    // v8.363: Gozlem devriyesi + 'Dron yarat' -> tur GOZLEM'e zorlanir (eskiden 'Otomatik' tur Crocus'ta FPV sortisi olurdu) ve firlatma BEKLEMEZ (gozlem dronu dusman bilinmeden, bilgi toplamak icin kalkar; tetik mesafesi dusman gerektirirdi)
    if (_mod isEqualTo "GOZLEM") then { _tur = "GOZLEM"; _tetik = 0; };
    if (isNull _iha && {_yaratSn isNotEqualTo ""} && {isClass (configFile >> "CfgVehicles" >> _yaratSn)}) exitWith {
        [_yaratSn, _tf, _poz, _tur, _yar, _men, _tetik, _op, _opMod, _canta, _sure] call (missionNamespace getVariable ["lambs_danger_fnc_ihaBekle", {false}]);
    };
    [_iha, _mod, _tur, _tf, _poz, _yar, _men, _op, _opMod, _sure] call (missionNamespace getVariable ["lambs_danger_fnc_ihaSorti", {false}]);
}] call CBA_fnc_addEventHandler;

// v8.196: Zeus 'ELITE Topcu TEST' - plan mantigindan bagimsiz atis denemesi (sunucu)
["lambs_danger_topcuTestIstegi", {
    params ["_poz", "_sahip"];
    if (!isServer) exitWith {};
    private _rapor = [];
    private _araclar = vehicles select {alive _x && {(getNumber (configOf _x >> "artilleryScanner")) > 0}};
    if (_araclar isEqualTo []) then { _rapor pushBack "sahada artilleryScanner'li arac YOK"; };
    {
        private _v = _x;
        private _ad = format ["%1 (%2)", getText (configOf _v >> "displayName"), side (group _v)];
        private _g = gunner _v;
        private _mg = (getArtilleryAmmo [_v]) param [0, ""];
        if (isNull _g) then { _rapor pushBack format ["%1: topcu (gunner) YOK", _ad]; continue };
        if (isPlayer _g) then { _rapor pushBack format ["%1: gunner OYUNCU - AI atis emri verilmez", _ad]; continue };
        if (!local _v) then {
            // v8.287: yerel degilse murettebat gruplari hemen sunucuya devredilir (oyuncu / uzaktan kontrol yoksa); 15-20 sn sonra testi tekrarlayin
            private _grlar = [];
            { private _gx = group _x; if (!isNull _gx && {!(_gx in _grlar)}) then { _grlar pushBack _gx; }; } forEach (crew _v);
            private _engel = (_grlar findIf { ((units _x) findIf {isPlayer _x}) >= 0 || {((units _x) findIf {!isNull (_x getVariable ["bis_fnc_moduleRemoteControl_owner", objNull])}) >= 0} }) >= 0;
            if (_engel) then {
                _rapor pushBack format ["%1: sunucuda YEREL DEGIL (sahip %2); murettebatta OYUNCU / ZEUS UZAKTAN KONTROL var -> devredilemez (kontrolu birak)", _ad, owner _v];
            } else {
                { _x setGroupOwner 2; } forEach _grlar;
                _rapor pushBack format ["%1: sunucuda yerel degildi (sahip %2) -> murettebat sunucuya DEVREDILDI; 15-20 sn sonra testi tekrarlayin", _ad, owner _v];
            };
            continue
        };
        if (!canFire _v) then { _rapor pushBack format ["%1: canFire FALSE (hasar / mermi)", _ad]; continue };
        if (_mg isEqualTo "") then { _rapor pushBack format ["%1: mermi YOK (getArtilleryAmmo bos)", _ad]; continue };
        if !(_poz inRangeOfArtillery [[_v], _mg]) then {
            private _kon = [_v, _poz, "TEST"] call (missionNamespace getVariable ["lambs_danger_fnc_topcuKonumla", {false}]);
            _rapor pushBack format ["%1: hedef %2 m'de MENZIL DISI -> %3", _ad, round (_v distance2D _poz), ["yer degistirme emri verilemedi (300 sn kilit / surucu yok)", "yer degistiriyor, 1-2 dk sonra tekrar deneyin"] select _kon];
            continue
        };
        [_v, _poz, _mg] call (missionNamespace getVariable ["lambs_danger_fnc_topcuAtisHazirla", {false}]);   // v8.287: hareket emri iptal, davranis / combatMode, atis tanisi
        _v doArtilleryFire [_poz getPos [random 25, random 360], _mg, 3];
        _rapor pushBack format ["%1: ATES EMRI VERILDI (%2 m, %3, 3 mermi, ETA %4 sn)", _ad, round (_v distance2D _poz), _mg, round (_v getArtilleryETA [_poz, _mg])];
    } forEach _araclar;
    { diag_log format ["[TOPCU-TEST] %1 | %2", mapGridPosition _poz, _x]; } forEach _rapor;
    ["lambs_danger_topcuTestYanit", [_rapor], _sahip] call CBA_fnc_ownerEvent;
}] call CBA_fnc_addEventHandler;
["lambs_danger_topcuTestYanit", {
    params ["_rapor"];
    if (!hasInterface) exitWith {};
    { systemChat format ["[ELITE Topcu TEST] %1", _x]; } forEach _rapor;
}] call CBA_fnc_addEventHandler;

["lambs_danger_garnizonYanit", {
    params ["_m"];
    if (!hasInterface) exitWith {};
    diag_log format ["[KARAKOL-YANIT] %1", _m];
    if (!isNull (getAssignedCuratorLogic player)) then { systemChat format ["[ELITE] %1", _m]; };
}] call CBA_fnc_addEventHandler;

diag_log "[PLAN-KAPI] Zeus / 3DEN modul olay kapisi baslatildi (sade surum)";
true
