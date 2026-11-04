#include "script_component.hpp"
/*
 * Author: Cinar (ELITE fork)
 * AKILLI / PLANLI DEVRIYE ADIMI (v8.400; kullanici: 'scheduled olsun ve akilli patrol ekle, her birim bir digerinin nerede patrol attigini bilsin, herkes herkesten haberdar olsun').
 * fnc_karakolGarnizon her 15 sn'de her DEVRIYE alt grubu icin bu adimi cagirir (devriye alarmda degilse). Her devriye bir DURUM MAKINESIDIR:
 *   DINLEN  : karakol toplanma noktasinda dinlenir (CBA devDinlen sn); ilk turlar KADEMELI baslar (devriye i, i x devAralik / devriye sayisi sn sonra) ve ayni karakoldan iki devriye devAralik / sayi sn'den
 *             yakin cikmaz (PLANLI = zamanlanmis tur takvimi; eskiden hepsi ayni anda cikip halkada dolasirdi).
 *   TUR     : SEKTOR devriyesi — karakol cevresi 8 sektore (45 derece) bolunur; devriye sektorun yayinda 4 noktali rota + toplanma noktasina donus yapar (dis noktalarda 6-20 sn dinleme duraklamasi).
 *             Tur bitince (son waypoint statement'i ya da CBA devTurSure) sektor 'ziyaret edildi' diye isaretlenir.
 *   DESTEK  : baska devriyenin temas raporuna yonlendirildi (fnc_devriyeHaber; SAD, devDestek suresi 240 sn), sonra DINLEN.
 *   KESILDI : karakol alarmi / dis mudahale rotayi kesti -> 20 sn sonra DINLEN (sektor ziyaret edildi SAYILMAZ).
 * ORTAK RESIM (herkes herkesten haberdar): lambs_danger_devriyeAg (HashMap grup netId -> [taraf, karakol, sektor, rota noktalari]) TUM karakollarin devriyeleri icin ortaktir. Sektor secimi (en yuksek puan):
 *   yas (sektorun en son ziyaretinden beri sn, en cok 900) - baska bir devriye (ayni taraf, TUR durumunda, herhangi karakol) o sektorun yakininda (0.32 x devriye mesafesi, en az 25 m) rota tutuyorsa -2000 (cakisma yok) + taze (< 300 sn) dost temas
 *   raporu o sektorun yakininda ise +400 (bildirilen yeri kontrol et) - onceki sektorun aynisi -250 (+ kucuk rastgele). Rapor paylasimi / destek yonlendirme: fnc_devriyeHaber.
 * Eski halka rotasi: CBA devAkilli kapaliysa fnc_karakolGarnizon eski halka rotasini kullanir.  Log: [KARAKOL-DEVRIYE]
 *
 * Arguments:
 * 0: Devriye grubu <GROUP>
 * 1: Devriye sirasi (0..) <NUMBER>
 * 2: Karakol isaret adi (kimlik) <STRING>
 * 3: Karakol merkezi <ARRAY>
 * 4: Karakol yaricapi <NUMBER>
 * 5: Devriye mesafesi (rotanin merkeze uzakligi) <NUMBER>
 * 6: Taraf <SIDE>
 * 7: Karakol adi <STRING>
 * 8: Devriye sayisi <NUMBER>
 *
 * Return Value: Durum <STRING>
 * Public: No
*/

params ["_dg", "_idx", "_mn", "_poz", "_yar", "_devBaz", "_taraf", "_ad", "_devN"];

if (isNil "lambs_danger_devriyeAg") then { lambs_danger_devriyeAg = createHashMap; };
if (isNil "lambs_danger_devSektorT") then { lambs_danger_devSektorT = createHashMap; };
if (isNil "lambs_danger_devKalkisT") then { lambs_danger_devKalkisT = createHashMap; };

private _ag = lambs_danger_devriyeAg;
private _sektorT = lambs_danger_devSektorT;
private _key = netId _dg;
private _aralik = missionNamespace getVariable ["lambs_danger_devAralik", 180];
private _dinlen = missionNamespace getVariable ["lambs_danger_devDinlen", 90];
private _turMaks = missionNamespace getVariable ["lambs_danger_devTurSure", 900];
private _sN = 8;
private _sAci = 360 / _sN;
private _aralikK = _aralik / (_devN max 1);
private _durum = _dg getVariable ["lambs_danger_devDurum", ""];

private _restPoz = _poz getPos [((_yar * 0.25) min 30), (_idx * 90) + 45];
if (surfaceIsWater _restPoz) then { _restPoz = +_poz; };

// waypoint temizligi: biki idiomu (forEach ile silmek indeksleri kaydirir)
private _wpTemizle = {
    params ["_g"];
    private _n = 0;
    while {(count (waypoints _g)) > 0 && {_n < 40}} do {
        deleteWaypoint ((waypoints _g) select 0);
        _n = _n + 1;
    };
};

