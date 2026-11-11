// ELITE fork (v8.362): 3DEN (Eden Editor) MODULLERI. Zeus gerekmez: senaryo editorde kurulur, gruplar / araclar / dronlar modullere SYNC (baglanti) ile baglanir.
// Her modul sunucuda gorev basinda bir kez calisir (isGlobal = 0) ve Zeus modullerinin kullandigi AYNI sunucu olaylarini tetikler (fnc_edenOrtak: ELITE hazir olana kadar bekler).
// NOT: makro argumanlarinda virgul / parantez YOK (RV on-isleyicisi); metinler bu yuzden sade tutuldu.
// Bu dosya CfgVehicles.hpp'nin ICINDE include edilir (class CfgVehicles govdesi).

#define E_COMBO(ADI,DISP,TIP,DEF,VALS) class ADI: Combo { property = QGVAR(ADI); displayName = DISP; tooltip = TIP; expression = "private _p = '%s'; if ((_p find 'lambs_danger_') != 0) then { _p = 'lambs_danger_' + _p; }; _this setVariable [_p,_value]; if (isNil 'lambs_danger_edIfadeIlk') then { lambs_danger_edIfadeIlk = true; diag_log ['[EDEN-IFADE] ilk nitelik ifadesi CALISTI', _p, _value, typeOf _this]; }; if ((_p find 'Topcu') >= 0 || {(_p find 'Iha') >= 0}) then { diag_log ['[EDEN-IFADE]', _p, _value, typeOf _this]; };"; typeName = "NUMBER"; defaultValue = DEF; class Values { VALS }; };
#define E_V(N,AD) class V##N { name = AD; value = N; };
#define E_NUM(ADI,DISP,TIP,DEF) class ADI: Edit { property = QGVAR(ADI); displayName = DISP; tooltip = TIP; expression = "private _p = '%s'; if ((_p find 'lambs_danger_') != 0) then { _p = 'lambs_danger_' + _p; }; _this setVariable [_p,_value]; if (isNil 'lambs_danger_edIfadeIlk') then { lambs_danger_edIfadeIlk = true; diag_log ['[EDEN-IFADE] ilk nitelik ifadesi CALISTI', _p, _value, typeOf _this]; }; if ((_p find 'Topcu') >= 0 || {(_p find 'Iha') >= 0}) then { diag_log ['[EDEN-IFADE]', _p, _value, typeOf _this]; };"; typeName = "NUMBER"; defaultValue = DEF; validate = "number"; };
#define E_TXT(ADI,DISP,TIP) class ADI: Edit { property = QGVAR(ADI); displayName = DISP; tooltip = TIP; expression = "private _p = '%s'; if ((_p find 'lambs_danger_') != 0) then { _p = 'lambs_danger_' + _p; }; _this setVariable [_p,_value]; if (isNil 'lambs_danger_edIfadeIlk') then { lambs_danger_edIfadeIlk = true; diag_log ['[EDEN-IFADE] ilk nitelik ifadesi CALISTI', _p, _value, typeOf _this]; }; if ((_p find 'Topcu') >= 0 || {(_p find 'Iha') >= 0}) then { diag_log ['[EDEN-IFADE]', _p, _value, typeOf _this]; };"; typeName = "STRING"; defaultValue = """"""; };
#define E_BOOL(ADI,DISP,TIP,DEF) class ADI: Checkbox { property = QGVAR(ADI); displayName = DISP; tooltip = TIP; expression = "private _p = '%s'; if ((_p find 'lambs_danger_') != 0) then { _p = 'lambs_danger_' + _p; }; _this setVariable [_p,_value]; if (isNil 'lambs_danger_edIfadeIlk') then { lambs_danger_edIfadeIlk = true; diag_log ['[EDEN-IFADE] ilk nitelik ifadesi CALISTI', _p, _value, typeOf _this]; }; if ((_p find 'Topcu') >= 0 || {(_p find 'Iha') >= 0}) then { diag_log ['[EDEN-IFADE]', _p, _value, typeOf _this]; };"; typeName = "BOOL"; defaultValue = DEF; };

