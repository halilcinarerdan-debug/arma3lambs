# Arastirma 4: Arma 3 AI Beceri, ACE Tibbi ve Balistik Kalibrasyonu

Tarih: 2026-10-06. Yontem: GitHub raw kaynak kodu (dogrudan okundu) + WebSearch ozetleri.
ERISIM NOTU: community.bistudio.com, ace3.acemod.org, steamcommunity.com, forums.bohemia.net, arma.fandom.com, pastebin.com bu ortamda egress proxy tarafindan ENGELLI. Bu siteler yalnizca WebSearch ozetleri uzerinden (ikincil, kisaltilmis) goruldu; bu satirlar GUVEN=orta/dusuk olarak isaretli. Kaynak koddan okunanlar GUVEN=yuksek.

Kisaltmalar: raw = https://raw.githubusercontent.com ; ACE = acemod/ACE3 master.

---------------------------------------------------------------
## 1. AI beceri sistemi

### 1.1 Alt beceri tanimlari (ne ise yarar)

| DEGER / TANIM | KAYNAK | GUVEN | NOT |
|---|---|---|---|
| aimingAccuracy: hedef onunu alma, menzil/dusme tahmini, silah dagilimi ve geri tepme telafisi (yuksek = daha kontrollu atis), ates etmeden once nisan emniyeti | https://github.com/robalo/mods/blob/master/asr_ai3/addons/skills/config.cpp (yorum blogu, BI wiki'den kopya); ayni metin WebSearch ile https://community.bistudio.com/wiki/CfgAISkill | yuksek (kodda okundu) | BI wiki dogrudan acilamadi; ASR config.cpp icinde birebir kopyasi var |
| aimingShake: silah salinimi (yuksek = daha az sallanma) | ayni | yuksek | |
| aimingSpeed: nisanin donme/oturma hizi (yuksek = hizli, az hata) | ayni | yuksek | |
| spotDistance: gorus/isitme menzilinde tespit yetenegi VE bilginin dogrulugu | ayni | yuksek | |
| spotTime: olume/hasara/dusman gormeye tepki hizi (yuksek = hizli) | ayni | yuksek | |
| courage: astlarin morali (yuksek = cesur) | ayni | yuksek | |
| reloadSpeed: sarjor/silah degistirme gecikmesi (yuksek = az gecikme) | ayni | yuksek | |
| commanding: taninan hedeflerin gruba bildirilme hizi | ayni | yuksek | |
| general: "ham" beceri; alt becerilere dagitilir, karar vermeyi etkiler. endurance: Arma 3'te devre disi | ayni | yuksek | |
| skillFinal: "AI Level" (zorluk) katsayisi uygulanmis NIHAI alt beceri degerini dondurur; skill/skill ise ayarlanan ham deger | WebSearch ozeti: https://community.bistudio.com/wiki/skillFinal ; https://community.bistudio.com/wiki/skill ; https://community.bistudio.com/wiki/setSkill | orta | Sayfa dogrudan okunamadi; yalnizca arama ozeti. Tam formul BULUNAMADI |

### 1.2 Sayisal etki: CfgAISkill egrisi (skill -> etkin deger)

