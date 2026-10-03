#include "script_component.hpp"
/*
 * Author: Cinar (ELITE fork)
 * Grup, USMC doktrinine uygun "Bounding Overwatch" manevrasi yapar.
 * 2026-10-01 v3 — OLUMCUL + GOZLE GORULUR
 *   - Her cycle 3 faz: ATES (1.5 sn) -> HAREKET (varisa kadar) -> ORTAK ATES
 *   - Hareket sprint (UP) ile; siper stance'i VARISTA (eskiden yatarak yola cikiyordu)
 *   - ODAK ATES: tum kapsama ekibi ayni dusmana (doTarget/doFire) + alana baski
 *   - Her 3. cycle FSE ileri sicrar, maneuver ortu verir (gercek leapfrog)
 *   - Buddy ciftleri: 2'li (en guclu + en zayif), MG kosmaz, tek kalan ilerler
 *   - combatMode RED (bitince geri yuklenir), lider jest + callout
 *   - Siper yok / ileri degilse yanal acili 25m atilim (capraz ates)
 * 2026-10-01 v3.1 — SIPERDEN SIPERE
 *   - Siper secimi MESAFE + YOL ACIKLIGI hesabi (6 aday; dusmanin gordugu yol ornekleri cezali)
 *   - Cift ayni / cok yakin siperde: kosucu varinca esi 2-8 m yanina gelir (BND-YAKIN)
 *   - Siper omru: en az ~4-5 sn kal, baski varsa uzar, sonunda PEEK (kalk-nisan-ol)
 *   - Guncel dusman yonu: cycle basinda ve yolda odak kayarsa hedef / siper yenilenir (BND-YON)
*/

params ["_group", "_target", ["_units", []], ["_delay", 180]];

// ---------------------------------------------------------------------------
// Lokal bounding sabitleri (USMC doktrini)
// ---------------------------------------------------------------------------
private _BND_ASSAULT_RANGE   = 40;   // bounding hucuma bu mesafede devreder (eskiden 55: 93 m'de sadece 2 cycle kaliyordu)
private _BND_CYCLE_BASE      = 6;   // ortak ates bekleme (sn)
private _BND_CYCLE_RAND      = 3;
private _BND_SUPPRESSION_MUL = 3;
private _BND_MAX_CYCLES      = 10;
private _BND_COVER_RANGE     = 50;    // ileri siper arama menzili (m)

// ---------------------------------------------------------------------------
// Grup / lider dogrulama
// ---------------------------------------------------------------------------
if (isNull _group) exitWith {false};
if (_group isEqualType objNull) then {_group = group _group;};
if ((units _group) isEqualTo []) exitWith {false};
private _unit = leader _group;
// DOKTRIN PROFILI: bounding bitis mesafesi / cycle siniri / overwatch kurulum suresi fraksiyona gore
_BND_ASSAULT_RANGE = [_group, "bndBitisM", _BND_ASSAULT_RANGE] call FUNC(dk);
_BND_MAX_CYCLES = [_group, "bndMaxCycle", _BND_MAX_CYCLES] call FUNC(dk);

// ---------------------------------------------------------------------------
// Hedefi normalize et
// ---------------------------------------------------------------------------
_target = +(_target call CBA_fnc_getPos);
if ((count _target) < 3) then { _target pushBack 0; };
if ((_target select 2) > 6) then {
    _target set [2, 0.5];
};

private _targetASL = AGLToASL _target;

// ---------------------------------------------------------------------------
// CQB ise assault'a devret
// ---------------------------------------------------------------------------
private _boundingCQB = (GVAR(cqbRange) min 20);
if (_unit distance2D _target < _boundingCQB) exitWith {
    [_group, _target] call FUNC(tacticsAssault);
    false
};

// ---------------------------------------------------------------------------
// Minimum 4 kisi
// ---------------------------------------------------------------------------
if (count (units _group) < 4) exitWith {
    [_group, _target] call FUNC(tacticsFlank);
    false
};

// ---------------------------------------------------------------------------
// Taktik kilidi + bounding bayragi
// ---------------------------------------------------------------------------
// v8.43: YENIDEN BASLATMA DEBOUNCE — RPT 5ef891c1: ayni grupta ayni saniyede 2 BND-BASLA, onceki dongu 'cycle:1 bizim:false' ile 3 sn'de biter
//   (token ezilir), roller / hareket emirleri surekli yeniden dagitilir -> asker bound'u tamamlayamaz ('formasyon loopu / etkisiz').
//   Son bounding baslangicindan < 8 sn ise yeni baslatma yok (calisan dongu surer).
if ((time - (_group getVariable [QGVAR(bndSonBasla), -999])) < 8) exitWith { false };
_group setVariable [QGVAR(bndSonBasla), time];
_group setVariable [QGVAR(isExecutingTactic), true];
_group setVariable [QGVAR(isBounding), true];
_group setVariable [QGVAR(boundingStartTime), time];
private _bndToken = format ["%1-%2", time, random 1000000];
_group setVariable [QGVAR(bndToken), _bndToken];

// ---------------------------------------------------------------------------
// Cleanup timer
// ---------------------------------------------------------------------------
[
    {
        params [["_group", grpNull], ["_delay", 0], "", "", ["_token", ""]];
        time > _delay
        || {isNull _group}
        || { !(_group getVariable [QGVAR(isExecutingTactic), false]) }
        || { (_group getVariable [QGVAR(bndToken), ""]) isNotEqualTo _token }
    },
    {
        params [["_group", grpNull], "", ["_speedMode", "NORMAL"], ["_formation", "WEDGE"], ["_token", ""]];
        // Token eslesmiyorsa baska bir taktik (Retreat / yeni Bounding) devraldi -> dokunma
        if (!isNull _group && {(_group getVariable [QGVAR(bndToken), ""]) isEqualTo _token}) then {
            _group setVariable [QGVAR(bndToken), nil];
            _group enableAttack true;
            _group setCombatMode (_group getVariable [QGVAR(bndOrigCombat), "YELLOW"]);
            (units _group) allowGetIn true;
            _group setVariable [QGVAR(isExecutingTactic), nil];
            _group setVariable [QGVAR(isBounding), nil];
            _group setVariable [QEGVAR(main,currentTactic), nil];
            _group setSpeedMode _speedMode;

            private _u2 = leader _group;
            private _t2 = _u2 getVariable [QEGVAR(main,currentTarget), [0,0,0]];
            _t2 = _t2 call CBA_fnc_getPos;
            if (_t2 isEqualTo [0,0,0]) then { _t2 = getPosATL _u2 vectorAdd [50, 0, 0]; };
            private _yeniForm = [_u2, _t2, "BOUNDING"] call FUNC(selectFormation);
            _group setFormation _yeniForm;

            {
                _x setVariable [QEGVAR(main,currentTask), nil, EGVAR(main,debug_functions)];
                _x setVariable [QGVAR(forceMove), nil];
                _x setUnitPos "AUTO";
                _x doWatch objNull;
                _x doFollow (leader _x);
            } forEach (units _group);
        };
    },
    [_group, time + _delay, speedMode _unit, formation _unit, _bndToken]
] call CBA_fnc_waitUntilAndExecute;

// ---------------------------------------------------------------------------
// Hazir birlikleri bul
// ---------------------------------------------------------------------------
if (_units isEqualTo []) then {
    _units = _unit call lambs_main_fnc_findReadyUnits;
};
if (count _units < 4) then {
    _units = (units _group) select {alive _x && {isNull objectParent _x}};
};
if (count _units < 4) exitWith {
    _group setVariable [QGVAR(bndToken), nil];   // 79. satirdaki temizlik zamanlayicisi bu calismaya dokunmasin
    _group setVariable ["lambs_danger_isBounding", nil];
    _group setVariable ["lambs_danger_isExecutingTactic", nil];
    false
};