// ---------------------------------------------------------------------------------------------------------------------------------------------------
// 1) KOORDINASYON (gruplar arasi telsiz agi) - baglanti gerekmez
// ---------------------------------------------------------------------------------------------------------------------------------------------------
class GVAR(EdenKumanda): Module_F {
    author = "ELITE fork";
    _generalMacro = QGVAR(EdenKumanda);
    scope = 2;
    scopeCurator = 0;
    displayName = "ELITE Koordinasyon (3DEN)";
    icon = "\A3\ui_f\data\igui\cfg\simpleTasks\types\intel_ca.paa";
    category = "lambs_danger_elite_cat";
    function = QFUNC(edenKumanda);
    functionPriority = 1;
    isGlobal = 0;
    isTriggerActivated = 0;
    isDisposable = 0;
    class Attributes: AttributesBase {
        E_BOOL(edKumAktif,"Kumanda aktif","Kapali: kumanda hicbir sey yapmaz. Acik: gruplar arasi koordinasyon calisir.","true")
        E_BOOL(edKumIstihbarat,"Istihbarat paylasimi","Bir grubun gordugu dusman telsiz menzilindeki 1500 m diger gruplara bildirilir.","true")
        E_BOOL(edKumTakviye,"Takviye","Zor durumdaki gruba musait 1-2 grup yardima gider.","true")
        E_BOOL(edKumKanat,"Kanat manevrasi","Temasta sabit bir gruba ikinci grup dusmanin kanadindan hucum eder.","true")
        E_BOOL(edKumFeint,"Feint","Kanat manevrasina destek: sinirli hedefli yanilticisi saldiri.","true")
        E_BOOL(edKumMedevac,"Medevac","Hekimi olmayan gruba hekim gonderir. Yalniz ACE saglik sisteminde anlamli.","false")
        E_BOOL(edKumUpstream,"LAMBS dynamic reinforcement kapat","Acik: LAMBS in kendi takviye sistemi kapatilir; takviyeyi yalniz kumanda yapar.","true")
        class ModuleDescription: ModuleDescription {};
    };
    class ModuleDescription: ModuleDescription {
        description = "Gruplar arasi telsiz agi ayarlari. Baglanti gerekmez. Mission basinda bir kez uygulanir.";
    };
};

// ---------------------------------------------------------------------------------------------------------------------------------------------------
// 4) GOREV ATA - baglanan grup / arac / askere gorev yazar
// ---------------------------------------------------------------------------------------------------------------------------------------------------

class GVAR(EdenGorevAta): Module_F {
    author = "ELITE fork";
    _generalMacro = QGVAR(EdenGorevAta);
    scope = 2;
    scopeCurator = 0;
    displayName = "ELITE Gorev Ata (3DEN)";
    icon = "\A3\ui_f\data\igui\cfg\simpleTasks\types\move_ca.paa";
    category = "lambs_danger_elite_cat";
    function = QFUNC(edenGorevAta);
    functionPriority = 1;
    isGlobal = 0;
    isTriggerActivated = 0;
    isDisposable = 0;
    class Attributes: AttributesBase {
        E_COMBO(edGorKod,"Gorev","Baglanan birimlerin gorevi. Otomatik: mevcut gorev korunur (RECON / RECON ARACI silinmez); silmek icin Zorla sil.","0",E_V(0,"Otomatik (mevcut gorevi koru)") E_V(1,"PLAN: Manevra") E_V(2,"PLAN: Destek baski") E_V(3,"PLAN: Yedek") E_V(4,"PLAN: Plan disi HARIC") E_V(5,"OZEL: Medevac ekibi araci") E_V(6,"OZEL: Topcu ates destegi") E_V(7,"OZEL: Topcu DEGIL") E_V(9,"OZEL: Tasima araci APC kamyon") E_V(10,"OZEL: RECON gozlem ekibi") E_V(11,"KOMUTA: Oyuncu komutasi") E_V(12,"KOMUTA: ELITE tam acik") E_V(13,"OZEL: RECON ARACI") E_V(14,"Zorla sil atamayi kaldir"))
        class ModuleDescription: ModuleDescription {};
    };
    class ModuleDescription: ModuleDescription {
        description = "SYNC ile baglanan asker grup ve araclara secilen gorevi yazar. Birden cok birim baglanabilir.";
    };
};

