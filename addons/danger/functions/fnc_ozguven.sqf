#include "script_component.hpp"
/*
 * Author: Cinar (ELITE fork)
 * OZGUVEN + BASKI-COURAGE BAGI (v8.368; kullanici: 'botlarin daha elit olmasi lazim, opsiyonel; ozguvenlerini arttir ama siper almalari azalmasin; kullandigim modlarda oyuncular da suppress ediliyor, baski altinda
 *   weapon sway artiyor, courage onemli ve sistemle iliskili olsun').
 *
 * 1) OZGUVEN (CBA lambs_danger_ozguven 0..1, varsayilan 0.5): askerin KENDI courage becerisi (misyon / Zeus / zorluk ne verdiyse = taban, ilk dokunusta bir kez okunur) hedefe yaklastirilir:
 *      courage = taban + (1 - taban) x ozguven x 0.6        (yalniz ARTAR, hicbir zaman dusurmez; ozguven 0 = degisiklik yok)
 *    courage'in sistemdeki yeri (hepsi mevcut): panik / felc sansi x (1.3 - courage) [fnc_panikFelc]; motor kacma (allowFleeing); lider devri puani; bu modulun baski etkisi (asagida).
 *    SIPER ALMA AZALMAZ: bu modul siper / hareket kararina dokunmaz; yalniz panik-felc ihtimalini ve baski altindaki nisan bozulmasini yumusatir.
 * 2) BASKI -> NISAN BOZULMASI (CBA lambs_danger_baskiEtki 0..1, varsayilan 0.5; oyuncudaki 'suppression sway' esdegeri): getSuppression (0..1, ustu kirpilir) yuksekse
 *      ceza = baskiEtki x baski x (1 - 0.6 x courage)          courage 0.9 + baski 1.0 + etki 0.5 -> 0.23 | courage 0.3 -> 0.41
 *      aimingShake  = taban x (1 - ceza)      aimingSpeed = taban x (1 - 0.5 x ceza)         (aimingAccuracy'ye DOKUNULMAZ: fnc_ortamSkill ile cakismasin)
 *    Taban: baski yokken okunan deger; baska bir sistem / Zeus beceriyi degistirirse (yazdigimizdan farkli) taban yeniden ogrenilir. Baski bitince taban geri yazilir.
 * LAMBS SUPPRESSION (v8.369): yuklu ise baskiEtki x lambs_danger_baskiLambsCarpan (0.4) - cift sayim olmasin.
 * Her 1.5 sn'de en fazla 40 yerel, oyuncusuz, yaya AI (donusumlu). Kapatma: CBA 'ELITE siper' > Ozguven + baski (lambs_danger_ozguvenAktif). Log: [OZGUVEN] (ilk 30 degisim) + 90 sn ozeti.
 *
 * Arguments: None
 * Return Value: Baslatildi mi <BOOL>
 * Public: No
*/

if (!isNil "lambs_danger_ozguvenStarted") exitWith {false};
lambs_danger_ozguvenStarted = true;

diag_log "[OZGUVEN] ozguven + baski->nisan bozulmasi (courage bagli) baslatildi (v8.368)";

