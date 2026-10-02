#include "script_component.hpp"
/*
 * Author: Cinar (ELITE fork)
 * PUSU DAVRANISI + ATES EMRI (ROE) v1 — VBS4 "ambush / fire control" fikrinin Arma 3 karsiligi (watcher).
 *
 * TETIK (hepsi saglanirsa, 2 sn'lik izleme dongusu):
 *   - grup yerel, oyuncu icermez, >= pusuMinKisi (4) piyade, hicbir taktik bayragi yok, son 6 sn'de temas yok, son pusudan 90 sn gecti
 *   - lider bir PIYADE dusmani BILIYOR (knowsAbout >= 1.2), mesafe 90-260 m ve dusman YAKLASIYOR (>= 4 m, >= 3 sn)
 *     (dusmanin bizi bilip bilmedigine bakilmaz: HILE YOK; "temas yok" = bize ates acilmadi / bizi vurmadi)
 *
 * PUSU (spawn): ates politikasi TUTULU (combatMode GREEN = ates yok, yalniz kendini savun), LAMBS bu grupta kapali (grup + birim bayragi),
 *   herkes dusmana donuk siper alir (findCover 25 m), pusuAtesM (70 m) kill-box mesafesine kadar bekler.
 * ATES (hepsi ayni anda; ates politikasi SERBEST, combatMode RED):
 *   - dusman <= pusuAtesM (kill-box)   - GRUP ELE VERILDI (baski/yara/kayip)   - dusman <= 35 m (cok yakin)
 * IPTAL: pusuMaxS (150 sn) doldu, dusman 15 sn kayip / > 320 m, grup tukendi. Bitince tum bayraklar eski haline doner.
 *
 * v8.35 DOKTRIN (TC 3-21.76 Ranger Handbook s. 7-10 ... 7-14, Hasty / Deliberate Ambush; kaynaklar_doktrin/):
 *   - SECURITY UNSURU: >= 5 kisi: iki yan guvenlik (en sol / en sag asker, kill zone ekseninin +-90 derece 22 m'sine gider: "move a given distance, set up, rejoin after the ambush"),
 *     >= 7 kisi: arka guvenlik (20 m arkada). Gorevi: yanlari / arkayi kollamak, takipcileri (followers) gormek; ates basladiginda kill zone'a da atesler (squad seviyesinde dis ekipler yan guvenlik + ates).
 *   - ATES KRITERI: "ambush is not initiated until the majority of the enemy is in the kill zone": kill zone = dusman yonunde pusuAtesM'de, yaricap pusuKzYaricap (35 m, TASARIM) daire;
 *     bilinen dusmanin >= pusuCogunluk (0.6, TASARIM) kill zone icindeyse ates. Bilinen dusman <= 2 ise onceki kural (en yakin <= pusuAtesM). Ek: en yakin <= 35 m / ele verildi.
 *   - IPTAL: "PL determines if the enemy force is too large": bilinen dusman (takipciler dahil) > kendi sayimizin pusuBuyukOran (2.0, TASARIM) kati ise ates acilmaz (IPTAL:dusman cok buyuk).
 *   - PUSU SONRASI: ates bittikten sonra temas koptugunda (en fazla 100 sn) toparlanma (fnc_toparlan: sayim, rapor, guvenlik) baslar ("accountability, reorganize, report"). Log [PUSU-GUVENLIK] [PUSU-KZ].
 * Kapatma: lambs_danger_pusuV1 = false (varsayilan acik) ya da doktrin anahtari pusu = false.
 * Log: [PUSU] ... | Olaylar: AmbushBasla / AmbushAtes / AmbushBitti (lambs_danger_grupOlayi)
 *
 * Arguments: None
 * Return Value: Baslatildi mi <BOOL>
 * Public: No
*/

if (!isNil "lambs_danger_pusuStarted") exitWith {false};
lambs_danger_pusuStarted = true;

diag_log "[PUSU] pusu / ates emri izleyicisi baslatildi";

