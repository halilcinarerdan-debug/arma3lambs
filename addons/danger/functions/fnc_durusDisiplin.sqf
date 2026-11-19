#include "script_component.hpp"
/*
 * Author: Cinar (ELITE fork)
 * DURUS DISIPLINI (v8.668; kullanici: 'hareketsiz askerlerin ayakta olmasini ele al'; RPT c6c1f3e6 lythium): TEMASTA hareketsiz asker AYAKTA kalmaz.
 *
 * TESHIS (RPT c6c1f3e6, [DURUM] satirlari): saglikli / yarali ornegin 68'i durgundu, bunlarin 38'i (%56) STAND; 24'u 'komut MOVE + anim mstpsraswrfldnon' (ayakta, bekliyor), 10'unda forceMove bayragi takili.
 *   Ayni askerler 'Group Flank' dur-kalk dongusunde dusmana 180-250 m'de ve temas varken ayakta bekliyordu. Mevcut katmanlar bu boslugu kapatmiyordu:
 *   - fnc_acikBekleme: yalniz 8 sn + acikta + (forceMove / taktikKilit / bounding / grup taktigi YOK) kosuluyla; RPT'de 12:11:23 -> 12:13:53 (tum catisma) HIC tetiklenmedi.
 *   - fnc_coverHug / fnc_acikSiper: dusman hattinda sert yuzey / acik maruziyet ararlar; 'uzak engel' (hat 4 m'den uzak nesne / arazi ile kesik, ornegin %82-96) siniflisi duruyor, durus degismiyor.
 *
 * KURAL: grubu temasta (45 sn) olan, binada olmayan, yerel AI asker >= lambs_danger_durusDisiplinSn sn durgunsa (hiz < 1.5 km/s) ve STAND ise duruşu DUSURULUR:
 *   - dusman bilinmiyor / belirsiz: COMEL (MIDDLE)
 *   - dusman biliniyor (25-500 m): ayaktaki goz yuksekliginden (1.5 m) hat KAPALI ise zaten gizli: COMEL; hat ACIK ise, dusman >= lambs_danger_durusYatMesafe (100 m) icin YAT (0.4 m'den hat acik ise;
 *     ~%25 askerde (birimId tohumu) yat yerine comel: cesitlilik), degilse COMEL (1.0 m'den hat acik ise). Alcak durusta da hat kapaliysa (ayakta durmak ates icin gerekli) ayakta BIRAKILIR (gorusYok).
 *   - dusman < 25 m (yakin dovus; CQB katmanlari yonetir): dokunulmaz.
 *   Durus 'setUnitPosWeak' ile verilir (AI ates / hareket icin gerekirse yukseltebilir). AI 12 sn icinde 3 kez ayaga kaldirirsa (direnen) 30 sn vazgecilir. Asker yurumeye baslayinca (>= 1.5 km/s) 'AUTO'ya birakilir.
 *   NEDEN eski katmanlar yetmedi diye forceMove / taktikKilit / bounding / grup taktigi MUAF DEGIL (durgun asker zaten hareket etmiyor; kosucu hareket halindeyken (hiz >= 1.5) hic islem yok).
 * MUAF: oyuncu / oyuncu komutasi, arac, bina ici, baygin / etkisiz, teslim, hekim (tcccBusy), el bombasi (grState), yeniden doldurma (reloadState), panik, kose temkini, yan guvenlik, disableAI, kendi duruşunu yoneten katmanlar
 *   (sipere yapisma son 20 sn, acikSiper hedefi son 25 sn, siper mikro duzeltme 6 sn), pusu / supurme / siper-mevzi / keskin nisanci takimi / retreat / evade / temas kes / soyma gruplari, son 2 sn icinde ates edenler.
 * CBA: lambs_danger_durusDisiplin (acik / kapali), lambs_danger_durusDisiplinSn (durgun sure sn), lambs_danger_durusYatMesafe (m). Log: [DURUS-DISIPLIN] (ilk 25) + [DURUS-DISIPLIN-OZET] 60 sn.
 *
 * Arguments: None
 * Return Value: Baslatildi mi <BOOL>
 * Public: No
*/

if (!isNil "lambs_danger_durusDisiplinStarted") exitWith {false};
lambs_danger_durusDisiplinStarted = true;

diag_log "[DURUS-DISIPLIN] duruş disiplini (temasta hareketsiz asker ayakta kalmaz: comel / yat) baslatildi (v8.668)";

