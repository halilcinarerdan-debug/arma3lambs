#include "script_component.hpp"
/*
 * Author: Cinar (ELITE fork)
 * GAFIL AVLAMA / OYUNCUYA OZEL KARSI FARKINDALIK KATMANI (v8.703; kullanici: 'oyuncularin bakis acisi eslesmediyse ya da oyuncular ates etmiyorsa karsilik vermiyorsa combat BASLAMADAN sis kullanmasinlar, botlar hazirda beklesin, oyunculari gafil avlasin').
 * Yalniz INSAN OYUNCU hedeflere karsi. Oyuncuyu bilen (group targets) yerel AI grubunda (>= gafilMinAsker saglam asker) SAVAS HENUZ BASLAMADIYSA (grupta son 25 sn ates yok, baski < 0.1, son 60 sn kayip yok, baska bilinen AI dusman yok):
 *   OYUNCU FARKINDA DEGILSE (oyuncunun bakis konisi - gafilAci 30 derece - grubun en yakin 3 askerine, gorus hatti acik, gafilMenzil icinde DEGIL; oyuncu son 20 sn ates etmedi) grup 'GAFIL BEKLEME'ye girer:
 *     STEALTH + combatMode GREEN (acmaz, ates edilirse karsilik verir), asker DUR + comel / yat (kilit), bakis oyuncu yonune; SIS KULLANILMAZ (fnc_tacticalSmoke bayragi gorur); taktik baslamaz (isExecutingTactic; en gec +sure+60 sn guvenlik agi);
 *   BEKLEME BITIS (gafil avla = ates serbest, COMBAT + RED + oyuncu reveal 2.5 + hep birden doTarget / doFire): (a) TETIK: oyuncu gruba <= gafilTetikM (70 m) (olum alani); (b) oyuncu BAKISI ESLESTI >= 1 sn; (c) oyuncu ates etti / ates sesi duyuldu / baski / kayip;
 *   sessiz bitis (eski combatMode / behaviour geri, ates YOK): sure doldu (gafilSure 150 sn) ya da oyuncu 45 sn bilinmiyor. Grup basina gafilBekle (240 sn) bekleme.
 * ATLANIR: geri cekilme / temas kes / kacis / bounding / taktik / supurme / pusu / sniper / sahte cekilme, LAMBS gorevi / TUTAN waypoint, binada, oyuncu liderli grup, bilinen AI dusman (oyuncu disi) 350 m icinde.
 * CBA: lambs_danger_gafilAvla (varsayilan KAPALI), gafilAci, gafilMenzil, gafilTetikM, gafilSure, gafilBekle, gafilMinAsker. Log: [GAFIL] (ilk 25) + [GAFIL-OZET] 60 sn.
 *
 * Arguments: None
 * Return Value: Baslatildi mi <BOOL>
 * Public: No
*/

if (!isNil "lambs_danger_gafilStarted") exitWith {false};
lambs_danger_gafilStarted = true;
diag_log "[GAFIL] gafil avlama (oyuncu farkinda degilse sis yok, botlar hazirda bekler, oyuncuyu gafil avlar) baslatildi (v8.703)";

