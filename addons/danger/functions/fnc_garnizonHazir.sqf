#include "script_component.hpp"
/*
 * Author: Cinar (ELITE fork)
 * GARNIZON HAZIR AYAR (v8.400; kullanici: 'ayni isi yapan modulleri sadelestir'): 'ELITE Karakol / Mevzi' modulu (Zeus + 3DEN) tek basina karakol + garnizon kurabilsin diye
 * hazir ayar paketleri. Garnizon modulunun paneli (fnc_garnizonPanel) ayni alanlari tek tek sorar; burasi yaygin kombinasyonlari tek secimle verir.
 *   1 Hafif    : 2 nobetci, 1 devriye x 2, ust kat acik, arac mevzisi kapali
 *   2 Standart : 4 nobetci, 2 devriye x 3, ust kat + arac mevzisi acik
 *   3 Guclu    : 6 nobetci, 3 devriye x 3, ust kat + arac mevzisi + anti-air konumlandirma + IHA 'alarmda gozlem'
 *   0 Yok      : bos dizi (garnizon istegi gonderilmez)
 *
 * Arguments:
 * 0: Hazir ayar indeksi (0 yok, 1 hafif, 2 standart, 3 guclu) <NUMBER>
 *
 * Return Value: [nobet, devriye, devriye boyu, ust kat, arac, anti-air, IHA modu] ya da [] <ARRAY>
 * Public: No
*/

params [["_i", 0, [0]]];

switch (round _i) do {
    case 1: { [2, 1, 2, true, false, 1, 0] };
    case 2: { [4, 2, 3, true, true, 1, 0] };
    case 3: { [6, 3, 3, true, true, 1, 2] };
    default { [] };
};
