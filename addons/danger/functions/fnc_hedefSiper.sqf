#include "script_component.hpp"
/*
 * Author: Cinar (ELITE fork)
 * HEDEF / SIPER ZEKASI (v8.557; kullanici: 'botlar gorus acisinin olmadigi ama penetrasyonun mumkun oldugu tahta objeleri bulsunlar, ozellikle CQB de sutre arkasindaki hedefe atmaya devam etsinler (araclar ve MG si icin de);
 * botlar bizim bakis acimiza ve tavrimiza gore direk ates etmesin, bizim siperden ayrilmamizi beklesin ve oyle ates etsin (CQB disinda); gordukleri dusmanin siper alabilecegi yerleri hesaplasin ve ona gore tavir takinsin').
 * Yerel AI piyade + ARAC NISANCISI (MG / top) icin 1 sn'de bir, tick basina <= 12 birim:
 *  1) PENETRASYON ATESI [CBA penetreAtes, penetreM (60)]: bilinen dusman (knowsAbout >= SEZILDI) gorunmuyor (checkVisibility < 0.15) AMA fnc_penetreMi: FIRE LOD hatti yalniz penetre edilebilir nesnelerden geciyor (tahta / kumas / brandra / calı ...)
 *     -> atici (piyade / arac nisancisi) doSuppressiveFire ile hedefin gogsune (aimPos) 4 sn'de bir; dostun ates hatti (1.5 m) engelliyse atilmaz; piyadede sarjor > 6, aracta mermi var. Arac MG'si dahil.
 *  2) SIPERLI HEDEF DISIPLINI [CBA siperliDisiplin, siperliMinM (25)] (yalniz piyade): dusman >= 25 m, SIPERDE (checkVisibility < 0.3: gorunmuyor / kismen gorunuyor), askerin kendisi baski altinda degil (< 0.25), grup taktik / geri cekilme / bounding halinde degil:
 *     birim 'GREEN' (yalniz kendini savun) moduna alinir = siperden cikmayan hedefe mermi harcamaz / aciga cikmaz. Hedef siperden cikinca (gorunurluk >= 0.45, > 3 m kayar, hiz > 3 km/s), baski gelince, mesafe < 25 m (CQB) olunca ESKI moda doner.
 *  3) SIPER TAHMINI [CBA siperTahmin] (yalniz piyade): hareketli (hiz > 3 km/s) bilinen dusman 15-120 m'de: findCover (dusmanin gozunden bize karsi DEFEND, 20 m, 3 aday; 7. arg origin = yalniz oneri, rezerv defteri yazilmaz) ile dusmanin SIPER ALABILECEGI noktalar hesaplanir; dusman onunde (<= 14 m, yone +-70 derece) bir noktaya gidiyorsa
 *     o noktaya doSuppressiveFire (siper almadan bastir). Dusman basina 2 sn'de bir, birim basina 5 sn'de bir.
 * v8.558: ates tutma YALNIZ ILK TEMAS FAZINDA (CBA siperliIlkTemasSn, 40 sn; grup 30 sn temassiz kalirsa faz basa doner): grup hedef ACIGA CIKANA kadar bekler; hedef acikta net gorununce (vis >= 0.6), ates edince (son 5 sn; RPT 1c620d7d: oyuncu ates ederken bot beklemisti), hareketlenince (> 3 km/s / > 3 m kayma) ya da CQB'ye girince faz BITER ve tum grup AYNI ANDA serbest kalir (en uygun zamanda, en acik yerde ates acilir). Faz bittikten sonra bastirma ESKI gibi (LAMBS / vanilla; yeni surekli baski YOK). OYUNCULU GRUPLARDA (icinde oyuncu olan) HICBIR ozellik calismaz.
 * Log: [PENETRE-ATES] / [SIPERLI-TUT] / [SIPER-TAHMIN] (ilk 20) + 60 sn ozeti [HEDEF-SIPER-OZET]. Kapatma: ilgili CBA ayarlari.
 *
 * Arguments: None
 * Return Value: Baslatildi mi <BOOL>
 * Public: No
*/

if (!isNil "lambs_danger_hedefSiperStarted") exitWith {false};
lambs_danger_hedefSiperStarted = true;
diag_log "[HEDEF-SIPER] penetrasyon atesi (tahta / kumas arkasi, arac MG dahil) + siperli hedef disiplini + siper tahmini baslatildi (v8.557)";

