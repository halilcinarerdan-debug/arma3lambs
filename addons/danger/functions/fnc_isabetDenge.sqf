#include "script_component.hpp"
/*
 * Author: Cinar (ELITE fork)
 * ISABET DENGESI: BOTLAR OYUNCUYLA AYNI ISABET ORANINA SAHIP OLSUN (v8.565; kullanici: 'oyuncu ile ayni isabet oranina sahip olsunlar').
 * OLCUM (her zaman, ucuz): yerel makinedeki mermi atislari (Fired, yalniz BulletBase) ve mermi isabetleri (Hit olayi, kaynak = mermi atan piyade, kurban DUSMAN piyade) iki grupta sayilir:
 *   OYUNCU (isPlayer) ve BOT (oyuncu olmayan AI), uc MESAFE bandinda (< 120 m, 120-250 m, > 250 m; atis aninda HEDEFE mesafe). Atis hedefi: oyuncu icin imlecin altindaki dusman asker (cursorTarget), bot icin assignedTarget (yoksa en yakin bilinen
 *   dusman; SuppressTarget / nokta bastirma SAYILMAZ). Her 15 sn yerel sayaclar sunucuya (CBA sunucu olayi) gonderilir; sunucu toplar.
 * DENGELEME (yalniz CBA 'isabetDenge' acikken): sunucu 60 sn'de bir BANT BAZINDA oyuncu ve bot isabet oranini (isabet / atis) karsilastirir: yalniz her iki taraf >= 8 atisli bantlar; bot atis dagilimina gore agirlikli ortalama oyuncu orani Rp ve bot orani Rb;
 *   K = K x clamp(Rp x CBA 'isabetHedefOran' / Rb, 0.85, 1.15) (K 0.4..1.6; en az 25 oyuncu + 40 bot atisi), sayaclar her turda x0.7 sonumlenir (kayan pencere). K herkese publicVariable ('lambs_danger_isabetK'); her makine 20 sn'de bir
 *   YEREL botlarin aimingAccuracy degerini (skill / eskiK) x yeniK olarak yeniden olcekler (becerisi varsayilanSkill ile atanmis, ALiVE / disableAI olmayan, oyunculu grupta olmayan birimler).
 * SINIRLAR: oyuncu / bot isabeti AYNI KOSULLARDA olculmez (siper, gorunurluk, silah, optik farkli): bant bazli karsilastirma yalniz mesafeyi esitler. Hit olayi atici ile kurbanin makinesine bagli: mermi turunu ('son mermi' degiskeni) yalniz
 *   ATICI YEREL ise okur (tek makine / host'ta tam, dedicated sunucuda uzak oyuncu isabeti eksik kalir -> o durumda oyuncu orani dusuk olcunur). Patlama / el bombasi hasari sayilmaz.
 * ISABET YARDIMI (v8.569, CBA isabetYardim, varsayilan 0): bkz. Fired isleyicisi - bot mermisinin yonu hataya gore duzeltilir (aimingAccuracy 1 siniri disina cikmak icin).
 * Log: [ISABET-DENGE] (60 sn'de bir: bant bazli oyuncu / bot atis + isabet + oran, K, aksiyon). Kapatma: CBA isabetDenge = false (olcum surer).
 *
 * Arguments: None
 * Return Value: Baslatildi mi <BOOL>
 * Public: No
*/

if (!isNil "lambs_danger_isabetDengeStarted") exitWith {false};
lambs_danger_isabetDengeStarted = true;
if (isNil "lambs_danger_isabetK") then { lambs_danger_isabetK = 1; };
// yerel sayaclar: [oyuncuAtis[3], oyuncuIsabet[3], botAtis[3], botIsabet[3]]
lambs_danger_isabetYerel = [[0, 0, 0], [0, 0, 0], [0, 0, 0], [0, 0, 0]];
lambs_danger_isabetMermiOn = createHashMap;
diag_log "[ISABET-DENGE] olcum baslatildi (v8.565); dengeleme CBA 'isabetDenge' ile";

private _bant = { params ["_m"]; if (_m >= 250) then {2} else { if (_m >= 120) then {1} else {0} } };
lambs_danger_isabetBant = _bant;

