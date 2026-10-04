#include "script_component.hpp"
/*
 * Author: Cinar (ELITE fork)
 * DRON + HELIKOPTER FARKINDALIGI (v8.47; v8.51: ATP 3-01.8 ates disiplini + toplu ates)
 *
 * Doktrin (ATP 3-01.8, kaynaklar_doktrin/HAVA_IED_DOKTRIN_OZET.md):
 *   - Oz savunma (2-8): hostile act / hostile intent'e karsi organik silahlarla (kucuk silah dahil) karsilik verilir.
 *   - Weapons-Hold (2-13): saldirmayan hava araci icin yalniz oz savunma; 3-4: saldirmayan araca ates etmek konumu ele verir -> once pasif onlem.
 *   - Pasif onlemler (3-5..3-9): gizlen, dagil, siper al / bina.
 *   - Kucuk silah (4-26..4-30, 4-42): karar komutanin; yalniz ALCAK ucan hedefe; "volume fire" komutla (bireysel degil), tek nisan noktasi (onculuk);
 *     uzak (kaynak ornek: 3 km) saldirgana etkisiz; olum olasiligi dusuk ama pilotu saldirisini birakmaya zorlayabilir.
 *   - Hover eden saldiri helisi buyuk olasilikla fuze atmaya hazirlaniyor (4-43): oncelikli tehdit.
 * Kaynakta SAYISAL ESIK yok; asagidaki degerler TASARIM tahminidir:
 *   - saldiri: heli son 20 sn icinde ates etti (Fired) VEYA grupta baski (getSuppression > 0.15) + heli <= 800 m.
 *   - kucuk silah zarfi: <= 600 m ve yukseklik <= 300 m. 20 sn toplu ates, 60 sn bekleme (lambs_danger_havaVolSn).
 *   - saldirmayan silahli heli: grup gizlenir (HIDE / GARRISON, 120 sn); bounding / taktik yurutenler yurumeye devam eder ama
 *     ates disiplini uygulanir (forgetTarget, yalniz zarf disindaysa); AA'li asker (Stinger / Strela / Igla) kimligi belli dusmana ates eder.
 *   - hover eden silahli heli: bilgi esigi 0.15, menzil 1500 m (oncelikli).
 *   - silahsiz dron <= 700 m, silahli dron <= 900 m. Silahsiz tasima helisi: yalniz reveal.
 *   - bilgi esigi 0.4 (lambs_danger_havaBilgiEsik).
 * Teshis: [HAVA-FARK-TANI] (30 sn'de bir), [HAVA-FARK-ATLA], [HAVA-FARK] ... tepki. v8.51: watchdog hata verirse otomatik yeniden baslar ([WATCHDOG-YENIDEN]).
 * Kapatma: lambs_danger_havaFarkOff = true.
 *
 * Arguments:
 * None
 *
 * Return Value:
 * Baslatildi mi <BOOL>
 *
 * Public: No
*/

if (!isNil "lambs_danger_havaFarkStarted") exitWith {false};
lambs_danger_havaFarkStarted = true;

diag_log "[HAVA-FARK] dron / helikopter farkindaligi watchdog baslatildi (v8.51)";

