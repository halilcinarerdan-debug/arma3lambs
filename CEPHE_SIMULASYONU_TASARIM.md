# CEPHE SİMÜLASYONU — "Genelkurmay / Cephe Komutanı" Tasarım Özeti (v8.236 sonrası, yeni sohbet için devir)

Yazıldığı tarih: 2026-10-14. Kaynak: kullanıcı isteği (bu sohbetin son mesajları) + `DEVIR_LOGU_v7.0.txt`.
**Bu belge KOD DEĞİL, tasarım ve iş bölümüdür.** Yeni sohbette önce bu belge + `DEVIR_LOGU_v7.0.txt` son 15 sürüm girdisi + `OZELLIKLER_LISTESI.md` (10d) okunmalı.

---

## 1. Vizyon (kullanıcının sözleriyle özet)

- İnsanın yaptığı tek şey: **üsleri / karakolları (FOB, COP, karakol, mevzi, gözetleme noktası, hendek) haritada elle yerleştirip sisteme TANIMLAMAK.** Geri kalanı komutan hesaplar:
  hangi kamyon nereye, hangi topçu hangi hedefe, hangi squad hangi FOB / karakolda duracak, ikmal, nöbet değişimi, ağır silah (bipodlu / tripodlu / statik) yerleşimi.
- **Eski sistem durur.** Elle düzenleme (Zeus: Objektif, Gözetleme Ata, Görev Ata, HQ, Karakol...) çalışmaya devam eder. Yeni katman **opsiyoneldir**: "Cephe Komutanı zekâsı" açılırsa kararları o verir; kapalıysa bugünkü gibi elle.
- **OPORD artık doğrudan CEPHEDEKİ BAŞ KOMUTANA** (cephe komutanı) verilir (Zeus'tan): neredeyiz, ne var, düşman kim, görev ne, sivil var mı. Komutan bu bilgiye göre **tavır alır** (örn. cephede sivil varsa ROE sıkı, topçu / ağır silah kısıtlı).
- **Düşmanı öğretiriz** ("kimle savaşıyoruz"): doktrin profili + kullandığı yöntemler (TTP). Komutan **öğrenir** (oturum içi, mevcut `fnc_komutanZihin` genişler): düşmanın yaklaşma yönü, ateş desteği kullanımı, duman, zırh, pusu, vb.
- **Kendi inisiyatifini alır:** bazı yapıları kendisi saptar, **COP / FOB kurup kurmamaya** kendisi karar verebilir (yetki seçilebilir: "yalnız tanımlılar" / "aday öner" / "kendi kursun"). Mevzi seçimi bunun için daha esnek olur.
- **Bot vs bot ve oyuncuya karşı bot** iki mod.
- **Resmî iş akışı:** her HQ üst HQ'ya rapor verir (SITREP / SPOTREP / LOGSTAT / CASREP / INTSUM benzeri). Komuta zinciri: Cephe → HQ → FOB/COP komutanı → karakol / squad.
- **Lojistik:** her asker susuzluk / açlık yaşar (ACE Field Rations öğeleriyle uyumlu), FOB'da yeniler; hepsi CBA ayarlarından açılıp kapanır / hızlanır. Su: asker başına günde 6 L, MRE günde 1 (`doktrinler.md` Class I planlama faktörleri); COP: kritik geçitlerde müfreze boyutunda, karşılıklı destekli noktalar.
- **Askıda:** drone / İHA / FPV işleri (v8.232-235 temel kod duruyor: `ihaGozlem`, `ihaSorti`, `ihaEnvanter`, Zeus "ELITE IHA Görevi"; test edilmedi, kullanıcı sonra test edecek). **Dokunma, bozma.**

## 2. Tasarım ilkeleri

1. **Hile yok:** komutan haritadaki gerçek konumları OKUMAZ; yalnız (a) elle tanımlananlar, (b) kendi birliklerinin algıladıkları (`knowsAbout`, SPOTREP ağı), (c) Zeus'ta anlatılan OPORD bilgisi.
2. **Kitaba uy** ("her şey kitaba göre"): sayısal eşik kitapta yoksa **TASARIM DEĞERİ** diye işaretle (devir logunda ve kod başlığında). Doktrin kaynakları: `DOKTRIN_KAYNAKLARI.md`, `kaynaklar_doktrin/`, kullanıcının `doktrinler.md` (FM 3-98, ATP 3-20.15, ATP 4-01.45, ATP 3-21.8, TC 3-21.76, ATP 3-01.8...). Başka modun kodu (Hetman/HAL vb.) KOPYALANMAZ (lisans); fikirler uyarlanır.
3. **Katmanlı ve kapatılabilir:** her ajan kendi `...Off` anahtarıyla kapanır; hepsi kapalıyken bugünkü davranış aynen kalır.
4. **Sunucu yetkili:** tüm kararlar sunucuda; yerel gruplara emir `hqEmir` (tek emir kanalı) ile.
5. **Ölçülebilir:** her ajan `[AJAN-ADI]` etiketli kısa log + özet satırı; test ölçütleri aşağıda.
6. **Performans:** kaba tik (grup düzeyi, 10-60 sn), pahalı hesap (arazi) tek sefer + önbellek.

## 3. Mimari — "kurmay" modeli (9 ajan / modül)

| # | Ajan (J/S) | Sorumluluk | Girdi → Çıktı | Mevcut temel (genişletilecek) |
|---|---|---|---|---|
| 0 | **Kayıt (Registry)** | Üs / karakol / mevzi / hendek / gözetleme / FOB / COP / depo / kamyon / topçu / HQ envanteri; tek doğruluk kaynağı | Zeus modülü + Eden işareti → `lambs_danger_cephe*` hash'leri | `lambs_danger_karakollar`, `hqListe`, `hendekAlani` (işaret `elite_hendek*`), `karakolAyar` |
| 1 | **Arazi ajanı** (terrain / OAKOC) | Arazi ürünleri: yol ağı, köprü / su, ağaçlık, hakim nokta, yapı kümeleri, yaklaşma koridorları, **aday FOB/COP/mevzi alanları** | harita (tek seferlik) → skorlu aday listeleri | `fnc_araziAnaliz`, `fnc_ufukMu`, `fnc_rotaPlan`, `fnc_agacGizlen`, `fnc_siperNokta` mantığı (komutanPlanDongu) |
| 2 | **İstihbarat (S2)** | Düşman resmi, **düşman profili + TTP öğrenme**, sivil varlığı, INTSUM | SPOTREP + Zeus "düşman kim" → profil + hipotezler | `fnc_hqIstihbarat`, `fnc_komutanZihin`, `fnc_olumBolgesi`, PID / iddia-doğrulama (komutanPlan) |
| 3 | **Harekât (S3)** | OPORD ayrıştırma, faz planı, **görev tahsisi** (hangi birim nereye), tavır, yedek, karşı saldırı | OPORD + resim + kayıt → plan(lar) | `fnc_komutanPlan` / `Dongu` (SAVUN / ELE GEÇİR), `hqEmir`, `komutanTavir` |
| 4 | **Lojistik (S4)** | Su / erzak / mühimmat / tıbbi stok, **ikmal sevki**, kamyon rotası, FOB/COP stoku, nöbet değişimi (dinlenme) | stok + tüketim → kamyon görevleri | `fnc_aracTasima`, `taksi`, `cephanePaylas`, `tccc`, `aracMedevac`, YENİ susuzluk / açlık modeli |
| 5 | **Ateş destek (FSCOORD)** | Hangi top hangi hedefe, RED, karşı-batarya, duman, ateş kaydırma; sivil varsa kısıt | hedef listesi + ROE → atış | `_topcuAt` (komutanPlanDongu), `fnc_topcuDestek`, `topcuKonumla`, `topSiper` |
| 6 | **Mühendis / tesis** | **COP / FOB kurma kararı ve kurulumu** (garnizon + hendek + mevzi + ağır silah), site seçimi | arazi adayları + yetki seviyesi → kurulum emri | `fnc_karakolGarnizon`, `mevziKur`, `hendekYerles`, `hendekBilinc` |
| 7 | **Haberleşme / rapor (S6)** | Resmî iş akışı: periyodik **SITREP / LOGSTAT / SPOTREP / CASREP / INTSUM**, rapor çizelgesi, kayıp / gecikme (telsiz şartı) | her HQ → üst HQ | `hqIstihbarat` (telsiz / bilgi sisi), `PLAN-OZET` (AAR) |
| 8 | **Cephe komutanı (CG / J3'ün üstü)** | Hepsini birleştirir: OPORD alır, ajanları sürer, **inisiyatif yetkisi**, bot-vs-bot / oyuncuya karşı modu, **manuel override kuralları** | tümü → tüm kararlar | `fnc_hq` çekirdeği, `komutanZihin` (tavır motoru) |

**Terrain ajanı için bölme (kullanıcının "kaç parçaya bölelim" sorusu): 3 parça.**
- **T1 — Statik tarama (tek sefer, önbellek):** ızgara (örn. 100 m hücre); hücre başına: yükseklik / eğim, ağaç yoğunluğu, su, yol, yapı sayısı, görüş (ufuk) özeti. Saniyeler, açılışta / ilk OPORD'da, `[ARAZI-AJAN]` logu.
- **T2 — Taktik ürünler:** yaklaşma koridorları (yol + açıklık + ortü), hakim noktalar, gözetleme / topçu gözlem noktası adayları, ortülü bekleme alanları (agacGizlen mantığı), engel / ana ikmal yolları (köprü / dar geçit).
- **T3 — Site seçimi:** FOB / COP / mevzi **aday listesi + skor** (ortü, savunulabilirlik, yola yakınlık, sivil yerleşime uzaklık, su temini), sıralı; mühendis ajanı (6) buradan seçer / öneri sunar.
Her parça ayrı fonksiyon + ayrı log + ayrı kapatma anahtarı; T3 yalnız T1+T2 ürünleriyle çalışır.

## 4. OPORD (cephe komutanına) — Zeus modülü taslağı

"ELITE OPORD (Cephe Komutanı)" modülü; 5 paragraf (yalnız öğretmek için; hepsi opsiyonel alan):
1. **Durum:** düşman (doktrin profili: ABD / RUS / DÜZENSİZ / ÖZEL; kuvvet tahmini; bilinen TTP listesi: topçu, zırh, İHA, pusu, IED), dost, **sivil varlığı** (yok / seyrek / yoğun → ROE, topçu kısıtı), arazi notları.
2. **Görev:** cephe hattı / savunma / ileri hareket / geciktirme; hedef bölgeler.
3. **İcra:** niyet, manevra şeması, ateş destek planı, ana / yedek eksen, **inisiyatif yetkisi** (yalnız tanımlı / aday öner / kendi kur FOB-COP), karşı saldırı yetkisi.
4. **Hizmet desteği:** FOB'lar, ikmal öncelikleri, su / erzak seviyesi, dinlenme / rotasyon.
5. **Komuta / sinyal:** HQ hiyerarşisi, rapor aralıkları, telsiz şartı.
Kural: OPORD verilmezse komutan **"bilinmiyor"** der ve temkinli varsayımla çalışır; verilirse değiştirilebilir (FRAGO).

## 5. Veri modeli taslağı (Kayıt)

- `lambs_danger_cepheUsler`: [{id, tur: FOB|COP|KARAKOL|MEVZI|GOZETLEME|HENDEK, taraf, konum, yaricap, ust: id, durum, depo{su, erzak, muhimmat, tibbi}, atananKamyon[], atananSquad[], manuel: bool}]
- `manuel` bayrağı: **elle atanmış her şey komutan tarafından DEĞİŞTİRİLMEZ** (kilit); komutan yalnız `manuel = false` olanlara karar verir. ("Sonradan müdahale edilemesin" = komutan kararı, Zeus kilitle açılır. Yok ayarı: CBA.)
- Eden işaretleri kalır: `elite_hendek*`; yeni: `elite_fob_*`, `elite_cop_*` (alan = yarıçap).
- CBA ayarları (hepsi tek kategoride "ELITE Cephe Komutanı"): komutan açık / kapalı, yetki seviyesi (3), susuzluk / açlık açık, hız çarpanı, eşikler, ACE öğe listeleri, rapor aralıkları.

## 6. Dilim planı (bu sohbetin tavsiyesi: hepsi tek seferde DEĞİL)

| Dilim | İçerik | Test ölçütü (kısa) |
|---|---|---|
| **A** | Kayıt + FOB/COP tanımı (Eden işareti / Zeus modülü) + CBA ayarları + **susuzluk / açlık modeli** (ACE öğeleri, FOB'da yenileme, hafif etki) | 1 FOB, 1 kamyon, 1 squad, hızlandırılmış susuzluk: asker içer, bitince FOB'a gider, `[LOJ-SU]` logları |
| **B** | **Arazi ajanı T1+T2** (+ aday listesi) ve **Kayıt → komutan** köprüsü (Cephe komutanı iskeleti: tanımlıları okur, atama önerisi loglar, henüz EMİR VERMEZ) | aday FOB/COP logu insan gözüyle mantıklı; ölçülü süre (< 3 sn / 10 km²) |
| **C** | **Lojistik ajanı**: stok takibi + ikmal sevki (kamyon görevleri), nöbet değişimi / dinlenme | stok düşünce kamyon FOB'a gider, indirir, döner; `[LOJ-IKMAL]` |
| **D** | **OPORD modülü + istihbarat profili / TTP öğrenme + sivil tavrı** | OPORD'daki "sivil yoğun" → topçu atmaz, ROE sıkı (kayıt: `[OPORD]` + `[PLAN-ROE]`) |
| **E** | **Mühendis ajanı**: inisiyatif — COP/FOB kurma (yetki seviyesine göre) + hendek / mevzi / ağır silah yerleşimi (bipod emülasyonu: yatık+sabit → nişan iyileşmesi) | komutan boş bir yerde kendi COP'unu önerir / kurar, `[MUHENDIS]` logu |
| **F** | **Rapor iş akışı (SITREP / LOGSTAT...)** + bot-vs-bot / oyuncuya karşı modu + son entegrasyon | raporlar zincirde akar; üst HQ logunda özet |

Her dilim: `lambs_danger_<ajan>Off` anahtarı, doktrin / tasarım değeri etiketi, `DEVIR_LOGU` girdisi, `OZELLIKLER_LISTESI.md` satırı, `TEST_SENARYOLARI.md` senaryosu.

## 7. Açık sorular (kullanıcıya bir kez sorulacak, sonra karar kilitlenecek)

1. **"Hetman / NR6 HAL" örneği:** Rydygier'in HETMAN / HAL modu mu? Hangi davranışı örnek: komutan atama mantığı mı, otonom saldırı planı mı?
2. **Susuzluk şiddeti:** hafif (performans düşüşü) mı, sert mi? Öneri: hafif.
3. **ACE öğe adları:** sunucudaki Field Rations / MRE / matara sınıfları (varsayılan liste CBA'dan düzenlenir).
4. **İlk dilim:** A.
5. **Yetki varsayılanı:** "yalnız tanımlı" (öneri) / "aday öner" / "kendi kursun".

## 8. Bilinen riskler / dürüst notlar

- AI sürücü **kök nedeni bilinmiyor** (araç sürmüyor; kinematik sürüş yedek). Lojistik kamyonları da buna takılabilir; `fnc_aracKinSurus` zinciri hazır ama doğrulanmadı.
- Bipod gerçek kurma eylemi AI'ya script'le yaptırılamıyor → emülasyon (yatık + sabit + nişan / geri tepme katsayısı).
- ACE Field Rations oyuncu için; AI için **kendi susuzluk / açlık modelimiz** ACE öğelerini tüketecek.
- Hendek **yol bulması** (Trench Generator parçaları) kullanıcıda doğrulanmadı; hendek alanları işaretle çalışır, rampa gerekir.
- Sayısal eşiklerin çoğu tasarım değeri (kodda ve logda işaretli).
- Test ortamı: kullanıcı kısa süre oynuyor (35-55 sn log); kısa testte görünür log şart (`[PLAN-ZAMAN]` benzeri zaman çizelgesi her ajanda).

## 9. Yeni sohbete başlama notu (komutlar ve sözleşmeler)

- Repo: `/home/user/arma3lambs`, dal `claude/bold-tesla-ipimq1`; push şablonu: `Co-Authored-By` + `Claude-Session` trailer.
- Sürüm: `XEH_PREP.hpp` boot dizesi (şu an `v8.236-SQF-TIRNAK`) + `tools/rpt_ozet.py` `BEKLENEN_SURUM`; `DEVIR_LOGU_v7.0.txt` sonuna girdi ekle.
- Lint: dosyaları `/tmp/ht2/addons/danger/functions`'a kopyala (+ `XEH_PREP.hpp`, `CfgVehicles.hpp`, `config.cpp`), `/tmp/hemtt_bin/hemtt check`; bilinen gürültü: "requires version", "Failed to check", `CfgVehicles.hpp` PE9 `QUOTE(PATHTOF2_SYS…)`. Ayrıca parantez dengesi (python ile yorum / dize / `//` ayıklanmış).
- SQF tuzakları (bu projede yaşandı): dize içinde `\"` YOK (`""` kullan); `if (...) exitWith` iç `then` bloğunda yalnız o bloğu bitirir; `select -1` geçersiz; `format`'ta `%%` kaçış değil.
- Türkçe yanıt, dürüstlük (neyin test edilmediği), kullanıcı kısa test yapar → loglar ilk bakışta okunur olmalı.
- **Askıdaki:** İHA / FPV / dron (Crocus, Mavic 3, RHS İHA; `FPV_AI_Drones` modu incelendi, hibrit hazır; sınıf adları için sunucu RPT'sindeki `[IHA-ENVANTER]` bekleniyor).
- **Bekleyen eski işler:** FRAGO küçük düzeltmeleri, HQ güvenlik elemanı rol seçimi, "hangi grup hangi hedefe izinli" kısıtı, mühendis / engel (yol haritası 7), oda temizleme (8), AI sürücü kök nedeni.

---

## 10. EK GEREKSINIMLER (kullanicinin 2. mesaji — 20x20 km, ~1500 asker, sanal / fiziksel)

Kullanici: sistem OPSIYONEL; harita 20x20 km, ~1500 asker civari; **her sey her an fiziksel olarak canli olmak ZORUNDA DEGIL**; Zeus'la ugrasmadan **faction listesinden + / - ile asker sayisi** ve **Personnel Replacement ayarlarinin HEPSI** bir panelden; **cephe gerisi SANAL**, cepheye yaklastikca (ve OPERASYONDA / TEMASTA kesinlikle) **fiziksel spawn**; catisma hattinda fiziksel birimler; gida / su tuketimi gercek.

### 10.1 Sanal / fiziksel (LOD) model — "PROFIL" cekirdegi
Bu is Dilim A'dan ONCE kayit modeline girmeli: her asker / squad bir **profil** (veri kaydi); fiziksel nesne profilin "cismi"dir.
- **Seviyeler:** L0 = SANAL (yalniz veri: konum, hedef, saglik, mermi, susuzluk / acllik, rol, kimlik; hareket soyut: yol grafi uzerinde hiz ile ilerler; tuketim FOB stokundan soyut dusulur; catisma soyut cozumlenir) → L1 = FIZIKSEL (spawn; gruplar, tam ELITE katmani) → L0'a geri donus (despawn) kurali.
- **Spawn tetikleri (hepsi CBA'dan ayarli):** oyuncu yakinligi (varsayilan 1500 m), **operasyon alani** (plan hedefi, OPORD bolgesi, FOB / COP yaricapi), **temas / ates / topcu darbesi** (kesin), cephe hatti seridi (yaklasildikca sikligi artar), gozlem / tespit (IHA vb. sonraki).
- **Despawn:** tetik yok + minimum bekleme + histerezis (yaptiklari tekrar tekrar acilip kapanmasin); durum KORUNUR (saglik, mermi, ACE tibbi, susuzluk, konum, rol).
- **Ust sinir:** `maksFizikiBirim` (CBA, varsayilan ornegin 300): tavan asilirsa uzak profiller sanal kalir / en uzak despawn. Kullanici "sistemim kaldirir" dedi; yine de TAVAN sart (20x20 km, 1500 asker).
- **Zeus'la elle konan birimler** sanal OLMAZ (elle konan fiziksel kalir; "sanallastir" ayri opsiyonel modul).
- **Kayit / saklama:** sanal profiller sunucu hafizasinda (oturum); kalici kayit (kaydet / yukle) SONRAKI dilim (Bakhmut-lite).
- **Riskler:** kimlik / yerellik (sunucu / HC), loadout / yaralanma tasima (ACE), grup kimligi, plan gruplarinin gecici sabitlenmesi ("planda olan grup despawn OLMAZ"), formasyon / ELITE durumlarinin sifirlanmasi (yeniden baslat), performans (profil basina maliyet sifira yakin olmali).

### 10.2 Faction paneli (Zeus'suz asker sayisi) + Personnel Replacement
- **Panel:** faction listesi; her satirda **+ / -** (ya da sayi) ile **baslangic asker sayisi** (taraf / faction / birim turu bazinda).
- **Personnel Replacement ayarlari (HEPSI):** baslangic toplam / rezerv havuzu, takviye hizi (saat basi), kayiptan takviyeye gecikme, takviye varis noktasi (HQ / FOB), takviye kalitesi (beceri), minimum squad boyu, ayni anda en cok spawn, cepheye yakinlik carpani (sik / seyrek), kayip esikleri (havuz biterse ne olur: bitkin / cekilme).
- **UI:** mevcut Zeus diyalog yardimcisi (`EFUNC(main,showDialog)`) LIST / SLIDER / BOOLEAN alanlari destekliyor (panel basina ~7 alan). **v1: faction basina sliderli sayfalar; gercek + / - butonlu liste = OZEL GUI (RscDisplay), SONRAKI dilim.** CBA ayarlari ayni degerlerin yedegi (sunucu baslangic).
- **Taraf / faction ayrimi:** faction listesi CfgFactionClasses'tan (RHS, GM...) otomatik doldurulur; kullanici hangilerinin sayisini ayarlar.

### 10.3 Lojistik: fiziksel tuketim ve sanal tuketim
- **Fiziksel profil (L1):** ACE Field Rations ogeleri gercekten tuketilir (matara / sise / MRE), FOB'da yenilenir.
- **Sanal profil (L0):** tuketim FOB / HQ stokundan SOYUT dusulur (6 L / kisi / gun, MRE 1 / gun — `doktrinler.md`); stok biterse sanal birim moral / etkinlik kaybeder, ikmal kamyonu (sanal kamyon da olabilir) gonderilir. Ikmal kamyonu cepheye yaklastikca fiziksel olur.
- Kullaniciya SORULACAK: sanal tuketimin soyut olmasi kabul mu? (Onerim: evet.)

### 10.4 Guncellenmis dilim plani
| Dilim | Icerik |
|---|---|
| **A0** | **Profil cekirdegi** (sanal / fiziksel gecis, spawn tetikleri, tavan, durum tasima) + faction paneli (v1 sliderli) + Personnel Replacement ayarlari + CBA |
| **A** | Kayit + FOB / COP + susuzluk / acllik modeli (hem L0 hem L1) |
| B-F | Onceki plan (Arazi, Lojistik ikmal, OPORD / istihbarat, Muhendis, Rapor); hepsi profil katmanini kullanir |
Gerekce: sanallastirma ve asker sayisi paneli kayit modelini degistirdigi icin A'dan once; aksi halde A yeniden yazilir.

### 10.5 Ek acik sorular
1. Faction listesi: hangi factionlar (RHS US / RU, GM, baska)? Taraf basina toplam asker (orn. 750 / 750?)
2. `maksFizikiBirim` hedefi (ornek 250-300?) ve spawn yaricapi (oyuncu 1500 m?) kabul mu?
3. Sanal birimler de hendek / mevzi / FOB'a "yerlesmis" sayilsin mi (cephe gerisinde garnizonlar sanal)?
4. Takviye gercekten KAMYONLA mi gelsin (sanal yol grafi + kamyon fiziksel olunca) yoksa HQ / FOB'da dogsun mu? (Onerim: FOB'da dogsun, sonra ikmal kamyonu ile cepheye.)
5. Panel: v1 sliderli yeterli mi, gercek + / - GUI sart mi?

### 10.6 KARARLAR (kullanicinin yaniti, 2026-10-14) — kilitli
1. **Factionlar otomatik taninir** (CfgFactionClasses; RHS / GM / vb.); asker sayisi panelden ayarlanir. Varsayilan taraf toplami panelde bos (0) baslar: kullanici girer.
2. **Catisma OYUNCU YOKKEN de fiziksel gerceklesir:** spawn tetikleri oyuncuya bagli DEGIL — operasyon alani, temas, ates / topcu darbesi, cephe seridi. **Cephe gerisinde oyuncu yakinligi spawn'i ARTIRIR** ("orta sekeri ben ayarlayacagim"): varsayilanlar (CBA'dan degisir, TASARIM DEGERI):
   - temas / operasyon / catisma hatti: HER ZAMAN fiziksel (tavan icinde ise; tavan asilirsa once uzak / temassiz sanallasir, temasli birim ASLA sanallasmaz);
   - cephe seridi (tanimli FOB / COP'tan ileri hatta dogru ~3000 m derinlik): fiziksel sikligi ARTAR (oyuncu olmasa da), seyrek tazeleme;
   - cephe gerisi: sanal; **oyuncu 1500 m'ye girerse** fiziksel;
   - `maksFizikiBirim` = 300 (varsayilan), temasli birimler tavandan once korunur.
3. (Anlasilmayan soru yeniden ifade edildi, asagiya bak: **FOB / COP'taki sanal garnizonlar** "orada duruyor" sayilir; yaklasildiginda ya da temasta hendek / mevzilerine fiziksel yerlesir. Onerim: EVET.)
4. **Takviye FOB'da DOGMAZ — ARACLA gider.** Yolda: (a) **suya dusme / arac glitch'i / havaya ucma olmasin**; (b) **dusman atesine maruz kalabilsin, zaiyat dogal olsun.** Tasarim: takviye konvoyu uzak yol boyunca **SANAL** ilerler (yol grafi, fizik YOK -> glitch yok); yolun bir bolumu bilinen dusmana / temasa / topcu hedefine **<= 600 m** ya da oyuncu yakinindaysa konvoy **FIZIKSEL** olur (mevcut su kacinma, ezme korumasi, kinematik surus yedegi devrede) ve gercek atese maruz kalir; SANAL iken de yol boyunca "pusu / topcu / hava" soyut zaiyat zari (yalniz bilinen dusman faaliyeti olan yol kesimlerinde; log `[KONVOY-SANAL]`). Zaiyat sayisi havuzdan dusulur.
5. **"Slider" = DAW'daki FADER gibi**: kaydirilan cubuk (soldan saga surukle), yaninda gosterilen SAYI ile deger secilir. Arma 3 Zeus diyalog yardimcisinda hazir gelir (asker sayisi icin 10'ar adim). Gercek "+ / -" butonlu liste ayri ozel GUI (sonraki dilim; v1'de fader yeterli).
