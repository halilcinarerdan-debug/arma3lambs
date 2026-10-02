#include "script_component.hpp"
/*
 * Author: Cinar (ELITE fork)
 * ROL ISTASYONU — herkes gorev yerini ve gorevini bilir.
 *
 * Sorun: Roller (MG / AT / nisanci / saglikci) sadece Bounding / Retreat / AT taarruzu gibi
 *        taktiklerin ICINDE kullaniliyordu. Normal catismada ve formasyonda MG'nin nerede duracagi,
 *        AT'nin sakli kalmasi, UGL'nin gorevi yoktu; Arma formasyon slotlarini role gore degil
 *        gruba katilma sirasina gore verir (MG en one dusebiliyordu).
 *
 * Bu watchdog (server / HC basina bir kez, 4 sn'de bir):
 *
 *   A) SAKIN (temas yok): FORMASYON SIRASI — grubun birim sirasi role gore duzenlenir
 *        lider, MG, bombaatar (UGL), tufekliler, nisanci, AT, saglikci
 *      (Arma formasyon slotlari birim sirasindan gelir: MG liderin yaninda, tufekliler dis kanatlarda,
 *       AT / saglikci / nisanci arkada korunur). Grup basina bir kez (kadro degisince tekrar),
 *       joinSilent ile atomik; kapatmak icin: lambs_danger_roleReorder = false
 *
 *   B) CATISMA (statik: lider duruyor, dusman 25..500m): ROL ISTASYONLARI
 *        MG       lidere 6..28m, liderin onunde DEGIL, OVERWATCH sipere (atis ussu, yan kanat)
 *        NISANCI  lidere 8..35m, geride/yanda, OVERWATCH sipere (uzun gorus)
 *        UGL      lidere 4..20m, ikinci hatta, DEFEND sipere
 *        AT       lidere 8..25m, liderin ARKASINDA, sert sipere (zirh gelene kadar korunur)
 *        SAGLIKCI lidere 8..20m, ARKADA (yarali varsa ACE medical AI'a karismaz)
 *      istasyon uygunsa yerinde kalir; degilse yakin siper (findCover) veya geometrik nokta;
 *      varista siper stance'i + dusmani izler. Temas bitince doFollow ile formasyona doner.
 *
 *   C) GOREVLER (istasyondan bagimsiz, asker durur ve baskida degilse):
 *        UGL      40..320m piyadeye 40mm (fnc_tacticalUGL; hat kapali / binada / kume / %50)
 *        MG       50..450m dusmana hat KAPALIysa alana baski (doSuppress) — atis ussu surer
 *        NISANCI  80..600m bilinen launcher'li / MG'li dusmani ONCELIKLI vurur
 *
 *   ATLANIR: Bounding / Retreat / Evade / Temas kes / AT taarruz / isExecutingTactic gruplari,
 *            oyunculu gruplar, lider hareket halinde (assault / flank), binada, baski >= 0.5
 *
 * Arguments:
 * None
 *
 * Return Value:
 * Baslatildi mi <BOOL>
 *
 * Public: No
*/

if (!isNil "lambs_danger_roleStationStarted") exitWith {false};
lambs_danger_roleStationStarted = true;

diag_log "[ROL] rol istasyonu (formasyon sirasi + MG / nisanci / UGL / AT / saglikci gorev yeri) watchdog baslatildi";

