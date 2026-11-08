#include "script_component.hpp"
/*
 * Author: Cinar (ELITE fork)
 * ARAC ETKIN HASAR (v8.500t; kullanici: 'rhs farkli hp sistemi kullaniyor, crew uyumlu olsun, ace icin de, CBA ile opsiyonel').
 *
 * NEDEN: murettebat terki, sur(ucu) yenileme, nakil / tank / plan kararlari araci 'damage _v' esikleriyle (0.45 .. 0.9) degerlendiriyordu. RHS ve ACE (vehicle damage / cookoff) zirhli aracta govde / motor / yakit
 *   hitpoint'lerini ayri isler; genel 'damage' degeri dusuk kalirken arac fiilen olu olabilir ya da tersi. ETKIN HASAR = genel damage ile govde / motor / yakit / cephanelik hitpoint'lerinin EN YUKSEGI.
 * CBA 'RHS / ACE arac hasar uyumu' (lambs_danger_rhsAceUyum, varsayilan KAPALI) kapaliyken yalniz damage _v doner (eski davranis, bilincli).
 * Hitpoint ADLARINA gore calisir (sinif adina degil): hull / body / engine / fuel / ammo icerenler; mod ve ACE sinif ailesi fark etmez.
 *
 * Arguments:
 * 0: Arac <OBJECT>
 *
 * Return Value: 0..1 etkin hasar <NUMBER>
 * Public: No
*/

params [["_v", objNull, [objNull]]];
if (isNull _v) exitWith {0};
private _d = damage _v;
if !(missionNamespace getVariable ["lambs_danger_rhsAceUyum", false]) exitWith {_d};
private _hp = getAllHitPointsDamage _v;
if (_hp isEqualTo [] || {(count _hp) < 3}) exitWith {_d};
private _adlar = _hp select 0;
private _deger = _hp select 2;
private _en = _d;
{
    private _n = toLower _x;
    private _val = _deger param [_forEachIndex, 0];
    if (_val isEqualType 0 && {((_n find "hull") >= 0) || {(_n find "body") >= 0} || {(_n find "engine") >= 0} || {(_n find "fuel") >= 0} || {(_n find "ammo") >= 0}}) then {
        _en = _en max _val;
    };
} forEach _adlar;
_en min 1
