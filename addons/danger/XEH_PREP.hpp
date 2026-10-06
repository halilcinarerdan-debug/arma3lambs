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
PREP(tehditBakis);
PREP(havaFarkindalik);
PREP(olumBolgesi);
PREP(pusuKarsi);
PREP(baskiTufekci);
PREP(yanGuvenlik);
PREP(noktaEleman);
PREP(yetimKatil);
PREP(panikFelc);
PREP(gizliAlgi);
PREP(formSet);
PREP(mekanizeIzle);
PREP(aracMedevac);
PREP(tehditIzle);
PREP(tehditOlay);
PREP(haltKur);
PREP(gozcuRto);
PREP(tarafSecim);
PREP(iedFarkindalik);
PREP(sonDirenis);
PREP(toparlan);
PREP(hq);
PREP(hqTakviye);
PREP(hqEmir);
PREP(hqMedevac);
PREP(hqIstihbarat);
PREP(hqKanat);
PREP(hqFeint);
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
// CBA AYARLARI (v8.40): taraf basina DOKTRIN PROFILI secimi (fnc_doktrin okur). Sunucu ayari: sunucu degeri tum makinelerde gecerli.
//   "OTO" = eskisi gibi fraksiyon adindan eslestir (fnc_doktrin haritasi); digerleri o taraftaki TUM AI gruplarini o profile zorlar.
// ===========================================================================
// !! preStart'ta CBA ayar altyapisi (CBA_settings_default) YOK: addSetting orada motor cokmesine yol acti (RPT 2829485b, ACCESS_VIOLATION). Yalniz altyapi hazirsa (preInit) kaydet.
if (!isNil "CBA_fnc_addSetting" && {!isNil "CBA_settings_default"}) then {
    private _profiller = ["OTO", "GENEL", "USMC", "ABD", "RUS", "CHN", "PESHMERGA", "DUZENSIZ"];
    private _etiketler = [
        "OTO (fraksiyondan)", "GENEL (taban)", "USMC", "ABD / NATO", "RUS (motorlu piyade)", "CHN (PLA)", "PESHMERGA", "DUZENSIZ (Taliban-tipi, pusu / vur-kac)"
    ];
    {
        _x params ["_degisken", "_ad"];
        [
            _degisken, "LIST",
            [format ["Doktrin profili: %1", _ad], "OTO: fraksiyon adindan eslestirir. Baska secim: bu taraftaki tum AI gruplari o profili kullanir (assaultM, bound, retreat, pusu, teslim ...). Kumanda (HQ) modulunden bagimsizdir."],
            ["LAMBS Danger", "ELITE doktrin"],
            [_profiller, _etiketler, 0],
            1
        ] call CBA_fnc_addSetting;
    } forEach [
        ["lambs_danger_doktrinWest", "BLUFOR (west)"],
        ["lambs_danger_doktrinEast", "OPFOR (east)"],
        ["lambs_danger_doktrinInd", "INDEPENDENT"]
    ];
    // v8.86: taraf secimi — hangi tarafta ELITE (LAMBS komutan + fork izleyicileri) aktif olsun; kapali taraf vanilla AI gibi davranir (oyuncular o tarafta ise)
    {
        _x params ["_degisken", "_ad", "_vars"];
        [
            _degisken, "CHECKBOX",
            [format ["ELITE aktif: %1", _ad], "Isaretli degilse bu taraftaki TUM AI gruplari (oyunculu gruptaki botlar dahil) LAMBS FSM'den ve fork izleyicilerinden cikarilir."],
            ["LAMBS Danger", "ELITE taraf secimi"],
            _vars,
            1
        ] call CBA_fnc_addSetting;
    } forEach [
        ["lambs_danger_aktifWest", "BLUFOR (west)", true],
        ["lambs_danger_aktifEast", "OPFOR (east)", true],
        ["lambs_danger_aktifInd", "INDEPENDENT", true],
        ["lambs_danger_aktifCiv", "SIVIL (civilian)", false]
    ];
    diag_log "[ELITE-CBA] doktrin ayarlari kaydedildi (CBA Addon Options > LAMBS Danger > ELITE doktrin: west / east / independent)";
} else {
    diag_log "[ELITE-CBA] ayar altyapisi bu asamada yok (preStart'ta normal; preInit'te 'kaydedildi' satiri gelmeli)";
};

