#include "script_component.hpp"
/*
 * Author: Cinar (ELITE fork)
 * ZIRH ROTA ENGELLERI (v8.349; kullanici: 'zirh gorus engeli cizgilerini ve bogazlari piyade temizlemeden gecmesin'). Aracin ates pozisyonuna giden dogrusal rotasini 30 m'de bir ornekler ve piyadenin ONCE temizlemesi gereken yerleri bulur:
 *   GORUS CIZGISI (intervisibility line): objektif gozlemcisinden (3 m) rota noktasina (kule yuksekligi 2.4 m) arazi gorusu kapaliyken (terrainIntersectASL) acik hale gectigi ILK nokta = arazinin ortu bitip arac siluetinin dusmana acildigi cizgi (tepe sirti / yamac).
 *     Arac cizginin ONUNDE durur; piyade cizgiyi asar ve ileriyi gozetler, sonra zirh gecer.
 *   GECIT / BOGAZ (defile): rotanin iki yaninda (28 m) su / en az 3 agac-bina-kaya-duvar (10 m'de) / 5 m'den dik yamac bulunan >= 2 ardisik ornek (>= 60 m'lik koridor): kopru, orman yolu, koy ici, yarma.
 *     Arac girisin ONUNDE durur; piyade koridoru temizleyene (gecit cikisini asana) kadar bekler.
 * Kitap: MCWP 3-11.1 satir 8751-8766 (arac / zirh hareketinde gorus engeli cizgileri ve bogazlar: once piyade temizler, zirh ancak sonra gecer; arac araligi arazi ve duruma gore) [K].
 *   Ornekleme araligi (30 m), yan mesafe (28 m), esikler (3 nesne / 5 m yukseklik / 60 m koridor), en cok 3 engel ve >= 100 m ara TASARIM degerleridir [T]; kitapta sayi YOKTUR.
 * Sonuc fnc_zirhBekle tarafindan grup basina onbellege alinir (ates pozisyonu degisince yeniden hesaplanir). Sadece analiz yapar, hic emir vermez.
 *
 * Arguments:
 * 0: Arac <OBJECT>
 * 1: Ates pozisyonu <ARRAY>
 * 2: Objektif <ARRAY>
 *
 * Return Value: [[konum <ARRAY>, tur <STRING> ("GORUS CIZGISI" | "GECIT"), pozisyona kalan mesafe <NUMBER>], ...] rota sirasina gore <ARRAY>
 * Public: No
*/

params [["_v", objNull, [objNull]], ["_poz", [], [[]]], ["_obj", [], [[]]]];
if (isNull _v || {_poz isEqualTo []} || {_obj isEqualTo []}) exitWith {[]};

private _a = getPosATL _v;
private _mesafe = (_a distance2D _poz) min 900;
if (_mesafe < 150) exitWith {[]};
private _yon = _a getDir _poz;
private _n = floor (_mesafe / 30);
private _gozObj = (AGLToASL [_obj select 0, _obj select 1, 0]) vectorAdd [0, 0, 3];

private _cikti = [];
private _ekle = {
    params ["_pp", "_tr"];
    if ((_pp distance2D _poz) > 60 && {(_pp distance2D _a) > 40} && {(_cikti findIf {((_x select 0) distance2D _pp) < 100}) < 0} && {(count _cikti) < 3}) then {
        _cikti pushBack [_pp, _tr, _pp distance2D _poz];
    };
};

private _oncekiP = _a;
private _oncekiGizli = false;
private _cizgiBulundu = false;
private _kapaliSay = 0;
private _gecitGiris = [];
for "_i" from 0 to _n do {
    private _p = _a getPos [_i * 30, _yon];
    // 1) gorus cizgisi: objektiften gizliydi, simdi acik
    private _gizli = terrainIntersectASL [_gozObj, (AGLToASL [_p select 0, _p select 1, 0]) vectorAdd [0, 0, 2.4]];
    if (_i > 0 && {_oncekiGizli} && {!_gizli} && {!_cizgiBulundu}) then {
        _cizgiBulundu = true;
        [_oncekiP, "GORUS CIZGISI"] call _ekle;
    };
    // 2) gecit: iki yan da kapali
    if (_i > 0) then {
        private _kapali = 0;
        {
            private _sp = _p getPos [28, _yon + _x];
            if (surfaceIsWater _sp || {(count (nearestTerrainObjects [_sp, ["TREE", "BUILDING", "HOUSE", "ROCK", "WALL"], 10, false, true])) >= 3} || {((getTerrainHeightASL _sp) - (getTerrainHeightASL _p)) > 5}) then { _kapali = _kapali + 1; };
        } forEach [90, -90];
        if (_kapali >= 2) then {
            if (_kapaliSay isEqualTo 0) then { _gecitGiris = _oncekiP; };
            _kapaliSay = _kapaliSay + 1;
            if (_kapaliSay isEqualTo 2) then { [_gecitGiris, "GECIT"] call _ekle; };
        } else {
            _kapaliSay = 0;
        };
    };
    _oncekiP = _p;
    _oncekiGizli = _gizli;
};
_cikti
