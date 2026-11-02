# Test report

Latest results: **516 scenarios in 51 groups: 516 passed, 0 failed, 0 skipped.** The last full run covered 504 scenarios; the Claude Code chat group and the AI, language, settings and dashboard groups were run again afterwards. The interface was in English during the run; Russian is covered by the i18n group and checked on screenshots.

The AI chat tests use `tests/fake_ai.py` and `tests/fake_claude.py`. The Claude Code path was also checked once by hand with a real subscription, the API key path never with the real API. The translation scenarios use stand-in scripts for slurp, grim, tesseract and trans. Some scenarios have passed and failed intermittently in earlier runs, so one clean run does not rule them out.

Environment: VirtualBox, CachyOS, niri 26.04, Quickshell 0.3.2. Scenario names are still in Uzbek.

## Workspace raqamlari (10/10)

- ✅ Boshida raqamlar 1 dan ketma-ket boradi
- ✅ Mod+2 ikkinchi workspace'ga o'tkazadi
- ✅ 2 raqamini bosish o'tkazadi
- ✅ 1 raqamini bosish qaytaradi
- ✅ Oyna ko'chirilsa yangi raqam paydo bo'ladi
- ✅ Oxirgi oyna yopilsa ortiqcha raqam yo'qoladi
- ✅ 9 ta workspace'da ham panel ishlaydi
- ✅ Mod+J va Mod+K raqam bo'ylab yuradi
- ✅ Diqqat so'ragan oyna shell'ni buzmaydi
- ✅ Bo'sh raqamlarni yashirish sozlamasi panelni o'zgartiradi

## Oyna ochilish qoidalari (10/10)

- ✅ Oddiy terminal lentada ochiladi
- ✅ Ovoz sozlamasi (pavucontrol) suzib ochiladi
- ✅ 'Open File' dialogi suzib ochiladi
- ✅ 'Save As' dialogi suzib ochiladi
- ✅ Ruscha 'Открыть файл' suzib ochiladi
- ✅ Picture-in-Picture suzib ochiladi va sticky bo'ladi
- ✅ 'Open Source Notes' oddiy oyna bo'lib qoladi
- ✅ Sarlavhada 'save' bo'lsa ham oddiy oyna qoladi
- ✅ Steam xabari fokusni olmaydi
- ✅ Scratchpad va Sozlamalar suzib ochiladi

## Ustunlar va lenta (10/10)

