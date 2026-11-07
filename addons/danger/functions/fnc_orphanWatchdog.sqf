#include "script_component.hpp"
/*
 * Author: Cinar (ELITE fork)
 * YETIM ASKER TOPLAMA (orphan watchdog) — v8.365'te CANLANDIRILDI (eski surum hicbir yerden baslatilmiyordu). Amac: hicbir ELITE sistemin yonetmedigi, lider/grubundan kopmus tek askeri gruba geri cagirmak.
 *
 * NEDEN GEREKLI: Arma AI'si tikanma / yol bulamama / eski bir doMove emrinden sonra bir askeri liderinden onlarca metre geride "unutabilir". Formasyon motoru bu askeri her zaman geri getirmez
 *   (askerin kendi emri varsa). TC 3-21.76 / MCWP 3-11.2: ekip uyeleri gorsel/ses temasini korur (SAYISAL_ESIKLER_KAYNAK_TABLOSU: hareket araliklari 10-50 m, kaynak: RH 4266-4305); 40 m [T].
 *
 * ESKI SURUMUN SORUNU (canlandirirken giderildi): eskiden 'forceMove' ve gorev degiskenlerini SILIYORDU. Bugun 'forceMove' 88 yerde "bu asker bilincli bir emir altinda" bayragi (hekim, mermi tasiyici, nobetci,
 *   mevzi, garnizon, FO, kovan ...) -> temizlemek tum o sistemleri bozardi. Yeni kural: AMACI OLAN ASKERE HIC DOKUNULMAZ; yalniz hicbir bayragi olmayan askere doFollow.
 *
 * DOKUNULMAYAN GRUPLAR: oyuncu lideri, yerel olmayan, bounding / peel / retreat / evade / temas kes / taktik yurutuyor, temas ya da taze komutan karari (45 sn), gorev atanmis (lambs_danger_gorev dolu),
 *   plan aktif, mevzide / hendekte, garnizon, gozetleme nobeti, oyuncu komutasi, ELITE kapali (disableGroupAI), COMBAT davranisi, lider aracta.
 * DOKUNULMAYAN ASKERLER: olu / aracta / oyuncu / esir (captive, teslim) / yarali ya da baygin / hekim / forceMove / TCCC / mermi tasiyici / statik mevzi gorevi / kovan / keskin nisanci takimi /
 *   150 m icinde dusman / hasar > 0.3.
 * SABIR: asker liderden >= 40 m uzakta ve YUKARIDAKILERIN HICBIRI yokken ilk tespitten sonra >= 12 sn (fiilen 3. taramada, ~16 sn) hala ayni durumdaysa cagrilir (gecici sapmalar ve yol bulma beklenir; arada herhangi bir muafiyet olursa sayac sifirlanir).
 *   Cagri sonrasi ayni askere 30 sn yeniden dokunulmaz. Tarama basina en fazla 6 asker (sunucu yuku).
 * Sadece sunucuda. Kapatma: lambs_danger_orphanOff = true / CBA 'Yetim asker toplama'. Log: [YETIM-TOPLA] (ilk 40) + 120 sn ozeti.
 *
 * Arguments: None
 * Return Value: Baslatildi mi <BOOL>
 * Public: No
*/

if (!isServer) exitWith {false};
if (!isNil "lambs_danger_orphanStarted") exitWith {false};
lambs_danger_orphanStarted = true;

diag_log "[YETIM-TOPLA] yetim asker toplama watchdog'u baslatildi (v8.365 canlandirma): gorev / mevzi / hekim / forceMove bayragi olmayan, liderden >= 40 m kopuk asker ~16 sn ayni ise doFollow";

