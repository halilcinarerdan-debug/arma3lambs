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
PREP(acikSiper);
PREP(perfBisect);
PREP(teslimBirey);
PREP(istiksaf);
PREP(pusuTepki);
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
PREP(liderDevri);
PREP(aracSenkron);
PREP(komutanPlan);
PREP(komutanPlanDongu);
PREP(komutanPlanKapi);
PREP(asistanTur);
PREP(mermiDisiplin);
PREP(grupSunucuDevir);
PREP(telemetri);
PREP(aracTasima);
PREP(taksi);
PREP(ezmeKoruma);
PREP(murettebatKoru);
PREP(objektifGrupSec);
PREP(giyimTani);
PREP(komutanZihin);
PREP(planZirh);
PREP(aracSinif);
PREP(mevziKur);
PREP(kaldirPanel);
PREP(topcuKonumla);
PREP(aracUzak);
PREP(reconArac);
PREP(aracKinSurus);
PREP(aracSurmeTani);
PREP(planZaman);
PREP(topSiper);
PREP(hendekAlani);
PREP(hendekYerles);
PREP(hendekBilinc);
PREP(agacGizlen);
PREP(ihaGozlem);
PREP(ihaEnvanter);
PREP(ihaTip);
PREP(ihaSorti);
PREP(ihaBekle);
PREP(ihaCantaSinif);
PREP(isaretGizle);
PREP(aracSurmeDeney);
PREP(topcuDestek);
PREP(gozetleAta);
PREP(karakolGarnizon);
PREP(hqDestek);
PREP(sinsiGeri);
PREP(gozcuRto);
PREP(tarafSecim);
PREP(cephanePaylas);
PREP(tehlikeAlani);
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

// CEPHE SIMULASYONU (v8.237, Dilim A0): profil cekirdegi (sanal / fiziksel), faction paneli, Personnel Replacement
PREP(cepheInit);
PREP(cepheLog);
PREP(cepheSablon);
PREP(cepheFactionListe);
PREP(cepheProfilYap);
PREP(cepheFaction);
PREP(cepheFizikle);
PREP(cepheSanalla);
PREP(cepheDongu);
PREP(cepheTakviye);
PREP(cepheOlaylar);
PREP(cephePanel);

// v8.239 arac surus A/B testi (AI surucu kok neden)
PREP(surusAB);

// v8.240 STRYKER FFV KOK NEDEN DUZELTMESI: yolcu FFV koltugunda arac surucu emrine uymuyor
PREP(aracDuzBos);
PREP(aracYolcuKoy);
PREP(aracFfvDuzelt);

// v8.242 AT roket paslama (AT asistani -> AT askeri)
PREP(atPaylas);
// v8.243 mevzide mi (hendekteki gruba LAMBS taktikleri / buddy / dagilma / rol istasyonu dokunmasin)
PREP(mevziDeMi);
// v8.244 surucu yenileme (surucu olunca yolcu surucu koltuguna gecer)
PREP(surucuYenile);
// v8.245 uzak hedef icin yol ara nokta zinciri (nakil)
PREP(yolZinciri);
// v8.247 nearTargets nesnesi gercek dusman mi (mantik modulu / bos arac hedef sayilmasin)
PREP(gercekHedef);
// v8.247 motor sesi farkindaligi (arac / heli / ucak motorunu duyma)
PREP(motorSes);
// v8.250 AT yetenegi olmayan arac bilinen dusman tankindan kacar
PREP(aracZirhKac);
// v8.251 tank hedef dagitimi + AT atesine tepki (duman / yer degistirme) + tank koruma
PREP(tankHedefSec);
PREP(tankBakis);
PREP(tankDuello);
PREP(dronTepki);
PREP(topcuAtisHazirla);
PREP(dronSakla);
PREP(tankDron);
PREP(tankIzle);
PREP(aracDuman);
PREP(tankKoru);
PREP(aracAtTepki);
PREP(atAtisIzle);
PREP(tankAtesKontrol);
// v8.252 tank murettebat tamamlama + koltuk degistirme
PREP(tankMurettebat);
// v8.255 tani paketi (olum / hendek / arac terk / topcu dususu loglari; davranis degistirmez)
PREP(tani);
PREP(hendekDurum);
// v8.256 hendek mevzi kilidi + hendek grubu statik silah
PREP(mevziKilit);
PREP(mevziStatik);
// v8.257 mevzi tutulsun mu (taktik fonksiyonu girisi korumasi)
PREP(mevziTutMu);

SUBPREP(ZeusModules,moduleConfigureGroupAI);
SUBPREP(ZeusModules,moduleDisableAI);
SUBPREP(ZeusModules,moduleSetRadio);
SUBPREP(ZeusModules,moduleKumanda);
SUBPREP(ZeusModules,moduleObjektif);
SUBPREP(ZeusModules,modulePlanNokta);
SUBPREP(ZeusModules,moduleGorevAta);
SUBPREP(ZeusModules,moduleKarakol);
SUBPREP(ZeusModules,moduleKarakolGarnizon);
SUBPREP(ZeusModules,moduleGozetleAta);
SUBPREP(ZeusModules,moduleIhaGorev);
SUBPREP(ZeusModules,moduleKarakolKaldir);
SUBPREP(ZeusModules,moduleCephe);
SUBPREP(ZeusModules,moduleSurusAB);
SUBPREP(ZeusModules,moduleTopcuTest);
SUBPREP(ZeusModules,moduleHQ);

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
// CBA AYARLARI — MORAL / TESLIM (v8.259): kategori "ELITE moral / teslim". Sunucu ayari (sunucu degeri tum makinelerde gecerli). Tum esikler TASARIM; fnc_moral okur.
//   Ana anahtar + taraf basina anahtar + FRAKSIYON bazli listeler (virgullu, parca eslesme; Kapali > Acik > taraf + doktrin) + esik slider'lari.
// ===========================================================================
if (!isNil "CBA_fnc_addSetting" && {!isNil "CBA_settings_default"}) then {
    private _katT = ["LAMBS Danger", "ELITE moral / teslim"];
    {
        _x params ["_degisken", "_tip", "_ad", "_ip", "_veri"];
        [_degisken, _tip, [_ad, _ip], _katT, _veri, 1] call CBA_fnc_addSetting;
    } forEach [
        ["lambs_danger_moralV1", "CHECKBOX", "Moral sistemi AKTIF", "Kapaliyken grup morali hesaplanmaz (panik / teslim moral'e bagli olanlar etkilenir).", true],
        ["lambs_danger_teslimV1", "CHECKBOX", "Teslim olma AKTIF (ana anahtar)", "Kapaliyken hicbir taraf teslim olmaz (sonuna kadar savasir).", true],
        ["lambs_danger_teslimWest", "CHECKBOX", "Teslim: BLUFOR (west)", "Isaretli degilse BLUFOR gruplari teslim olmaz (fraksiyon 'Acik' listesi bunu ezer).", true],
        ["lambs_danger_teslimEast", "CHECKBOX", "Teslim: OPFOR (east)", "Isaretli degilse OPFOR gruplari teslim olmaz (fraksiyon 'Acik' listesi bunu ezer).", true],
        ["lambs_danger_teslimInd", "CHECKBOX", "Teslim: INDEPENDENT", "Isaretli degilse INDEPENDENT gruplari teslim olmaz (fraksiyon 'Acik' listesi bunu ezer).", true],
        ["lambs_danger_teslimDuzensiz", "CHECKBOX", "Teslim: duzensiz (isyanci) profiller", "Doktrin profili DUZENSIZ olan fraksiyonlar (taliban, lop_ists, insurgent ...) da teslim olabilir (kayip >= %60 ve 15 sn umutsuzluk sarti). Kapaliyken bu profiller sonuna kadar savasir.", true],
        ["lambs_danger_teslimFraksiyonKapali", "EDITBOX", "Asla teslim olmayan fraksiyonlar", "Virgullu liste, fraksiyon adinin PARCASI (kucuk / buyuk harf onemsiz), ornek: rhs_faction_msv, afou. Bu listedeki fraksiyonlar HICBIR kosulda teslim olmaz (en yuksek oncelik).", ""],
        ["lambs_danger_teslimFraksiyonAcik", "EDITBOX", "Her zaman teslim olabilen fraksiyonlar", "Virgullu liste (parca eslesme). Taraf onay kutusu kapali ya da doktrin 'teslim yok' (DUZENSIZ) olsa bile bu fraksiyonlar teslim olabilir; 'Asla' listesi bunu ezer.", ""],
        ["lambs_danger_teslimMoral", "SLIDER", "Teslim moral esigi", "Grup morali bu degerin altindaysa (diger kosullarla birlikte) teslim. TASARIM v8.275: 0.45 (eski 0.30; moral formulune cokme terimi eklendi).", [0.05, 0.7, 0.45, 2]],
        ["lambs_danger_teslimKayip", "SLIDER", "Teslim icin min. kayip (yuzde)", "Baslangictan kayip orani. TASARIM v8.275: 50 (eski 60).", [30, 95, 50, 0]],
        ["lambs_danger_teslimKalan", "SLIDER", "Teslim icin en cok kalan asker", "Etkin asker sayisi bu kadar ya da daha azsa. TASARIM v8.275: 5 (eski 4).", [1, 10, 5, 0]],
        ["lambs_danger_teslimBaski", "SLIDER", "Teslim icin min. ortalama baski", "Grubun ortalama baskisi (0-1). TASARIM v8.275: 0.30 (eski 0.40).", [0.1, 1, 0.30, 2]],
        ["lambs_danger_teslimMesafe", "SLIDER", "Teslim icin dusman mesafesi (m)", "Bilinen en yakin dusman bu mesafeden yakinsa. TASARIM v8.276: 200 (v8.275: 150, eski 120).", [20, 400, 200, 0]],
        ["lambs_danger_teslimDron", "CHECKBOX", "Teslim: dron muhatap sayilir", "Yakinda (100 m ustu) bilinen piyade yoksa, 450 m icinde dusman dron (IHA) uzerlerindeyse teslim kosulundaki gruplar dronun onunde teslim olabilir. v8.307.", true]
    ];
    diag_log "[ELITE-CBA] moral / teslim ayarlari kaydedildi (CBA Addon Options > LAMBS Danger > ELITE moral / teslim)";
};

