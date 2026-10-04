#include "script_component.hpp"
/*
 * Author: diwako (ELITE fork: Cinar)
 * Returns position and stance of the best cover locations.
 *
 * ELITE v4 — MERMI GEOMETRISINE dayali puanlama:
 *   Gizlenme (VIEW) ile KORUNMA (FIRE geometri = mermi durdurur) ayrimi: cali gizler ama
 *   mermi durdurmaz; duvar / bina / kaya / govde hem gizler hem korur.
 *
 *   + KORUNMA   : 0.1 / 0.75 / 1.45 m yukseklikte FIRE-geometri engel sayisi  x14
 *   + gizlenme  : DOWN / MIDDLE / UP gizli stance sayisi                       x8
 *   - sadece gizleme (mermi durdurmaz)                                         -20
 *   + omuz testi: +-0.35m yandan da gizli (govde genisligi)                   +4 / -6
 *   + yan acilar: dusman +-25 derece kayarsa da gizli                         +8 / aci
 *   + diger bilinen dusmanlara (en fazla 2) karsi da gizli                    +10 / -6
 *   + hull-down (DEFEND): MIDDLE gizli, UP acik = korunup ates edebilir        +6
 *   - uzaklik (0.5 / m; EVADE 0.25 / m)
 *   - dusmana yaklasma (DEFEND/OVERWATCH -0.8 / m;  ADVANCE bonus +0.9 / m;  EVADE: UZAKLASMA bonusu +0.9 / m)
 *   - yumusak obje (cali / kucuk agac) -6
 *   - baska askerin 8 sn icinde rezerve ettigi nokta (6m icinde) -20
 *   - 5m icinde dost kalabaligi -10 / kisi (tek el bombasi / RPG hepsini almasin)
 *   OVERWATCH: ayakta gorus VARSA +14 — MG/nisanci icin atis pozisyonu
 *   EVADE    : sadece SERT siper (en az 2 yukseklikte FIRE engel), dusmandan >= 40m, bina +12
 *              (zirhtan kacis: tank/APC mermisi ve HE'ye karsi cali / agac yetmez)
 *
 * Arguments:
 * 0: Unit seeking cover <OBJECT>
 * 1: Enemy <OBJECT> or Enemy Position (AGL) <ARRAY>
 * 2: Range to find cover, default ELITE_COVER_RANGE <NUMBER>
 * 3: Sort mode <STRING>, default "ASCEND" (aday toplama sirasi): ASCEND, DESCEND, RANDOM
 * 4: Max Results <Number>, default ELITE_COVER_MAX_RESULTS, -1 for all
 * 5: Mode <STRING>, default "DEFEND": "DEFEND" | "ADVANCE" | "OVERWATCH" | "EVADE" | "SURVIVE"
 *    SURVIVE: EN YAKIN sert siper (en az 1 yukseklikte mermi durduran engel), mesafe 0.9/m, uzaklasma bonusu / yaklasma cezasi 0.5/m (tek kalan asker / temas kesme)
 *
 * Return Value:
 * Array of format [[_posAGL, _stance], ...] SKORA GORE sirali (en iyi ilk);
 * bos dizi = siper yok. Stance "UP", "MIDDLE" or "DOWN" (gizli kalinan EN YUKSEK stance)
 *
 * Example:
 * [bob, angryJoe, 30, "ASCEND", 1, "ADVANCE"] call lambs_main_fnc_findCover
 *
 * Public: Yes
*/
params [
    ["_unit", objNull, [objNull]],
    ["_enemy", objNull, [objNull, []]],
    ["_range", ELITE_COVER_RANGE],
    ["_sortMode", "ASCEND", [""]],
    ["_maxResults", ELITE_COVER_MAX_RESULTS],
    ["_mode", "DEFEND", [""]]
];

_maxResults = floor _maxResults;
private _ret = [];

if (_maxResults isEqualTo 0) exitWith {_ret};

