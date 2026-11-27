#include "script_component.hpp"
/*
 * Author: Cinar (ELITE fork)
 * DURUS AKICILIGI / YAT-KALK SONUMLEYICI (v8.725; kullanici: 'botlar cok yat-kalk yapiyor, daha smooth hareket etmeliler, covera direk girmeliler, movementte zaman kaybetmesinler'):
 * KANIT (1v1 RPT 25647f54, [DURUM] 20 sn ornekleme): tek bir bot (Aslan Karizi) 18 aralikta 13 kez durus degistirdi (STAND -> PRONE -> STAND -> CROUCH -> STAND ...), cogu 0 km/s'de; her degisim yatma / kalkma animasyonu = 1-3 sn kayip.
 *   Kaynak tek degil: durusDisiplin (durgun ayakta askeri 2.5 sn sonra comeltir / yatirir, harekette serbest birakir), LAMBS CQB ('Stay inside' / 'Assault' icinde kendi durus degisimleri), siper katmanlari (coverHug / acikSiper / siperMikro), tehlikeAlani, grenade tepkisi ...
 *   (onlarca setUnitPos cagri yeri). Bu yuzden kaynaktan bagimsiz, SONUCA bakan bir sinirlayici:
 * KURAL: yerel AI asker (oyuncu degil, aracta degil), grubu son 60 sn'de temasli; durusu (stance) CBA durusAkiciPencere (12 sn) icinde >= durusAkiciFlip (3) kez degistiyse 'dur-kalk salinimi' sayilir ve asker
 *   durusAkiciKilitS (6 sn) boyunca COMEL (MIDDLE: yurur / kosar / atar, yatma-kalkma animasyonu yok) kilidine alinir; kilit bitince 'AUTO'ya birakilir; sonraki kilit icin 10 sn sogutma. Kilit ERKEN biter: baski >= 0.6.
 *   MUAF: baski >= 0.5 (yaklasan ates: yatmak dogru), tedavi / bomba tepkisi / sarjor degistirme / panik / kose temkini / yan guvenlik, teslim / esir / baygin, sniper / pusu grubu (yatis bilincli), siperde bekleme (siperTut), peek (siperPeek: kalk-alcal bilincli), kosucu (forceMove ve hiz >= 6 km/s).
 * OLCUM: [DURUS-AKICI] (ilk 15 kilit) + 60 sn [DURUS-AKICI-OZET]: izlenen birim-dakika, durus degisimi, birim basina dakikada degisim, kilit sayisi, muaf sayisi. Karne satiri: YAT-KALK.
 * CBA: lambs_danger_durusAkici (varsayilan ACIK), durusAkiciPencere, durusAkiciFlip, durusAkiciKilitS.
 * SINIR: kilit sert 'setUnitPos MIDDLE' (AI'nin kendi yatma karari 6 sn bastirilir; baski 0.6'da erken biter); yatma gereken yerde (siper arkasi) coverHug / siperTut kendi durusunu kilit bitince / siperTut icinde yeniden yazar.
 *
 * Arguments: None
 * Return Value: Baslatildi mi <BOOL>
 * Public: No
*/

if (!isNil "lambs_danger_durusAkiciStarted") exitWith {false};
lambs_danger_durusAkiciStarted = true;

diag_log "[DURUS-AKICI] yat-kalk sonumleyici (durus degisimi sinirlayici) baslatildi (v8.725)";