// toplanma noktasina dinlenmeye gonder
private _dinlenBasla = {
    params ["_g", "_sure"];
    [_g] call _wpTemizle;
    _g setVariable ["lambs_danger_devDurum", "DINLEN"];
    _g setVariable ["lambs_danger_devBitis", time + _sure];
    _g setVariable ["lambs_danger_devTurBitti", false];
    _ag set [netId _g, [_taraf, _mn, -1, []]];
    _g setBehaviour "AWARE";
    _g setCombatMode "YELLOW";
    private _w = _g addWaypoint [_restPoz, 6];
    _w setWaypointType "MOVE";
    _w setWaypointName format ["ELITE DEVRIYE %1: dinlen", _ad];
    _w setWaypointBehaviour "AWARE";
    _w setWaypointSpeed "LIMITED";
    _w setWaypointCombatMode "YELLOW";
    _w setWaypointCompletionRadius 15;
};

// ilk kayit: kademeli baslangic takvimi
if (_durum isEqualTo "") then {
    _durum = "DINLEN";
    _dg setVariable ["lambs_danger_devSektor", -1];
    [_dg, 8 + (_idx * _aralikK)] call _dinlenBasla;
    diag_log format ["[KARAKOL-DEVRIYE] %1 | %2 PLANA ALINDI: ilk tur %3 sn sonra (devriye %4/%5, aralik %6 sn, dinlenme %7 sn)", _ad, groupId _dg, round (8 + (_idx * _aralikK)), _idx + 1, _devN, round _aralikK, round _dinlen];
};

if (_durum isEqualTo "KESILDI") then {
    [_dg, 20] call _dinlenBasla;
    _durum = "DINLEN";
    diag_log format ["[KARAKOL-DEVRIYE] %1 | %2 rotasi kesilmisti (alarm / mudahale): 20 sn sonra yeni tur planlanir", _ad, groupId _dg];
};

if (_durum isEqualTo "DESTEK") then {
    if (time > (_dg getVariable ["lambs_danger_devDestekBitis", 0])) then {
        [_dg, 30] call _dinlenBasla;
        _durum = "DINLEN";
        diag_log format ["[KARAKOL-DEVRIYE] %1 | %2 destek gorevi bitti -> karakole donup dinleniyor", _ad, groupId _dg];
    };
};

if (_durum isEqualTo "TUR") then {
    private _t0 = _dg getVariable ["lambs_danger_devTurT0", time];
    private _bitti = (_dg getVariable ["lambs_danger_devTurBitti", false]) || {(time - _t0) > _turMaks} || {(count (waypoints _dg)) < 2};
    if (_bitti) then {
        private _sek = _dg getVariable ["lambs_danger_devSektor", -1];
        if (_dg getVariable ["lambs_danger_devTurBitti", false]) then {
            _sektorT set [format ["%1|%2", _mn, _sek], time];
        };
        diag_log format ["[KARAKOL-DEVRIYE] %1 | %2 TUR BITTI: sektor %3 (%4 derece) | sure %5 sn | %6", _ad, groupId _dg, _sek, round (_sek * _sAci), round (time - _t0), ["erken / waypoint yok", "toplanma noktasina dondu"] select (_dg getVariable ["lambs_danger_devTurBitti", false])];
        [_dg, _dinlen + (random 20)] call _dinlenBasla;
        _durum = "DINLEN";
    };
};

