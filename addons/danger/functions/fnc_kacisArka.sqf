#include "script_component.hpp"
/*
 * Author: Cinar (ELITE fork)
 * KACIS ARKA ALAN TARAMASI (v8.814; kullanici: 'oldu bu sefer ama kotu pozisyondaydi; arkada su vardi'; RPT 3b3bf4bd v8.813: TEMAS-KES Alpha 1-2 tek kalan asker 'kacis yonu 233, hedef 25 m, gizli puan 43' secti; 33 sn sonra 'sipere vardi';
 *   kacis noktasi suyun kenarinda cikmaz bir yerdi: aday yalniz KENDI noktasinin su olup olmadigina bakiliyordu (surfaceIsWater _c), noktanin ARKASINDA kacacak yer olup olmadigina bakilmiyordu).
 * Bir kacis / geri cekilme adayinin (konum) kacis yonundeki ARKA ALANini olcer: adaydan kacis yonunun 12 / 25 / 40 m ilerisinde, -30 / 0 / +30 derece yelpazesinde 9 ornek; her ornek SU ya da DIK YAMAC (adaya gore yukseklik farki > 0.45 x mesafe + 1.5 m)
 * ise 'kapali' sayilir. Senkron, isinsiz (yuzey / arazi yuksekligi ornekleri): ucuz.
 * Cagiranlar puandan (1 - kara orani) x CBA kacisArkaCeza (40) + orta hat kapaliysa 15 dusurur: su kenarina / ucuruma yaslanan cikmaz noktalar elenir, arkasi acik nokta secilir.
 *
 * Arguments:
 * 0: Aday konum (AGL) <ARRAY>
 * 1: Kacis yonu (derece; dusmandan uzaga) <NUMBER>
 *
 * Return Value: [kara orani 0-1, su sayisi, dik sayisi, ornek sayisi, orta hat (0 derece, 25 m) kapali mi <BOOL>]
 * CBA: lambs_danger_kacisArkaTara (acik / kapali; kapaliysa [1, 0, 0, 0, false]), lambs_danger_kacisArkaCeza
 * Public: No
*/

params [["_c", [], [[]]], ["_dir", 0, [0]]];
if ((count _c) < 2 || {!(missionNamespace getVariable ["lambs_danger_kacisArkaTara", true])}) exitWith {[1, 0, 0, 0, false]};
private _su = 0;
private _dik = 0;
private _n = 0;
private _orta = false;
private _h0 = getTerrainHeightASL [_c select 0, _c select 1];
{
    private _m = _x;
    {
        private _p = _c getPos [_m, _dir + _x];
        _n = _n + 1;
        if (surfaceIsWater _p) then {
            _su = _su + 1;
            if (_x isEqualTo 0 && {_m isEqualTo 25}) then { _orta = true; };
        } else {
            if ((abs ((getTerrainHeightASL [_p select 0, _p select 1]) - _h0)) > ((_m * 0.45) + 1.5)) then {
                _dik = _dik + 1;
                if (_x isEqualTo 0 && {_m isEqualTo 25}) then { _orta = true; };
            };
        };
    } forEach [-30, 0, 30];
} forEach [12, 25, 40];
[1 - ((_su + _dik) / (_n max 1)), _su, _dik, _n, _orta]