// ---- olcum: atis ----
["CAManBase", "Fired", {
    params ["_u", "_wep", "", "", "_ammo", "", "_proj"];
    if (!local _u || {_wep isEqualTo (secondaryWeapon _u)}) exitWith {};
    private _on = lambs_danger_isabetMermiOn;
    private _b = _on getOrDefault [_ammo, -1];
    if (_b < 0) then { _b = [0, 1] select (_ammo isKindOf ["BulletBase", configFile >> "CfgAmmo"]); _on set [_ammo, _b]; };
    _u setVariable ["lambs_danger_sonMermiB", _b];
    if (_b isEqualTo 0) exitWith {};
    private _oy = isPlayer _u;
    private _t = if (_oy) then { cursorTarget } else { assignedTarget _u };
    if (!_oy && {isNull _t || {!(_t isKindOf "CAManBase")}}) then { _t = _u findNearestEnemy _u; };
    if (isNull _t || {!alive _t} || {!(_t isKindOf "CAManBase")} || {((side group _u) getFriend (side group _t)) >= 0.6}) exitWith {};
    private _m = _u distance _t;
    if (_m > 600) exitWith {};
    // v8.569 ISABET YARDIMI (kullanici: 'oyunun 1 limiti disinda'): aimingAccuracy en cok 1 olur; botun mermisinin yonu, hedefe (onculu + dusme telafili) olan HATANIN CBA isabetYardim orani kadari duzeltilir (hata <= 4 derece).
    //   Hile benzeri (aimbot yardimi): 0 = kapali (varsayilan). Yalniz oyuncusuz grup / bot, yerel mermi, <= 600 m.
    private _yrd = missionNamespace getVariable ["lambs_danger_isabetYardim", 0];
    // v8.570 TEST (kullanici: 'oyuncu olarak ayni seviyeyi istiyorum, bir test etmek icin'): CBA isabetYardimOyuncu aciksa AYNI yardim OYUNCUNUN mermisine de uygulanir (hedef = imlecin altindaki dusman asker)
    if (_yrd > 0 && {!isNull _proj} && {(!_oy && {((units group _u) findIf {isPlayer _x}) < 0}) || {_oy && {missionNamespace getVariable ["lambs_danger_isabetYardimOyuncu", false]}}}) then {
        private _v = velocity _proj;
        private _sp = vectorMagnitude _v;
        private _vh = sqrt (((_v select 0) ^ 2) + ((_v select 1) ^ 2));
        if (_sp > 50 && {_vh > 1}) then {
            private _p0 = getPosASL _proj;
            private _tp = aimPos _t;
            private _d = _tp vectorDiff _p0;
            private _R = (sqrt (((_d select 0) ^ 2) + ((_d select 1) ^ 2))) max 1;
            private _tof = _R / (_sp * 0.9);
            private _d2 = (_tp vectorAdd ((velocity _t) vectorMultiply _tof)) vectorDiff _p0;
            private _R2 = (sqrt (((_d2 select 0) ^ 2) + ((_d2 select 1) ^ 2))) max 1;
            private _azI = (_d2 select 0) atan2 (_d2 select 1);
            private _elI = atan ((((_d2 select 2) + (0.5 * 9.81 * _tof * _tof))) / _R2);
            private _azC = (_v select 0) atan2 (_v select 1);
            private _elC = atan ((_v select 2) / _vh);
            private _dAz = ((((_azI - _azC) + 540) mod 360) - 180) max -4 min 4;
            private _dEl = ((_elI - _elC) max -4) min 4;
            private _azN = _azC + (_dAz * _yrd);
            private _elN = _elC + (_dEl * _yrd);
            _proj setVelocity ([(sin _azN) * (cos _elN), (cos _azN) * (cos _elN), sin _elN] vectorMultiply _sp);
        };
    };
    private _bn = [_m] call lambs_danger_isabetBant;
    private _y = lambs_danger_isabetYerel;
    private _a = _y select ([2, 0] select _oy);
    _a set [_bn, (_a select _bn) + 1];
}, true, [], true] call CBA_fnc_addClassEventHandler;

// ---- olcum: isabet ----
["CAManBase", "Hit", {
    params ["_unit", "_src", "_dmg", "_ins"];
    private _sh = if (!isNull _ins) then {_ins} else {_src};
    if (isNull _sh || {!(_sh isKindOf "CAManBase")} || {_sh isEqualTo _unit} || {!local _sh}) exitWith {};
    if ((_sh getVariable ["lambs_danger_sonMermiB", 0]) isNotEqualTo 1 || {_dmg <= 0}) exitWith {};
    if (((side group _sh) getFriend (side group _unit)) >= 0.6) exitWith {};
    private _m = _sh distance _unit;
    if (_m > 600) exitWith {};
    private _bn = [_m] call lambs_danger_isabetBant;
    private _y = lambs_danger_isabetYerel;
    private _a = _y select ([3, 1] select (isPlayer _sh));
    _a set [_bn, (_a select _bn) + 1];
}, true, [], true] call CBA_fnc_addClassEventHandler;