| DEGER / TANIM | KAYNAK | GUVEN | NOT |
|---|---|---|---|
| ASR_AI3, vanilla egrileri (yorum satirinda): aimingAccuracy {0,0, 1,1}; aimingShake {0,0, 1,1}; aimingSpeed {0,0.5, 1,1}; spotDistance {0,0, 1,1}; spotTime {0,0, 1,1} (cift = x,y; dogrusal) | https://raw.githubusercontent.com/robalo/mods/master/asr_ai3/addons/skills/config.cpp | yuksek (modun yorumladigi "orijinal" degerler) | Yani vanilla'da aimingAccuracy/Shake dogrusal 0-1; aimingSpeed taban 0.5 |
| ASR_AI3 degistirilmis egriler: aimingAccuracy {0,0.1, 0.8,0.7, 1,1}; aimingShake {0,0.1, 0.8,0.4, 1,1}; aimingSpeed {0,0.1, 0.8,0.6, 1,1}; spotDistance {0,0.1, 0.8,0.3, 1,1}; spotTime {0,0.1, 0.8,0.4, 1,1} | ayni dosya | yuksek | Mantik: 0.8 skill'e kadar "tavan" dusuk tutulur, 0.8-1.0 arasi hizla yukselir (ustun nisanci/SF ayrisir). Ornek: aimingAccuracy skill 0.5 -> etkin ~0.4 (hesap: 0.1 + 0.5/0.8*0.6) = TAHMIN (dogrusal ara deger) |
| Resmi zorluk on ayarlari (aimingAccuracy / aimingShake): Recruit 0.01/1, Regular 0.05/0.9, Veteran 0.1/0.75, Expert 0.2/0.55 | WebSearch ozeti (Steam topluluk sayfalari): https://steamcommunity.com/app/107410/discussions/0/1727575977538016111 (okunamadi) | dusuk-orta | Cikarimlar ikinci el; sayfa engelli. Bu degerlerin ayni sey (precisionAI) oldugu dogrulanamadi |
| skillFinal icin AI Level katsayisi formulu | BULUNAMADI (BI wiki engelli) | - | |

### 1.3 Dusuk beceri gercekte ne kadar isabet dusurur (olcum)

| DEGER / TANIM | KAYNAK | GUVEN | NOT |
|---|---|---|---|
| Test: 300 m, optiksiz tufek, yatarak nisanci, yatan hedef, 200 atis. VANILLA: skill 0.9 -> 47/200 isabet (%23.5); 0.1 -> 7/200 (%3.5); 0.01 -> 4/200 (%2) | https://github.com/acemod/ACE3/issues/6948 | orta-yuksek | Tek kisi testi (BlackAlpha), kucuk orneklem. Issue "stale", cozulmedi. Not: aimingAccuracy dagitim modeli ile birlikte tek bir alt beceri mi hepsi mi ayarlandi net degil ("SetSkills: 0.9") |
| Ayni test ACE3 ile: 0.9 -> 182/200 (%91); 0.1 -> 71/200 (%35.5); 0.01 -> 60/200 (%30). Yani ACE yuklu iken isabet ~4-10x ve dusuk beceride bile %30+ | https://github.com/acemod/ACE3/issues/6948 | orta | ONEMLI: ACE ile "dusuk skill" beklentisi calismayabilir. Neden (hangi ACE modulu) issue'da BELIRTILMEMIS = BULUNAMADI. Kod icinde AI icin bilinen dagilimi etkileyen ACE modulleri: overheating dagilimi (asagida). Test eski (ACE ~3.12/2019 donemi); guncel ACE'de yeniden dogrulanmadi |
| aimingAccuracy tavsiyesi: 0.2 en cok kabul gören denge; 0.2-0.4 iyi; "0.1-1 arasi" | WebSearch ozeti (Steam): https://steamcommunity.com/app/107410/discussions/0/558751813085906160 vb. (okunamadi) | dusuk | Oznel topluluk gorusu |
| 100-200 m'de AI'nin bir sarjor harcayip vurmamasi sikayeti (dusuk skill) | WebSearch ozeti (Steam) | dusuk | |
| AI hata payinin menzil ile olcegi (formul) | BULUNAMADI | - | Kesin formul kaynaklarda yok. TAHMIN (kaynaksiz): hata payi aci cinsinden sabit varsa, metre cinsinden menzille dogrusal buyur (ve 300 m testindeki %23.5 -> %3.5 dusus buna uyar). Olcumle dogrulanmali |

### 1.4 Topluluk kalibrasyonlari ("gercekci" kabul edilen degerler)

