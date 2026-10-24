#include "script_component.hpp"
/*
 * Author: Cinar (ELITE fork)
 * TOPCU DESTEK (v8.214; yol haritasi 4) — plan topcusu disinda ek destek ateslari:
 *  "SIS"   : DUMAN PERDESI — saldiri basinda dusman gozetlemesini kor etmek icin hedefin onune (yaklasma yonune) duman mermisi (dost sinirinda; ates kaydirma/yikici deyil). Duman mermisi yoksa loglanir, atilmaz.
 *  "KARSI" : KARSI-BATARYA — tarafin BILDIGI (knowsAbout) dusman topcu / havan araci icin tarafin kendi topcusu 3 mermi atar (dost mesafesi >= 200 m; ayni hedefe 90 sn'de bir). Kaynak ilkesi (FM 3-09 karsi atesli destek): dusman atesli desteginin imhasi / bastirilmasi; sayisal esikler tasarim degerleridir.
 *  "OPERATOR": DRON OPERATORU KARSI ATESI (v8.307; kullanici: 'dronun geldigi yone acimasinlar') — nokta = tahmini operator / firlatma bolgesi (ucus izinden geri cikarim); dost 200 m icinde ise atilmaz; HE (duman / isik / fisek haric) 3 mermi, 45 m yayilim.
 * v8.338 KITAP DENETIMI: OPERATOR ve KARSI modlari dost mesafesini tek tip 200 m ile denetliyordu; kitaptaki RED (TC 3-21.76 Tablo 3-3) 120 mm icin ~430 m, 105 / 155 mm icin ~455 m. Artik her top icin
 *   fnc_topcuRed + fnc_topcuGuvenlik: dost >= RED + 20 m, ates yasak alan (NFA) ve sivil yok; ayrica gozlemsiz (duzeltmesiz) atis oldugu icin DANGER CLOSE alaninda (dost <= 600 m) ATILMAZ.
 *   Eski davranis (200 m): lambs_danger_topcuEskiMesafe = true. SIS (duman) modu degismedi (duman mermisi yaralayici degil).
 * Log: [PLAN-SIS] / [PLAN-KARSI-BATARYA] / [DRON-KARSI-ATES]
 *
 * Arguments:
 * 0: Taraf <SIDE>
 * 1: Nokta (SIS icin duman noktasi; KARSI icin yok sayilir) <ARRAY>
 * 2: Mod "SIS" / "KARSI" <STRING>
 * 3: Plan kimligi (log) <STRING>
 * 4: OPERATOR modu yayilim yaricapi (m, varsayilan 45) <NUMBER>
 * 5: OPERATOR modu en cok top (varsayilan 99) <NUMBER>
 *
 * Return Value: Atan arac sayisi <NUMBER>
 * Public: No
*/

params [["_taraf", sideUnknown, [sideUnknown]], ["_poz", [0, 0, 0], [[]]], ["_mod", "SIS", [""]], ["_id", "?", [""]], ["_yay", 45, [0]], ["_topMax", 99, [0]]];   // v8.327: OPERATOR modunda yayilim (m) ve en cok top

private _topcular = vehicles select {
    alive _x && {(side (group _x)) isEqualTo _taraf} && {(getNumber (configOf _x >> "artilleryScanner")) > 0} && {!isNull (gunner _x)} && {!isPlayer (gunner _x)} && {local _x} && {canFire _x}
    && {!("TOPCU_YOK" in [_x getVariable ["lambs_danger_gorev", ""], (group (gunner _x)) getVariable ["lambs_danger_gorev", ""]])}
};
private _atan = 0;

if (_mod isEqualTo "SIS") then {
    {
        private _v = _x;
        private _siseler = (getArtilleryAmmo [_v]) select {(toLower _x) find "smoke" >= 0};
        if (_siseler isEqualTo []) then {
            diag_log format ["[PLAN-SIS] %1 | %2 duman mermisi yok (%3) - perde atilmadi", _id, typeOf _v, getArtilleryAmmo [_v]];
        } else {
            if (_poz inRangeOfArtillery [[_v], _siseler select 0]) then {
                [_v, _poz, _siseler select 0, _forEachIndex] spawn {
                    params ["_tv", "_tn", "_tm", "_ti"];
                    sleep (3 * _ti);
                    if (alive _tv && {canFire _tv}) then { _tv doArtilleryFire [_tn getPos [random 25, random 360], _tm, 2]; };
                };
                _atan = _atan + 1;
                diag_log format ["[PLAN-SIS] %1 | duman perdesi: %2 -> %3 (%4, 2 mermi)", _id, typeOf _v, mapGridPosition _poz, _siseler select 0];
            };
        };
    } forEach _topcular;
};