// ===========================================================================
// CBA AYARLARI — PUSU / GERILLA KARSITI (v8.308): kategori "ELITE pusu / gerilla". Sunucu ayari.
// ===========================================================================
if (!isNil "CBA_fnc_addSetting" && {!isNil "CBA_settings_default"}) then {
    private _katP = ["LAMBS Danger", "ELITE pusu / gerilla"];
    {
        _x params ["_degisken", "_ad", "_ip"];
        [_degisken, "CHECKBOX", [_ad, _ip], _katP, true, 1] call CBA_fnc_addSetting;
    } forEach [
        ["lambs_danger_pusuTepkiAktif", "Pusuya hizli tepki AKTIF", "Gorunmeyen atici tarafindan vurulan grup hizla COMBAT'a gecer, tahmini atici yonune bakar / bastirma atesi eder, komsulari uyarir (fnc_pusuTepki)."],
        ["lambs_danger_pusuKanatAktif", "Pusu: kanat elemani", "Grup >= 4 ve kayip < %50 ise 2 asker tahmini atici konumunun yanina hizla gider (fnc_istiksaf KANAT)."],
        ["lambs_danger_pusuCagriAktif", "Pusu: konum tahmini + cagri atesi", "Tahmini atici konumuna (ses / parlama / catlama ile, hata payli) topcu / havan HE cagrilir (dost 200 m icinde ise atilmaz, taraf basina 120 sn'de bir)."],
        ["lambs_danger_dronIstiksaf", "Dron: operator yonune kesif", "Temasta olmayan grup >= 4 ise 2 asker dronun geldigi yone (<= 300 m) kesife cikar (fnc_istiksaf ISTIKSAF)."],
        ["lambs_danger_teslimBirey", "Teslim: bireysel (karsilik veremeyen asker)", "Silahi / atilabilir mermisi olmayan ve tehdit altindaki asker tek basina teslim olur (grup teslimiyetinden bagimsiz). fnc_teslimBirey."]
    ];
    diag_log "[ELITE-CBA] pusu / gerilla ayarlari kaydedildi (CBA Addon Options > LAMBS Danger > ELITE pusu / gerilla)";
};

// ===========================================================================
// CBA AYARLARI — DRON SAVUNMASI (v8.307): kategori "ELITE dron savunmasi". Sunucu ayari.
// ===========================================================================
if (!isNil "CBA_fnc_addSetting" && {!isNil "CBA_settings_default"}) then {
    ["lambs_danger_dronKarsiAtes", "CHECKBOX", ["Dron operatorune karsi topcu / havan ATESI", "Dron gorunce ucus izinden tahmin edilen operator / firlatma bolgesine tarafin topcusu / havani HE atar (dost 200 m icinde ise atmaz, 180 sn'de bir). Hile degil: gercek konum bilinmez, geri-yon tahmini kullanilir."], ["LAMBS Danger", "ELITE dron savunmasi"], true, 1] call CBA_fnc_addSetting;
};

// ===========================================================================
// CBA AYARLARI — SAGLIK / TCCC (v8.307): kategori "ELITE saglik / TCCC". Sunucu ayari.
// ===========================================================================
if (!isNil "CBA_fnc_addSetting" && {!isNil "CBA_settings_default"}) then {
    ["lambs_danger_tcccAktif", "CHECKBOX", ["TCCC hekim sistemi AKTIF", "Kapaliyken ELITE hekimleri yaralilara gitmez (fnc_tccc atama yapmaz). ACE'nin kendi AI tedavisi / oyuncu tedavisi etkilenmez. Calisirken de degistirilebilir."], ["LAMBS Danger", "ELITE saglik / TCCC"], true, 1] call CBA_fnc_addSetting;
};

// ===========================================================================
// CBA AYARLARI — ZIRH / MEKANIZE (v8.265): kategori "ELITE zirh / mekanize". Sunucu ayari.
// ===========================================================================
if (!isNil "CBA_fnc_addSetting" && {!isNil "CBA_settings_default"}) then {
    private _katZ = ["LAMBS Danger", "ELITE zirh / mekanize"];
    {
        _x params ["_degisken", "_tip", "_ad", "_ip", "_veri"];
        [_degisken, _tip, [_ad, _ip], _katZ, _veri, 1] call CBA_fnc_addSetting;
    } forEach [
        ["lambs_danger_tankPiyadeV1", "CHECKBOX", "Tank piyade bagi AKTIF", "Hareket fazlarinda (toplanma / recon / nakil / ORP) tank, plan piyadesinin onune sinirdan fazla gecmez, bekler (en cok 300 sn).", true],
        ["lambs_danger_tankPiyadeMesafe", "SLIDER", "Tank piyade bagi mesafesi (m)", "Tank, plan piyadesinin (medyan) objektife mesafesinden en cok bu kadar onde olabilir. TASARIM: 400.", [100, 1000, 400, 0]],
        ["lambs_danger_tankTerkV1", "CHECKBOX", "Hareket edemeyen tank: murettebat terki AKTIF", "Motor / palet hasariyla hareket edemeyen tankta murettebat tekrar tekrar ejekte ediliyorsa (4. geri donus ya da 3 / 60 sn) tanki birakir ve yakindaki dost piyade grubuna katilir.", true],
        ["lambs_danger_tankSenkron", "CHECKBOX", "Tank piyade eskort hiz kuralina (ARAC-SENKRON) girer", "Varsayilan KAPALI (v8.275): tank yakindaki piyade grubuna gore BEKLE / YAVASLA ile kisilmaz (RPT: plan oncesi tank dur-kalkli surunuyordu). Acik: eski davranis (APC / kamyon gibi eskort).", false]
    ];
    diag_log "[ELITE-CBA] zirh / mekanize ayarlari kaydedildi (CBA Addon Options > LAMBS Danger > ELITE zirh / mekanize)";
};