// ---------------------------------------------------------------------------
// Araclar
// ---------------------------------------------------------------------------
private _vehicles = [_unit] call EFUNC(main,findReadyVehicles);

// ---------------------------------------------------------------------------
// Hedef cevresindeki potansiyel hedefler
// ---------------------------------------------------------------------------

// ---------------------------------------------------------------------------
// Gorev degiskenleri
// ---------------------------------------------------------------------------
_unit setVariable [QEGVAR(main,currentTarget), _target, EGVAR(main,debug_functions)];
_unit setVariable [QEGVAR(main,currentTask), "Tactics Bounding", EGVAR(main,debug_functions)];
_group setVariable [QEGVAR(main,currentTactic), "Bounding Overwatch", EGVAR(main,debug_functions)];

// ---------------------------------------------------------------------------
// Jest + callout
// ---------------------------------------------------------------------------
// (v8.31: her cycle'da jest = komutan "sayiklama" spami; 35 sn'de bir)
if ((time - (_group getVariable [QGVAR(bndSonJest), 0])) > 35) then {
    _group setVariable [QGVAR(bndSonJest), time];
    [_unit, ["gestureGo"]] call EFUNC(main,doGesture);
    [_units select -1, "gestureGoB"] call EFUNC(main,doGesture);
};

private _sonCallout = _group getVariable [QGVAR(bndSonCallout), 0];
if (time - _sonCallout > 60) then {
    [_unit, "combat", "Advance", 125] call EFUNC(main,doCallout);
    _group setVariable [QGVAR(bndSonCallout), time];
};

// ---------------------------------------------------------------------------
// Grubu hazirla
// ---------------------------------------------------------------------------
// v8.38: yon histerezisi (selectFormation ile ortak): sapma > 35 derece ve >= 40 sn, yoksa slotlara yeniden kosma (ates kesilir)
private _bndYon = _unit getDir _target;
private _bndEski = _group getVariable [QGVAR(selFdirV), -1];
private _bndSapma = if (_bndEski < 0) then {360} else {abs (((_bndYon - _bndEski + 540) mod 360) - 180)};
if (_bndSapma > 35 && {(time - (_group getVariable [QGVAR(selFdirT), -999])) >= 40}) then {
    _group setFormDir _bndYon;
    _group setVariable [QGVAR(selFdirV), _bndYon];
    _group setVariable [QGVAR(selFdirT), time];
};

// Bitiste geri verilecek orijinal degerler
_group setVariable [QGVAR(bndOrigForm), formation _group];
_group setVariable [QGVAR(bndOrigAtk), attackEnabled _group];
_group setVariable [QGVAR(bndOrigSpeed), speedMode _group];

private _formation = [_unit, _target, "BOUNDING"] call FUNC(selectFormation);
_group setFormation _formation;
_group setVariable [QGVAR(dangerFormation), _formation];

_group enableAttack false;
// Olumculuk: serbest ates (combatMode RED); bitince orijinal geri yuklenir
_group setVariable [QGVAR(bndOrigCombat), combatMode _group];
_group setCombatMode "RED";
(_units select {isNull objectParent _x}) allowGetIn false;   // aractakiler (surucu / nisanci) araci terk etmesin
_units doWatch _target;

// forceMove burada TUM askerlere konmaz: LAMBS reaksiyonlarini (cover/dodge) tamamen susturuyor ve
// ates altinda askerler siper alamiyordu. Sadece HAREKET EDEN askerde (kosan) gecici olarak konur.
{
    _x forceSpeed -1;
} forEach (_units select {isNull objectParent _x});

// ---------------------------------------------------------------------------
// FAZ 2: FIRE TEAM SUBDIVISION
// ---------------------------------------------------------------------------
private _teams = [_group] call FUNC(splitFireTeams);
_teams params ["_fse", "_maneuver", "_reserve"];

if (_fse isEqualTo [] || _maneuver isEqualTo []) then {
    _fse = [];
    _maneuver = [];
    {
        if ((_forEachIndex % 2) isEqualTo 0) then {
            _fse pushBack _x;
        } else {
            _maneuver pushBack _x;
        };
    } forEach _units;
    _reserve = [];
};

if (_fse isEqualTo [] || _maneuver isEqualTo []) exitWith {
    _group setVariable [QGVAR(bndToken), nil];
    _group setVariable ["lambs_danger_isBounding", nil];
    _group setVariable ["lambs_danger_isExecutingTactic", nil];
    // combatMode / enableAttack / allowGetIn burada zaten degistirilmisti -> geri ver
    _group setCombatMode (_group getVariable [QGVAR(bndOrigCombat), "YELLOW"]);
    _group enableAttack (_group getVariable [QGVAR(bndOrigAtk), true]);
    (units _group) allowGetIn true;
    false
};

// ---------------------------------------------------------------------------
// Debug
// ---------------------------------------------------------------------------
if (EGVAR(main,debug_functions)) then {
    ["%1 TACTICS BOUNDING (%2 with %3 units [FSE:%4 MVR:%5 RES:%6] @ %7m)", side _unit, name _unit, count _units, count _fse, count _maneuver, count _reserve, round (_unit distance2D _target)] call EFUNC(main,debugLog);

    private _m  = [_unit,   "tactics bounding", _unit call EFUNC(main,debugMarkerColor), "hd_arrow"]    call EFUNC(main,dotMarker);
    private _mt = [_target, "",                 _unit call EFUNC(main,debugMarkerColor), "hd_objective"] call EFUNC(main,dotMarker);
    {_x setMarkerSizeLocal [0.6, 0.6];} forEach [_m, _mt];
    _m setMarkerDirLocal (_unit getDir _target);
    [{{deleteMarker _x; true} count _this;}, [_m, _mt], _delay + 30] call CBA_fnc_waitAndExecute;
};

