#include "script_component.hpp"
/*
 * Author: Cinar (ELITE fork)
 * KARSI PUSU KURALI (v8.60) — commanderAssess karar akisina takilir (cekilme kilidinden once).
 *
 * Imza (ani temas + zarar): temas oncesi >= 25 sn sakin; temas basladiktan <= 20 sn icinde (kayip >= 2 VEYA baski ortalamasi >= 0.5). Tasarim esikleri: kaynakta sayi YOK.
 * Doktrin ilkesi (genel bilgi; repodaki kaynaklarda ayrintisi yok): yakin pusuda erken ve siddetli karsi saldiri (icinden gec) ile ates alani terk edilir; uzak pusuda ates alanindan cik / ates ustunlugu kur.
 * Tepki:
 *   YAKIN (en yakin dusman <= 50 m) + saglikli (>= 4 asker, kayip orani < 0.4, guc orani >= 0.5)  -> "ASSAULT" (icinden gec)
 *   UZAK (> 50 m) + zayif (< 4 asker VEYA kayip >= 0.4 VEYA guc orani < 0.5)                         -> "DELAY"   (siper al, temas kes)
 *   diger durumlar: kural DOKUNMAZ (yalniz [ZEKA-PUSU] gozlem logu)
 * Ayni pusuda tek tepki (AllClear'e kadar); tepkiden sonra 3 sn 'karar taahhudu' atlanir (zekaPusuT).
 * Kapatma: lambs_danger_pusuKarsiOff = true.   Log: [ZEKA-PUSU]
 *
 * Arguments:
 * 0: Grup <GROUP>
 * 1: Mevcut karar <STRING>
 * 2: Baglam <ARRAY> [ownCount, enemyCount, closest, pwrRatio, suppAvg, lossRatio]
 *
 * Return Value:
 * [yeniKarar, sebep] veya [] (dokunma) <ARRAY>
 *
 * Public: No
*/

params [["_g", grpNull, [grpNull]], ["_karar", "", [""]], ["_ctx", [], [[]]]];
if (isNull _g || {missionNamespace getVariable ["lambs_danger_pusuKarsiOff", false]} || {(count _ctx) < 6}) exitWith {[]};
_ctx params ["_own", "_enemy", "_closest", "_pwr", "_supp", "_loss"];

private _bas = _g getVariable [QGVAR(zekaTemasBas), -999];
if (_bas < 0 || {(time - _bas) > 20}) exitWith {[]};
if ((_g getVariable [QGVAR(zekaPusuT), -999]) > _bas) exitWith {[]};   // bu temas icin zaten tepki verildi

private _sakin = _bas - (_g getVariable [QGVAR(zekaSakinT), -99999]);
private _kayip = (_g getVariable ["lambs_danger_olaySay_Casualty", 0]) - (_g getVariable [QGVAR(zekaTemasKayip0), 0]);
private _ani = _sakin >= 25;
private _isaret = (_kayip >= 2) || {_supp >= 0.5};
if (!(_ani && _isaret)) exitWith {[]};

private _yakin = _closest <= 50;
private _saglikli = (_own >= 4) && {_loss < 0.4} && {_pwr >= 0.5};
private _sonuc = [];
if (_yakin && {_saglikli}) then {
    _sonuc = ["ASSAULT", format ["karsi pusu: yakin (%1 m), kayip %2, baski %3, guc %4 -> icinden gec", round _closest, _kayip, _supp toFixed 2, _pwr toFixed 2]];
};
if (!_yakin && {!_saglikli}) then {
    _sonuc = ["DELAY", format ["karsi pusu: uzak (%1 m) ve zayif (asker %2, kayip orani %3, guc %4) -> siper al, temas kes", round _closest, _own, _loss toFixed 2, _pwr toFixed 2]];
};

private _n = (missionNamespace getVariable ["lambs_danger_zekaLogN", 0]);
if (_n < 120) then {
    missionNamespace setVariable ["lambs_danger_zekaLogN", _n + 1];
    diag_log format ["[ZEKA-PUSU] %1 | ani temas (sakin %2 sn) + zarar (kayip %3, baski %4) | en yakin %5 m | asker %6 dusman %7 guc %8 kayip orani %9 | mevcut karar:%10 | TEPKI:%11",
        groupId _g, round _sakin, _kayip, _supp toFixed 2, round _closest, _own, _enemy, _pwr toFixed 2, _loss toFixed 2, _karar, if (_sonuc isEqualTo []) then {"yok (kural dokunmadi: yakin+zayif / uzak+saglikli)"} else {_sonuc select 0}];
};

if (_sonuc isEqualTo []) exitWith {[]};
_g setVariable [QGVAR(zekaPusuT), time];
missionNamespace setVariable ["lambs_danger_zekaPusuSay", (missionNamespace getVariable ["lambs_danger_zekaPusuSay", 0]) + 1];
_sonuc