// ===========================================================================
// CBA AYARLARI — BOT BECERISI (v8.289; kullanici: 'cba ayarlarindan botlarin dogruluklarini ayarlayabilelim'): kategori "ELITE bot becerisi". Sunucu ayari.
//   Deger degisince oyuncu olmayan yerel AI'lara hemen yeniden uygulanir (fnc_varsayilanSkill taban degerleri yeniden yazar, carpanlar ust uste binmez).
//   NOT: setSkill degerleri sunucu zorluk ayarlariyla (skillAI / precisionAI) olceklenir; o ayar betikle degismez.
// ===========================================================================
if (!isNil "CBA_fnc_addSetting" && {!isNil "CBA_settings_default"}) then {
    private _katB = ["LAMBS Danger", "ELITE bot becerisi"];
    {
        _x params ["_degisken", "_tip", "_ad", "_ip", "_veri"];
        [_degisken, _tip, [_ad, _ip], _katB, _veri, 1, {
            if (isNil "CBA_missionTime" || {CBA_missionTime < 5}) exitWith {};
            {
                _x setVariable ["lambs_danger_skillAyarli", nil];
                [_x] call (missionNamespace getVariable ["lambs_danger_fnc_varsayilanSkill", {false}]);
            } forEach (allUnits select {local _x && {!isPlayer _x} && {alive _x}});
        }] call CBA_fnc_addSetting;
    } forEach [
        ["lambs_danger_skillVarsayilanV1", "CHECKBOX", "Bot beceri sistemi AKTIF", "Kapaliyken ELITE hicbir AI'ya beceri atamaz (misyonun / Zeus'un verdigi kalir).", true],
        ["lambs_danger_skillIsabetMin", "SLIDER", "Isabet (aimingAccuracy) taban - en dusuk", "Her askere bu aralikta rastgele taban isabet atanir (bireysel fark). TASARIM: 0.70. Sonra optik cezasi, tecrubesiz orani ve carpan uygulanir.", [0.05, 1, 0.70, 2]],
        ["lambs_danger_skillIsabetMax", "SLIDER", "Isabet (aimingAccuracy) taban - en yuksek", "Rastgele taban isabetin ust siniri. TASARIM: 0.88.", [0.05, 1, 0.88, 2]],
        ["lambs_danger_skillIsabetCarpan", "SLIDER", "Isabet carpani", "Taban isabet x bu carpan (tavana kadar). TASARIM: 1.26 (= eski 1.2 x 1.05). 1.0 = carpan yok.", [0.5, 2, 1.26, 2]],
        ["lambs_danger_skillTavanIsabet", "SLIDER", "Isabet TAVANI (insani sinir)", "Hicbir asker bu isabetin ustune cikmaz (kusursuz nisan yok). TASARIM: 0.95.", [0.3, 1, 0.95, 2]],
        ["lambs_danger_skillOptiksizCarpan", "SLIDER", "Optiksiz silah isabet carpani", "Optigi (ACOG / reflex) olmayan askerin isabeti bu carpanla azalir. TASARIM: 0.75 (kalibrasyon arastirmasi). 1.0 = ceza yok.", [0.3, 1, 0.75, 2]],
        ["lambs_danger_skillAcemiOran", "SLIDER", "Tecrubesiz asker orani", "Askerlerin bu orani 'tecrubesiz' sayilir (isabet / titreme azalir). TASARIM: 0.15. 0 = herkes ayni seviyede.", [0, 0.5, 0.15, 2]],
        ["lambs_danger_skillAcemiCarpan", "SLIDER", "Tecrubesiz asker carpani", "Tecrubesiz askerin isabet / titreme carpani. TASARIM: 0.85.", [0.3, 1, 0.85, 2]],
        ["lambs_danger_skillHizMin", "SLIDER", "Nisan hizi (aimingSpeed) taban - en dusuk", "Nisan alma / donus hizi tabani (rastgele aralik). TASARIM: 0.70.", [0.05, 1, 0.70, 2]],
        ["lambs_danger_skillHizMax", "SLIDER", "Nisan hizi (aimingSpeed) taban - en yuksek", "TASARIM: 0.80.", [0.05, 1, 0.80, 2]],
        ["lambs_danger_skillFarkMin", "SLIDER", "Farkindalik (spotDistance / spotTime) taban - en dusuk", "Fark etme MESAFESI ve HIZI (reaksiyon suresi) tabani, rastgele aralik. TASARIM v8.308: 0.85 (eski 0.75). 1.0 = en keskin.", [0.05, 1, 0.85, 2]],
        ["lambs_danger_skillFarkMax", "SLIDER", "Farkindalik (spotDistance / spotTime) taban - en yuksek", "TASARIM v8.308: 0.98 (eski 0.90).", [0.05, 1, 0.98, 2]],
        ["lambs_danger_skillCarpan", "SLIDER", "Nisan hizi carpani", "Taban nisan hizi x bu carpan (en cok 0.95). TASARIM: 1.2.", [0.5, 2, 1.2, 2]],
        ["lambs_danger_tankEkipSkill", "SLIDER", "Tank murettebati beceri tabani", "Tank murettebatinin nisan / gozlem / yeniden doldurma becerileri en az bu degere cikarilir (asla dusurulmez). TASARIM: 0.95. 0 = kapali.", [0, 1, 0.95, 2]]
    ];
    diag_log "[ELITE-CBA] bot becerisi ayarlari kaydedildi (CBA Addon Options > LAMBS Danger > ELITE bot becerisi)";
};

// ===========================================================================
// CBA AYARLARI — ISARETLER (v8.271): kategori "ELITE isaretler". Istemci ayari (her oyuncu kendi gorunumunu belirler; sunucu degeri varsayilan).
// ===========================================================================
if (!isNil "CBA_fnc_addSetting" && {!isNil "CBA_settings_default"}) then {
    private _katI = ["LAMBS Danger", "ELITE isaretler"];
    {
        _x params ["_degisken", "_tip", "_ad", "_ip", "_veri"];
        [_degisken, _tip, [_ad, _ip], _katI, _veri, 0] call CBA_fnc_addSetting;
    } forEach [
        ["lambs_danger_isaretGizleV1", "CHECKBOX", "Dusman ELITE isaretlerini gizle", "Oyuncunun tarafina DUSMAN olan taraflarin ELITE harita isaretleri (plan OBJ / RP / SBF / CCP, mevzi, karakol, HQ, manuel noktalar) bu oyuncuda gorunmez.", true],
        ["lambs_danger_isaretZeusTum", "CHECKBOX", "Zeus tum ELITE isaretlerini gorur", "Isaretli ise Zeus (curator) olan oyuncu dusman isaretlerini de gorur. Varsayilan KAPALI (v8.274): Zeus oyuncu da kendi gorunum tarafi disindakileri gormez; hepsini gormek icin asagidaki gorunumu 'Hepsi' yap.", false],
        ["lambs_danger_isaretGorunum", "LIST", "ELITE isaret gorunumu", "Otomatik: oyuncunun tarafina dusman olanlari gizle (sivil / yalniz-Zeus oyuncuda gizleme yok). BLUFOR / OPFOR / INDEP: yalniz o tarafin isaretleri gorunur. Hepsi: gizleme yok.", [[0, 1, 2, 3, 4], ["Otomatik (oyuncu tarafi)", "Yalniz BLUFOR", "Yalniz OPFOR", "Yalniz INDEP", "Hepsi"], 0]]
    ];
    diag_log "[ELITE-CBA] isaret ayarlari kaydedildi (CBA Addon Options > LAMBS Danger > ELITE isaretler)";
};