// ---------------------------------------------------------------------------------------------------------------------------------------------------
// 5) KARAKOL / MEVZI - modul konumu; baglanan gruplar savunma plani ile bu mevziye atanir
// ---------------------------------------------------------------------------------------------------------------------------------------------------
class GVAR(EdenKarakol): Module_F {
    author = "ELITE fork";
    _generalMacro = QGVAR(EdenKarakol);
    scope = 2;
    scopeCurator = 0;
    displayName = "ELITE Karakol / Mevzi (3DEN) - kur + hazir garnizon";
    icon = "\A3\ui_f\data\igui\cfg\simpleTasks\types\move_ca.paa";
    category = "lambs_danger_elite_cat";
    function = QFUNC(edenKarakol);
    functionPriority = 1;
    isGlobal = 0;
    isTriggerActivated = 0;
    isDisposable = 0;
    class Attributes: AttributesBase {
        E_COMBO(edKarTaraf,"Taraf savunan sahip","Otomatik: baglanan ilk grubun tarafi; grup yoksa BLUFOR.","0",E_V(0,"Otomatik") E_V(1,"BLUFOR") E_V(2,"OPFOR") E_V(3,"INDEP"))
        E_COMBO(edKarAd,"Ad tur","Harita isaretindeki ad.","0",E_V(0,"Karakol") E_V(1,"Mevzi") E_V(2,"Gozetleme noktasi"))
        E_NUM(edKarYar,"Yaricap m","Karakol cevre yaricapi (garnizon alani da bu yaricap; 30-1500 m onerilir).","120")
        E_COMBO(edKarGar,"Garnizon hazir ayar","Tek modulle karakol + garnizon: Hafif = 2 nobetci + 1 devriye x 2. Standart = 4 nobetci + 2 devriye x 3 + arac mevzisi. Guclu = 6 nobetci + 3 devriye x 3 + arac + anti-air + IHA alarmda gozlem. Ozel ayar (asker takim secimi IHA SYNC devriye mesafesi) icin ayrica Karakol Garnizon modulu koyun.","0",E_V(0,"Yok") E_V(1,"Hafif") E_V(2,"Standart") E_V(3,"Guclu"))
        class ModuleDescription: ModuleDescription {};
    };
    class ModuleDescription: ModuleDescription {
        description = "Modul konumunda karakol veya mevzi tanimlar. SYNC ile baglanan gruplar mevziyi savunur.";
    };
};

