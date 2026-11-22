#include "script_component.hpp"
/*
 * Author: Cinar (ELITE fork)
 * PROFILE GORE CBA DEGERI (v8.738; kullanici: 'cover profili bulunduklari konuma gore dinamik degissin, CBA'dan opsiyonel'): bir CBA ayarinin (lambs_danger_<ad>) TABAN degerini askerin CEVRE PROFILINE (fnc_cevreProfil) gore carpar / ekler.
 * deger = taban + (taban x carpan + ek - taban) x cevreProfilGuc (0-1; 1 = tam profil, 0 = statik / eski). Profil KARISIK ya da cevreProfil = 0 ise taban aynen doner. Sonuc [0, ust sinir] icinde.
 * PROFIL TABLOSU (carpan, ek): taban = kullanicinin CBA degeri (kullanici ayari 'merkez'; profil ondan SAPAR).
 *   ORMAN   (ince agaclar, kisa goruş, yakin temas): siperYaricap x0.7, siperGercekCezaM x0.4 (agaclar yumusak / VIEW'siz olabilir: tamamen reddetme), siperYanAgirlik x1.5 (yan ani cikis), rotaRiskAgirlik x0.5 / ongoruAgirlik x0.5 (kisa hat),
 *             siperOnTaramaM x0.6, siperYakinM x0.8, siperDusuk -1 (yaprakli yerde cok yatma yok), uzakHucumM x1.0
 *   KENTSEL (duvar / bina, CQB): siperYaricap x0.6, siperGercekCezaM x1.3 (duvar sert: sahteyi reddet), siperYanAgirlik x1.5 (kose / aralik), rotaRiskAgirlik x1.2, siperYakinM x1.2, siperYakinKosuM x0.8, siperOnTaramaM x0.6, siperDusuk -1 (sokakta yatma yok), uzakHucumM x0.6
 *   ACIK    (nesnesiz arazi): siperYaricap x1.8 (uzak siper ara), siperGercekCezaM x0.3 (nadir nesne: gizlenme / arazi kivrimi serbest), siperYanAgirlik x0.7, rotaRiskAgirlik x2.0 (uzun hat), ongoruAgirlik x1.5, siperOnTaramaM x2.0, siperYakinKosuM x1.6, uzakHucumM x0.8
 *
 * Arguments:
 * 0: Asker <OBJECT> (lider olabilir; grup kararlari icin)
 * 1: CBA ayari adi (lambs_danger_ oneksiz) <STRING>
 * 2: Varsayilan (CBA yoksa) <NUMBER>
 *
 * Return Value: Profile gore deger <NUMBER>
 * Public: No
*/

params [["_u", objNull, [objNull]], ["_ad", "", [""]], ["_def", 0, [0]]];
private _baz = missionNamespace getVariable ["lambs_danger_" + _ad, _def];
if !(_baz isEqualType 0) exitWith {_baz};
if (isNull _u || {(missionNamespace getVariable ["lambs_danger_cevreProfil", 1]) isEqualTo 0}) exitWith {_baz};
private _pr = [_u] call FUNC(cevreProfil);
if (_pr isEqualTo "KARISIK") exitWith {_baz};
private _tab = missionNamespace getVariable ["lambs_danger_profilTablo", createHashMap];
if ((count _tab) isEqualTo 0) then {
    _tab = createHashMapFromArray [
        ["ORMAN|siperYaricap", [0.7, 0]], ["ORMAN|siperGercekCezaM", [0.4, 0]], ["ORMAN|siperYanAgirlik", [1.5, 0]], ["ORMAN|rotaRiskAgirlik", [0.5, 0]], ["ORMAN|ongoruAgirlik", [0.5, 0]], ["ORMAN|siperOnTaramaM", [0.6, 0]], ["ORMAN|siperYakinM", [0.8, 0]], ["ORMAN|siperDusuk", [1, -1]],
        ["KENTSEL|siperYaricap", [0.6, 0]], ["KENTSEL|siperGercekCezaM", [1.3, 0]], ["KENTSEL|siperYanAgirlik", [1.5, 0]], ["KENTSEL|rotaRiskAgirlik", [1.2, 0]], ["KENTSEL|siperYakinM", [1.2, 0]], ["KENTSEL|siperYakinKosuM", [0.8, 0]], ["KENTSEL|siperOnTaramaM", [0.6, 0]], ["KENTSEL|siperDusuk", [1, -1]], ["KENTSEL|uzakHucumM", [0.6, 0]],
        ["ACIK|siperYaricap", [1.8, 0]], ["ACIK|siperGercekCezaM", [0.3, 0]], ["ACIK|siperYanAgirlik", [0.7, 0]], ["ACIK|rotaRiskAgirlik", [2.0, 0]], ["ACIK|ongoruAgirlik", [1.5, 0]], ["ACIK|siperOnTaramaM", [2.0, 0]], ["ACIK|siperYakinKosuM", [1.6, 0]], ["ACIK|uzakHucumM", [0.8, 0]]
    ];
    missionNamespace setVariable ["lambs_danger_profilTablo", _tab];
};
private _e = _tab getOrDefault [_pr + "|" + _ad, []];
if (_e isEqualTo []) exitWith {_baz};
private _guc = ((missionNamespace getVariable ["lambs_danger_cevreProfilGuc", 1]) max 0) min 1;
private _hedef = (_baz * (_e select 0)) + (_e select 1);
(((_baz + ((_hedef - _baz) * _guc)) max 0) min 400)
