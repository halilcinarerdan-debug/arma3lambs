#include "script_component.hpp"
/*
 * Author: Cinar (ELITE fork)
 * RPG ATIS KAPISI + OLCUMU (v8.746; kullanici: 'lambs rpg arastir' + 'rpg sistemi yapalim'): AI omuz roketatari atisini (Fired, shotRocket / shotMissile, gudumsuz) izler ve guvensizse IPTAL eder.
 * NEDEN: LAMBS RPG yalniz CONFIG modudur (aiAmmoUsageFlags: roketatar secimi motorun kararidir) ve atisin guvenligini DENETLEMEZ; RPT'lerde (120 dosya) AI roketatar atisi HIC loglanmiyordu (kim, neye, ne kadar, kime zarar) -> olcum yoktu.
 * KURAL: fnc_rpgGuvenli (min mesafe, bina ici, hedefte dost, geri duvar, arkada dost, zirh yedegi) ihlalinde mermi silinir (deleteVehicle), 12 sn sonra mermi geri verilir
 *   (silah bossa setAmmo 1, motor yedekten doldurduysa addMagazine); atici 12 sn karar verilmez (rpgBekleT). Gudumlu fuzeye (AA / Javelin / Titan / NLAW: weaponLockSystem / maxControlRange > 0) DOKUNULMAZ.
 *   Dusus noktasi: mermi hiz yonunde 800 m FIRE LOD hatti + arazi (ilk vurus); hedef zirh: dususun 15 m'sinde dusman kara araci / zirh. REZERV (v8.747): piyadeye / binaya atis kalan roket <= rpgYedek ise iptal (arac / hava / sabit silah hedefi muaf).
 * OLCUM: [RPG-ATIS] (ilk 60: atici, silah, mermi, aiAmmoUsageFlags, dusus mesafesi, hedef turu, kaynak 'karar' = fnc_rpgSistem emri / 'motor' = LAMBS RPG / motor) + [RPG-IPTAL] (ilk 40) + 60 sn [RPG-OZET]. Karne: RPG SISTEMI.
 * CBA: lambs_danger_rpgSistem (varsayilan ACIK; kapali = hicbir sey yapmaz), rpgMinM, rpgDostM, rpgYedek.
 *
 * Arguments:
 * 0: Atici <OBJECT>
 * 1: Silah <STRING>
 * 2: Mermi sinifi <STRING>
 * 3: Sarjor <STRING>
 * 4: Mermi nesnesi <OBJECT>
 *
 * Return Value: Iptal edildi mi <BOOL>
 *
 * Public: No
*/

params ["_unit", "_weapon", "_ammo", "_mag", "_proj"];
if !(missionNamespace getVariable ["lambs_danger_rpgSistem", true]) exitWith {false};
if (isNull _proj || {!local _unit} || {isPlayer _unit}) exitWith {false};
if ((getNumber (configFile >> "CfgWeapons" >> _weapon >> "type")) isNotEqualTo 4) exitWith {false};
private _ac = configFile >> "CfgAmmo" >> _ammo;
if ((getNumber (_ac >> "weaponLockSystem")) > 0 || {(getNumber (_ac >> "maxControlRange")) > 0}) exitWith {false};

_unit setVariable [QGVAR(rpgAtisT), time];   // v8.754: roket atis zamani (karar sonucu icin)
private _say = missionNamespace getVariable ["lambs_danger_rpgSay", createHashMap];
missionNamespace setVariable ["lambs_danger_rpgSay", _say];

// dusus noktasi
private _p0 = getPosASL _proj;
private _vel = velocity _proj;
private _vm = vectorMagnitude _vel;
private _dir = if (_vm > 1) then { _vel vectorMultiply (1 / _vm) } else { eyeDirection _unit };
private _son = _p0 vectorAdd (_dir vectorMultiply 800);
private _vur = lineIntersectsSurfaces [_p0, _son, _unit, _proj, true, 1, "FIRE", "NONE"];
private _imp = if (_vur isNotEqualTo []) then { (_vur select 0) select 0 } else { _son };
private _ti = terrainIntersectAtASL [_p0, _son];
if (_ti isNotEqualTo [0, 0, 0] && {(_p0 distance _ti) < (_p0 distance _imp)}) then { _imp = _ti; };
private _yon = (_dir select 0) atan2 (_dir select 1);
private _taraf = side group _unit;

