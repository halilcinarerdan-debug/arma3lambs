#include "script_component.hpp"
/*
 * Author: Cinar (ELITE fork)
 * HELIKOPTERE KARSI KATMAN (v8.387; kullanici: 'lambs rpg ile uyumlu hale getir, helikoptere karsi katman ekle, piyade ve anti air icin doktrinlere gore ne ekleyebiliriz'). fnc_havaFarkindalik'in her turunda (3 sn)
 * silahli helikopter hedefi secilen grup icin AKTIF hava savunmasi: (A) AA ekibi, (B) alcak / asili helikoptere roketatar.
 *
 * DOKTRIN (kaynaklar_doktrin/ATP_3-01.8_2016; SAYISAL ESIKLER [T] = tasarim tahmini, kitapta sayi yok):
 *   - Ates kontrol durumu (2-13): Weapons-Tight (varsayilan: yalniz dusman olarak TANIMLI silahli heli) ya da Weapons-Hold (yalniz hostile act: heli son 20 sn ates etti / hover / grupta baski) - CBA 'lambs_danger_havaAAHold'.
 *   - Hover eden saldiri helisi buyuk olasilikla fuze atmaya hazirlaniyor (4-43): oncelikli; ucus yolu uzerinde gecen heli ikinci planda (ayni kural, daha kisa menzil).
 *   - (A) AA ekibi: aiAmmoUsageFlags HAVA olan omuz fuzesi (Stinger / Titan AA / Igla / Strela, RHS / CUP dahil; ad tabanli yedek) - 150 m ile (fuze kilit menzili x 0.85, yoksa 2000 m [T]) arasi, gorus hatti acik,
 *     arkasi 8 m / 60 derece'de dost ya da 4 m'de duvar yok, binanin icinde degil; secilen silah -> doTarget -> 3-5 sn sonra doFire; birim basina 12 sn, grup basina tur basina en cok 2 atici;
 *     ATESTEN 10 sn SONRA ALTERNATIF POZISYON (findCover SURVIVE, 40 m): ates eden mevzi helikopterin gorus / ates noktasi olur, ayni yerde kalinmaz [T] (kitapta MANPADS atis-sonrasi yer degistirme dogrudan yok; genel pasif onlem: gizlen / dagil 3-5..3-9).
 *   - (B) Roketatar (AT; aiAmmoUsageFlags arac / zirh): YALNIZ kilitsiz (yonlendirmesiz) roket (maxControlRange 0, kilit sistemi 0: RPG-7 / RPG-32 / M72 sinifi) ve helikopter HOVER'da ya da alcakta-yavas (<= 25 m, < 12 m/sn)
 *     VE <= 350 m [T]; CBA 'lambs_danger_havaATAktif'. Yonlendirmeli AT (Titan AT, Javelin) helikoptere atilmaz (kilit tutmaz). Ayni arka-patlama / hat / duvar kontrolleri.
 *   - dronAtesIzin kapisi (sessizlik / recon / CBA dronAtesModu) korunur: sessiz / gizli grup ates edip konumunu vermez (3-4).
 *   LAMBS RPG (config modu) yuklu ve hava yetenekli roketatar varsa AI kendi kurallariyla da ates edebilir; bu fonksiyon ona EK olarak komut verir (cift ates yok: birim 12 sn cooldown).
 * Log: [HAVA-AA] (ilk 120). Kapatma: CBA 'lambs_danger_havaAAAktif' ya da lambs_danger_havaAAOff = true.
 *
 * Arguments:
 * 0: Grup <GROUP>
 * 1: Hedef (helikopter) <OBJECT>
 * 2: Lider - hedef yatay mesafe m <NUMBER>
 * 3: Hover (silahli, asili) <BOOL>
 * 4: Saldiri (son 20 sn ates / baski + 800 m) <BOOL>
 * 5: Silahli <BOOL>
 *
 * Return Value: Komut verilen atici sayisi <NUMBER>
 * Public: No
*/

params [["_g", grpNull, [grpNull]], ["_hedef", objNull, [objNull]], ["_hd", 0, [0]], ["_hover", false, [false]], ["_saldiri", false, [false]], ["_silahli", false, [false]]];
if (isNull _g || {isNull _hedef} || {!alive _hedef} || {unitIsUAV _hedef} || {!_silahli}) exitWith {0};
if (!(missionNamespace getVariable ["lambs_danger_havaAAAktif", true]) || {missionNamespace getVariable ["lambs_danger_havaAAOff", false]}) exitWith {0};

// ates kontrol durumu: Hold = yalniz hostile act (ates / hover / baski)
if ((missionNamespace getVariable ["lambs_danger_havaAAHold", false]) && {!_saldiri} && {!_hover}) exitWith {0};
if !([_g, _hedef, (leader _g) distance _hedef] call FUNC(dronAtesIzin)) exitWith {0};

private _lrpg = [] call FUNC(lambsRpgMi);
private _aaFlag = [units _g, AI_AMMO_USAGE_FLAG_AIR, true] call EFUNC(main,getLauncherUnits);
if !(_aaFlag isEqualType []) then { _aaFlag = []; };
// ad tabanli yedek (eski liste): flags'i bos olan modlar icin
private _aaAd = (units _g) select {alive _x && {(magazines _x) findIf {private _m = toLower _x; (_m find "stinger") >= 0 || {(_m find "strela") >= 0} || {(_m find "igla") >= 0} || {(_m find "fim92") >= 0} || {(_m find "zipkin") >= 0} || {(_m find "zıpkın") >= 0} || {(_m find "_aa") >= 0}} >= 0}};
private _aaTum = _aaFlag + (_aaAd select {!(_x in _aaFlag)});
private _atTum = [];
if (missionNamespace getVariable ["lambs_danger_havaATAktif", true]) then {
    _atTum = [units _g, AI_AMMO_USAGE_FLAG_VEHICLE + AI_AMMO_USAGE_FLAG_ARMOUR] call EFUNC(main,getLauncherUnits);
    if !(_atTum isEqualType []) then { _atTum = []; };
    _atTum = _atTum select {!(_x in _aaTum)};
};
if (_aaTum isEqualTo [] && {_atTum isEqualTo []}) exitWith {0};

