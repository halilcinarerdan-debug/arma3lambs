#include "script_component.hpp"
/*
 * Author: Cinar (ELITE fork)
 * ACIK ARAZIDE ZIKZAK (v8.688; kullanici: 'acik arazide zigzagla ilerlesinler vurulmasi guc olsun, 7-10 metrede zigzag atsinlar').
 * Temasli grupta KOSAN (taktik kosucusu, kendi doMove emri VEYA formasyonu izleyen) asker, gozu acik dusmandan (40 m - zigzagMaxM) gorunuyorsa ve cevresi AÇIK ise
 *   GERCEK hedefine dogru dogrudan gitmez: her ~1.8 sn'de ileri 6-14 m + yana 7-10 m (CBA) ARA NOKTA, yan yon her seferinde ters -> hedefe zikzakla ilerler.
 * GERCEK HEDEF: askerin su anki doMove hedefi (expectedDestination); baska sistem yeni emir verirse (ara noktamiz degil) o yeni gercek hedef olur (emri EZMEZ: zikzak her zaman en son verilen hedefe yoneliktir).
 * BITIS: hedefe < 25 m, asker kosmuyor (hiz < 6 km/sa), forceMove kalkti, dusman gorus disi / yakin (< 40 m), cevre kapali (>= 2 sert nesne 10 m icinde), binada -> zikzak biter; ara noktadaysa gercek hedefe doMove verilir.
 * CBA: lambs_danger_zigzag (acik / kapali), zigzagYanMin / zigzagYanMax (m), zigzagMaxM (dusman azami mesafe). Log: [ZIGZAG] (ilk 20) + 60 sn ozeti.
 *
 * Arguments: None
 * Return Value: Baslatildi mi <BOOL>
 * Public: No
*/

if (!isNil "lambs_danger_zigzagStarted") exitWith {false};
lambs_danger_zigzagStarted = true;
diag_log "[ZIGZAG] acik arazide zikzak (kosan asker 7-10 m yana, ters yon) baslatildi (v8.688)";