[] spawn {
    private _logN = 0;
    private _say = createHashMapFromArray [["tick", 0], ["degisim", 0], ["kilit", 0], ["muaf", 0]];
    private _ozetT = time + 60;
    while {true} do {
        sleep 0.5;
        if !(missionNamespace getVariable ["lambs_danger_durusAkici", true]) then { continue };
        private _pen = ((missionNamespace getVariable ["lambs_danger_durusAkiciPencere", 12]) max 5) min 40;
        private _fN = ((missionNamespace getVariable ["lambs_danger_durusAkiciFlip", 3]) max 2) min 8;
        private _kS = ((missionNamespace getVariable ["lambs_danger_durusAkiciKilitS", 10]) max 2) min 20;
        {
            private _u = _x;
            if (!local _u || {isPlayer _u} || {!alive _u} || {!isNull objectParent _u}) then { continue };
            private _g = group _u;
            if (([_g] call FUNC(temasSeviye)) > 2) then { continue };
            private _st = stance _u;
            if !(_st in ["STAND", "CROUCH", "PRONE"]) then { continue };
            _say set ["tick", (_say get "tick") + 1];
            private _d = _u getVariable [QGVAR(akiciD), []];
            if (_d isEqualTo []) then { _u setVariable [QGVAR(akiciD), [_st, [], 0]]; continue };
            _d params ["_son", "_fl", "_sb"];
            if (_st isNotEqualTo _son) then {
                _fl pushBack time;
                _d set [0, _st];
                _say set ["degisim", (_say get "degisim") + 1];
            };
            _fl = _fl select {(time - _x) <= _pen};
            _d set [1, _fl];
            if ((count _fl) < _fN || {time < _sb}) then { continue };
            // muaf (bilincli durus / tehlike / baska katmanin durusu)
            if (
                (([_u] call FUNC(baskiSeviye)) >= 3) || {!((lifeState _u) in ["HEALTHY", "INJURED"])} || {captive _u} || {_u getVariable [QGVAR(teslim), false]} || {_u getVariable ["ACE_isUnconscious", false]}
                || {time < (_u getVariable [QGVAR(tcccBusy), 0])} || {(_u getVariable [QGVAR(grState), []]) isNotEqualTo []} || {(_u getVariable [QGVAR(reloadState), []]) isNotEqualTo []}
                || {time < (_u getVariable [QGVAR(panikBitis), 0])} || {!isNil {_u getVariable QGVAR(koseAktif)}} || {!isNil {_u getVariable QGVAR(yanGuv)}} || {_u getVariable [QGVAR(disableAI), false]}
                || {(_g getVariable [QGVAR(isAmbushing), false]) isEqualTo true} || {(_g getVariable [QGVAR(sniperTeam), false]) isEqualTo true}
                || {(_u getVariable [QGVAR(siperTutBit), 0]) > time} || {(_u getVariable [QGVAR(peekNext), 0]) > time}
                || {((_u getVariable [QGVAR(forceMove), false]) isEqualTo true) && {(speed _u) >= 6}}
            ) then {
                _say set ["muaf", (_say get "muaf") + 1];
                _d set [1, []];
                continue
            };
            // KILIT: comel (MIDDLE) _kS sn
            private _tk = time;
            _u setVariable [QGVAR(akiciTok), _tk];
            _u setVariable [QGVAR(akiciKB), time + _kS];
            // v8.753 (kullanici: 'bir de dur kalk yapiyor karakterler'): kilit YATIKSA yatik, COMELSE comel KALIR (eskiden PRONE -> MIDDLE = kilidin kendisi ek durus degisimiydi); yalniz AYAKTA ise comele iner
            _u setUnitPos (switch (_st) do { case "PRONE": {"DOWN"}; default {"MIDDLE"} });
            _d set [1, []];
            _d set [2, time + _kS + 10];
            _say set ["kilit", (_say get "kilit") + 1];
            if (_logN < 15) then {
                _logN = _logN + 1;
                diag_log format ["[DURUS-AKICI] %1 | %2 | %3 sn'de %4 durus degisimi (%5 -> kilit %6 sn) | hiz %7 km/s | baski %8 | bina %9 | komut %10", groupId _g, name _u, _pen, _fN, _st, _kS, round (speed _u), (getSuppression _u) toFixed 2, (insideBuilding _u) toFixed 1, currentCommand _u];
            };
            [{
                params ["_a", "_t"];
                !alive _a || {time > (_a getVariable [QGVAR(akiciKB), 0])} || {([_a] call FUNC(baskiSeviye)) >= 4} || {(_a getVariable [QGVAR(akiciTok), -1]) isNotEqualTo _t}
            }, {
                params ["_a", "_t"];
                if (alive _a && {(_a getVariable [QGVAR(akiciTok), -1]) isEqualTo _t}) then {
                    _a setVariable [QGVAR(akiciTok), nil];
                    _a setUnitPos "AUTO";
                };
            }, [_u, _tk], _kS + 2, {
                params ["_a", "_t"];
                if (alive _a && {(_a getVariable [QGVAR(akiciTok), -1]) isEqualTo _t}) then {
                    _a setVariable [QGVAR(akiciTok), nil];
                    _a setUnitPos "AUTO";
                };
            }] call CBA_fnc_waitUntilAndExecute;
        } forEach allUnits;
        if (time > _ozetT) then {
            _ozetT = time + 60;
            private _bdk = (_say get "tick") * 0.5 / 60;
            if ((_say get "tick") > 0) then {
                diag_log format ["[DURUS-AKICI-OZET] 60 sn: izlenen birim-dk %1 | durus degisimi %2 | birim basina dakikada %3 | kilit %4 | muaf %5", _bdk toFixed 1, _say get "degisim", ((_say get "degisim") / (_bdk max 0.05)) toFixed 1, _say get "kilit", _say get "muaf"];
            };
            { _say set [_x, 0]; } forEach ["tick", "degisim", "kilit", "muaf"];
        };
    };
};
true