| DEGER / TANIM | KAYNAK | GUVEN | NOT |
|---|---|---|---|
| ASR_AI3 skill setleri (her seviye icin [taban, +random]): general / aiming / spotting. L0 super-AI [1.0,0]/[1.0,0]/[1.0,0]; L1 SF1 [0.90,0.1]/[0.50,0.2]/[0.50,0.1]; L2 SF2 [0.85,0.1]/[0.40,0.2]/[0.40,0.1]; L3 Regular1 [0.80,0.1]/[0.25,0.1]/[0.30,0.1]; L4 Regular2 [0.75,0.1]/[0.20,0.1]/[0.25,0.1]; L5 milis/egitimli isyanci [0.70,0.1]/[0.15,0.1]/[0.20,0.1]; L6 [0.65,0.1]/[0.10,0.1]/[0.15,0.1]; L7 egitimsiz [0.60,0.1]/[0.05,0.1]/[0.10,0.1]; L8 pilot1 [0.80,0.1]/[0.20,0.1]/[0.35,0.1]; L9 pilot2 [0.75,0.1]/[0.15,0.1]/[0.30,0.1]; L10 sniper [0.90,0.1]/[0.70,0.3]/[0.90,0.1] | https://raw.githubusercontent.com/robalo/mods/master/asr_ai3/addons/skills/initSettings.sqf (kod bloku yorum icinde; guncel surumde yorumlanmis, varsayilan sets baska dosyada olabilir) | yuksek (degerler okundu) ama "su an aktif varsayilan" orta | Duzenli ordu (L4) icin aiming 0.20-0.30 -> bu ASR'nin "gercekci" hedefi. Egriyle (1.2) birlikte etkin deger ~0.26-0.34. Bu da ayrica 2024 Steam arama sonucundaki "0.2" tavsiyesiyle uyumlu |
| ASR ayar adlari: asr_ai3_skills_setskills (checkbox, sinif bazli beceri), asr_ai3_skills_teamsuperai (oyuncu grubu AI daha iyi), ASR AI3 > skills | https://raw.githubusercontent.com/robalo/mods/master/asr_ai3/addons/skills/initSettings.sqf | yuksek | Prefix 'asr_ai3_skills_' makro GVAR'dan turetildi (orta). Repo 2021'de arsivlendi (Wolfenswan/ASR_AI3), orijinal robalo/mods hala erisilebilir |
| VCOM AI (rutbe bazli; surum A: AISettingsV2): aimingAccuracy = 0.05 + random 0.05; aimingShake = 0.05 + random 0.05; aimingSpeed 0.6; courage 0.7+random 0.3; commanding 1; general 1; spotDistance 0.6-0.7 (Captain 1.0); reloadSpeed 0.2-1.0 rutbeye gore | https://github.com/Shervanator/arma3-warfare/blob/master/userconfig/VCOM_AI/AISettingsV2.hpp | yuksek (okundu) ama eski VCOM v2 kopyasi | Cok dusuk nisan degerleri: ACE'siz oyunda ~%3 isabet bolgesi (bkz 1.3) |
| VCOM AI (surum B: VCOMAI_DefaultSettings): aimingAccuracy ve aimingShake = 0.6 + random 0.1; spotDistance 1; aimingSpeed 1; courage 0.7+random 0.3; reloadSpeed rutbeye gore | https://github.com/hellsan631/PRAXUS_ZEUS.Altis/blob/master/VCOMAI/functions/VCOMAI_DefaultSettings.sqf | yuksek (okundu), eski kopya | A ve B arasi tutarsizlik: VCOM varsayilanlari surumden surume cok degismis -> hangisi guncel BULUNAMADI. Guncel VCOM'da CBA ayari "AI impacted by VCOM skill settings" var; hata: kapatilsa da uygulanmasi (v3.3.3) https://github.com/genesis92x/VcomAI-3.0/issues/153 |
| VCOM: VCOM_HEARINGDISTANCE=600, VCOM_GRENADECHANCE=20, VCOM_IncreasingAccuracy=true, NOAI_FOR_PLAYERLEADERS=1 | https://github.com/hellsan631/PRAXUS_ZEUS.Altis/blob/master/VCOMAI/functions/VCOMAI_DefaultSettings.sqf | orta (eski surum) | |
| EOS script ornek: INF/ARM/LIG/AIR/STA hepsi [aimingAccuracy 0.25, aimingShake 0.45, aimingSpeed 0.6, spotDistance 0.4, spotTime 0.4, courage 1, reloadSpeed 1, commanding 1, general 1] | https://github.com/Mange/Arma-3-missions/blob/master/Drip_Drop.Altis/eos/AI_Skill.sqf | yuksek (okundu) | Tek kisi mission script'i; "standart bir kalibrasyon" degil, ornek |
| WebSearch: "0.25 ile aimingAccuracy, aimingShake, aimingSpeed, spotTime, spotDistance, reloadSpeed" yaygin dengeli ayar | WebSearch ozeti (Steam, okunamadi): https://steamcommunity.com/app/107410/discussions/0/828940421742644643 | dusuk | |
| LAMBS Danger: beceri (setSkill) ayari YOK. settings.inc.sqf icinde "skill/accuracy" gecen ayar bulunmadi; ayarlar: davranis (kacma, bastirma, CQB, panik, bilgi paylasimi) | https://raw.githubusercontent.com/nk3nny/LambsDanger/master/addons/main/settings.inc.sqf ve .../addons/danger/settings.inc.sqf | yuksek | LAMBS beceriyi sabit tutar, davranisi degistirir; kalibrasyon olarak "gercekci beceri" onermez. Guncel surum 2.6.1 (README) |
| TCL (Tactical Combat Link) wiki: beceri sayisal degerleri sayfalarda bulunamadi ("Advanced configuration" yalnizca "TODO") | https://github.com/Arma-TCL-TypeX/TCL-TypeX-docs/wiki/Advanced-configuration | yuksek (bulunamadigi icin) | TCL beceri degerleri BULUNAMADI |