[] spawn {
    private _logN = 0;
    private _say = createHashMapFromArray [["durgunAyakta", 0], ["comel", 0], ["yat", 0], ["direnen", 0], ["gizliComel", 0], ["gorusYok", 0], ["yakin", 0], ["serbest", 0]];
    private _ozetT = time + 60;
    while {true} do {
        sleep ([1, true] call FUNC(dusunSure));
        if !(missionNamespace getVariable ["lambs_danger_durusDisiplin", true]) then { continue };
        private _sn = ((missionNamespace getVariable ["lambs_danger_durusDisiplinSn", 2.5]) max 1) min 10;
        private _yatM = ((missionNamespace getVariable ["lambs_danger_durusYatMesafe", 100]) max 40) min 400;
        private _esik = ["SUPHE"] call FUNC(bilgiEsik);
        private _n = 0;
        {
            private _u = _x;
            if (_n >= 10) exitWith {};
            if (!local _u || {isPlayer _u} || {!alive _u} || {!isNull objectParent _u}) then { continue };

            // hareket basladiysa: kendi dusurdugumuz duruş serbest (AI yuruyus hizini alcak durusta kisitlamasin)
            if ((speed _u) >= 1.5) then {
                if (!isNil {_u getVariable QGVAR(durusDusT)}) then {
                    _u setUnitPosWeak "AUTO";
                    _u setVariable [QGVAR(durusDusT), nil];
                    _say set ["serbest", (_say get "serbest") + 1];
                };
                if (!isNil {_u getVariable QGVAR(durgunT)}) then { _u setVariable [QGVAR(durgunT), nil]; };
                continue
            };

            private _g = group _u;
            if (
                ((_g getVariable [QGVAR(contact), 0]) < (time - 45)) || {(insideBuilding _u) > 0.5}
                || {!((lifeState _u) in ["HEALTHY", "INJURED"])} || {captive _u} || {_u getVariable [QGVAR(teslim), false]}
            ) then { if (!isNil {_u getVariable QGVAR(durgunT)}) then { _u setVariable [QGVAR(durgunT), nil]; }; continue };

            // ne kadar suredir durgun
            private _dt = _u getVariable [QGVAR(durgunT), -1];
            if (_dt < 0) then { _u setVariable [QGVAR(durgunT), time]; continue };
            if ((time - _dt) < _sn) then { continue };
            if ((stance _u) isNotEqualTo "STAND") then { continue };
            if (time < (_u getVariable [QGVAR(durusBekT), 0])) then { continue };

            // muaf katmanlar (kendi duruşunu yonetenler / bilinçli ayakta duranlar)
            if (
                (time < (_u getVariable [QGVAR(tcccBusy), 0])) || {(_u getVariable [QGVAR(grState), []]) isNotEqualTo []} || {(_u getVariable [QGVAR(reloadState), []]) isNotEqualTo []}
                || {time < (_u getVariable [QGVAR(panikBitis), 0])} || {!isNil {_u getVariable QGVAR(koseAktif)}} || {!isNil {_u getVariable QGVAR(yanGuv)}} || {_u getVariable [QGVAR(disableAI), false]}
                || {(time - (_u getVariable [QGVAR(hugAt), -999])) < 20} || {(time - ((_u getVariable [QGVAR(acikSiperHedef), [0, -999]]) param [1, -999])) < 25}
                || {time < ((_u getVariable [QGVAR(mikroT), 0]) + 2)}
                || {(time - (_u getVariable [QGVAR(sonAtisT), -999])) < 2}
                || {_g getVariable [QGVAR(isAmbushing), false]} || {_g getVariable [QGVAR(isSweeping), false]} || {_g getVariable [QGVAR(sniperTeam), false]} || {_g getVariable [QGVAR(isPeeling), false]}
                || {_g getVariable [QGVAR(isRetreating), false]} || {_g getVariable [QGVAR(isEvading), false]} || {_g getVariable [QGVAR(isBreakingContact), false]}
                || {[_g] call FUNC(mevziDeMi)} || {[_u] call FUNC(oyuncuKomutaMi)}
            ) then { continue };

            _say set ["durgunAyakta", (_say get "durgunAyakta") + 1];
            _n = _n + 1;

            // direnc: biz dusurduk, AI ayaga kaldirdi (ates / hareket icin) -> 3 kez sonra 30 sn vazgec
            private _dd = _u getVariable [QGVAR(durusDusT), -1];
            if (_dd >= 0 && {(time - _dd) < 12}) then {
                private _dn = (_u getVariable [QGVAR(durusDirenc), 0]) + 1;
                _u setVariable [QGVAR(durusDirenc), _dn];
                _say set ["direnen", (_say get "direnen") + 1];
                if (_dn >= 3) then {
                    _u setVariable [QGVAR(durusBekT), time + 30];
                    _u setVariable [QGVAR(durusDirenc), 0];
                    _u setVariable [QGVAR(durusDusT), nil];
                    continue
                };
            } else { _u setVariable [QGVAR(durusDirenc), 0]; };

            private _e = _u findNearestEnemy _u;
            private _ed = if (isNull _e || {!alive _e}) then {-1} else {_u distance2D _e};
            if (_ed >= 0 && {_ed < 25}) then {
                _u setVariable [QGVAR(durusBekT), time + 5];
                _say set ["yakin", (_say get "yakin") + 1];
                continue
            };

            private _hedef = "";
            private _neden = "";
            if (_ed < 0 || {_ed > 500} || {(_u knowsAbout _e) < _esik}) then {
                _hedef = "MIDDLE";
                _neden = "temas var, dusman belirsiz -> comel";
            } else {
                private _tgt = aimPos _e;
                private _pA = getPosASL _u;
                private _gorur = {
                    params ["_h"];
                    private _c = _pA vectorAdd [0, 0, _h];
                    ((lineIntersectsSurfaces [_c, _tgt, _u, _e, true, 1, "VIEW", "NONE"]) isEqualTo []) && {!(terrainIntersectASL [_c, _tgt])}
                };
                if !([1.5] call _gorur) then {
                    // ayakta bile hat kapali: zaten gizli; yine de ayakta beklemesin (yer isgali dusuk profil)
                    _hedef = "MIDDLE";
                    _neden = "dusman hatti ayakta kapali (gizli) -> comel";
                    _say set ["gizliComel", (_say get "gizliComel") + 1];
                } else {
                    // ~%25 askerde yat yerine comel (cesitlilik; ayni noktada herkes ayni duruşta olmasin)
                    private _yatIzin = _ed >= _yatM && {(["durusDisiplin", [_u] call FUNC(birimId), false] call FUNC(rastgele)) >= 0.25};
                    if (_yatIzin && {[0.4] call _gorur}) then {
                        _hedef = "DOWN";
                        _neden = format ["dusman %1 m, hat 0.4 m'den acik -> yat", round _ed];
                    } else {
                        if ([1.0] call _gorur) then {
                            _hedef = "MIDDLE";
                            _neden = format ["dusman %1 m, hat 1.0 m'den acik -> comel", round _ed];
                        };
                    };
                };
            };
            if (_hedef isEqualTo "") then {
                // alcak durusta hat kapali: ayakta durmak ates icin gerekli -> birak (sik tekrar etmesin)
                _u setVariable [QGVAR(durusBekT), time + 8];
                _say set ["gorusYok", (_say get "gorusYok") + 1];
                continue
            };

            _u setUnitPosWeak _hedef;
            _u setVariable [QGVAR(durusDusT), time];
            _u setVariable [QGVAR(durusBekT), time + 4];
            private _sk = ["comel", "yat"] select (_hedef isEqualTo "DOWN");
            _say set [_sk, (_say get _sk) + 1];
            if (_logN < 25) then {
                _logN = _logN + 1;
                diag_log format [
                    "[DURUS-DISIPLIN] %1 | %2 | rol %3 | %4 sn durgun + ayakta | gorev %5 | komut %6 | forceMove %7 | taktikKilit %8 sn | grup taktik %9 | %10",
                    groupId _g, name _u, [_u] call (missionNamespace getVariable ["lambs_danger_fnc_getUnitRole", {"RIFLE"}]), round (time - _dt),
                    _u getVariable [QEGVAR(main,currentTask), "-"], currentCommand _u, _u getVariable [QGVAR(forceMove), false],
                    round (((_u getVariable [QGVAR(taktikKilit), 0]) - time) max 0), _g getVariable [QGVAR(isExecutingTactic), false], _neden
                ];
            };
        } forEach allUnits;
        if (time > _ozetT) then {
            _ozetT = time + 60;
            if ((_say get "durgunAyakta") > 0 || {(_say get "serbest") > 0}) then {
                diag_log format [
                    "[DURUS-DISIPLIN-OZET] 60 sn: durgun + ayakta (temasta) %1 | yat %2 | comel %3 (gizli ayakta %4) | AI ayaga kaldirdi (direnen) %5 | alcak durusta hat kapali, ayakta birakildi %6 | yakin dovus (< 25 m) %7 | yurumeye baslayinca serbest %8",
                    _say get "durgunAyakta", _say get "yat", _say get "comel", _say get "gizliComel", _say get "direnen", _say get "gorusYok", _say get "yakin", _say get "serbest"
                ];
            };
            { _say set [_x, 0]; } forEach (keys _say);
        };
    };
};
true
