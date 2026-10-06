#include "script_component.hpp"
/*
 * Author: Cinar (ELITE fork)
 * TCCC — TAKTIK SAHA YARALI BAKIMI (ACE Medical / Advanced Combat Medicine (ACM) uyumlu)
 *
 * Yerel AI gruplari icin 3 sn'de bir; grupta yarali (baygin / yarali / kan kaybi) varsa en yakin HEKIM secilir
 * (medic rolu > Medic trait'i > sargi tasiyan tufekli). Evre:
 *
 *   ATES ALTINDA (temas suruyor): sadece BAYGIN yarali, hekim baskida degil (< 0.4) ve en yakin dusman > 50 m ise
 *       yarali dusmandan uzaga, siperli KENARA CEKILIR (ACE drag) + M adimi (kanama).  Aksi halde bekler.
 *   GUVENLI (temas bitti 6 sn+ ya da hic temas yok): once baygin yarali kenara cekilir, sonra tam MARCH:
 *       M  Massive hemorrhage : paketleme / elastik / sahra sargisi tum vucut bolgelerine; kanama suruyorsa turnike (uzuvlar)
 *       A/R Airway / Respiration : ACM'ye ozgu adimlar DEVIR_LOGU'nda yapilacak (kalp durmasinda CPR + epinefrin burada)
 *       C  Circulation : kan hacmi dusukse IV (BloodIV_500 / BloodIV / SalineIV), agri yuksekse morfin
 *       H  Hypothermia : yapilacak
 *
 * ACE API (surum farki icin ozellik tespiti + RPT'ye [TCCC] satiri):
 *   ace_medical_treatment_fnc_treatment [hekim, hasta, bolge, sinif]  -> tedavi (ACM bunu kendi sinif listesiyle ezer)
 *   ace_medical_status_fnc_getBloodLoss, ace_dragging_fnc_startDrag / dropObject
 *   Fonksiyon yoksa: tedavi vanilla "HealSoldier" aksiyonuna duser, cekme atlanir.
 *   Hekimde malzeme yoksa adim atlanir (ACE kendisi de reddeder).
 *
 * Arguments:
 * None
 *
 * Return Value:
 * Baslatildi mi <BOOL>
 *
 * Public: No
*/

if (!isNil "lambs_danger_tcccStarted") exitWith {false};
lambs_danger_tcccStarted = true;

diag_log format [
    "[TCCC] baslatildi | ace_medical:%1 ACM:%2 treatment_fn:%3 drag_fn:%4 bloodloss_fn:%5",
    isClass (configFile >> "CfgPatches" >> "ace_medical"), isClass (configFile >> "CfgPatches" >> "ACM_core"),
    !isNil "ace_medical_treatment_fnc_treatment", !isNil "ace_dragging_fnc_startDrag", !isNil "ace_medical_status_fnc_getBloodLoss"
];

// v8.100: ACE'nin KENDI AI tedavisi (medical_ai) de dahil her yerel tedavi olayini logla (kullanici: 'medic calisti, RPT'de goremiyorsan sorun loglamada')
if (isNil "lambs_danger_tcccAceDinleyici" && {!isNil "CBA_fnc_addEventHandler"}) then {
    lambs_danger_tcccAceDinleyici = true;
    lambs_danger_tcccAceN = 0;
    {
        private _ev = _x;
        [_ev, {
            if (lambs_danger_tcccAceN >= 200) exitWith {};
            private _e = _thisArgs;
            private _hasta = [_this select 0, _this select 1] select (_e isEqualTo "ace_medical_treatment_cprLocal");
            if !(_hasta isEqualType objNull) exitWith {};
            private _yakin = (_hasta nearEntities ["CAManBase", 8]) select {_x isNotEqualTo _hasta && {alive _x} && {!((lifeState _x) in ["INCAPACITATED", "UNCONSCIOUS"])} && {(side (group _x)) isEqualTo (side (group _hasta))}};
            _yakin = [_yakin, [], {_x distance2D _hasta}, "ASCEND"] call BIS_fnc_sortBy;
            private _hk = [objNull, _yakin select 0] select (_yakin isNotEqualTo []);
            lambs_danger_tcccAceN = lambs_danger_tcccAceN + 1;
            diag_log format ["[ACE-TEDAVI] %1 | hasta %2 (%3) | parametre %4 | en yakin bilincli dost: %5 (%6 m)", _e, name _hasta, groupId (group _hasta), (_this select [1, 2]), ["-", name _hk] select (!isNull _hk), ["-", round (_hk distance2D _hasta)] select (!isNull _hk)];
        }, _ev] call CBA_fnc_addEventHandlerArgs;
    } forEach ["ace_medical_treatment_bandageLocal", "ace_medical_treatment_tourniquetLocal", "ace_medical_treatment_medicationLocal", "ace_medical_treatment_ivBagLocal", "ace_medical_treatment_cprLocal"];
};