// ---------------------------------------------------------------------------------------------------------------------------------------------------
// 6) KARAKOL GARNIZON - karakolun icine birakilir; nobetci devriye ust kat arac mevzisi
// ---------------------------------------------------------------------------------------------------------------------------------------------------
class GVAR(EdenGarnizon): Module_F {
    author = "ELITE fork";
    _generalMacro = QGVAR(EdenGarnizon);
    scope = 2;
    scopeCurator = 0;
    displayName = "ELITE Karakol Garnizon (3DEN) - ozel ayar / IHA / asker sec";
    icon = "\A3\ui_f\data\igui\cfg\simpleTasks\types\move_ca.paa";
    category = "lambs_danger_elite_cat";
    function = QFUNC(edenGarnizon);
    functionPriority = 3;
    isGlobal = 0;
    isTriggerActivated = 0;
    isDisposable = 0;
    class Attributes: AttributesBase {
        E_NUM(edGarNobet,"Nobetci sayisi","Ust kat yuksek arazide tek basina nobet tutan asker.","3")
        E_NUM(edGarDev,"Devriye alt grubu sayisi","Karakol cevresinde dolasan devriye grubu.","1")
        E_NUM(edGarDevBoy,"Devriye boyu asker","Her devriye grubundaki asker sayisi.","3")
        E_BOOL(edGarUst,"Ust kat cati nobet pozisyonlari","Binalarin yuksek ic pozisyonlari nobet adayi olur.","true")
        E_BOOL(edGarArac,"Araclar mevzi olsun","Karakol icindeki AI suruculu kara araclari cevrede ates mevzisine gider.","true")
        E_COMBO(edGarSecim,"Secim modu SYNC","Modulle SYNC edilen askerler: Yalniz kendileri = yalniz o askerler garnizon olur. Takimlari = SYNC edilen askerlerin TAKIMI (grup) garnizona asker verebilir (kaynak takimda en az 3 asker kalir). Hic asker SYNC edilmezse karakol yaricapi havuzu.","0",E_V(0,"Yalniz baglanan askerler") E_V(1,"Baglanan askerlerin takimlari"))
        E_COMBO(edGarAA,"Anti-air konumlandirma","Otomatik: MANPADS (Stinger / Igla / Zipkin ...) tasiyan askerler ayri acik / yuksek AA nobet noktalarina (en cok 3, 55 m aralikla), kendiyurur AA araclari (SPAAG) karakol merkezine yakin ic halkaya gider, STATIK AA (ZU-23 vb.) yerinde kalir. Elle tanim: nesne init this setVariable ['lambs_danger_aa', 'SPAAG', true] (MANPADS / SPAAG / STATIK / NONE). v8.402: varsayilan Otomatik (eskiden Yok: RPT 'AA 0' - kullanici 'akilli AA yerlesimi calismadi' dedi).","1",E_V(0,"Yok") E_V(1,"Otomatik"))
        E_COMBO(edGarIha,"IHA gozlem","Karakola bagli gozlem IHA: Surekli = karakol merkezinde gozlem devriyesi, Alarmda = yalniz grup temasinda. Modulle SYNC edilen IHA kullanilir; baglanmazsa karakol yaricapinin x1.5 icindeki bosta, ayni taraf, GOZLEM tipi IHA (FPV / bomba degil).","0",E_V(0,"Yok") E_V(1,"Surekli gozlem devriyesi") E_V(2,"Alarmda gozlem"))
        E_NUM(edGarIhaYar,"IHA devriye yaricapi m","IHA gozlem devriyesi yaricapi (karakol merkezi etrafinda). 0 = karakol yaricapi (100-800 m).","0")
        E_NUM(edGarIhaSure,"IHA gozlem suresi dk","0 = CBA Gozlem IHA suresi (varsayilan 20 dk).","0")
        E_NUM(edGarDevMes,"Devriye mesafesi m","Devriye rotasinin karakol MERKEZINE uzakligi (halka). 0 = karakol yaricapinin yuzde 60i (yaricap kucukse devriye merkezin dibinde doner). Uzak devriye icin buyuk deger (ornek 600).","0")
        class ModuleDescription: ModuleDescription {};
    };
    class ModuleDescription: ModuleDescription {
        description = "Yakinda karakol yoksa karakol OTOMATIK kurulur (taraf: SYNC askerin / takimin / en yakin AI askerin tarafi; yaricap 150 m). Karakol varsa: karakolun yaricapi + CBA Garnizon ek mesafesi (varsayilan 500 m) icine yerlestirin; garnizon alani karakolun yaricapidir (genis alan icin Karakol yaricapini buyutun, Eden yaricap sinirsiz). Karakol modulunden SONRA calisir. Modulle SYNC edilen AI askerler garnizon havuzu olur (nobetci / devriye yalniz onlardan, yaricap kurali yok); hic asker baglanmazsa karakol yaricapinin x1.5 icindeki gruplardan asker alinir.";
    };
};

// ---------------------------------------------------------------------------------------------------------------------------------------------------
// 7) GOZETLEME ATA - baglanan gruplar modul konumuna en yakin karakolda nobet tutar
// ---------------------------------------------------------------------------------------------------------------------------------------------------
class GVAR(EdenGozetle): Module_F {
    author = "ELITE fork";
    _generalMacro = QGVAR(EdenGozetle);
    scope = 2;
    scopeCurator = 0;
    displayName = "ELITE Gozetleme Ata (3DEN) - squad ekle";
    icon = "\A3\ui_f\data\igui\cfg\simpleTasks\types\scout_ca.paa";
    category = "lambs_danger_elite_cat";
    function = QFUNC(edenGozetle);
    functionPriority = 3;
    isGlobal = 0;
    isTriggerActivated = 0;
    isDisposable = 0;
    class Attributes: AttributesBase {
        E_NUM(edGozAra,"Karakol arama mesafesi m","Modul konumuna bu mesafedeki en yakin ELITE karakol mevzi gozetleme noktasi hedef olur.","300")
        class ModuleDescription: ModuleDescription {};
    };
    class ModuleDescription: ModuleDescription {
        description = "SYNC ile baglanan gruplar modul konumuna en yakin karakolda nobet tutar. Karakol modulunden SONRA calisir.";
    };
};