// ===========================================================================
// CBA AYARLARI — CEPHE SIMULASYONU (v8.237, Dilim A0): kategori "ELITE Cephe Komutani". Hepsi sunucu ayari (sunucu degeri tum makinelerde gecerli).
//   Tum sayilar TASARIM DEGERIDIR (kitapta yok); CEPHE_SIMULASYONU_TASARIM.md 10.6 kararlari: temas / operasyon HER ZAMAN fiziksel, cephe seridi ~3000 m, gerisi sanal,
//   oyuncu 1500 m'ye girerse fiziksel, tavan 300 asker. Sistem OPSIYONELDIR: 'Aktif' kapaliyken (ya da hic faction eklenmediyse) hicbir sey yapmaz.
//   Faction basina asker sayisi CBA'da DEGIL, Zeus 'ELITE Cephe Paneli' modulunde (faction listesi otomatik; CBA'da yuzlerce faction ayari yapilamaz) ya da
//   mission maker API'siyle verilir: [faction, adet, rezerv, merkez, yaricap, varisYap] call lambs_danger_fnc_cepheFaction.
// ===========================================================================
if (!isNil "CBA_fnc_addSetting" && {!isNil "CBA_settings_default"}) then {
    private _kat = ["LAMBS Danger", "ELITE Cephe Komutani"];
    {
        _x params ["_degisken", "_tip", "_ad", "_ip", "_veri"];
        [_degisken, _tip, [_ad, _ip], _kat, _veri, 1] call CBA_fnc_addSetting;
    } forEach [
        ["lambs_danger_cepheAktif", "CHECKBOX", "Cephe simulasyonu AKTIF", "Kapaliyken sanal / fiziksel profil dongusu calismaz (profiller silinmez). Zeus paneliyle faction eklemek de sistemi acar.", false],
        ["lambs_danger_cepheFizikMaks", "SLIDER", "Fiziksel tavan (asker)", "Ayni anda fiziksel olabilecek profil askeri. Temasli birimler tavandan once korunur; tavan asilirsa once uzak ve temassiz profiller sanallanir. TASARIM: 300.", [20, 1500, 300, 0]],
        ["lambs_danger_cepheFizikYaricap", "SLIDER", "Oyuncu yakinligi (m)", "Cephe gerisinde bir oyuncu bu mesafeye girerse profil fiziksel olur (cikis histerezisi x1.3). TASARIM: 1500.", [200, 5000, 1500, 0]],
        ["lambs_danger_cepheTemasMesafe", "SLIDER", "Temas mesafesi (m)", "Dusman profil / birim bu mesafedeyse profil KESIN fiziksel olur (oyuncu olmasa da). TASARIM: 1200.", [300, 3000, 1200, 0]],
        ["lambs_danger_cepheOpYaricap", "SLIDER", "Operasyon alani yaricapi (m)", "Aktif plan hedefi etrafinda profiller fiziksel olur. TASARIM: 800.", [300, 2500, 800, 0]],
        ["lambs_danger_cepheSeritMesafe", "SLIDER", "Cephe seridi derinligi (m)", "En yakin dusman profile bu mesafedeki profiller 'cephe seridi'dir; fiziksel sikligi artar (oyuncu olmasa da). TASARIM: 3000.", [500, 8000, 3000, 0]],
        ["lambs_danger_cepheSeritOran", "SLIDER", "Cephe seridi fiziksel orani (yuzde)", "Seritteki profillerin bu yuzdesi fiziksel tutulur, kalani sanal (tavan icinde). TASARIM: 35.", [0, 100, 35, 0]],
        ["lambs_danger_cepheSeritTazeleS", "SLIDER", "Cephe seridi tazeleme (sn)", "Serit profili bu sure fiziksel kaldiktan sonra sira digerlerine gecer ('seyrek tazeleme'). TASARIM: 300.", [60, 1800, 300, 0]],
        ["lambs_danger_cepheMinFizikS", "SLIDER", "Minimum fiziksel kalis (sn)", "Fiziksel olan profil en az bu kadar fiziksel kalir (acilip kapanmasin). TASARIM: 90.", [20, 600, 90, 0]],
        ["lambs_danger_cepheDespawnBeklemeS", "SLIDER", "Sanallama beklemesi (sn)", "Tetik bittikten sonra sanallamadan once beklenen sure (histerezis). TASARIM: 60.", [10, 600, 60, 0]],
        ["lambs_danger_cepheTikS", "SLIDER", "Dongu araligi (sn)", "LOD yoneticisi turu. Kucuk = hizli tepki, fazla yuk. TASARIM: 3.", [1, 15, 3, 0]],
        ["lambs_danger_cepheTikSpawn", "SLIDER", "Tur basina fizikselleme (squad)", "Tek turda fiziksel yapilacak squad sayisi (temas / operasyonda x3). Yuksek = ani takilma. TASARIM: 3.", [1, 10, 3, 0]],
        ["lambs_danger_cepheSanalHizKmh", "SLIDER", "Sanal yurume hizi (km/s)", "Hedefi olan sanal squadin duz cizgide ilerleme hizi (yol grafi sonraki dilim). TASARIM: 4.", [1, 20, 4, 0]],
        ["lambs_danger_cepheSoyutCatisma", "CHECKBOX", "Tavan yuzunden sanal kalan temasta SOYUT catisma", "Tavan dolu oldugu icin fiziksel olamayan, karsi tarafla temastaki sanal squadlar 30 sn'de bir soyut kayip verir. Kapaliysa beklerler.", true],
        ["lambs_danger_cepheSoyutMesafe", "SLIDER", "Soyut catisma mesafesi (m)", "Sanal squadlar bu mesafedeyse soyut catisma. TASARIM: 500.", [100, 1500, 500, 0]]
    ];
    // ---- Personnel Replacement (varsayilanlar; Zeus panelinde taraf bazli ustune yazilir)
    private _katPR = ["LAMBS Danger", "ELITE Cephe Komutani"];
    {
        _x params ["_degisken", "_tip", "_ad", "_ip", "_veri"];
        [_degisken, _tip, [_ad, _ip], _katPR, _veri, 1] call CBA_fnc_addSetting;
    } forEach [
        ["lambs_danger_cepheTakvHizSaat", "SLIDER", "Takviye hizi (asker / saat)", "Personnel Replacement: taraf basina birikme hizi. 0 = takviye yok. TASARIM: 60.", [0, 600, 60, 0]],
        ["lambs_danger_cepheTakvGecikmeS", "SLIDER", "Kayiptan takviyeye gecikme (sn)", "Squad min boyun altina dusunce talebin isleme alinma gecikmesi. TASARIM: 300.", [0, 1800, 300, 0]],
        ["lambs_danger_cepheMinSquad", "SLIDER", "Minimum squad boyu", "Canli asker bu sayinin altina dusunce squad takviye ister (tam kadroya dek doldurulur). TASARIM: 4.", [1, 12, 4, 0]],
        ["lambs_danger_cepheTakvEsZamanli", "SLIDER", "Ayni anda en cok takviye paketi", "Taraf basina yolda olabilecek takviye paketi. TASARIM: 2.", [1, 10, 2, 0]],
        ["lambs_danger_cepheTakvBeceri", "SLIDER", "Takviye becerisi (yuzde)", "Takviye askerlerin AI beceri seviyesi. TASARIM: 60.", [0, 100, 60, 0]],
        ["lambs_danger_cepheTakvYakinCarpan", "SLIDER", "Cepheye yakinlik carpani (yuzde)", "Cephe seridindeki squadlara takviye bu oranda sik gelir (200 = iki kat). TASARIM: 200.", [25, 400, 200, 0]],
        ["lambs_danger_cepheKonvoyKayip", "SLIDER", "Konvoy zaiyat olasiligi (yuzde)", "Soyut konvoy dusmana <= 600 m iken 30 sn'de uye basina olum olasiligi (A0'da gercek arac yok). TASARIM: 5.", [0, 30, 5, 0]],
        ["lambs_danger_cepheKonvoyKmh", "SLIDER", "Soyut konvoy hizi (km/s)", "Takviye paketinin duz cizgi ilerleme hizi. TASARIM: 30.", [10, 80, 30, 0]]
    ];
    [
        "lambs_danger_cepheHavuzBitince", "LIST",
        ["Rezerv havuzu bitince", "Rezerv sifirlanip squad eksik kalinca: devam (hicbir sey), bitkin (beceri x0.85), cekil (takviye varis noktasina)."],
        _katPR, [[0, 1, 2], ["Devam", "Bitkin (beceri dusur)", "Cekil (varis noktasina)"], 0], 1
    ] call CBA_fnc_addSetting;
    diag_log "[ELITE-CBA] cephe ayarlari kaydedildi (CBA Addon Options > LAMBS Danger > ELITE Cephe Komutani)";
};

