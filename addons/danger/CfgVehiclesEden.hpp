// ELITE fork (v8.362): 3DEN (Eden Editor) MODULLERI. Zeus gerekmez: senaryo editorde kurulur, gruplar / araclar / dronlar modullere SYNC (baglanti) ile baglanir.
// Her modul sunucuda gorev basinda bir kez calisir (isGlobal = 0) ve Zeus modullerinin kullandigi AYNI sunucu olaylarini tetikler (fnc_edenOrtak: ELITE hazir olana kadar bekler).
// NOT: makro argumanlarinda virgul / parantez YOK (RV on-isleyicisi); metinler bu yuzden sade tutuldu.
// Bu dosya CfgVehicles.hpp'nin ICINDE include edilir (class CfgVehicles govdesi).

#define E_COMBO(ADI,DISP,TIP,DEF,VALS) class ADI: Combo { property = QGVAR(ADI); displayName = DISP; tooltip = TIP; expression = "_this setVariable ['%s',_value];"; typeName = "NUMBER"; defaultValue = DEF; class Values { VALS }; };
#define E_V(N,AD) class V##N { name = AD; value = N; };
#define E_NUM(ADI,DISP,TIP,DEF) class ADI: Edit { property = QGVAR(ADI); displayName = DISP; tooltip = TIP; expression = "_this setVariable ['%s',_value];"; typeName = "NUMBER"; defaultValue = DEF; validate = "number"; };
#define E_BOOL(ADI,DISP,TIP,DEF) class ADI: Checkbox { property = QGVAR(ADI); displayName = DISP; tooltip = TIP; expression = "_this setVariable ['%s',_value];"; typeName = "BOOL"; defaultValue = DEF; };

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
// 2) HQ / US - modul konumu komuta noktasi; baglanan gruplar bu kategoriye atanir
// ---------------------------------------------------------------------------------------------------------------------------------------------------
class GVAR(EdenHQ): Module_F {
    author = "ELITE fork";
    _generalMacro = QGVAR(EdenHQ);
    scope = 2;
    scopeCurator = 0;
    displayName = "ELITE HQ / US Kur (3DEN)";
    icon = "\A3\ui_f\data\igui\cfg\simpleTasks\types\move_ca.paa";
    category = "lambs_danger_elite_cat";
    function = QFUNC(edenHQ);
    functionPriority = 1;
    isGlobal = 0;
    isTriggerActivated = 0;
    isDisposable = 0;
    class Attributes: AttributesBase {
        E_COMBO(edHqTaraf,"Taraf","Otomatik: baglanan ilk grubun tarafi; grup yoksa BLUFOR.","0",E_V(0,"Otomatik") E_V(1,"BLUFOR") E_V(2,"OPFOR") E_V(3,"INDEP"))
        E_COMBO(edHqKat,"Kategori","Ayni kategori ve taraf tekrar kurulursa tasinir.","0",E_V(0,"HQ1") E_V(1,"HQ2") E_V(2,"HQ3") E_V(3,"US ana ussu"))
        E_NUM(edHqYar,"Yaricap m","Donuste ulasti sayilma mesafesi ve harita isareti.","100")
        class ModuleDescription: ModuleDescription {};
    };
    class ModuleDescription: ModuleDescription {
        description = "Modul konumu komuta noktasi olur. Bu module BAGLANAN gruplar bu HQ ya atanir. Objektif modulune de baglayin.";
    };
};

