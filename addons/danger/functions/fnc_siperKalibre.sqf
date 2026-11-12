#include "script_component.hpp"
/*
 * Author: Cinar (ELITE fork)
 * SIPER KALIBRASYONU (HARITAYA GORE) (v8.515; kullanici: 'hala cok acikta siper aliyorlar, bence bu terrain ile alakali').
 * Neden: 'siperde mi?' testleri (fnc_coverHug / fnc_doCover / fnc_acikSiper) mermi geometrisini (FIRE LOD) ve govde genisligini (+-0.25 m yan isinlar) olcer. Harita agaclari (ozellikle Arma 2 tarzi
 * Chernarus: t_picea3f / t_fagus2f) INCE govdeli ya da FIRE LOD'u zayif / hic olmayabilir: 242 agacli ormanda ([YAPRAK-TANI] 150 m: TREE 242) 'govde genisliginde kapali yuzey yok' -> kimse siperde sayilmiyor.
 * Bu fonksiyon mission basinda (30 sn sonra; agac yoksa 45 sn'de bir, en cok 6 kez) oyuncunun / bir AI liderinin cevresindeki en yakin 16 agaci OLCER: govde yuksekliginde (1.1 m) 3 m'den 8 yonden,
 * 0.04 m adimlarla +-0.8 m yanal tarama; nesnenin FIRE LOD'una carpan isin sayisi = govde genisligi. Sonuc:
 *   lambs_danger_siperGovde = govde genisligi medyani / 2 (0.05 - 0.25 m)  -> yan isin toleransi (ince govdeli haritada gevsek)
 *   lambs_danger_siperLod   = "FIRE" (agaclarin >= %30'unda FIRE LOD var) ya da "VIEW" (yoksa: gorus keserek 'siper' sayilir)
 * Log: [AGAC-TANI] harita | agac sayisi | FIRE LOD'lu % | govde genisligi medyan | yon | ornek modeller.  Kapatma: lambs_danger_siperKalibreOff = true (varsayilan 0.25 / FIRE).
 *
 * Arguments: None
 * Return Value: Baslatildi mi <BOOL>
 * Public: No
*/

if (!isNil "lambs_danger_siperKalibreStarted") exitWith {false};
lambs_danger_siperKalibreStarted = true;

[] spawn {
    sleep 30;
    for "_deneme" from 1 to 6 do {
        if (missionNamespace getVariable ["lambs_danger_siperKalibreOff", false]) exitWith {};
        private _kaynak = objNull;
        { if (!isNull _x && {alive _x}) exitWith { _kaynak = _x; }; } forEach (allPlayers + ((allGroups select {(side _x) in [west, east, resistance] && {!isNull leader _x}}) apply {leader _x}));
        if (isNull _kaynak) then { sleep 45; continue };
        private _agaclar = nearestTerrainObjects [_kaynak, ["TREE"], 90, true, true];
        _agaclar = _agaclar select [0, 16];
        if ((count _agaclar) < 6) then { sleep 45; continue };
        private _genislikler = [];
        private _modeller = [];
        private _fireVar = 0;
        {
            private _o = _x;
            private _c = getPosASL _o;
            private _hh = (_c select 2) + 1.1;
            private _olc = [];
            for "_i" from 0 to 7 do {
                private _yon = _i * 45;
                private _bas = [(_c select 0) + (sin _yon) * 3, (_c select 1) + (cos _yon) * 3, _hh];
                private _perp = [cos _yon, -(sin _yon), 0];
                private _say = 0;
                for "_k" from -20 to 20 do {
                    private _b = _bas vectorAdd (_perp vectorMultiply (_k * 0.04));
                    private _e = [(_c select 0) + (_perp select 0) * (_k * 0.04), (_c select 1) + (_perp select 1) * (_k * 0.04), _hh];
                    private _vur = lineIntersectsSurfaces [_b, _e, objNull, objNull, true, 3, "FIRE", "NONE"];
                    if ((_vur findIf {(_x select 2) isEqualTo _o}) > -1) then { _say = _say + 1; };
                };
                _olc pushBack (_say * 0.04);
            };
            _olc sort true;
            private _w = (_olc select 4) max 0;   // medyan yon
            _genislikler pushBack _w;
            if (_w > 0.04) then { _fireVar = _fireVar + 1; };
            if ((count _modeller) < 3) then { _modeller pushBackUnique ((getModelInfo _o) select 0); };
        } forEach _agaclar;
        _genislikler sort true;
        private _n = count _genislikler;
        private _wMed = _genislikler select (floor (_n / 2));
        private _fireOran = _fireVar / _n;
        private _govde = ((_wMed / 2) max 0.05) min 0.25;
        private _lod = ["VIEW", "FIRE"] select (_fireOran >= 0.3);
        missionNamespace setVariable ["lambs_danger_siperGovde", _govde];
        missionNamespace setVariable ["lambs_danger_siperLod", _lod];
        diag_log format ["[AGAC-TANI] harita %1 | %2 agac olculdu | FIRE LOD'lu %3 %% | govde genisligi medyan %4 m (maks %5 m) | -> yan isin toleransi +-%6 m, siper LOD %7 | ornek: %8", worldName, _n, round (_fireOran * 100), _wMed toFixed 2, (_genislikler select (_n - 1)) toFixed 2, _govde toFixed 2, _lod, _modeller joinString ", "];
        break;
    };
};
true