// ---------------------------------------------------------------------------
// Bounding dongusunu ayri scheduled thread'de baslat
// ---------------------------------------------------------------------------
[_group, _fse, _maneuver, _reserve, _target, _targetASL, _vehicles, _unit,
 _BND_ASSAULT_RANGE, _BND_CYCLE_BASE, _BND_CYCLE_RAND, _BND_SUPPRESSION_MUL,
 _BND_MAX_CYCLES, _BND_COVER_RANGE, _bndToken, _delay] spawn {

    params [
        "_group", "_fse", "_maneuver", "_reserve", "_target", "_targetASL", "_vehicles", "_leader",
        "_BND_ASSAULT_RANGE", "_BND_CYCLE_BASE", "_BND_CYCLE_RAND", "_BND_SUPPRESSION_MUL",
        "_BND_MAX_CYCLES", "_BND_COVER_RANGE", "_bndToken", "_delay"
    ];

    private _cycleCount = 0;
    private _rushN = 0;   // sadece buddy cycle'larda artar (kosucu dagilimi esit olsun)
    // Zarif bitis: temizlik zamanlayicisindan (delay) 20 sn once dongu kendisi biter
    private _bndEnd = time + ((_delay - 20) max 60);

    // Fonksiyon kayitli degilse (XEH_PREP eksik) hata vermeden devam: rol=TUFEKLI, sis=yok
    private _rolFn = missionNamespace getVariable ["lambs_danger_fnc_getUnitRole", {"RIFLE"}];
    private _sisFn = missionNamespace getVariable ["lambs_danger_fnc_tacticalSmoke", {false}];
    private _pairFn = missionNamespace getVariable ["lambs_danger_fnc_buddyPairs", {[_this select 0]}];
    private _uglFn = missionNamespace getVariable ["lambs_danger_fnc_tacticalUGL", {false}];
    private _atFn = missionNamespace getVariable ["lambs_danger_fnc_isATUnit", {params ["_u"]; (secondaryWeapon _u) isNotEqualTo "" && {(_u ammo (secondaryWeapon _u)) > 0}}];
    private _atFireFn = missionNamespace getVariable ["lambs_danger_fnc_atFire", {params ["_u", "_t"]; _u doTarget _t; _u doFire _t; true}];

    // -----------------------------------------------------------------------
    // YARDIMCI KODLAR
    // -----------------------------------------------------------------------

    // Bounding'i temiz bitirir (bayraklar + enableAttack/allowGetIn/doWatch/combatMode geri)
    private _bndTemizle = {
        params ["_g"];
        _g setVariable [QGVAR(bndToken), nil];
        { _x setVariable [QGVAR(taktikKilit), nil]; } forEach (units _g);   // HAREKET KILIDI (arbitraj) birak
        _g setVariable [QGVAR(isBounding), nil];
        _g setVariable [QGVAR(isExecutingTactic), nil];
        _g setVariable [QEGVAR(main,currentTactic), nil];
        _g enableAttack (_g getVariable [QGVAR(bndOrigAtk), true]);
        _g setSpeedMode (_g getVariable [QGVAR(bndOrigSpeed), "NORMAL"]);
        _g setCombatMode (_g getVariable [QGVAR(bndOrigCombat), "YELLOW"]);
        private _of = _g getVariable [QGVAR(bndOrigForm), ""];
        if (_of isNotEqualTo "") then { _g setFormation _of; };
        _g setVariable [QGVAR(dangerFormation), nil];
        (units _g) allowGetIn true;
        {
            _x setVariable [QGVAR(forceMove), nil];
            _x doWatch objNull;
            _x setUnitPos "AUTO";
            _x setUnitPosWeak "AUTO";
        } forEach (units _g);
    };

    // Bu bounding HALA bu thread'e mi ait? (token + bayraklar) — iptal / yeni bounding sonrasi eski thread durur
    private _hala = {
        !isNull _group
        && {(_group getVariable [QGVAR(bndToken), ""]) isEqualTo _bndToken}
        && {_group getVariable [QGVAR(isBounding), false]}
        && {_group getVariable [QGVAR(isExecutingTactic), false]}
    };

    // Varis / siper stance'i: ezilen (>=0.85) yatar; siperden 8 m'den uzaktaysa (varmadi) acikta cokmez
    private _durusFn = {
        params ["_b", "_p", "_s"];
        if (!alive _b) exitWith {};
        _b setUnitPosWeak (
            if ((getSuppression _b) >= 0.85) then {"DOWN"} else {
                if ((_b distance2D _p) > 8) then {"AUTO"} else {_s}
            }
        );
        // VARDI: sipernin yerinde KAL (doStop) — aksi halde AI formasyon slotuna (liderin yanina) geri yuruyup "ileri-geri" yapiyor.
        // Bounding bitince / sonraki sicramada doMove zaten yeni emir verir; en sonda doFollow gruba doner.
        if ((_b distance2D _p) <= 8 && {(getSuppression _b) < 0.85}) then { doStop _b; };
    };

    // ODAK: grubun bildigi en yakin dusman (hepsi AYNI hedefe ates eder = yogun ates)
    private _odakSec = {
        params ["_g"];
        private _l = leader _g;
        private _e = _l findNearestEnemy _l;
        // Arac / zirh odak olursa baski olcumu (getSuppression) calismaz: bilinen en yakin PIYADEYI tercih et
        if (!isNull _e && {!(_e isKindOf "CAManBase")}) then {
            private _pl = (_l nearEntities ["CAManBase", 450]) select {
                alive _x && {((side _l) getFriend (side _x)) < 0.6} && {(side _x) isNotEqualTo civilian} && {(_l knowsAbout _x) > 0.5}
            };
            if (_pl isNotEqualTo []) then {
                _e = ([_pl, [], {_l distance2D _x}, "ASCEND"] call BIS_fnc_sortBy) select 0;
            };
        };
        if (isNull _e || {!alive _e} || {(_l distance2D _e) > 450}) then {objNull} else {_e}
    };

    // ATES (OLUMCUL OVERWATCH): kapsama ekibi
    //   - SEKTOR YELPAZESI: her asker hedefin -12 / 0 / +12 derece sapmasina baski atar
    //     (eskiden hepsi ayni noktayi doviyordu -> cephe taranmiyordu)
    //   - ODAK: bilinen en yakin dusmana doTarget; MG icin doFire esigi dusuk (surekli ates)
    //   - AT: 40-450m bilinen ZIRHA roket (selectWeapon launcher + doTarget + doFire)
    private _atesEt = {
        params ["_birimler", "_hedef", "_hedefASL", "_odak", "_gorev"];

        private _l = leader _group;
        private _mySide = side _l;
        private _zirhlar = (_l nearEntities [["Tank", "Wheeled_APC_F"], 450]) select {
            alive _x
            && {(_mySide getFriend (side _x)) < 0.6}
            && {((side _x) != civilian)}
        };
        private _zirh = objNull;
        if (_zirhlar isNotEqualTo []) then {
            _zirh = ([_zirhlar, [], {_l distance2D _x}, "ASCEND"] call BIS_fnc_sortBy) select 0;
        };

        {
            if (alive _x && {isNull objectParent _x}) then {
                private _rol = [_x] call _rolFn;

                // Sektor: -12 / 0 / +12 derece
                private _ofs = [-12, 0, 12] select (_forEachIndex % 3);
                private _mes = (_x distance2D _hedef) max 20;
                private _sekPos = (getPosATL _x) getPos [_mes, ((_x getDir _hedef) + _ofs)];
                _sekPos set [2, 0.5];

                _x setVariable [QEGVAR(main,currentTask), _gorev, EGVAR(main,debug_functions)];
                _x doWatch _sekPos;
                [_x, AGLToASL _sekPos] call EFUNC(main,doSuppress);

                // AT: zirha roket
                private _atAtti = false;
                if (!isNull _zirh && {[_x] call _atFn}) then {
                    private _d = _x distance2D _zirh;
                    if (_d > 40 && {_d < 450} && {(_x knowsAbout _zirh) > 0.5}) then {
                        [_x, _zirh] call _atFireFn;
                        _atAtti = true;
                    };
                };

                if (!_atAtti) then {
                    // AT piyadeye ates ederken ana silaha don
                    if ((secondaryWeapon _x) isNotEqualTo "" && {(currentWeapon _x) isEqualTo (secondaryWeapon _x)}) then {
                        [_x, primaryWeapon _x] call CBA_fnc_selectWeapon;
                    };
                    if (!isNull _odak && {alive _odak} && {(_x distance2D _odak) < 350}) then {
                        _x doTarget _odak;
                        if ((_x knowsAbout _odak) > ([1, 0.5] select (_rol isEqualTo "MG"))) then {
                            _x doFire _odak;
                        };
                        // UGL BOOST: piyade hedefe 40mm (hat kapali / binada / kume / %50; 5 sn cooldown)
                        if (_odak isKindOf "CAManBase") then {
                            [_x, _odak] call _uglFn;
                        };
                    };
                };
            };
        } forEach _birimler;
    };

    // Kosucu hareketi: ADVANCE modunda ILERI siperli sicrama. SIPER SECIMI mesafe + YOL ACIKLIGI hesabi:
    //   - findCover'in ilk 6 adayi tek tek degerlendirilir (eskiden sadece 1.)
    //   - atilim <= 40 m ve en az 6 m ileri kazanc
    //   - yol aciklik: kosucudan siperine giden hat boyunca 5 m'de bir ornek; dusmanin GORDUGU ornek 'acik'
    //   - puan = -4 x findCover sirasi - 7 x acik ornek - 1.5 x (atilim - 30 m)  -> kisa, korunakli yol kazanir
    // YAKLASIM ACISI (_aci): hedefe dogru hattin +-derece sapmasi; siper puanina aci uyumu eklenir (0.2/derece),
    //   boylece kosucular tek hat yerine yelpaze seklinde ilerler ve kapsama ekibiyle capraz ates olusur
    // Siper yoksa yanal acili 25 m atilim (capraz ates + dagilma). Siper stance'i VARISTA uygulanir.
    // Doner: [birim, hedefPos, varisStance, atilimMetre, acikOrnek] veya []
    private _kosanHareket = {
        params ["_kosan", "_hedef", "_siperMenzil", "_hucumMenzil", "_gorev", ["_aci", 0]];
        if (!alive _kosan || {!isNull objectParent _kosan}) exitWith {[]};

        private _mesafe = _kosan distance2D _hedef;
        private _kPos = getPosATL _kosan;
        private _eASL = AGLToASL (_hedef vectorAdd [0, 0, 1.6]);
        // MESAFEYE GORE ATILIM (doktrin: ates altinda 3-5 sn / 15-30 m atilim; uzak ve ortulu arazide daha uzun):
        //   > 200 m : kazanc >= 15, atilim <= 70   (uzak, dusman etkisiz)
        //   100-200 : kazanc >= 12, atilim <= 40
        //   < 100 m : kazanc >= 8,  atilim <= 25   (yakin temas: kisa, hizli atilim)
        // bantlar doktrin profilinden: [[mesafe_ustu, atilimMax, kazancMin], ...] buyukten kucuge
        private _bantlar = [group _kosan, "bantlar", [[200, 70, 15], [100, 40, 12], [0, 25, 8]]] call FUNC(dk);
        private _bnd = _bantlar select (((_bantlar findIf {_mesafe > (_x select 0)}) max 0) min ((count _bantlar) - 1));
        // v8.21 YORGUNLUK DUYARLI ATILIM: ACE advanced fatigue (anReserve, ~2300 J tam) varsa onun, yoksa vanilla getFatigue; rezerv dustukce atilim kisalir (en az x0.5)
        private _yorgunluk = 0;
        private _anR = _kosan getVariable ["ace_advanced_fatigue_anReserve", -1];
        if (_anR >= 0) then { _yorgunluk = 1 - ((_anR / 2300) min 1); } else { _yorgunluk = (getFatigue _kosan) min 1; };
        private _yorgCarpan = 1 - (0.5 * ([group _kosan, "yorgunlukEtki", 1] call FUNC(dk)) * _yorgunluk);
        private _atMax = ((_bnd select 1) * _yorgCarpan) max 12;
        if (_yorgunluk > 0.3) then {
            if (isNil "lambs_danger_yorgLogN") then { lambs_danger_yorgLogN = 0; };
            if (lambs_danger_yorgLogN < 40) then {
                lambs_danger_yorgLogN = lambs_danger_yorgLogN + 1;
                diag_log format ["[YORGUNLUK] %1 | %2 | yorgunluk:%3 (%4) | atilim siniri %5 -> %6 m", groupId (group _kosan), name _kosan, _yorgunluk toFixed 2, ["vanilla", "ACE"] select (_anR >= 0), round (_bnd select 1), round _atMax];
            };
        };

        private _kazMin = _bnd select 2;
        _siperMenzil = _siperMenzil min (_atMax + 10);
        private _cover = [_kosan, _hedef, _siperMenzil, "ASCEND", 6, "ADVANCE"] call EFUNC(main,findCover);
        private _movePos = [];
        private _stance = "MIDDLE";
        private _hop = 0;
        private _acik = 0;

        private _enIyi = -999999;
        {
            private _cp = _x select 0;
            private _atilim = _kPos distance2D _cp;
            // en az 6m ILERI kazanc yoksa siper sayma (yerinde saymasin); cok uzak atilim da sayilmaz
            if ((_mesafe - (_cp distance2D _hedef)) >= _kazMin && {_atilim <= _atMax}) then {
                private _n = (floor (_atilim / 5)) max 1;
                private _a = 0;
                for "_k" from 1 to _n do {
                    private _p = _kPos vectorAdd ((_cp vectorDiff _kPos) vectorMultiply (_k / _n));
                    private _pASL = AGLToASL (_p vectorAdd [0, 0, 1]);
                    if (!(terrainIntersectASL [_eASL, _pASL]) && {!(lineIntersects [_eASL, _pASL, objNull, objNull])}) then {
                        _a = _a + 1;
                    };
                };
                private _aciFark = abs ((((_kPos getDir _cp) - ((_kosan getDir _hedef) + _aci)) + 540) % 360 - 180);
                private _skor = (-4 * _forEachIndex) - (7 * _a) - (1.5 * ((_atilim - (_atMax * 0.75)) max 0)) - (0.2 * _aciFark);
                if (_skor > _enIyi) then {
                    _enIyi = _skor;
                    _movePos = _cp;
                    _stance = _x select 1;
                    _hop = _atilim;
                    _acik = _a;
                };
            };
        } forEach _cover;

        if (_movePos isEqualTo []) then {
            private _kayma = if (_aci isNotEqualTo 0) then {_aci} else {[-30, 30] select ((((units (group _kosan)) find _kosan) max 0) % 2)};
            private _kalan = (_mesafe - _hucumMenzil) max 0;
            _hop = (_atMax * 0.6) min _kalan;
            _movePos = _kPos getPos [_hop, ((_kosan getDir _hedef) + _kayma)];
            if (surfaceIsWater _movePos) then { _movePos = _kPos; _hop = 0; };
            _stance = "MIDDLE";
        };

        _kosan setVariable [QEGVAR(main,currentTask), _gorev, EGVAR(main,debug_functions)];
        _kosan setVariable [QGVAR(forceMove), true];
        _kosan setUnitPosWeak "UP";
        _kosan moveTo _movePos;
        _kosan doWatch _hedef;
        _kosan forceSpeed -1;

        [_kosan, _movePos, _stance, _hop, _acik]
    };

    diag_log format [
        "[BND-BASLA] %1 | hedef:%2m | FSE:%3 MVR:%4 RES:%5",
        groupId _group, round ((leader _group) distance2D _target), count _fse, count _maneuver, count _reserve
    ];
    [_group, "BoundingBasla", round ((leader _group) distance2D _target)] call FUNC(olayGonder);

    // Taktik sis: dusmana dogru, hareket eden birligin onune (tacticalSmoke cooldown'u var)
    [_group, _target, "COVER_MOVE"] call _sisFn;

    // FORMASYON ZORLAMA
    [_group, _bndToken] spawn {
        params ["_g", "_tok"];
        while {!isNull _g && {_g getVariable ["lambs_danger_isBounding", false]} && {(_g getVariable [QGVAR(bndToken), ""]) isEqualTo _tok}} do {
            private _df = _g getVariable ["lambs_danger_dangerFormation", ""];
            // Baski altinda (>= 0.4) formasyon ZORLANMAZ: gercek catismada esner, siper icin bozulur
            private _baskida = ((units _g) findIf {alive _x && {(getSuppression _x) >= 0.4}}) > -1;
            if (!_baskida && {_df isNotEqualTo ""} && {formation _g isNotEqualTo _df}) then {
                _g setFormation _df;
            };
            sleep 0.5;
        };
    };

    // =======================================================================
    // ANA DONGU — her cycle: ATES (1.5 sn) -> HAREKET (varisa kadar) -> ORTAK ATES
    //   normal cycle : maneuver BUDDY RUSH (ciftlerde kosan), FSE + reserve + destekler ates eder
    //   her 3. cycle : FSE (+reserve) ILERI sicrar, maneuver ortu atesi verir  (takim leapfrog)
    // =======================================================================
    while {
        (call _hala)
        && {time < _bndEnd}
        && {(leader _group) distance2D _target > _BND_ASSAULT_RANGE}
        && {{alive _x} count (units _group) >= 2}
        && {_cycleCount < _BND_MAX_CYCLES}
    } do {
        _cycleCount = _cycleCount + 1;
        // HAREKET ARBITRAJI: bounding'e katilan HER askere (koşucu + overwatch) taktik kilidi — buddyBond / dispersion / roleStation / rearGuard /
        // coverHug / fieldCraft / cqbReflex bu askerlere hareket emri vermez (RPT: bounding / retreat sirasinda "[BUDDY] ... yanina donuyor")
        { if (alive _x) then { _x setVariable [QGVAR(taktikKilit), time + 30]; }; } forEach (units _group);

        // Siste periyodik sis (cooldown 45 sn icinde)
        if ((_cycleCount % 3) isEqualTo 2) then {
            [_group, _target, "COVER_MOVE"] call _sisFn;
        };

        // KAYIP KONTROLU — komutan her cycle'da yeniden degerlendirir.
        private _komutanKarar = [_group, _target] call FUNC(commanderAssess);
        if (_komutanKarar in ["WITHDRAW", "PEEL", "EVADE_ARMOR", "AT_ENGAGE", "HOLD", "DELAY"]) exitWith {
            // tani: bounding neden yarida kesildi? (RPT: cycle 2'de, sebebi logda yoktu)
            diag_log format ["[BND-CIKIS] %1 | cycle:%2 | komutan karari: %3 | durum(zaman,yakin,dusman,MG,zirh,oran,kayip): %4", groupId _group, _cycleCount, _komutanKarar, _group getVariable [QGVAR(cmdSit), []]];
            [_group] call _bndTemizle;
            switch (_komutanKarar) do {
                case "EVADE_ARMOR": {
                    // AT'siz grup zirhtan kacar (fonksiyon kayitli degilse Retreat)
                    [_group, _target] call (missionNamespace getVariable ["lambs_danger_fnc_tacticsEvadeArmor", FUNC(tacticsRetreat)]);
                };
                case "AT_ENGAGE": {
                    // AT zirha taarruz + piyade eskort (fonksiyon kayitli degilse Flank)
                    [_group, _target] call (missionNamespace getVariable ["lambs_danger_fnc_tacticsATEngage", FUNC(tacticsFlank)]);
                };
                case "HOLD": {
                    // ezilen / cephanesi kritik grup bounding'e devam etmez (fnc_tactics HOLD ile ayni)
                    _group setVariable [QGVAR(isExecutingTactic), true];
                    [_group, 20] call FUNC(tacticsHold);
                };
                case "DELAY": {
                    if ((time - (_group getVariable [QGVAR(delayBasT), -999])) > 30) then {
                        _group setVariable [QGVAR(delayBasT), time];
                        _group setVariable [QGVAR(isExecutingTactic), true];
                        [_group, _target, false, 25] call FUNC(tacticsHide);
                        [_group, _target, "BREAK_CONTACT"] call _sisFn;
                    };
                };
                default {
                    [_group, _target] call FUNC(tacticsRetreat);
                };
            };
        };

        // FORMASYON KORUMA
        private _bndFormation = _group getVariable [QGVAR(dangerFormation), "WEDGE"];
        private _mevcutFormation = formation _group;
        private _grupBaskida = ((units _group) findIf {alive _x && {(getSuppression _x) >= 0.4}}) > -1;
        if (!_grupBaskida && {_mevcutFormation isNotEqualTo _bndFormation}
            && {!(_group getVariable [QGVAR(isRetreating), false])} && {!(_group getVariable [QGVAR(isEvading), false])} && {!(_group getVariable [QGVAR(isBreakingContact), false])}
            && {time > (_group getVariable [QGVAR(formKorumaT), 0])}) then {
            _group setVariable [QGVAR(formKorumaT), time + 45];
            _group setFormation _bndFormation;
        };

        // FORMASYON GUNCELLEME (arazi degisti mi)
        private _sonPos = _group getVariable [QGVAR(bndSonPos), [0,0,0]];
        private _simdiPos = getPosATL (leader _group);
        private _uzaklik = _sonPos distance2D _simdiPos;

        if (_cycleCount isEqualTo 1 || {_uzaklik > 5}) then {
            _group setVariable [QGVAR(bndSonPos), _simdiPos];
            private _yeniFormasyon = [leader _group, _target, "BOUNDING"] call FUNC(selectFormation);
            if (_yeniFormasyon isNotEqualTo _bndFormation && {time > (_group getVariable [QGVAR(formKorumaT), 0])}) then {
                _group setVariable [QGVAR(formKorumaT), time + 20];
                _group setVariable [QGVAR(dangerFormation), _yeniFormasyon];
                _group setFormation _yeniFormasyon;
            };
        };

        // Canli birlikleri yeniden ayir
        _fse      = _fse select {alive _x};
        _maneuver = _maneuver select {alive _x};
        _reserve  = _reserve select {alive _x};

        if (count _fse < 2 && {count _reserve > 0}) then {
            _fse pushBack (_reserve deleteAt 0);
        };
        if (count _maneuver < 2 && {count _reserve > 0}) then {
            _maneuver pushBack (_reserve deleteAt 0);
        };

        private _odak = [_group] call _odakSec;

        // KOMUTAN TAKIP: lider koşucu degil ama bound ekiplerinin ARKASINDAN ilerler (RPT: 6 cycle'da lider hedefe 329 -> 315 m = sadece 14 m,
        // ekipler 42 m'lik atilimlarla ilerlerken lider yerinde kaliyordu). Hedef: ekip agirlik merkezinden 8 m geride; en fazla 10 sn'de bir emir.
        private _ldrT = leader _group;
        if (
            alive _ldrT && {isNull objectParent _ldrT} && {!isPlayer _ldrT}
            && {time > (_group getVariable [QGVAR(bndLiderT), 0])}
        ) then {
            private _uyeler = (units _group) select {alive _x && {_x isNotEqualTo _ldrT} && {isNull objectParent _x}};
            if (count _uyeler >= 2) then {
                private _mrk = [0, 0, 0];
                { _mrk = _mrk vectorAdd (getPosATL _x); } forEach _uyeler;
                _mrk = _mrk vectorMultiply (1 / (count _uyeler));
                private _gerid = _mrk getPos [8, _target getDir _mrk];
                if ((_ldrT distance2D _gerid) > 15 && {!surfaceIsWater _gerid}) then {
                    _group setVariable [QGVAR(bndLiderT), time + 10];
                    _ldrT doMove _gerid;
                };
            };
        };

        // GUNCEL DUSMAN YONU: odak dusman hedeften 25 m'den fazla kaydiysa hedef (siper / sektor / mesafe) guncellenir
        if (!isNull _odak) then {
            private _op = getPosATL _odak;
            _op set [2, 0.5];
            if ((_op distance2D _target) > 25 && {(time - (_group getVariable [QGVAR(bndTargetTime), -999])) > 10}) then {
                _group setVariable [QGVAR(bndTargetTime), time];
                diag_log format [
                    "[BND-YON] %1 | cycle:%2 | hedef %3 m kaydi, yon %4 -> %5 derece (odak: %6)",
                    groupId _group, _cycleCount, round (_op distance2D _target),
                    round ((leader _group) getDir _target), round ((leader _group) getDir _op), name _odak
                ];
                _target = _op;
                _targetASL = AGLToASL _target;
                (leader _group) setVariable [QEGVAR(main,currentTarget), _target, EGVAR(main,debug_functions)];
            };
        };

        // -------------------------------------------------------------------
        // HANGI EKIP HAREKET EDIYOR?
        // -------------------------------------------------------------------
        // DOKTRIN — BOUNDING OVERWATCH (FM 3-21.8): IKI EKIP kesin dönüşümlü: bir ekip HAREKET EDERKEN diger ekip DURUP ates eder.
        //   tek cycle : ALPHA (maneuver + reserve) hareket, BRAVO (FSE: MG / nisanci) overwatch
        //   cift cycle: BRAVO hareket, ALPHA overwatch
        // Hareket eden ekibin TUMU ayni anda kalkar (ekip icinde farkli acilardan), diger ekip tamamen durur.
        // (Eskiden: her 3. cycle FSE, digerlerinde her cift icinden sadece biri -> herkes bir arada kalkip duruyordu)
        private _alphaE = (_maneuver + _reserve) select {alive _x};
        private _bravoE = _fse select {alive _x};
        // DENGE: hareket eden ekip toplamin yarisini gecmesin (RPT: 13 kisilik grupta 8 kisi ayni anda kosarken ates altinda 13 -> 4'e dustu).
        // Fazla kisiler (once MG olmayanlar) digerine gecer: iki ekip ~esit, biri kosarken digeri (>= yari) ates eder.
        private _yarim = ceil (((count _alphaE) + (count _bravoE)) / 2);
        while {(count _alphaE) > _yarim && {(count _alphaE) > 1}} do {
            private _gk = _alphaE select {([_x] call _rolFn) isNotEqualTo "MG"};
            private _kk = if (_gk isEqualTo []) then {_alphaE select ((count _alphaE) - 1)} else {_gk select ((count _gk) - 1)};
            _alphaE = _alphaE - [_kk];
            _bravoE pushBack _kk;
        };
        while {(count _bravoE) > _yarim && {(count _bravoE) > 1}} do {
            private _gk = _bravoE select {([_x] call _rolFn) isNotEqualTo "MG"};
            private _kk = if (_gk isEqualTo []) then {_bravoE select ((count _bravoE) - 1)} else {_gk select ((count _gk) - 1)};
            _bravoE = _bravoE - [_kk];
            _alphaE pushBack _kk;
        };
        private _fseSicrama = ((_cycleCount % 2) isEqualTo 0) && {_bravoE isNotEqualTo []} && {_alphaE isNotEqualTo []};
        private _hareketEdecek = [];
        private _kapsama = [];
        private _ciftYakinla = [];   // eski cift yakinlasma: ekip bound'unda gerek yok (bos kalir)

        if (_fseSicrama) then {
            // BRAVO ileri sicrar (MG kosmaz, kapsamada kalir); ALPHA durup ates eder
            private _bk = _bravoE select {([_x] call _rolFn) isNotEqualTo "MG"};
            if (_bk isEqualTo []) then { _bk = +_bravoE; };
            _hareketEdecek = _bk;
            _kapsama = _alphaE + (_bravoE - _bk);
        } else {
            _rushN = _rushN + 1;
            // ALPHA ileri sicrar (MG kosmaz); BRAVO durup ates eder
            private _ak = _alphaE select {([_x] call _rolFn) isNotEqualTo "MG"};
            if (_ak isEqualTo []) then { _ak = +_alphaE; };
            _hareketEdecek = _ak;
            _kapsama = _bravoE + (_alphaE - _ak);
        };

        // KOMUTAN ONDE KOSMAZ: lider sicramaya katilmaz, kapsama ekibinde (geriden) ates eder ve yonetir;
        // yalnizca baska kosacak kimse kalmadiysa kosar
        private _ldrB = leader _group;
        if ((_ldrB in _hareketEdecek) && {(count _hareketEdecek) > 1}) then {
            _hareketEdecek = _hareketEdecek - [_ldrB];
            _ciftYakinla = _ciftYakinla select {(_x select 0) isNotEqualTo _ldrB};
            _kapsama pushBackUnique _ldrB;
        };

        // Kosacak kimse yoksa (manevra ekibi eridi / cift kurulamadi) FSE + rezerv sicrar; donga durmasin
        if (_hareketEdecek isEqualTo [] && {(_fse + _reserve) isNotEqualTo []}) then {
            _hareketEdecek = (_fse + _reserve) select {alive _x};
            _kapsama = _maneuver select {alive _x};
            _fseSicrama = true;
        };

        // -------------------------------------------------------------------
        // 0) ATES USSU KURULUMU (OVERWATCH)
        //    cycle 1: FSE'NIN TAMAMI korunakli + gorusu olan atis pozisyonuna (findCover OVERWATCH),
        //             varana kadar BEKLENIR; maneuver ancak ates ussu kurulunca kalkar
        //    cycle 5, 9..: MG / nisanci pozisyonu tazelenir (beklemeden)
        // -------------------------------------------------------------------
        if (_cycleCount isEqualTo 1) then {
            private _kurulum = [];
            {
                if (alive _x && {isNull objectParent _x}) then {
                    private _ow = [_x, _target, 30, "ASCEND", 1, "OVERWATCH"] call EFUNC(main,findCover);
                    // v8.13 KOMUTAN ARAZI BILINCI: MG / nisanci icin HAKIM NOKTA (>= 2.5 m yuksek, tehdidi goren, ufukta olmayan) 45 m icindeyse oraya
                    if (([_x] call _rolFn) in ["MG", "MARKSMAN"]) then {
                        private _arz = [getPosATL _x, 45, _target] call FUNC(araziAnaliz);
                        private _hk = _arz getOrDefault ["hakim", []];
                        if (_hk isNotEqualTo []) then {
                            _ow = [[_hk select 0, "DOWN"]];
                            diag_log format ["[ARAZI-KOMUTAN] %1 | %2 hakim noktaya gozetleme: +%3 m yuksek", groupId _group, name _x, (_hk select 1) toFixed 1];
                        };
                    };
                    if (_ow isNotEqualTo []) then {
                        private _owPos = (_ow select 0) select 0;
                        private _owStance = (_ow select 0) select 1;
                        if ((_x distance2D _owPos) > 4) then {
                            _x setVariable [QGVAR(forceMove), true];
                            _x setUnitPosWeak "UP";
                            _x moveTo _owPos;
                            _kurulum pushBack [_x, _owPos, _owStance];
                        } else {
                            _x setUnitPosWeak _owStance;
                        };
                    };
                };
            } forEach _fse;

            private _kurBitis = time + ([_group, "owKurulumS", 5] call FUNC(dk));   // spawn icinde: dis kapsam degiskeni (_dkOwKurulum) GORUNMEZ -> dogrudan oku   // overwatch kurulum tavani (eskiden 8 sn: ilk bound'a 14-16 sn gec basliyordu)
            waitUntil {
                sleep 0.5;
                {
                    _x params ["_b", "_p", "_s"];
                    if (alive _b && {(_b distance2D _p) < 4}) then {
                        _b setVariable [QGVAR(forceMove), nil];
                        _b setUnitPosWeak _s;
                    };
                } forEach _kurulum;
                !(call _hala)
                || {time > _kurBitis}
                || {(_kurulum findIf {alive (_x select 0) && {((_x select 0) distance2D (_x select 1)) >= 4}}) isEqualTo -1}
            };
            {
                _x params ["_b", "_p", "_s"];
                if (alive _b) then {
                    _b setVariable [QGVAR(forceMove), nil];
                    _b setUnitPosWeak _s;
                };
            } forEach _kurulum;

            private _fseCanli = _fse select {alive _x};
            diag_log format [
                "[OVERWATCH] %1 | FSE:%2 | pozisyona giden:%3 | MG/nisanci:%4",
                groupId _group, count _fseCanli, count _kurulum,
                count (_fseCanli select {([_x] call _rolFn) in ["MG", "MARKSMAN"]})
            ];
        } else {
            if ((_cycleCount % 4) isEqualTo 1) then {
                {
                    if (alive _x && {isNull objectParent _x} && {([_x] call _rolFn) in ["MG", "MARKSMAN"]}) then {
                        private _ow = [_x, _target, 30, "ASCEND", 1, "OVERWATCH"] call EFUNC(main,findCover);
                        if (_ow isNotEqualTo []) then {
                            private _owPos = (_ow select 0) select 0;
                            if ((_x distance2D _owPos) > 4) then {
                                _x moveTo _owPos;
                                _x setUnitPosWeak "UP";   // yolda cokerek / surunerek gitmesin
                            } else {
                                _x setUnitPosWeak ((_ow select 0) select 1);
                            };
                        };
                    };
                } forEach _kapsama;
            };
        };

        if (!(call _hala)) exitWith {};

        // overwatch kurulumu 8 sn'e kadar surebilir: odak dusman bayatlamis olabilir -> yenile
        _odak = [_group] call _odakSec;

        // -------------------------------------------------------------------
        // 1) ATES FAZI — kapsama ekibi ates acar; ATES USTUNLUGU KAPISI:
        //    kosucular odak dusman BASTIRILDIKTAN sonra (baski >= 0.25) kalkar; en fazla 5 sn,
        //    odak yoksa / oldu ise 1.5 sn. Dusman ates ediyorken koşulmaz.
        // -------------------------------------------------------------------
        private _atesBasi = time;
        [_kapsama, _target, _targetASL, _odak, if (_fseSicrama) then {"Bound/Cover(Maneuver)"} else {"Bound/Suppress"}] call _atesEt;

        waitUntil {
            sleep 0.5;
            !(call _hala)
            || {(time - _atesBasi) >= 5}
            || {
                ((time - _atesBasi) >= 1.5)
                && {isNull _odak || {!alive _odak} || {(getSuppression _odak) >= 0.25}}
            }
        };

        if (!(call _hala)) exitWith {};

        // -------------------------------------------------------------------
        // 2) HAREKET FAZI — kosanlar siperli ileri sicrama
        // -------------------------------------------------------------------
        private _hareketler = [];
        // v8.7 ROTA PLANLAMA: ortulu yaklasma yonu (sapma acisi); yelpaze bu acinin etrafinda kurulur (toplam en fazla +-75 derece)
        private _rotaAci = [_group, _target] call FUNC(rotaPlan);
        {
            private _h = [_x, _target, _BND_COVER_RANGE, _BND_ASSAULT_RANGE, if (_fseSicrama) then {"Leapfrog/Move"} else {"TeamBound/Move"}, (_rotaAci + ([30, -30, 0] select ((_forEachIndex + _cycleCount) % 3))) max -75 min 75] call _kosanHareket;
            if (_h isNotEqualTo []) then { _hareketler pushBack _h; };
        } forEach _hareketEdecek;

        // Gozle gorulur: lider jest + callout (30 sn'de bir)
        // JEST + CAGRI: her cycle DEGIL, 45 sn'de bir (surekli "ilerle / ilerle" spam'i olmasin)
        if (_hareketler isNotEqualTo []) then {
            private _sonCycleCallout = _group getVariable [QGVAR(bndSonCycleCallout), 0];
            if ((time - _sonCycleCallout) > 45) then {
                [leader _group, ["gestureGo"]] call EFUNC(main,doGesture);
                [leader _group, "combat", "Advance", 125] call EFUNC(main,doCallout);
                _group setVariable [QGVAR(bndSonCycleCallout), time];
            };

            // Gozlem: her cycle bir satir (debug kapaliyken de). kapi = ates ustunlugu bekleme suresi (max 5)
            diag_log format [
                "[BND] %1 | cycle:%2 | %3 | hareket:%4 kapsama:%5 | kapi:%6s | odak:%7 %8m baski:%9 | atilim:%10 acik:%11",
                groupId _group, _cycleCount, ["buddy", "FSE-sicrama"] select _fseSicrama,
                count _hareketler, count _kapsama, (time - _atesBasi) toFixed 1,
                if (isNull _odak) then {"yok"} else {name _odak},
                if (isNull _odak) then {0} else {round ((leader _group) distance2D _odak)},
                if (isNull _odak) then {"-"} else {(getSuppression _odak) toFixed 2},
                _hareketler apply {round (_x param [3, 0])},
                _hareketler apply {_x param [4, 0]}
            ];
        };

        // Araclar
        // Araclar: sadece ilk cycle'da, hedefin onunde standoff (+40 m) ile dur (hedefe surup girmesin)
        if (_cycleCount isEqualTo 1) then {
            { if (alive _x) then { _x doMove (_target getPos [_BND_ASSAULT_RANGE + 40, _target getDir _x]); }; } forEach _vehicles;
        };

        // Varisa kadar bekle (9 sn + baski kadar ek), varan askere siper stance'i
        private _maxSupp = 0;
        { _maxSupp = _maxSupp max (getSuppression _x); } forEach (_hareketEdecek select {alive _x});
        private _bekleBitis = time + 9 + (_maxSupp * 4);
        private _inen = [];
        private _yenidenSecti = [];
        private _yonKontrol = time;

        waitUntil {
            sleep 0.5;

            // DUSMAN YONU DEGISTI (yolda): odak 40 m'den fazla kaydiysa varmamis kosucular siperini yeniden secer
            if ((time - _yonKontrol) > 3) then {
                _yonKontrol = time;
                private _oN = [_group] call _odakSec;
                if (!isNull _oN) then {
                    private _np = getPosATL _oN;
                    _np set [2, 0.5];
                    if ((_np distance2D _target) > 40) then {
                        diag_log format [
                            "[BND-YON] %1 | cycle:%2 | YOLDA hedef %3 m kaydi -> siper yeniden seciliyor",
                            groupId _group, _cycleCount, round (_np distance2D _target)
                        ];
                        _group setVariable [QGVAR(bndTargetTime), time];
                        _target = _np;
                        _targetASL = AGLToASL _target;
                        (leader _group) setVariable [QEGVAR(main,currentTarget), _target, EGVAR(main,debug_functions)];
                        {
                            private _rb = _x select 0;
                            if (alive _rb && {!(_rb in _inen)} && {!(_rb in _yenidenSecti)}) then {
                                _yenidenSecti pushBack _rb;
                                private _yh = [_rb, _target, _BND_COVER_RANGE, _BND_ASSAULT_RANGE, "Bound/YonDegisti"] call _kosanHareket;
                                if (_yh isNotEqualTo []) then { _hareketler set [_forEachIndex, _yh]; };
                            };
                        } forEach _hareketler;
                    };
                };
            };

            {
                _x params ["_b", "_p", "_s"];
                if (alive _b && {!(_b in _inen)} && {(_b distance2D _p) < 4}) then {
                    _inen pushBack _b;
                    _b setVariable [QGVAR(forceMove), nil];
                    _b setUnitPosWeak _s;
                } else {
                    // Baski >= 0.85: kosucu ezildi -> forceMove birakilir, FSM siper alir
                    if (alive _b && {!(_b in _inen)} && {(getSuppression _b) >= 0.85}) then {
                        _inen pushBack _b;
                        _b setVariable [QGVAR(forceMove), nil];
                        _b setUnitPosWeak "DOWN";
                    };
                };
            } forEach _hareketler;
            !(call _hala)
            || {time > _bekleBitis}
            || {(_hareketler findIf {alive (_x select 0) && {!((_x select 0) in _inen)}}) isEqualTo -1}
        };

        // Varamayanlar da siper stance'ine gecsin
        {
            _x params ["_b", "_p", "_s"];
            if (alive _b) then {
                _b setVariable [QGVAR(forceMove), nil];
                [_b, _p, _s] call _durusFn;
            };
        } forEach _hareketler;

        if (!(call _hala)) exitWith {};

        // -------------------------------------------------------------------
        // 2b) CIFT YAKINLASMA — kosucu siperde iken esi AYNI siperin 2-8 m yanina gelir
        //     (cift ayni / cok yakin siperde: birbirini korur, aralarinda 25 m bosluk kalmaz)
        // -------------------------------------------------------------------
        private _yakinlasan = [];
        private _yMes = [];
        {
            _x params ["_kosan", "_destekler"];
            private _hi = _hareketler findIf {(_x select 0) isEqualTo _kosan};
            if (alive _kosan && {_hi > -1}) then {
                private _cp = (_hareketler select _hi) select 1;
                if ((_kosan distance2D _cp) < 12) then {
                    {
                        private _d = _x;
                        if (
                            alive _d && {isNull objectParent _d}
                            && {(getSuppression _d) < 0.6}
                            && {(_d distance2D _cp) > 8}
                            && {(_d distance2D _cp) < 30}
                        ) then {
                            private _dPos = [];
                            private _dStance = "MIDDLE";
                            private _cv = [_d, _target, 40, "ASCEND", 6, "ADVANCE"] call EFUNC(main,findCover);
                            private _ci = _cv findIf {
                                private _dd = (_x select 0) distance2D _cp;
                                _dd >= 2 && {_dd <= 8}
                            };
                            if (_ci > -1) then {
                                _dPos = (_cv select _ci) select 0;
                                _dStance = (_cv select _ci) select 1;
                            } else {
                                // Yakinda ayri siper yok: kosucunun yaninda 3-6 m (yanal) bosluk
                                private _yan = [-90, 90] select (_forEachIndex % 2);
                                _dPos = _cp getPos [3 + (random 3), (_target getDir _cp) + _yan];
                            };
                            if (!surfaceIsWater _dPos) then {
                                _yMes pushBack (round (_d distance2D _dPos));
                                _d setVariable [QGVAR(forceMove), true];
                                _d setUnitPosWeak "UP";
                                _d moveTo _dPos;
                                _d doWatch _target;
                                _d forceSpeed -1;
                                _yakinlasan pushBack [_d, _dPos, _dStance];
                            };
                        };
                    } forEach _destekler;
                };
            };
        } forEach _ciftYakinla;

        if (_yakinlasan isNotEqualTo []) then {
            private _yBitis = time + 7;
            private _yInen = [];
            waitUntil {
                sleep 0.5;
                {
                    _x params ["_b", "_p", "_s"];
                    if (alive _b && {!(_b in _yInen)} && {((_b distance2D _p) < 3) || {(getSuppression _b) >= 0.85}}) then {
                        _yInen pushBack _b;
                        _b setVariable [QGVAR(forceMove), nil];
                        _b setUnitPosWeak ([_s, "DOWN"] select ((getSuppression _b) >= 0.85));
                    };
                } forEach _yakinlasan;
                !(call _hala)
                || {time > _yBitis}
                || {(_yakinlasan findIf {alive (_x select 0) && {!((_x select 0) in _yInen)}}) isEqualTo -1}
            };
            {
                _x params ["_b", "_p", "_s"];
                if (alive _b) then {
                    _b setVariable [QGVAR(forceMove), nil];
                    [_b, _p, _s] call _durusFn;
                };
            } forEach _yakinlasan;
            diag_log format [
                "[BND-YAKIN] %1 | cycle:%2 | esi yanina gelen:%3 | atilim:%4",
                groupId _group, _cycleCount, count _yakinlasan, _yMes
            ];
        };

        if (!(call _hala)) exitWith {};

        // -------------------------------------------------------------------
        // 3) ORTAK ATES — kosanlar siperde, herkes baski + odak ates
        // -------------------------------------------------------------------
        private _odak2 = [_group] call _odakSec;
        [(_hareketEdecek + _kapsama) select {alive _x}, _target, _targetASL, _odak2, "Bound/Fire"] call _atesEt;

        // -------------------------------------------------------------------
        // 4) SIPER OMRU — siperde en az BASE+1.5 .. +RAND sn kal (hemen kalkma); baski varsa 3 sn uzar;
        //    suresinin sonunda, baskida degilse PEEK: kisaca kalkip nisan al, sonra siper stance'ine don
        // -------------------------------------------------------------------
        private _siperde = (_hareketler + _yakinlasan) select {alive (_x select 0)};
        { _maxSupp = _maxSupp max (getSuppression (_x select 0)); } forEach _siperde;   // yola cikmadan onceki deger bayat
        private _omurBitis = time + _BND_CYCLE_BASE + 1.5 + (random _BND_CYCLE_RAND) + (_maxSupp * _BND_SUPPRESSION_MUL);
        private _uzatildi = false;
        private _peekte = false;
        private _siperGeri = {
            { if (alive (_x select 0)) then { _x call _durusFn; }; } forEach _this;
        };

        while {
            time < _omurBitis
            && {!isNull _group}
            && {_group getVariable [QGVAR(isBounding), false]}
        } do {
            sleep 0.5;
            private _baskiMax = 0;
            { _baskiMax = _baskiMax max (getSuppression (_x select 0)); } forEach (_siperde select {alive (_x select 0)});
            { _baskiMax = _baskiMax max (getSuppression _x); } forEach (_kapsama select {alive _x});

            if (_baskiMax >= 0.5 && {!_uzatildi}) then {
                _uzatildi = true;
                _omurBitis = _omurBitis + 3;
            };
            if (_peekte && {_baskiMax >= 0.5}) then {
                _peekte = false;
                _siperde call _siperGeri;
            };
            if (!_peekte && {_baskiMax < 0.4} && {time > (_omurBitis - 2.2)} && {time < (_omurBitis - 0.5)}) then {
                _peekte = true;
                {
                    private _pb = _x select 0;
                    if (
                        alive _pb && {(_x select 2) isNotEqualTo "UP"}
                        && {(getSuppression _pb) < 0.3}
                        && {(_pb distance2D (_x select 1)) < 4}
                    ) then {
                        _pb setUnitPosWeak "UP";
                    };
                } forEach _siperde;
            };
        };
        _siperde call _siperGeri;
    };

    if (!isNull _group) then {
        diag_log format [
            "[BND-BITTI] %1 | cycle:%2 | mesafe:%3m | bizim:%4",
            groupId _group, _cycleCount, round ((leader _group) distance2D _target),
            (_group getVariable [QGVAR(bndToken), ""]) isEqualTo _bndToken
        ];
        [_group, "BoundingBitti", [_cycleCount, round ((leader _group) distance2D _target)]] call FUNC(olayGonder);
    };

    // Dongu bitti — token eslesiyorsa bu bounding hala bizim (Retreat devralmadi)
    if (
        !isNull _group
        && {(_group getVariable [QGVAR(bndToken), ""]) isEqualTo _bndToken}
    ) then {
        private _yakin = ((leader _group) distance2D _target < (_BND_ASSAULT_RANGE + 10))
            && {({alive _x} count (units _group)) >= 2};
        [_group] call _bndTemizle;
        if (_yakin) then {
            [_group, _target] call FUNC(tacticsAssault);
        } else {
            // Cycle limiti doldu / hedef uzak: kilidi birak, gruba normal davranisi geri ver
            { if (alive _x) then { _x doFollow (leader _x); }; } forEach (units _group);
        };
    };
};

// end
true
