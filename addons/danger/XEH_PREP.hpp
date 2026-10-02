// ===========================================================================
// NE BULACAKSIN — PREP KAYIT KONTROLU
// ===========================================================================
// Yeni fonksiyon `tacticsBounding` burada PREP edilmeli.
// Eksikse: RPT'de "lambs_danger_fnc_tacticsBounding is not defined" hatasi.
// Dogruysa : fnc_tactics.sqf'ten cagirabilirsin.
// Kontrol  : HEMTT build sonrasi ".hemttout" icinde
//            "fnc_tacticsBounding.sqf" ciktisi var mi?
// ===========================================================================

PREP(brain);
PREP(brainAdjust);
PREP(brainAssess);
PREP(brainEngage);
PREP(brainForced);
PREP(brainHide);
PREP(brainReact);
PREP(brainVehicle);
PREP(fsmAllowAnimation);
PREP(isForced);
PREP(isForcedExit);
PREP(isLeader);

PREP(contact);

PREP(tactics);
PREP(commanderAssess);
PREP(splitFireTeams);
PREP(getUnitRole);
PREP(buddyPairs);
PREP(tacticalSmoke);
PREP(classifyVehicle);
PREP(armorSupport);
PREP(tacticsRetreat);
PREP(tacticsPeel);
PREP(tacticsEvadeArmor);
PREP(tacticsATEngage);
PREP(tacticsBreakContact);
PREP(dispersion);
PREP(buddyBond);
PREP(leaderSync);
PREP(firedHub);
PREP(soundAwareness);
PREP(cqbReflex);
PREP(isSniper);
PREP(sniperTeam);
PREP(buildingClear);
PREP(buildingClearRun);
PREP(coverHug);
PREP(rpgReaction);
PREP(fireSupport);
PREP(buddyDebug);
PREP(hasUGL);
PREP(roleStation);
PREP(reloadCover);
PREP(grenadeAwareness);
PREP(tacticalUGL);
PREP(isATUnit);
PREP(atFire);
PREP(orphanWatchdog);
PREP(tacticsAssault);
PREP(tacticsBounding);
PREP(selectFormation);
PREP(commanderFormation);
PREP(moveAssist);
PREP(fireLine);
PREP(tccc);
PREP(fieldCraft);
PREP(atisGuvenli);
PREP(rearGuard);
PREP(uglMags);
PREP(durumLog);
PREP(doktrin);
PREP(dk);
PREP(olayGonder);
PREP(olay);
PREP(rotaPlan);
PREP(pusu);
PREP(ufukMu);
PREP(araziAnaliz);
PREP(kamuflaj);
PREP(saglik);
PREP(ortamSkill);
PREP(yaprakGorus);
PREP(varsayilanSkill);
PREP(medicTasma);
PREP(moral);
PREP(roeGuard);
PREP(sonDirenis);
PREP(hq);
PREP(hqTakviye);
PREP(hqEmir);
PREP(hqMedevac);
PREP(hqIstihbarat);
PREP(hqKanat);
PREP(tacticsAssess);
PREP(tacticsAttack);
PREP(tacticsCQB);
PREP(tacticsFlank);
PREP(tacticsGarrison);
PREP(tacticsHide);
PREP(tacticsHold);
PREP(tacticsProfiles);
PREP(tacticsReinforce);
PREP(tacticsSuppress);
PREP(eliteCover);

SUBPREP(ZeusModules,moduleConfigureGroupAI);
SUBPREP(ZeusModules,moduleDisableAI);
SUBPREP(ZeusModules,moduleSetRadio);
SUBPREP(ZeusModules,moduleKumanda);

SUBPREP(ZEN,setDisableAI);
SUBPREP(ZEN,setDisableGroupAI);
SUBPREP(ZEN,setHasRadio);
SUBPREP(ZEN,setReinforcement);
SUBPREP(ZEN,showHasRadio);
SUBPREP(ZEN,showReinforcement);
SUBPREP(ZEN,showSetDisableAI);
SUBPREP(ZEN,showSetDisableGroupAI);

