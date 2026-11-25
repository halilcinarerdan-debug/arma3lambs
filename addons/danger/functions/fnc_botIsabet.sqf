#include "script_component.hpp"
/*
 * Author: Cinar (ELITE fork)
 * BOT ISABETI: OYUNIN aimingAccuracy = 1 SINIRININ OTESI (v8.575; kullanici: 'oyuncunun isabeti ile ilgili her seyi kaldir, ben sadece botlarin 1 limitinden cikmasini istemistim').
 * v8.801: mesafe bandi 4'e bolundu (<50 / 50-120 / 120-250 / >250 m; eskiden <120 tek bant) -> tools/rpt_ozet.py GERCEKCILIK KARNESI bant bazli isabet oranini hedef bantla karsilastirir.
 * ATIS / ISABET SAYACI (v8.577, v8.585, v8.586): botlar icin 60 sn'de bir [BOT-ISABET] (genel + mesafe bandi, oturum toplami); OYUNCU icin OLAY TABANLI [OYUNCU-ISABET] (her isabette bir satir; 60 sn penceresi gorev yeniden baslatmalarinda bos kaliyordu). OLUM SAYILMAZ (baygin / yaralanma durumlari yaniltir; kullanici: 'olmeyi sayma hit say').
 * Oyuncu sayaci YALNIZ OLCUMDUR (kullanici: 'gozlemim uydurma degil, hadi kur sistemi, atis sayisini olcelim'): oyuncuya yardim / mudahale YOK; bot isabet yardimi yalniz botlara uygulanir. Oyuncu atisi = nisan noktasindaki (cursorObject) dusman piyadeye atilan BulletBase mermisi; hedef basina 'son isabetten beri atis' tutulur. Etiket: SAVAS = hedef birimin davranisi COMBAT ve grup combatMode BLUE / GREEN / WHITE degil; aksi UYANDIRMA (hold fire hedefi uyandirmak icin atilan mermiler; kullanici: 'onlari hesaba katma') ve toplama SAYILMAZ. Satirda hedefin oyuncu hakkindaki bilgisi (knowsAbout) da var (spot suresi etkisi icin). Oyuncu ve hedef ayni makinede yerelse (SP / host / editor) calisir.
 * aimingAccuracy / aimingShake en cok 1.0'dir (setSkill siniri). Bu sinirin otesi iki ayarla:
 *   - CBA isabetSeviye (0 = kapali, 1.25 / 1.30 ...): > 1 ise (1) yerel botlarin aimingAccuracy / aimingShake degeri 1.0'a sabitlenir (5 sn'de bir; eski deger saklanir, seviye <= 1 olunca geri yazilir; oyunculu grup / ALiVE / disableAI haric),
 *     (2) mermi yonu hatasi (1 - 1 / seviye) oraninda duzeltilir (isabet seviyesi ~ 1 / hata varsayimi: 1.25 -> %20, 1.30 -> %23, 1.5 -> %33).
 *   - CBA isabetYardim (0-1): seviyeden bagimsiz dogrudan mermi yonu duzeltme orani; ikisi birlikte ise buyuk olan gecerli.
 * MERMI YONU DUZELTME: bot (oyuncusuz grup, yerel mermi) bilinen dusman piyadeye <= 600 m BulletBase mermisi attiginda (hedef = assignedTarget, yoksa en yakin dusman; SuppressTarget / nokta bastirma sayilmaz) mermi hizinin yonu
 *   (azimut + yukselme) hedefe (aimPos + hedef hizi x ucus suresi onculu; yercekimi dusmesi 0.5 g t^2 telafili, ucus suresi = menzil / (hiz x 0.9)) olan hatanin orani kadar duzeltilir; her eksende en cok +-15 derece (v8.594; v8.592: +-8; eskiden +-4).
 * SINIR: setVelocity'nin tum mermi turlerinde / ACE Advanced Ballistics ile calistigi DENENMEDI; hava surtunmesi modellenmedi; hile benzeri (aimbot yardimi). Log: [ISABET-SEVIYE] (ilk 10).
 *
 * Arguments: None
 * Return Value: Baslatildi mi <BOOL>
 * Public: No
*/

if (!isNil "lambs_danger_botIsabetStarted") exitWith {false};
lambs_danger_botIsabetStarted = true;
lambs_danger_isabetMermiOn = createHashMap;
diag_log "[ISABET-SEVIYE] bot isabeti (aimingAccuracy 1 siniri otesi: CBA isabetSeviye / isabetYardim) baslatildi (v8.575)";