[] spawn {
    private _rolFn = missionNamespace getVariable ["lambs_danger_fnc_getUnitRole", {"RIFLE"}];
    private _glFn  = missionNamespace getVariable ["lambs_danger_fnc_hasUGL", {""}];
    private _uglFn = missionNamespace getVariable ["lambs_danger_fnc_tacticalUGL", {false}];
    private _supFn = missionNamespace getVariable ["lambs_main_fnc_doSuppress", {false}];

    // [minMes, maxMes, ileriUst, ileriAlt, siperModu, geometri bearing ofseti, geometri mesafesi]
    //   ileri = liderin dusmana dogru ekseninde izdusum (+ = liderin onunde)
    private _tabloFn = {
        params ["_rol"];
        switch (_rol) do {
            case "MG":       { [6, 28, 6, -25, "OVERWATCH", 90, 14] };
            case "MARKSMAN": { [8, 35, 4, -30, "OVERWATCH", -130, 22] };
            case "GL":       { [4, 20, 8, -20, "DEFEND", -90, 9] };
            case "AT":       { [8, 25, 0, -30, "DEFEND", 160, 14] };
            case "MEDIC":    { [8, 20, -3, -30, "DEFEND", -170, 12] };
            default          { [] };
        }
    };

    private _uygunFn = {
        params ["_p", "_lPos", "_fwd", "_t"];
        _t params ["_minL", "_maxL", "_ahUst", "_ahAlt"];
        private _mes = _lPos distance2D _p;
        private _ileri = (_p vectorDiff _lPos) vectorDotProduct _fwd;
        (_mes >= _minL) && {_mes <= _maxL} && {_ileri <= _ahUst} && {_ileri >= _ahAlt}
    };

    while {true} do {
        sleep 4;
        private _butce = 5;   // tikte en fazla bu kadar findCover (tum gruplar)

        {
            private _g = _x;
            if (isNull _g) then { continue };
            if ((count (units _g)) < 3) then { continue };
            if (_g getVariable [QGVAR(roleStationOff), false]) then { continue };

            private _leader = leader _g;
            if (isNull _leader || {!alive _leader} || {!(local _leader)} || {isPlayer _leader}) then { continue };
            if (((units _g) findIf {isPlayer _x}) > -1) then { continue };

            // UGL HER TAKTIKTE: bounding / hucum / hold sirasinda istasyon mantigi atlanir ama bombaatar 40mm gorevini yapar
            // (eskiden taktik aktifken UGL hic atmiyordu). Cekilme / evade / temas kes: atis yok.
            if (
                ((_g getVariable [QGVAR(contact), 0]) > time)
                && {!(_g getVariable [QGVAR(isRetreating), false])} && {!(_g getVariable [QGVAR(isEvading), false])}
                && {!(_g getVariable [QGVAR(isBreakingContact), false])}
            ) then {
                {
                    private _gu = _x;
                    if (
                        alive _gu && {local _gu} && {!isPlayer _gu} && {isNull objectParent _gu}
                        && {(speed _gu) < 1.5} && {(getSuppression _gu) < 0.5}
                        && {!(_gu getVariable [QGVAR(forceMove), false])}
                        && {([_gu] call _glFn) isNotEqualTo ""}
                    ) then {
                        private _ge = _gu findNearestEnemy _gu;
                        if (!isNull _ge && {alive _ge} && {_ge isKindOf "CAManBase"}) then {
                            if ([_gu, _ge] call _uglFn) then {
                                diag_log format ["[ROL-GOREV] %1 | %2 | UGL (taktikte) -> %3 (%4m)", groupId _g, name _gu, name _ge, round (_gu distance2D _ge)];
                            };
                        };
                    };
                } forEach (units _g);
            };

            // Kendi hareket duzeni olan taktikler: atla
            if (
                (_g getVariable [QGVAR(isBounding), false])
                || {_g getVariable [QGVAR(isRetreating), false]}
                || {_g getVariable [QGVAR(isEvading), false]}
                || {_g getVariable [QGVAR(isBreakingContact), false]}
                || {_g getVariable [QGVAR(isATEngage), false]}
                || {_g getVariable [QGVAR(isExecutingTactic), false]}
                || {((_g getVariable [QGVAR(cmdLastDecision), ""]) in ["FLANK", "ASSAULT", "SUPPRESS_ASSAULT"]) && {(time - (_g getVariable [QGVAR(cmdSonKararZaman), -999])) < 30}}
            ) then { continue };

            private _tum = (units _g) select {alive _x && {isNull objectParent _x}};
            if ((count _tum) < 3) then { continue };

            private _savasta = (_g getVariable [QGVAR(contact), 0]) > time;

            // =================================================================
            // A) SAKIN: temas bitti -> istasyon izlerini temizle; formasyon sirasini rol'e gore duzenle
            // =================================================================
            if (!_savasta) then {
                {
                    if (_x getVariable [QGVAR(stationDirty), false]) then {
                        _x setVariable [QGVAR(stationDirty), nil];
                        _x setVariable [QGVAR(stationPos), nil];
                        if (alive _x && {local _x} && {!isPlayer _x}) then {
                            _x doWatch objNull;
                            _x setUnitPosWeak "AUTO";
                            _x doFollow _leader;
                        };
                    };
                } forEach _tum;

                if (
                    (count _tum) >= 4
                    && {(_g getVariable [QGVAR(roleOrderSig), -1]) != (count _tum)}
                    && {(time - (_g getVariable [QGVAR(contact), 0])) > 20}
                    && {missionNamespace getVariable ["lambs_danger_roleReorder", true]}
                    && {(_tum findIf {!(local _x) || {!((lifeState _x) in ["HEALTHY", "INJURED"])}}) isEqualTo -1}
                ) then {

                    private _mg = [];
                    private _gl = [];
                    private _rif = [];
                    private _mrk = [];
                    private _at = [];
                    private _med = [];
                    {
                        if (_x isNotEqualTo _leader) then {
                            switch ([_x] call _rolFn) do {
                                case "MG":       { _mg pushBack _x; };
                                case "MARKSMAN": { _mrk pushBack _x; };
                                case "AT":       { _at pushBack _x; };
                                case "MEDIC":    { _med pushBack _x; };
                                default {
                                    if (([_x] call _glFn) isNotEqualTo "") then {
                                        _gl pushBack _x;
                                    } else {
                                        _rif pushBack _x;
                                    };
                                };
                            };
                        };
                    } forEach _tum;

                    private _sira = _mg + _gl + _rif + _mrk + _at + _med;
                    private _simdi = (units _g) select {_x isNotEqualTo _leader && {alive _x}};

                    if ((count _sira) isEqualTo (count _simdi)) then {
                        _g setVariable [QGVAR(roleOrderSig), count _tum];   // sadece sayilar tutunca (araca binen varsa tekrar denenir)
                    };

                    if ((count _sira) isEqualTo (count _simdi) && {_sira isNotEqualTo _simdi}) then {
                        private _yeni = createGroup [side _leader, true];
                        // Atomik: arada baska script / olay araya girmesin, birimler gecici grupta kalmasin
                        isNil {
                            { [_x] joinSilent _yeni; } forEach _sira;
                            { [_x] joinSilent _g; } forEach _sira;
                        };
                        // Guvenlik: biri eski gruba donmediyse ZORLA geri al (ayri grupta MG/AT kalmasin)
                        private _kopuk = _sira select {alive _x && {(group _x) isNotEqualTo _g}};
                        if (_kopuk isNotEqualTo []) then {
                            _kopuk joinSilent _g;
                            diag_log format ["[ROL-SIRA-HATA] %1 | %2 asker gruptan kopmustu, geri alindi", groupId _g, count _kopuk];
                        };
                        diag_log format [
                            "[ROL-SIRA] %1 | MG:%2 UGL:%3 tufek:%4 nisanci:%5 AT:%6 saglikci:%7 | formasyon sirasi role gore duzenlendi",
                            groupId _g, count _mg, count _gl, count _rif, count _mrk, count _at, count _med
                        ];
                    };
                };
                continue
            };

            // =================================================================
            // B) CATISMA — sadece STATIK catisma (lider duruyor); assault / flank / hareket = atla
            // =================================================================
            if ((speed _leader) > 1.5) then { continue };

            private _dusman = _leader findNearestEnemy _leader;
            if (isNull _dusman) then {
                private _i = _tum findIf {!isNull (_x findNearestEnemy _x)};
                if (_i > -1) then {
                    private _bu = _tum select _i;
                    _dusman = _bu findNearestEnemy _bu;
                };
            };
            if (isNull _dusman) then { continue };

            private _ePos = getPosATL _dusman;
            private _lPos = getPosATL _leader;
            private _dm = _lPos distance2D _ePos;
            if (_dm > 500 || {_dm < 25}) then { continue };   // cok uzak / yakin dovus (CQB'ye karisma)

            private _yon = _lPos getDir _ePos;
            private _fwd = [sin _yon, cos _yon, 0];

            // ACE medical AI: saglikci yaralisina kosuyor — istasyona cagirip karistirma
            private _yaraliVar = (_tum findIf {
                (damage _x) > 0.25 || {(lifeState _x) isNotEqualTo "HEALTHY"}
            }) > -1;

            private _tasinan = 0;
            {
                private _u = _x;
                if (_u isEqualTo _leader) then { continue };

                // Uygun asker: yerel, bot, ayakta, hareket etmiyor, baskida degil, binada degil
                if (
                    !(local _u)
                    || {isPlayer _u}
                    || {!((lifeState _u) in ["HEALTHY", "INJURED"])}
                    || {_u getVariable [QGVAR(forceMove), false]} || {(_u getVariable [QGVAR(taktikKilit), 0]) > time}
                    || {(speed _u) > 1.5}
                    || {(getSuppression _u) >= 0.5}
                    || {(insideBuilding _u) >= 0.5}
                ) then { continue };

                private _rol = [_u] call _rolFn;
                private _glM = [_u] call _glFn;
                private _key = switch (true) do {
                    case (_rol isEqualTo "MG"):       {"MG"};
                    case (_rol isEqualTo "MARKSMAN"): {"MARKSMAN"};
                    case (_rol isEqualTo "AT"):       {"AT"};
                    case (_rol isEqualTo "MEDIC"):    {"MEDIC"};
                    case (_glM isNotEqualTo ""):      {"GL"};
                    default                           {""};
                };

                // ---------------------------------------------------------
                // Varis: siper stance'i + dusmani izle (bir kez)
                // ---------------------------------------------------------
                private _sp = _u getVariable [QGVAR(stationPos), []];
                if (_sp isNotEqualTo []) then {
                    _sp params ["_spPos", "_spStance", "_spEPos", "_spZaman", "_spBitti"];
                    if (!_spBitti && {(_u distance2D _spPos) < 4}) then {
                        _u setUnitPosWeak _spStance;
                        _u doWatch _spEPos;
                        _u setVariable [QGVAR(stationPos), [_spPos, _spStance, _spEPos, _spZaman, true]];
                    };
                    if ((time - _spZaman) > 90) then {
                        _u setVariable [QGVAR(stationPos), nil];
                        _u doWatch objNull;
                    };
                };

                // ---------------------------------------------------------
                // ISTASYON: uygun degilse yakin siper / geometrik nokta
                // ---------------------------------------------------------
                private _t = [_key] call _tabloFn;
                private _dene =
                    (_t isNotEqualTo [])
                    && {_butce > 0}
                    && {_tasinan < 2}
                    && {(time - (_u getVariable [QGVAR(stationLast), -999])) > 20}
                    && {(time - (_u getVariable [QGVAR(stationTry), -999])) > 20}
                    && {!(_key isEqualTo "MEDIC" && {_yaraliVar})};

                if (_dene) then {
                    private _uPos = getPosATL _u;
                    // Hedef bulunamasa / suda olsa bile 20 sn sonra tekrar dene (her tikte findCover yemesin)
                    _u setVariable [QGVAR(stationTry), time];
                    if !([_uPos, _lPos, _fwd, _t] call _uygunFn) then {
                        private _hedef = [];
                        private _stance = "MIDDLE";
                        private _kaynak = "siper";

                        private _cvr = [_u, _dusman, 25, "ASCEND", 6, _t select 4] call EFUNC(main,findCover);
                        _butce = _butce - 1;
                        private _ci = _cvr findIf {[_x select 0, _lPos, _fwd, _t] call _uygunFn};
                        if (_ci > -1) then {
                            _hedef = (_cvr select _ci) select 0;
                            _stance = (_cvr select _ci) select 1;
                            // findCover EN YUKSEK GIZLI stance'i doner; atis pozisyonunda (MG / nisanci) gorus ister -> bir ust
                            if (_key in ["MG", "MARKSMAN"]) then {
                                _stance = ["MIDDLE", "UP", "UP"] select ((["DOWN", "MIDDLE", "UP"] find _stance) max 0);
                            };
                        } else {
                            // Siper yok: lidere gore rolun geometrik yeri (MG yanda, AT / saglikci arkada...)
                            private _ofs = _t select 5;
                            if (((_tum find _u) % 2) isEqualTo 1) then { _ofs = -_ofs; };
                            // ayni roldeki birden fazla asker ayni noktaya yigilmasin: 4 m'lik halkalar
                            _hedef = _lPos getPos [(_t select 6) + (4 * ((floor ((_tum find _u) / 2)) min 2)), _yon + _ofs];
                            _kaynak = "geometri";
                        };

                        if (_hedef isNotEqualTo [] && {!surfaceIsWater _hedef}) then {
                            _u doMove _hedef;
                            _u setVariable [QGVAR(stationLast), time];
                            _u setVariable [QGVAR(stationPos), [_hedef, _stance, _ePos, time, false]];
                            _u setVariable [QGVAR(stationDirty), true];   // temas bitince doFollow / doWatch / stance temizligi icin (stationPos sure dolunca silinse de kalir)
                            _tasinan = _tasinan + 1;
                            diag_log format [
                                "[ROL] %1 | %2 | %3 istasyonu (%4) | lidere %5m, ileri %6m -> %7m",
                                groupId _g, name _u, _key, _kaynak,
                                round (_uPos distance2D _lPos),
                                round ((_uPos vectorDiff _lPos) vectorDotProduct _fwd),
                                round (_hedef distance2D _lPos)
                            ];
                        };
                    };
                };

                // ---------------------------------------------------------
                // GOREVLER (istasyondan bagimsiz)
                // ---------------------------------------------------------
                // UGL: piyadeye 40mm (tacticalUGL kendi cooldown / uygunluk kontrolunu yapar)
                if (_glM isNotEqualTo "") then {
                    private _e = _u findNearestEnemy _u;
                    if (!isNull _e && {_e isKindOf "CAManBase"}) then {
                        if ([_u, _e] call _uglFn) then {
                            diag_log format ["[ROL-GOREV] %1 | %2 | UGL -> %3 (%4m)", groupId _g, name _u, name _e, round (_u distance2D _e)];
                        };
                    };
                };

                // MG: hat kapaliysa alana baski (atis ussu ates kesmesin)
                if (_key isEqualTo "MG" && {(time - (_u getVariable [QGVAR(mgSupLast), -999])) > 8}) then {
                    private _e = _u findNearestEnemy _u;
                    if (!isNull _e) then {
                        private _d = _u distance2D _e;
                        if (_d > 50 && {_d < 450} && {(_u knowsAbout _e) > 0.4}) then {
                            if (lineIntersects [eyePos _u, eyePos _e, _u, _e]) then {
                                _u setVariable [QGVAR(mgSupLast), time];
                                private _bp = getPosATL _e;
                                _bp set [2, 0.5];
                                [_u, AGLToASL _bp] call _supFn;
                                diag_log format ["[ROL-GOREV] %1 | %2 | MG alana baski (hat kapali, %3m)", groupId _g, name _u, round _d];
                            };
                        };
                    };
                };

                // NISANCI: launcher'li / MG'li dusman once
                if (_key isEqualTo "MARKSMAN" && {(time - (_u getVariable [QGVAR(mrkLast), -999])) > 6}) then {
                    private _adaylar = (_u targets [true, 600]) select {
                        _x isKindOf "CAManBase"
                        && {(_u distance2D _x) > 80}
                        && {(_u knowsAbout _x) > 1}
                    };
                    private _en = objNull;
                    private _enPuan = 0;
                    {
                        private _puan = 0;
                        if ((secondaryWeapon _x) isNotEqualTo "") then {
                            _puan = 3;
                        } else {
                            if (([_x] call _rolFn) isEqualTo "MG") then { _puan = 2; };
                        };
                        if (_puan > _enPuan) then {
                            _enPuan = _puan;
                            _en = _x;
                        };
                    } forEach _adaylar;

                    if (!isNull _en) then {
                        _u setVariable [QGVAR(mrkLast), time];
                        _u doTarget _en;
                        _u doFire _en;
                        diag_log format [
                            "[ROL-GOREV] %1 | %2 | nisanci oncelikli hedef: %3 (%4m)",
                            groupId _g, name _u, ["MG", "launcher"] select (_enPuan >= 3), round (_u distance2D _en)
                        ];
                    };
                };
            } forEach _tum;
        } forEach allGroups;
    };
};

true