// ===========================================================================
// ELITE-BOOT — dagitim dogrulamasi + watchdog'lari ilk temasi beklemeden baslat
// (bu dosya XEH_preInit'e include edilir: asagidaki satirlar acilista RPT'ye yazar,
//  LAMBS debug acik olmasa da gorunur)
// ===========================================================================
diag_log "[ELITE-BOOT] lambs_danger ELITE build v8.33-KOMUTAN (Zeus modulu ile acilan HQ: istihbarat agi + kanat manevrasi + takviye; HQ cekirdegi + PUSH retreat sonrasi kilitli + cekilme dusman hafizasi + jest/callout susturma + kale savunmasi + retreat sonrasi toparlanma + retreat her sicramada forceSpeed sifirla + TAKILI AI bayraklari + sivil / dost / esir koruma + bina: rol / etaj + peek + stealth flas + donus +%15 + fieldCraft hata duzeltmesi + iceride geride durma + muzzle flash riski + iceride atis pozisyonu: dar aci + pencereden geride + retreat takilma tanisi + kademeli mudahale + retreat: uzak mesafede toplu kosu + retreat kosan sert ayakta durus + siper-yapis tanisi + moral + teslimiyet + yorgunluk duyarli atilim + spawn / duran grupta formasyon sirasi duzenlemesi yok + coverHug v2 hassas siper + sakin formasyon + telsiz tanisi + yakin mesafe tabani + saglikci tasmasi + temas kesme gizli ters yon + DUZENSIZ/Taliban doktrini + yeni birimlere varsayilan beceri + yaprak arkasi gorus kirici + guclu debug + toplu test karnesi + ortam beceri dususu: isik + NVG/termal + sis + yagmur + retreat ek sicrama adimi + saglik / anomali izleyicisi + rpt_ozet --grup / --anomali + arazi bilinci: komutan hakim nokta + bireysel arazi kivrimi + kamuflaj bilinci + ufuk cizgisi + pusu davranisi + ates emri ROE + sis 3 atici genis perde + erken varista COMBAT + retreat: baski altinda once siper + baski altinda sicrama erken cikis + CAGRI log kisma + taktik rota planlama v1 (ortulu yaklasma acisi) + retreat ek sicramalar + kapsama lideri doStop + retreat sicrama penceresi mesafeye gore 12-26 sn + grup olay mesajlari + retreat birim duzeyi LAMBS kapatma + bounding spawn kapsam hatasi duzeltildi + siper analizi v2 faz1 + global doktrin cercevesi: profil + kalitim + fnc_dk + arbitraj tum taktiklerde + rpt_ozet + lint + hareket arbitraji taktik kilidi + retreat sirasinda LAMBS reaksiyon kapali + bomba tepki 0.2 sn tarama + el bombasi inis noktasi tahmini + komutan bound takibi + UGL uzak mesafe/rezerv + siper hedefli retreat + moveAssist derleme hatasi + UGL salvo arguman + hucum esigi 45 m + overwatch kurulum 5 sn + RHS el bombasi shotgrenade tespiti + duvar koruma 15 sn + CAGRI JEST KOMUT logu + DURUM komut/anim/katsayi + el bombasi genis tani + allMissionObjects tarama + baski altinda acikta HOLD yerine DELAY + bound ekip dengesi + BND-CIKIS logu + 250-500 m BOUNDING + retreat doStop sadece varanlar + PATH acik + durum+doktrin gozlemcisi + donus hizi dogrudan uygulama + el bombasi tarama yaricapi grup boyu + DELAY/take cover spam kilidi + el bombasi tani logu + kucuk ekip kacmaz DELAY + kisa retreat atilimi + ates hatti kapali (felc) + komutan temasta beklemez + ustunken 60 m ustu BOUNDING + bounding ekip dönüşümlü + UGL hat kontrolu gevsetildi + donus hizi senkron + retreat doStop + UGL-TESPIT tani logu + UGL magazineWell duzeltmesi + taktikte UGL + arka guvenlik + hile kapatma + mesafeye gore bound/cekilme boyu + ates hatti yan adimi felc etmez + sikisma adimi sadece sakin intikal + spam kesildi: jest 45 sn + komutan bekle sogumasi + formasyon histerezisi: arazi Schmitt + mesafe bandi + 90 sn bekleme + uzun bound + komutan arkada kosmaz + cekilme sonrasi kilit + atis guvenligi RPG/UGL + karar+formasyon istikrari + tek kalan saklan + TCCC fix + once siper sonra ates + TCCC + saha ustaligi + ates hatti + hizli retreat + donus x1.2 + duvar korumasi + sikisma + komutan formasyon + lider arkada) yuklendi (XEH_PREP preInit)";
[{
    // HER makinede: Zeus'la yaratilan AI'lar istemcide yerel olur; watchdog'lar yalnizca YEREL gruplara dokunur
    if (true) then {
        private _fns = [
            "tactics", "commanderAssess", "tacticsBounding", "tacticsRetreat", "tacticsEvadeArmor", "tacticsATEngage",
            "tacticsBreakContact", "roleStation", "buddyBond", "dispersion", "reloadCover", "grenadeAwareness",
            "leaderSync", "firedHub", "soundAwareness", "cqbReflex", "isSniper", "sniperTeam", "buildingClear", "buildingClearRun", "coverHug", "rpgReaction", "fireSupport", "buddyDebug", "tacticalUGL", "rotaPlan", "pusu", "ufukMu", "araziAnaliz", "kamuflaj", "saglik", "ortamSkill", "yaprakGorus", "varsayilanSkill", "medicTasma", "moral", "roeGuard", "sonDirenis", "hq", "hqTakviye", "hqEmir", "hqMedevac", "hqIstihbarat", "hqKanat", "tacticalSmoke", "getUnitRole", "buddyPairs", "commanderFormation", "moveAssist", "fireLine", "tccc", "fieldCraft", "atisGuvenli", "rearGuard", "uglMags", "durumLog", "doktrin", "dk", "olayGonder", "olay"
        ];
        diag_log format [
            "[ELITE-BOOT] makine: isServer=%1 hasInterface=%2 | fonksiyonlar: %3",
            isServer, hasInterface,
            _fns apply {format ["%1=%2", _x, !isNil (format ["lambs_danger_fnc_%1", _x])]}
        ];

        // watchdog'lar ilk temasta degil, acilista baslasin
        {
            [] call (missionNamespace getVariable [format ["lambs_danger_fnc_%1", _x], {false}]);
        } forEach ["firedHub", "buddyDebug", "dispersion", "buddyBond", "leaderSync", "roleStation", "reloadCover", "grenadeAwareness", "cqbReflex", "sniperTeam", "buildingClear", "coverHug", "fireSupport", "commanderFormation", "moveAssist", "fireLine", "tccc", "fieldCraft", "rearGuard", "durumLog", "olay", "pusu", "kamuflaj", "saglik", "ortamSkill", "yaprakGorus", "varsayilanSkill", "medicTasma", "moral", "roeGuard", "hq"];

        // nabiz: 60 sn'de bir (yerel AI grubu varsa) — temas / taktik bayraklari RPT'de gorunsun
        [] spawn {
            while {true} do {
                sleep 60;
                private _gr = allGroups select {local _x && {!isNull leader _x} && {!isPlayer leader _x} && {({alive _x} count units _x) > 0}};
                if (_gr isNotEqualTo []) then {
                    diag_log format [
                        "[ELITE-HB] t=%1 | yerel AI grup:%2 | temasta:%3 | bounding:%4 retreat:%5 evade:%6 atEngage:%7 breakContact:%8 | disableGroupAI:%9 | lambs_debug:%10",
                        round time, count _gr,
                        {(_x getVariable ["lambs_danger_contact", 0]) > time} count _gr,
                        {_x getVariable ["lambs_danger_isBounding", false]} count _gr,
                        {_x getVariable ["lambs_danger_isRetreating", false]} count _gr,
                        {_x getVariable ["lambs_danger_isEvading", false]} count _gr,
                        {_x getVariable ["lambs_danger_isATEngage", false]} count _gr,
                        {_x getVariable ["lambs_danger_isBreakingContact", false]} count _gr,
                        {_x getVariable ["lambs_danger_disableGroupAI", false]} count _gr,
                        missionNamespace getVariable ["lambs_main_debug_Functions", "ayar yok"]
                    ];
                };
            };
        };
    };
}, [], 8] call CBA_fnc_waitAndExecute;
