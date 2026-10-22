#include "script_component.hpp"
/*
 * Author: Cinar (ELITE fork)
 * PERFORMANS BISECT (v8.304; kullanici: 'bot yokken sunucu 32 FPS, mod cikarinca rahatliyor'). Hangi mod dongusu FPS yiyor? Otomatik ikili arama.
 * KULLANIM (SUNUCU debug konsolu, 'Server exec'): [] spawn lambs_danger_fnc_perfBisect;      (~3-5 dk; bos harita / az bot onerilir)
 *   1) taban FPS (10 sn ortalama)   2) TUM lambs_danger_*Off anahtarlari acik -> FPS   3) kazanc >= 2 FPS ise anahtarlar ikiye bolunerek suclu bulunur
 *   Sonuc: RPT '[PERF-BISECT]' satirlari; anahtarlar sonunda sifirlanir. Gorev sirasinda KULLANMA (planlar / tasima gecici kapanir).
 *   Kazanc yoksa: surec mod anahtarlarindan degil (flagsiz dongu: moveAssist anahtari dahil / ortam / gorev betigi).
 *
 * Return Value: Baslatildi mi <BOOL>
 * Public: No
*/

if (!isServer) exitWith {false};
if (!isNil "lambs_danger_perfBisectCalisiyor") exitWith {false};
lambs_danger_perfBisectCalisiyor = true;
[] spawn {
    private _tum = ["lambs_danger_adimSesOff", "lambs_danger_agacGizlenOff", "lambs_danger_aracAtTepkiOff", "lambs_danger_aracDumanOff", "lambs_danger_aracMedevacOff", "lambs_danger_aracSenkronOff", "lambs_danger_aracUzakMurOff", "lambs_danger_aracUzakOff", "lambs_danger_aracZirhKacOff", "lambs_danger_arkaDestekOff", "lambs_danger_atPaylasOff", "lambs_danger_baskiTufekciOff", "lambs_danger_bayginPatlayiciOff", "lambs_danger_buildingClearOff", "lambs_danger_cephanePaylasOff", "lambs_danger_coverHugOff", "lambs_danger_crewImmobileOff", "lambs_danger_dronSaklaOff", "lambs_danger_dronTepkiOff", "lambs_danger_dronZorlaOff", "lambs_danger_durumLogOff", "lambs_danger_ezmeOff", "lambs_danger_ffvDuzeltOff", "lambs_danger_fieldCraftOff", "lambs_danger_fireSupportOff", "lambs_danger_formSetOff", "lambs_danger_fragoOff", "lambs_danger_garnizonOff", "lambs_danger_gercekHedefOff", "lambs_danger_giyimTaniOff", "lambs_danger_gizliAlgiOff", "lambs_danger_gozcuOff", "lambs_danger_haltOff", "lambs_danger_havaFarkOff", "lambs_danger_hazirlikOff", "lambs_danger_hendekBilincOff", "lambs_danger_hendekEkOff", "lambs_danger_hendekOncelikOff", "lambs_danger_hqPlanOtomatikOff", "lambs_danger_hqSisOff", "lambs_danger_iedOff", "lambs_danger_iedZarOff", "lambs_danger_ihaBekleOff", "lambs_danger_ihaGozlemOff", "lambs_danger_ihaSortiOff", "lambs_danger_isikAlgiOff", "lambs_danger_karakolMevziOff", "lambs_danger_karakolOff", "lambs_danger_kayipDonusOff", "lambs_danger_komutanPlanOff", "lambs_danger_liderDevriOff", "lambs_danger_mekanizeDuzeltOff", "lambs_danger_mekanizeOff", "lambs_danger_mermiDisiplinOff", "lambs_danger_mevziKilitOff", "lambs_danger_mevziStatikOff", "lambs_danger_mevziTutOff", "lambs_danger_motorSesOff", "lambs_danger_moveAssistOff", "lambs_danger_murKoruOff", "lambs_danger_nakilTehditGenisOff", "lambs_danger_nakilZincirOff", "lambs_danger_noktaOff", "lambs_danger_olumBOff", "lambs_danger_optikSkillOff", "lambs_danger_oranKapisiOff", "lambs_danger_panikOff", "lambs_danger_planOtoTankOff", "lambs_danger_pusuKarsiOff", "lambs_danger_reconYolZinciriOff", "lambs_danger_rpgReactionOff", "lambs_danger_saglikOff", "lambs_danger_savunmaKomutanOff", "lambs_danger_savunmaTopcuOff", "lambs_danger_savunmaUzatmaOff", "lambs_danger_seferGuvenliOff", "lambs_danger_senkTavanOff", "lambs_danger_seyirFormOff", "lambs_danger_silahDegisimOff", "lambs_danger_sinsiGeriOff", "lambs_danger_sniperTeamOff", "lambs_danger_sunucuDevirOff", "lambs_danger_surmeDeneyOff", "lambs_danger_surucuYenileOff", "lambs_danger_taksiOff", "lambs_danger_taniOff", "lambs_danger_tankAtesOff", "lambs_danger_tankBakisOff", "lambs_danger_tankDronOff", "lambs_danger_tankDuelloOff", "lambs_danger_tankHedefDagitOff", "lambs_danger_tankIzleOff", "lambs_danger_tankKilitOff", "lambs_danger_tankKoruOff", "lambs_danger_tankMevziOff", "lambs_danger_tankMurettebatOff", "lambs_danger_tankSicramaOff", "lambs_danger_tankUlasOff", "lambs_danger_tankYerOff", "lambs_danger_tankZorlaOff", "lambs_danger_tasimaOff", "lambs_danger_tasimaOncelikOff", "lambs_danger_tehditBakisOff", "lambs_danger_tehditOlayOff", "lambs_danger_tehlikeAlaniOff", "lambs_danger_topErkenKacisOff", "lambs_danger_topSiperOff", "lambs_danger_topcuDevirOff", "lambs_danger_topcuHazirlaOff", "lambs_danger_yanGuvenlikOff", "lambs_danger_yetimOff", "lambs_danger_zihinOff", "lambs_danger_zirhSurucuOnarOff"];
    private _olc = {
        private _bit = time + 10;
        private _s = 0;
        private _n = 0;
        while {time < _bit} do { _s = _s + diag_fps; _n = _n + 1; sleep 0.5; };
        _s / (_n max 1)
    };
    private _ara = {
        params ["_liste", "_taban"];
        if ((count _liste) <= 1) exitWith { diag_log format ["[PERF-BISECT] SUCLU ADAY: %1", _liste]; };
        private _yarim = floor ((count _liste) / 2);
        private _a = _liste select [0, _yarim];
        private _b = _liste select [_yarim];
        { missionNamespace setVariable [_x, true]; } forEach _a;
        sleep 3;
        private _f = call _olc;
        { missionNamespace setVariable [_x, nil]; } forEach _a;
        diag_log format ["[PERF-BISECT] %1 anahtar kapali -> fps %2 (taban %3)", count _a, _f toFixed 1, _taban toFixed 1];
        if ((_f - _taban) >= 2) then { [_a, _taban] call _ara } else { [_b, _taban] call _ara };
    };
    diag_log format ["[PERF-BISECT] basladi: %1 anahtar | AI: %2 asker", count _tum, count allUnits];
    sleep 3;
    private _taban = call _olc;
    diag_log format ["[PERF-BISECT] taban fps %1", _taban toFixed 1];
    { missionNamespace setVariable [_x, true]; } forEach _tum;
    sleep 5;
    private _hepsi = call _olc;
    { missionNamespace setVariable [_x, nil]; } forEach _tum;
    diag_log format ["[PERF-BISECT] TUM anahtarlar kapali -> fps %1 (kazanc %2)", _hepsi toFixed 1, (_hepsi - _taban) toFixed 1];
    if ((_hepsi - _taban) >= 2) then {
        [_tum, _taban] call _ara;
    } else {
        diag_log "[PERF-BISECT] anahtarlar FPS kazandirmadi: maliyet bu anahtarli dongulerde degil (flagsiz dongu / moveAssist / gorev betigi / ortam). Modu tamamen kapatip ayni olcumu karsilastir.";
    };
    diag_log "[PERF-BISECT] bitti";
    lambs_danger_perfBisectCalisiyor = nil;
};
true