// hedef turu (dususun 15 m'si)
private _yakin = ((ASLToAGL _imp) nearEntities [["CAManBase", "LandVehicle", "StaticWeapon"], 15]) select {alive _x && {(_taraf getFriend (side group _x)) < 0.6} && {(side group _x) isNotEqualTo civilian}};
private _zirh = (_yakin findIf {(_x isKindOf "Tank") || {_x isKindOf "APC"} || {_x isKindOf "Wheeled_APC_F"}}) >= 0;
private _arac = (_yakin findIf {_x isKindOf "LandVehicle"}) >= 0;
private _tur = if (_zirh) then {"zirh"} else { if (_arac) then {"arac"} else { if ((_yakin findIf {_x isKindOf "CAManBase" && {(insideBuilding _x) > 0.5}}) >= 0) then {"bina ici dusman"} else { if (_yakin isNotEqualTo []) then {"piyade"} else {"hedef yok / nokta"} } } };

// v8.747 REZERV MUAFIYETI: atici hedefi (atanmis / saldiri) arac / hava ise ya da dususun 15 m'sinde dusman arac / sabit silah varsa roket piyadeye harcanmis sayilmaz
private _ah = assignedTarget _unit;
if (isNull _ah) then { _ah = getAttackTarget _unit; };
private _ahMuaf = !isNull _ah && {alive _ah} && {(_taraf getFriend (side group _ah)) < 0.6} && {(_ah isKindOf "Air") || {_ah isKindOf "LandVehicle"}};
private _neden = [_unit, _weapon, _yon, _imp, _arac || _ahMuaf || {[_unit, "apMi", _ammo] call FUNC(rpgMuhimmat)}, true] call FUNC(rpgGuvenli);   // AP (piyadeye uygun) roket rezervden muaf
private _kaynak = ["motor", "karar"] select ((time - (_unit getVariable [QGVAR(rpgKararT), -999])) < 10);
private _dI = _unit distance _imp;