[] spawn {
    private _gonder = missionNamespace getVariable ["lambs_danger_fnc_olayGonder", {false}];
    while {true} do {
        sleep 2;
        if (!(missionNamespace getVariable ["lambs_danger_pusuV1", true])) then { continue };
        {
            private _g = _x;
            if (isNull _g || {!local _g}) then { continue };
            if ((units _g) findIf {isPlayer _x} > -1) then { continue };
            if ((side _g) isEqualTo civilian) then { continue };
            if (
                (_g getVariable [QGVAR(isRetreating), false]) || {_g getVariable [QGVAR(isEvading), false]}
                || {_g getVariable [QGVAR(isBreakingContact), false]} || {_g getVariable [QGVAR(isBounding), false]}
                || {_g getVariable [QGVAR(isAmbushing), false]} || {_g getVariable [QGVAR(isExecutingTactic), false]}
            ) then { continue };
            if ((time - (_g getVariable [QGVAR(pusuSon), -999])) < 90) then { continue };
            if ((_g getVariable [QGVAR(contact), 0]) > (time - 6)) then { continue };

            private _us = (units _g) select {alive _x && {isNull objectParent _x}};
            if ((count _us) < ([_g, "pusuMinKisi", 4] call FUNC(dk))) then { continue };
            if (!([_g, "pusu", true] call FUNC(dk))) then { continue };

            private _ld = leader _g;
            if (isNull _ld || {!alive _ld}) then { continue };
            private _en = _ld findNearestEnemy _ld;
            if (isNull _en || {!(_en isKindOf "CAManBase")} || {!alive _en} || {!isNull objectParent _en}) then {
                _g setVariable [QGVAR(pusuGecmis), []];
                continue
            };
            private _d = _ld distance2D _en;
            if (_d < 90 || {_d > 260} || {(_ld knowsAbout _en) < 1.2}) then {
                _g setVariable [QGVAR(pusuGecmis), []];
                continue
            };

            // yaklasma: son 3+ sn'de >= 4 m kisaldi mi
            private _gecmis = _g getVariable [QGVAR(pusuGecmis), []];
            _gecmis pushBack [time, _d];
            if ((count _gecmis) > 6) then { _gecmis deleteAt 0; };
            _g setVariable [QGVAR(pusuGecmis), _gecmis];
            private _eski = _gecmis select 0;
            if ((time - (_eski select 0)) < 3 || {((_eski select 1) - _d) < 4}) then { continue };

            _g setVariable [QGVAR(pusuGecmis), []];
            [_g, _en, _d] spawn {
                params ["_g", "_en", "_d0"];
                private _gonder = missionNamespace getVariable ["lambs_danger_fnc_olayGonder", {false}];
                private _t0 = time;

                // --- bayraklar (eski degerler geri verilecek) ---
                _g setVariable [QGVAR(isAmbushing), true];
                _g setVariable [QGVAR(isExecutingTactic), true];
                private _eskiDGA = _g getVariable [QGVAR(disableGroupAI), false];
                private _eskiCM = combatMode _g;
                private _eskiBeh = behaviour (leader _g);
                _g setVariable [QGVAR(disableGroupAI), true];
                _g setCombatMode "GREEN";
                _g setVariable [QGVAR(atesPolitikasi), "TUTULU"];
                {
                    _x setVariable [QGVAR(pusuEskiDAI), _x getVariable [QGVAR(disableAI), false]];
                    _x setVariable [QGVAR(disableAI), true];
                } forEach (units _g);

                private _atesM = [_g, "pusuAtesM", 70] call FUNC(dk);
                private _maxS = [_g, "pusuMaxS", 150] call FUNC(dk);
                diag_log format ["[PUSU] %1 | BASLADI | dusman:%2 m | kill-box:%3 m | politika:TUTULU", groupId _g, round _d0, _atesM];
                [_g, "AmbushBasla", round _d0] call _gonder;

                // --- kurulum: herkes dusmana donuk siper ---
                private _enPos = getPosATL _en;
                private _kurulan = 0;
                {
                    if (alive _x && {isNull objectParent _x}) then {
                        _x setBehaviour "STEALTH";
                        _x allowFleeing 0;
                        private _cv = [_x, _enPos, 25, "ASCEND", 1, "OVERWATCH"] call EFUNC(main,findCover);
                        if (_cv isNotEqualTo [] && {(_cv select 0) isNotEqualTo []}) then {
                            private _cp = (_cv select 0) select 0;
                            private _st = (_cv select 0) select 1;
                            if ((_x distance2D _cp) > 3) then {
                                _x setVariable [QGVAR(forceMove), true];
                                _x setUnitPosWeak "UP";
                                _x doMove _cp;
                            } else {
                                _x setUnitPosWeak _st;
                            };
                            _x setVariable [QGVAR(pusuSt), _st];
                            _kurulan = _kurulan + 1;
                        } else {
                            _x setUnitPosWeak "DOWN";
                        };
                        _x doWatch _enPos;
                    };
                } forEach (units _g);

                // --- SECURITY UNSURU (TC 3-21.76 s. 7-12): yan + arka guvenlik ---
                private _ldPos0 = getPosATL (leader _g);
                private _enBrg = _ldPos0 getDir _enPos;
                private _kzM = [_g, "pusuAtesM", 70] call FUNC(dk);
                private _kzR = [_g, "pusuKzYaricap", 35] call FUNC(dk);
                private _kzC = _ldPos0 getPos [_kzM, _enBrg];
                private _guvenlikler = [];
                private _rolFnP = missionNamespace getVariable ["lambs_danger_fnc_getUnitRole", {"RIFLE"}];
                private _uyeler = (units _g) select {alive _x && {isNull objectParent _x} && {_x isNotEqualTo (leader _g)} && {([_x] call _rolFnP) isNotEqualTo "MEDIC"}};
                if ((count (units _g select {alive _x})) >= 5 && {(count _uyeler) >= 2}) then {
                    private _sirali = [_uyeler, [], { private _a = (((_ldPos0 getDir (getPosATL _x)) - _enBrg + 540) mod 360) - 180; _a }, "ASCEND"] call BIS_fnc_sortBy;
                    private _sol = _sirali select 0;
                    private _sag = _sirali select ((count _sirali) - 1);
                    private _ark = objNull;
                    if ((count (units _g select {alive _x})) >= 7) then {
                        private _kal = _uyeler select {_x isNotEqualTo _sol && {_x isNotEqualTo _sag}};
                        if (_kal isNotEqualTo []) then {
                            _ark = ([_kal, [], { abs ((((_ldPos0 getDir (getPosATL _x)) - _enBrg + 540) mod 360) - 180) }, "DESCEND"] call BIS_fnc_sortBy) select 0;
                        };
                    };
                    {
                        _x params ["_u", "_rol", "_yon", "_mes"];
                        if (!isNull _u) then {
                            private _spot = _ldPos0 getPos [_mes, _enBrg + _yon];
                            if (surfaceIsWater _spot) then { _spot = _ldPos0 getPos [8, _enBrg + _yon]; };
                            _u setVariable [QGVAR(pusuGuvenlik), _rol];
                            _u setVariable [QGVAR(forceMove), true];
                            _u setUnitPosWeak "UP";
                            _u doMove _spot;
                            _u doWatch (_spot getPos [100, _enBrg + (_yon * 0.67)]);   // dis yana / geriye bak (takipciler, yan tehdit)
                            _guvenlikler pushBack _u;
                            diag_log format ["[PUSU-GUVENLIK] %1 | %2 -> %3 | %4 m (eksen %5 derece)", groupId _g, name _u, _rol, _mes, _yon];
                        };
                    } forEach [[_sol, "SOL", -90, 22], [_sag, "SAG", 90, 22], [_ark, "ARKA", 180, 20]];
                };

                // --- bekleme dongusu ---
                private _neden = "";
                private _n0 = count ((units _g) select {alive _x});
                private _sonGorus = time;
                private _dur = 0;
                while {_neden isEqualTo ""} do {
                    sleep 0.5;
                    if (isNull _g) exitWith {};
                    private _canli = (units _g) select {alive _x && {isNull objectParent _x}};
                    if (_canli isEqualTo []) exitWith { _neden = "IPTAL:grup tukendi"; };
                    private _ld = leader _g;
                    // kilit: baska watchdog'lar hareket emri vermesin; varanlar pozisyonda dursun
                    { _x setVariable [QGVAR(taktikKilit), time + 5]; } forEach _canli;
                    if ((time - _t0) > 4) then {
                        {
                            if ((_x getVariable [QGVAR(forceMove), false]) && {unitReady _x}) then {
                                _x setVariable [QGVAR(forceMove), nil];
                                _x setUnitPosWeak (_x getVariable [QGVAR(pusuSt), "MIDDLE"]);
                            };
                        } forEach _canli;
                    };

                    private _e = _ld findNearestEnemy _ld;
                    if (isNull _e || {!alive _e}) then {
                        if ((time - _sonGorus) > 15) then { _neden = "IPTAL:dusman kayip"; };
                    } else {
                        _sonGorus = time;
                        _en = _e;
                        _dur = _ld distance2D _e;
                        if (_dur > 320) then { _neden = "IPTAL:dusman uzaklasti"; };
                    };

                    private _elden = (_canli findIf {((getSuppression _x) > 0.15) || {(damage _x) > 0.05}}) > -1;
                    private _olen = (count _canli) < _n0;

                    // bilinen dusman (lider + guvenlik gozu): nearTargets, knowsAbout >= 0.4, 400 m
                    private _bilinen = [];
                    {
                        private _gz = _x;
                        if (alive _gz && {_gz in _canli}) then {
                            {
                                private _ob = _x select 4;
                                if (!isNull _ob && {alive _ob} && {(side _ob) getFriend (side _g) < 0.6} && {!(_ob in _bilinen)} && {_gz knowsAbout _ob >= 0.4}) then { _bilinen pushBack _ob; };
                            } forEach (_gz nearTargets 400);
                        };
                    } forEach ([_ld] + _guvenlikler);
                    private _kzIc = {(getPosATL _x) distance2D _kzC <= _kzR} count _bilinen;
                    private _cogunluk = [_g, "pusuCogunluk", 0.6] call FUNC(dk);
                    private _buyukOran = [_g, "pusuBuyukOran", 2.0] call FUNC(dk);
                    if ((time - _t0) > 3 && {(round (time * 2)) % 10 == 0}) then {
                        diag_log format ["[PUSU-KZ] %1 | bilinen:%2 | kill zone icinde:%3 (yaricap %4 m, %5 m'de) | en yakin %6 m", groupId _g, count _bilinen, _kzIc, _kzR, round _kzM, round _dur];
                    };
                    if (_neden isEqualTo "") then {
                        // IPTAL: dusman cok buyuk (takipciler dahil) — "PL determines if the enemy force is too large"
                        if ((time - _t0) > 5 && {(count _bilinen) > (_n0 * _buyukOran)} && {!_elden} && {!_olen}) then { _neden = format ["IPTAL:dusman cok buyuk (%1 / %2)", count _bilinen, _n0]; };
                        // ATES: cogunluk kill zone'da (>= 3 bilinen) ya da az dusmanda en yakin kill-box'ta
                        if (_neden isEqualTo "" && {(count _bilinen) >= 3} && {_kzIc >= (ceil (_cogunluk * (count _bilinen)))}) then { _neden = format ["ATES:cogunluk kill zone'da (%1 / %2)", _kzIc, count _bilinen]; };
                        if (_neden isEqualTo "" && {(count _bilinen) <= 2} && {_dur > 0} && {_dur <= _atesM}) then { _neden = "ATES:kill-box"; };
                        if (_neden isEqualTo "" && {_dur > 0} && {_dur <= 35}) then { _neden = "ATES:cok yakin"; };
                        if (_neden isEqualTo "" && {_elden || _olen}) then { _neden = "ATES:ele verildi"; };
                        if (_neden isEqualTo "" && {(time - _t0) > _maxS}) then { _neden = "IPTAL:sure doldu"; };
                    };
                };

                // --- ates ya da iptal: bayraklari eski haline getir ---
                private _atesEt = (_neden select [0, 4]) isEqualTo "ATES";
                if (!isNull _g) then {
                    if (_atesEt) then {
                        _g setCombatMode "RED";
                        _g setBehaviour "COMBAT";
                        _g setVariable [QGVAR(atesPolitikasi), "SERBEST"];
                        private _l = leader _g;
                        if (!isNull _l && {alive _l}) then { [_l, ["gestureGo"]] call EFUNC(main,doGesture); };
                        {
                            if (alive _x) then {
                                _x enableAI "TARGET";
                                _x enableAI "AUTOTARGET";
                                _x enableAI "AUTOCOMBAT";
                                _x enableAI "COVER";
                                _x setVariable [QGVAR(forceMove), nil];
                                _x setUnitPosWeak "MIDDLE";
                                if (!isNull _en && {alive _en}) then { _x doTarget _en; _x doFire _en; };
                            };
                        } forEach (units _g);
                        diag_log format ["[PUSU] %1 | ATES | neden:%2 | dusman:%3 m | sure:%4 sn | kurulan:%5", groupId _g, _neden, round _dur, round (time - _t0), _kurulan];
                        [_g, "AmbushAtes", _neden] call _gonder;
                        // ilk salvo: LAMBS 8 sn kapali kalir (hemen kosmaya / taktik degistirmeye baslamasin)
                        sleep 8;
                        // PUSU SONRASI (TC 3-21.76: accountability, reorganize, report): temas koptugunda toparlanma (en fazla 100 sn bekle)
                        [_g, getPosATL _en] spawn {
                            params ["_gg", "_hp"];
                            private _tb = time;
                            sleep 20;
                            waitUntil { sleep 3; isNull _gg || {((_gg getVariable [QGVAR(contact), 0]) < (time - 10))} || {(time - _tb) > 100} };
                            if (!isNull _gg && {((_gg getVariable [QGVAR(contact), 0]) < (time - 10))}
                                && {!(_gg getVariable [QGVAR(isRetreating), false])} && {!(_gg getVariable [QGVAR(isToparlan), false])}) then {
                                [_gg, _hp, _gg getVariable [QGVAR(disableGroupAI), false]] call FUNC(toparlan);
                            };
                        };
                    } else {
                        _g setCombatMode _eskiCM;
                        _g setBehaviour _eskiBeh;
                        diag_log format ["[PUSU] %1 | %2 | sure:%3 sn", groupId _g, _neden, round (time - _t0)];
                    };
                };
                if (!isNull _g) then {
                    _g setVariable [QGVAR(disableGroupAI), [nil, true] select _eskiDGA];
                    _g setVariable [QGVAR(isAmbushing), nil];
                    _g setVariable [QGVAR(isExecutingTactic), nil];
                    _g setVariable [QGVAR(pusuSon), time];
                    _g setCombatMode _eskiCM;
                    _g setVariable [QGVAR(atesPolitikasi), nil];
                    {
                        if (alive _x) then {
                            _x setVariable [QGVAR(disableAI), [nil, true] select (_x getVariable [QGVAR(pusuEskiDAI), false])];
                            _x setVariable [QGVAR(pusuEskiDAI), nil];
                            _x setVariable [QGVAR(pusuGuvenlik), nil];
                            _x setVariable [QGVAR(taktikKilit), nil];
                            _x setVariable [QGVAR(forceMove), nil];
                            _x setUnitPos "AUTO";
                            _x doWatch objNull;
                            _x setBehaviour (if (_atesEt) then {"COMBAT"} else {_eskiBeh});
                        };
                    } forEach (units _g);
                    [_g, "AmbushBitti", _neden] call _gonder;
                };
            };
        } forEach allGroups;
    };
};

true