---------------------------------------------------------------
## 2. ACE3 tibbi (kaynak kod)

### 2.1 Ayar adlari ve varsayilanlar

| DEGER / TANIM | KAYNAK | GUVEN | NOT |
|---|---|---|---|
| ace_medical_AIDamageThreshold: slider 0-25, CBA varsayilan 1 (ucuncu eleman), aciklama: "AI'nin bayilmadan (veya Sum of Trauma aciksa olmeden) once alabilecegi hasar" | https://raw.githubusercontent.com/acemod/ACE3/master/addons/medical_damage/initSettings.inc.sqf ; aciklama: .../addons/medical_damage/stringtable.xml | yuksek | Kodda `[0, 25, 1, 2]` formati CBA'da [min,max,varsayilan,ondalik]. Eski surumlerde varsayilanlar farkli olabilir |
| ace_medical_playerDamageThreshold: slider 0-25, varsayilan 1 | ayni | yuksek | Gercek kullanimda cogunlukla override edilir (ornek 3.5) |
| ace_medical_fatalDamageSource: 0 = yalniz vital atislar, 1 = Sum of Trauma (travma toplami), 2 = ikisi (VARSAYILAN 2) | ayni | yuksek | |
| ace_medical_useLimbDamage: 0 Never (VARSAYILAN), 1 AI only, 2 Players and AI; ace_medical_limbDamageThreshold: 0-25, varsayilan 5 | ayni | yuksek | Uzuv travmasi esigi = limbDamageThreshold x damageThreshold |
| ace_medical_painUnconsciousChance: 0-1, varsayilan 0.1; ace_medical_painUnconsciousThreshold: 0-1, varsayilan 0.5; ace_medical_deathChance: 0-1, varsayilan 1 (yalniz oyuncular icin uygulanir) | ayni | yuksek | woundsHandlerBase: `if (!isPlayer _unit \|\| random 1 < deathChance)` => AI icin deathChance etkisiz |
| ace_medical_statemachine_AIUnconsciousness: checkbox, VARSAYILAN true; ace_medical_statemachine_fatalInjuriesAI: Always / In Cardiac Arrest / Never (VARSAYILAN Never); cardiacArrestTime 300 sn | https://raw.githubusercontent.com/acemod/ACE3/master/addons/medical_statemachine/initSettings.inc.sqf | yuksek | "AI fatal injuries = In Cardiac Arrest" ise AIUnconsciousness acik olmali (dokuman) |
| ace_medical_ai_enabledFor: 0 Disabled / 1 Server&HC only / 2 Enabled (VARSAYILAN 2); ace_medical_ai_requireItems: 0/1/2 (VARSAYILAN 0) | https://raw.githubusercontent.com/acemod/ACE3/master/addons/medical_ai/initSettings.inc.sqf | yuksek | Bu ayar AI MEDIK'in (yaralilari tedavi) acik olmasini kontrol eder; AI'nin bayilma/olum esigini degil. Mission restart gerekir |
| ace_medical_spontaneousWakeUpChance varsayilan 0.1, ace_medical_spontaneousWakeUpEpinephrineBoost 1.5, fractureChance 0.8 | https://raw.githubusercontent.com/acemod/ACE3/master/addons/medical/initSettings.inc.sqf | yuksek | |