// ===========================================================================
// ELITE-BOOT — dagitim dogrulamasi + watchdog'lari ilk temasi beklemeden baslat
// (bu dosya XEH_preInit'e include edilir: asagidaki satirlar acilista RPT'ye yazar,
//  LAMBS debug acik olmasa da gorunur)
// ===========================================================================
diag_log "[ELITE-BOOT] lambs_danger ELITE build v8.90-KALIBRASYON (v8.90: optiksiz birim aimingAccuracy x0.75 + rpt_ozet --kayip; gerceklik arastirmasi kaynaklar_doktrin/arastirma_gerceklik; v8.89: lider telsiz kabul + DELAY/hide ates kesme duzeltmesi + HQ tahta logu taraf basina; v8.88: doAssaultSpeed overlay - arac icindekilere forceSpeed uygulanmaz; v8.87: mekanize surucu forceSpeed sifirlama + hiz ozeti; v8.86: CBA taraf secimi - ELITE hangi tarafta aktif; v8.85: TCCC hekimi bounding emirlerinden muaf, AI surukleme varsayilan kapali; v8.84: DIAMOND yalniz >= 4 aracli acik arazi yaklasma yuruyusunde; v8.83: roket dustu + duman tehdit tepkisi (arac murettebati dahil), halt (slot kovalama kesici), ileri gozcu + RTO, DIAMOND kaldirildi, UGL HE yukleme, AI surukleme devre disi; v8.82: aracli medevac (APC/arac yaralilari toplama noktasina tasir), panik disableAI sizinti duzeltmesi, mekanize duzeltici 100 m + FULL hiz; v8.81: AI hekim suruklemede Zeus ekranina dusen Release yakalayicisi kaldirilir; v8.80: formasyon yazma hakemi formSet, mekanize dur-kalk izleyici + COLUMN, TCCC suruklem / iptal logu; v8.79: HEMTT lint temizligi (count/not/select/pi/pushBackUnique), davranis ayni; v8.78: HEMTT SPE2 koku: checkVisibility [..] -> lineIntersects; v8.77: gizliAlgi HEMTT SPE2 sozdizimi sadelestirildi; v8.76: TCCC ayni hekim ayni anda coklu yarali atamasi duzeltildi; v8.75: oyuncunun ayak sesi + el feneri / IR lazer algisi; v8.74: panik ve bilgi sisi varsayilanlari oyuncu karsisinda hafifletildi; v8.73: panik/felc - donma, kor ates, kacis (LAMBS doPanic entegre); v8.72: HQ istihbarat sisli (telsiz sarti, gecikme, belirsizlik, kayip rapor), retreat komut-ezme duzeltmesi; v8.71: buddy bagi sakinde lider hareket+45 sn bekler, 8+ kisi limit 35 m; v8.70: BOSTA-HAREKET logu yuruyen askerin hedef modu + hangi script; v8.69: acik arazi bounding 8+ kisi WEDGE, BAYRAK-TAKILI yalniz ayni bayrak kumesinde, nokta elemani neden ozeti; v8.68: bounding 0.5 sn formasyon zorlamasi taktik formasyonunu ezmez; v8.67: tek kalan askerler telsiz/yakinlik ile diger squad a katilir, formasyon hakemi (taktik formasyonu 25 sn korunur), HQ takviye bounding/uzak temas grubunu da kullanir; v8.66: traveling overwatch nokta elemani; v8.65: hareket halinde yan koruma + arka emniyet gozetleme; v8.64: MG yoksa baski tufekcisi atamasi; v8.63: hucum oncesi bastirma penceresi; v8.62: UGL kullanim sikligi + neden-atmadi sayaci [UGL-OZET]; v8.61: LAMBS taktik zamanlayicisi formasyon geri yazmaz (Assault / Suppress / Flank / Attack / Garrison / Hide); v8.60: olum bolgesi hafizasi + rota gozcusu, karsi pusu kurali, HQ otomatik; ZEKA-* loglari; v8.59: IED yok olunca kacis iptal; v8.58: IED grubu felc etmez: yalniz EOD + 2 guvenlik elemani, grubun gerisi devam eder; v8.57: EOD imha zari (beceri / kit / cihaz / baski), basarisizlikta iptal + patlatma, EOD buddy disi, kit kurali; v8.56: garrison cagri oncesi / sonrasi / 4-12-30 sn asker bazli ici-disi logu; v8.55: yakinlik tetikli IED icin kontrollu patlatma (standoff), calisma kesilme nedeni logu; v8.54: IED cevre noktasi radyal (askerler IED uzerinden yurumez), hava egik mesafe zarfi, garrison sonrasi acikta kalanlar siper; v8.53: hava + IED teshis loglari: NABIZ, KARAR, ELE, ATLA, GOZLEM, IMHA, CEVRE, son-adim bekcisi; v8.52: IED cevre emniyeti 360 derece + yaricap x6 + sadece yakinlik tetikli komsu engeller, hava KARAR teshis logu + YERE-YAT; v8.51: ATP 3-01.8 hava ates disiplini + toplu ates + onculuk, IED yaricap config, watchdog bekcisi; v8.50e: kumelenmis IED sirayla imha, ikincil cihaz kurali daraldi; v8.50d: EOD IED imha yaklasmasi duzeltildi; v8.50c: IED temasta yere yat + uzaklas, ikincil cihaz kontrolu, yakinlik tetikli IED, tek is, tarama merkezi EOD; v8.50b: EOD imha icin ACE_DefusalKit / ToolKit sart; v8.50a: hava watchdog coktu - getFriend yan hatasi tani logunda (RPT line 54), duzeltildi; v8.50: IED sistemi ACE EOD (explosiveSpecialist / ACE_isEOD) entegrasyonu: erken tespit 90 m, EOD imha eder, digerleri acilir, taktik kilidi gecilir; hava farkindaligi: bilgi esigi 0.4, bounding gruplar da tepki verir, [HAVA-FARK-TANI] teshis logu; tacticsHold / tacticsHide eski geri-verme zamanlayicisi bounding / retreat kilidini silmez; formasyon felci: LAMBS taktik formasyonuna 60 sn karismama + degisim sonrasi 60 sn bekleme + [FORM-DEGISIM] logu; bounding yeniden baslatma debounce 8 sn; buddy bagi ilerleme kontrolu + 120 sn geri cekilme; preStart cokmesi duzeltildi: CBA ayari yalniz preInit; CBA ayari: west / east / independent icin doktrin profili secimi; siper secimi: ayni noktaya yigilma cezasi + coverHug dost mesafesi 2.5 m; formasyon yon histerezisi: setFormDir sapma>35 ve 40 sn + komutan formasyon 25 sn + bastirilmis grupta dokunma yok; kumanda feint modulu (MCWP 3-11.1) + toparlanma dagilan sayimi; rota ara nokta zinciri + kapi yanindan yigilma / zit koseli oda girisi; pusu: security unsuru + cogunluk kill zone + cok buyuk dusman iptali + pusu sonrasi toparlanma; Zeus modulu CfgPatches units[] duzeltmesi + retreat gorus bitisi + yon degistirme + toparlanma modulu (consolidate and reorganize) + kanat ates kaydirma; Zeus modulu ile acilan HQ: istihbarat agi + kanat manevrasi + takviye; HQ cekirdegi + PUSH retreat sonrasi kilitli + cekilme dusman hafizasi + jest/callout susturma + kale savunmasi + retreat sonrasi toparlanma + retreat her sicramada forceSpeed sifirla + TAKILI AI bayraklari + sivil / dost / esir koruma + bina: rol / etaj + peek + stealth flas + donus +%15 + fieldCraft hata duzeltmesi + iceride geride durma + muzzle flash riski + iceride atis pozisyonu: dar aci + pencereden geride + retreat takilma tanisi + kademeli mudahale + retreat: uzak mesafede toplu kosu + retreat kosan sert ayakta durus + siper-yapis tanisi + moral + teslimiyet + yorgunluk duyarli atilim + spawn / duran grupta formasyon sirasi duzenlemesi yok + coverHug v2 hassas siper + sakin formasyon + telsiz tanisi + yakin mesafe tabani + saglikci tasmasi + temas kesme gizli ters yon + DUZENSIZ/Taliban doktrini + yeni birimlere varsayilan beceri + yaprak arkasi gorus kirici + guclu debug + toplu test karnesi + ortam beceri dususu: isik + NVG/termal + sis + yagmur + retreat ek sicrama adimi + saglik / anomali izleyicisi + rpt_ozet --grup / --anomali + arazi bilinci: komutan hakim nokta + bireysel arazi kivrimi + kamuflaj bilinci + ufuk cizgisi + pusu davranisi + ates emri ROE + sis 3 atici genis perde + erken varista COMBAT + retreat: baski altinda once siper + baski altinda sicrama erken cikis + CAGRI log kisma + taktik rota planlama v1 (ortulu yaklasma acisi) + retreat ek sicramalar + kapsama lideri doStop + retreat sicrama penceresi mesafeye gore 12-26 sn + grup olay mesajlari + retreat birim duzeyi LAMBS kapatma + bounding spawn kapsam hatasi duzeltildi + siper analizi v2 faz1 + global doktrin cercevesi: profil + kalitim + fnc_dk + arbitraj tum taktiklerde + rpt_ozet + lint + hareket arbitraji taktik kilidi + retreat sirasinda LAMBS reaksiyon kapali + bomba tepki 0.2 sn tarama + el bombasi inis noktasi tahmini + komutan bound takibi + UGL uzak mesafe/rezerv + siper hedefli retreat + moveAssist derleme hatasi + UGL salvo arguman + hucum esigi 45 m + overwatch kurulum 5 sn + RHS el bombasi shotgrenade tespiti + duvar koruma 15 sn + CAGRI JEST KOMUT logu + DURUM komut/anim/katsayi + el bombasi genis tani + allMissionObjects tarama + baski altinda acikta HOLD yerine DELAY + bound ekip dengesi + BND-CIKIS logu + 250-500 m BOUNDING + retreat doStop sadece varanlar + PATH acik + durum+doktrin gozlemcisi + donus hizi dogrudan uygulama + el bombasi tarama yaricapi grup boyu + DELAY/take cover spam kilidi + el bombasi tani logu + kucuk ekip kacmaz DELAY + kisa retreat atilimi + ates hatti kapali (felc) + komutan temasta beklemez + ustunken 60 m ustu BOUNDING + bounding ekip dönüşümlü + UGL hat kontrolu gevsetildi + donus hizi senkron + retreat doStop + UGL-TESPIT tani logu + UGL magazineWell duzeltmesi + taktikte UGL + arka guvenlik + hile kapatma + mesafeye gore bound/cekilme boyu + ates hatti yan adimi felc etmez + sikisma adimi sadece sakin intikal + spam kesildi: jest 45 sn + komutan bekle sogumasi + formasyon histerezisi: arazi Schmitt + mesafe bandi + 90 sn bekleme + uzun bound + komutan arkada kosmaz + cekilme sonrasi kilit + atis guvenligi RPG/UGL + karar+formasyon istikrari + tek kalan saklan + TCCC fix + once siper sonra ates + TCCC + saha ustaligi + ates hatti + hizli retreat + donus x1.2 + duvar korumasi + sikisma + komutan formasyon + lider arkada) yuklendi (XEH_PREP preInit)";
[{
    // HER makinede: Zeus'la yaratilan AI'lar istemcide yerel olur; watchdog'lar yalnizca YEREL gruplara dokunur
    if (true) then {
        private _fns = [
            "tactics", "commanderAssess", "tacticsBounding", "tacticsRetreat", "tacticsEvadeArmor", "tacticsATEngage",
            "tacticsBreakContact", "roleStation", "buddyBond", "dispersion", "reloadCover", "grenadeAwareness",
            "leaderSync", "firedHub", "soundAwareness", "cqbReflex", "isSniper", "sniperTeam", "buildingClear", "buildingClearRun", "coverHug", "rpgReaction", "fireSupport", "buddyDebug", "tacticalUGL", "rotaPlan", "pusu", "ufukMu", "araziAnaliz", "kamuflaj", "saglik", "ortamSkill", "yaprakGorus", "varsayilanSkill", "medicTasma", "moral", "roeGuard", "tehditBakis", "havaFarkindalik", "olumBolgesi", "pusuKarsi", "baskiTufekci", "yanGuvenlik", "noktaEleman", "yetimKatil", "panikFelc", "gizliAlgi", "formSet", "mekanizeIzle", "aracMedevac", "tehditIzle", "tehditOlay", "haltKur", "gozcuRto", "tarafSecim", "iedFarkindalik", "sonDirenis", "toparlan", "hq", "hqTakviye", "hqEmir", "hqMedevac", "hqIstihbarat", "hqKanat", "hqFeint", "tacticalSmoke", "getUnitRole", "buddyPairs", "commanderFormation", "moveAssist", "fireLine", "tccc", "fieldCraft", "atisGuvenli", "rearGuard", "uglMags", "durumLog", "doktrin", "dk", "olayGonder", "olay"
        ];
        diag_log format [
            "[ELITE-BOOT] makine: isServer=%1 hasInterface=%2 | fonksiyonlar: %3",
            isServer, hasInterface,
            _fns apply {format ["%1=%2", _x, !isNil (format ["lambs_danger_fnc_%1", _x])]}
        ];

        // watchdog'lar ilk temasta degil, acilista baslasin
        {
            [] call (missionNamespace getVariable [format ["lambs_danger_fnc_%1", _x], {false}]);
        } forEach ["firedHub", "buddyDebug", "dispersion", "buddyBond", "leaderSync", "roleStation", "reloadCover", "grenadeAwareness", "cqbReflex", "sniperTeam", "buildingClear", "coverHug", "fireSupport", "commanderFormation", "moveAssist", "fireLine", "tccc", "fieldCraft", "rearGuard", "durumLog", "olay", "pusu", "kamuflaj", "saglik", "ortamSkill", "yaprakGorus", "varsayilanSkill", "medicTasma", "moral", "roeGuard", "tehditBakis", "havaFarkindalik", "iedFarkindalik", "olumBolgesi", "baskiTufekci", "yanGuvenlik", "noktaEleman", "yetimKatil", "panikFelc", "gizliAlgi", "mekanizeIzle", "aracMedevac", "haltKur", "gozcuRto", "tarafSecim", "hq"];

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