if (_durum isEqualTo "DINLEN") then {
    private _bitis = _dg getVariable ["lambs_danger_devBitis", 0];
    private _son = _dg getVariable ["lambs_danger_devSonCikis", -999];
    private _varmis = ((leader _dg) distance2D _restPoz) < 60 || {time > (_bitis + 240)};
    private _kalkisOk = (time - (lambs_danger_devKalkisT getOrDefault [_mn, -999])) >= _aralikK;
    if (time >= _bitis && {_varmis} && {_kalkisOk} && {(time - _son) > 20}) then {
        // ---- SEKTOR SECIMI (ortak resim) ----
        private _sec = -1;
        private _enS = -1e9;
        private _onceki = _dg getVariable ["lambs_danger_devSektor", -1];
        private _kr = 25 max (_devBaz * 0.32);   // sektor merkezi ile komsu sektorun rota noktasi ~0.41 x devBaz, ayni sektorun noktasi ~0.25 x devBaz uzakta
        private _kb = 250 max (_devBaz * 0.5);      // temas raporu etki yaricapi
        private _haberler = missionNamespace getVariable ["lambs_danger_devHaberler", []];
        for "_s" from 0 to (_sN - 1) do {
            private _ac = _s * _sAci;
            private _pm = _poz getPos [_devBaz * 0.8, _ac];
            private _skor = (time - (_sektorT getOrDefault [format ["%1|%2", _mn, _s], -900])) min 900;
            if (surfaceIsWater _pm) then { _skor = _skor - 600; };
            {
                if (_x isNotEqualTo _key) then {
                    private _xv = _y;
                    private _xg = groupFromNetId _x;
                    if ((_xv select 0) isEqualTo _taraf && {!isNull _xg} && {(_xg getVariable ["lambs_danger_devDurum", ""]) isEqualTo "TUR"} && {((_xv select 3) findIf {_x distance2D _pm < _kr}) >= 0}) then { _skor = _skor - 2000; };
                };
            } forEach _ag;
            {
                if ((_x select 0) isEqualTo _taraf && {(time - (_x select 2)) < 300} && {((_x select 1) distance2D _pm) < _kb}) then { _skor = _skor + 400; };
            } forEach _haberler;
            if (_s isEqualTo _onceki) then { _skor = _skor - 250; };
            _skor = _skor + (random 15);
            if (_skor > _enS) then { _enS = _skor; _sec = _s; };
        };

        // ---- ROTA: sektor yayinda 4 nokta (su / su kenari elenir) ----
        private _ac = _sec * _sAci;
        private _rota = [];
        {
            _x params ["_da", "_df"];
            private _wp = [];
            {
                private _kat = _x;
                if (_wp isEqualTo []) then {
                    private _rr = _devBaz * _df * _kat;
                    {
                        private _cp = _poz getPos [_rr, _ac + _da + _x];
                        if (_wp isEqualTo [] && {!surfaceIsWater _cp} && {(count ([0, 90, 180, 270] select {surfaceIsWater (_cp getPos [12, _x])})) isEqualTo 0}) then { _wp = _cp; };
                    } forEach [0, 12, -12];
                };
            } forEach [1, 0.75, 0.5];
            if (_wp isNotEqualTo []) then { _rota pushBack _wp; };
        } forEach [[-22, 0.55], [-8, 1], [8, 1], [22, 0.55]];

        if ((count _rota) < 2) then {
            _dg setVariable ["lambs_danger_devBitis", time + 60];
            diag_log format ["[KARAKOL-DEVRIYE] %1 | %2 | sektor %3 icin gecerli rota noktasi yok (su / arazi); 60 sn sonra tekrar", _ad, groupId _dg, _sec];
        } else {
            [_dg] call _wpTemizle;
            {
                private _w = _dg addWaypoint [_x, 6];
                _w setWaypointType "MOVE";
                _w setWaypointName format ["ELITE DEVRIYE %1 S%2 #%3", _ad, _sec, _forEachIndex + 1];
                _w setWaypointBehaviour "AWARE";
                _w setWaypointSpeed "LIMITED";
                _w setWaypointFormation "STAG COLUMN";
                _w setWaypointCombatMode "YELLOW";
                _w setWaypointCompletionRadius 12;
                if (_forEachIndex > 0 && {_forEachIndex < ((count _rota) - 1)}) then { _w setWaypointTimeout [6, 12, 20]; };
            } forEach _rota;
            private _wd = _dg addWaypoint [_restPoz, 8];
            _wd setWaypointType "MOVE";
            _wd setWaypointName format ["ELITE DEVRIYE %1 S%2: donus", _ad, _sec];
            _wd setWaypointBehaviour "AWARE";
            _wd setWaypointSpeed "LIMITED";
            _wd setWaypointCombatMode "YELLOW";
            _wd setWaypointCompletionRadius 15;
            _wd setWaypointStatements ["true", "(group this) setVariable ['lambs_danger_devTurBitti', true];"];
            _dg setVariable ["lambs_danger_devDurum", "TUR"];
            _dg setVariable ["lambs_danger_devTurT0", time];
            _dg setVariable ["lambs_danger_devTurBitti", false];
            _dg setVariable ["lambs_danger_devSektor", _sec];
            _dg setVariable ["lambs_danger_devSonCikis", time];
            lambs_danger_devKalkisT set [_mn, time];
            _ag set [_key, [_taraf, _mn, _sec, +_rota]];
            _durum = "TUR";
            private _digerleri = [];
            {
                if (_x isNotEqualTo _key) then {
                    private _xg = groupFromNetId _x;
                    if (!isNull _xg && {((_y select 0) isEqualTo _taraf)}) then { _digerleri pushBack format ["%1:%2 S%3", groupId _xg, _xg getVariable ["lambs_danger_devDurum", "?"], _y select 2]; };
                };
            } forEach _ag;
            diag_log format ["[KARAKOL-DEVRIYE] %1 | %2 TUR BASLADI: sektor %3 (%4 derece, puan %5) | rota %6 nokta | merkezden %7 m | diger devriyeler (ortak resim): %8",
                _ad, groupId _dg, _sec, round _ac, round _enS, count _rota, round _devBaz, if (_digerleri isEqualTo []) then {"yok"} else {_digerleri}];
        };
    };
};

_durum
