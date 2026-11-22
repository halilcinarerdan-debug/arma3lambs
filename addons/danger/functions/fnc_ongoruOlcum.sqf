#include "script_component.hpp"
/*
 * Author: Cinar (ELITE fork)
 * ONGORU OLCUMU (v8.730; kullanici: 'on gorunun gercekten ise yarayip yaramayacagini olcecek sistem ekle'). Roadmap Asama 13 madde 8.
 * fnc_ongoruKayit'in olcum kuyrugundaki (lambs_danger_ogKayit) her siper secimini 12 sn izler ve iki soruyu yanitlar:
 *  1) TAHMIN DOGRU MU? ongoruSure sn sonra GERCEK dusman konumu ile 'ileri' senaryo konumu arasi hata (m) vs 'dusman oldugu yerde kalir' tabani (daha kucuk = ileri senaryo ise yarar); dusmanin siperden bakilan
 *     yanal kaymasi >= 12 / >= 25 derece olan oran (kanat senaryosu gercekci mi).
 *  2) SECIM IYILESTI MI? (kontrollu deney) Secimlerin CBA ongoruKontrolOran'i KONTROL (ceza uygulanmaz), digerleri TEDAVI (ceza uygulanir). Her secimde siper noktasinin 2 / 4 / 6 / 8 / 10. sn'de GERCEK dusmanin goz hattindan
 *     ACIK olup olmadigi (FIRE LOD, asker siperde = 3 m icinde) ve 12 sn icinde hasar (>= 0.05) / olum izlenir. Gruplar: K0 / K1 (kontrol, ham ceza = 0 / > 0), T0 / T1 (tedavi, ham ceza = 0 / > 0).
 *     TAHMIN GUCU = kontrolde (K1 acik% - K0 acik%): senaryolara acik noktalar gercekten daha acik mi? (kontrolde secim ongoruden etkilenmedigi icin yansiz). TEDAVI ETKISI = (T tumu acik% - K tumu acik%) (negatif iyi).
 * Log: [ONGORU-OLCUM] 120 sn'de bir (kumulatif) + HUKUM (ISE YARIYOR / YARAMIYOR / BELIRSIZ / VERI AZ; her grupta >= 12 kayit gerekir). Karne: ONGORU OLCUMU.
 * CBA: lambs_danger_ongoruOlcum (varsayilan ACIK), lambs_danger_ongoruKontrolOran (0.25; 0 = kontrol yok, olcum yalniz tahmin hatasi).
 * SINIR: yalniz nesne arkasi siper secimleri (acikSiper); 'acik %' siperdeki asker icin gercek dusman goz hattidir, atis degil; hasar nadir -> hasar orani icin cok kayit gerekir (acik % daha hizli oturur).
 *
 * Arguments: None
 * Return Value: Baslatildi mi <BOOL>
 * Public: No
*/

if (!isNil "lambs_danger_ongoruOlcumStarted") exitWith {false};
lambs_danger_ongoruOlcumStarted = true;
diag_log "[ONGORU-OLCUM] ongoru olcum sistemi (tahmin hatasi + kontrollu karsilastirma) baslatildi (v8.730)";