// ===========================================================================
// ELITE-BOOT — dagitim dogrulamasi + watchdog'lari ilk temasi beklemeden baslat
// (bu dosya XEH_preInit'e include edilir: asagidaki satirlar acilista RPT'ye yazar,
//  LAMBS debug acik olmasa da gorunur)
// ===========================================================================
diag_log "[ELITE-BOOT] lambs_danger ELITE build v8.308-PUSU-TEPKI (v8.308: pusuya hizli tepki + konum tahmini + cagri atesi + kanat / dron operatoru yonune kesif (istiksaf) + bireysel teslim + farkindalik CBA; v8.307: TCCC CBA ile kapatilabilir; dron teslim muhatabi; tank / zirhli ekibi pervane sesini duyar; dron operatorune karsi topcu / havan atesi (CBA); v8.306: dron atisinda bakis dronun kendisinde (doWatch tek sefer), govde donusu yumusak adimlarla, isinlanma yok; v8.305: acikta kalan asker agac / kaya / duvar ARKASINA gecer (dusmandan gizli nokta, durus), sadece yaninda durmaz; v8.304: perfBisect (sunucu konsolu: [] spawn lambs_danger_fnc_perfBisect) + hekim durgun esigi 5 sn / script yurutme kademe 3; v8.303: acikta kalan asker yakin binaya girer (fnc_acikSiper) + hekim ates altinda yaralinin yeri dusmana aciksa 90 sn bekler; v8.302: el bombasi taramasi allMissionObjects yerine lider cevresi nearObjects; v8.301: [PERF-SQF] 60 sn: calisan betik sayisi + en cok betik calistiran dosyalar + el bombasi taramasi suresi; v8.300: tank MG zorla atis (fireAtTarget) + duman 420 m + kacinma 200 m; v8.299: nisan alan botta sag-sol donus titremesi (doWatch / setDir seyreltildi, donus katsayisi histerezisi); v8.298: dronda agac / cali dibine saklanma + saklaninca 90 sn yerinde, surekli kacma yok; v8.297: dronda kacarken AYAKTA kosar (prone+doMove surunme yapiyordu); v8.296: teslim olan / captive hekim tedaviye gitmez; v8.295: dik aci (>40 derece) nisanci yerinde beklemez, >50 ates emri yok;  dron zorla atis ana silahla (GP-25 namlusu degil) + govde hizalama + nisan acisi logu; v8.294: teslim olan ACE captives ile uyumlu - ace_captives_isSurrendering, kelepce / refakat / araca yukle; v8.293: dronda forceWeaponFire ile zorla atis (AI karar mekanizmasindan bagimsiz); v8.292: dron gorunce guclu kacis (bina / siper / 35-60 m, 40 sn), yerinde ates eden 2, GERCEK ATIS sayaci + ATIS YOK dokumu; v8.291: combat / taktik yurutenler dronda artik tepki verir (<= 200 m yere yatar, yururken de ates); [MOTOR-SES-ELE] tanisi; v8.290: FPV pervane sesi 700 m + duyunca grup dronu bilir (reveal) -> dagil / saklan / ates; v8.289: bot isabeti / nisan hizi / tavan / tecrubesiz orani / optik cezasi / tank ekibi CBA ayarlarindan (ELITE bot becerisi), degisince canli uygulanir; v8.288: kamikaze / silahli dron gorunce grup dagilir + siper alir / yatar, 3 nisanci yerinde ates; isabete ek %7 (tavan 0.95); v8.287: topcu atis hazirligi (hareket emri iptal, davranis / combatMode) + [TOPCU-ATIS] tanisi; Zeus topcu testinde yerel olmayan arac murettebati devredilir; v8.286: tum AI gruplari sunucuya daha hizli devredilir (piyade 60 sn, arac 30 sn, 5 sn tur, 6 grup), devir dogrulamasi; v8.285: yerel olmayan topcu araci murettebati atis aninda sunucuya devredilir; v8.284: UGL piyadeye karsi sik: cooldown 4 sn, sans %92, menzil 30-340 m, uzak aralik 12 sn, ates destegi 5 sn / %60, rol gorevi 2li salvo; v8.283: yat / kalk / comel gecis animasyonu x1.25 + donus x1.2 (yurume degismez), ag gonderimi yalniz degisimde; v8.282: isabet tavani 0.92 + ~%15 tecrubesiz + genis bireysel aralik; v8.281: bot becerileri artirildi (aimingAccuracy 0.80-0.88, aimingSpeed / shake / spot / reload yuksek, general + commanding 1.0); tank topu hasar carpani (hile) kaldirildi; v8.280: susturucu duyulma menzili ~x3.5 + ses carpani 1.2 + dinleyici 10 grup; bot isabet / nisan hizi x1.2; askerler kamikaze drona ates eder + ucus izinden operator yonu paylasilir; tank dron savunmasi (yon, MG, duman, kacinma, uyari); tank koordinasyonu (tek hamle kilidi, sektor dagitimi, odakli ates); tank ekip becerisi 0.95 + tank topu hasari x1.3; v8.279: IHA dalisi her adimda iptal edilip 8 m/sn kaliyordu (hata duzeltildi, dalis 32 m/sn, seyir 22 m/sn); duzensiz profiller (lop_ists vb.) teslim olabilir; tank atis / hasar tanisi + ekip becerisi 0.85; tank gorus hattinda dusman tanki varken COMBAT / RED; v8.278: tank duellosu (dusman tankina gorus hatti olan / hull-down yeni pozisyona sicrama), saldirida da 300 sn yer degistirme, FPV / bomba seyir hizi (FULL + 17 m/sn yardim); v8.277: esirlerin TUM silahlari alinir + AI kapali tutulur (5 sn bakim); tank mevziye ulasamayinca kilitlenmez (sure uzatma / yeni mevzi); SALDIRI basi sicrama gerilemesi duzeltildi; savunma tanki 150 sn sonra yedek mevziye gecer (shoot-and-scoot); v8.276: teslim: kayitli eski CBA esikleri yeni varsayilana tasinir + baski zorunlu degil (umutsuzluk) + 2 ardisik tur; tasima: BUTUN grup (lider takimini birakmaz) + yukleme onceligi + guvenli sefer (temasta ertelenir); tank: taret bakisi (olu nokta yerine en acik tehlike sektoru / bilinen dusman) + mevzi olu nokta cezasi + ileri sicrama kademeleri; v8.275: recon kismi binme iptali (binemeyen araci kovalamasin) + tank ARAC-SENKRON muaf (CBA) + moral cokme terimi + teslim esikleri 0.45 / 50 / 5 / 0.30 / 150 + TESLIM-ADAY logu moral < 0.60; v8.274: isaret gizleme Zeus oyuncuda da calisir + gorunum secimi + tani logu; v8.273: FPV dalisi AI pilotu kapatip yumusak hiz rampasi + setVectorDirAndUp (havada glitch / kamikaze duzeltmesi); v8.272: Crocus cantasi (asker / yerde) IHA atamasinda taninir, sinif cantadan bulunur, canta tuketilir; v8.271: dusman ELITE isaretleri gizlenir (istemci, CBA), savunma planinda ORP isareti yok; v8.270: formasyon politikasi kitaba hizalandi (seyir teknigi / sicrama kama / temasta kolon yok / hucum hatti), bkz. kaynaklar_doktrin/FORMASYON_POLITIKASI.md; v8.269: temassiz hareket halindeki gruplar da tehdit mesafesine gore seyir formasyonu secer; v8.268: IHA operator bagi - operator olunce dron duser / hedefe kilitliyse dalar; v8.267: Zeus dron yarat = dusman tetik mesafesine girince bilincli firlatma (fnc_ihaBekle); v8.266: oyuncu komutasindaki botlar murettebat koruma / geri cagirma / GET OUT iptalinden muaf; v8.265: tank piyade bagi (piyadenin onune gecmez) + hareket edemeyen tankta murettebat terki / sabit atis + CBA ELITE zirh / mekanize; v8.264: recon aracinda AI surusune sabir (kinematik 10 sn yerine ~38 sn) + [RECON-ARAC-HAREKET] tani; v8.263: kinematik surus sabit engele (agac / duvar) itmez + carpisma hasari yok sayilir (recon araci parcalaniyordu); v8.262: atanmis arac koltugu yetmezse atanmamis uygun araclar eklenir + koltuk yetmiyorsa medevac rezervi ayrilmaz; v8.261: erken kuvvet orani kapisi (recon raporunda) + hibrit dusman tahmini (gozlenen + OPORD iddiasi guvene gore agirlikli) + oran bekleme sirasinda tank / nakil tutulur; v8.260: IHA gorevi zamanlanmamis ortamda calismiyordu -> duzeltildi, Zeus dronu sunucuda 40 m havada yaratilir, IHA Killed / Explosion logu; v8.259: teslim esikleri gevsetildi + CBA ana / taraf / fraksiyon bazli teslim anahtarlari + TESLIM-ADAY logu; v8.258: saldiri oncesi kuvvet orani kapisi + zirh korkusu / sag-sol dagilma panigi + planZirh surunme yenilemesi + aracTasima hata duzeltmesi; v8.257: tank mevzide surucu MOVE kilidi (nisanci doFire araci ileri surmesin) + AT tepki capasi + TAKILDI duzeltmesi + taktik fonksiyon girisi hendek korumasi + hendek saglikcisi muafiyeti; v8.256: hendek mevzi kilidi + statik silah + aracUzak hendek istisnasi + tank crewInImmobile + duman yontem kademesi + OLUM-TANI hata duzeltmesi; v8.255: tani paketi OLUM-TANI / HENDEK-DURUM / ARAC-TERK / ARAC-HAREKET / TANI-TOPCU / KAYIP-DEGERLENDIRME; v8.254: kayip esiginde (yuzde 50) HQ / rally point'e geri cekilme: ele gecir ORP-KESIF-SALDIRI + savunma; v8.253: kendi murettebati araktan uzaklastirilmaz + arac murettebat icin bekler + lider yayaysa planZirh arac emri; v8.252: duman cephane duzeltmesi + tank murettebat koltuk degistirme + savunma mevzi yaricapi / hendek kapasitesi / karakol-gozetleme mevzisi; v8.251: tank hedef dagitimi + AT atesine tepki (duman / yer degistirme) + tank koruma; v8.250: AT yetenegi olmayan arac tanktan kacar; v8.249: savunma temassiz sure siniri + Zeus dron yarat; v8.248: ORP gerisi temas destegi (orman dogrulamasi); v8.247: motor sesi farkindaligi + gercek hedef filtresi; v8.246: nakilde genis dusman mesafesi + otomatik tank; v8.245: nakil yol zinciri + BTR-80 FFV muaf; v8.244: tank savunma mevzisi + surucu yenileme + gozetleme yonu; v8.243: mevzi tutma + karsi saldiri donusu + savunma atesi + senkron bekle tavani + top erken kacis; v8.242: AT roket paslama + binmeyen / etkin komutan tanisi; v8.241: recon yol zinciri + agaclik geri izi; v8.240b: FFV duzeltme nisanciyi indirmesin; v8.240: Stryker FFV yolcu koku neden duzeltmesi; v8.239e: A/B koltuk / komut seti K1-K7 + koltuk duzeni logu; v8.239d: A/B duzeltme adaylari RELOKE / JOIN; v8.239c: surus A/B ayristirma setleri + koltuk tanisi; v8.239: coklu mevzi + surus A/B testi; v8.238: hendek onceligi; v8.237: cephe profil cekirdegi A0; v8.235: iha envanter ad; v8.234: iha mod motoru; v8.233: iha gorev; v8.232: agac iha; v8.231: tek grup karsi yok; v8.230: hendek bilinc; v8.229: hendek alani; v8.228: top siper; v8.227: zaman log; v8.226: ozel recon araci; v8.225: yukle bekle; v8.224: hizli kurtarma; v8.223: kapi kapali; v8.222: arac devir 15s; v8.221: recon yaya kapi; v8.220: surme deney; v8.219: surucu isinla; v8.218: recon yol; v8.217: komutan geri; v8.216: rp recon ek; v8.215: komutan koltuk; v8.214: zincir gozetle; v8.213: surme tani; v8.212: recon hizli; v8.211: kin bos; v8.210: kin engel; v8.209: kin ortak; v8.208: kin puruzsuz; v8.207: anahtarlar; v8.206: atis paceleme; v8.205: kinematik surus; v8.204: savunma komutani; v8.203: surus rotasi; v8.202: yol onceligi; v8.201: ziplama tani; v8.200: recon bekleme tani; v8.199: basit topcu hq tamami; v8.198: arac su savunma tank; v8.197: su muaf; v8.196: topcu test; v8.195: su yol ac buddy; v8.194: doktrin recon tank; v8.193: recon geri donus; v8.192: gec recon canli; v8.191: kurtarma; v8.190: saglik recon hiz; v8.189: konvoy tank yol; v8.188: recon arac; v8.187: senkron kalkis tank2; v8.186: topcu senkron muaf; v8.185: takilma sabir; v8.184: topcu sinif inis korunak; v8.183: topcu nisan kaydir; v8.182: arac uzak; v8.181: kalkis topcu stratejik; v8.180: park cikisi tank erken; v8.179: hq duzeltme tekillestirme; v8.178: hq kategori donus; v8.177: arac yayilma; v8.176: kaldir arac durum; v8.175: topcu tank mevzi; v8.174: cover rally siper; v8.173: prep temizlik; v8.172: silahci karsilik; v8.171: senkron mevzi; v8.170: nakil ilerleme; v8.169: paletli apc; v8.168: nakil piyade yurur; v8.167: carpisma guvenligi; v8.166: arac devir; v8.165: nakil bekle; v8.164: apc ifv rol; v8.163: arac zirh sefer; v8.162: grupsec sonraki kare; v8.161: grupsec tani; v8.160: grupsec duzeltme; v8.159: zihin bayat; v8.158: komutan tavir; v8.157: zihin duzeltme; v8.156: komutan zihni; v8.155: devir gecikme; v8.154: cephane env; v8.153: cephane anim kapali; v8.152: giyim tanisi; v8.151: oyuncu komutasi; v8.150: elle grup secimi; v8.149: murettebat koruma; v8.148: yolcu bekcisi; v8.147: motor zorlamasi; v8.146: ezme tanisi; v8.145: murettebat tamamlama; v8.144: ezme korumasi; v8.143: Rus doktrini ATP 7-100.1; v8.142: murettebat bekcisi; v8.141: murettebat toplama; v8.140: takilma tanisi; v8.139: nakil yol / atanmis arac; v8.138: pusu dayaniklilik; v8.137: nakil sefer; v8.136: nakil hiz / rezerv; v8.135: nakil takilma; v8.134: istihbarat / PID; v8.133: nakil dinamik alma; v8.132: nakil erken baslar; v8.131: recon / takim bazli bolme; v8.130: karakol garnizonu; v8.129: taksi / arac nakli; v8.128: karakol / baskin; v8.127: Gorev Ata; v8.126: telemetri; v8.125: donus animasyon hizi 1.15; v8.124: AI gruplari sunucuya devir; v8.123: plan uzak grup devri; v8.122: plan tanisi; v8.121: plan yaniti; v8.120: Objektif paneli 3 kucuk panel; v8.119: bounding sicrama gozetleyen menzilinin 2/3 siniri; v8.118: kesif = guvenlik halti 60 / 90 / 30 sn (TC 3-21.76 short halt 1-2 dk), SBF uyarisi 460 m (M16), kaynakli / tasarim esik tablosu; v8.117: ORP 200-400 m ve topcu RED / DANGER CLOSE kitaptan (TC 3-21.76); v8.116: Zeus modulleri plani sunucuda kurar (CBA sunucu olayi) - dedicated / MP duzeltmesi; v8.115: komutan plani - tempo / niyet, H-saati + Zeus onayi, sure siniri + cekilme, tehdit yonu, ROE kisitlari, topcu / havan destegi, CCP, manuel plan noktalari (tarihsel canlandirma), [PLAN-OZET] AAR; v8.114: Objektif modulu dialog hata dongusu duzeltmesi (SIDE kontrolu -> LIST, modul hemen silinir); v8.113: Zeus ELITE Objektif modulu + komutan plani (arazi tanima, rally point, ORP, destek / manevra / yedek, kanat, garrison, toparlanma, gercek waypoint) [PLAN]; v8.112: sis ekonomisi ayni inis noktasi (22 m) kontrolu; v8.111: arac - piyade senkronu [ARAC-SENKRON], DUZENSIZ doktrinde DIAMOND yok; v8.110: sis ekonomisi - ayni acida sis varsa tekrar atilmaz [SIS-EKONOMI]; v8.109: parcali / duman alicisi yalniz verici varsa, [BUDDY-ES] asistan cifti logu; v8.108: MG + MG asistani / AT + AT asistani oncelikli buddy, asistan MG ye mermi saglar, bomba siniflari envanterden, halef yapiskanligi; v8.107: cephane aktarim kilidi (ust uste 7 verici sorunu), alici 4 sarjora tamamlanir; v8.106: cephane sarjor sayimi tum uyumlu siniflar (karisik yukleme), verici sinif secimi, [CEPHANE-TANI]; v8.105: cephane gercek ates degisimi ile temas (contact bayragi yuzunden paslama hic calismiyordu) + Throw tum sinif tarama + [CEPHANE-NEDEN]; lider devri / destek ayrintili log; v8.104: destek ateşi (taarruz grubu icin yan tepede destek grubu doSuppress) [HQ-DESTEK], lider devri on hesabi [LIDER-DEVRI], mermi disiplini farkindaligi [MERMI]; v8.103: hekim script yurutmesi pürüzsüz (anim yeniden baslatma / dir snap titremesi giderildi); v8.102: hekim triyaj onceligi (kalp durmasi > kanama > dusuk kan > bekleme suresi), gercek hekim bounding forceMove ile elenmez; v8.101: ACE playTreatmentAnim hatasi hekim betigini oldurup hekimi 150 sn dondurup yaraliyi kilitliyordu -> kendi animasyon + olu betik kilidi temizligi; sinsiGeri cmdSit hatasi; v8.100: [ACE-TEDAVI] ACE nin kendi AI tedavisini de loglar; v8.99: el bombasi atisinda hedef yoksa inis noktasi 12 m hedef sayilir (baygina bomba iptali), cephane bomba sinifi: patlayici yuk / isik hariç, duman sinifi; v8.98: hekim yalniz FirstAidKit tasiyorsa FAK = FieldDressing (RPT fd9aa156: tibbi esya YOK-ESYA), bayilan hekim script yurutmesi durdurulur (baygin hekim yaralinin ustune kayiyordu), yarasiz bolgeye esya harcanmaz; v8.97: [TCCC-TX] tedavi adimi logu (esya / uygulandi / kan kaybi once-sonra), yerel hastaya dogrudan ACE yerel fonksiyonu; v8.96: cephane watchdog cokme duzeltmesi (verici filtresinde _x golgeleme) + bomba siniflari mermi simulasyonundan; v8.95: sinsi geri cekilme (ates kes, onde olanlar arkaya, bekle) [SINSI-GERI], hekim tedavisi ACE AI yoluyla (animasyon + bekleme + aktivite logu), durgun hekim script yurutme, ; v8.94: TCCC hekim durgun tespiti + kademeli mudahale [TCCC-DURGUN]; v8.93: bayilana patlayici (RPG / bomba) infaz yasagi, medevac talep + hekim havuzu duzeltmesi, TCCC yaklasma doMove tazeleme, RPG farkindaligi dagilma; v8.92: cephane + bomba paylasimi (yere birak / alici alir), tehlike alani (yol) gecisi; v8.91: bayilan asker kayip sayilir (komutan / moral / HQ / son direnis); v8.90: optiksiz birim aimingAccuracy x0.75 + rpt_ozet --kayip; gerceklik arastirmasi kaynaklar_doktrin/arastirma_gerceklik; v8.89: lider telsiz kabul + DELAY/hide ates kesme duzeltmesi + HQ tahta logu taraf basina; v8.88: doAssaultSpeed overlay - arac icindekilere forceSpeed uygulanmaz; v8.87: mekanize surucu forceSpeed sifirlama + hiz ozeti; v8.86: CBA taraf secimi - ELITE hangi tarafta aktif; v8.85: TCCC hekimi bounding emirlerinden muaf, AI surukleme varsayilan kapali; v8.84: DIAMOND yalniz >= 4 aracli acik arazi yaklasma yuruyusunde; v8.83: roket dustu + duman tehdit tepkisi (arac murettebati dahil), halt (slot kovalama kesici), ileri gozcu + RTO, DIAMOND kaldirildi, UGL HE yukleme, AI surukleme devre disi; v8.82: aracli medevac (APC/arac yaralilari toplama noktasina tasir), panik disableAI sizinti duzeltmesi, mekanize duzeltici 100 m + FULL hiz; v8.81: AI hekim suruklemede Zeus ekranina dusen Release yakalayicisi kaldirilir; v8.80: formasyon yazma hakemi formSet, mekanize dur-kalk izleyici + COLUMN, TCCC suruklem / iptal logu; v8.79: HEMTT lint temizligi (count/not/select/pi/pushBackUnique), davranis ayni; v8.78: HEMTT SPE2 koku: checkVisibility [..] -> lineIntersects; v8.77: gizliAlgi HEMTT SPE2 sozdizimi sadelestirildi; v8.76: TCCC ayni hekim ayni anda coklu yarali atamasi duzeltildi; v8.75: oyuncunun ayak sesi + el feneri / IR lazer algisi; v8.74: panik ve bilgi sisi varsayilanlari oyuncu karsisinda hafifletildi; v8.73: panik/felc - donma, kor ates, kacis (LAMBS doPanic entegre); v8.72: HQ istihbarat sisli (telsiz sarti, gecikme, belirsizlik, kayip rapor), retreat komut-ezme duzeltmesi; v8.71: buddy bagi sakinde lider hareket+45 sn bekler, 8+ kisi limit 35 m; v8.70: BOSTA-HAREKET logu yuruyen askerin hedef modu + hangi script; v8.69: acik arazi bounding 8+ kisi WEDGE, BAYRAK-TAKILI yalniz ayni bayrak kumesinde, nokta elemani neden ozeti; v8.68: bounding 0.5 sn formasyon zorlamasi taktik formasyonunu ezmez; v8.67: tek kalan askerler telsiz/yakinlik ile diger squad a katilir, formasyon hakemi (taktik formasyonu 25 sn korunur), HQ takviye bounding/uzak temas grubunu da kullanir; v8.66: traveling overwatch nokta elemani; v8.65: hareket halinde yan koruma + arka emniyet gozetleme; v8.64: MG yoksa baski tufekcisi atamasi; v8.63: hucum oncesi bastirma penceresi; v8.62: UGL kullanim sikligi + neden-atmadi sayaci [UGL-OZET]; v8.61: LAMBS taktik zamanlayicisi formasyon geri yazmaz (Assault / Suppress / Flank / Attack / Garrison / Hide); v8.60: olum bolgesi hafizasi + rota gozcusu, karsi pusu kurali, HQ otomatik; ZEKA-* loglari; v8.59: IED yok olunca kacis iptal; v8.58: IED grubu felc etmez: yalniz EOD + 2 guvenlik elemani, grubun gerisi devam eder; v8.57: EOD imha zari (beceri / kit / cihaz / baski), basarisizlikta iptal + patlatma, EOD buddy disi, kit kurali; v8.56: garrison cagri oncesi / sonrasi / 4-12-30 sn asker bazli ici-disi logu; v8.55: yakinlik tetikli IED icin kontrollu patlatma (standoff), calisma kesilme nedeni logu; v8.54: IED cevre noktasi radyal (askerler IED uzerinden yurumez), hava egik mesafe zarfi, garrison sonrasi acikta kalanlar siper; v8.53: hava + IED teshis loglari: NABIZ, KARAR, ELE, ATLA, GOZLEM, IMHA, CEVRE, son-adim bekcisi; v8.52: IED cevre emniyeti 360 derece + yaricap x6 + sadece yakinlik tetikli komsu engeller, hava KARAR teshis logu + YERE-YAT; v8.51: ATP 3-01.8 hava ates disiplini + toplu ates + onculuk, IED yaricap config, watchdog bekcisi; v8.50e: kumelenmis IED sirayla imha, ikincil cihaz kurali daraldi; v8.50d: EOD IED imha yaklasmasi duzeltildi; v8.50c: IED temasta yere yat + uzaklas, ikincil cihaz kontrolu, yakinlik tetikli IED, tek is, tarama merkezi EOD; v8.50b: EOD imha icin ACE_DefusalKit / ToolKit sart; v8.50a: hava watchdog coktu - getFriend yan hatasi tani logunda (RPT line 54), duzeltildi; v8.50: IED sistemi ACE EOD (explosiveSpecialist / ACE_isEOD) entegrasyonu: erken tespit 90 m, EOD imha eder, digerleri acilir, taktik kilidi gecilir; hava farkindaligi: bilgi esigi 0.4, bounding gruplar da tepki verir, [HAVA-FARK-TANI] teshis logu; tacticsHold / tacticsHide eski geri-verme zamanlayicisi bounding / retreat kilidini silmez; formasyon felci: LAMBS taktik formasyonuna 60 sn karismama + degisim sonrasi 60 sn bekleme + [FORM-DEGISIM] logu; bounding yeniden baslatma debounce 8 sn; buddy bagi ilerleme kontrolu + 120 sn geri cekilme; preStart cokmesi duzeltildi: CBA ayari yalniz preInit; CBA ayari: west / east / independent icin doktrin profili secimi; siper secimi: ayni noktaya yigilma cezasi + coverHug dost mesafesi 2.5 m; formasyon yon histerezisi: setFormDir sapma>35 ve 40 sn + komutan formasyon 25 sn + bastirilmis grupta dokunma yok; kumanda feint modulu (MCWP 3-11.1) + toparlanma dagilan sayimi; rota ara nokta zinciri + kapi yanindan yigilma / zit koseli oda girisi; pusu: security unsuru + cogunluk kill zone + cok buyuk dusman iptali + pusu sonrasi toparlanma; Zeus modulu CfgPatches units[] duzeltmesi + retreat gorus bitisi + yon degistirme + toparlanma modulu (consolidate and reorganize) + kanat ates kaydirma; Zeus modulu ile acilan HQ: istihbarat agi + kanat manevrasi + takviye; HQ cekirdegi + PUSH retreat sonrasi kilitli + cekilme dusman hafizasi + jest/callout susturma + kale savunmasi + retreat sonrasi toparlanma + retreat her sicramada forceSpeed sifirla + TAKILI AI bayraklari + sivil / dost / esir koruma + bina: rol / etaj + peek + stealth flas + donus +%15 + fieldCraft hata duzeltmesi + iceride geride durma + muzzle flash riski + iceride atis pozisyonu: dar aci + pencereden geride + retreat takilma tanisi + kademeli mudahale + retreat: uzak mesafede toplu kosu + retreat kosan sert ayakta durus + siper-yapis tanisi + moral + teslimiyet + yorgunluk duyarli atilim + spawn / duran grupta formasyon sirasi duzenlemesi yok + coverHug v2 hassas siper + sakin formasyon + telsiz tanisi + yakin mesafe tabani + saglikci tasmasi + temas kesme gizli ters yon + DUZENSIZ/Taliban doktrini + yeni birimlere varsayilan beceri + yaprak arkasi gorus kirici + guclu debug + toplu test karnesi + ortam beceri dususu: isik + NVG/termal + sis + yagmur + retreat ek sicrama adimi + saglik / anomali izleyicisi + rpt_ozet --grup / --anomali + arazi bilinci: komutan hakim nokta + bireysel arazi kivrimi + kamuflaj bilinci + ufuk cizgisi + pusu davranisi + ates emri ROE + sis 3 atici genis perde + erken varista COMBAT + retreat: baski altinda once siper + baski altinda sicrama erken cikis + CAGRI log kisma + taktik rota planlama v1 (ortulu yaklasma acisi) + retreat ek sicramalar + kapsama lideri doStop + retreat sicrama penceresi mesafeye gore 12-26 sn + grup olay mesajlari + retreat birim duzeyi LAMBS kapatma + bounding spawn kapsam hatasi duzeltildi + siper analizi v2 faz1 + global doktrin cercevesi: profil + kalitim + fnc_dk + arbitraj tum taktiklerde + rpt_ozet + lint + hareket arbitraji taktik kilidi + retreat sirasinda LAMBS reaksiyon kapali + bomba tepki 0.2 sn tarama + el bombasi inis noktasi tahmini + komutan bound takibi + UGL uzak mesafe/rezerv + siper hedefli retreat + moveAssist derleme hatasi + UGL salvo arguman + hucum esigi 45 m + overwatch kurulum 5 sn + RHS el bombasi shotgrenade tespiti + duvar koruma 15 sn + CAGRI JEST KOMUT logu + DURUM komut/anim/katsayi + el bombasi genis tani + allMissionObjects tarama + baski altinda acikta HOLD yerine DELAY + bound ekip dengesi + BND-CIKIS logu + 250-500 m BOUNDING + retreat doStop sadece varanlar + PATH acik + durum+doktrin gozlemcisi + donus hizi dogrudan uygulama + el bombasi tarama yaricapi grup boyu + DELAY/take cover spam kilidi + el bombasi tani logu + kucuk ekip kacmaz DELAY + kisa retreat atilimi + ates hatti kapali (felc) + komutan temasta beklemez + ustunken 60 m ustu BOUNDING + bounding ekip dönüşümlü + UGL hat kontrolu gevsetildi + donus hizi senkron + retreat doStop + UGL-TESPIT tani logu + UGL magazineWell duzeltmesi + taktikte UGL + arka guvenlik + hile kapatma + mesafeye gore bound/cekilme boyu + ates hatti yan adimi felc etmez + sikisma adimi sadece sakin intikal + spam kesildi: jest 45 sn + komutan bekle sogumasi + formasyon histerezisi: arazi Schmitt + mesafe bandi + 90 sn bekleme + uzun bound + komutan arkada kosmaz + cekilme sonrasi kilit + atis guvenligi RPG/UGL + karar+formasyon istikrari + tek kalan saklan + TCCC fix + once siper sonra ates + TCCC + saha ustaligi + ates hatti + hizli retreat + donus x1.2 + duvar korumasi + sikisma + komutan formasyon + lider arkada) yuklendi (XEH_PREP preInit)";
[{
    // HER makinede: Zeus'la yaratilan AI'lar istemcide yerel olur; watchdog'lar yalnizca YEREL gruplara dokunur
    if (true) then {
        private _fns = [
            "tactics", "commanderAssess", "tacticsBounding", "tacticsRetreat", "tacticsEvadeArmor", "tacticsATEngage",
            "tacticsBreakContact", "roleStation", "buddyBond", "dispersion", "reloadCover", "grenadeAwareness",
            "leaderSync", "firedHub", "soundAwareness", "cqbReflex", "isSniper", "sniperTeam", "buildingClear", "buildingClearRun", "coverHug", "rpgReaction", "fireSupport", "buddyDebug", "tacticalUGL", "rotaPlan", "pusu", "ufukMu", "araziAnaliz", "kamuflaj", "saglik", "ortamSkill", "yaprakGorus", "varsayilanSkill", "medicTasma", "moral", "roeGuard", "tehditBakis", "havaFarkindalik", "olumBolgesi", "pusuKarsi", "baskiTufekci", "yanGuvenlik", "noktaEleman", "yetimKatil", "panikFelc", "gizliAlgi", "formSet", "mekanizeIzle", "aracMedevac", "tehditIzle", "tehditOlay", "haltKur", "sinsiGeri", "liderDevri", "mermiDisiplin", "grupSunucuDevir", "telemetri", "aracTasima", "taksi", "ezmeKoruma", "aracUzak", "reconArac", "murettebatKoru", "giyimTani", "komutanZihin", "topSiper", "hendekBilinc", "agacGizlen", "ihaGozlem", "ihaEnvanter", "ihaTip", "ihaSorti", "karakolGarnizon", "hqDestek", "asistanTur", "aracSenkron", "komutanPlan", "komutanPlanDongu", "komutanPlanKapi", "gozcuRto", "tarafSecim", "cephanePaylas", "tehlikeAlani", "iedFarkindalik", "sonDirenis", "toparlan", "hq", "hqTakviye", "hqEmir", "hqMedevac", "hqIstihbarat", "hqKanat", "hqFeint", "tacticalSmoke", "getUnitRole", "buddyPairs", "commanderFormation", "moveAssist", "fireLine", "tccc", "fieldCraft", "atisGuvenli", "rearGuard", "uglMags", "durumLog", "doktrin", "dk", "olayGonder", "olay"
        ];
        diag_log format [
            "[ELITE-BOOT] makine: isServer=%1 hasInterface=%2 | fonksiyonlar: %3",
            isServer, hasInterface,
            _fns apply {format ["%1=%2", _x, !isNil (format ["lambs_danger_fnc_%1", _x])]}
        ];

        // watchdog'lar ilk temasta degil, acilista baslasin
        {
            [] call (missionNamespace getVariable [format ["lambs_danger_fnc_%1", _x], {false}]);
        } forEach ["isaretGizle", "firedHub", "buddyDebug", "dispersion", "buddyBond", "leaderSync", "roleStation", "reloadCover", "grenadeAwareness", "cqbReflex", "sniperTeam", "buildingClear", "coverHug", "fireSupport", "commanderFormation", "moveAssist", "fireLine", "tccc", "fieldCraft", "rearGuard", "durumLog", "olay", "pusu", "kamuflaj", "saglik", "ortamSkill", "yaprakGorus", "varsayilanSkill", "medicTasma", "moral", "roeGuard", "tehditBakis", "havaFarkindalik", "iedFarkindalik", "olumBolgesi", "baskiTufekci", "yanGuvenlik", "noktaEleman", "yetimKatil", "panikFelc", "gizliAlgi", "mekanizeIzle", "aracMedevac", "haltKur", "sinsiGeri", "liderDevri", "mermiDisiplin", "grupSunucuDevir", "telemetri", "taksi", "ezmeKoruma", "aracUzak", "murettebatKoru", "giyimTani", "komutanZihin", "topSiper", "hendekBilinc", "agacGizlen", "ihaGozlem", "ihaEnvanter", "karakolGarnizon", "aracSenkron", "komutanPlanKapi", "gozcuRto", "tarafSecim", "cephanePaylas", "tehlikeAlani", "hq", "cepheOlaylar", "cepheDongu", "surusAB", "aracFfvDuzelt", "atPaylas", "surucuYenile", "motorSes", "aracZirhKac", "tankAtesKontrol", "tankMurettebat", "tani", "mevziKilit", "teslimBirey", "pusuTepki"];

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