if (_mod isEqualTo "OPERATOR") then {
    private _dostVar = false;
    private _eski = missionNamespace getVariable ["lambs_danger_topcuEskiMesafe", false];
    { if (alive _x && {(side (group _x)) isEqualTo _taraf} && {(_x distance2D _poz) < 200}) exitWith { _dostVar = true; }; } forEach allUnits;
    if (!_dostVar && {!surfaceIsWater _poz}) then {
        {
            private _v = _x;
            private _mg = ((getArtilleryAmmo [_v]) select {
                private _a = toLower _x;
                (_a find "smoke") < 0 && {(_a find "illum") < 0} && {(_a find "flare") < 0} && {(_a find "cluster") < 0} && {(_a find "mine") < 0}
            }) param [0, ""];
            // v8.338: kitap RED + gozlemsiz atista danger close (600 m) yasagi
            private _guv = if (_eski || {_mg isEqualTo ""}) then {[true, "", 0, false, []]} else {[_taraf, _poz, [_v, _mg] call FUNC(topcuRed)] call FUNC(topcuGuvenlik)};
            private _guvOk = (_guv select 0) && {_eski || {!(_guv select 3)}};
            if (!_guvOk && {_mg isNotEqualTo ""}) then {
                diag_log format ["[DRON-KARSI-ATES] %1 | %2 ATMADI (kitap emniyeti): %3", _id, typeOf _v, if (_guv select 0) then {format ["gozlemsiz atista danger close: en yakin dost %1 m <= 600 m", round (_guv select 2)]} else {_guv select 1}];
            };
            if (_guvOk && {_mg isNotEqualTo ""} && {_atan < _topMax} && {_poz inRangeOfArtillery [[_v], _mg]}) then {
                // v8.339: hareket emri iptal / davranis / nisanci AI + [TOPCU-ATIS] Fired tanisi (plan atisiyla ayni hazirlik); RPT 21-43: operator atesinde bir mermi hedeften ~1.6 km uzaga dustu (Sh_82mm_AMOS), neden bu logla ayirt edilecek
                [_v, _poz, _mg] call FUNC(topcuAtisHazirla);
                diag_log format ["[DRON-KARSI-ATES] %1 | ATIS EMRI: %2 (%3) mermi %4 -> %5 | mesafe %6 m | ETA %7 sn | yayilim %8 m | tum mermiler: %9", _id, typeOf _v, getText (configOf _v >> "displayName"), _mg, mapGridPosition _poz, round (_v distance2D _poz), round (_v getArtilleryETA [_poz, _mg]), _yay, getArtilleryAmmo [_v]];
                [_v, _poz, _mg, _atan, _yay] spawn {
                    params ["_tv", "_tn", "_tm", "_ti", "_ty"];
                    sleep (3 * _ti);
                    if (alive _tv && {canFire _tv}) then { _tv doArtilleryFire [_tn getPos [random _ty, random 360], _tm, 3]; };
                };
                _atan = _atan + 1;
            };
        } forEach _topcular;
    };
};

if (_mod isEqualTo "KARSI") then {
    private _hedefler = vehicles select {
        private _h0 = _x;
        alive _x && {(getNumber (configOf _x >> "artilleryScanner")) > 0} && {!isNull (gunner _x)} && {(_taraf getFriend (side (group (gunner _x)))) < 0.6} && {(allGroups findIf {(side _x) isEqualTo _taraf && {!isNull (leader _x)} && {(_x knowsAbout _h0) >= 1.0}}) >= 0}
        && {(time - (_x getVariable ["lambs_danger_karsiBatT", -999])) > 90}
    };
    {
        private _h = _x;
        private _hp = getPosATL _h;
        private _dost = false;
        private _eski = missionNamespace getVariable ["lambs_danger_topcuEskiMesafe", false];
        { if (alive _x && {(side (group _x)) isEqualTo _taraf} && {(_x distance2D _hp) < 200}) exitWith { _dost = true; }; } forEach allUnits;
        if (!_dost) then {
            private _atanBu = 0;
            {
                private _v = _x;
                private _mg = (getArtilleryAmmo [_v]) param [0, ""];
                // v8.338: kitap RED + gozlemsiz atista danger close (600 m) yasagi (karsi-batarya duzeltmesiz atilir)
                private _guv = if (_eski || {_mg isEqualTo ""}) then {[true, "", 0, false, []]} else {[_taraf, _hp, [_v, _mg] call FUNC(topcuRed)] call FUNC(topcuGuvenlik)};
                private _guvOk = (_guv select 0) && {_eski || {!(_guv select 3)}};
                if (!_guvOk && {_mg isNotEqualTo ""} && {(time - (_h getVariable ["lambs_danger_karsiBatRetT", -999])) > 60}) then {
                    _h setVariable ["lambs_danger_karsiBatRetT", time];
                    diag_log format ["[PLAN-KARSI-BATARYA] %1 | %2 ATMADI (kitap emniyeti): %3", _id, typeOf _v, if (_guv select 0) then {format ["gozlemsiz atista danger close: en yakin dost %1 m <= 600 m", round (_guv select 2)]} else {_guv select 1}];
                };
                if (_guvOk && {_mg isNotEqualTo ""} && {_v isNotEqualTo _h} && {_hp inRangeOfArtillery [[_v], _mg]}) then {
                    [_v, _hp, _mg] call FUNC(topcuAtisHazirla);   // v8.339: hazirlik + [TOPCU-ATIS] tanisi
                    [_v, _hp, _mg, _atan] spawn {
                        params ["_tv", "_tn", "_tm", "_ti"];
                        sleep (3 * _ti);
                        if (alive _tv && {canFire _tv}) then { _tv doArtilleryFire [_tn getPos [random 20, random 360], _tm, 3]; };
                    };
                    _atan = _atan + 1; _atanBu = _atanBu + 1;
                };
            } forEach _topcular;
            if (_atanBu > 0) then {
                _h setVariable ["lambs_danger_karsiBatT", time];
                diag_log format ["[PLAN-KARSI-BATARYA] %1 | dusman topcu %2 (%3) bilinen -> %4 top 3'er mermi", _id, typeOf _h, mapGridPosition _hp, _atanBu];
            };
        };
    } forEach _hedefler;
};

_atan