### 2.2 Olum / bayilma mantigi (koddan)

| DEGER / TANIM | KAYNAK | GUVEN | NOT |
|---|---|---|---|
| Sabitler: HEAD_DAMAGE_THRESHOLD=1; ORGAN_DAMAGE_THRESHOLD=0.6; HEART_HIT_CHANCE=0.05; PENETRATION_THRESHOLD=0.35; LIMPING 0.30; FRACTURE 0.50 | https://raw.githubusercontent.com/acemod/ACE3/master/addons/medical_engine/script_macros_medical.hpp | yuksek | Sabitler `const_*` degiskenleriyle config/sabit olabilir |
| determineIfFatal (fatalDamageSource 0 veya 2): tek yara hasari >= 1 kafaya = kesin olum; govdede yara >= 0.6 ise %5 kalp vurusu = olum | https://raw.githubusercontent.com/acemod/ACE3/master/addons/medical_damage/functions/fnc_determineIfFatal.sqf | yuksek | "Hasar" burada ACE'nin zirh sonrasi cevirilmis degeridir (damage = vanilla yeni hasar x zirh katsayisi) |
| determineIfFatal (fatalDamageSource 1 veya 2, Sum of Trauma): vitalDamage = max(basHasar - 1.25 x esik, 0) + max(govdeHasar - 1.5 x esik, 0) (+uzuvlar, useLimbDamage'e bagli); olum olasiligi = 1 - exp(-(vitalDamage / L)^K) (Weibull) | ayni | yuksek | Weibull K ve L sabit degerleri BULUNAMADI (initConstants dosyasi bulunamadi) |
| handleIncapacitation: AI/oyuncu bayilir (CriticalInjury) eger basHasar > esik/2 VEYA govdeHasar (penetre etmeyen yaralar haric) > esik VEYA (agri >= painUnconsciousThreshold VE random < painUnconsciousChance) | https://raw.githubusercontent.com/acemod/ACE3/master/addons/medical_damage/functions/fnc_handleIncapacitation.sqf | yuksek | woundsHandlerBase: kritik hasar = kafa isabeti veya govde yarasi > 0.35 penetrasyon -> handleIncapacitation cagrilir |
| Esik makrosu: GET_DAMAGE_THRESHOLD = unit'in 'ace_medical_damageThreshold' degiskeni; yoksa AI icin AIDamageThreshold, oyuncu icin playerDamageThreshold | https://raw.githubusercontent.com/acemod/ACE3/master/addons/medical_engine/script_macros_medical.hpp | yuksek | Birimler bazinda setVariable ile ozel esik verilebilir (ornek: sadece bir tarafa) |
| Mermi yara sayisi esikleri (ACE_Medical_Injuries bullet): thresholds {{20,10},{4.5,2},{3,1},{0,1}}; ACE yaralari: VelocityWound sadece 0.35-1.5 hasar araliginda | https://raw.githubusercontent.com/acemod/ACE3/master/addons/medical_damage/ACE_Medical_Injuries.hpp | yuksek | |
| Tavsiye (ACE resmi "Co-Op preset 1"): fatalDamageSource=1; AIDamageThreshold=0.2 ("AI tek kafa atisiyla ve govdeye birkac atisla olur, yelege gore"); playerDamageThreshold=3.5; bleedingCoefficient=0.25; spontaneousWakeUpChance=0.85; AIUnconsciousness=true; cardiacArrestTime=630 | https://raw.githubusercontent.com/acemod/ACE3/master/docs/wiki/feature/medical-system.md | yuksek | Bu, ACE'nin kendi dokumani |
| ACE PvP preset: fatalDamageSource=1; spontaneousWakeUpChance=0.15; cardiacArrestTime=300 | ayni | yuksek | |
| 5.56 / 7.62 / RPG / 40mm HE icin tipik "bayilma/olum" orani | BULUNAMADI | - | Hicbir kaynakta yuzde tablo yok; sonuc zirh, vurulan bolge, hasar bolgesine bagli. Ancak yapi: esik 0.2 iken govde bayilma esigi 0.2 (penetre yaralar sayilir), kafa 0.1 -> neredeyse her gercek tufek isabeti bayiltir/oldurur (TAHMIN, kaynaksiz: isabet basina yara hasari ~0.35+ penetrasyon esigi uzerinde). Test gerekir |
| AI dogruluk, yara/kirik ile dusmuyor: ACE dogruluk dusurmeyi setCustomAimCoef ile yapar; bu komut AI'da calismaz. Issue "not planned" kapandi | https://github.com/acemod/ACE3/issues/7391 | orta-yuksek | Yani yaralanan AI atis kabiliyetini korur (yalniz bayilirsa durur) |
| ACE tarafsiz: playerDamageThreshold ve AIDamageThreshold iki ayri ayar -> iki tarafin dayanikliligi, taraf degil OYUNCU / AI ayrimi yapar. Taraf bazli esit/farkli yapmak icin birim bazinda setVariable ('ace_medical_damageThreshold') gerekir | koddan (GET_DAMAGE_THRESHOLD makrosu) | yuksek | Makro ismi koddan; kullanim yontemi cikarim (orta) |

---------------------------------------------------------------
## 3. Balistik ve optik

| DEGER / TANIM | KAYNAK | GUVEN | NOT |
|---|---|---|---|
| ACE Advanced Ballistics ayarlari: ace_advanced_ballistics_enabled (VARSAYILAN false, mission restart), muzzleVelocityVariationEnabled true, ammoTemperatureEnabled true, barrelLengthInfluenceEnabled true, bulletTraceEnabled true, simulationInterval 0.05 (0-0.2) | https://raw.githubusercontent.com/acemod/ACE3/master/addons/advanced_ballistics/initSettings.inc.sqf | yuksek | |
| AB ozellikleri: surtunme/BC bazli drag, hava yogunlugu, ruzgar, spin drift, Coriolis/Eotvos, transonik kararsizlik, namlu uzunluguna bagli degisken namlu cikis hizi | https://raw.githubusercontent.com/acemod/ACE3/master/docs/wiki/feature/advanced-ballistics.md | yuksek | |
| AB yerel birimin mermisine uygulanir (`!local _unit` degilse tam simule); uzak birimin mermisi yalnizca izleyiciye yakin veya izli ise detayli simule edilir -> AI mermileri de AB'den etkilenir (ruzgar/drag), ama AI ruzgar telafisi YAPMAZ (TAHMIN, kaynaksiz) | https://raw.githubusercontent.com/acemod/ACE3/master/addons/advanced_ballistics/functions/fnc_handleFired.sqf | orta | Kod okundu; AI telafi yapmadigi yorumu kaynaksiz |
| ACE Overheating dagilimi: ace_overheating_enabled (varsayilan true), ace_overheating_overheatingDispersion (varsayilan true, restart), heatCoef 1, coolingCoef 1, jamChanceCoef 1, particleEffectsAndDispersionDistance (slider) | https://raw.githubusercontent.com/acemod/ACE3/master/addons/overheating/initSettings.inc.sqf | yuksek | "ACE Weapon Dispersion" adinda ayri bir ayar BULUNAMADI; ACE'de dagilimi etkileyen modul overheating |
| 5.56x45 M855A1 / 7.62x39 / 5.45x39 isabet dagilimi (MOA, CfgWeapons dispersion degerleri) | BULUNAMADI (CfgAmmo/CfgWeapons sadece oyun icinde, GitHub'da yok) | - | Silah mod'una (RHS, CUP vb.) bagli |
| AI optik kullanimi: AI nisan alirken optik zoom kullanmaz, isabeti optikten iyilesmez; optikli AI uzak hedefleri atlayabilir. Tahmini maksimum angajman menzili: iron sight 700-800 m, ACO 300-400 m, RCO 500-600 m | WebSearch ozeti (oyun forumu): https://forums.sixdays.com/main/viewtopic.php?p=867 ve BI feedback https://feedback.bistudio.com/T119114 (okunamadi) | dusuk | Guvenilirligi dusuk, ikinci el. Kendi testinle dogrula |

---------------------------------------------------------------
## 4. Zeus / sandbox: iki tarafin AI becerisini esitleme/farklilastirma

| DEGER / TANIM | KAYNAK | GUVEN | NOT |
|---|---|---|---|
| ZEN "Global AI Skill" modulu: tek bir ayar seti (general, aimingAccuracy, aimingSpeed, aimingShake, commanding, courage, spotDistance, spotTime, reloadSpeed 0-1 yuzde sliderlari + seekCover, autoCombat, suppression evet/hayir). publicVariable ile herkese yayilir, TUM yerel birimlere uygulanir, taraf ayrimi YOK; yeni dogan CAManBase'e initMan ile uygulanir | https://raw.githubusercontent.com/zen-mod/ZEN/master/addons/modules/functions/fnc_moduleGlobalAISkill.sqf ; .../addons/ai/functions/fnc_handleSkillsChange.sqf ; .../addons/ai/functions/fnc_initMan.sqf | yuksek | Taraflari farkli yapmak icin kendi kodun gerekir |
| Taraf bazli esitleme/farklilastirma yontemi (SQF): her birim icin `_u setSkill ["aimingAccuracy", x]` vb.; taraf ayrimi: `side group _u == east`. Yeni birimler icin CBA_fnc_addClassEventHandler("CAManBase","InitPost") ile | WebSearch: https://community.bistudio.com/wiki/setSkill ve ZEN'in initMan yontemi (ayni CBA event kalibi) | orta | |
| ASR_AI3 skill sinifi ile faction katsayisi: "AI skill faction coefficients" (ornek [['LOP_AA',0.9],['LOP_IA',0.9]]) = fraksiyon bazli carpan | https://raw.githubusercontent.com/robalo/mods/master/asr_ai3/addons/skills/initSettings.sqf | yuksek (ancak yorumda) | Fraksiyona gore farklilastirmanin hazir yolu (ASR yuklenirse) |
| VCOM: CBA "AI impacted by VCOM skill settings" ac/kapat; VCOM, kapatilmadan beceri atar | https://github.com/genesis92x/VcomAI-3.0/issues/153 | orta | Beceriyi kendin ayarliyorsan VCOM beceri atamasini kapat |
| LAMBS CBA ayarlari (beceri degil, davranis): lambs_danger_cqbRange 20-150 (vars. 60), lambs_danger_panicChance 0-1 (vars. 0), lambs_danger_disableAIPlayerGroup, lambs_danger_disableAIAutonomousManoeuvres, lambs_main_minSuppressionRange (vars. 50), lambs_main_maxRevealValue 0-4 (vars. 1), lambs_main_combatShareRange (vars. 200), lambs_main_radioShout (vars. 100), lambs_main_disableAIDodge/Fleeing/Gestures/Callouts | https://raw.githubusercontent.com/nk3nny/LambsDanger/master/addons/danger/settings.inc.sqf ve .../addons/main/settings.inc.sqf | yuksek (ayar/varsayilanlar okundu); ayar ADI prefixleri (lambs_main_/lambs_danger_) makrodan cikarim: orta | LAMBS tum taraflara esit uygulanir (taraf ayrimi yok); taraf bazli ayar yalniz `radioWest/East/Guer` menzilleri |
| ACE medical: oyuncu vs AI ayri esik; taraf bazli degil. Iki tarafi esitlemek: tum birimlere ayni 'ace_medical_damageThreshold' degiskeni | koddan (GET_DAMAGE_THRESHOLD) | yuksek | |

---------------------------------------------------------------
## TAHMIN (kaynaksiz) - dogrulanmamis, test edilmeli

1. Sandbox'ta iki tarafi ESIT yapmak icin: ZEN Global AI Skill modulunde hepsini ayni deger (orn. aimingAccuracy 0.3, aimingShake 0.4, aimingSpeed 0.5, spotDistance 0.5, spotTime 0.5, courage 0.6, reloadSpeed 0.6) + ACE AIDamageThreshold iki taraf icin ayni. Sayilar kaynaksiz baslangic noktasi.
2. "Gercekci KIA/WIA orani" icin baslangic: fatalDamageSource=1 (veya 2), AIDamageThreshold 0.2-0.5, AIUnconsciousness=true, fatalInjuriesAI=In Cardiac Arrest (bayilanlarin bir kismi kurtarilabilir), cardiacArrestTime 300-630, bleedingCoefficient 0.25 (ACE co-op preset). KIA/WIA yuzdesini olcmek icin kendi 100-atislik testinle iterasyon yap; kaynakta kesin oran yok.
3. ACE yuklu iken isabeti dusurmek icin skill'i cok dusuk (0.01-0.1) vermek yetmeyebilir (%30 isabet, bkz 1.3); bu durumda aimingAccuracy'yi 0 civarina, aimingShake'i dusuk tutup ACE_Overheating dagilimi acik birak.

---------------------------------------------------------------
## Kaynak listesi (en az 10)

1. https://raw.githubusercontent.com/robalo/mods/master/asr_ai3/addons/skills/config.cpp  (CfgAISkill egrileri)
2. https://raw.githubusercontent.com/robalo/mods/master/asr_ai3/addons/skills/initSettings.sqf  (ASR skill setleri)
3. https://raw.githubusercontent.com/robalo/mods/master/asr_ai3/addons/main/script_units.hpp  (ASR seviye 0-10 tanimlari)
4. https://github.com/acemod/ACE3/issues/6948  (ACE ile AI isabet olcumu)
5. https://github.com/acemod/ACE3/issues/7391  (AI dogrulugu yara ile dusmuyor)
6. https://raw.githubusercontent.com/acemod/ACE3/master/addons/medical_damage/initSettings.inc.sqf
7. https://raw.githubusercontent.com/acemod/ACE3/master/addons/medical_damage/functions/fnc_determineIfFatal.sqf
8. https://raw.githubusercontent.com/acemod/ACE3/master/addons/medical_damage/functions/fnc_handleIncapacitation.sqf
9. https://raw.githubusercontent.com/acemod/ACE3/master/addons/medical_damage/functions/fnc_woundsHandlerBase.sqf
10. https://raw.githubusercontent.com/acemod/ACE3/master/addons/medical_engine/script_macros_medical.hpp
11. https://raw.githubusercontent.com/acemod/ACE3/master/docs/wiki/feature/medical-system.md  (preset'ler)
12. https://raw.githubusercontent.com/acemod/ACE3/master/addons/medical_statemachine/initSettings.inc.sqf
13. https://raw.githubusercontent.com/acemod/ACE3/master/addons/medical_ai/initSettings.inc.sqf
14. https://raw.githubusercontent.com/acemod/ACE3/master/addons/advanced_ballistics/initSettings.inc.sqf
15. https://raw.githubusercontent.com/acemod/ACE3/master/addons/overheating/initSettings.inc.sqf
16. https://raw.githubusercontent.com/nk3nny/LambsDanger/master/addons/main/settings.inc.sqf ve .../addons/danger/settings.inc.sqf
17. https://raw.githubusercontent.com/zen-mod/ZEN/master/addons/modules/functions/fnc_moduleGlobalAISkill.sqf
18. https://github.com/Shervanator/arma3-warfare/blob/master/userconfig/VCOM_AI/AISettingsV2.hpp
19. https://github.com/hellsan631/PRAXUS_ZEUS.Altis/blob/master/VCOMAI/functions/VCOMAI_DefaultSettings.sqf
20. https://github.com/genesis92x/VcomAI-3.0/issues/153
21. https://github.com/Mange/Arma-3-missions/blob/master/Drip_Drop.Altis/eos/AI_Skill.sqf
22. https://github.com/Arma-TCL-TypeX/TCL-TypeX-docs/wiki (TCL; beceri verisi yok)
23. Ikinci el (okunamadi, WebSearch ozeti): https://community.bistudio.com/wiki/CfgAISkill , /skillFinal , /setSkill , /skill ; https://forums.sixdays.com/main/viewtopic.php?p=867 ; Steam tartisma sayfalari (yukarida).