[] spawn {
    private _indeks = 0;
    private _say = createHashMapFromArray [["penetre", 0], ["arac", 0], ["tutma", 0], ["tahmin", 0]];
    private _logN = 0;
    private _ozetT = time + 60;
    // nokta - dogru parcasi 2D uzakligi
    private _cizgiMes = {
        params ["_p", "_a", "_b"];
        private _ab = [(_b select 0) - (_a select 0), (_b select 1) - (_a select 1)];
        private _l2 = ((_ab select 0) ^ 2) + ((_ab select 1) ^ 2);
        if (_l2 < 0.01) exitWith {_p distance2D _a};
        private _t = ((((_p select 0) - (_a select 0)) * (_ab select 0)) + (((_p select 1) - (_a select 1)) * (_ab select 1))) / _l2;
        _t = (_t max 0) min 1;
        _p distance2D [(_a select 0) + (_t * (_ab select 0)), (_a select 1) + (_t * (_ab select 1))]
    };
    while {true} do {
        sleep ([1, true, false, "hedefSiper"] call FUNC(dusunSure));
        // ---- siperli tutma birakma ----
        {
            private _u = _x;
            private _e = _u getVariable [QGVAR(sipHedef), objNull];
            private _vis = if (isNull _e || {!alive _e}) then {1} else {[_u, "VIEW", _e] checkVisibility [eyePos _u, eyePos _e]};
            private _g0 = group _u;
            private _ilkSn0 = missionNamespace getVariable ["lambs_danger_siperliIlkTemasSn", 40];
            // ACIGA CIKTI: net gorunur (>= 0.6), hareketlendi, yer degistirdi ya da CQB'ye girdi -> ilk temas fazi biter, TUM grup ayni anda serbest kalir
            private _acik = !isNull _e && {alive _e} && {(_vis >= 0.6) || {(time - (_e getVariable [QGVAR(sonAtisT), -999])) < 5} || {(speed _e) > 3} || {((getPosATL _e) distance2D (_u getVariable [QGVAR(sipPoz), [0, 0, 0]])) > 3} || {(_u distance2D _e) < (missionNamespace getVariable ["lambs_danger_siperliMinM", 25])}};
            if (_acik) then { _g0 setVariable [QGVAR(hsBas), -1000000]; };
            if (isNull _e || {!alive _e} || _acik || {([_u] call FUNC(baskiSeviye)) >= 2} || {(time - (_g0 getVariable [QGVAR(hsBas), time])) > _ilkSn0} || {time > (_u getVariable [QGVAR(sipHoldT), 0])}) then {
                _u setUnitCombatMode (_u getVariable [QGVAR(sipEskiCM), "YELLOW"]);
                _u setVariable [QGVAR(sipEskiCM), ""];
                if (!isNull _e && {alive _e}) then { _u doTarget _e; };
            } else {
                // hedef kismen gorunuyor ama henuz tam acikta degil: beklemeye devam
                _u setVariable [QGVAR(sipHoldT), time + 3];
            };
        } forEach (allUnits select {local _x && {(_x getVariable [QGVAR(sipEskiCM), ""]) isNotEqualTo ""}});

        private _penetreAcik = missionNamespace getVariable ["lambs_danger_penetreAtes", true];
        private _siperliAcik = missionNamespace getVariable ["lambs_danger_siperliDisiplin", true];
        private _tahminAcik = missionNamespace getVariable ["lambs_danger_siperTahmin", true];
        if (!_penetreAcik && {!_siperliAcik} && {!_tahminAcik}) then { continue };
        private _penetreM = missionNamespace getVariable ["lambs_danger_penetreM", 60];
        private _siperliM = missionNamespace getVariable ["lambs_danger_siperliMinM", 25];
        private _ilkSn = missionNamespace getVariable ["lambs_danger_siperliIlkTemasSn", 40];

        private _adaylar = allUnits select {
            local _x && {alive _x} && {!isPlayer _x} && {((units group _x) findIf {isPlayer _x}) < 0} && {(side group _x) in [west, east, resistance]} && {!captive _x} && {(lifeState _x) in ["HEALTHY", "INJURED"]} && {!([_x] call FUNC(bombaciMi))}
            && {([(group _x)] call FUNC(temasSeviye)) <= 1}
            && {
                (isNull objectParent _x && {(primaryWeapon _x) isNotEqualTo ""}) || {(vehicle _x) isNotEqualTo _x && {_x isEqualTo (gunner (vehicle _x))} && {(vehicle _x) isKindOf "LandVehicle"}}
            }
        };
        private _n = count _adaylar;
        if (_n > 0) then {
            private _kesit = 12 min _n;
            private _tahminBut = 3;
            for "_i" from 0 to (_kesit - 1) do {
                private _u = _adaylar select ((_indeks + _i) mod _n);
                private _g = group _u;
                // ilk temas fazi: grup 30 sn temassiz kaldiktan sonra yeniden temasa girerse faz basa doner (v8.558)
                if ((time - (_g getVariable [QGVAR(hsSon), -999])) > 30) then { _g setVariable [QGVAR(hsBas), time]; };
                _g setVariable [QGVAR(hsSon), time];
                private _ilkFaz = (time - (_g getVariable [QGVAR(hsBas), time])) <= _ilkSn;
                private _arac = (vehicle _u) isNotEqualTo _u;
                private _e = _u findNearestEnemy _u;
                if (isNull _e || {!alive _e} || {captive _e} || {!(_e isKindOf "AllVehicles")} || {[_e] call FUNC(teslimMi)}) then { continue };
                if (_e isKindOf "CAManBase" && {(lifeState _e) in ["INCAPACITATED", "UNCONSCIOUS"]}) then { continue };
                private _d = _u distance2D _e;
                if (_d < 6 || {_d > ([200, 250] select _arac)}) then { continue };
                if ((_u knowsAbout _e) < (["SEZILDI"] call FUNC(bilgiEsik))) then { continue };
                private _uGoz = eyePos _u;
                private _hedefASL = aimPos _e;
                private _vis = [_u, "VIEW", _e] checkVisibility [_uGoz, eyePos _e];
                private _atesVerdi = false;

                // v8.619 DUVARA DEGIL PENCEREYE (kullanici: 'sadece pencereye ates etsinler duvara degil'; RPT 39835e40 / eec0f873: [PENETRE-ATES] duvar arkasi dusmana 'BILINMEYEN malzeme DENEMESI'): dusman BINADAYSA ve CBA pencereAtesi aciksa duvar penetrasyonu YOK; yalniz pencere / kapidan gorulen ic noktaya bastirma (fnc_pencereNoktasi)
                private _binaPen = (missionNamespace getVariable ["lambs_danger_pencereAtesi", true]) && {!_arac} && {(insideBuilding _e) > 0.15};
                if (_binaPen && {_vis < 0.15} && {_d <= _penetreM} && {time >= (_u getVariable [QGVAR(penetreT), 0])} && {(_u ammo (primaryWeapon _u)) > 6}) then {
                    private _pw = [_u, getPosATL _e] call FUNC(pencereNoktasi);
                    _u setVariable [QGVAR(penetreT), time + 4];
                    if (_pw isNotEqualTo [] && {[_u, _e, "pencere"] call FUNC(baskiKapisi)}) then {   // v8.743: uzak + gozlemci yok = atma
                        _u doSuppressiveFire (AGLToASL _pw);
                        _atesVerdi = true;
                    };
                };

                // v8.666 PENETRASYON FARKINDALIGI (kullanici: 'penetrasyonu farkindaligi ekle, bu duvar arkasi atislar icin de gelsin'): dusman BINADAYSA artik duvara KOSULSUZ yasak degil; mermi gucu (fnc_munisyonGucu) malzeme x kalinlik direncini (fnc_penetreGuc) asarsa VE malzeme bilinen ise duvar arkasina penetrasyon atesi, degilse pencereye (eski)
                private _binaGec = false;
                private _pgB = [false, 0, 0, 0, 0];
                if (_binaPen && {_vis < 0.15} && {_d <= _penetreM} && {missionNamespace getVariable ["lambs_danger_penetreGuc", true]}) then {
                    _pgB = [_uGoz, _hedefASL, _u, _e, [_u] call FUNC(munisyonGucu)] call FUNC(penetreGuc);
                    _binaGec = (_pgB select 0) && {(_pgB select 2) isEqualTo 0} && {(_pgB select 1) > 0};
                };

                // ---- 1) PENETRASYON ATESI ----
                if ((!_binaPen || {_binaGec}) && {_penetreAcik} && {_vis < 0.15} && {_d <= _penetreM} && {time >= (_u getVariable [QGVAR(penetreT), 0])}
                    && {[(_u ammo (primaryWeapon _u)) > 6, someAmmo (vehicle _u)] select _arac}) then {
                    private _pm = if (_binaGec) then {_pgB} else {[_uGoz, _hedefASL, [_u, vehicle _u] select _arac, _e, true] call FUNC(penetreMi)};
                    // v8.666: bilinen malzeme (deneme degil) penetrasyonu da MERMI GUCU x KALINLIK ile sinanir (ince gövde / kalin tahta / buyuk kalibre farki)
                    if (!_arac && {!_binaGec} && {_pm select 0} && {(_pm select 2) isEqualTo 0} && {(_pm select 1) > 0} && {missionNamespace getVariable ["lambs_danger_penetreGuc", true]}) then {
                        private _pgK = [_uGoz, _hedefASL, _u, _e, [_u] call FUNC(munisyonGucu)] call FUNC(penetreGuc);
                        if !(_pgK select 0) then { _pm = [false, 0, 0]; };
                    };
                    if (_pm select 0) then {
                        private _dostEngel = ((_u nearEntities ["CAManBase", _d]) findIf {
                            alive _x && {_x isNotEqualTo _u} && {_x isNotEqualTo _e} && {((side group _x) getFriend (side _g)) >= 0.6} && {([getPosASL _x, _uGoz, _hedefASL] call _cizgiMes) < 1.5}
                        }) >= 0;
                        private _denemeMi = (_pm select 2) > 0;
                        // deneme (bilinmeyen malzeme): 8 sn arayla, ayni birim 40 sn'de en cok 4 kez
                        if (_denemeMi) then {
                            if ((time - (_u getVariable [QGVAR(penDenT), -999])) > 40) then { _u setVariable [QGVAR(penDenN), 0]; _u setVariable [QGVAR(penDenT), time]; };
                            if ((_u getVariable [QGVAR(penDenN), 0]) >= 4) then { _dostEngel = true; } else { _u setVariable [QGVAR(penDenN), (_u getVariable [QGVAR(penDenN), 0]) + 1]; };
                        };
                        if (!_dostEngel && {_pm select 1 > 0} && {[_u, _e, "penetre"] call FUNC(baskiKapisi)}) then {   // v8.743: uzak + gozlemci yok = atma
                            _u doSuppressiveFire _hedefASL;
                            _u setVariable [QGVAR(penetreT), time + ([4, 8] select _denemeMi)];
                            _atesVerdi = true;
                            _say set [["penetre", "arac"] select _arac, (_say get (["penetre", "arac"] select _arac)) + 1];
                            if (_logN < 20) then {
                                _logN = _logN + 1;
                                diag_log format ["[PENETRE-ATES] %1 %2 | %3 (%4) -> %5 | %6 m | gorunmuyor (vis %7), hat %8 nesneden geciyor (%11) | xy %9 -> %10", str (side _g), groupId _g, name _u, ["piyade", "ARAC NISANCISI " + typeOf (vehicle _u)] select _arac, typeOf _e, round _d, _vis toFixed 2, _pm select 1,
                                    (getPosATL _u) select [0, 2] apply { round _x }, (getPosATL _e) select [0, 2] apply { round _x }, ["bilinen penetre edilebilir", "BILINMEYEN malzeme DENEMESI"] select _denemeMi];
                            };
                        };
                    };
                };
                if (_arac) then { continue };

                // ---- 2) SIPERLI HEDEF DISIPLINI ----
                if (_siperliAcik && {_ilkFaz} && {!(_g getVariable [QGVAR(disableGroupAI), false])} && {!_atesVerdi} && {_d > _siperliM} && {(time - (_e getVariable [QGVAR(sonAtisT), -999])) >= 5} && {_vis < 0.3} && {([_u] call FUNC(baskiSeviye)) < 2}
                    && {!(_g getVariable [QGVAR(isBounding), false])} && {!(_g getVariable [QGVAR(isExecutingTactic), false])} && {!(_g getVariable [QGVAR(isRetreating), false])} && {!(_g getVariable [QGVAR(isBreakingContact), false])}
                    && {(_u getVariable [QGVAR(forceMove), false]) isNotEqualTo true} && {(speed _e) < 3} && {!(_g getVariable [QGVAR(isAmbushing), false])}) then {
                    if ((_u getVariable [QGVAR(sipEskiCM), ""]) isEqualTo "") then {
                        _u setVariable [QGVAR(sipEskiCM), unitCombatMode _u];
                        _u setVariable [QGVAR(sipHedef), _e];
                        _u setVariable [QGVAR(sipPoz), getPosATL _e];
                        _u setUnitCombatMode "GREEN";
                        _say set ["tutma", (_say get "tutma") + 1];
                        if (_logN < 20) then {
                            _logN = _logN + 1;
                            diag_log format ["[SIPERLI-TUT] %1 %2 | %3 | dusman %4 m siperde (vis %5), kendisi baskida degil -> ates tutuluyor (GREEN) siperden cikmasini bekliyor", str (side _g), groupId _g, name _u, round _d, _vis toFixed 2];
                        };
                    };
                    _u setVariable [QGVAR(sipHoldT), time + 3];
                };

                // ---- 3) SIPER TAHMINI ----
                if (_tahminAcik && {_tahminBut > 0} && {_d >= 15} && {_d <= 120} && {(speed _e) > 3} && {time >= (_e getVariable [QGVAR(siperTahminT), 0])} && {time >= (_u getVariable [QGVAR(siperTahminU), 0])}) then {
                    _e setVariable [QGVAR(siperTahminT), time + 2];
                    _tahminBut = _tahminBut - 1;
                    private _kv = [_e, _u, 20, "ASCEND", 3, "DEFEND", getPosATL _e] call EFUNC(main,findCover);
                    private _hedefCp = [];
                    private _hedefMes = 99;
                    {
                        private _cp = _x select 0;
                        if (_cp isEqualType [] && {(count _cp) >= 2}) then {
                            private _mes = _e distance2D _cp;
                            private _yon = abs ((((_e getDir _cp) - (getDir _e)) + 540) mod 360 - 180);
                            if (_mes <= 14 && {_mes >= 2} && {_yon <= 70} && {_mes < _hedefMes}) then { _hedefMes = _mes; _hedefCp = _cp; };
                        };
                    } forEach _kv;
                    // v8.743 (kullanici: 'bos duvari tariyorlar'): tahmin noktasi cogu zaman duvarin / nesnenin KENDISI; hat kontrolu yoktu -> hat acik + (dusman yakin ya da ileri gozlemci goruyor) sart
                    if (_hedefCp isNotEqualTo [] && {[_u, _hedefCp] call FUNC(atesHatiAcik)} && {[_u, _e, "tahmin"] call FUNC(baskiKapisi)}) then {
                        _u doSuppressiveFire (_hedefCp vectorAdd [0, 0, 0.9]);
                        _u setVariable [QGVAR(siperTahminU), time + 5];
                        _say set ["tahmin", (_say get "tahmin") + 1];
                        if (_logN < 20) then {
                            _logN = _logN + 1;
                            diag_log format ["[SIPER-TAHMIN] %1 %2 | %3 | dusman %4 m hareketli, olasi siperi %5 m onunde (yone %6 derece) -> siper almadan bastirma | siper xy %7", str (side _g), groupId _g, name _u, round _d, _hedefMes toFixed 1, round (abs ((((_e getDir _hedefCp) - (getDir _e)) + 540) mod 360 - 180)), _hedefCp select [0, 2] apply { round _x }];
                        };
                    };
                };
            };
            _indeks = _indeks + _kesit;
        };
        if (time > _ozetT) then {
            _ozetT = time + 60;
            if (((_say get "penetre") + (_say get "arac") + (_say get "tutma") + (_say get "tahmin")) > 0) then {
                diag_log format ["[HEDEF-SIPER-OZET] 60 sn: penetrasyon atesi piyade %1 | arac nisancisi %2 | siperli hedefte ates tutma %3 | siper tahmini bastirma %4", _say get "penetre", _say get "arac", _say get "tutma", _say get "tahmin"];
            };
            { _say set [_x, 0]; } forEach ["penetre", "arac", "tutma", "tahmin"];
        };
    };
};
true
