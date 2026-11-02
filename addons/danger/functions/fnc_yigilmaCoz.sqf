#include "script_component.hpp"
/*
 * Author: Cinar (ELITE fork)
 * YIGILMA NEDENI + COZUCU (v8.367; kullanici: 'herseyin nedeni olsun, ayni yerde birden fazla adam yigiliyor').
 *
 * NEDEN GEREKLI (RPT 20:08-20:17, Alpha 1-1 / 1-2, 8'er kisi): [DOKTRIN] yigilma(<2.5m) 3-5/8 (PUAN 26-66) olculdu ama fnc_dispersion bir kez bile 'tasindi' yazmadi -> dagilma sistemi bu durumlarda HIC calismiyordu:
 *   - dispersion BOUNDING / taktik yurutenleri ve forceMove'lu askerleri tamamen atliyor (fnc_dispersion 51-79), yigilmalar tam da bu durumlarda (BND+TAK bayragi) olusuyordu;
 *   - yigilan askerlerin kendi sistemleri (acikSiper, bounding kosucusu, hekim) ayni noktayi ayri ayri secti: acikSiper 3-4 askeri AYNI direk / tele (1.5 m kurali), bounding kosucularinin
 *     GERCEK sectigi nokta rezerv defterinde yoktu, hekim yaralinin 4.5-6 m uzaginda yarim ayakta bekledi (bunlar ilgili dosyalarda duzeltildi: acikSiper, tacticsBounding, tccc);
 *   - kalan yigilmalarin NEDENI hicbir yerde yazilmiyordu.
 * BU FONKSIYON iki is yapar:
 *   1) NEDEN: ayni yerde (< 2.5 m) en az 3 AYAKTA / bilincli asker 6 sn (temas) ya da 12 sn (sakin) boyunca yigili kalirsa [YIGILMA-NEDEN] satiri her uyenin NEDENINI adiyla yazar:
 *        HEKIM (tcccBusy) / BOMBA (el bombasi durumu) / ISTASYON (rol istasyonu) / BOUND-VARIS (bounding forceMove) / EMIR-FM (baska forceMove) / BINA / ACIK-SIPER-ORTAK (ayni siper noktasi) /
 *        SIPER-YAPIS (coverHug 25 sn) / BOUND-KAPSAMA (kapsama ekibi yerinde) / TEMAS-DURAN (temasta duruyor) / FORMASYON-SIKISIK (sakin; formasyon slotu cok yakin).
 *      Ayrica baygin / yarali kumesi (3+ baygin 4 m icinde) [YIGILMA-BAYGIN] ile ayri yazilir (olum bolgesi sinyali: askerler ayni yerde vurulmus).
 *   2) COZUM: yigilmanin TASINABILIR uyelerinden (nedeni muaf degil, lider degil) en fazla 2'si, her biri bos bir noktaya 4-8 m yana tasinir (diger dostlardan >= 3.5 m, rezerv defterinde olmayan,
 *      yolu duvara carpmayan; dusmanin yonunde engel varsa +8; dusmana yaklasmaz). doMove kalici emirdir: asker orada KALIR. Asker basina 15 sn, grup basina tik 4 sn.
 *      MUAF (tasinmaz, yalniz loglanir): hekim, bomba, istasyon, forceMove, binada. BOUNDING kapsama ekibi (forceMove'suz) tasinabilir - dispersion'in atladigi bosluk budur.
 *   Grup duzeyi muafiyet: oyuncu lideri, retreat / evade / temas kes / peel / sweep (bina temizleme) / AT taarruz, mevzi / hendek, keskin nisanci takimi, ELITE kapali.
 * Kapatma: CBA 'ELITE yigilma cozucu' (lambs_danger_yigilmaAktif). Yaricap lambs_danger_yigilmaYaricap (2.5 m), siper noktalari arasi asgari aralik lambs_danger_yigilmaAralik (4 m; fnc_acikSiper kullanir).
 * Log: [YIGILMA-NEDEN] / [YIGILMA-COZ] / [YIGILMA-BAYGIN] (ilk 60'ar) + 120 sn [YIGILMA-OZET].
 *
 * Arguments: None
 * Return Value: Baslatildi mi <BOOL>
 * Public: No
*/

if (!isNil "lambs_danger_yigilmaStarted") exitWith {false};
lambs_danger_yigilmaStarted = true;

diag_log "[YIGILMA] yigilma nedeni + cozucu baslatildi (v8.367): < 2.5 m'de >= 3 ayakta asker 6-12 sn ayni yerde ise NEDEN yazilir, tasinabilir olan 4-8 m yana bos noktaya gecer";