// ---------------------------------------------------------------------------------------------------------------------------------------------------
// 8) IHA GOREVI - baglanan IHA (dron) ve opsiyonel operator asker
// ---------------------------------------------------------------------------------------------------------------------------------------------------
class GVAR(EdenIha): Module_F {
    author = "ELITE fork";
    _generalMacro = QGVAR(EdenIha);
    scope = 2;
    scopeCurator = 0;
    displayName = "ELITE IHA Gorevi (3DEN)";
    icon = "\A3\ui_f\data\igui\cfg\simpleTasks\types\scout_ca.paa";
    category = "lambs_danger_elite_cat";
    function = QFUNC(edenIha);
    functionPriority = 1;
    isGlobal = 0;
    isTriggerActivated = 0;
    isDisposable = 0;
    class Attributes: AttributesBase {
        E_COMBO(edIhaGorev,"Gorev","Sorti: IHA kendi basina hedef secer ve saldirir. Gozlem: modul konumu etrafinda devriye.","0",E_V(0,"Sorti otomatik hedef") E_V(1,"Gozlem devriyesi") E_V(2,"Gorevi KALDIR"))
        E_COMBO(edIhaTur,"Tur","Otomatik: sinif adindan tahmin.","0",E_V(0,"Otomatik") E_V(1,"FPV-AT zirh avcisi") E_V(2,"FPV-AP personel") E_V(3,"BOMBA Mavic") E_V(4,"GOZLEM"))
        E_COMBO(edIhaTaraf,"Taraf","Otomatik: operatorun ya da arac sinifinin tarafi.","0",E_V(0,"Otomatik") E_V(1,"BLUFOR") E_V(2,"OPFOR") E_V(3,"INDEP"))
        E_NUM(edIhaMenzil,"Menzil m","Kalkis noktasindan hedefe en fazla bu kadar.","3000")
        E_NUM(edIhaYar,"Gozlem yaricapi m","Gozlem devriyesinde modul konumu etrafinda (ucak tipi: daire yaricapi, en az 500 m).","300")
        E_NUM(edIhaSure,"Gozlem suresi dk","Yalniz Gozlem devriyesi. 0 = CBA ayari Gozlem IHA suresi (varsayilan 20 dk).","0")
        E_COMBO(edIhaOp,"Operator bagi","Baglanan asker operatordur. Operator olunce dron kontrolu kaybeder ve duser.","0",E_V(0,"Bagsiz") E_V(1,"Operator olunce dron duser") E_V(2,"Hedefe kilitliyse dalar"))
        class ModuleDescription: ModuleDescription {};
    };
    class ModuleDescription: ModuleDescription {
        description = "SYNC ile bir IHA (dron) ve istege bagli operator askere baglayin. Modul konumu gozlem merkezidir. Gozlem icin Gorev = Gozlem devriyesi: quad / helikopter tipi (Darter, Pelican) rastgele noktalara, ucak tipi (Greyhawk, Ababil, Falcon, Sentinel) daire cizerek ucar.";
    };
};