[] spawn {
    private _rolFn = missionNamespace getVariable ["lambs_danger_fnc_getUnitRole", {"RIFLE"}];

    private _yarali = {
        params ["_u"];
        alive _u && {
            ((lifeState _u) isEqualTo "INCAPACITATED")
            || {_u getVariable ["ACE_isUnconscious", false]}
            || {damage _u > 0.2}
            || {(_u getVariable ["ace_medical_bloodVolume", 6]) < 5.3}
        }
    };
    private _baygin = { params ["_u"]; ((lifeState _u) isEqualTo "INCAPACITATED") || {_u getVariable ["ACE_isUnconscious", false]} };
    private _kanKaybi = {
        params ["_u"];
        if (isNil "ace_medical_status_fnc_getBloodLoss") then {0} else {[_u] call ace_medical_status_fnc_getBloodLoss}
    };
    lambs_danger_tcccMalzeme = createHashMapFromArray [
        ["packingbandage", ["ace_packingbandage"]], ["elasticbandage", ["ace_elasticbandage"]],
        ["fielddressing", ["ace_fielddressing", "firstaidkit"]], ["pressurebandage", ["ace_fielddressing", "ace_elasticbandage"]],
        ["quikclot", ["ace_quikclot"]], ["applytourniquet", ["ace_tourniquet"]],
        ["morphine", ["ace_morphine"]], ["epinephrine", ["ace_epinephrine"]],
        ["bloodiv", ["ace_bloodiv"]], ["bloodiv_500", ["ace_bloodiv_500"]], ["bloodiv_250", ["ace_bloodiv_250"]],
        ["salineiv", ["ace_salineiv"]], ["salineiv_500", ["ace_salineiv_500"]]
    ];
    lambs_danger_tcccMedikOk = {
        params ["_m"];
        alive _m && {!((lifeState _m) in ["INCAPACITATED", "UNCONSCIOUS"])} && {!(_m getVariable ["ACE_isUnconscious", false])}
    };
    lambs_danger_tcccVarMi = {
        params ["_m", "_cls"];
        private _l = lambs_danger_tcccMalzeme getOrDefault [toLower _cls, []];
        _l isEqualTo [] || {((items _m) findIf {(toLower _x) in _l}) > -1}
    };

    // Tek tedavi adimi: true = uygulandi
    // v8.95: AI hekim icin ACE'nin kendi AI yolu (medical_ai healingLogic): ilerleme cubugu / animasyon / log olmayan ace_medical_treatment_fnc_treatment yerine
    //   anim + bekleme + item sil + CBA hedef olayi + aktivite logu (RPT 5d7b3371: kullanici 'animasyon yok, aktivite logunda bir sey yok' dedi)
    private _tx = {
        params ["_m", "_c", "_part", "_cls"];
        if (isNil "lambs_danger_tcccTxN") then { lambs_danger_tcccTxN = 0; };
        if !([_m, _cls] call lambs_danger_tcccVarMi) exitWith {
            if (lambs_danger_tcccTxN < 120) then {
                lambs_danger_tcccTxN = lambs_danger_tcccTxN + 1;
                diag_log format ["[TCCC-TX] %1 -> %2 | %3 %4 | YOK-ESYA | tibbi esyalar: %5", name _m, name _c, _cls, _part, (items _m) select {(toLower _x) find "ace_" == 0 || {(toLower _x) find "firstaid" >= 0}}];
            };
            false
        };
        private _sinif = toLower _cls;
        private _kanOnce = if (isNil "ace_medical_status_fnc_getBloodLoss") then {0} else {[_c] call ace_medical_status_fnc_getBloodLoss};
        private _l = lambs_danger_tcccMalzeme getOrDefault [_sinif, []];
        private _esya = "";
        if (_l isNotEqualTo []) then { private _i = (items _m) findIf {(toLower _x) in _l}; if (_i >= 0) then { _esya = (items _m) select _i; }; };
        private _tip = 0;
        if (_sinif in ["fielddressing", "packingbandage", "elasticbandage", "quikclot"]) then { _tip = 1; };
        if (_sinif isEqualTo "applytourniquet") then { _tip = 2; };
        if (_sinif in ["morphine", "epinephrine"]) then { _tip = 3; };
        if (_tip isEqualTo 0 && {_sinif find "iv" >= 0}) then { _tip = 4; };
        if (_sinif isEqualTo "cpr") then { _tip = 5; };
        // yarasi olmayan bolgeye esya harcama (FirstAidKit dahil)
        private _aw = _c getVariable ["ace_medical_openWounds", createHashMap];
        private _yarasiz = _tip isEqualTo 1 && {_aw isEqualType createHashMap} && {(_aw getOrDefault [toLower _part, []]) isEqualTo []};
        if (_yarasiz) exitWith { false };
        private _sure = [3, 3.5, 4.5, 2.5, 4, 8] select _tip;
        if (_tip isEqualTo 0 || {isNil "CBA_fnc_targetEvent"} || {_tip < 5 && {_esya isEqualTo ""}}) exitWith {
            // eski yol (yedek)
            private _once = count (items _m);
            _m playActionNow "MedicOther";
            if (isNil "ace_medical_treatment_fnc_treatment") then { _m action ["HealSoldier", _c]; } else { [_m, _c, _part, _cls] call ace_medical_treatment_fnc_treatment; };
            sleep 2.5;
            (count (items _m)) < _once || {_cls isEqualTo "CPR"}
        };
        // v8.101: ace_medical_ai_fnc_playTreatmentAnim cagrisi RPT 30f9155e'de 'Type Bool, expected String' hatasiyla hekim betigini oldurdu (hekim 150 sn yaralinin yaninda dondu); ACE surumu imzasi farkli -> kendi animasyon
        _m playActionNow "MedicOther";
        private _t = time + _sure;
        waitUntil { sleep 0.3; time > _t || {!([_m] call lambs_danger_tcccMedikOk)} || {!alive _c} || {(_m distance2D _c) > 6} };
        if (!([_m] call lambs_danger_tcccMedikOk) || {!alive _c} || {(_m distance2D _c) > 6}) exitWith {false};
        if (_esya isNotEqualTo "") then { _m removeItem _esya; };
        private _dogrudan = local _c;
        switch (_tip) do {
            case 1: { if (_dogrudan && {!isNil "ace_medical_treatment_fnc_bandageLocal"}) then { [_c, _part, _cls] call ace_medical_treatment_fnc_bandageLocal; } else { ["ace_medical_treatment_bandageLocal", [_c, _part, _cls], _c] call CBA_fnc_targetEvent; }; };
            case 2: { if (_dogrudan && {!isNil "ace_medical_treatment_fnc_tourniquetLocal"}) then { [_c, _part] call ace_medical_treatment_fnc_tourniquetLocal; } else { ["ace_medical_treatment_tourniquetLocal", [_c, _part], _c] call CBA_fnc_targetEvent; }; };
            case 3: { ["ace_medical_treatment_medicationLocal", [_c, _part, _cls], _c] call CBA_fnc_targetEvent; };
            case 4: { ["ace_medical_treatment_ivBagLocal", [_c, _part, _cls, _m], _c] call CBA_fnc_targetEvent; };
            case 5: { ["ace_medical_treatment_cprLocal", [_m, _c], _c] call CBA_fnc_targetEvent; };
        };
        if (!isNil "ace_medical_treatment_fnc_addToLog") then {
            private _msg = ["", "STR_ACE_Medical_Treatment_Activity_bandagedPatient", "STR_ACE_Medical_Treatment_Activity_appliedTourniquet", "STR_ACE_Medical_Treatment_Activity_usedItem", "STR_ACE_Medical_Treatment_Activity_gaveIV", "STR_ACE_Medical_Treatment_Activity_CPR"] select _tip;
            if (_msg isNotEqualTo "" && {_tip < 5}) then {
                private _arg = [name _m];
                if (_tip isEqualTo 3) then { _arg pushBack _cls; };
                [_c, "activity", _msg, _arg] call ace_medical_treatment_fnc_addToLog;
            };
        };
        if (lambs_danger_tcccTxN < 120) then {
            lambs_danger_tcccTxN = lambs_danger_tcccTxN + 1;
            private _kanSonra = if (isNil "ace_medical_status_fnc_getBloodLoss") then {0} else {[_c] call ace_medical_status_fnc_getBloodLoss};
            diag_log format ["[TCCC-TX] %1 -> %2 | %3 %4 | UYGULANDI (%5) esya:%6 | kanKaybi %7 -> %8 | anim:%9", name _m, name _c, _cls, _part, ["olay", "dogrudan"] select _dogrudan, _esya, _kanOnce toFixed 3, _kanSonra toFixed 3, animationState _m];
        };
        true
    };

    private _birak = {
        params ["_m", "_c"];
        if (!isNil "ace_dragging_fnc_dropObject" && {!isNull _c} && {!isNull (attachedTo _c)}) then {
            [_m, _c] call ace_dragging_fnc_dropObject;
        };
        if (alive _m) then {
            _m setVariable [QGVAR(forceMove), nil];
            _m setVariable [QGVAR(tcccFM), nil];
            _m setVariable [QGVAR(tcccBusy), 0];
            _m setUnitPos "AUTO";
            _m doFollow (leader _m);
        };
        if (!isNull _c) then { _c setVariable [QGVAR(tcccBy), objNull]; _c setVariable [QGVAR(tcccDone), time]; };
    };

    private _tedavi = {
        params ["_g", "_m", "_c", "_baygin", "_birak", "_tx", "_kanKaybi"];
        private _t0 = time;
        _m setVariable [QGVAR(tcccBusy), time + 150];
        _m setVariable [QGVAR(forceMove), true];
        _m setVariable [QGVAR(tcccFM), true];
        _c setVariable [QGVAR(tcccBy), _m];
        private _guvenliFn = { (((_this select 0) getVariable [QGVAR(contact), 0]) < time) };
        diag_log format ["[TCCC] %1 | hekim %2 -> yarali %3 | baygin:%4 | %5", groupId _g, name _m, name _c, [_c] call _baygin, ["ATES ALTINDA", "GUVENLI"] select ([_g] call _guvenliFn)];

        // 1) yaralıya git
        // uzaktan gelen hekim (kumanda medevac): yuruyus suresi mesafeye gore (25 sn sabit uzak yaraliya yetmiyordu)
        private _bitis = time + ((25 max (((_m distance2D _c) / 3) + 8)) min 100);
        _m setUnitPos "UP";
        _m doMove (getPosATL _c);
        private _tazeT = time + 1.5;
        private _durPos = getPosATL _m; private _durT = time; private _durKademe = 0;
        waitUntil {
            sleep 0.7;
            // v8.94: DURGUN tespiti (RPT a331c7eb: hekim 13 m'de 25 sn hic yurumedi) -> 3 sn'de 1 m'den az ilerlediyse kademeli mudahale
            if (([_m] call lambs_danger_tcccMedikOk) && {(_m distance2D _durPos) > 1}) then { _durPos = getPosATL _m; _durT = time; _durKademe = 0; };
            if (([_m] call lambs_danger_tcccMedikOk) && {alive _c} && {time - _durT > 3} && {(_m distance2D _c) > 3} && {_durKademe < 3}) then {
                _durKademe = _durKademe + 1; _durT = time;
                {_m enableAI _x} forEach ["MOVE", "PATH", "ANIM"];
                _m setVariable [QGVAR(forceMove), true];
                _m setVariable [QGVAR(taktikKilit), 0];
                _m forceSpeed -1; _m setSpeedMode "FULL";
                if (_durKademe >= 2) then { doStop _m; _m setUnitPos "UP"; };
                _m doMove (getPosATL _c);
                diag_log format ["[TCCC-DURGUN] %1 | %2 -> %3 | kademe %4 | mesafe %5 m | komut:%6 | durus:%7 | MOVE:%8 PATH:%9 ANIM:%10 | baski %11 | panik:%12", groupId _g, name _m, name _c, _durKademe, round (_m distance2D _c), currentCommand _m, stance _m, _m checkAIFeature "MOVE", _m checkAIFeature "PATH", _m checkAIFeature "ANIM", (getSuppression _m) toFixed 2, _m getVariable [QGVAR(panikEskiDAI), "-"]];
                // v8.95: AI komutu ise yaramiyorsa (RPT 5d7b3371: kademe 1-3 sonrasi da durgun, MOVE/PATH/ANIM acik) hekim kosu animasyonu + hiz vektoruyle yaraliya yurutulur
                if (_durKademe >= 2) then {
                    private _yT = time + 14; private _y0 = _m distance2D _c;
                    _bitis = _bitis + 14;
                    _m setUnitPos "UP";
                    while {([_m] call lambs_danger_tcccMedikOk) && {alive _c} && {(_m distance2D _c) > 2.5} && {time < _yT} && {(getSuppression _m) < 0.9}} do {
                        // v8.103: pürüzsüz yürütme (kullanici: 'minik minik tplene tplene'): her 0.15 sn'de anim yeniden baslatma + dir snap titreme yapiyordu
                        //   -> animasyon yalniz kosu degilse baslatilir, yon yalniz > 20 derece sapmada duzeltilir, hiz vektoru 0.05 sn'de bir (hedef hiz yumusak)
                        private _hDir = _m getDir _c;
                        if ((abs ((((getDir _m) - _hDir) + 540) mod 360 - 180)) > 20) then { _m setDir _hDir; };
                        if (((toLower (animationState _m)) find "run") < 0) then { _m playMoveNow "AmovPercMrunSrasWrflDf"; };
                        private _vm = velocityModelSpace _m;
                        _m setVelocityModelSpace [0, ((_vm select 1) * 0.6) + 1.2, _vm select 2];
                        sleep 0.05;
                    };
                    diag_log format ["[TCCC-DURGUN] %1 | %2 -> %3 | SCRIPT-YURUTME | %4 m -> %5 m | %6 sn", groupId _g, name _m, name _c, round _y0, round (_m distance2D _c), round (14 - (_yT - time))];
                    _durT = time; _durPos = getPosATL _m;
                };
            };
            // v8.93: baska taktik (Group Flank / bounding) hekimin doMove'unu eziyor (RPT a331c7eb: hekim flank takiminda 240 m ileri, 13-117 m'de 'yetisemedi') -> her 1.5 sn'de emri tazele
            if (time > _tazeT && {([_m] call lambs_danger_tcccMedikOk)} && {alive _c}) then { _tazeT = time + 1.5; _m doMove (getPosATL _c); };
            !([_m] call lambs_danger_tcccMedikOk) || {!alive _c} || {(_m distance2D _c) < 3} || {time > _bitis}
            || {!([_g] call _guvenliFn) && {(getSuppression _m) > 0.6}}
        };
        if (!([_m] call lambs_danger_tcccMedikOk) || {!alive _c} || {(_m distance2D _c) >= 5}) exitWith {
            // v8.80 IPTAL NEDENI (RPT f8015d87: 5 hekim atandi, 1 yaraliyi bitirdi; digerleri sessizce birakildi)
            diag_log format ["[TCCC] %1 | %2 -> %3 | IPTAL (yaklasma): %4 | mesafe %5 m | hekim baski %6 | %7 sn", groupId _g, name _m, name _c,
                ([["hekim baski altinda (>0.6) / ates basladi", "sure doldu (yetisemedi)"] select (time > _bitis), "yarali oldu"] select (!alive _c)) + (["", " (hekim de oldu)"] select (!([_m] call lambs_danger_tcccMedikOk))),
                round (_m distance2D _c), (getSuppression _m) toFixed 2, round (time - _t0)];
            [_m, _c] call _birak;
        };

        // 2) baygin ise dusmandan uzaga siperli kenara cek
        if ([_c] call _baygin && {!isNil "ace_dragging_fnc_startDrag"} && {missionNamespace getVariable ["lambs_danger_tcccSurukleAc", false]} && {(missionNamespace getVariable ["lambs_danger_tcccDragBozuk", 0]) < 3}) then {   // v8.85: varsayilan KAPALI (RPT 820408cd: AI surukleme 8/8 takildi + ACE Release yakalayicisi)   // v8.83: AI surukleme 3 kez takilirsa devre disi (RPT c4eedb1d: hepsi 0-1 m)
            private _tp = [];
            private _sit = _g getVariable [QGVAR(cmdSit), []];
            if (_sit isNotEqualTo [] && {(_sit select 7) isEqualType []} && {(_sit select 7) isNotEqualTo [0,0,0]}) then { _tp = _sit select 7; };
            if (_tp isEqualTo []) then {
                private _en = _m findNearestEnemy _m;
                if (!isNull _en) then { _tp = getPosATL _en; };
            };
            private _cp = getPosATL _c;
            private _kac = if (_tp isEqualTo []) then {random 360} else {_tp getDir _cp};
            private _hedef = [];
            private _hS = -9999;
            {
                private _a = _kac + _x;
                {
                    private _p = _cp getPos [_x, _a];
                    if (!surfaceIsWater _p) then {
                        private _s = 6 * (count (nearestTerrainObjects [_p, ["WALL", "BUILDING", "HOUSE", "TREE", "ROCK", "FENCE"], 6, false, true])) min 12;
                        if (_tp isNotEqualTo []) then {
                            _s = _s + 0.05 * (_p distance2D _tp);
                            if (lineIntersects [AGLToASL (_tp vectorAdd [0,0,1.5]), AGLToASL (_p vectorAdd [0,0,0.5])]) then { _s = _s + 15; };
                        };
                        if (_s > _hS) then { _hS = _s; _hedef = _p; };
                    };
                } forEach [10, 15];
            } forEach [0, 35, -35];

            if (_hedef isNotEqualTo []) then {
                _c setVariable ["ace_dragging_ignoreWeightDrag", true, true];   // v8.83: agirlik yavaslatmasini yoksay (AI hekim 0 km/s takiliyordu; ACE degiskeni dogrulanamadi)
                _m setVariable ["ace_dragging_ignoreWeightDrag", true];
                [_m, _c] call ace_dragging_fnc_startDrag;
                // v8.81: Zeus / host ekranina "Release" dusmesi (kullanici): ACE startDrag birimin birincil-aksiyon (DefaultAction) yakalayicisini YEREL istemciye kurar; AI icin bu istemci Zeus / host olabilir.
                //   AI hekim icin bu yakalayici hemen kaldirilir (birakma yine kodla ace_dragging_fnc_dropObject ile yapilir). ACE ic degiskenleri dogrulanamadi: ilk 6 sefer degisken adlari loglanir.
                if (!isNil "ace_common_fnc_removeActionEventHandler") then {
                    private _rid = _m getVariable ["ace_dragging_ReleaseActionID", -1];
                    if (_rid isEqualType 0 && {_rid >= 0}) then {
                        [_m, "DefaultAction", _rid] call ace_common_fnc_removeActionEventHandler;
                        _m setVariable ["ace_dragging_ReleaseActionID", -1];
                    };
                };
                if (isNil "lambs_danger_tcccAceLogN") then { lambs_danger_tcccAceLogN = 0; };
                if (lambs_danger_tcccAceLogN < 6) then {
                    lambs_danger_tcccAceLogN = lambs_danger_tcccAceLogN + 1;
                    diag_log format ["[TCCC] %1 | %2 | ACE surukleme degiskenleri: %3 | removeActionEventHandler:%4", groupId _g, name _m, (allVariables _m) select {(toLower _x) find "drag" >= 0 || {(toLower _x) find "carry" >= 0}}, !isNil "ace_common_fnc_removeActionEventHandler"];
                };
                _m doMove _hedef;
                private _b2 = time + 22;
                // v8.80 SURUKLEME IZLEME (RPT f8015d87: 'yaraliyi 1-3 m kenara cekti' - hedef 10-15 m; suruklemeye girip durdu): 5 sn'de bir konum / hiz / komut logu; 8 sn'de < 1.5 m ilerlediyse TAKILDI
                private _dp0 = getPosATL _m;
                private _dT = time;
                private _dLog = time + 5;
                private _takildi = false;
                waitUntil {
                    sleep 0.7;
                    if (time > _dLog) then {
                        _dLog = time + 5;
                        diag_log format ["[TCCC] %1 | %2 suruklerken | hedefe %3 m | hiz %4 km/s | komut %5 | anim %6 | baski %7 | ilerleme %8 m", groupId _g, name _m, round (_m distance2D _hedef), round (speed _m), currentCommand _m, animationState _m, (getSuppression _m) toFixed 2, round (_m distance2D _dp0)];
                    };
                    if ((time - _dT) > 8 && {(_m distance2D _dp0) < 1.5}) then { _takildi = true; };
                    !([_m] call lambs_danger_tcccMedikOk) || {!alive _c} || {(_m distance2D _hedef) < 3} || {time > _b2} || {_takildi}
                };
                if (_takildi) then {
                    diag_log format ["[TCCC] %1 | %2 | SURUKLEME TAKILDI (8 sn'de < 1.5 m): yerinde tedavi | AI PATH:%3 MOVE:%4 ANIM:%5", groupId _g, name _m, _m checkAIFeature "PATH", _m checkAIFeature "MOVE", _m checkAIFeature "ANIM"];
                    _m enableAI "PATH"; _m enableAI "MOVE"; _m enableAI "ANIM";
                    missionNamespace setVariable ["lambs_danger_tcccDragBozuk", (missionNamespace getVariable ["lambs_danger_tcccDragBozuk", 0]) + 1];
                    if ((missionNamespace getVariable ["lambs_danger_tcccDragBozuk", 0]) isEqualTo 3) then {
                        diag_log "[TCCC] AI SURUKLEME DEVRE DISI: 3 takilma (hekim anim surukleme, hiz 0). Yaralilar yerinde tedavi edilir; ACE 'Release' yakalayicisi artik cikmaz.";
                    };
                };
                if (!isNull (attachedTo _c)) then { [_m, _c] call ace_dragging_fnc_dropObject; };
                diag_log format ["[TCCC] %1 | %2 yaraliyi %3 m kenara cekti", groupId _g, name _m, round ((getPosATL _c) distance2D _cp)];
            };
        };
        if (!([_m] call lambs_danger_tcccMedikOk) || {!alive _c}) exitWith { [_m, _c] call _birak; };

        // 3) M — kanama: sarma / paketleme / elastik; durmazsa turnike
        private _guvenli = [_g] call _guvenliFn;
        private _parcalar = ["Body", "LeftLeg", "RightLeg", "LeftArm", "RightArm"];
        private _tur = 0;
        while {([_m] call lambs_danger_tcccMedikOk) && {alive _c} && {([_c] call _kanKaybi) > 0.001} && {_tur < 3} && {time < (_t0 + 140)}} do {
            if (_tur >= 1) then {
                { [_m, _c, _x, "ApplyTourniquet"] call _tx; } forEach ["LeftLeg", "RightLeg", "LeftArm", "RightArm"];
            } else {
                {
                    private _p = _x;
                    private _ok = false;
                    {
                        if (!_ok) then { _ok = [_m, _c, _p, _x] call _tx; };
                    } forEach ["PackingBandage", "ElasticBandage", "FieldDressing"];
                } forEach _parcalar;
            };
            _tur = _tur + 1;
            if (!_guvenli) then { break };
        };

        // ates altinda sadece M; ilerisi guvenli olunca
        if ([_g] call _guvenliFn) then {
            // A/R: kalp durmasi -> CPR + epinefrin (ACM'ye ozgu hava yolu / pnomotoraks yapilacak)
            if (_c getVariable ["ace_medical_inCardiacArrest", false]) then {
                for "_i" from 1 to 5 do {
                    if (([_m] call lambs_danger_tcccMedikOk) && {alive _c} && {_c getVariable ["ace_medical_inCardiacArrest", false]}) then { [_m, _c, "Body", "CPR"] call _tx; };
                };
                if (_c getVariable ["ace_medical_inCardiacArrest", false]) then { [_m, _c, "Body", "Epinephrine"] call _tx; };
            };
            // C: kan hacmi / agri
            private _iv = 0;
            while {([_m] call lambs_danger_tcccMedikOk) && {alive _c} && {(_c getVariable ["ace_medical_bloodVolume", 6]) < 5.2} && {_iv < 2}} do {
                private _ok = false;
                { if (!_ok) then { _ok = [_m, _c, "LeftArm", _x] call _tx; }; } forEach ["BloodIV_500", "BloodIV", "SalineIV_500", "SalineIV"];
                _iv = _iv + 1;
                if (!_ok) then { break };
            };
            if ((_c getVariable ["ace_medical_pain", 0]) > 0.35) then { [_m, _c, "Body", "Morphine"] call _tx; };
        };

        diag_log format [
            "[TCCC] %1 | %2 -> %3 | tamam %4 sn | kanKaybi:%5 kan:%6 baygin:%7",
            groupId _g, name _m, name _c, round (time - _t0),
            ([_c] call _kanKaybi) toFixed 3, (_c getVariable ["ace_medical_bloodVolume", 6]) toFixed 2, [_c] call _baygin
        ];
        [_m, _c] call _birak;
    };

    while {true} do {
        sleep 3;
        {
            private _g = _x;
            private _l = leader _g;
            if (isNull _l || {isPlayer _l} || {!local _l}) then { continue };
            if (_g getVariable [QGVAR(isRetreating), false] || {_g getVariable [QGVAR(isEvading), false]}) then { continue };

            private _contact = (_g getVariable [QGVAR(contact), 0]) > time;
            private _sonKes = time - (_g getVariable [QGVAR(contact), 0]);
            private _guvenli = !_contact && {_sonKes > 6};

            {
                if (_x getVariable [QGVAR(tcccFM), false] && {time > (_x getVariable [QGVAR(tcccBusy), 0])}) then {
                    _x setVariable [QGVAR(forceMove), nil];
                    _x setVariable [QGVAR(tcccFM), nil];
                };
            } forEach (units _g);
            private _yaralilar = (units _g) select {
                [_x] call _yarali
                && {
                    private _by = _x getVariable [QGVAR(tcccBy), objNull];
                    // v8.101: olen hekim betigi tcccBy'i temizleyemez -> hekim yok / bayilmis / suresi dolmus ise yarali yeniden atanabilir
                    isNull _by || {!([_by] call lambs_danger_tcccMedikOk)} || {time > (_by getVariable [QGVAR(tcccBusy), 0])}
                }
                && {(time - (_x getVariable [QGVAR(tcccDone), -999])) > 60}
            };
            if (_yaralilar isEqualTo []) then { continue };
            // v8.102 TRIYAJ ONCELIGI (kullanici: 'medikler icin oncelik belirtilsin'): kalp durmasi > kanama hizi > dusuk kan hacmi > en uzun suredir bekleyen (ilk bayilan atlanmasin)
            {
                if ((_x getVariable [QGVAR(tcccGorulduT), -1]) < 0) then { _x setVariable [QGVAR(tcccGorulduT), time]; };
            } forEach _yaralilar;
            _yaralilar = [_yaralilar, [], {
                private _p = 0;
                if (_x getVariable ["ace_medical_inCardiacArrest", false]) then { _p = _p + 1000; };
                _p = _p + 4000 * (([_x] call _kanKaybi) min 0.2);
                _p = _p + 25 * ((6 - (_x getVariable ["ace_medical_bloodVolume", 6])) max 0);
                _p = _p + ((time - (_x getVariable [QGVAR(tcccGorulduT), time])) min 240) / 4;
                _p
            }, "DESCEND"] call BIS_fnc_sortBy;

            {
                private _c = _x;
                // ates altinda: sadece baygin yarali
                if (!_guvenli && {!([_c] call _baygin)}) then { continue };

                private _adaylar = (units _g) select {
                    (_x isNotEqualTo _c) && {alive _x} && {local _x} && {!isPlayer _x} && {isNull objectParent _x}
                    && {(lifeState _x) in ["HEALTHY", "INJURED"]} && {!([_x] call _baygin)}
                    && {time > (_x getVariable [QGVAR(tcccBusy), 0])}
                    && {!(_x getVariable [QGVAR(forceMove), false]) || {([_x] call _rolFn) isEqualTo "MEDIC" || {_x getUnitTrait "Medic"}}}   // v8.102: gercek hekim bounding'in forceMove'u yuzunden elenmez (RPT 30f9155e: hekim 'fm' diye atlandi, tufekci hekim secildi)
                    && {(_x getVariable [QGVAR(grState), []]) isEqualTo []}
                };
                // hekim onceligi: MEDIC rolu > Medic trait > sargi tasiyan
                private _hekim = _adaylar select {([_x] call _rolFn) isEqualTo "MEDIC" || {_x getUnitTrait "Medic"}};
                if (_hekim isEqualTo []) then {
                    _hekim = _adaylar select {((items _x) findIf {(toLower _x) in ["ace_packingbandage", "ace_elasticbandage", "ace_fielddressing", "ace_quikclot", "ace_tourniquet", "firstaidkit"]}) > -1};
                };
                // KUMANDA MEDEVAC (fnc_hqMedevac): grupta hekim yoksa baska gruptan atanan hekim
                if (_hekim isEqualTo []) then {
                    private _hqM = _c getVariable [QGVAR(hqMedic), objNull];
                    if (!isNull _hqM && {alive _hqM} && {local _hqM} && {!isPlayer _hqM} && {isNull objectParent _hqM}
                        && {(lifeState _hqM) in ["HEALTHY", "INJURED"]} && {time > (_hqM getVariable [QGVAR(tcccBusy), 0])}) then {
                        _hekim = [_hqM];
                    };
                };
                if (_hekim isEqualTo []) then { continue };
                _hekim = [_hekim, [], {_x distance2D _c}, "ASCEND"] call BIS_fnc_sortBy;
                private _m = _hekim select 0;

                // ates altinda: hekim baskida degil ve dusman uzak olmali
                if (!_guvenli) then {
                    private _en = _m findNearestEnemy _m;
                    if ((getSuppression _m) >= 0.4 || {!isNull _en && {(_m distance2D _en) < 35}}) then { continue };   // v8.82: 50 -> 35 m (medevac guclendirme)
                };
                // v8.76 YARIS DUZELTMESI (RPT 7066b2ea: ayni hekim ayni saniyede 4 yaraliya birden atandi -> hekim yaralilar arasinda gidip geliyor, tedavi 1/5, hekim kendi yaralandi):
                //   spawn edilen _tedavi mesgul bayragini gec koyuyordu; dongunun sonraki yaralisi ayni hekimi tekrar aday gorur. Bayrak SENKRON, spawn'dan once konur.
                _m setVariable [QGVAR(tcccBusy), time + 150];
                _m setVariable [QGVAR(forceMove), true];
                _c setVariable [QGVAR(tcccBy), _m];
                [_g, _m, _c, _baygin, _birak, _tx, _kanKaybi] spawn _tedavi;
            } forEach _yaralilar;
        } forEach (allGroups select {local _x && {!isNull leader _x} && {!(_x getVariable ["lambs_danger_tarafKapali", false])}});
    };
};

true
