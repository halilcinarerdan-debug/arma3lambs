#include "script_component.hpp"
/*
 * Author: Cinar (ELITE fork)
 * FORMASYON YAZMA HAKEMI (v8.80) — grubun formasyonunu yalnizca BU fonksiyon degistirir (fork icindeki tum setFormation cagrilari buradan gecer).
 *
 * NEDEN: RPT f8015d87: "form line loopu 3-4 sn" (Alpha 1-5: STAG COLUMN -> LINE -> STAG COLUMN -> LINE, 5 sn aralikla, karar BOUNDING). Birden cok sistem (bounding, komutan formasyonu, contact, hucum / bastirma / saklanma / kanat taktikleri)
 * bagimsiz formasyon yaziyor; her setFormation askerleri yeni slota kosturur (ates kesilir, "arada kalma"). Tek tek hakemler (taktikFormT, 90 sn histerezis) bir kismini yakaladi ama kaynagi bilinmeyen yazarlar kaldi.
 * KURAL: ayni formasyon ise bir sey yapma; son YAZMADAN `bekle` sn (varsayilan 12) gecmedi ve yeni yazarin ONCELIGI son yazardan YUKSEK DEGIL ise yazma (atla).
 *   Oncelik: 0 sakin / bounding / komutan / contact | 1 hucum - bastirma - saklanma - kanat - garnizon taktikleri | 2 geri cekilme / peel / sniper (her zaman yazar)
 * Log: [FORM-SET] (ilk 120 uygulanan + ilk 80 atlanan) -> kaynak teshisi icin: hangi sistem kac sn arayla yaziyor / hangisi atlandi.   Kapatma: lambs_danger_formSetOff = true (dogrudan setFormation)
 *
 * Arguments:
 * 0: Grup <GROUP> veya birim <OBJECT>
 * 1: Formasyon <STRING>
 * 2: Kaynak etiketi <STRING>
 * 3: Oncelik 0..2 <NUMBER> (varsayilan 0)
 * 4: Bekleme sn <NUMBER> (varsayilan 12)
 *
 * Return Value: Uygulandi mi <BOOL>
 * Public: No
*/

params [["_g", grpNull, [grpNull, objNull]], ["_f", "", [""]], ["_kaynak", "?", [""]], ["_oncelik", 0, [0]], ["_bekle", 12, [0]]];
if (_g isEqualType objNull) then { _g = group _g; };
if (isNull _g || {_f isEqualTo ""}) exitWith {false};

private _simdi = formation _g;
if (_simdi isEqualTo _f) exitWith {false};

if (missionNamespace getVariable ["lambs_danger_formSetOff", false]) exitWith { _g setFormation _f; true };

private _sonT = _g getVariable [QGVAR(fsT), -999];
private _sonO = _g getVariable [QGVAR(fsO), 0];
private _sonK = _g getVariable [QGVAR(fsK), "-"];
if (isNil "lambs_danger_fsLogA") then { lambs_danger_fsLogA = 0; lambs_danger_fsLogS = 0; };

if ((time - _sonT) < _bekle && {_oncelik <= _sonO}) exitWith {
    if (lambs_danger_fsLogS < 80 && {!(_kaynak in ["bounding-zorla", "bounding-koru"])}) then {   // 0.5 sn dongusu: atlama logu spam (RPT f3b1b53f: 50+ satir)
        lambs_danger_fsLogS = lambs_danger_fsLogS + 1;
        diag_log format ["[FORM-SET] %1 | ATLANDI %2 -> %3 | kaynak:%4 (oncelik %5) | son yazan:%6 (oncelik %7) %8 sn once", groupId _g, _simdi, _f, _kaynak, _oncelik, _sonK, _sonO, round (time - _sonT)];
    };
    false
};

_g setFormation _f;
_g setVariable [QGVAR(fsT), time];
_g setVariable [QGVAR(fsO), _oncelik];
_g setVariable [QGVAR(fsK), _kaynak];
if (lambs_danger_fsLogA < 120) then {
    lambs_danger_fsLogA = lambs_danger_fsLogA + 1;
    diag_log format ["[FORM-SET] %1 | %2 -> %3 | kaynak:%4 (oncelik %5) | onceki yazan:%6 %7 sn once", groupId _g, _simdi, _f, _kaynak, _oncelik, _sonK, round (time - _sonT)];
};
true