// ---- uyenin yigilma NEDENI: [kod, tasinabilir] ----
lambs_danger_yigilmaNeden = {
    params ["_u", "_g"];
    private _ah = _u getVariable [QGVAR(acikSiperHedef), []];
    private _fm = (_u getVariable [QGVAR(forceMove), false]) isEqualTo true;
    call {
        if ((_u getVariable [QGVAR(tcccBusy), 0]) > time) exitWith { ["HEKIM", false] };
        if ((_u getVariable [QGVAR(grState), []]) isNotEqualTo []) exitWith { ["BOMBA", false] };
        if ((_u getVariable [QGVAR(stationPos), []]) isNotEqualTo []) exitWith { ["ISTASYON", false] };
        if (_fm && {_g getVariable [QGVAR(isBounding), false]}) exitWith { ["BOUND-VARIS", false] };
        if (_fm) exitWith { ["EMIR-FM", false] };
        if ((insideBuilding _u) > 0.5) exitWith { ["BINA", false] };
        if (_ah isNotEqualTo [] && {(time - (_ah select 1)) < 40} && {((_ah select 0) distance2D _u) < 6}) exitWith { ["ACIK-SIPER-ORTAK", true] };
        if ((time - (_u getVariable [QGVAR(hugAt), -999])) < 25) exitWith { ["SIPER-YAPIS", true] };
        if (_g getVariable [QGVAR(isBounding), false]) exitWith { ["BOUND-KAPSAMA", true] };
        if ((_g getVariable [QGVAR(contact), 0]) > time) exitWith { ["TEMAS-DURAN", true] };
        ["FORMASYON-SIKISIK", true]
    }
};

// ---- bos nokta: askerin 4-8 m yani; digerlerinden >= 3.5 m; [] = bulunamadi ----
lambs_danger_yigilmaYer = {
    params ["_u", "_ekRezerv"];
    private _p = getPosATL _u;
    private _en = _u findNearestEnemy _u;
    private _enP = if (isNull _en) then {[]} else {getPosATL _en};
    private _bak = if (_enP isEqualTo []) then {getDir _u} else {_p getDir _enP};
    private _dostlar = ((_p nearEntities ["CAManBase", 22]) select {_x isNotEqualTo _u && {alive _x} && {(side group _x) isEqualTo (side group _u)}}) apply {getPosATL _x};
    private _talep = ((((group _u) getVariable [QEGVAR(main,coverClaims), []]) select {(time - (_x select 1)) < 8 && {(_x select 2) isNotEqualTo _u}}) apply {_x select 0});
    private _dolu = ((missionNamespace getVariable ["lambs_danger_acikSiperDolu", []]) select {(time - (_x select 1)) < 30}) apply {_x select 0};
    private _hepsi = _dostlar + _ekRezerv + _talep + _dolu;
    private _eH = getTerrainHeightASL _p;
    private _enIyi = [];
    private _enS = -1e9;
    {
        private _ang = _bak + _x;
        {
            private _r = _x;
            private _c = _p getPos [_r, _ang];
            if (!surfaceIsWater _c && {(abs ((getTerrainHeightASL _c) - _eH)) <= 2}) then {
                private _min = 99;
                { _min = _min min (_x distance2D _c); } forEach _hepsi;
                if (_min >= 3.5 && {!(lineIntersects [AGLToASL (_p vectorAdd [0, 0, 0.9]), AGLToASL (_c vectorAdd [0, 0, 0.9]), _u, objNull])}) then {
                    private _yaklas = if (_enP isEqualTo []) then {0} else {((_p distance2D _enP) - (_c distance2D _enP)) max 0};
                    private _s = ((_min min 9) * 3) - (_r * 0.8) - (_yaklas * 2);
                    // dusman yonunde 2.5 m onde mermi durduran engel = hafif siper
                    if (_enP isNotEqualTo []) then {
                        private _on = _c getPos [2.5, _c getDir _enP];
                        if (lineIntersects [AGLToASL (_c vectorAdd [0, 0, 1]), AGLToASL (_on vectorAdd [0, 0, 1]), _u, objNull]) then { _s = _s + 8; };
                    };
                    if (_s > _enS) then { _enS = _s; _enIyi = _c; };
                };
            };
        } forEach [4, 6, 8];
    } forEach [90, -90, 135, -135, 60, -60, 180, 0];
    _enIyi
};

