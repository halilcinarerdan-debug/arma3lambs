#include "script_component.hpp"
/*
 * Author: Cinar (ELITE fork)
 * DURUM / DOKTRIN GOZLEMCISI — RPT'ye her asker icin anlik durum + grup basina doktrin uyum puani yazar (tani amacli, oyuna mudahale ETMEZ).
 *
 *   [DURUM-GRUP] grup | kisi | karar | formasyon | davranis | bayraklar | temas | en yakin dusman
 *   [DURUM]      grup | asker | rol | konum | lidere gore ileri/yanal | lider mesafesi | stance | hiz | baski | cephane | dusman mesafesi | gorev | bayrak
 *   [DOKTRIN]    grup | komutan onde mi | yigilma | ort. aralik | temasta ayakta | hareket orani | bound donusumu | dusuk cephane | PUAN /100
 *
 * Sikligi: temasta (son 60 sn) 20 sn'de bir, sakinde 60 sn'de bir; grup basina en fazla 16 asker satiri.
 * KAPATMA: lambs_danger_durumLogOff = true
 *
 * PUAN (yaklasik): 100 - komutan en onde (temasta, >= 4 kisi) 30 - yigilma orani x 30 - temasta ayakta orani x 20
 *                  - bound sirasinda herkes ayni anda hareket / kimse hareket etmiyor 20 - dusuk cephane orani x 10
 *
 * Arguments:
 * None
 *
 * Return Value:
 * Baslatildi mi <BOOL>
 *
 * Public: No
*/

if (!isNil "lambs_danger_durumLogStarted") exitWith {false};
lambs_danger_durumLogStarted = true;

diag_log "[DURUM] durum / doktrin gozlemcisi baslatildi (her asker: konum, rol, stance, hiz, gorev; grup: doktrin puani)";