private _calis = {
    missionNamespace setVariable ["lambs_danger_havaAdim", "basladi"];
    private _logN = 0;
    private _tur = 0;
    private _nabizT = time + 60;
    private _turMs = 0;
    private _tani = 0;
    private _taniN = 0;
    private _atlaT = 0;
    private _disT = 0;
    private _atlaN = 0;
    private _eleN = 0;
    while {true} do {
        sleep 3;
        private _t0 = diag_tickTime;
        _tur = _tur + 1;
        missionNamespace setVariable ["lambs_danger_havaAdim", format ["tur %1: hava araci listesi", _tur]];
        if (missionNamespace getVariable ["lambs_danger_havaFarkOff", false]) then { continue };
        // NABIZ: dongu yasiyor mu, kac hava araci / yerel grup var, son turun suresi (60 sn'de bir)
        if (time > _nabizT) then {
            _nabizT = time + 60;
            diag_log format ["[HAVA-FARK-NABIZ] tur:%1 | hava araci:%2 | yerel AI grup:%3 | son tur:%4 ms | adim:%5", _tur, count (vehicles select {alive _x && {(_x isKindOf "Helicopter") || {unitIsUAV _x}}}), count (allGroups select {local _x && {!isNull leader _x} && {!isPlayer leader _x}}), round _turMs, missionNamespace getVariable ["lambs_danger_havaAdim", "?"]];
        };
        private _hava = vehicles select {alive _x && {(_x isKindOf "Helicopter") || {unitIsUAV _x}} && {(count (crew _x)) > 0}};
        if (_hava isEqualTo []) then { continue };

        // heli ates ettiginde saat tutulur (Fired); yerel degilse aracin sahibinde eklenir
        {
            if (isNil {_x getVariable "lambs_danger_havaEH"}) then {
                _x setVariable ["lambs_danger_havaEH", true];
                private _eh = { params ["_veh"]; if ((time - (_veh getVariable ["lambs_danger_havaAtesT", -99])) > 2) then { _veh setVariable ["lambs_danger_havaAtesT", time, true]; if ((time - (missionNamespace getVariable ["lambs_danger_havaAtesLogT", -99])) > 10) then { missionNamespace setVariable ["lambs_danger_havaAtesLogT", time]; diag_log format ["[HAVA-FARK-ATES] %1 ates etti (Fired EH, bu makinede)", typeOf _veh]; }; }; };
                if (local _x) then { _x addEventHandler ["Fired", _eh]; diag_log format ["[HAVA-FARK-ATES] %1 icin Fired EH eklendi (YEREL arac)", typeOf _x]; } else { [_x, ["Fired", _eh]] remoteExecCall ["addEventHandler", _x]; diag_log format ["[HAVA-FARK-ATES] %1 icin Fired EH uzaktan istendi (arac baska makinede; remoteExec engelli olabilir)", typeOf _x]; };
            };
        } forEach _hava;

        // tani: yakin hava araci (<=1500 m) varsa 30 sn'de bir listele
        if (time > _tani) then {
            _tani = time + 30;
            {
                private _gv = _x;
                private _lv = leader _gv;
                if (!isNull _lv && {local _lv} && {!isPlayer _lv} && {alive _lv}) then {
                    {
                        private _dv = _lv distance2D _x;
                        if (_dv <= 1500 && {_taniN < 120}) then {
                            _taniN = _taniN + 1;
                            diag_log format ["[HAVA-FARK-TANI] %1 | %2 %3 %4 m | taraf:%5 dost:%6 | knows:%7 | silahli:%8 uav:%9 | ates:%10 sn once hover:%11 | bayrak: bnd:%12 tac:%13 ret:%14",
                                groupId _gv, typeOf _x, side (group (effectiveCommander _x)), round _dv, side _gv, (side _gv) getFriend (side (group (effectiveCommander _x))),
                                (_gv knowsAbout _x) toFixed 2, ((_x weaponsTurret [-1]) isNotEqualTo []) || {(_x weaponsTurret [0]) isNotEqualTo []}, unitIsUAV _x,
                                round (time - (_x getVariable ["lambs_danger_havaAtesT", -999])), ((speed _x) < 15) && {((getPosATL _x) select 2) > 8},
                                _gv getVariable [QGVAR(isBounding), false], _gv getVariable [QGVAR(isExecutingTactic), false], _gv getVariable [QGVAR(isRetreating), false]];
                        };
                    } forEach _hava;
                };
            } forEach (allGroups select {local _x && {!isNull leader _x} && {side _x != civilian}});
        };

        {
            private _g = _x;
            private _l = leader _g;
            if (isNull _l || {isPlayer _l} || {!local _l} || {!alive _l} || {!isNull objectParent _l}) then { continue };
            missionNamespace setVariable ["lambs_danger_havaAdim", format ["tur %1: grup %2", _tur, groupId _g]];
            if (
                (_g getVariable [QGVAR(isRetreating), false]) || {_g getVariable [QGVAR(isEvading), false]} || {_g getVariable [QGVAR(isBreakingContact), false]}
                || {_g getVariable [QGVAR(sniperTeam), false]}
            ) then {
                // neden atlandi: heli <= 1500 m ise 15 sn'de bir yaz
                if ((time - (_g getVariable [QGVAR(havaAtlaT), -99])) > 15 && {(_hava findIf {(_l distance2D _x) <= 1500}) >= 0} && {_atlaN < 80}) then {
                    _g setVariable [QGVAR(havaAtlaT), time];
                    _atlaN = _atlaN + 1;
                    diag_log format ["[HAVA-FARK-ATLA] %1 | grup atlandi, neden: retreat:%2 evade:%3 breakContact:%4 sniper:%5", groupId _g, _g getVariable [QGVAR(isRetreating), false], _g getVariable [QGVAR(isEvading), false], _g getVariable [QGVAR(isBreakingContact), false], _g getVariable [QGVAR(sniperTeam), false]];
                };
                continue;
            };
            private _mesgul = (_g getVariable [QGVAR(isBounding), false]) || {_g getVariable [QGVAR(isExecutingTactic), false]};

            private _taraf = side _g;
            private _lp = getPosATL _l;
            private _bask = ((units _g) findIf {alive _x && {(getSuppression _x) > 0.15}}) >= 0;

            // en yakin ilgili hava tehdidi
            private _hedef = objNull;
            private _silahli = false;
            private _dron = false;
            private _saldiri = false;
            private _hover = false;
            private _hd = 1e9;
            private _ele = [];
            {
                private _v = _x;
                private _d = _lp distance2D _v;
                if (_d > 1500) then { continue };
                if ((_taraf getFriend (side (group (effectiveCommander _v)))) >= 0.6) then { _ele pushBack format ["%1 %2 m: dost / tarafsiz (getFriend>=0.6)", typeOf _v, round _d]; continue };
                private _arm = ((_v weaponsTurret [-1]) isNotEqualTo []) || {(_v weaponsTurret [0]) isNotEqualTo []};
                private _uav = unitIsUAV _v;
                private _ho = _arm && {!_uav} && {(speed _v) < 15} && {((getPosATL _v) select 2) > 8};
                private _ates = (time - (_v getVariable ["lambs_danger_havaAtesT", -999])) < 20;
                private _esik = if (_ho || _ates) then {0.15} else {missionNamespace getVariable ["lambs_danger_havaBilgiEsik", 0.4]};
                if ((_g knowsAbout _v) < _esik) then { _ele pushBack format ["%1 %2 m: knowsAbout %3 < esik %4", typeOf _v, round _d, (_g knowsAbout _v) toFixed 2, _esik]; continue };
                if (_d > 1200 && {!_ho}) then { _ele pushBack format ["%1 %2 m: menzil disi (>1200, hover degil)", typeOf _v, round _d]; continue };
                if (_uav && {!_arm} && {_d > 700}) then { _ele pushBack format ["%1 %2 m: silahsiz dron >700", typeOf _v, round _d]; continue };
                if (_uav && {_arm} && {_d > 900}) then { _ele pushBack format ["%1 %2 m: silahli dron >900", typeOf _v, round _d]; continue };
                if (!_uav && {!_arm}) then { _g reveal [_v, 2]; continue };
                if (_d < _hd) then {
                    _hd = _d; _hedef = _v; _silahli = _arm; _dron = _uav; _hover = _ho;
                    _saldiri = _ates || {_bask && {_d < 800}};
                };
            } forEach _hava;
            if (isNull _hedef) then {
                if (_ele isNotEqualTo [] && {(time - (_g getVariable [QGVAR(havaEleT), -99])) > 15} && {_eleN < 100}) then {
                    _g setVariable [QGVAR(havaEleT), time];
                    _eleN = _eleN + 1;
                    diag_log format ["[HAVA-FARK-ELE] %1 | hedef secilmedi: %2", groupId _g, _ele joinString " ; "];
                };
                continue;
            };

            private _zarf = (_hd <= 600) && {((getPosATL _hedef) select 2) <= 300};

            // teshis: heli <= 800 m ise grup basina 6 sn'de bir karar girdisi (neden tepki yok sorusu icin)
            if (_hd <= 800 && {_taniN < 160} && {(time - (_g getVariable [QGVAR(havaKarT), -99])) > 6}) then {
                _g setVariable [QGVAR(havaKarT), time];
                _taniN = _taniN + 1;
                diag_log format ["[HAVA-FARK-KARAR] %1 | %2 %3 m | alt:%4 | saldiri:%5 (ates:%6 sn once, baski:%7) | silahli:%8 | zarf:%9 | hover:%10 | bounding/taktik:%11", groupId _g, typeOf _hedef, round _hd, round ((getPosATL _hedef) select 2), _saldiri, round (time - (_hedef getVariable ["lambs_danger_havaAtesT", -999])), _bask, _silahli, _zarf, _hover, _mesgul];
            };

            // 1) SALDIRI ALTINDA + kucuk silah zarfinda: oz savunma, komutla toplu ates (volume fire), onculu tek nisan noktasi (ATP 3-01.8 4-27..4-29, 4-42)
            if (_saldiri && {_silahli} && {_zarf}) then {
                private _bas = _g getVariable [QGVAR(havaVolBas), -999];
                private _volSn = missionNamespace getVariable ["lambs_danger_havaVolSn", 20];
                if ((time - _bas) > (_volSn + 60)) then { _bas = time; _g setVariable [QGVAR(havaVolBas), time]; };
                if ((time - _bas) <= _volSn && {(time - (_g getVariable [QGVAR(havaVolT), -99])) >= 3}) then {
                    _g setVariable [QGVAR(havaVolT), time];
                    if ((combatMode _g) isEqualTo "WHITE") then { _g setCombatMode "YELLOW"; };
                    private _vel = velocity _hedef;
                    private _tp = getPosASL _hedef;
                    private _n = 0;
                    {
                        private _u = _x;
                        if (alive _u && {isNull objectParent _u} && {(lifeState _u) in ["HEALTHY", "INJURED"]} && {(primaryWeapon _u) isNotEqualTo ""} && {(speed _u) < 3}) then {
                            private _iv = getNumber (configFile >> "CfgMagazines" >> (currentMagazine _u) >> "initSpeed");
                            if (_iv <= 0) then { _iv = 800 };
                            private _tof = ((_u distance _hedef) / (_iv * 0.9)) min 2;
                            private _lead = ASLToAGL (_tp vectorAdd (_vel vectorMultiply _tof));
                            _g reveal [_hedef, 4];
                            _u doSuppressiveFire _lead;
                            _n = _n + 1;
                        };
                    } forEach (units _g);
                    if (_logN < 120 && {(time - (_g getVariable [QGVAR(havaLogT), -99])) > 6}) then {
                        _g setVariable [QGVAR(havaLogT), time];
                        _logN = _logN + 1;
                        diag_log format ["[HAVA-FARK] %1 | %2 %3 %4 m | tepki:TOPLU-ATES (oz savunma) | ates eden:%5 | yukseklik:%6 m | bounding:%7", groupId _g, ["HELI", "DRON"] select _dron, typeOf _hedef, round _hd, _n, round ((getPosATL _hedef) select 2), _mesgul];
                    };
                };
                continue;
            };

            // 2) SALDIRMIYOR (veya zarf disinda): Weapons-Hold - ates ederek konum verme (3-4). Gruba heli hedefini unutturur (motor tekrar fark edebilir, 4 sn'de bir)
            if (!_saldiri && {_silahli} && {time > _disT}) then {
                _disT = time + 4;
                _g forgetTarget _hedef;
            };

            // 2b) UZERIMIZDEN GECIYOR (saldirmayan silahli heli <= 250 m) ve grup bounding / taktik yurutuyor: duran askerler 8 sn yere yatar (gizlenme; yurumeye devam edenler bozulmaz)
            if (!_saldiri && {_silahli} && {_hd <= 250} && {_mesgul} && {time > (_g getVariable [QGVAR(havaYatT), 0])}) then {
                _g setVariable [QGVAR(havaYatT), time + 30];
                private _y = 0;
                {
                    if (alive _x && {isNull objectParent _x} && {(speed _x) < 3}) then {
                        _x setUnitPos "DOWN";
                        [{ params ["_uu"]; if (alive _uu) then { _uu setUnitPos "AUTO"; }; }, [_x], 8] call CBA_fnc_waitAndExecute;
                        _y = _y + 1;
                    };
                } forEach (units _g);
                diag_log format ["[HAVA-FARK] %1 | %2 %3 m | tepki:YERE-YAT (heli ustumuzden geciyor, saldirmiyor) | yatan:%4", groupId _g, typeOf _hedef, round _hd, _y];
            };

            // 3) PASIF ONLEM / hava savunma
            if ((time - (_g getVariable [QGVAR(havaT), -999])) < 120) then { continue };
            if (_mesgul && {!_silahli}) then {
                if (time > _atlaT) then { _atlaT = time + 30; diag_log format ["[HAVA-FARK-ATLA] %1 | gozlemci dron ama grup bounding / taktik yurutuyor", groupId _g]; };
                continue;
            };
            // gozlemci dron: temasta saklanma yok
            if (!_silahli && {(_g getVariable [QGVAR(contact), 0]) > time}) then { continue };

            _g setVariable [QGVAR(havaT), time];
            private _sure = [90, 120] select _silahli;
            private _aa = (units _g) select {alive _x && {(magazines _x) findIf {private _m = toLower _x; (_m find "_aa_") >= 0 || {(_m find "stinger") >= 0} || {(_m find "strela") >= 0} || {(_m find "igla") >= 0} || {(_m find "_aa") >= 0}} >= 0}};
            private _yontem = "HIDE";
            if (_mesgul) then {
                // bounding / taktik yurutuyor: yurumeye devam, yalniz farkindalik + AA ates
                _g reveal [_hedef, 3];
                _yontem = "BOUNDING-DEVAM";
            } else {
                private _garrisonF = missionNamespace getVariable ["lambs_danger_fnc_tacticsGarrison", {false}];
                private _ok = false;
                if ((count (nearestObjects [_lp, ["House", "Building"], 42])) > 0) then {
                    _ok = [_g, getPosATL _l, [], _sure] call _garrisonF;
                    if (_ok isEqualType true && {_ok}) then { _yontem = "GARRISON"; };
                };
                if (_yontem isEqualTo "HIDE") then { [_g, _hedef, false, _sure] call FUNC(tacticsHide); };
            };
            // hava savunma: AA'li asker kimligi belli dusman silahli araca ates eder (Weapons-Tight)
            {
                _g reveal [_hedef, 4];
                _x doTarget _hedef;
                _x doFire _hedef;
            } forEach _aa;

            if (_logN < 120) then {
                _logN = _logN + 1;
                diag_log format ["[HAVA-FARK] %1 | %2 %3 %4 m (silahli:%5 hover:%6 saldiri:%7) | tepki:%8 | AA asker:%9", groupId _g, ["HELI", "DRON"] select _dron, typeOf _hedef, round _hd, _silahli, _hover, _saldiri, _yontem, count _aa];
            };
        } forEach (allGroups select {local _x && {!isNull leader _x}});
        _turMs = (diag_tickTime - _t0) * 1000;
        missionNamespace setVariable ["lambs_danger_havaAdim", format ["tur %1 bitti (%2 ms)", _tur, round _turMs]];
    };
};

// bekci: watchdog betigi bir hata ile olurse (SQF'te calisma hatasi betigi sonlandirir) otomatik yeniden baslat
[_calis] spawn {
    params ["_fn"];
    while {true} do {
        private _h = [] spawn _fn;
        waitUntil { sleep 5; scriptDone _h };
        diag_log format ["[WATCHDOG-YENIDEN] hava farkindaligi betigi sonlandi (hata?), son adim: %1 | RPT'de hemen ustteki 'Error' satirina bak", missionNamespace getVariable ["lambs_danger_havaAdim", "?"]];
        sleep 5;
    };
};

true