// ---------------------------------------------------------------------------------------------------------------------------------------------------
// 3) OBJEKTIF (komutan plani) - modul konumu objektif; HQ modulu ve plan gruplari baglanir
// ---------------------------------------------------------------------------------------------------------------------------------------------------
class GVAR(EdenObjektif): Module_F {
    author = "ELITE fork";
    _generalMacro = QGVAR(EdenObjektif);
    scope = 2;
    scopeCurator = 0;
    displayName = "ELITE Objektif - komutan plani (3DEN)";
    icon = "\A3\ui_f\data\igui\cfg\simpleTasks\types\attack_ca.paa";
    category = "lambs_danger_elite_cat";
    function = QFUNC(edenObjektif);
    functionPriority = 2;
    isGlobal = 0;
    isTriggerActivated = 0;
    isDisposable = 0;
    class Attributes: AttributesBase {
        E_COMBO(edObTaraf,"Taraf","Otomatik: baglanan HQ nun ya da ilk grubun tarafi.","0",E_V(0,"Otomatik") E_V(1,"BLUFOR") E_V(2,"OPFOR") E_V(3,"INDEP"))
        E_COMBO(edObTip,"Gorev tipi","Ele gecir: toplan - ORP - kesif - saldiri. Savun: objektif cevresinde sektorlu mevzi.","0",E_V(0,"Ele gecir saldiri") E_V(1,"Savun mevzilen"))
        E_COMBO(edObTempo,"Tempo","Sessiz: AWARE-STEALTH ve ates disiplini. Hizli: tam hiz kisa kesif.","0",E_V(0,"Dengeli") E_V(1,"Sessiz gizli") E_V(2,"Hizli agresif"))
        E_COMBO(edObBasla,"Baslama H-saati","Plan kurulduktan sonra harekete gecme zamani.","0",E_V(0,"Hemen") E_V(1,"30 sn") E_V(2,"60 sn") E_V(3,"120 sn") E_V(4,"300 sn"))
        E_COMBO(edObSure,"Sure siniri","Ele gecir: toplam sure. Savunma: temassiz sure.","0",E_V(0,"Sinirsiz") E_V(1,"10 dk") E_V(2,"20 dk") E_V(3,"30 dk") E_V(4,"45 dk") E_V(5,"1 saat") E_V(6,"2 saat") E_V(7,"4 saat") E_V(8,"10 saat"))
        E_NUM(edObGecikme,"Kurulum gecikmesi sn","Mission basladiktan sonra plan istegi bu kadar sn sonra gonderilir.","10")
        E_COMBO(edObGrupSec,"Grup secimi","Bagli gruplar: modul e SYNC edilen gruplar plana alinir. Otomatik: HQ ya atananlardan sayiya gore secilir. HQ tamami: HQ ya bagli tum squadlar.","1",E_V(0,"Otomatik sayi") E_V(1,"Bagli gruplar") E_V(2,"HQ tamami guvenlik birakilir") E_V(3,"HQ tamami hepsi"))
        E_NUM(edObGrupN,"Katilacak grup sayisi","Yalniz Otomatik secimde.","4")
        E_BOOL(edObPiy,"Dusman: piyade var","Objektifte dusman piyadesi var.","true")
        E_BOOL(edObZirh,"Dusman: zirh arac var","Tank APC teknik var. Isaretli degilse zirh yok kabul edilir.","false")
        E_BOOL(edObAt,"Dusman: AT RPG var","Roketatar fuze tasiyan dusman var.","false")
        E_BOOL(edObMg,"Dusman: MG var","Makineli tufek var - kanat manevrasi.","false")
        E_BOOL(edObNis,"Dusman: nisanci var","Keskin nisanci var.","false")
        E_BOOL(edObBina,"Dusman: binalarda mevzili","CQB bina temizleme beklenir.","false")
        E_NUM(edObSay,"Dusman sayisi tahmin","0 bilinmiyor.","0")
        E_BOOL(edObSivil,"Kisit: siviller var","Destek grubu korleme baski atesi yapmaz.","false")
        E_BOOL(edObAgir,"Kisit: binalara agir silah yasak","Binadaki hedefe roket fuze 40 mm bomba atilmaz.","false")
        E_NUM(edObRally,"Rally point mesafesi m","Toplanma noktasi objektiften bu kadar geride ortulu.","450")
        E_NUM(edObOrp,"ORP mesafesi m","TC 3-21.76: ORP tipik olarak 200-400 m.","300")
        E_COMBO(edObBaskin,"Baskin vur-cek","Evet: hedef temizlenince ya da sure dolunca cekilme.","0",E_V(0,"Hayir ele gecir") E_V(1,"Evet 5 dk") E_V(2,"Evet 10 dk"))
        E_COMBO(edObTehdit,"Tehdit yonu savunma","Dusmanin objektife geldigi yon.","0",E_V(0,"Bilinmiyor") E_V(1,"Kuzey") E_V(2,"Kuzeydogu") E_V(3,"Dogu") E_V(4,"Guneydogu") E_V(5,"Guney") E_V(6,"Guneybati") E_V(7,"Bati") E_V(8,"Kuzeybati"))
        E_NUM(edObMevziYar,"Mevzi arama yaricapi m","Savunma icin hendek ve karakol arama yaricapi.","500")
        E_NUM(edObOran,"Min. kuvvet orani saldiri","Dost dusman orani bunun altindaysa komutan saldirmaz. 0 kapi kapali.","2")
        E_COMBO(edObGuven,"Bilgi guvenilirligi","Komutanin elindeki bilgi.","1",E_V(0,"Yetersiz") E_V(1,"Orta tek kaynak") E_V(2,"Kesin ama yine iddia"))
        E_COMBO(edObDogr,"Dogrulama disiplini","Tam kesif: rapor gelmeden topcu atmaz. Yok: iddiaya guvenir.","0",E_V(0,"Tam kesif") E_V(1,"Son dogrulama kisa") E_V(2,"YOK iddiaya guvenilir"))
        E_COMBO(edObTopcu,"Ates destegi topcu havan","Tarafin topcu havan araclari kullanilir.","0",E_V(0,"Yok") E_V(1,"Hazirlik atesi") E_V(2,"Cagri atesi") E_V(3,"Hazirlik ve cagri"))
        E_NUM(edObTopcuN,"Topcu atis sayisi mermi","Atis seansi basina mermi.","4")
        E_COMBO(edObTopcuBasit,"Topcu modu","Basit: dogrulama beklenmez.","0",E_V(0,"Standart dogrulamali") E_V(1,"BASIT dogrulamasiz"))
        E_COMBO(edObZincir,"Hedef zinciri","Zincire ekle: ayni taraftaki aktif planin siradaki hedefi olur.","0",E_V(0,"Hayir bagimsiz plan") E_V(1,"Zincire ekle"))
        E_COMBO(edObRecon,"Recon ek gozlem","Evet: recon dusman noktalarini da gizlice gozlemler. Gorev Ata ile RECON grubu gerekir.","0",E_V(0,"Hayir") E_V(1,"Evet gizlice incele"))
        E_COMBO(edObTut,"Ele gecirileni tut zincir","Zincirde ele gecirilen objektifte squad birakilir.","1",E_V(0,"Hayir hepsi ilerler") E_V(1,"Evet 1 squad birak") E_V(2,"Evet 2 squad birak"))
        E_COMBO(edObDron,"Dron operatoru avi","Dusman dronu cok kez gorulunce operator bolgesine devriye.","0",E_V(0,"CBA ayarina uy") E_V(1,"Hayir") E_V(2,"3 kisi yaya") E_V(3,"4 kisi yaya") E_V(4,"3 kisi hafif arac") E_V(5,"4 kisi hafif arac"))
        E_COMBO(edObOtoGar,"Otomatik mevzi garnizon bolgeleri","Arazi analizi ile karakol mevzi gozletme bolgeleri.","0",E_V(0,"Hayir") E_V(1,"Evet") E_V(2,"Evet guclu"))
        class ModuleDescription: ModuleDescription {};
    };
    class ModuleDescription: ModuleDescription {
        description = "Modul konumu OBJEKTIF. ELITE HQ modulune ve plan gruplarina SYNC ile baglayin. Ele gecir plani icin HQ gerekir; grup baglamazsaniz otomatik secim yapilir.";
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
        E_COMBO(edGorKod,"Gorev","Baglanan birimlerin gorevi. Otomatik: atama silinir.","0",E_V(0,"Otomatik atamayi sil") E_V(1,"Plan MANEVRA") E_V(2,"Plan DESTEK baski SBF") E_V(3,"Plan YEDEK") E_V(4,"Plan disi HARIC") E_V(5,"MEDEVAC ekibi araci") E_V(6,"TOPCU ates destegi") E_V(7,"Topcu DEGIL") E_V(9,"TASIMA araci APC kamyon") E_V(10,"RECON gozlem gizli") E_V(11,"OYUNCU KOMUTASI") E_V(12,"ELITE TAM ACIK") E_V(13,"RECON ARACI"))
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
    displayName = "ELITE Karakol / Mevzi (3DEN)";
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
        E_COMBO(edKarSav,"Savunma","Hemen: baglanan gruplarla savunma plani kurulur; grup baglanmazsa yaricap x1.5 icindeki savunan gruplar alinir. Alarm: dusman 800 m icinde bilinince plan kurulur.","1",E_V(0,"Yok yalniz isaret") E_V(1,"Savunma plani HEMEN") E_V(2,"Alarm dusman yaklasinca"))
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
    displayName = "ELITE Karakol Garnizon (3DEN)";
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
        E_NUM(edGarDevMes,"Devriye mesafesi m","Devriye rotasinin karakol MERKEZINE uzakligi (halka). 0 = karakol yaricapinin yuzde 60i (yaricap kucukse devriye merkezin dibinde doner). Uzak devriye icin buyuk deger (ornek 600).","0")
        class ModuleDescription: ModuleDescription {};
    };
    class ModuleDescription: ModuleDescription {
        description = "Karakolun yaricapi + CBA Garnizon ek mesafesi (varsayilan 500 m) icine yerlestirin; garnizon alani karakolun yaricapidir (genis alan icin Karakol yaricapini buyutun, Eden yaricap sinirsiz). Karakol modulunden SONRA calisir. Modulle SYNC edilen AI askerler garnizon havuzu olur (nobetci / devriye yalniz onlardan, yaricap kurali yok); hic asker baglanmazsa karakol yaricapinin x1.5 icindeki gruplardan asker alinir.";
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
    displayName = "ELITE Gozetleme Ata (3DEN)";
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