// KOMUT GECISLERI: "ilerle / dur" spam'ini gormek icin temasli gruplarin askerlerinde currentCommand degisimi (1 sn'de bir kontrol,
// asker basina en fazla 3 sn'de bir satir, toplam 400 satir)
// v8.684 GIDIP GELME OLCUMU (kullanici: '1 2 3 yap' -> 2: birim MOVE -> STOP -> MOVE ters donusu 22 gecisin 5'i (<= 4 sn), kimin durdurdugu bilinmiyor; 'gorev:Assault' cogunlukta = LAMBS taban kodu repoda yok):
//   STOP'a her gecis aninda o birimin / grubun AKTIF SISTEM IMZASI cikarilir (forceMove, taktikKilit, yeni ates, baski, grup bayraklari, komutan karari, LAMBS gorevi, en yakin dusman mesafesi);
//   <= 4 sn icinde MOVE geri gelirse (MOVE -> STOP -> MOVE) imza 'ters donus' sayilir. 60 sn'de bir [EMIR-GIDIP-GELME]: gecis / ters donus orani + belirtec sikligi (ters donuslerde / tum STOP'larda) + en sik imza;
//   ilk 30 ters donus [EMIR-TERS-DONUS] olarak tek tek yazilir. YALNIZ OLCUM; emir akisini degistirmez; 400 satir / 3 sn sinirindan bagimsiz sayar.
[] spawn {
    private _n = 0;
    private _top = 0;
    private _stopS = 0;
    private _ters = 0;
    private _bAll = createHashMap;
    private _bTers = createHashMap;
    private _imzaH = createHashMap;
    private _tersLog = 0;
    private _tersKay = createHashMap;
    private _ozetT = time + 60;
    private _imza = {
        params ["_u", "_g"];
        private _t = [];
        if (_u getVariable [QGVAR(forceMove), false]) then { _t pushBack "fm"; };
        if (time < (_u getVariable [QGVAR(taktikKilit), 0])) then { _t pushBack "tk"; };
        if ((time - (_u getVariable [QGVAR(sonAtisT), -999])) < 3) then { _t pushBack "atis"; };
        if ((getSuppression _u) > 0.3) then { _t pushBack "baski"; };
        if ((time - (_u getVariable [QGVAR(hugAt), -999])) < 8) then { _t pushBack "hug"; };
        private _ah = _u getVariable [QGVAR(acikSiperHedef), [0, -999]];
        if ((time - (_ah param [1, -999])) < 8) then { _t pushBack "acikSiper"; };
        if (!isNil {_u getVariable QGVAR(kacisTok)}) then { _t pushBack "kacis"; };
        if (time < (_u getVariable [QGVAR(tcccBusy), 0])) then { _t pushBack "tccc"; };
        { if (_g getVariable [_x select 0, false]) then { _t pushBack (_x select 1); }; } forEach [
            [QGVAR(isBounding), "BND"], [QGVAR(isRetreating), "RET"], [QGVAR(isEvading), "EVD"], [QGVAR(isBreakingContact), "BRK"],
            [QGVAR(isExecutingTactic), "TAK"], [QGVAR(isAmbushing), "AMB"], [QGVAR(isSweeping), "SWP"]
        ];
        private _kar = _g getVariable [QGVAR(cmdSonKarar), ""];
        if (_kar isNotEqualTo "") then { _t pushBack ("k:" + _kar); };
        private _gv = _u getVariable [QEGVAR(main,currentTask), ""];
        if (_gv isEqualType "" && {_gv isNotEqualTo ""}) then { _t pushBack ("g:" + (_gv select [0, 12])); };
        private _en = _u findNearestEnemy _u;
        if (!isNull _en) then {
            private _dd = _u distance2D _en;
            _t pushBack (if (_dd < 25) then { "<25m" } else { if (_dd < 60) then { "<60m" } else { if (_dd < 120) then { "<120m" } else { ">=120m" } } });
        };
        _t
    };
    while {true} do {
        sleep 1;
        if (missionNamespace getVariable ["lambs_danger_durumLogOff", false]) then { continue };
        {
            private _g = _x;
            if (isNull _g || {!local _g} || {isPlayer (leader _g)}) then { continue };
            if ((_g getVariable [QGVAR(contact), 0]) < (time - 60)) then { continue };
            {
                private _u = _x;
                if (!alive _u || {!isNull objectParent _u}) then { continue };
                private _c = currentCommand _u;
                private _o = _u getVariable [QGVAR(durumKomut), ""];
                if (_c isNotEqualTo _o) then {
                    _u setVariable [QGVAR(durumKomut), _c];
                    if (_o isNotEqualTo "") then {
                        _top = _top + 1;
                        private _prev = _u getVariable [QGVAR(durumGecis), []];
                        // ters donus: onceki gecis MOVE -> STOP idi, <= 4 sn icinde yeniden MOVE
                        if (_prev isNotEqualTo [] && {(_prev select 2) isEqualTo "STOP"} && {(_prev select 1) isEqualTo "MOVE"} && {_o isEqualTo "STOP"} && {_c isEqualTo "MOVE"} && {(time - (_prev select 0)) <= 4}) then {
                            _ters = _ters + 1;
                            private _im = +(_prev select 3);
                            // v8.707 KAYNAK ATFI (RPT 87f87da8: ters donuslerin 16 / 29'u 'acikSiper' imzali, sureler 1-2 sn = acikSiper'in 'siper noktasina otur' adimi sleep 2 + doMove _pt ile ortusuyor ama KANITSIZDI): ikinci MOVE, MOVE -> STOP gecisinden SONRA verilmis bir acikSiper doMove'u ise kaynak damgalanir:
                            //   siperOtur = siper noktasina OTUR adiminin kendi doMove'u (kasitli); siperYeni = acikSiper yeni siper secimi (gercek gidip-gelme adayi); damga yoksa belirsiz (motor / formasyon / baska modul)
                            // v8.709 KESIN ATIF: zaman toleransi yerine DAMGA DEGISTI MI (RPT 1e81987e: +-1 sn tolerans ayni sicramanin damgasini 'siperYeni' sayabiliyordu); MOVE -> STOP gecisinde damgalar kaydedilir, ters donuste simdiki damgayla karsilastirilir
                            private _dm0 = if ((count _prev) > 4) then { _prev select 4 } else { [-1, -1] };
                            private _kay = "belirsiz";
                            if ((_u getVariable [QGVAR(oturDoMoveT), -999]) isNotEqualTo (_dm0 select 1)) then { _kay = "siperOtur"; } else { if ((_u getVariable [QGVAR(siperDoMoveT), -999]) isNotEqualTo (_dm0 select 0)) then { _kay = "siperYeni"; }; };
                            _tersKay set [_kay, (_tersKay getOrDefault [_kay, 0]) + 1];
                            _im pushBack ("kaynak:" + _kay);
                            { _bTers set [_x, (_bTers getOrDefault [_x, 0]) + 1]; } forEach _im;
                            private _ik = _im joinString ",";
                            _imzaH set [_ik, (_imzaH getOrDefault [_ik, 0]) + 1];
                            if (_tersLog < 30) then {
                                _tersLog = _tersLog + 1;
                                diag_log format ["[EMIR-TERS-DONUS] %1 | %2 | MOVE -> STOP -> MOVE %3 sn | imza (STOP aninda): %4 | hiz:%5", groupId _g, name _u, (time - (_prev select 0)) toFixed 1, _ik, round (speed _u)];
                            };
                        };
                        private _imN = [];
                        if (_c isEqualTo "STOP" && {_o isEqualTo "MOVE"}) then {
                            _stopS = _stopS + 1;
                            _imN = [_u, _g] call _imza;
                            { _bAll set [_x, (_bAll getOrDefault [_x, 0]) + 1]; } forEach _imN;
                        };
                        _u setVariable [QGVAR(durumGecis), [time, _o, _c, _imN, [_u getVariable [QGVAR(siperDoMoveT), -999], _u getVariable [QGVAR(oturDoMoveT), -999]]]];
                    };
                    if (_o isNotEqualTo "" && {_n < 400} && {time > (_u getVariable [QGVAR(durumKomutT), 0])}) then {
                        _u setVariable [QGVAR(durumKomutT), time + 3];
                        _n = _n + 1;
                        diag_log format ["[KOMUT] %1 | %2 | %3 -> %4 | gorev:%5 | hiz:%6", groupId _g, name _u, _o, _c, _u getVariable [QEGVAR(main,currentTask), "-"], round (speed _u)];
                    };
                };
            } forEach (units _g);
        } forEach allGroups;
        if (time > _ozetT) then {
            _ozetT = time + 60;
            if (_top > 0) then {
                private _bel = (keys _bAll) apply { [_bAll get _x, _x] };
                _bel sort false;
                private _belS = (_bel select [0, 10]) apply { format ["%1 %2/%3", _x select 1, _bTers getOrDefault [_x select 1, 0], _x select 0] };
                private _iz = (keys _imzaH) apply { [_imzaH get _x, _x] };
                _iz sort false;
                diag_log format ["[EMIR-GIDIP-GELME] 60 sn: komut gecisi %1 | MOVE -> STOP %2 | ters donus (MOVE -> STOP -> MOVE <= 4 sn) %3 (%4 %% of STOP) | belirtec (ters donuslerde / tum STOP'larda): %5 | en sik imza: %6 | ters donus kaynagi: siperOtur %7 (kasitli) / siperYeni %8 / belirsiz %9",
                    _top, _stopS, _ters, (if (_stopS > 0) then { round (100 * _ters / _stopS) } else { 0 }), _belS joinString ", ", ((_iz select [0, 3]) apply { format ["%1x [%2]", _x select 0, _x select 1] }) joinString " ; ", _tersKay getOrDefault ["siperOtur", 0], _tersKay getOrDefault ["siperYeni", 0], _tersKay getOrDefault ["belirsiz", 0]];
            };
            _top = 0; _stopS = 0; _ters = 0; _bAll = createHashMap; _bTers = createHashMap; _imzaH = createHashMap; _tersKay = createHashMap;
        };
    };
};