private _calis = {
    missionNamespace setVariable ["lambs_danger_orphanAdim", "basladi"];
    private _aralik = 8;       // tarama (sn)
    private _uzak = 40;        // liderden bu kadar uzaktaysa yetim adayi (m)
    private _dusmanM = 150;    // bu mesafede dusman varsa dokunma
    private _logN = 0;
    private _topN = 0;
    private _ozetT = time + 120;
    private _gorev = ["", "MANEVRA"];   // bos ya da genel manevra: ELITE gorev atamamis
    while {true} do {
        sleep _aralik;
        missionNamespace setVariable ["lambs_danger_orphanAdim", "tarama"];
        if (missionNamespace getVariable ["lambs_danger_orphanOff", false] || {!(missionNamespace getVariable ["lambs_danger_orphanAktif", true])}) then { continue };
        private _butce = 6;
        {
            private _g = _x;
            if (_butce <= 0) exitWith {};
            if (isNull _g || {!local _g}) then { continue };
            private _l = leader _g;
            if (isNull _l || {isPlayer _l} || {!alive _l} || {!isNull objectParent _l}) then { continue };
            if ((count (units _g)) < 2) then { continue };
            // ---- grup duzeyi muafiyet ----
            if (
                (_g getVariable [QGVAR(isBounding), false]) || {_g getVariable [QGVAR(isPeeling), false]} || {_g getVariable [QGVAR(isRetreating), false]}
                || {_g getVariable [QGVAR(isEvading), false]} || {_g getVariable [QGVAR(isBreakingContact), false]} || {_g getVariable [QGVAR(isExecutingTactic), false]}
                || {_g getVariable [QGVAR(disableGroupAI), false]} || {_g getVariable ["lambs_danger_disableGroupAI", false]}
                || {(_g getVariable [QGVAR(contact), 0]) > time} || {(time - (_g getVariable [QGVAR(cmdSonKararZaman), -999])) < 45}
                || {!((_g getVariable ["lambs_danger_gorev", ""]) in _gorev)} || {_g getVariable ["lambs_danger_planAktif", false]}
                || {_g getVariable ["lambs_danger_oyuncuKomuta", false]} || {([_g] call FUNC(mevziDeMi))}
                || {(_g getVariable ["lambs_danger_garnizonAlt", ""]) isNotEqualTo ""} || {(_g getVariable ["lambs_danger_gozetleme", ""]) isNotEqualTo ""}
                || {_g getVariable [QGVAR(sniperTeam), false]} || {(behaviour _l) isEqualTo "COMBAT"}
            ) then { continue };

            private _lp = getPosATL _l;
            {
                private _u = _x;
                if (_butce <= 0) exitWith {};
                if (_u isEqualTo _l || {!alive _u} || {isPlayer _u} || {!isNull objectParent _u}) then { continue };
                // ---- asker duzeyi muafiyet: amaci olan askere dokunma ----
                if (
                    captive _u || {_u getVariable [QGVAR(teslimOldu), false]} || {!((lifeState _u) in ["HEALTHY", "INJURED"])} || {_u getUnitTrait "medic"} || {(damage _u) > 0.3}
                    || {!isNil {_u getVariable QGVAR(forceMove)}} || {!isNil {_u getVariable QGVAR(tcccBy)}} || {time < (_u getVariable [QGVAR(tcccBusy), 0])}
                    || {_u getVariable [QGVAR(cephaneAliciBusy), false]} || {!isNil {_u getVariable QGVAR(mevziStatikGorev)}} || {!isNil {_u getVariable QGVAR(rearGuardPos)}}
                    || {(time - (_u getVariable [QGVAR(yetimT), -999])) < 30} || {!(_u checkAIFeature "PATH")}
                ) then { _u setVariable [QGVAR(yetimGor), nil]; continue };
                if ((_u distance2D _lp) < _uzak) then { _u setVariable [QGVAR(yetimGor), nil]; continue };
                private _dusman = _u findNearestEnemy _u;
                if (!isNull _dusman && {(_u distance2D _dusman) < _dusmanM}) then { _u setVariable [QGVAR(yetimGor), nil]; continue };

                // SABIR: ilk taramada yalniz isaretle; isaretten >= 12 sn sonra (3. tarama) cagir. 30 sn'den eski isaret BAYAT (grup arada muaf kalmis olabilir) -> yeniden baslar
                private _gor = _u getVariable [QGVAR(yetimGor), -1];
                if (_gor < 0 || {(time - _gor) > 30}) then { _u setVariable [QGVAR(yetimGor), time]; continue };
                if ((time - _gor) < (_aralik * 1.5)) then { continue };

                // ---- YETIM: gruba cagir ----
                _u setVariable [QGVAR(yetimGor), nil];
                _u setVariable [QGVAR(yetimT), time];
                _u setUnitPos "AUTO";
                _u forceSpeed -1;
                _u doFollow _l;
                _butce = _butce - 1;
                _topN = _topN + 1;
                if (_logN < 40) then {
                    _logN = _logN + 1;
                    diag_log format ["[YETIM-TOPLA] %1 | %2 (%3) liderden %4 m kopuk, ~16 sndir bayraksiz -> doFollow", groupId _g, name _u, typeOf _u, round (_u distance2D _lp)];
                };
            } forEach (units _g);
        } forEach allGroups;
        if (time > _ozetT) then {
            _ozetT = time + 120;
            if (_topN > 0) then { diag_log format ["[YETIM-TOPLA] 120 sn ozeti: toplam cagrilan %1", _topN]; };
        };
    };
};

// yeniden baslatma korumasi: dongu olurse 15 sn sonra yeniden (diger watchdog'lardaki gibi)
[_calis] spawn {
    params ["_fn"];
    while {true} do {
        private _h = [] spawn _fn;
        waitUntil { sleep 5; scriptDone _h };
        diag_log "[YETIM-TOPLA] watchdog donguden cikti, 15 sn sonra yeniden baslatiliyor";
        sleep 15;
    };
};
true