// ---- BOT ISABET SAYACI (v8.577; kullanici: 'genele vurdugunda ortalama kaba tahmin 100 ustudur'): YALNIZ botlar (oyuncu sayilmaz / olculmez). Bu makinedeki yerel botlarin TUM mermileri (baski ateşi dahil) ve dusman piyadeye ISABETLERI ----
// sayac: [toplam atis, nisanli atis (bant 0/1/2), isabet (bant 0/1/2), toplam isabet]; oyuncu icin nisanli atis kullanilmaz (hedef secimi yok)
lambs_danger_botSay = [0, [0, 0, 0, 0], [0, 0, 0, 0], 0];
lambs_danger_botSayTop = [0, 0, 0];   // oturum toplami: [atis, isabet, nisanli atis]
lambs_danger_oyuSay = [0, 0, 0, 0];   // oyuncu oturum: [SAVAS atis, SAVAS isabet, UYANDIRMA atis, UYANDIRMA isabet]
lambs_danger_savasMi = { params ["_h"]; ((behaviour _h) isEqualTo "COMBAT") && {!((combatMode group _h) in ["BLUE", "GREEN", "WHITE"])} };

["CAManBase", "Fired", {
    params ["_u", "_wep", "", "", "_ammo", "", "_proj"];
    if (!local _u || {_wep isEqualTo (secondaryWeapon _u)}) exitWith {};
    private _on = lambs_danger_isabetMermiOn;
    private _b = _on getOrDefault [_ammo, -1];
    if (_b < 0) then { _b = [0, 1] select (_ammo isKindOf ["BulletBase", configFile >> "CfgAmmo"]); _on set [_ammo, _b]; };
    _u setVariable ["lambs_danger_sonMermiB", _b];
    if (_b isEqualTo 0) exitWith {};
    if (isPlayer _u) exitWith {
        private _o = cursorObject;
        if (!(_o isKindOf "CAManBase") || {!alive _o} || {((side group _u) getFriend (side group _o)) >= 0.6}) exitWith {};
        _o setVariable ["lambs_danger_oyuAtis", (_o getVariable ["lambs_danger_oyuAtis", 0]) + 1];
        private _oy = lambs_danger_oyuSay;
        private _ix = [0, 2] select !([_o] call lambs_danger_savasMi);
        _oy set [_ix, (_oy select _ix) + 1];
    };
    private _say = lambs_danger_botSay;
    _say set [0, (_say select 0) + 1];
    private _t = assignedTarget _u;
    if (isNull _t || {!(_t isKindOf "CAManBase")}) then { _t = _u findNearestEnemy _u; };
    private _gecerli = !isNull _t && {alive _t} && {_t isKindOf "CAManBase"} && {!([_t] call FUNC(teslimMi))} && {((side group _u) getFriend (side group _t)) < 0.6} && {(_u distance _t) <= 600};
    if (_gecerli) then {
        private _m = _u distance _t;
        private _bn = if (_m >= 250) then {3} else { if (_m >= 120) then {2} else { if (_m >= 50) then {1} else {0} } };
        private _na = _say select 1;
        _na set [_bn, (_na select _bn) + 1];
    };
    // mermi yonu duzeltme (isabetSeviye / isabetYardim)
    private _yrd = missionNamespace getVariable ["lambs_danger_isabetYardim", 0];
    private _sev = missionNamespace getVariable ["lambs_danger_isabetSeviye", 0];
    if (_sev > 1) then { _yrd = _yrd max (1 - (1 / _sev)); };
    if (_yrd <= 0 || {!_gecerli} || {isNull _proj} || {(((units group _u) findIf {isPlayer _x}) > -1) && {!(missionNamespace getVariable ["lambs_danger_oyuncuGrubuBot", false])}}) exitWith {};   // v8.721: CBA oyuncuGrubuBot acikken oyuncu grubundaki botlar da isabet yardimi alir
    private _v = velocity _proj;
    private _sp = vectorMagnitude _v;
    private _vh = sqrt (((_v select 0) ^ 2) + ((_v select 1) ^ 2));
    if (_sp < 50 || {_vh < 1}) exitWith {};
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
    private _dAz = ((((_azI - _azC) + 540) mod 360) - 180) max -15 min 15;
    private _dEl = ((_elI - _elC) max -15) min 15;
    private _azN = _azC + (_dAz * _yrd);
    private _elN = _elC + (_dEl * _yrd);
    _proj setVelocity ([(sin _azN) * (cos _elN), (cos _azN) * (cos _elN), sin _elN] vectorMultiply _sp);
}, true, [], true] call CBA_fnc_addClassEventHandler;