[] spawn {
    private _sayac = createHashMap;     // neden kodu -> adet (120 sn)
    private _kumeTop = 0;
    private _tasTop = 0;
    private _logN = 0;
    private _cozN = 0;
    private _bayN = 0;
    private _ozetT = time + 120;
    private _rolFn = missionNamespace getVariable ["lambs_danger_fnc_getUnitRole", {"RIFLE"}];
    while {true} do {
        sleep 4;
        if (!(missionNamespace getVariable ["lambs_danger_yigilmaAktif", true])) then { continue };
        private _yar = missionNamespace getVariable ["lambs_danger_yigilmaYaricap", 2.5];
        private _butce = 6;
        {
            private _g = _x;
            if (isNull _g || {!local _g}) then { continue };
            private _l = leader _g;
            if (isNull _l || {isPlayer _l}) then { continue };
            private _tum = (units _g) select {alive _x && {isNull objectParent _x}};
            if ((count _tum) < 3) then { continue };
            // grup duzeyi muafiyet: kendi hareket duzeni olan taktikler (BOUNDING / genel taktik DEGIL: dispersion'in atladigi bosluk)
            if (
                (_g getVariable [QGVAR(isRetreating), false]) || {_g getVariable [QGVAR(isEvading), false]} || {_g getVariable [QGVAR(isBreakingContact), false]}
                || {_g getVariable [QGVAR(isPeeling), false]} || {_g getVariable [QGVAR(isSweeping), false]} || {_g getVariable [QGVAR(isATEngage), false]}
                || {_g getVariable [QGVAR(disableGroupAI), false]} || {_g getVariable ["lambs_danger_disableGroupAI", false]}
                || {_g getVariable [QGVAR(sniperTeam), false]} || {_g getVariable ["lambs_danger_oyuncuKomuta", false]} || {[_g] call FUNC(mevziDeMi)}
            ) then { continue };

            // ---- baygin kumesi (olum bolgesi sinyali) ----
            private _bay = _tum select {!((lifeState _x) in ["HEALTHY", "INJURED"])};
            if (count _bay >= 3 && {_bayN < 60} && {(time - (_g getVariable [QGVAR(yigilBayT), -999])) > 60}) then {
                private _bk = _bay select {private _b0 = _x; ({(_x distance2D _b0) < 4} count _bay) >= 3};
                if (_bk isNotEqualTo []) then {
                    _bayN = _bayN + 1;
                    _g setVariable [QGVAR(yigilBayT), time];
                    private _bm = getPosATL (_bk select 0);
                    diag_log format ["[YIGILMA-BAYGIN] %1 | %2 baygin/yarali asker 4 m icinde (merkez [%3,%4]) | grup %5 kisi | karar:%6 | NEDEN: askerler birlikte vuruldu = yigilma sonucu (olum bolgesi); onlem: bu yigilma icin [YIGILMA-NEDEN] satirlarina bak", groupId _g, count _bk, round (_bm select 0), round (_bm select 1), count _tum, _g getVariable [QGVAR(cmdLastDecision), "-"]];
                };
            };

            // ---- ayakta / bilincli askerlerin yigilmasi ----
            private _akt = _tum select {(lifeState _x) in ["HEALTHY", "INJURED"] && {!captive _x} && {!isPlayer _x} && {(speed _x) < 2}};
            if ((count _akt) < 3) then { { _x setVariable [QGVAR(yigilGor), nil]; } forEach _tum; continue };
            private _nb = _akt apply { private _a = _x; [{_x isNotEqualTo _a && {(_x distance2D _a) < _yar}} count _akt, _a] };
            private _kume = _nb select {(_x select 0) >= 2};
            private _kumeU = _kume apply {_x select 1};
            { if !(_x in _kumeU) then { _x setVariable [QGVAR(yigilGor), nil]; }; } forEach _tum;
            if (_kume isEqualTo []) then { continue };

            private _temas = (_g getVariable [QGVAR(contact), 0]) > time;
            private _esik = [12, 6] select _temas;
            private _kalici = false;
            {
                private _gu = (_x select 1) getVariable [QGVAR(yigilGor), -1];
                if (_gu < 0) then { (_x select 1) setVariable [QGVAR(yigilGor), time]; } else { if ((time - _gu) >= _esik) then { _kalici = true; }; };
            } forEach _kume;
            if (!_kalici) then { continue };

            // ---- NEDEN ----
            private _satir = [];
            private _tasinabilir = [];
            {
                _x params ["_k", "_u"];
                private _nd = [_u, _g] call lambs_danger_yigilmaNeden;
                _sayac set [_nd select 0, (_sayac getOrDefault [_nd select 0, 0]) + 1];
                _satir pushBack format ["%1=%2%3", name _u, _nd select 0, ["", "(muaf)"] select (!(_nd select 1))];
                if ((_nd select 1) && {_u isNotEqualTo _l} && {(time - (_u getVariable [QGVAR(yigilT), -999])) > 15} && {(_u getVariable [QGVAR(taktikKilit), 0]) <= time}) then { _tasinabilir pushBack [_k, _u]; };
            } forEach _kume;
            _kumeTop = _kumeTop + 1;
            private _mrk = getPosATL ((_kume select 0) select 1);
            if (_logN < 60 && {(time - (_g getVariable [QGVAR(yigilLogT), -999])) > 20}) then {
                _logN = _logN + 1;
                _g setVariable [QGVAR(yigilLogT), time];
                diag_log format ["[YIGILMA-NEDEN] %1 | %2/%3 ayakta asker < %4 m (merkez [%5,%6]) | >= %7 sn | karar:%8 | temas:%9 | bayrak:%10 | uyeler: %11",
                    groupId _g, count _kume, count _akt, _yar, round (_mrk select 0), round (_mrk select 1), _esik, _g getVariable [QGVAR(cmdLastDecision), "-"], ["yok", "var"] select _temas,
                    (([[QGVAR(isBounding), "BND"], [QGVAR(isExecutingTactic), "TAK"]] select {_g getVariable [_x select 0, false]}) apply {_x select 1}) joinString "+",
                    _satir joinString ", "];
            };

            // ---- COZUM ----
            if (_tasinabilir isEqualTo [] || {_butce <= 0}) then {
                if (_tasinabilir isEqualTo [] && {_cozN < 60} && {(time - (_g getVariable [QGVAR(yigilCozT), -999])) > 20}) then {
                    _cozN = _cozN + 1;
                    _g setVariable [QGVAR(yigilCozT), time];
                    diag_log format ["[YIGILMA-COZ] %1 | cozum yok: tasinabilir uye bulunamadi (hepsi muaf / lider / 15 sn once tasindi / taktik kilidi) | %2 uye", groupId _g, count _kume];
                };
                continue
            };
            _tasinabilir = [_tasinabilir, [], {-(_x select 0)}, "ASCEND"] call BIS_fnc_sortBy;
            private _hedefSay = (floor ((count _kume) / 2)) max 1 min 2;
            private _rezerv = [];
            {
                if (_forEachIndex >= _hedefSay || {_butce <= 0}) exitWith {};
                private _u = _x select 1;
                private _hedef = [_u, _rezerv] call lambs_danger_yigilmaYer;
                if (_hedef isNotEqualTo []) then {
                    _butce = _butce - 1;
                    _rezerv pushBack _hedef;
                    _tasTop = _tasTop + 1;
                    private _nd = [_u, _g] call lambs_danger_yigilmaNeden;
                    _u setVariable [QGVAR(yigilT), time];
                    _u setVariable [QGVAR(yigilGor), nil];
                    _u setVariable [QGVAR(taktikKilit), time + 8];
                    _u doMove _hedef;
                    _u setUnitPosWeak (["AUTO", "MIDDLE"] select _temas);
                    private _cl = ((_g getVariable [QEGVAR(main,coverClaims), []]) select {(time - (_x select 1)) < 8});
                    _cl pushBack [_hedef, time, _u];
                    _g setVariable [QEGVAR(main,coverClaims), _cl];
                    if (_cozN < 60) then {
                        _cozN = _cozN + 1;
                        diag_log format ["[YIGILMA-COZ] %1 | %2 (%3, nedeni %4) -> %5 m yana bos noktaya (en yakin dost %6 m) | temas:%7", groupId _g, name _u, [_u] call _rolFn, _nd select 0, round (_u distance2D _hedef), (round (selectMin ((_tum - [_u]) apply {_x distance2D _hedef}))), ["yok", "var"] select _temas];
                    };
                };
            } forEach _tasinabilir;
        } forEach allGroups;

        if (time > _ozetT) then {
            _ozetT = time + 120;
            if (_kumeTop > 0) then {
                diag_log format ["[YIGILMA-OZET] 120 sn: kalici yigilma %1 kez | tasinan %2 | uye nedenleri: %3", _kumeTop, _tasTop, (keys _sayac) apply {format ["%1:%2", _x, _sayac get _x]}];
            };
            _kumeTop = 0; _tasTop = 0; _sayac = createHashMap;
        };
    };
};
true