- ✅ Mod+H va Mod+L ustunlar orasida yuradi
- ✅ Chetdagi ustunda Mod+L hech narsani buzmaydi
- ✅ Mod+R kenglikni almashtiradi
- ✅ Mod+Ctrl+L ustun o'rnini almashtiradi
- ✅ Mod+M ustunni kengaytiradi
- ✅ Mod+Shift+F to'liq ekran qiladi va qaytaradi
- ✅ Mod+[ oynani qo'shni ustunga qo'shadi
- ✅ Mod+Minus ustunni toraytiradi
- ✅ Mod+Q yopadi va fokus qo'shni oynaga o'tadi
- ✅ 15 ta oyna ochilsa ham lenta ishlaydi

## Suzuvchi oynalar (10/10)

- ✅ Mod+Shift+Space suzuvchi qiladi va qaytaradi
- ✅ Mod+Alt+Space suzuvchi va oddiy oyna orasida o'tadi
- ✅ Suzuvchi oyna ustida Mod+Q faqat uni yopadi
- ✅ Suzuvchi oyna bor joyda yangi oyna ochiladi
- ✅ Suzuvchi oyna boshqa workspace'ga ko'chadi
- ✅ Mod+Ctrl+M oynani ekran chetigacha kengaytiradi
- ✅ Mod+Shift+= oyna balandligini oshiradi
- ✅ Mod+Ctrl+C ko'rinib turgan ustunlarni markazlaydi
- ✅ Mod+Ctrl+F bo'sh joyni to'ldiradi
- ✅ Sichqoncha bilan Mod+sudrash oynani siljitadi

## Sticky oyna (10/10)

- ✅ Mod+S oynani suzuvchi va sticky qiladi
- ✅ Workspace almashsa oyna ergashadi
- ✅ Orqaga qaytganda ham ergashadi
- ✅ Mod+S qayta bosilsa o'chadi
- ✅ O'chirilgandan keyin ergashmaydi
- ✅ Yopilgan oyna ro'yxatdan chiqadi
- ✅ Oyna yo'q joyda Mod+S xato bermaydi
- ✅ Ikkita sticky oyna birga ergashadi
- ✅ Sticky oyna overview'dan keyin ham joyida
- ✅ Ketma-ket tez almashtirishda oyna yo'qolmaydi

## Alt+Tab (10/10)

- ✅ Alt+Tab oldingi oynaga o'tadi
- ✅ Ikki marta bosish oldingidan oldingisiga o'tadi
- ✅ Yagona oynada xato bermaydi
- ✅ Oyna yo'q joyda xato bermaydi
- ✅ Esc bekor qiladi
- ✅ Boshqa workspace'dagi oynaga ham o'tadi
- ✅ Alt+Tab ochiq turganda oynalar ko'rinadi
- ✅ Shift bilan teskari yo'nalishda yuradi
- ✅ Yopilgan oyna ro'yxatda qolmaydi
- ✅ Alt+Tab'dan keyin klaviatura shu oynaga ishlaydi

## Scratchpad terminal (10/10)

- ✅ Mod+` ochadi, suzib turadi va fokus oladi
- ✅ Fokusda turganda qayta bosish yopadi
- ✅ Yopilganda sessiya tirik qoladi
- ✅ Qayta ochilganda oldingi matn turadi
- ✅ Fokusda bo'lmasa bosish fokusni qaytaradi
- ✅ Mod+Q bilan yopilsa ham sessiya tirik
- ✅ Boshqa workspace'da ham o'sha sessiya ochiladi
- ✅ Tez-tez bosilganda ikkinchi nusxa ochilmaydi
- ✅ Shell'dan exit qilinganda oyna yopiladi va keyingisi yangi
- ✅ Klavishi o'zgartirilsa yangi klavish ishlaydi

## Dastur oynasiga tez o'tish (10/10)

- ✅ Dastur yopiq bo'lsa ochadi
- ✅ Ochiq bo'lsa yangisini ochmaydi, unga o'tadi
- ✅ Boshqa workspace'dagi oynaga o'tkazadi
- ✅ Harf katta-kichikligi farq qilmaydi
- ✅ Noto'g'ri regex xato qaytaradi va oyna ochmaydi
- ✅ Dastur o'rnatilmagan bo'lsa shell buzilmaydi
- ✅ Bir nechta nusxadan oxirgi ishlatilganiga o'tadi
- ✅ Mod+E fayl menejerini ochadi
- ✅ Mod+E ikkinchi marta yangisini ochmaydi
- ✅ Burp o'rnatilmagan bo'lsa Mod+Shift+B xato bermaydi

## Qidiruv oynasi (10/10)

- ✅ Mod+Space ochadi, Esc yopadi
- ✅ Mod+Space qayta bosilsa yopiladi
- ✅ Nomi bilan dastur topiladi va birinchi turadi
- ✅ Enter dasturni ochadi va oyna yopiladi
- ✅ Topilmaydigan so'z bo'sh ro'yxat beradi, Enter hech narsa qilmaydi
- ✅ Pastga va tepaga tugmalari tanlovni siljitadi, chetdan chiqmaydi
- ✅ Oyna tashqarisiga bosish yopadi
- ✅ Qatorni sichqoncha bilan bosish ochadi
- ✅ Ochiq oyna nomi bilan unga o'tadi
- ✅ Aniq moslik bo'lsa taxminiy dastur chiqmaydi

## Qidiruvda hisoblash (10/10)

- ✅ 2+2*3 amal tartibini to'g'ri hisoblaydi
- ✅ =2^10 ishlaydi
- ✅ Qavslar ishlaydi
- ✅ Kasr sonlar ishlaydi
- ✅ Nolga bo'lish xato bermaydi
- ✅ Tugallanmagan ifoda shell'ni buzmaydi
- ✅ Enter natijani nusxalaydi
- ✅ IP manzil hisob deb qabul qilinmaydi
- ✅ Kod yuborilsa bajarilmaydi
- ✅ Juda katta son xato bermaydi

## Qidiruvda kodlash (10/10)

- ✅ b64 kodlaydi
- ✅ b64d ochadi
- ✅ url kodlaydi
- ✅ urld ochadi
- ✅ hex kodlaydi
- ✅ hexd ochadi
- ✅ md5 hisoblaydi
- ✅ Noto'g'ri base64 xato haqida aytadi
- ✅ Enter natijani nusxalaydi
- ✅ Noto'g'ri urld shell'ni buzmaydi

## Qidiruvda buyruq va internet (10/10)

- ✅ >buyruq terminal ochib ishga tushiradi
- ✅ Quvur va belgilar buzilmaydi
- ✅ Qo'shtirnoqli buyruq ishlaydi
- ✅ Xato buyruqda terminal ochiq qoladi
- ✅ Enter bosilganda terminal yopiladi
- ✅ Bo'sh > hech narsa ishga tushirmaydi
- ✅ Bo'sh joyli > ham xavfsiz
- ✅ ?qidiruv qatorini ko'rsatadi
- ✅ Bo'sh ? hech narsa ochmaydi
- ✅ Faqat buyruq qatori chiqadi, boshqalar aralashmaydi

## Pentest nishoni va lab holati (10/10)

- ✅ target buyrug'i nishonni yozadi
- ✅ Xavfli matn nishon sifatida qabul qilinmaydi
- ✅ Domen nomi ham nishon bo'la oladi
- ✅ Port ochilsa holat yangilanadi
- ✅ Port yopilsa holat qaytadi
- ✅ Bo'sh nishonda dashboard buzilmaydi
- ✅ VPN interfeysi paydo bo'lsa manzili ko'rinadi
- ✅ Dashboard'da nishonni bosish nusxalaydi
- ✅ Skript noto'g'ri portni e'tiborsiz qoldiradi
- ✅ Portlar ro'yxati bo'sh bo'lsa ham ishlaydi

## Clipboard tarixi (10/10)

- ✅ Nusxalangan matn tarixda ko'rinadi
- ✅ Mod+V faqat clipboard'ni ko'rsatadi
- ✅ Yozish tarixni filtrlaydi
- ✅ Enter tanlangan matnni qaytaradi
- ✅ Xavfli belgili matn buyruq bo'lib ishlamaydi
- ✅ Ko'p qatorli matn to'liq qaytadi
- ✅ Kirill va o'zbek harflari buzilmaydi
- ✅ Mod+V ikkinchi bosish yopadi
- ✅ Tarix bo'sh bo'lsa xato bermaydi
- ✅ Juda uzun matn oynani buzmaydi

## Fon rasmi va ranglar (10/10)

- ✅ Mod+W ochadi, Esc yopadi
- ✅ Hozirgi fon tanlangan holda ochiladi
- ✅ O'ng va chap tugmalar chetdan chiqmaydi
- ✅ Enter fonni almashtiradi
- ✅ Fon almashganda rang ham o'zgaradi
- ✅ Kartani bosish fonni almashtiradi
- ✅ Yo'q fayl xato qaytaradi, joriy fon qoladi
- ✅ Nomida bo'sh joy bor rasm ishlaydi
- ✅ Rasm bo'lmagan fayl joriy holatni buzmaydi
- ✅ Papka bo'sh bo'lsa xabar chiqadi

## Dashboard (10/10)

- ✅ Mod+D ochadi va klaviaturani oladi
- ✅ Esc yopadi va fokus oynaga qaytadi
- ✅ Soatni bosish ochadi
- ✅ Tashqariga bosish yopadi
- ✅ Ichiga bosish yopmaydi
- ✅ Dashboard ochiq turganda boshqa panel ochilsa almashadi
- ✅ Xabar dashboard yopilguncha kutadi
- ✅ CPU halqasini bosish monitor ochadi
- ✅ Ob-havo o'chirilsa ko'rinmaydi, qolgani ishlaydi
- ✅ Tez ochib-yopishda holat chalkashmaydi

## Boshqaruv paneli (10/10)

- ✅ Holat tugmasini bosish ochadi
- ✅ Mod+C ochadi, Esc yopadi
- ✅ Tashqariga bosish yopadi
- ✅ Kofe tugmasi ishlaydi va xabar chiqaradi
- ✅ Tungi rejim wlsunset'ni boshqaradi
- ✅ 'Bezovta qilmang' xabarlarni to'xtatadi
- ✅ VPN buyrug'i yo'q bo'lsa qalqon tugmasi ishlamaydi
- ✅ VPN buyrug'i berilsa qalqon ishga tushiradi
- ✅ Chiqish tugmasi birinchi bosishda bajarilmaydi
- ✅ Ochiq panelda Mod+Q oynani yopmaydi, panel saqlanadi

## Ovoz (10/10)

- ✅ Ovoz tugmasi oshiradi
- ✅ Ovoz tugmasi kamaytiradi
- ✅ 100% dan oshmaydi
- ✅ 0% dan pastga tushmaydi
- ✅ O'chirish tugmasi ishlaydi va qaytaradi
- ✅ Orolda to'g'ri foiz ko'rinadi
- ✅ Ketma-ket bosishda xabar navbatga to'planmaydi
- ✅ Slider ovozni o'zgartiradi
- ✅ Sliderni sudrash oxirigacha yetadi
- ✅ Qurilma almashganda shell buzilmaydi

## Xabarlar (10/10)

- ✅ Xabar orolda chiqadi
- ✅ Vaqti o'tgach yo'qoladi
- ✅ Bir nechta xabar navbat bilan chiqadi
- ✅ Tarixga yoziladi
- ✅ O'qilmaganlar soni panel ochilganda nolga tushadi
- ✅ HTML teglar tozalanadi
- ✅ Juda uzun matn oroldan chiqib ketmaydi
- ✅ Muhim xabar o'zi yo'qolmaydi, bosilganda yopiladi
- ✅ Tarix chegarasi ishlaydi
- ✅ Xabar vaqtini sozlash ishlaydi

## Tray (12/12)

- ✅ Dastur tray'ga qo'shilsa hisoblanadi
- ✅ Dastur yopilsa ikonka yo'qoladi
- ✅ Dastur qayta ochilsa qaytib keladi
- ✅ Ikonka panelda ko'rinadi
- ✅ Sozlamada o'chirilsa panelda ko'rinmaydi
- ✅ O'ng tugma menyu ochadi
- ✅ Menyu Esc bilan yopiladi
- ✅ Menyu ishlatilgandan keyin dastur yopilsa shell yiqilmaydi
- ✅ Menyu ochiq turganda dastur yopilsa menyu yopiladi, shell yiqilmaydi
- ✅ Chap tugma shell'ni buzmaydi
- ✅ O'rta tugma shell'ni buzmaydi
- ✅ Shell qayta ishga tushsa tray tiklanadi

## Fokus rejimi (10/10)

- ✅ Mod+F yoqadi va zen faylini yozadi
- ✅ Mod+F qayta bosilsa o'chadi
- ✅ Panel yashiriladi
- ✅ Oynalar ekran balandligini to'ldiradi
- ✅ Qaytganda eski o'lcham tiklanadi
- ✅ Zen'da qidiruv ishlaydi
- ✅ Zen'da Mod+D ochilishi shell'ni buzmaydi
- ✅ Oyna yo'q joyda ham ishlaydi
- ✅ Tez-tez bosilganda niri config'i buzilmaydi
- ✅ Zen o'chirilgach sozlangan oraliq qaytadi

## Skrinshot va tahrirlash (10/10)

- ✅ Mod+Shift+S va Enter fayl saqlaydi
- ✅ O'zbekcha xabar chiqadi, inglizchasi yo'q
- ✅ Clipboard'ga ham tushadi
- ✅ Esc bekor qiladi
- ✅ Xabarni bosish tahrirlovchini ochadi
- ✅ Tahrirlovchi yopilsa fayl joyida qoladi
- ✅ Xabar bosilmasa tahrirlovchi ochilmaydi
- ✅ Print tugmasi ishlaydi
- ✅ Ctrl+Print butun ekranni oladi
- ✅ Papka o'chirilgan bo'lsa ham shell buzilmaydi

## Ekranni yozish (10/10)

- ✅ Soha tanlansa yozish boshlanadi
- ✅ Qayta bosish to'xtatadi va video saqlaydi
- ✅ Video haqiqatan o'qiladi
- ✅ Esc bilan bekor qilinsa yozish boshlanmaydi
- ✅ Yozish paytida orolda qizil vaqt ko'rinadi
- ✅ Yozish paytida qidiruv ishlaydi
- ✅ Shell qayta ishga tushsa yozish davom etadi va to'xtatsa bo'ladi
- ✅ wf-recorder o'zi to'xtasa keyingi bosish yangisini boshlaydi
- ✅ Videos papkasi yo'q bo'lsa yaratiladi
- ✅ Ikki yozuv ketma-ket ishlaydi

## Ekrandan matn va rang olish (10/10)

- ✅ Mod+P matnni nusxalaydi
- ✅ Natija xabari chiqadi
- ✅ Esc bekor qiladi, clipboard o'zgarmaydi
- ✅ Bo'sh sohada 'Matn topilmadi' deydi
- ✅ Kirill matn ham o'qiladi
- ✅ Kichik soha ham shell'ni buzmaydi
- ✅ Rang olish hex nusxalaydi
- ✅ Rang olishda xabar chiqadi
- ✅ Rang olishni Esc bekor qiladi
- ✅ OCR ketma-ket ikki marta ishlaydi

## Bloklash va kofe rejimi (10/10)

- ✅ Mod+X bloklaydi
- ✅ logind holati ham 'locked' bo'ladi
- ✅ Noto'g'ri parol ochmaydi
- ✅ Bo'sh Enter ochmaydi
- ✅ Bloklanganda Mod+Space ishlamaydi
- ✅ Bloklanganda ovoz tugmasi ishlaydi
- ✅ Qayta Mod+X ikkinchi nusxa ochmaydi
- ✅ Shell o'ldirilsa ham ekran bloklangan qoladi
- ✅ Bo'sh turganda avtomatik bloklanadi
- ✅ Kofe rejimida avtomatik bloklanmaydi

## Sozlamalar: ko'rinish (10/10)

- ✅ Yorug' rejim ranglarni o'zgartiradi
- ✅ Rang uslubi o'zgarishi ranglarga ta'sir qiladi
- ✅ O'z rangini berish ishlaydi
- ✅ Noto'g'ri rang rad etiladi, eski rang qoladi
- ✅ Noto'g'ri rang uslubi rad etiladi
- ✅ Matn o'lchami o'zgaradi
- ✅ Panel shaffofligi o'zgaradi
- ✅ Terminal shaffofligi kitty fayliga yoziladi
- ✅ Mavjud bo'lmagan shrift shell'ni buzmaydi
- ✅ Chegaradan tashqari matn o'lchami panelni qulatmaydi

## Sozlamalar: oynalar (10/10)

- ✅ Oraliq o'zgartirilsa oyna o'lchami o'zgaradi
- ✅ Oraliq 0 ham ishlaydi
- ✅ Manfiy oraliq rad etiladi va eski config qoladi
- ✅ Matn berilsa rad etiladi
- ✅ Burchak yumaloqligi config'ga yoziladi
- ✅ Animatsiya o'chiriladi
- ✅ Xira fon o'chiriladi
- ✅ Faol bo'lmagan oyna shaffofligi qo'shiladi
- ✅ Yangi oyna kengligi sozlamasi ishlaydi
- ✅ Yagona oynani markazlash o'chiriladi

## Sozlamalar: oyna qoidalari (10/10)

- ✅ Qoida bilan dastur suzib ochiladi
- ✅ Sarlavha bo'yicha qoida ishlaydi
- ✅ Boshqa dasturga ta'sir qilmaydi
- ✅ Kenglik qoidasi ishlaydi
- ✅ Fokus olmaslik qoidasi ishlaydi
- ✅ Noto'g'ri regex rad etiladi
- ✅ Bo'sh qoida e'tiborsiz qoldiriladi
- ✅ Maxsus belgili regex KDL'ni buzmaydi
- ✅ Qoida o'chirilsa dastur oddiy ochiladi
- ✅ Yozuvdan yashirish qoidasi config'ga tushadi

## Sozlamalar: panel (10/10)

- ✅ Panel pastga ko'chadi
- ✅ Pastda turganda oynalar panel ostiga kirmaydi
- ✅ Pastda dashboard ochiladi
- ✅ Pastda raqam bosiladi
- ✅ Noto'g'ri joylashuv panelni yo'qotmaydi
- ✅ Raqamlarni yashirish ishlaydi
- ✅ Til, Wi-Fi, ovoz, batareya alohida yashiriladi
- ✅ Hammasi yashirilsa ham boshqaruv paneli ochiladi
- ✅ Soniya va sana ko'rsatiladi
- ✅ Bo'sh ish stoli soati o'chiriladi

## Sozlamalar: klavishlar va klaviatura (10/10)

- ✅ Klavishni o'zgartirish ishlaydi
- ✅ Eski klavish endi ishlamaydi
- ✅ Klavishni bo'sh qoldirish uni o'chiradi
- ✅ Bir klavish ikki amalga berilsa rad etiladi
- ✅ Band tizim klavishi rad etiladi
- ✅ Mavjud bo'lmagan tugma nomi rad etiladi
- ✅ Xavfli matn klavish sifatida qabul qilinmaydi
- ✅ Yangi til qo'shiladi
- ✅ Noto'g'ri til config'ni buzmaydi
- ✅ Har oyna o'z tilini eslaydi

## Sozlamalar oynasi (10/10)

- ✅ Mod+, ochadi va suzib turadi
- ✅ Qayta bosilsa yopiladi
- ✅ Mod+Q bilan yopilsa holat to'g'ri qoladi
- ✅ Ikkinchi nusxa ochilmaydi
- ✅ Qidiruv oynasidan ham ochiladi
- ✅ Tugma bosilganda settings.json o'zgaradi
- ✅ Bo'limlar orasida o'tish oynani buzmaydi
- ✅ Qidiruv maydoni sozlamani topadi
- ✅ Fayl qo'lda buzilsa eski sozlama qoladi va xabar chiqadi
- ✅ Standartga qaytarish oynasi ikki bosish talab qiladi

## Sozlamalar oynasi boshqaruvlari (10/10)

- ✅ Sliderni bosish qiymatni o'zgartiradi
- ✅ Sliderni oxirigacha sudrash chegaradan oshmaydi
- ✅ Tanlov tugmasi qiymatni o'zgartiradi
- ✅ Matn maydoni Enter bilan saqlanadi
- ✅ Noto'g'ri rang kiritilsa xato xabari chiqadi
- ✅ Klavishni maydondan o'zgartirish ishlaydi
- ✅ Yangi qoida tugmasi qoida qo'shadi
- ✅ Qoidadagi Suzuvchi tugmasi ishlaydi va yangi oynaga ta'sir qiladi
- ✅ Qidiruv natijasidagi tugma ishlaydi
- ✅ Oyna qayta ochilganda qiymat saqlanib qoladi

## Barqarorlik (10/10)

- ✅ Bo'sh turganda shell protsessorni band qilmaydi
- ✅ Qayta yuklanganda bitta nusxa ishlaydi
- ✅ Shell o'ldirilsa nazoratchi o'zi qaytaradi
- ✅ niri config xatosi shell'ga xabar qiladi
- ✅ Oyna yopilishida shell xato yozmaydi
- ✅ Xotira tez o'smaydi
- ✅ Monitor o'chib yonsa panel qoladi
- ✅ Masshtab o'zgarsa panel ishlaydi
- ✅ Monitor qayta ulansa panel qaytadi
- ✅ Uzoq ishlashdan keyin ham jurnalda xato ko'p emas

## Dashboard: 4 ta vkladka (10/10)

- ✅ 1-vkladka (Today) ochiladi
- ✅ 2-vkladka (Status) ochiladi
- ✅ 3-vkladka (Lab) ochiladi
- ✅ 4-vkladka (AI) ochiladi
- ✅ Soatni bosish birinchi vkladkani ochadi
- ✅ Vkladka nomini bosish uni tanlaydi
- ✅ Raqam tugmalari vkladkani almashtiradi
- ✅ Tab keyingisiga o'tadi va aylanadi
- ✅ Esc har vkladkada yopadi
- ✅ Oxirgi tanlangan vkladka qayta ochilganda eslab qolinadi

## AI chat (11/11)

- ✅ Xabar yuboriladi va javob oqib keladi
- ✅ Darhol yozilgan xabar tarix yuklanishida yo'qolmaydi
- ✅ Ikkinchi savolda tarix ham yuboriladi, thinking bloki buzilmaydi
- ✅ Standart model va sozlamalar to'g'ri yuboriladi
- ✅ Sozlamadagi model ishlatiladi
- ✅ Noto'g'ri kalit tushunarli xato beradi, tarix iflos bo'lmaydi
- ✅ Rad etilgan javob tarixga yozilmaydi
- ✅ To'xtatish javobni kesadi va busy qoldirmaydi
- ✅ Javob kutilganda ikkinchi xabar yuborilmaydi
- ✅ Kalit fayli faqat egasiga ochiq va settings.json ga tushmaydi
- ✅ Tozalash suhbatni va faylni o'chiradi

## Lab vkladkasi: nishon va qaydlar (10/10)

- ✅ Qayd yozilsa nishon papkasiga saqlanadi
- ✅ Qayd fayli faqat egasiga ochiq
- ✅ Esc bosilsa oxirgi yozuv ham saqlanadi
- ✅ Qayta ochilganda qayd joyida turadi
- ✅ Nishon almashganda qaydlar aralashmaydi
- ✅ Yo'ldan chiqadigan nishon qaydni yozdirmaydi
- ✅ Nishonsiz qayd maydoni faqat o'qish uchun
- ✅ Nishonni kiritish maydonidan o'zgartirish mumkin
- ✅ Nusxa tugmasi nishonni clipboard'ga qo'yadi
- ✅ Barcha terminal uchun nishon fayli yangilanadi

## Pomodoro (10/10)

- ✅ Boshlash ish bosqichini va to'g'ri vaqtni qo'yadi
- ✅ Sozlamadagi daqiqa ishlatiladi
- ✅ Vaqt kamayib boradi
- ✅ To'xtatilganda vaqt turadi
- ✅ Davom etish vaqtni yana yuradi
- ✅ Ish tugasa dam olishga o'tadi va xabar beradi
- ✅ Dam olish tugasa ishga qaytadi
- ✅ Bekor qilish hammasini tozalaydi
- ✅ Panel yopilsa ham taymer davom etadi
- ✅ Noto'g'ri qiymatda standart vaqt olinadi

## Ish profillari (10/10)

- ✅ Dasturlar o'z workspace'ida ochiladi
- ✅ Oxirida birinchi workspace'ga qaytadi
- ✅ Ochiq dastur qayta ochilmaydi
- ✅ O'rnatilmagan dastur xato chiqarmaydi va xabarda aytiladi
- ✅ Noma'lum profil xato qaytaradi
- ✅ Noto'g'ri fayl dasturni yiqitmaydi
- ✅ Launcher @ bilan profillarni ko'rsatadi
- ✅ Launcher'dan ochish ishlaydi
- ✅ VPN yoqilgan profil VPN buyrug'ini bajaradi
- ✅ Fayl o'zgarsa ro'yxat qayta o'qiladi

## Sessiyani tiklash (10/10)

- ✅ Saqlash ochiq oynalarni workspace bilan yozadi
- ✅ Xizmat oynalari saqlanmaydi
- ✅ Tiklash dasturni ochadi
- ✅ Argumentlar qayta bajarilmaydi
- ✅ Ochiq oyna bo'lsa tiklash hech narsa qilmaydi
- ✅ Sozlama o'chiq bo'lsa kirishda tiklanmaydi
- ✅ Buzuq fayl xato bermaydi
- ✅ O'rnatilmagan dastur o'tkazib yuboriladi
- ✅ Yo'l ko'rinishidagi buyruq bajarilmaydi
- ✅ Workspace to'g'ri tiklanadi

## Launcher: fayl qidiruvi (10/10)

- ✅ /parol-royxat qidiruvi
- ✅ /PAROL-ROYXAT qidiruvi
- ✅ /hisobot 2026 qidiruvi
- ✅ /yoq-bunday-fayl qidiruvi
- ✅ Bitta harfda qidiruv boshlanmaydi
- ✅ Yashirin fayllar chiqmaydi
- ✅ Maxsus belgilar buyruq sifatida bajarilmaydi
- ✅ -- bilan boshlangan so'z fd bayrog'iga aylanmaydi
- ✅ Natijalar 9 tadan oshmaydi
- ✅ Enter faylni ochadi

## Snippetlar (10/10)

- ✅ ; hammasini ko'rsatadi
- ✅ Nom bo'yicha filtrlaydi
- ✅ {target} joriy nishon bilan to'ldiriladi
- ✅ {lport} sozlamadan olinadi
- ✅ {lhost} VPN yo'q bo'lsa sozlamadan olinadi
- ✅ Oddiy snippet Enter bilan nusxalanadi
- ✅ run snippet terminalda ishlaydi
- ✅ Nishon bo'sh bo'lsa run snippet bajarilmaydi, nusxalanadi
- ✅ Xavfli nishon buyruqqa kirmaydi
- ✅ Buzuq fayl eski ro'yxatni saqlab xabar beradi

## Skrinshot va video nishon papkasiga (10/10)

- ✅ Yoqilganda papka yaratiladi
- ✅ Skrinshot nishon papkasiga tushadi
- ✅ Fayl nomida sana va vaqt bor
- ✅ O'chiq bo'lsa odatiy papka ishlatiladi
- ✅ Nishon almashsa yo'l ham almashadi
- ✅ Nishonsiz yig'ilmaydi
- ✅ Xavfli nishon ishlatilmaydi
- ✅ IPv6 nishon papka nomida ishlaydi
- ✅ Boshqa papka tanlash mumkin
- ✅ Video yozuvi ham shu papkaga yo'naltiriladi

## HTB/THM: /etc/hosts (10/10)

- ✅ Nom qo'shiladi
- ✅ Takror qo'shilmaydi
- ✅ IP qo'lda berilishi mumkin
- ✅ Noto'g'ri nom rad etiladi (a b)
- ✅ Noto'g'ri nom rad etiladi (x;touch /tmp/nd-h)
- ✅ Noto'g'ri nom rad etiladi (-rf)
- ✅ Noto'g'ri nom rad etiladi ($(id))
- ✅ Noto'g'ri IP rad etiladi
- ✅ Nishon bo'sh bo'lsa rad etiladi
- ✅ Launcher hosts buyrug'ini ko'rsatadi

## Yangi kodlashlar (10/10)

- ✅ sha256 abc
- ✅ html <b>
- ✅ htmld &lt;b&gt;
- ✅ jwt eyJhbGciOiJIUzI1NiJ9.eyJ
- ✅ hashid 5f4dcc3b5aa765d61d832
- ✅ hashid da39a3ee5e6b4b0d3255b
- ✅ hashid $2y$10$abcdefghij
- ✅ hashid $6$salt$hash
- ✅ Buzuq JWT ochilmaydi, xato bermaydi
- ✅ Natija Enter bilan nusxalanadi

## Noto'g'ri klaviatura tuzatish (10/10)

- ✅ лшеен -> kitty
- ✅ ащще -> foot
- ✅ ащ -> foot
- ✅ Lotin yozuvi oldingidek ishlaydi
- ✅ To'g'ri moslik birinchi turadi
- ✅ Enter tuzatilgan natijani ochadi
- ✅ Bo'sh qidiruv buzilmaydi
- ✅ Raqam va belgilar o'zgarmaydi
- ✅ Topilmagan so'z bo'sh ro'yxat beradi
- ✅ Aralash yozuv yiqitmaydi

## Ekrandan tarjima (11/11)

- ✅ Natija oynada ochiladi
- ✅ Oyna suzib turadi
- ✅ Natija clipboard'ga tushadi
- ✅ Tanlov bekor qilinsa hech narsa bo'lmaydi
- ✅ Matn bo'lmasa xabar beradi
- ✅ Internet bo'lmasa asl matn nusxalanadi
- ✅ Til sozlamadan olinadi
- ✅ Standart til o'zbekcha
- ✅ OCR xato qilsa jim to'xtamaydi, xabar beradi
- ✅ Klavish sozlangan
- ✅ Launcher'da bor

## Monitor profillari (10/10)

- ✅ Masshtab qo'llanadi
- ✅ Aylantirish qo'llanadi
- ✅ Joy qo'llanadi
- ✅ Faqat X berilsa Y nol olinadi
- ✅ Sozlama olib tashlansa asliga qaytadi
- ✅ Ulanmagan monitor uchun qoida xato bermaydi
- ✅ off yoqilsa kdl'ga yoziladi
- ✅ Chegaradan tashqari masshtab rad etiladi va eski saqlanadi
- ✅ Noto'g'ri aylantirish rad etiladi
- ✅ Sozlamalarda Monitorlar sahifasi bor

## Kechki rejim jadvali (10/10)

- ✅ Yorug' vaqtda yorug' rejim yoqiladi
- ✅ Qorong'i vaqtda qorong'i rejim yoqiladi
- ✅ O'chiq bo'lsa o'zgartirmaydi
- ✅ Noto'g'ri vaqt standartga tushadi va yiqitmaydi
- ✅ Rang rejimga qarab o'zgaradi
- ✅ Tungi jadval wlsunset vaqtlari bilan ishlaydi
- ✅ Tungi jadval o'chsa qo'lda rejim eski holatda
- ✅ Tungi harorat jadvalda ham qo'llanadi
- ✅ Yarim tunni kesib o'tgan jadval
- ✅ Sozlamalarda vaqt maydonlari bor

## Sozlamalarni zaxiralash (10/10)

- ✅ Eksport fayl yaratadi
- ✅ Yo'l berilmasa uy papkasiga yozadi
- ✅ API kaliti zaxiraga kirmaydi
- ✅ Sozlama va profillar bor
- ✅ Import sozlamani qaytaradi
- ✅ Import niri'ga qo'llanadi
- ✅ Tashqi yo'lli arxiv rad etiladi
- ✅ Boshqa konfig faylini almashtira olmaydi
- ✅ Buzuq fayl sozlamani buzmaydi
- ✅ Yo'q fayl xato qaytaradi

## Interfeys tili (10/10)

- ✅ Inglizcha tanlansa matn inglizcha
- ✅ Ruscha tanlansa matn ruscha
- ✅ Launcher bo'limlari tilga ergashadi
- ✅ Skript xabari tilga ergashadi
- ✅ Klavish sarlavhalari tilga ergashadi
- ✅ Bloklash ekrani matni tilga ergashadi
- ✅ Sozlama xatosi tilga ergashadi
- ✅ AI xatosi tilga ergashadi
- ✅ Kodda ishlatilgan har bir matnning ruscha tarjimasi bor
- ✅ Kataloglarda o'zbekcha matn qolmagan

## AI chat: Claude Code obunasi (12/12)

- ✅ Javob oqib keladi va tarixga yoziladi
- ✅ Asboblar, MCP va sozlama fayllari o'chiq
- ✅ Ikkinchi xabar o'sha suhbatni davom ettiradi
- ✅ API kaliti obuna so'roviga o'tkazilmaydi
- ✅ Kirilmagan bo'lsa tushunarli xato
- ✅ Obuna limiti aytiladi, tarix iflos bo'lmaydi
- ✅ Rad etilgan javob tarixga yozilmaydi
- ✅ Yo'qolgan suhbat o'rniga yangisi boshlanadi
- ✅ To'xtatish claude jarayonini ham o'ldiradi
- ✅ Tozalash suhbat identifikatorini ham o'chiradi
- ✅ claude topilmasa tushunarli xato
- ✅ Auto rejim claude bo'lsa obunani tanlaydi