[] spawn {
    private _logN = 0;
    private _say = createHashMapFromArray [["basladi", 0], ["tetik", 0], ["bakis", 0], ["ates", 0], ["sure", 0], ["kayboldu", 0], ["iptal", 0]];
    private _ozetT = time + 60;
    private _red = createHashMap;   // v8.704: aday grubun NEDEN gafil beklemeye girmedigi sayaclari
    private _durumT = time + 20;
    while {true} do {
        sleep 0.4;
        if (time > _durumT) then { _durumT = time + 1e9; diag_log format ["[GAFIL] CBA gafilAvla = %1 (ilk kontrol; false ise preset / CBA ayari yuklenmemis)", missionNamespace getVariable ["lambs_danger_gafilAvla", false]]; };
        if (time > _ozetT) then {
            _ozetT = time + 60;
            private _t = 0;
            { _t = _t + (_say get _x); } forEach (keys _say);
            if ((count _red) > 0) then { diag_log format ["[GAFIL-OZET] 60 sn: aday grup-tur ret nedenleri: %1", (keys _red) apply { format ["%1=%2", _x, _red get _x] }]; _red = createHashMap; };
            if (_t > 0) then { diag_log format ["[GAFIL-OZET] 60 sn: bekleme basladi %1 | bitis: tetik (olum alani) %2, bakis eslesti %3, ates / baski / kayip %4, sure doldu %5, oyuncu kayboldu %6, iptal %7", _say get "basladi", _say get "tetik", _say get "bakis", _say get "ates", _say get "sure", _say get "kayboldu", _say get "iptal"]; };
            { _say set [_x, 0]; } forEach (keys _say);
        };
        if !(missionNamespace getVariable ["lambs_danger_gafilAvla", false]) then { continue };
        private _aci = ((missionNamespace getVariable ["lambs_danger_gafilAci", 30]) max 10) min 60;
        private _menzil = ((missionNamespace getVariable ["lambs_danger_gafilMenzil", 400]) max 100) min 600;
        private _tetik = ((missionNamespace getVariable ["lambs_danger_gafilTetikM", 70]) max 30) min 200;
        private _sure = ((missionNamespace getVariable ["lambs_danger_gafilSure", 150]) max 30) min 300;
        private _bekle = ((missionNamespace getVariable ["lambs_danger_gafilBekle", 240]) max 60) min 900;
        private _minA = ((missionNamespace getVariable ["lambs_danger_gafilMinAsker", 4]) max 3) min 12;
        private _gozlem = ((missionNamespace getVariable ["lambs_danger_gafilGozlemS", 5]) max 2) min 15;
        private _sqMax = ((missionNamespace getVariable ["lambs_danger_gafilSquadMax", 4]) max 1) min 12;
        private _n = 0;
        {
            private _g = _x;
            if (_n >= 8) exitWith {};
            private _l = leader _g;
            if (isNull _l || {!local _g} || {isPlayer _l} || {!alive _l} || {!isNull objectParent _l}) then { continue };
            if ((_g getVariable [QGVAR(gafilAktif), false]) isEqualTo true) then { continue };
            if (time < (_g getVariable [QGVAR(gafilT), 0])) then { continue };
            private _gr = "";
            if ((_g getVariable [QGVAR(isExecutingTactic), false]) || {_g getVariable [QGVAR(isBounding), false]}) then { _gr = "taktik yurutuyor (TAK / BND)"; } else {
            if ((_g getVariable [QGVAR(isRetreating), false]) || {_g getVariable [QGVAR(isEvading), false]} || {_g getVariable [QGVAR(isBreakingContact), false]}) then { _gr = "geri cekilme / kacis / temas kes"; } else {
            if ((insideBuilding _l) > 0.5) then { _gr = "binada"; } else {
            if (([_g] call FUNC(wpSahip)) in ["LAMBS", "TUTAN"]) then { _gr = "LAMBS gorevi / TUTAN waypoint"; } else {
            if ((_g getVariable [QGVAR(isSweeping), false]) || {_g getVariable [QGVAR(isAmbushing), false]} || {_g getVariable [QGVAR(sniperTeam), false]} || {(_g getVariable [QGVAR(sahteAktif), false]) isEqualTo true}) then { _gr = "pusu / supurme / sniper / sahte cekilme"; }; }; }; }; };
            if (_gr isNotEqualTo "") then { _red set [_gr, (_red getOrDefault [_gr, 0]) + 1]; continue };
            private _us = (units _g) select {alive _x && {isNull objectParent _x} && {!isPlayer _x} && {(lifeState _x) in ["HEALTHY", "INJURED"]}};
            private _sayiN = count _us;
            // kayip takibi (son 60 sn)
            private _onc = _g getVariable [QGVAR(gafilSayi), _sayiN];
            if (_sayiN < _onc) then { _g setVariable [QGVAR(gafilKayipT), time]; };
            _g setVariable [QGVAR(gafilSayi), _sayiN];
            if (_sayiN < _minA) then { _red set ["grupta asker az", (_red getOrDefault ["grupta asker az", 0]) + 1]; continue };
            if ((time - (_g getVariable [QGVAR(gafilKayipT), -999])) < 60) then { _red set ["son 60 sn kayip", (_red getOrDefault ["son 60 sn kayip", 0]) + 1]; continue };
            _n = _n + 1;
            // savas basladi mi?
            private _bsk = 0;
            { _bsk = _bsk max (getSuppression _x); } forEach _us;
            if (_bsk > 0.1) then { _red set ["savas basladi (baski / son 25 sn ates)", (_red getOrDefault ["savas basladi (baski / son 25 sn ates)", 0]) + 1]; continue };
            if ((_us findIf {(time - (_x getVariable [QGVAR(sonAtisT), -999])) < 25}) >= 0) then { _red set ["savas basladi (baski / son 25 sn ates)", (_red getOrDefault ["savas basladi (baski / son 25 sn ates)", 0]) + 1]; continue };
            // bilinen oyuncu hedefi; baska bilinen AI dusman varsa savas var
            private _tum = _l targets [true, _menzil, [], 90];
            private _hedef = _tum select {isPlayer _x || {((crew _x) findIf {isPlayer _x}) >= 0}};
            if (_hedef isEqualTo []) then { _red set ["bilinen oyuncu yok", (_red getOrDefault ["bilinen oyuncu yok", 0]) + 1]; continue };
            if (((_l targets [true, 350, [], 30]) findIf {!(isPlayer _x) && {((crew _x) findIf {isPlayer _x}) < 0}}) >= 0) then { continue };
            _hedef = [_hedef, [], {_l distance2D _x}, "ASCEND"] call BIS_fnc_sortBy;
            private _p = _hedef select 0;
            if ((_l distance2D _p) <= (_tetik + 15)) then { _red set ["oyuncu tetik mesafesinde (zaten cok yakin)", (_red getOrDefault ["oyuncu tetik mesafesinde (zaten cok yakin)", 0]) + 1]; continue };
            // v8.703: OYUNCU SQUADI (oyuncu + AI dostlari, canli) gafilSquadMax'tan (4) buyukse bekleme YOK: AI dostlar botlari gorur / ates eder, gafil avlama anlamsiz
            if ((count ((units (group _p)) select {alive _x})) > _sqMax) then { _g setVariable [QGVAR(gafilGozlemBas), nil]; _red set ["oyuncu squadi buyuk", (_red getOrDefault ["oyuncu squadi buyuk", 0]) + 1]; continue };
            // oyuncu farkinda mi? (bakis konisi + gorus hatti) / ates ediyor mu?
            private _eye = eyePos _p;
            private _dir = if (local _p) then { getCameraViewDirection _p } else { eyeDirection _p };
            if ((vectorMagnitude _dir) < 0.1) then { continue };
            _dir = vectorNormalized _dir;
            private _yakinlar = ([_us, [], {_x distance2D _p}, "ASCEND"] call BIS_fnc_sortBy) select [0, 3];
            // v8.703 GUVENLI GOZLEM (kullanici: 'safe olsun, oyuncunun birkac saniye gozleyip gozlemedigini cikarim yapsinlar'): gafil karari TEK ornekle degil; oyuncu GOZLEM penceresi (gafilGozlemS, 5 sn) boyunca KESINTISIZ izlenir:
            //   her 0.75 sn'de bakis dogrulamasi (grubun en yakin 3 askerine aci <= gafilAci x 1.5 [guvenli taraf] + gorus hatti acik); tek bir eslesme / ates gozlemi sifirlar; en az 4 ornek; ornekler arasi > 3 sn bosluk (hedef kayboldu / savas) gozlemi sifirlar
            private _farkinda = (_yakinlar findIf {
                private _tg = (getPosASL _x) vectorAdd [0, 0, 1.3];
                private _v = _tg vectorDiff _eye;
                private _d = vectorMagnitude _v;
                (_d > 5) && {_d <= _menzil} && {(acos ((((_dir vectorDotProduct _v) / _d) min 1) max -1)) <= (_aci * 1.5)} && {!(terrainIntersectASL [_eye, _tg])} && {!(lineIntersects [_eye, _tg, _p, _x])}
            }) >= 0;
            if (_farkinda || {(time - (_p getVariable [QGVAR(sonAtisT), -999])) < 20} || {(time - (_g getVariable [QGVAR(sesSonZaman), -999])) < 10}) then { _g setVariable [QGVAR(gafilGozlemBas), nil]; _red set ["oyuncu farkinda (bakis konisi) / ates / ates sesi", (_red getOrDefault ["oyuncu farkinda (bakis konisi) / ates / ates sesi", 0]) + 1]; continue };
            // v8.705: gozlem artik BEKLEME ICINDE (taktikler ilk temasta saniyeler icinde basladigi icin 5 sn once-gozlem hic bitmiyordu: RPT f743a43c 'taktik yurutuyor' 40-125 ret / dk): hemen hazirda beklemeye gecilir, gozlem penceresi (gafilGozlemS) bekleme basinda

            // ---- GAFIL BEKLEME BASLAT
            _say set ["basladi", (_say get "basladi") + 1];
            _g setVariable [QGVAR(gafilAktif), true];
            _g setVariable [QGVAR(isExecutingTactic), true];
            private _eskiCM = combatMode _g;
            private _eskiBeh = behaviour _l;
            _g setCombatMode "GREEN";
            _g setBehaviour "STEALTH";
            private _tpos = getPosATL _p;
            {
                _x setVariable [QGVAR(taktikKilit), time + _sure + 20];
                doStop _x;
                _x setUnitPosWeak (["DOWN", "MIDDLE"] select ((_forEachIndex mod 3) isEqualTo 0));
                _x doWatch ((getPosATL _l) getPos [150, ((getPosATL _l) getDir _tpos) + ((random 40) - 20)]);
            } forEach _us;
            if (_logN < 25) then {
                _logN = _logN + 1;
                diag_log format ["[GAFIL] %1 | BEKLEME BASLADI | oyuncu %2 (%3 m) su an bakmiyor (koni %8 derece, gorus hatti) ve ates etmiyor | %4 asker HAZIRDA BEKLER (ilk bilgide, taktik baslamadan), SIS YOK | gozlem %7 sn: bakis eslesirse savas, eslesmezse pusu | tetik %5 m, sure %6 sn", groupId _g, name _p, round (_l distance2D _p), _sayiN, _tetik, _sure, _gozlem, round (_aci * 1.5)];
            };

            [_g, _p, _us, _eskiCM, _eskiBeh, _sure, _tetik, _aci, _menzil, _bekle, _say, _gozlem] spawn {
                params ["_g", "_p", "_us", "_eskiCM", "_eskiBeh", "_sure", "_tetik", "_aci", "_menzil", "_bekle", "_say", "_gozlem"];
                private _gozlemLog = false;
                private _bas = time;
                private _sonGor = time;
                private _dwell = -1;
                private _sebep = "";
                private _sayi0 = ({alive _x} count _us);
                while {_sebep isEqualTo ""} do {
                    sleep 0.5;
                    if (isNull _g || {isNull (leader _g)}) exitWith { _sebep = "iptal"; };
                    if ((_g getVariable [QGVAR(isRetreating), false]) || {_g getVariable [QGVAR(isBreakingContact), false]} || {_g getVariable [QGVAR(isEvading), false]}) exitWith { _sebep = "iptal"; };
                    if ((time - _bas) > _sure) exitWith { _sebep = "sure"; };
                    if ((count ((units (group _p)) select {alive _x})) > ((missionNamespace getVariable ["lambs_danger_gafilSquadMax", 4]) max 1)) exitWith { _sebep = "iptal"; };   // oyuncu squadi buyudu (AI dostlar katildi): bekleme biter
                    private _canli = _us select {alive _x};
                    if (_canli isEqualTo [] || {!alive _p}) exitWith { _sebep = "iptal"; };
                    // ates / baski / kayip / ates sesi
                    private _bsk = 0;
                    { _bsk = _bsk max (getSuppression _x); } forEach _canli;
                    if (_bsk >= 0.15 || {(count _canli) < _sayi0} || {(time - (_p getVariable [QGVAR(sonAtisT), -999])) < 3} || {(time - (_g getVariable [QGVAR(sesSonZaman), -999])) < 3}) exitWith { _sebep = "ates"; };
                    // tetik: oyuncu olum alanina girdi
                    private _enYakin = selectMin (_canli apply { _x distance2D _p });
                    if (_enYakin <= _tetik) exitWith { _sebep = "tetik"; };
                    // oyuncu bakisi esleşti mi (>= 1 sn)
                    private _eye = eyePos _p;
                    private _dir = if (local _p) then { getCameraViewDirection _p } else { eyeDirection _p };
                    private _farkinda = false;
                    if ((vectorMagnitude _dir) > 0.1) then {
                        _dir = vectorNormalized _dir;
                        _farkinda = ((_canli apply { [_x distance2D _p, _x] }) select {(_x select 0) <= _menzil}) findIf {
                            private _u = _x select 1;
                            private _tg = (getPosASL _u) vectorAdd [0, 0, 1.3];
                            private _v = _tg vectorDiff _eye;
                            private _d = vectorMagnitude _v;
                            (_d > 5) && {(acos ((((_dir vectorDotProduct _v) / _d) min 1) max -1)) <= _aci} && {!(terrainIntersectASL [_eye, _tg])} && {!(lineIntersects [_eye, _tg, _p, _u])}
                        } >= 0;
                    };
                    if (_farkinda) then { if (_dwell < 0) then { _dwell = time; }; if ((time - _dwell) >= 1) exitWith { _sebep = "bakis"; }; } else { _dwell = -1; };
                    if (!_gozlemLog && {(time - _bas) >= _gozlem}) then { _gozlemLog = true; diag_log format ["[GAFIL] %1 | GOZLEM TAMAM: oyuncu %2 sn boyunca bakis konisine girmedi, ates etmedi -> PUSU (tetik %3 m)", groupId _g, _gozlem, _tetik]; };
                    // oyuncu hala biliniyor mu
                    if (((leader _g) targets [true, _menzil + 100, [], 45]) findIf {_x isEqualTo _p || {(crew _x) findIf {_x isEqualTo _p} >= 0}} >= 0) then { _sonGor = time; };
                    if ((time - _sonGor) > 45) exitWith { _sebep = "kayboldu"; };
                };
                // ---- BITIS
                private _ates = _sebep in ["tetik", "bakis", "ates"];
                {
                    if (alive _x) then {
                        _x setVariable [QGVAR(taktikKilit), nil];
                        _x setUnitPosWeak "AUTO";
                        _x doWatch objNull;
                    };
                } forEach _us;
                if (!isNull _g) then {
                    if (_ates && {alive _p}) then {
                        // GAFIL AVLA: ates serbest, hep birden
                        _g setCombatMode "RED";
                        _g setBehaviour "COMBAT";
                        _g reveal [_p, 2.5];
                        // v8.707 TEMAS BAYRAGI (RPT 87f87da8: gafil avlama sonrasi grup COMBAT + RED kaldi ama QGVAR(contact) HIC yazilmadi -> [ANOMALI] TEMAS-YOK-COMBAT 4 satir; temasSonrasi / combatGevset contact > 0 sarti aradigi icin grubu hic gevsetmedi, patlayici modulu da 'temasta degil' saydi): LAMBS fnc_contact ile ayni deger (+600 sn)
                        _g setVariable [QGVAR(contact), ((time + 600) max (_g getVariable [QGVAR(contact), 0]))];
                        { if (alive _x) then { _x doTarget _p; _x doFire _p; }; } forEach _us;
                    } else {
                        _g setCombatMode _eskiCM;
                        _g setBehaviour _eskiBeh;
                        if (_sebep isNotEqualTo "iptal") then { { if (alive _x && {!isNull (leader _g)}) then { [_x, leader _g] call FUNC(doFollowGuvenli); }; } forEach _us; };
                    };
                    _g setVariable [QGVAR(gafilAktif), nil];
                    _g setVariable [QGVAR(isExecutingTactic), false];
                    _g setVariable [QGVAR(gafilT), time + _bekle];
                };
                _say set [_sebep, (_say getOrDefault [_sebep, 0]) + 1];
                diag_log format ["[GAFIL] %1 | BEKLEME BITTI | neden: %2 | %3 sn bekledi | %4", if (isNull _g) then {"-"} else {groupId _g}, _sebep, round (time - _bas), ["sessiz (ates yok, eski mod geri)", "GAFIL AVLA (ates serbest, COMBAT + RED, hep birden)"] select _ates];
            };
            // guvenlik agi: surec ne olursa olsun bayrak temizlenir
            [{ params ["_gg"]; if (!isNull _gg && {(_gg getVariable [QGVAR(gafilAktif), false]) isEqualTo true}) then { _gg setVariable [QGVAR(gafilAktif), nil]; _gg setVariable [QGVAR(isExecutingTactic), false]; }; }, [_g], _sure + 60] call CBA_fnc_waitAndExecute;
        } forEach allGroups;
    };
};
true