[] spawn {
    // v8.369: LAMBS Suppression YUKLUYSE motor zaten baskiyi nisan hatasina cevirir (CfgBrains: bastirma azalma 25 sn beceri0 -> 4 sn beceri1; nisan oturma 3.5 -> 0.6 sn) -> kendi cezamiz CIFT SAYILMASIN diye carpanla kisilir
    private _lSup = isClass (configFile >> "CfgPatches" >> "lambs_suppression");
    private _indeks = 0;
    private _logN = 0;
    private _ozetT = time + 90;
    private _say = createHashMapFromArray [["courage", 0], ["cezali", 0], ["toplamCeza", 0]];
    while {true} do {
        sleep 1.5;
        if (time > _ozetT) then {
            _ozetT = time + 90;
            if ((_say get "courage") + (_say get "cezali") > 0) then {
                diag_log format ["[OZGUVEN-OZET] 90 sn: courage yukseltilen %1 | baski cezasi uygulanan tur %2 (ort ceza %3)", _say get "courage", _say get "cezali", ((_say get "toplamCeza") / ((_say get "cezali") max 1)) toFixed 2];
            };
            { _say set [_x, 0]; } forEach (keys _say);
        };
        if (!(missionNamespace getVariable ["lambs_danger_ozguvenAktif", true])) then { continue };
        private _ozg = (missionNamespace getVariable ["lambs_danger_ozguven", 0.5]) max 0 min 1;
        private _etki = (missionNamespace getVariable ["lambs_danger_baskiEtki", 0.5]) max 0 min 1;
        if (_lSup) then { _etki = _etki * ((missionNamespace getVariable ["lambs_danger_baskiLambsCarpan", 0.4]) max 0 min 1); };
        private _adaylar = allUnits select {local _x && {alive _x} && {!isPlayer _x} && {isNull objectParent _x} && {(side group _x) in [west, east, independent]}};
        private _n = count _adaylar;
        if (_n isEqualTo 0) then { continue };
        if (_indeks >= _n) then { _indeks = 0; };
        private _son = (_indeks + 40) min _n;
        for "_i" from _indeks to (_son - 1) do {
            private _u = _adaylar select _i;

            // ---- 1) courage ----
            private _cYaz = _u getVariable [QGVAR(ozgCYaz), -1];
            private _cNow = _u skill "courage";
            if (_cYaz < 0 || {abs (_cNow - _cYaz) > 0.01}) then {
                _u setVariable [QGVAR(ozgCTaban), _cNow];       // ilk dokunus ya da baska sistem degistirdi: taban yeniden
            };
            private _cTaban = _u getVariable [QGVAR(ozgCTaban), _cNow];
            private _cHedef = _cTaban + ((1 - _cTaban) * _ozg * 0.6);
            if (abs (_cHedef - _cNow) > 0.02) then {
                _u setSkill ["courage", _cHedef];
                _u setVariable [QGVAR(ozgCYaz), _u skill "courage"];
                _say set ["courage", (_say get "courage") + 1];
                if (_logN < 30) then {
                    _logN = _logN + 1;
                    diag_log format ["[OZGUVEN] %1 (%2) | courage %3 -> %4 (taban %5, ozguven %6)", name _u, groupId (group _u), _cNow toFixed 2, (_u skill "courage") toFixed 2, _cTaban toFixed 2, _ozg toFixed 2];
                };
            } else {
                _u setVariable [QGVAR(ozgCYaz), _cNow];
            };

            // ---- 2) baski -> nisan ----
            private _baski = ((getSuppression _u) max 0) min 1;
            private _cour = _u skill "courage";
            private _ceza = _etki * _baski * (1 - (0.6 * _cour));
            private _eskiCeza = _u getVariable [QGVAR(ozgCeza), 0];
            if (abs (_ceza - _eskiCeza) >= 0.03 || {_ceza < 0.01 && {_eskiCeza > 0}}) then {
                {
                    _x params ["_b", "_agirlik"];
                    private _yaz = _u getVariable [format ["lambs_danger_ozgYaz_%1", _b], -1];
                    private _simdi = _u skill _b;
                    if (_yaz < 0 || {abs (_simdi - _yaz) > 0.01}) then {
                        _u setVariable [format ["lambs_danger_ozgTaban_%1", _b], _simdi];
                    };
                    private _taban = _u getVariable [format ["lambs_danger_ozgTaban_%1", _b], _simdi];
                    private _yeni = (_taban * (1 - (_ceza * _agirlik))) max 0.05;
                    if (_ceza < 0.01) then { _yeni = _taban; };
                    _u setSkill [_b, _yeni];
                    _u setVariable [format ["lambs_danger_ozgYaz_%1", _b], _u skill _b];
                } forEach [["aimingShake", 1], ["aimingSpeed", 0.5]];
                _u setVariable [QGVAR(ozgCeza), _ceza];
                if (_ceza >= 0.01) then {
                    _say set ["cezali", (_say get "cezali") + 1];
                    _say set ["toplamCeza", (_say get "toplamCeza") + _ceza];
                };
            };
        };
        _indeks = _son;
    };
};

true