// ---- yerel -> sunucu (15 sn) ----
[] spawn {
    while {true} do {
        sleep 15;
        private _y = lambs_danger_isabetYerel;
        if (((flatten _y) findIf {_x > 0}) >= 0) then {
            lambs_danger_isabetYerel = [[0, 0, 0], [0, 0, 0], [0, 0, 0], [0, 0, 0]];
            ["lambs_danger_isabetOlay", [_y]] call CBA_fnc_serverEvent;
        };
    };
};

// ---- sunucu: toplama + dengeleme ----
if (isServer) then {
    lambs_danger_isabetTop = [[0, 0, 0], [0, 0, 0], [0, 0, 0], [0, 0, 0]];
    ["lambs_danger_isabetOlay", {
        params ["_y"];
        { private _i = _forEachIndex; { (lambs_danger_isabetTop select _i) set [_forEachIndex, ((lambs_danger_isabetTop select _i) select _forEachIndex) + _x]; } forEach _x; } forEach _y;
    }] call CBA_fnc_addEventHandler;
    [] spawn {
        while {true} do {
            sleep 60;
            private _t = lambs_danger_isabetTop;
            _t params ["_pA", "_pI", "_bA", "_bI"];
            private _pTop = 0; { _pTop = _pTop + _x; } forEach _pA;
            private _bTop = 0; { _bTop = _bTop + _x; } forEach _bA;
            private _wTop = 0; private _rp = 0; private _rb = 0;
            private _satir = [];
            for "_i" from 0 to 2 do {
                private _pa = _pA select _i; private _ba = _bA select _i;
                private _rpi = if (_pa > 0) then {(_pI select _i) / _pa} else {-1};
                private _rbi = if (_ba > 0) then {(_bI select _i) / _ba} else {-1};
                _satir pushBack format ["%1: oyuncu %2 atis / %3 isabet (%4) | bot %5 atis / %6 isabet (%7)", ["<120 m", "120-250 m", ">250 m"] select _i, _pa, _pI select _i, if (_rpi >= 0) then {_rpi toFixed 2} else {"-"}, _ba, _bI select _i, if (_rbi >= 0) then {_rbi toFixed 2} else {"-"}];
                if (_pa >= 8 && {_ba >= 8}) then { _wTop = _wTop + _ba; _rp = _rp + (_rpi * _ba); _rb = _rb + (_rbi * _ba); };
            };
            private _k = missionNamespace getVariable ["lambs_danger_isabetK", 1];
            private _eylem = "olcum";
            if ((missionNamespace getVariable ["lambs_danger_isabetDenge", false]) && {_pTop >= 25} && {_bTop >= 40} && {_wTop > 0} && {_rb > 0}) then {
                private _hedef = missionNamespace getVariable ["lambs_danger_isabetHedefOran", 1];
                private _oran = ((_rp * _hedef) / _rb) max 0.85 min 1.15;
                _k = ((_k * _oran) max 0.4) min 1.6;
                missionNamespace setVariable ["lambs_danger_isabetK", _k, true];
                _eylem = format ["DENGELEME oyuncu %1 / bot %2 (agirlikli, hedef x%3) -> K %4", (_rp / _wTop) toFixed 2, (_rb / _wTop) toFixed 2, _hedef toFixed 2, _k toFixed 3];
            };
            diag_log format ["[ISABET-DENGE] %1 | %2 | K=%3 | %4", _satir joinString " || ", ["KAPALI (yalniz olcum)", "ACIK"] select (missionNamespace getVariable ["lambs_danger_isabetDenge", false]), _k toFixed 3, _eylem];
            // kayan pencere
            { private _a = _x; { _a set [_forEachIndex, _x * 0.7]; } forEach +_a; } forEach _t;
        };
    };
};

// ---- her makine: yerel botlari K'ya gore olcekle (20 sn) ----
[] spawn {
    while {true} do {
        sleep 20;
        if !(missionNamespace getVariable ["lambs_danger_isabetDenge", false]) then { continue };
        private _k = missionNamespace getVariable ["lambs_danger_isabetK", 1];
        {
            private _u = _x;
            if (!(_u getVariable [QGVAR(skillAyarli), false]) || {isPlayer _u} || {((units group _u) findIf {isPlayer _x}) > -1} || {_u getVariable [QGVAR(disableAI), false]} || {[_u] call FUNC(aliveSahip)}) then { continue };
            private _ku = _u getVariable ["lambs_danger_isabetKUyg", 1];
            if ((abs (_k - _ku)) < 0.03) then { continue };
            private _a = _u skill "aimingAccuracy";
            _u setSkill ["aimingAccuracy", (((_a / _ku) * _k) max 0.05) min 1];
            _u setVariable ["lambs_danger_isabetKUyg", _k];
        } forEach (allUnits select {local _x && {alive _x} && {_x isKindOf "CAManBase"}});
    };
};
true