[] spawn {
    private _acc = createHashMap;
    private _ekle = { params ["_k", "_v"]; _acc set [_k, (_acc getOrDefault [_k, 0]) + _v]; };
    private _oran = { params ["_a", "_b"]; if (_b <= 0) then {"-"} else { (100 * _a / _b) toFixed 0 }; };
    private _ozetT = time + 120;
    while {true} do {
        sleep 1;
        private _list = missionNamespace getVariable ["lambs_danger_ogKayit", []];
        private _kalan = [];
        {
            _x params ["_t0", "_u", "_en", "_ep0", "_s1", "_cp", "_ham", "_kon", "_d0", "_sure", "_st", "_up0", ["_sk", []]];
            private _age = time - _t0;
            private _bitti = false;
            if (isNull _u) then { continue };   // silindi: sayilmaz
            // 1) tahmin puani (ongoruSure sonra)
            if (!(_st select 0) && {_age >= _sure}) then {
                _st set [0, true];
                if (!isNull _en && {alive _en}) then {
                    private _ac = getPosASL _en;
                    private _hrk = _ac distance2D _ep0;
                    ["pr_n", 1] call _ekle;
                    ["pr_hareket", _hrk] call _ekle;
                    if (_s1 isNotEqualTo []) then {
                        private _eS1 = _ac distance2D _s1;
                        ["pr_s1N", 1] call _ekle;
                        ["pr_errS1", _eS1] call _ekle;
                        ["pr_errTaban", _hrk] call _ekle;
                        if (_eS1 < _hrk) then { ["pr_s1Iyi", 1] call _ekle; };
                    };
                    // olasi siper kumesi isabeti: dusman ongoruSure sn sonra tahmin edilen siper noktalarindan birine <= 8 m mi? (taban: oldugu yerde <= 8 m)
                    if (_sk isNotEqualTo []) then {
                        private _mnD = 1e9;
                        { _mnD = _mnD min (_ac distance2D _x); } forEach _sk;
                        ["pr_kumeN", 1] call _ekle;
                        _acc set ["pr_ongoruSure", _sure];
                        if (_mnD <= 8) then { ["pr_kumeIsabet", 1] call _ekle; };
                        if (_hrk <= 8) then { ["pr_kumeKaldi", 1] call _ekle; };
                    };
                    private _dB = abs ((((_up0 getDir _ac) - (_up0 getDir _ep0)) + 540) mod 360 - 180);
                    if (_dB >= 12) then { ["pr_kay12", 1] call _ekle; };
                    if (_dB >= 25) then { ["pr_kay25", 1] call _ekle; };
                };
            };
            // 2) acik orani ornekleri: 2 / 4 / 6 / 8 / 10. sn
            private _ni = _st select 3;
            if (_ni < 5 && {_age >= (2 + (2 * _ni))}) then {
                _st set [3, _ni + 1];
                // STABILITE (v8.733): yol uzunlugu (ornekler arasi yer degistirme toplami)
                if (alive _u) then { _st set [4, (_st select 4) + (((getPosASL _u) distance2D (_st select 5)))]; _st set [5, getPosASL _u]; };
                if (alive _u && {!isNull _en} && {alive _en} && {((getPosATL _u) distance2D _cp) < 3}) then {
                    private _pa = (AGLToASL [_cp select 0, _cp select 1, 0]) vectorAdd [0, 0, 1.0];
                    private _ge = eyePos _en;
                    private _acik = ((lineIntersectsSurfaces [_ge, _pa, _en, _u, true, 1, "FIRE", "NONE"]) isEqualTo []) && {!(terrainIntersectASL [_ge, _pa])};
                    _st set [2, (_st select 2) + 1];
                    if (_acik) then { _st set [1, (_st select 1) + 1]; };
                };
            };
            // 3) bitis: 12 sn ya da asker oldu
            if (_age >= 12 || {!alive _u}) then { _bitti = true; };
            if (_bitti) then {
                private _g = (["T", "K"] select _kon) + (["0", "1"] select (_ham > 0));
                private _hasar = (!alive _u) || {((damage _u) - _d0) >= 0.05};
                [_g + "_n", 1] call _ekle;
                [_g + "_acik", _st select 1] call _ekle;
                [_g + "_ornek", _st select 2] call _ekle;
                [_g + "_yol", _st select 4] call _ekle;
                private _ah = _u getVariable [QGVAR(acikSiperHedef), []];
                if (_ah isNotEqualTo [] && {(_ah select 1) > (_t0 + 0.5)}) then { [_g + "_tekrar", 1] call _ekle; };
                if (_hasar) then { [_g + "_hasar", 1] call _ekle; };
                if (!alive _u) then { [_g + "_olum", 1] call _ekle; };
            } else {
                _kalan pushBack _x;
            };
        } forEach _list;
        missionNamespace setVariable ["lambs_danger_ogKayit", _kalan];

        if (time > _ozetT) then {
            _ozetT = time + 120;
            private _n = _acc getOrDefault ["pr_n", 0];
            private _toplamKayit = 0;
            { _toplamKayit = _toplamKayit + (_acc getOrDefault [_x + "_n", 0]); } forEach ["K0", "K1", "T0", "T1"];
            if (_toplamKayit > 0 || {_n > 0}) then {
                private _s1N = _acc getOrDefault ["pr_s1N", 0];
                private _grup = {
                    params ["_g"];
                    format ["%1 n=%2 acik=%%%3 (%4/%5) hasar=%%%6", _g, _acc getOrDefault [_g + "_n", 0], [_acc getOrDefault [_g + "_acik", 0], _acc getOrDefault [_g + "_ornek", 0]] call _oran, _acc getOrDefault [_g + "_acik", 0], _acc getOrDefault [_g + "_ornek", 0], [_acc getOrDefault [_g + "_hasar", 0], _acc getOrDefault [_g + "_n", 0]] call _oran]
                };
                // toplamlar: kontrol / tedavi
                private _kN = (_acc getOrDefault ["K0_n", 0]) + (_acc getOrDefault ["K1_n", 0]);
                private _tN = (_acc getOrDefault ["T0_n", 0]) + (_acc getOrDefault ["T1_n", 0]);
                private _kA = (_acc getOrDefault ["K0_acik", 0]) + (_acc getOrDefault ["K1_acik", 0]);
                private _kO = (_acc getOrDefault ["K0_ornek", 0]) + (_acc getOrDefault ["K1_ornek", 0]);
                private _tA = (_acc getOrDefault ["T0_acik", 0]) + (_acc getOrDefault ["T1_acik", 0]);
                private _tO = (_acc getOrDefault ["T0_ornek", 0]) + (_acc getOrDefault ["T1_ornek", 0]);
                private _kAr = if (_kO > 0) then {100 * _kA / _kO} else {-1};
                private _tAr = if (_tO > 0) then {100 * _tA / _tO} else {-1};
                private _k0 = if ((_acc getOrDefault ["K0_ornek", 0]) > 0) then {100 * (_acc getOrDefault ["K0_acik", 0]) / (_acc getOrDefault ["K0_ornek", 0])} else {-1};
                private _k1 = if ((_acc getOrDefault ["K1_ornek", 0]) > 0) then {100 * (_acc getOrDefault ["K1_acik", 0]) / (_acc getOrDefault ["K1_ornek", 0])} else {-1};
                private _guc = if (_k0 >= 0 && {_k1 >= 0}) then { (_k1 - _k0) toFixed 0 } else {"-"};
                private _etki = if (_kAr >= 0 && {_tAr >= 0}) then { (_tAr - _kAr) toFixed 0 } else {"-"};
                private _yeter = ((_acc getOrDefault ["K0_n", 0]) + (_acc getOrDefault ["K1_n", 0])) >= 12 && {_tN >= 12};
                private _hukum = if (!_yeter) then {"VERI AZ (kontrol >= 12 ve tedavi >= 12 kayit gerekir)"} else {
                    if (_kAr < 0 || {_tAr < 0}) then {"VERI AZ"} else {
                        if (_tAr <= (_kAr - 5)) then {"ISE YARIYOR (tedavide daha az acik)"} else {
                            if (_tAr >= (_kAr + 5)) then {"YARAMIYOR (tedavide daha cok acik)"} else {"BELIRSIZ (fark < 5 puan)"}
                        }
                    }
                };
                // STABILITE: yeniden siper secimi % ve ort. yol (kontrol vs tedavi) -> 'ongoru stabilite / smoothluk / zaman kazandiriyor mu'
                private _kYol = (_acc getOrDefault ["K0_yol", 0]) + (_acc getOrDefault ["K1_yol", 0]);
                private _tYol = (_acc getOrDefault ["T0_yol", 0]) + (_acc getOrDefault ["T1_yol", 0]);
                private _kTk = (_acc getOrDefault ["K0_tekrar", 0]) + (_acc getOrDefault ["K1_tekrar", 0]);
                private _tTk = (_acc getOrDefault ["T0_tekrar", 0]) + (_acc getOrDefault ["T1_tekrar", 0]);
                private _kTkR = if (_kN > 0) then {100 * _kTk / _kN} else {-1};
                private _tTkR = if (_tN > 0) then {100 * _tTk / _tN} else {-1};
                private _kYolO = if (_kN > 0) then {_kYol / _kN} else {-1};
                private _tYolO = if (_tN > 0) then {_tYol / _tN} else {-1};
                private _kuN = _acc getOrDefault ["pr_kumeN", 0];
                if (_kuN > 0) then {
                    diag_log format ["[ONGORU-KUME] olasi siper kumesi (3 nokta, dusmanin 15 m'si): olcum %1 | dusman %2 sn sonra tahmin noktalarindan birine <= 8 m: %%%3 | 'oldugu yerde kalir' tabani (<= 8 m): %%%4 | not: kume noktalari dusmanin 15 m'sinde, bu yuzden durgun dusmanda iki oran birbirine yakin cikar; fark = siper degistiren dusmanin kume tarafindan yakalanmasi", _kuN, _acc getOrDefault ["pr_ongoruSure", 0], [_acc getOrDefault ["pr_kumeIsabet", 0], _kuN] call _oran, [_acc getOrDefault ["pr_kumeKaldi", 0], _kuN] call _oran];
                };
                diag_log format ["[ONGORU-STABILITE] kontrol n=%1: 12 sn'de yeniden siper secimi %%%2, ort. yol %3 m | tedavi n=%4: yeniden secim %%%5, ort. yol %6 m | FARK (tedavi - kontrol; negatif = ongoru daha stabil / az hareket): yeniden secim %7 puan, yol %8 m%9",
                    _kN, if (_kTkR >= 0) then {_kTkR toFixed 0} else {"-"}, if (_kYolO >= 0) then {_kYolO toFixed 1} else {"-"}, _tN, if (_tTkR >= 0) then {_tTkR toFixed 0} else {"-"}, if (_tYolO >= 0) then {_tYolO toFixed 1} else {"-"},
                    if (_kTkR >= 0 && {_tTkR >= 0}) then {(_tTkR - _kTkR) toFixed 0} else {"-"}, if (_kYolO >= 0 && {_tYolO >= 0}) then {(_tYolO - _kYolO) toFixed 1} else {"-"}, if (_yeter) then {""} else {" | VERI AZ"}];
                diag_log format ["[ONGORU-OLCUM] TAHMIN: olcum %1 | ileri senaryolu %2: ort hata %3 m vs 'yerinde kalir' tabani %4 m (ileri daha iyi %%%5) | dusman ort. hareket %6 m | yanal kayma >=12 derece %%%7, >=25 derece %%%8 || SONUC: %9 | %10 | %11 | %12 || TAHMIN GUCU (kontrolde ham>0 acik - ham=0 acik) %13 puan | TEDAVI ETKISI (tedavi - kontrol acik) %14 puan || HUKUM: %15",
                    _n, _s1N, ((_acc getOrDefault ["pr_errS1", 0]) / (_s1N max 1)) toFixed 1, ((_acc getOrDefault ["pr_errTaban", 0]) / (_s1N max 1)) toFixed 1, [_acc getOrDefault ["pr_s1Iyi", 0], _s1N] call _oran, ((_acc getOrDefault ["pr_hareket", 0]) / (_n max 1)) toFixed 1,
                    [_acc getOrDefault ["pr_kay12", 0], _n] call _oran, [_acc getOrDefault ["pr_kay25", 0], _n] call _oran,
                    ["K0"] call _grup, ["K1"] call _grup, ["T0"] call _grup, ["T1"] call _grup, _guc, _etki, _hukum];
            };
        };
    };
};
true