// ---------------------------------------------------------------------------------------------------------------------------------------------------
// 9) CATISMA POZISYONU (v8.385) - senaryoda ELLE yerlestirilen cover / mevzi / bina ici / cati / gecis noktasi; bagimsiz (SYNC YOK)
//    Modul konumu = pozisyon, modul YONU (rotasyon oku) = ates / ilerleme yonu. Botlar siper secerken (findCover: cover, bounding, geri cekilme), karakol nobetinde ve SAVUN mevzisinde
//    bu pozisyonlari ONEM PUANINA ve TIPINE gore degerlendirir (fnc_cpAday). Tip: pozisyonun ne ise yaradigi (ev ici, cati, ates mevzii, kotu arazide gecis rotasi).
// ---------------------------------------------------------------------------------------------------------------------------------------------------
class GVAR(EdenPozisyon): Module_F {
    author = "ELITE fork";
    _generalMacro = QGVAR(EdenPozisyon);
    scope = 2;
    scopeCurator = 0;
    displayName = "ELITE Catisma Pozisyonu (3DEN)";
    icon = "\A3\ui_f\data\igui\cfg\simpleTasks\types\defend_ca.paa";
    category = "lambs_danger_elite_cat";
    function = QFUNC(edenPozisyon);
    functionPriority = 1;
    isGlobal = 0;
    isTriggerActivated = 0;
    isDisposable = 0;
    class Attributes: AttributesBase {
        E_COMBO(edPozTip,"Pozisyon tipi","Pozisyonun NE ISE YARADIGI. Siper: genel koruma. Bina ici: pencere kapi oda mevzisi. Cati ust kat: gozetleme ve nisanci. Ates mevzii: MG nisanci icin hedefi gorur ve korunur. Gecis: kotu arazide ilerleme rotasi yol noktasi - yalniz ilerlerken adaydir.","0",E_V(0,"Siper genel") E_V(1,"Bina ici pencere kapi oda") E_V(2,"Cati ust kat gozetleme") E_V(3,"Ates mevzii MG nisanci") E_V(4,"Gecis yol noktasi kotu arazi"))
        E_COMBO(edPozPuan,"Onem puani","Yuksek puan = bot bu pozisyonu dogal siperlere tercih eder. Taban skor 20 + puan x 6 - dogal siperler tipik olarak 50-100 alir. 1-3 yedek 4-6 iyi 7-8 cok onemli 9-10 kritik tercih.","5",E_V(1,"1 dusuk") E_V(2,"2") E_V(3,"3") E_V(4,"4") E_V(5,"5 orta") E_V(6,"6") E_V(7,"7") E_V(8,"8") E_V(9,"9") E_V(10,"10 kritik"))
        E_COMBO(edPozTaraf,"Taraf","Hangi tarafin askeri kullanabilir. Hepsi: her taraf.","0",E_V(0,"Hepsi") E_V(1,"BLUFOR") E_V(2,"OPFOR") E_V(3,"INDEP"))
        E_COMBO(edPozDurus,"Durus","Otomatik: dusmandan gizli kalinan en yuksek durus. Sabit: pozisyonda bu durus zorlanir.","0",E_V(0,"Otomatik") E_V(1,"Yatarak") E_V(2,"Comelerek") E_V(3,"Ayakta"))
        E_NUM(edPozKap,"Kapasite asker","Ayni anda pozisyonu kullanabilecek asker 1-8. Dolu pozisyon -45 puan alir. Karakol nobetinde pozisyon basina tek nobetci.","2")
        E_NUM(edPozSektor,"Sektor genisligi derece","Ates ilerleme sektoru 20-360. Merkez = modul yonu. Dusman sektor disindaysa pozisyon aday olmaz. 360 = her yon.","360")
        E_COMBO(edPozRol,"Rol tercihi","Tercih edilen rol eslesirse +16 eslesmezse -14 puan. Karakol nobetinde eslesen rol onceliklidir. Herkes: tercih yok.","0",E_V(0,"Herkes") E_V(1,"Nisanci") E_V(2,"MG") E_V(3,"AT roketatar") E_V(4,"Tufekci"))
        E_BOOL(edPozGarnizon,"Karakol ve mevzi plani kullansin","Karakol nobeti ve SAVUN mevzi plani bu pozisyonu (bina ici cati ates mevzii ve siper tipleri) oncelikli kullanir. Gecis tipi hic kullanilmaz.","true")
        E_BOOL(edPozIsaret,"Oyunda harita isareti","Hata ayiklama: pozisyon tipi ve puani haritada isaretlenir.","false")
        class ModuleDescription: ModuleDescription {};
    };
    class ModuleDescription: ModuleDescription {
        description = "Modul konumu bir catisma pozisyonudur; modul yonu ates veya ilerleme yonudur. Baglanti GEREKMEZ. Tip ve onem puani botlara pozisyonun ne ise yaradigini soyler: cover secimi - bounding - geri cekilme - karakol nobeti - SAVUN mevzisi bu pozisyonlari puana gore kullanir. Gecis tipini kotu arazide 40-60 m arayla zincir olarak dizin.";
    };
};