["CAManBase", "Hit", {
    params ["_unit", "_src", "_dmg", "_ins"];
    private _sh = if (!isNull _ins) then {_ins} else {_src};
    if (isNull _sh || {!(_sh isKindOf "CAManBase")} || {_sh isEqualTo _unit} || {!local _sh} || {_dmg <= 0}) exitWith {};
    if ((_sh getVariable ["lambs_danger_sonMermiB", 0]) isNotEqualTo 1) exitWith {};
    if (((side group _sh) getFriend (side group _unit)) >= 0.6) exitWith {};
    private _m = _sh distance _unit;
    if (isPlayer _sh) exitWith {
        private _sv = [_unit] call lambs_danger_savasMi;
        private _oy = lambs_danger_oyuSay;
        private _ix = [1, 3] select !_sv;
        _oy set [_ix, (_oy select _ix) + 1];
        private _at = _unit getVariable ["lambs_danger_oyuAtis", 0];
        _unit setVariable ["lambs_danger_oyuAtis", 0];
        diag_log format ["[OYUNCU-ISABET] %1 | mesafe %2 m | bu hedefe son isabetten beri atis %3 | hedef davranis %4 combatMode %5 bilgi(knowsAbout) %6 || OTURUM SAVAS: %7 atis / %8 isabet = %9 mermi/isabet | UYANDIRMA (sayilmaz): %10 atis / %11 isabet",
            ["SAVAS", "UYANDIRMA"] select !_sv, _m toFixed 0, _at, behaviour _unit, combatMode group _unit, (_unit knowsAbout _sh) toFixed 1,
            _oy select 0, _oy select 1, if ((_oy select 1) > 0) then { ((_oy select 0) / (_oy select 1)) toFixed 1 } else {"-"}, _oy select 2, _oy select 3];
    };
    private _bn = if (_m >= 250) then {3} else { if (_m >= 120) then {2} else { if (_m >= 50) then {1} else {0} } };
    private _say = lambs_danger_botSay;
    private _ia = _say select 2;
    _ia set [_bn, (_ia select _bn) + 1];
    _say set [3, (_say select 3) + 1];
}, true, [], true] call CBA_fnc_addClassEventHandler;

[] spawn {
    while {true} do {
        sleep 60;
        private _say = lambs_danger_botSay;
        _say params ["_at", "_na", "_ia", "_ih"];
        private _top = lambs_danger_botSayTop;
        _top set [0, (_top select 0) + _at];
        _top set [1, (_top select 1) + _ih];
        _top set [2, (_top select 2) + (_na select 0) + (_na select 1) + (_na select 2) + (_na select 3)];
        if (_at > 0) then {
            private _bantS = [0, 1, 2, 3] apply { format ["%1: nisanli %2 atis / %3 isabet (%4 atis/isabet)", ["<50 m", "50-120 m", "120-250 m", ">250 m"] select _x, _na select _x, _ia select _x, if ((_ia select _x) > 0) then { ((_na select _x) / (_ia select _x)) toFixed 0 } else {"-"}] };
            diag_log format ["[BOT-ISABET] son 60 sn (bu makinedeki botlar): TUM atis %1 (baski ateşi dahil) | isabet %2 | GENEL %3 mermi/isabet | %4 || OTURUM: %5 atis / %6 isabet = %7 mermi/isabet",
                _at, _ih, if (_ih > 0) then { (_at / _ih) toFixed 0 } else {"-"}, _bantS joinString " | ", _top select 0, _top select 1, if ((_top select 1) > 0) then { ((_top select 0) / (_top select 1)) toFixed 0 } else {"-"}];
        };
        lambs_danger_botSay = [0, [0, 0, 0, 0], [0, 0, 0, 0], 0];
    };
};

// ---- isabet seviyesi > 1 -> bot becerisi azami (5 sn'de bir; seviye <= 1 olunca eski deger) ----
[] spawn {
    private _logN = 0;
    while {true} do {
        sleep 5;
        private _sev = missionNamespace getVariable ["lambs_danger_isabetSeviye", 0];
        {
            private _u = _x;
            private _bay = _u getVariable ["lambs_danger_isabetSevBay", false];
            if (_sev > 1) then {
                if (isPlayer _u || {(((units group _u) findIf {isPlayer _x}) > -1) && {!(missionNamespace getVariable ["lambs_danger_oyuncuGrubuBot", false])}} || {_u getVariable [QGVAR(disableAI), false]} || {[_u] call FUNC(aliveSahip)}) then { continue };
                if (!_bay) then {
                    _u setVariable ["lambs_danger_isabetSevEski", [_u skill "aimingAccuracy", _u skill "aimingShake"]];
                    _u setVariable ["lambs_danger_isabetSevBay", true];
                    if (_logN < 10) then { _logN = _logN + 1; diag_log format ["[ISABET-SEVIYE] %1 | seviye %2: aimingAccuracy %3 -> 1.00, aimingShake %4 -> 1.00 | mermi hatasi duzeltme orani %5", name _u, _sev toFixed 2, (_u skill "aimingAccuracy") toFixed 2, (_u skill "aimingShake") toFixed 2, (1 - (1 / _sev)) toFixed 2]; };
                };
                if ((_u skill "aimingAccuracy") < 0.99) then { _u setSkill ["aimingAccuracy", 1]; };
                if ((_u skill "aimingShake") < 0.99) then { _u setSkill ["aimingShake", 1]; };
            } else {
                if (_bay) then {
                    private _e = _u getVariable ["lambs_danger_isabetSevEski", []];
                    if (_e isNotEqualTo []) then { _u setSkill ["aimingAccuracy", _e select 0]; _u setSkill ["aimingShake", _e select 1]; };
                    _u setVariable ["lambs_danger_isabetSevBay", nil];
                    _u setVariable ["lambs_danger_isabetSevEski", nil];
                };
            };
        } forEach (allUnits select {local _x && {alive _x} && {_x isKindOf "CAManBase"} && {!isPlayer _x} && {(_sev > 1) || {_x getVariable ["lambs_danger_isabetSevBay", false]}}});
    };
};
true