[] spawn {
    private _logN = 0;
    private _say = 0;
    private _red = createHashMap;   // v8.690: aday askerin (kosuyor + temasli) NEDEN zikzak yapmadigi sayaclari
    private _ozetT = time + 60;
    while {true} do {
        sleep 0.5;
        if (time > _ozetT) then {
            _ozetT = time + 60;
            if (_say > 0 || {count _red > 0}) then { diag_log format ["[ZIGZAG-OZET] 60 sn: zikzak adimi %1 | aday asker-tur ret nedenleri: %2", _say, (keys _red) apply {format ["%1:%2", _x, _red get _x]}]; };
            _say = 0; _red = createHashMap;
        };
        if !(missionNamespace getVariable ["lambs_danger_zigzag", true]) then { continue };
        private _yMin = ((missionNamespace getVariable ["lambs_danger_zigzagYanMin", 7]) max 3) min 15;
        private _yMax = ((missionNamespace getVariable ["lambs_danger_zigzagYanMax", 10]) max _yMin) min 20;
        private _enMax = ((missionNamespace getVariable ["lambs_danger_zigzagMaxM", 600]) max 100) min 800;   // v8.696: ust sinir 500 -> 800 (CBA kaydirgaci 800'e kadar, varsayilan 600; eskiden sessizce 500'e kirpiliyordu)
        private _ilMax = ((missionNamespace getVariable ["lambs_danger_zigzagIleriMax", 14]) max 4) min 20;
        private _ilMin = ((missionNamespace getVariable ["lambs_danger_zigzagIleriMin", 6]) max 3) min _ilMax;
        private _adimS = ((missionNamespace getVariable ["lambs_danger_zigzagAdimS", 1.8]) max 0.8) min 4;
        private _genis = missionNamespace getVariable ["lambs_danger_zigzagGenis", false];
        private _gCarp = ((missionNamespace getVariable ["lambs_danger_zigzagGenisCarpan", 2]) max 1) min 3;
        private _n = 0;
        {
            private _u = _x;
            if (_n >= 20) exitWith {};
            if (!local _u || {isPlayer _u} || {!alive _u} || {!isNull objectParent _u} || {!((lifeState _u) in ["HEALTHY", "INJURED"])}) then { continue };
            private _son = _u getVariable [QGVAR(zigNokta), []];
            private _g = group _u;
            // zikzak kosullari (v8.690 GENISLETILDI: 'zigzag yok' - taktik bayragi sarti kalkti; temasli grupta kosan her asker: forceMove (taktik kosucusu) YA DA kendi doMove emri (expectedDestination 'DoNotPlan'); formasyon izleyen asker haric)
            private _mod = (expectedDestination _u) select 1;
            private _kosEmir = ((_u getVariable [QGVAR(forceMove), false]) isEqualTo true) || {_mod isEqualTo "DoNotPlan"};
            // v8.695 BAYA GEVSEK (kullanici: 'baya bi gevset gorulur olsun'): temas bayragi / gorus testi YOK; kosan (> 4 km/sa) her asker, bilinen dusman 30 m - zigzagMaxM, cevre cok kapali degilse zikzak yapar
            private _uygun = (speed _u) > 4;
            if (_uygun) then {
                private _neden = "";
                if (isPlayer (leader _g)) then { _neden = "oyuncu liderli grup"; } else {
                if ((insideBuilding _u) >= 0.5) then { _neden = "binada"; } else {
                if ((time - (((_u getVariable [QGVAR(acikSiperHedef), [0, -999]]) param [1, -999]))) < 8 || {(time - (_u getVariable [QGVAR(hugAt), -999])) < 8}) then { _neden = "siper kosusu"; }; }; };
                if (_neden isNotEqualTo "") then { _uygun = false; _red set [_neden, (_red getOrDefault [_neden, 0]) + 1]; };
            };
            private _en = objNull;
            private _ed = 0;
            if (_uygun) then {
                private _neden = "";
                _en = _u findNearestEnemy _u;
                // v8.696: BILINEN dusman yoksa: COMBAT'taki asker icin cevresindeki (zigzagMaxM) dusman taraf askerine (oyuncu dahil, bilinmese de) gore; 2 sn onbellek (RPT 457a400a: ret nedeninin cogu 'dusman yok' = koşan asker dusmani bilmiyordu)
                if ((isNull _en || {!alive _en}) && {(behaviour _u) isEqualTo "COMBAT"}) then {
                    if (time > (_u getVariable [QGVAR(zigEnT), 0])) then {
                        _u setVariable [QGVAR(zigEnT), time + 2];
                        private _yak = (_u nearEntities ["CAManBase", _enMax]) select {alive _x && {((side group _u) getFriend (side group _x)) < 0.6} && {(side group _x) isNotEqualTo civilian}};
                        _u setVariable [QGVAR(zigEn), if (_yak isEqualTo []) then { objNull } else { ([_yak, [], {_u distance2D _x}, "ASCEND"] call BIS_fnc_sortBy) select 0 }];
                    };
                    _en = _u getVariable [QGVAR(zigEn), objNull];
                };
                if (isNull _en || {!alive _en}) then { _neden = "dusman yok"; } else {
                    _ed = _u distance2D _en;
                    if (_ed < 30) then { _neden = "dusman < 30 m"; } else {
                    if (_ed > _enMax) then { _neden = "dusman uzak"; } else {
                    if (count (nearestTerrainObjects [_u, ["TREE", "ROCK", "ROCKS", "WALL", "BUILDING", "HOUSE"], 10, false, true]) >= 6) then { _neden = "cevre cok kapali (>= 6 agac / kaya / duvar / bina)"; }; }; };
                };
                if (_neden isNotEqualTo "") then { _uygun = false; _red set [_neden, (_red getOrDefault [_neden, 0]) + 1]; };
            };
            private _gercek = _u getVariable [QGVAR(zigGercek), []];
            private _ep = (expectedDestination _u) select 0;
            if (_uygun) then {
                // baska sistem yeni emir verdiyse (ara noktamiz degil): o yeni GERCEK hedef
                if (_son isEqualTo [] || {(_ep distance2D _son) > 4}) then {
                    // v8.690: formasyon izleyen asker (kendi emri yok): gercek hedef = formasyon slotu; zikzak bitince doFollowGuvenli ile lidere / formasyona donulur
                    _u setVariable [QGVAR(zigForm), !_kosEmir];
                    _gercek = if (_kosEmir) then { _ep } else { formationPosition _u };
                    _u setVariable [QGVAR(zigGercek), _gercek];
                    _son = [];
                    _u setVariable [QGVAR(zigNokta), nil];
                } else {
                    if (_u getVariable [QGVAR(zigForm), false]) then { _gercek = formationPosition _u; _u setVariable [QGVAR(zigGercek), _gercek]; };
                };
                if (_gercek isEqualTo [] || {(_gercek distance2D [0, 0, 0]) < 5} || {(_u distance2D _gercek) < 14}) then { _uygun = false; };   // v8.697: 25 -> 14 m (bounding sicramalari 22-40 m; 25 m alti kalinca zikzak bitiyordu)
            };
            if (!_uygun) then {
                // zikzak bitti: ara noktamizdaysa gercek hedefe don (baska sistem emir vermediyse)
                if (_son isNotEqualTo [] && {_gercek isNotEqualTo []} && {(_ep distance2D _son) <= 4}) then {
                    if (_u getVariable [QGVAR(zigForm), false]) then { [_u, leader _g] call FUNC(doFollowGuvenli); } else { _u doMove _gercek; };
                };
                if (_son isNotEqualTo []) then { _u setVariable [QGVAR(zigNokta), nil]; };
                if (_son isEqualTo [] || {(_ep distance2D _son) > 4}) then { _u setVariable [QGVAR(zigGercek), nil]; };
                continue
            };
            _n = _n + 1;
            if (time < (_u getVariable [QGVAR(zigT), 0])) then { continue };
            // v8.701 VARIS TABANLI TEMPO (kullanici: 'animasyon hizli olunca zikzak yolu hizli bitiyor, belirgin degil'): sabit adim suresi yerine yeni adim, asker ARA NOKTAYA VARINCA (<= 3.5 m) verilir (en gec zigTmax'ta);
            //   animHiz x1.6 ile asker sabit sureden once varip genligi yarida kesiyordu / yon degistirmeden dogru gidiyordu
            if (_son isNotEqualTo [] && {time < (_u getVariable [QGVAR(zigTmax), 0])} && {(_u distance2D _son) > 3.5}) then { continue };
            private _dir = _u getDir _gercek;
            // v8.696 GENIS ZIKZAK (kullanici: 'eger varsa baya genis alsinlar, adami vurmak cok zor olsun'): 25 m icinde <= 1 sert nesne = AÇIK ARAZI -> yan adim x zigzagGenisCarpan (varsayilan 2: 14-20 m), adim suresi 2.4 sn
            private _acikGenis = _genis && {(count (nearestTerrainObjects [_u, ["TREE", "ROCK", "ROCKS", "WALL", "BUILDING", "HOUSE"], 25, false, true])) <= 1};
            private _yan = ((_yMin + (random (_yMax - _yMin))) * ([1, _gCarp] select _acikGenis)) min ((_u distance2D _gercek) * 0.7);   // v8.697: kisa bacakta yan adim bacak boyunun %70'ini gecmez
            private _isaret = -(_u getVariable [QGVAR(zigYon), 1]);
            private _ileri = (((_u distance2D _gercek) - 8) min (_ilMin + (random (_ilMax - _ilMin)))) max 3;   // v8.699: CBA zigzagIleriMin / Max (varsayilan 6-14); kucuk ileri adim + buyuk yan adim = STRAFE gibi
            private _pt = [];
            for "_t" from 0 to 2 do {
                private _c = (_u getPos [_ileri, _dir]) getPos [_yan * ([1, 1, 0.55] select _t), _dir + (90 * _isaret)];
                if (!surfaceIsWater _c && {((surfaceNormal _c) select 2) > 0.8}) exitWith { _pt = _c; };
                _isaret = -_isaret;
            };
            if (_pt isEqualTo []) then { _u setVariable [QGVAR(zigT), time + 1]; continue };
            // v8.700 GERCEKLESME IZI (kullanici: 'zikzak yok'; RPT 4648beb0: 15 adim LOGLANDI ama ekranda gorunup gorunmedigi bilinmiyordu): onceki adimin KOMUT yan / ileri mesafesi ile askerin GERCEKTE kat ettigi yan / ileri mesafe karsilastirilir
            private _p0 = _u getVariable [QGVAR(zigP0), []];
            if (_p0 isNotEqualTo [] && {(time - (_p0 select 0)) < 6} && {(missionNamespace getVariable ["lambs_danger_zigIzN", 0]) < 80}) then {
                private _d0 = _p0 select 3;
                private _vv = (getPosATL _u) vectorDiff (_p0 select 1);
                private _gy = (_vv vectorDotProduct [sin (_d0 + 90), cos (_d0 + 90), 0]) * (_p0 select 2);
                private _gi = _vv vectorDotProduct [sin _d0, cos _d0, 0];
                missionNamespace setVariable ["lambs_danger_zigIzN", (missionNamespace getVariable ["lambs_danger_zigIzN", 0]) + 1];
                diag_log format ["[ZIGZAG-IZ] %1 | onceki adim %2 sn once: komut yan %3 m ileri %4 m | GERCEKLESEN yan %5 m ileri %6 m | ara noktaya kalan %7 m | hiz %8 km/sa", name _u, (time - (_p0 select 0)) toFixed 1, round (_p0 select 4), round (_p0 select 5), round _gy, round _gi, round (_u distance2D (if (_son isEqualTo []) then { getPosATL _u } else { _son })), round (speed _u)];
            };
            _u setVariable [QGVAR(zigP0), [time, getPosATL _u, _isaret, _dir, _yan, _ileri]];
            _u setVariable [QGVAR(zigYon), _isaret];
            _u setVariable [QGVAR(zigNokta), _pt];
            // adim suresi: yol uzunlugu / askerin GERCEK hizi (animHiz dahil); en erken %75'inde (varis beklenir), en gec %150'sinde (takilma / ezilme guvenligi); CBA zigzagAdimS = alt sinir
            private _yolU = sqrt ((_ileri * _ileri) + (_yan * _yan));
            private _vMs = (((speed _u) / 3.6) max 3.5);
            private _tYol = _yolU / _vMs;
            _u setVariable [QGVAR(zigT), time + ((_tYol * 0.75) max (_adimS * 0.5))];
            _u setVariable [QGVAR(zigTmax), time + ((_tYol * 1.5) max _adimS)];
            _u doMove _pt;
            _say = _say + 1;
            if (_logN < 20) then {
                _logN = _logN + 1;
                diag_log format ["[ZIGZAG] %1 | %2 | dusman %3 m%7 | ileri %4 m yan %5 m%8 | gercek hedefe %6 m", groupId _g, name _u, round _ed, round _ileri, round _yan, round (_u distance2D _gercek), (if ((_u getVariable [QGVAR(zigEn), objNull]) isEqualTo _en) then { " (bilinmeyen)" } else { "" }), (if (_acikGenis) then { " GENIS (acik arazi)" } else { "" })];
            };
        } forEach allUnits;
    };
};
true