private _enemyPos = _enemy call CBA_fnc_getPos;
private _dangerPos = _enemyPos vectorAdd [0, 0, 1.8];

if (_dangerPos isNotEqualTo [0, 0, 1.8]) then {
    _dangerPos = AGLToASL _dangerPos;

    private _unitEnemyDist = _unit distance2D _enemyPos;
    private _group = group _unit;
    private _simdi = time;
    private _evade = _mode isEqualTo "EVADE";
    private _survive = _mode isEqualTo "SURVIVE";
    private _minDist = if (_evade) then {
        ELITE_COVER_MIN_DIST max 40
    } else {
        [ELITE_COVER_MIN_DIST, 20] select (_survive)
    };

    // ---------------------------------------------------------------------
    // Aday objeler: sert (agac/bina/HIDE) + yumusak (cali/kucuk agac) + araclar
    // ---------------------------------------------------------------------
    // Mesafeye gore SIRALI; sert / yumusak AYRI kesilir (yogun bitkide en yakin 40 obje hep cali olup
    // arkadaki sert siperi (agac / bina / kaya / duvar) disarida birakmasin)
    private _sert = nearestTerrainObjects [_unit, ["TREE", "HIDE", "BUILDING", "ROCK", "WALL"], _range, true, true];
    private _yumusak = nearestTerrainObjects [_unit, ["BUSH", "SMALL TREE"], _range, true, true];
    _sert = _sert select [0, 30];
    _yumusak = _yumusak select [0, 10];
    private _terrainObjects = _sert + _yumusak;
    private _uz = (getPosASL _unit) select 2;

    // Murettebatli (hareketli / dost) arac siper sayilmaz; "building" cift sayilmaz
    private _vehicles = (nearestObjects [_unit, ["building", "Car"], _range]) select {
        !(_x in _terrainObjects)
        && {((crew _x) findIf {alive _x}) isEqualTo -1}
    };

    private _allObjs = [];
    if (_sortMode in ["ASCEND", "DESCEND"]) then {
        _allObjs = [_terrainObjects + _vehicles, [], {_unit distance2D _x}, _sortMode] call BIS_fnc_sortBy;
    } else {
        _allObjs = (_terrainObjects + _vehicles) call BIS_fnc_arrayShuffle;
    };
    if ((count _allObjs) > 40) then {
        _allObjs = _allObjs select [0, 40];
    };

    // 8 sn'den eski rezervleri at
    private _claims = (_group getVariable [QGVAR(coverClaims), []]) select {(_simdi - (_x select 1)) < 8};

    // Gizli mi (GORUS): obje VEYA arazi hatti kesiyor
    private _gizli = {
        params ["_bas", "_son", "_u"];
        (lineIntersects [_bas, _son, _u]) || {terrainIntersectASL [_bas, _son]}
    };

    // Korunmus mu (MERMI): FIRE geometrisi hatti kesiyor (cali / yaprak mermi durdurmaz)
    private _korunmus = {
        params ["_bas", "_son", "_u"];
        (count (lineIntersectsSurfaces [_bas, _son, _u, objNull, true, 1, "FIRE", "NONE"])) > 0
    };

    // Birimin bildigi DIGER dusmanlar (en fazla 2): siper hepsine karsi korumali olmali
    private _hedefObj = if (_enemy isEqualType objNull) then {_enemy} else {objNull};
    private _digerTehditler = [];
    {
        if ((count _digerTehditler) < 2 && {_x isNotEqualTo _hedefObj} && {alive _x}) then {
            _digerTehditler pushBack (eyePos _x);
        };
    } forEach (_unit targets [true, 250]);

    private _adaylar = [];
    private _degerlendirilen = 0;

    {
        if (_degerlendirilen >= 60) exitWith {};

        private _obj = _x;
        private _yumusakMi = _obj in _yumusak;
        private _buildingPos = [_obj, ELITE_COVER_BUILDING_POS] call CBA_fnc_buildingPositions;
        private _binaMi = _buildingPos isNotEqualTo [];

        if (!_binaMi) then {
            // Bina pozisyonu yok (bitki / kucuk obje): dusmana gore objenin ARKASI,
            // bbox disina +0.8m (eskiden rastgele bbox kosesi seciliyordu).
            private _objPos = getPosATL _obj;
            private _awayDir = _enemyPos getDir _objPos;
            private _farPos = _objPos getPos [50, _awayDir];
            private _loc = _obj worldToModel _farPos;
            private _dx = _loc select 0;
            private _dy = _loc select 1;
            private _len = (sqrt ((_dx * _dx) + (_dy * _dy))) max 0.001;
            _dx = _dx / _len;
            _dy = _dy / _len;
            (boundingBoxReal _obj) params ["_bbMin", "_bbMax"];
            private _ex = if (_dx >= 0) then {_bbMax select 0} else {abs (_bbMin select 0)};
            private _ey = if (_dy >= 0) then {_bbMax select 1} else {abs (_bbMin select 1)};
            private _t = 15;
            if ((abs _dx) > 0.01) then {_t = _t min (_ex / (abs _dx));};
            if ((abs _dy) > 0.01) then {_t = _t min (_ey / (abs _dy));};
            private _golge = _objPos getPos [_t + 0.8, _awayDir];
            _golge set [2, 0.1];
            _buildingPos = [_golge];
        };

        {
            private _pos = _x;

            // Su / ust kat / cati (> 4 m yukseklik farki) aday degil: ulasilamaz
            if (
                _degerlendirilen < 60
                && {(_dangerPos distance2D _pos) > _minDist}
                && {!surfaceIsWater _pos}
                && {abs (((AGLToASL _pos) select 2) - _uz) < 4}
            ) then {
                private _posASL = AGLToASL _pos;

                // DOWN gizli degilse aday degil
                if ([_dangerPos, _posASL vectorAdd [0, 0, 0.1], _unit] call _gizli) then {
                    _degerlendirilen = _degerlendirilen + 1;

                    // KORUNMA: 3 yukseklikte FIRE geometri engel sayisi
                    private _sertSayi = 0;
                    {
                        if ([_dangerPos, _posASL vectorAdd [0, 0, _x], _unit] call _korunmus) then {
                            _sertSayi = _sertSayi + 1;
                        };
                    } forEach [0.1, 0.75, 1.45];

                    // EVADE: sadece sert siper (en az 2 yukseklikte mermi durduran engel)
                    if ((!_evade || {_sertSayi >= 2}) && {!_survive || {_sertSayi >= 1}}) then {

                        private _stances = ["DOWN"];
                        if ([_dangerPos, _posASL vectorAdd [0, 0, 0.75], _unit] call _gizli) then {
                            _stances pushBack "MIDDLE";
                            if ([_dangerPos, _posASL vectorAdd [0, 0, 1.45], _unit] call _gizli) then {
                                _stances pushBack "UP";
                            };
                        };

                        private _enemyDist = _pos distance2D _enemyPos;
                        private _skor = ((count _stances) * 8) + (_sertSayi * 14);

                        // Sadece gizleme (cali): mermi durdurmaz
                        if (_sertSayi isEqualTo 0) then {
                            _skor = _skor - 20;
                        };

                        private _enemyDir = _pos getDir _enemyPos;

                        // Omuz testi: govde genisligi (+-0.35m) — kenardan vurulmasin
                        {
                            private _sp = _pos getPos [0.35, _enemyDir + _x];
                            _sp set [2, (_pos select 2) + 0.75];
                            private _omuz = AGLToASL _sp;
                            if ([_dangerPos, _omuz, _unit] call _gizli) then {
                                _skor = _skor + 4;
                            } else {
                                _skor = _skor - 6;
                            };
                        } forEach [90, -90];

                        // Yan acilar: dusman +-25 derece kayarsa / ikinci dusman varsa hala gizli mi
                        {
                            private _yan = AGLToASL ((_pos getPos [_enemyDist, _enemyDir + _x]) vectorAdd [0, 0, 1.8]);
                            if ([_yan, _posASL vectorAdd [0, 0, 0.75], _unit] call _gizli) then {
                                _skor = _skor + 8;
                            };
                        } forEach [-25, 25];

                        // Diger bilinen dusmanlara karsi da gizli mi
                        {
                            if ([_x, _posASL vectorAdd [0, 0, 0.75], _unit] call _gizli) then {
                                _skor = _skor + 10;
                            } else {
                                _skor = _skor - 6;
                            };
                        } forEach _digerTehditler;

                        // Uzaklik maliyeti
                        _skor = _skor - ((_unit distance2D _pos) * (if (_evade) then {0.25} else {[0.5, 0.9] select (_survive)}));

                        // Dusmana yaklasma: ADVANCE bonus, EVADE uzaklasma bonusu, digerleri ceza
                        private _yaklasma = _unitEnemyDist - _enemyDist;
                        if (_mode isEqualTo "ADVANCE") then {
                            _skor = _skor + (((_yaklasma min 30) max -30) * 0.9);
                        } else {
                            if (_evade) then {
                                _skor = _skor + ((((-_yaklasma) min 40) max -40) * 0.9);
                            } else {
                                if (_survive) then {
                                    // en yakin siper; dusmandan uzaklasan +, yaklasan - (0.5/m)
                                    _skor = _skor + ((((-_yaklasma) min 30) max -30) * 0.5);
                                } else {
                                    if (_yaklasma > 0) then {
                                        _skor = _skor - (_yaklasma * 0.8);
                                    };
                                };
                            };
                        };

                        // EVADE: bina en iyi (tank gorus hatti kirilir)
                        if (_evade && {_binaMi}) then {
                            _skor = _skor + 12;
                        };

                        // OVERWATCH: ayakta gorus VARSA atis pozisyonu (MG / nisanci)
                        if (_mode isEqualTo "OVERWATCH") then {
                            if ("UP" in _stances) then {
                                _skor = _skor - 10;
                            } else {
                                _skor = _skor + 14;
                            };
                        };

                        // Siper-arkasi atis (hull-down): MIDDLE gizli, UP acik = korunup ates edebilir
                        if (_mode isEqualTo "DEFEND" && {"MIDDLE" in _stances} && {!("UP" in _stances)}) then {
                            _skor = _skor + 6;
                        };

                        // Yumusak obje (cali) mermi durdurmaz
                        if (_yumusakMi) then {
                            _skor = _skor - 6;
                        };

                        // Baska askerin rezervi / dost kalabaligi
                        if ((_claims findIf {
                            (((_x select 0) distance2D _pos) < 6) && {(_x select 2) isNotEqualTo _unit}
                        }) > -1) then {
                            _skor = _skor - 20;
                        };
                        _skor = _skor - ((count ((_pos nearEntities ["CAManBase", 5]) - [_unit])) * 10);

                        _adaylar pushBack [_skor, _pos, _stances select -1];
                    };
                };
            };
        } forEach _buildingPos;
    } forEach _allObjs;

    // ---------------------------------------------------------------------
    // ARAZI KIVRIMI ADAYLARI (v8.13, BIREYSEL arazi bilinci): nesne siperi olmasa da arazinin kendisi (cukur, ters egim, kivrim) gizler.
    // Askerin 6 / 14 m cevresinde 8 yon; yatik (0.4 m) dusman gozunden arazi ile gizliyse aday. Comelmis (1.0 m) de gizliyse +8 (daha iyi),
    // atis modunda (DEFEND/OVERWATCH/ADVANCE) yatik gizli + comelmis GORUNUR = hull-down +8. Ufuk cizgisi -10. Dusman >= 70 m, EVADE degil.
    // Nesne siperinden belirgin ustun degilse nesne kazanir (taban 20, nesneler genelde daha yuksek).
    // ---------------------------------------------------------------------
    if (!_evade && {_unitEnemyDist >= 70} && {missionNamespace getVariable ["lambs_main_coverMikro", true]}) then {
        private _upos = getPosATL _unit;
        private _egoz = AGLToASL (_enemyPos vectorAdd [0, 0, 1.6]);
        private _atisM = _mode in ["DEFEND", "OVERWATCH", "ADVANCE"];
        {
            private _r = _x;
            {
                private _c = _upos getPos [_r, _x];
                if (surfaceIsWater _c || {(_c distance2D _enemyPos) > (_unitEnemyDist + 10)}) then { continue };
                private _hYat = [_egoz, AGLToASL (_c vectorAdd [0, 0, 0.4]), _unit] call _gizli;
                if (!_hYat) then { continue };
                private _hCom = [_egoz, AGLToASL (_c vectorAdd [0, 0, 1.0]), _unit] call _gizli;
                private _sk = 20 - (_r * 0.5);
                if (_atisM) then { if (!_hCom) then { _sk = _sk + 8; }; } else { if (_hCom) then { _sk = _sk + 8; }; };
                private _bsh = AGLToASL (_c vectorAdd [0, 0, 0.4]);
                private _dd = vectorNormalized (_bsh vectorDiff _egoz);
                private _s3 = _bsh vectorAdd (_dd vectorMultiply 300);
                if (!(terrainIntersectASL [_bsh, _s3]) && {!(lineIntersects [_bsh, _s3, objNull, objNull])}) then { _sk = _sk - 10; };
                if (((_c nearEntities ["CAManBase", 4]) - [_unit]) isNotEqualTo []) then { _sk = _sk - 10; };
                _adaylar pushBack [_sk, _c, ["DOWN", "MIDDLE"] select _hCom];
            } forEach [0, 45, 90, 135, 180, 225, 270, 315];
        } forEach [6, 14];
    };
    // ---------------------------------------------------------------------
    // En iyiler (skora gore) + rezerv
    // ---------------------------------------------------------------------
    if (_adaylar isNotEqualTo []) then {
        _adaylar sort false;

        // -----------------------------------------------------------------
        // FAZ 2 — SIPER VE ATIS POZISYONU ANALIZI (v2, VBS4 "cover and firing position analysis" fikri)
        //   Yalniz ilk 6 aday (pahali isinlar az): tehdit YELPAZESI + ATIS EDEBILME
        //   + yelpaze: dusman +-10/20/40 derece kayarsa kac isin hala gizli  (0..6) -> +2 / isin   (sektor maruziyeti)
        //   + atis  : DEFEND / OVERWATCH / ADVANCE'de siper HEDEFI de gorebilmeli:
        //       - ayakta gorus varsa (UP acik)            : zaten atis edebilir                      +8
        //       - ayakta gizli ama yandan 0.6 m eğilip hedef gorulur (lean)                          +10
        //       - hicbir noktadan hedef gorulmuyor (siper kendi atisimizi da kesiyor)               -15
        //   Kapatma: lambs_main_coverV2 = false
        // -----------------------------------------------------------------
        if (missionNamespace getVariable ["lambs_main_coverV2", true]) then {
            private _k = 6 min (count _adaylar);
            private _bas = _adaylar select [0, _k];
            private _ilkPos = (_bas select 0) select 1;
            private _atisModu = _mode in ["DEFEND", "OVERWATCH", "ADVANCE"];
            private _rolC = [_unit] call (missionNamespace getVariable ["lambs_danger_fnc_getUnitRole", {"RIFLE"}]);
            {
                private _a = _x;
                private _pos = _a select 1;
                private _posASL = AGLToASL _pos;
                private _eDir = _pos getDir _enemyPos;
                private _eDist = _pos distance2D _enemyPos;

                // yelpaze
                private _gizliSay = 0;
                {
                    private _yan = AGLToASL ((_pos getPos [_eDist, _eDir + _x]) vectorAdd [0, 0, 1.8]);
                    if ([_yan, _posASL vectorAdd [0, 0, 0.75], _unit] call _gizli) then { _gizliSay = _gizliSay + 1; };
                } forEach [-40, -20, -10, 10, 20, 40];
                _a set [0, (_a select 0) + (_gizliSay * 2)];
                // UFUK CIZGISI (v8.12): siper gokyuzu / ufuk arkasinda ise (egim tepesi, sirt) silueti en gorunur olur -> -10 (yatik / comelmis yuksekligiyle)
                if (_eDist >= 60) then {
                    private _hh = [1.7, 1.0, 0.4] select ((["UP", "MIDDLE", "DOWN"] find (_a select 2)) max 0);
                    private _bsh = AGLToASL (_pos vectorAdd [0, 0, _hh]);
                    private _eg = AGLToASL (_enemyPos vectorAdd [0, 0, 1.6]);
                    private _d2 = vectorNormalized (_bsh vectorDiff _eg);
                    private _s2 = _bsh vectorAdd (_d2 vectorMultiply 300);
                    if (!(terrainIntersectASL [_bsh, _s2]) && {!(lineIntersects [_bsh, _s2, objNull, objNull])}) then {
                        _a set [0, (_a select 0) - 10];
                    };
                };

                // BINA / CQB (v8.27; kullanici: "bina kullanimi agresif", "pencere arkasi calisiyor ama aci yoksa aciyi kendisi ayarlasin, sadece geri durmasin PEEK atsin, yakinlasabilir",
                //   "marksman ust kat, MG ve AT cikmasin", "muzzle flash sadece STEALTH"):
                //   ICERI = ustte cati (1.6 m -> 25 m isin kesisir). ETAJ = round(yerden yukseklik / 3).
                //   ROL (FM 3-06.11 / M136 guvenlik): MARKSMAN ust kat +6 / kat (en fazla 2); MG alt kat tercih (yer seviyesi grazing atesi) -6 / kat; AT ust kat -15 / kat, icerde -12 ve
                //   arkada (dusmanin tersine) 5 m icinde duvar varsa -20 (backblast).  AGRESIF BINA: iceri +6 (lambs_main_binaAgresif).
                private _ustCati = lineIntersects [_posASL vectorAdd [0, 0, 1.6], _posASL vectorAdd [0, 0, 25], _unit];
                if (_ustCati) then {
                    private _etaj = round (((_pos select 2) max 0) / 3);
                    private _cqbP = 0;
                    if (missionNamespace getVariable ["lambs_main_binaAgresif", true]) then { _cqbP = _cqbP + 6; };
                    switch (_rolC) do {
                        case "MARKSMAN": { _cqbP = _cqbP + (6 * (_etaj min 2)); };
                        case "MG": { _cqbP = _cqbP - (6 * _etaj); };
                        case "AT": {
                            _cqbP = _cqbP - (15 * _etaj) - 12;
                            private _arka = _posASL vectorAdd ([-(sin _eDir), -(cos _eDir), 0] vectorMultiply 5);
                            if (lineIntersects [_posASL vectorAdd [0, 0, 1.2], _arka vectorAdd [0, 0, 1.2], _unit]) then { _cqbP = _cqbP - 20; };
                        };
                        default {};
                    };
                    // ACI GENISLIGI (atis modu): dusmana dik 5 yanal ornek hangileri dusmandan gorunuyor
                    private _gorunen = 0;
                    private _derin = 0;
                    private _peek = false;
                    if (_atisModu) then {
                        private _perpC = [cos (_eDir), -(sin (_eDir)), 0];
                        {
                            private _yp = (_posASL vectorAdd [0, 0, 1.4]) vectorAdd (_perpC vectorMultiply _x);
                            if (!([_dangerPos, _yp, _unit] call _gizli)) then { _gorunen = _gorunen + 1; };
                        } forEach [-0.8, -0.4, 0, 0.4, 0.8];
                        if (_gorunen in [1, 2]) then { _cqbP = _cqbP + 10; };
                        if (_gorunen isEqualTo 5) then { _cqbP = _cqbP - 8; };
                        if (_gorunen > 0) then {
                            { 
                                private _on = (_posASL vectorAdd [0, 0, 1.4]) vectorAdd ([sin _eDir, cos _eDir, 0] vectorMultiply _x);
                                if (!([_dangerPos, _on, _unit] call _gizli)) then { _derin = _derin + 1; };
                            } forEach [0.8, 1.6, 2.4];
                            _cqbP = _cqbP + (3 * _derin);
                        } else {
                            // PEEK / ACI AYARI: bu noktadan hedef gorulmuyor -> yanal (0.6 / 1.2 / 1.8 m) ve one (0.8..3.2 m) kayarak EN YAKIN gorus acisini bul;
                            //   cati altinda, aradan duvar yok (ray), hedefi goruyor; ayakta ("UP") peek
                            private _perpP = [cos (_eDir), -(sin (_eDir)), 0];
                            private _dirP = [sin _eDir, cos _eDir, 0];
                            private _adaylarP = [];
                            { private _l = _x; { _adaylarP pushBack [(abs _l) + _x, _l, _x]; } forEach [0, 0.8, 1.6, 2.4, 3.2]; } forEach [0, 0.6, -0.6, 1.2, -1.2, 1.8, -1.8];
                            _adaylarP sort true;
                            {
                                _x params ["_mS", "_lat", "_ile"];
                                if (_mS > 0) then {
                                    private _kP = _pos vectorAdd (_perpP vectorMultiply _lat) vectorAdd (_dirP vectorMultiply _ile);
                                    _kP set [2, _pos select 2];
                                    private _kA = AGLToASL _kP;
                                    if (
                                        !surfaceIsWater _kP
                                        && {lineIntersects [_kA vectorAdd [0, 0, 1.6], _kA vectorAdd [0, 0, 25], _unit]}
                                        && {!(lineIntersects [_posASL vectorAdd [0, 0, 1.0], _kA vectorAdd [0, 0, 1.0], _unit])}
                                        && {!([_dangerPos, _kA vectorAdd [0, 0, 1.4], _unit] call _gizli)}
                                    ) exitWith {
                                        _a set [1, _kP];
                                        _a set [2, "UP"];
                                        _peek = true;
                                        _cqbP = _cqbP + 8;
                                    };
                                };
                            } forEach _adaylarP;
                        };
                        // GERIDE DURMA (aci var, pencereye yakin): dusmandan uzaga 1.6 / 1.0 m, gorus korunuyorsa
                        if (_gorunen > 0 && {_derin < 3}) then {
                            {
                                private _kp = _pos getPos [_x, _eDir + 180];
                                _kp set [2, _pos select 2];
                                private _kASL = AGLToASL _kp;
                                if (
                                    !surfaceIsWater _kp
                                    && {lineIntersects [_kASL vectorAdd [0, 0, 1.6], _kASL vectorAdd [0, 0, 25], _unit]}
                                    && {!(lineIntersects [_posASL vectorAdd [0, 0, 1.0], _kASL vectorAdd [0, 0, 1.0], _unit])}
                                    && {!([_dangerPos, _kASL vectorAdd [0, 0, 1.4], _unit] call _gizli)}
                                ) exitWith {
                                    _a set [1, _kp];
                                    _cqbP = _cqbP + 4;
                                };
                            } forEach [1.6, 1.0];
                        };
                    };
                    // MUZZLE FLASH: yalniz STEALTH / temas YOK iken (catismada hesaplanmaz)
                    private _flasRisk = 0;
                    if (_atisModu && {_gorunen > 0} && {((behaviour _unit) isEqualTo "STEALTH") || {(_group getVariable ["lambs_danger_contact", 0]) < time}}) then {
                        private _mzItem = (primaryWeaponItems _unit) param [0, ""];
                        private _vf = 1;
                        if (_mzItem isNotEqualTo "") then { private _v = getNumber (configFile >> "CfgWeapons" >> _mzItem >> "ItemInfo" >> "AmmoCoef" >> "visibleFire"); if (_v > 0) then { _vf = _v min 1; }; };
                        _flasRisk = (_gorunen / 5) * (1 + (1.5 * ((1 - sunOrMoon) max 0))) * _vf * (1 - (0.25 * _derin));
                        _cqbP = _cqbP - (10 * _flasRisk);
                    };
                    _a set [0, (_a select 0) + _cqbP];
                    if (isNil "lambs_main_cqbLogN") then { lambs_main_cqbLogN = 0; };
                    if (lambs_main_cqbLogN < 60) then {
                        lambs_main_cqbLogN = lambs_main_cqbLogN + 1;
                        diag_log format ["[CQB-POZ] %1 (%2) | iceride | etaj:%3 | aci genisligi:%4/5 | derinlik:%5/3 | PEEK:%6 | flas riski (yalniz stealth):%7 | geriye kaydirildi:%8 | puan degisimi:%9 | dusman %10 m", name _unit, _rolC, _etaj, _gorunen, _derin, _peek, _flasRisk toFixed 2, (_a select 1) isNotEqualTo _pos, round _cqbP, round _eDist];
                    };
                };
                // atis edebilme
                if (_atisModu) then {
                    if ((_a select 2) isNotEqualTo "UP") then {
                        _a set [0, (_a select 0) + 8];                    // ayakta acik = hedefi gorur
                    } else {
                        private _lean = false;
                        {
                            private _pp = _pos getPos [0.6, _eDir + _x];
                            _pp set [2, (_pos select 2) + 1.45];
                            if (!([_dangerPos, AGLToASL _pp, _unit] call _gizli)) exitWith { _lean = true; };
                        } forEach [90, -90];
                        _a set [0, (_a select 0) + ([-15, 10] select _lean)];
                    };
                };
            } forEach _bas;
            _bas sort false;
            _adaylar = _bas + (_adaylar select [_k, (count _adaylar) - _k]);

            // tani: ilk 40 cagri (RPT: [SIPER-ANALIZ])
            if (isNil "lambs_main_siperLogN") then { lambs_main_siperLogN = 0; };
            if (lambs_main_siperLogN < 40) then {
                lambs_main_siperLogN = lambs_main_siperLogN + 1;
                diag_log format ["[SIPER-ANALIZ] %1 | mod:%2 | aday:%3 | faz2:%4 | ilk secim %5 (%6 m)", name _unit, _mode, count _adaylar, _k, ["DEGISTI", "ayni"] select (((_adaylar select 0) select 1) isEqualTo _ilkPos), round (_unit distance2D ((_adaylar select 0) select 1))];
            };
        };
        private _adet = if (_maxResults isEqualTo -1) then {
            count _adaylar
        } else {
            _maxResults min (count _adaylar)
        };
        for "_i" from 0 to (_adet - 1) do {
            private _a = _adaylar select _i;
            _ret pushBack [_a select 1, _a select 2];
        };

        _claims pushBack [(_ret select 0) select 0, _simdi, _unit];
        _group setVariable [QGVAR(coverClaims), _claims];
    };
};

if (GVAR(debug_functions) && {(_ret isNotEqualTo [])}) then {
    ["Found %1 cover positions", count _ret] call FUNC(debugLog);
    {
        "Sign_Arrow_Large_F" createVehicleLocal ((_enemy call CBA_fnc_getPos) vectorAdd [0, 0, 1.8]);
        private _add = if ((_x select 1) isEqualTo "UP") then {
            2
        } else {
            [0.2, 1] select (_x select 1 isEqualTo "MIDDLE");
        };
        "Sign_Arrow_Large_Blue_F" createVehicleLocal ((_x select 0) vectorAdd [0, 0, _add]);
    } forEach _ret;
};

_ret
