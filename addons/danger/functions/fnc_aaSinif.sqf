#include "script_component.hpp"
/*
 * Author: Cinar (ELITE fork)
 * ANTI-AIR (HAVA SAVUNMA) SINIFLANDIRMASI (v8.399; kullanici: 'anti air tanimlansin sisteme, ona gore konumlandirilsin karakolda ya da objektifte, mesela zipkin AA sistemi; statik ZSU olduğu yerde kalabilir').
 * Nesnenin hava savunma TURUNU soyler:
 *   "MANPADS" : omuz fuzesi tasiyan piyade (aiAmmoUsageFlags HAVA: Stinger / Igla / Strela / Titan AA / Zipkin ...; flags bossa mermi adi: stinger / strela / igla / fim92 / mistral / starstreak / zipkin / _aa)
 *   "SPAAG"   : kendiyurur hava savunma araci (ZSU-23-4 / Tunguska / Gepard / Pantsir / Tor / Avenger sinifi): kara araci (statik degil) VE (kilitli hava hedefi fuzesi: CfgAmmo airLock > 0 ya da ad: zsu / shilka / tunguska / pantsir / tor-m / gepard / avenger / stormer / anti-air / flak / zipkin / ' aa')
 *   "STATIK"  : ayni olcutlerle STATIK silah (ZU-23, statik Stinger / Zipkin kuyusu): YERINDE KALIR, tasinmaz / mevzi degistirmez
 *   ""        : hava savunma degil
 * Elle tanim (oncelik sirasi): nesne degiskeni lambs_danger_aa = "MANPADS" / "SPAAG" / "STATIK" / "NONE" (3DEN init: this setVariable ["lambs_danger_aa", "SPAAG", true]); sinif tablosu lambs_danger_aaOverride (HashMap sinif -> tur); otomatik.
 * NOT: otomatik tespit sinif adi / config'e dayanir; modlarin AA araclari farkli adlandirilmis olabilir (yanlis / eksik tespitte elle tanimla). Zipkin modunun sinif adlari bilinmiyor: 'zipkin' / 'zipkin' adi + airLock fuzesi aranir.
 *
 * Arguments:
 * 0: Nesne (asker / arac / statik silah) <OBJECT>
 *
 * Return Value: "MANPADS" / "SPAAG" / "STATIK" / "" <STRING>
 * Public: No
*/

params [["_o", objNull, [objNull]]];
if (isNull _o) exitWith {""};

private _ov = _o getVariable ["lambs_danger_aa", ""];
if (_ov isNotEqualTo "") exitWith { if (_ov isEqualTo "NONE") then {""} else {_ov} };
private _hm = missionNamespace getVariable ["lambs_danger_aaOverride", createHashMap];
private _cls = typeOf _o;
if (_cls in _hm) exitWith { _hm get _cls };

private _mad = ["zipkin", "zıpkın", "stinger", "strela", "igla", "fim92", "fim-92", "mistral", "starstreak"];

if (_o isKindOf "CAManBase") exitWith {
    private _fl = [[_o], AI_AMMO_USAGE_FLAG_AIR, true] call EFUNC(main,getLauncherUnits);
    if (_fl isEqualType [] && {_o in _fl}) exitWith {"MANPADS"};
    if (((magazines _o) findIf {private _m = toLower _x; ((_mad findIf {(_m find _x) >= 0}) >= 0) || {(_m find "_aa") >= 0}}) >= 0) exitWith {"MANPADS"};
    ""
};

// arac / statik: kilitli hava hedefi fuzesi ya da ad
private _ad = toLower (_cls + " " + getText (configOf _o >> "displayName"));
private _adTok = ["zsu", "shilka", "tunguska", "pantsir", "tor-m", "gepard", "avenger", "stormer", "anti-air", "antiair", "flak", "zipkin", "zıpkın", "zu-23", "zu23", "zpu", "zsu-23", " aa", "_aa", "(aa)"];
private _hava = ((_adTok findIf {(_ad find _x) >= 0}) >= 0)
    || {((magazinesAllTurrets _o) findIf {private _am = getText (configFile >> "CfgMagazines" >> (_x select 0) >> "ammo"); _am isNotEqualTo "" && {(getNumber (configFile >> "CfgAmmo" >> _am >> "airLock")) > 0}}) >= 0};
if (!_hava) exitWith {""};
if (_o isKindOf "StaticWeapon") exitWith {"STATIK"};
if (_o isKindOf "LandVehicle") exitWith {"SPAAG"};
""