if (_neden isNotEqualTo "") then {
    deleteVehicle _proj;
    _unit setVariable [QGVAR(rpgBekleT), time + 12];
    [{
        params ["_u", "_w", "_m"];
        if (alive _u && {(secondaryWeapon _u) isEqualTo _w}) then {
            if ((_u ammo _w) <= 0) then { _u setAmmo [_w, 1]; } else { _u addMagazine _m; };
        };
    }, [_unit, _weapon, _mag], 12] call CBA_fnc_waitAndExecute;
    private _k = format ["iptal_%1", _neden];
    _say set [_k, (_say getOrDefault [_k, 0]) + 1];
    private _n = missionNamespace getVariable ["lambs_danger_rpgIptalLogN", 0];
    if (_n < 40) then {
        missionNamespace setVariable ["lambs_danger_rpgIptalLogN", _n + 1];
        diag_log format ["[RPG-IPTAL] %1 | %2 | %3 (%4) | neden: %5 | dusus %6 m | dusus hedefi: %7 | kaynak: %8 | mermi 12 sn sonra geri verilir", groupId group _unit, name _unit, _weapon, _ammo, _neden, round _dI, _tur, _kaynak];
    };
} else {
    // v8.761 ISABET DUZELTMESI (kullanici: 'eleman tutturamiyor acil duzelt'): gudumsuz roketin cikis yonu hedefin ONGORULEN konumuna (hiz x ucus suresi + yercekimi payi) CBA rpgIsabetDuzeltme (0.85) orani kadar cevrilir (botIsabet mermi duzeltmesi gibi); hedef: karar katmani hedefi (son 12 sn) ya da atanmis / saldiri hedefi
    // HILESIZ (kullanici: 'hilesiz olsun accuracy ayarina baksin'): duzeltme orani ve ongoru TIRADOR BECERISINE (aimingAccuracy; CBA 'ELITE bot becerisi' isabet ayarlari) bagli; dusuk beceri = az duzeltme + rastgele sapma konisi
    private _acc = (_unit skill "aimingAccuracy") max 0 min 1;
    private _dz = (((missionNamespace getVariable ["lambs_danger_rpgIsabetDuzeltme", 0.85]) max 0) min 1) * _acc;
    if (_dz > 0 && {_vm > 1}) then {
        private _t = _unit getVariable [QGVAR(rpgHedef), objNull];
        if (isNull _t || {(time - (_unit getVariable [QGVAR(rpgKararT), -999])) > 12} || {!alive _t}) then { _t = assignedTarget _unit; if (isNull _t) then { _t = getAttackTarget _unit; }; };
        if (!isNull _t && {alive _t} && {(_taraf getFriend (side group _t)) < 0.6} && {((getPosASL _proj) distance (aimPos _t)) < 700}) then {
            private _pp = getPosASL _proj;
            private _hp = aimPos _t;
            private _tf = (((_pp distance _hp) / (_vm max 80)) min 6);
            private _gp = (_hp vectorAdd ((velocity _t) vectorMultiply (_tf * _acc))) vectorAdd [0, 0, 0.5 * 9.81 * _tf * _tf * 0.35 * _acc];   // ongoru + dusme payi becerisiyle olceklenir
            private _dirT = vectorNormalized (_gp vectorDiff _pp);
            private _dirN = vectorNormalized (velocity _proj);
            private _dirY = vectorNormalized ((_dirN vectorMultiply (1 - _dz)) vectorAdd (_dirT vectorMultiply _dz));
            private _sap = acos ((((_dirN vectorDotProduct _dirT) min 1) max -1));
            private _yan = _dirY vectorCrossProduct [0, 0, 1];
            // rastgele sapma konisi: (1 - beceri) x 2.5 derece (yaw / pitch)
            if ((vectorMagnitude _yan) > 0.01) then {
                private _hata = (1 - _acc) * 2.5;
                private _yn = vectorNormalized _yan;
                private _yu = _yn vectorCrossProduct _dirY;
                _dirY = vectorNormalized (_dirY vectorAdd (_yn vectorMultiply ((((random 2) - 1) * (sin _hata)))) vectorAdd (_yu vectorMultiply ((((random 2) - 1) * (sin _hata)))));
                _yan = _dirY vectorCrossProduct [0, 0, 1];
            };
            if ((vectorMagnitude _yan) > 0.01) then {
                _proj setVelocity (_dirY vectorMultiply _vm);
                _proj setVectorDirAndUp [_dirY, _yan vectorCrossProduct _dirY];
                private _sy = missionNamespace getVariable ["lambs_danger_rpgSay", createHashMap];
                _sy set ["isabet_duzeltme", (_sy getOrDefault ["isabet_duzeltme", 0]) + 1];
                private _ln = missionNamespace getVariable ["lambs_danger_rpgDuzLogN", 0];
                if (_ln < 30) then { missionNamespace setVariable ["lambs_danger_rpgDuzLogN", _ln + 1]; diag_log format ["[RPG-DUZELTME] %1 | %2 | hedef %3 %4 m | sapma %5 derece -> orani %6 (beceri %9) | ucus %7 sn | hedef hizi %8 m/sn", groupId group _unit, name _unit, typeOf _t, round (_pp distance _hp), _sap toFixed 1, _dz toFixed 2, _tf toFixed 1, (vectorMagnitude (velocity _t)) toFixed 1, _acc toFixed 2]; };
            };
        };
    };
    private _k = format ["atis_%1", _kaynak];
    _say set [_k, (_say getOrDefault [_k, 0]) + 1];
    private _kt = format ["hedef_%1", _tur];
    _say set [_kt, (_say getOrDefault [_kt, 0]) + 1];
    private _n = missionNamespace getVariable ["lambs_danger_rpgAtisLogN", 0];
    if (_n < 60) then {
        missionNamespace setVariable ["lambs_danger_rpgAtisLogN", _n + 1];
        diag_log format ["[RPG-ATIS] %1 | %2 | %3 (%4) | aiAmmoUsageFlags %5 | dusus %6 m | dusus hedefi: %7 | kaynak: %8 | kalan roket %9", groupId group _unit, name _unit, _weapon, _ammo, getNumber (_ac >> "aiAmmoUsageFlags"), round _dI, _tur, _kaynak, (_unit ammo _weapon) + ({(toLower (_x select 0)) in ((compatibleMagazines _weapon) apply {toLower _x})} count (magazinesAmmo _unit))];
    };
};

private _ot = missionNamespace getVariable ["lambs_danger_rpgOzetT", -1];
if (_ot < 0) then { missionNamespace setVariable ["lambs_danger_rpgOzetT", time + 60]; } else {
    if (time > _ot) then {
        missionNamespace setVariable ["lambs_danger_rpgOzetT", time + 60];
        private _nz = (keys _say) select {(_say get _x) > 0};
        if (_nz isNotEqualTo []) then {
            diag_log format ["[RPG-OZET] 60 sn: %1", (([_nz, [], {_x}, "ASCEND"] call BIS_fnc_sortBy) apply { format ["%1=%2", _x, _say get _x] }) joinString " "];
        };
        { _say set [_x, 0]; } forEach (keys _say);
    };
};
_neden isNotEqualTo ""