[] spawn {
    private _rolFn = missionNamespace getVariable ["lambs_danger_fnc_getUnitRole", {"RIFLE"}];

    while {true} do {
        sleep 5;
        if (missionNamespace getVariable ["lambs_danger_durumLogOff", false]) then { continue };

        {
            private _g = _x;
            if (isNull _g || {!local _g}) then { continue };
            private _l = leader _g;
            if (isNull _l || {isPlayer _l} || {!alive _l}) then { continue };
            private _us = (units _g) select {alive _x && {isNull objectParent _x}};
            if (_us isEqualTo []) then { continue };

            private _temas = (_g getVariable [QGVAR(contact), 0]) > (time - 60);
            if ((time - (_g getVariable [QGVAR(durumT), -999])) < ([60, 20] select _temas)) then { continue };
            _g setVariable [QGVAR(durumT), time];

            private _lPos = getPosATL _l;
            private _en = _l findNearestEnemy _l;
            private _enMes = if (isNull _en) then {-1} else {round (_l distance2D _en)};
            private _yon = if (isNull _en) then {getDir _l} else {_l getDir _en};
            private _fwd = [sin _yon, cos _yon, 0];
            private _sag = [cos _yon, -(sin _yon), 0];

            private _bayrak = [];
            { if (_g getVariable [_x select 0, false]) then { _bayrak pushBack (_x select 1); }; } forEach [
                [QGVAR(isBounding), "BND"], [QGVAR(isRetreating), "RET"], [QGVAR(isEvading), "EVD"],
                [QGVAR(isBreakingContact), "BRK"], [QGVAR(isAmbushing), "AMB"], [QGVAR(isExecutingTactic), "TAK"], [QGVAR(isATEngage), "ATE"]
            ];

            // v8.542 ETKIN SAYISI + SILAH DAGILIMI (kullanici: 'baygin da etkisiz; bizde herkeste otomatik, onlarda cok az; sks ile m16 ayni degil'): 'kisi' canli sayisi (baygin DAHIL); etkin = saglikli / yarali ve baygin olmayan;
            //   silah: otomatik (q >= 0.8) / yari-otomatik veya bolt (q < 0.8) sayisi ve ortalama silah gucu (fnc_silahGucu)
            private _etkinN = count (_us select {(lifeState _x) in ["HEALTHY", "INJURED"] && {!(_x getVariable ["ACE_isUnconscious", false])}});
            private _qs = _us apply { [_x] call FUNC(silahGucu) };
            private _oto = count (_qs select { _x >= 0.8 });
            private _qT = 0;
            { _qT = _qT + _x; } forEach _qs;
            private _qOrt = _qT / ((count _qs) max 1);
            diag_log format [
                "[DURUM-GRUP] %13 %1 | %2 kisi (etkin %14) | silah: otomatik %15 / yari-bolt %16, ort guc %17 | karar:%3 | form:%4 | beh:%5 cm:%6 | bayrak:%7 | temas:%8 | dusman:%9 m yon:%10 | lider xy:%11 | dusman xy:%12",
                groupId _g, count _us, _g getVariable [QGVAR(cmdLastDecision), "-"], formation _g, behaviour _l, combatMode _g,
                _bayrak joinString "+", ["yok", "var"] select _temas, _enMes, round _yon,
                (getPosATL _l) select [0, 2] apply { round _x },
                if (isNull _en) then {"-"} else {(getPosATL _en) select [0, 2] apply { round _x }},
                str (side _g), _etkinN, _oto, (count _qs) - _oto, _qOrt toFixed 2
            ];

            private _onde = 0;
            private _yigil = 0;
            private _baygin = 0;
            private _aralikT = 0;
            private _ayakta = 0;
            private _hareket = 0;
            private _dusukC = 0;
            private _n = count _us;
            private _i = 0;
            {
                private _u = _x;
                private _fark = (getPosATL _u) vectorDiff _lPos;
                private _ileri = (_fark vectorDotProduct _fwd);
                private _yanal = (_fark vectorDotProduct _sag);
                if (_u isNotEqualTo _l && {_ileri > 6}) then { _onde = _onde + 1; };

                private _komsu = 9999;
                { if (_x isNotEqualTo _u) then { _komsu = _komsu min (_u distance2D _x); }; } forEach _us;
                if (_n > 1) then {
                    _aralikT = _aralikT + (_komsu min 60);
                    // v8.367: YIGILMA yalniz AYAKTA / bilincli askerler arasinda sayilir (RPT 20:13:34: yan yana yatan baygin askerler 'yigilma 5/8' puani dusuruyordu); baygin kumesi ayri sayilir
                    private _aktif = (lifeState _u) in ["HEALTHY", "INJURED"];
                    if (!_aktif) then { _baygin = _baygin + 1; };
                    if (_aktif && {_komsu < 2.5} && {({(_x isNotEqualTo _u) && {(lifeState _x) in ["HEALTHY", "INJURED"]} && {(_x distance2D _u) < 2.5}} count _us) > 0}) then { _yigil = _yigil + 1; };
                };

                private _st = stance _u;
                if (_st isEqualTo "STAND" && {(getSuppression _u) > 0.2 || {_temas}}) then { _ayakta = _ayakta + 1; };
                if ((speed _u) > 1.5) then { _hareket = _hareket + 1; };
                private _mag = count (magazines _u);
                if (_mag <= 1 && {(_u ammo (primaryWeapon _u)) < 10}) then { _dusukC = _dusukC + 1; };

                if (_i < 16) then {
                    private _e = _u findNearestEnemy _u;
                    diag_log format [
                        "[DURUM] %1 | %2%3 | %4 | poz:[%5,%6] | ileri:%7 yanal:%8 | lider:%9 m | %10 | %11 km/s | baski:%12 | sarjor:%13 | dusman:%14 m | gorev:%15 | %16 | komut:%17 | anim:%18 | katsayi:%19 | yon:%20",
                        groupId _g, name _u, ["", " (K)"] select (_u isEqualTo _l), [_u] call _rolFn,
                        round ((getPosATL _u) select 0), round ((getPosATL _u) select 1),
                        round _ileri, round _yanal, round (_u distance2D _l), _st, round (speed _u),
                        (getSuppression _u) toFixed 2, _mag,
                        if (isNull _e) then {"-"} else {round (_u distance2D _e)},
                        _u getVariable [QEGVAR(main,currentTask), "-"],
                        ([
                            ["fm", _u getVariable [QGVAR(forceMove), false]],
                            ["ist", (_u getVariable [QGVAR(stationPos), []]) isNotEqualTo []],
                            ["bomba", (_u getVariable [QGVAR(grState), []]) isNotEqualTo []],
                            ["arka", (_g getVariable [QGVAR(rearGuardU), objNull]) isEqualTo _u]
                        ] select {_x select 1} apply {_x select 0}) joinString ",",
                        currentCommand _u,
                        (animationState _u) select [((count (animationState _u)) - 16) max 0],
                        _u getVariable [QGVAR(mvAnim), "-"],
                        round (getDir _u)
                    ];
                };
                _i = _i + 1;
            } forEach _us;

            // komutan en onde mi? (hicbir asker liderin 6 m'den fazla onunde degil, grup >= 4, temasta)
            private _komutanOnde = _temas && {_n >= 4} && {_onde isEqualTo 0};
            private _yigilOran = if (_n > 1) then {_yigil / _n} else {0};
            private _ayaktaOran = [0, _ayakta / _n] select _temas;
            private _hareketOran = _hareket / _n;
            private _boundOk = true;
            if (_g getVariable [QGVAR(isBounding), false]) then {
                _boundOk = (_hareketOran >= 0.2) && {_hareketOran <= 0.75};
            };
            private _puan = 100
                - ([0, 30] select _komutanOnde)
                - (_yigilOran * 30)
                - (_ayaktaOran * 20)
                - ([20, 0] select _boundOk)
                - ((_dusukC / _n) * 10);

            diag_log format [
                "[DOKTRIN] %1 | komutan_onde:%2 | yigilma(<2.5m):%3/%4 | ort.aralik:%5 m | temasta_ayakta:%6/%7 | hareket:%8%% | bound_donusum:%9 | dusuk_cephane:%10 | PUAN:%11/100 | baygin:%12",
                groupId _g, _komutanOnde, _yigil, _n, if (_n > 1) then {round (_aralikT / _n)} else {0},
                _ayakta, _n, round (_hareketOran * 100), ["IHLAL", "ok"] select _boundOk, _dusukC, round (_puan max 0), _baygin
            ];
        } forEach allGroups;
    };
};

true