private _hAlt = (getPosATL _hedef) select 2;
private _alcak = _hover || {_hAlt <= 25 && {(speed _hedef) < 12}};
private _hASL = getPosASL _hedef;
private _verilen = 0;
private _sira = _aaTum apply {[_x, "AA"]};
_sira append (_atTum apply {[_x, "AT"]});

{
    _x params ["_u", "_tur"];
    if (_verilen >= 2) exitWith {};
    if (
        !alive _u || {!local _u} || {isPlayer _u} || {!isNull objectParent _u} || {!((lifeState _u) in ["HEALTHY", "INJURED"])} || {_u getVariable ["ACE_isUnconscious", false]}
        || {time < (_u getVariable [QGVAR(tcccBusy), 0])} || {(time - (_u getVariable [QGVAR(hvAAT), -999])) < 12} || {_u getVariable [QGVAR(forceMove), false]}
        || {(insideBuilding _u) >= 0.5}
    ) then { continue };
    private _ls = secondaryWeapon _u;
    if (_ls isEqualTo "" || {(_u ammo _ls) <= 0}) then { continue };
    private _mag = (secondaryWeaponMagazine _u) param [0, ""];
    private _ammo = if (_mag isEqualTo "") then {""} else { getText (configFile >> "CfgMagazines" >> _mag >> "ammo") };
    private _d3 = _u distance _hedef;
    private _menzil = 2000;
    if (_tur isEqualTo "AA") then {
        private _kil = if (_ammo isEqualTo "") then {0} else { getNumber (configFile >> "CfgAmmo" >> _ammo >> "missileLockMaxDistance") };
        if (_kil > 0) then { _menzil = _kil * 0.85; };
        if (_d3 < 150 || {_d3 > _menzil}) then { continue };
    } else {
        // roketatar: yalniz kilitsiz roket + alcak / asili heli + 350 m
        if (!_alcak || {_d3 > 350} || {_d3 < 40}) then { continue };
        if (_ammo isEqualTo "" || {(getNumber (configFile >> "CfgAmmo" >> _ammo >> "maxControlRange")) > 0} || {(getNumber (configFile >> "CfgAmmo" >> _ammo >> "weaponLockSystem")) > 0}) then { continue };
    };
    // gorus hatti + arka-patlama guvenligi
    private _eye = eyePos _u;
    if (terrainIntersectASL [_eye, _hASL] || {lineIntersects [_eye, _hASL, _u, _hedef]}) then { continue };
    private _yon = _u getDir _hedef;
    private _arka = (getPosASL _u) vectorAdd [-(sin _yon) * 4, -(cos _yon) * 4, 1.2];
    if (lineIntersects [(getPosASL _u) vectorAdd [0, 0, 1.2], _arka, _u]) then { continue };
    if (((_u nearEntities ["CAManBase", 8]) findIf {_x isNotEqualTo _u && {alive _x} && {((side group _x) getFriend (side _g)) >= 0.6} && {(abs (((_u getRelDir _x) + 180) mod 360 - 180)) >= 120}}) >= 0) then { continue };

    _u setVariable [QGVAR(hvAAT), time];
    _g reveal [_hedef, 4];
    if !(missionNamespace getVariable ["lambs_danger_silahDegisimOff", false]) then { [_u, _ls] call CBA_fnc_selectWeapon; };
    _u doTarget _hedef;
    [{ params ["_uu", "_tt"]; if (alive _uu && {alive _tt} && {isNull objectParent _uu}) then { _uu doFire _tt; }; }, [_u, _hedef], 3 + (random 2)] call CBA_fnc_waitAndExecute;
    // atistan sonra alternatif pozisyon (mevzide / hendekte olan grup yer degistirmez)
    if (!([_g] call FUNC(mevziTutMu))) then {
        [{
            params ["_uu", "_tt"];
            if (alive _uu && {isNull objectParent _uu} && {!isNull _tt}) then {
                private _cv = [_uu, _tt, 40, "ASCEND", 1, "SURVIVE"] call EFUNC(main,findCover);
                if (_cv isNotEqualTo []) then { _uu doMove ((_cv select 0) select 0); };
            };
        }, [_u, _hedef], 10] call CBA_fnc_waitAndExecute;
    };
    _verilen = _verilen + 1;
    if (isNil "lambs_danger_havaAALogN") then { lambs_danger_havaAALogN = 0; };
    if (lambs_danger_havaAALogN < 120) then {
        lambs_danger_havaAALogN = lambs_danger_havaAALogN + 1;
        diag_log format ["[HAVA-AA] %1 | %2 (%3) -> %4 %5 m (alt %6 m, %7 m/sn) | hover:%8 saldiri:%9 | mermi:%10 | menzil %11 m | LAMBS RPG:%12", groupId _g, name _u, _tur, typeOf _hedef, round _d3, round _hAlt, round (speed _hedef / 3.6), _hover, _saldiri, _ammo, round _menzil, _lrpg];
    };
} forEach _sira;
_verilen
