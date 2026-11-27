import json, os
R = "/home/claude/jelajah-kampung-godot/data"

def quiz_chain(npc_who, qs, final_fx, wrong_reply, chain=True):
    """Counter-based chained quiz variants. qs: [(question, right, [wrong, wrong])]."""
    n = len(qs); out = []
    for k, (q, right, wrong) in enumerate(qs):
        opts = [right] + wrong; rot = (k * 2 + 1) % 3; opts = opts[rot:] + opts[:rot]
        ch = []
        for o in opts:
            if o == right:
                c = {"label": o, "counter_add": 1, "sfx": "pick"}
                if k == n - 1:
                    c.update(final_fx)
                else:
                    c.update({"toast": "Bagus! %d dari %d" % (k + 1, n)})
                    if chain:
                        c["continue"] = True
            else:
                c = {"label": o, "reply": [{"who": npc_who, "text": wrong_reply}]}
            ch.append(c)
        out.append({"if": {"counter_gte": k, "counter_lt": k + 1}, "lines": [{"who": npc_who, "text": q}], "choices": ch})
    return out

def base(qid, title, requires, start, objective, notes, steps, goal=None):
    q = {"quest_id": qid, "type": "side", "title": title, "requires": requires, "start_target": start,
         "content_status": "draft_pending_review", "review_notes": notes,
         "learning_objective": objective, "target_age": "5-12", "reviewer": None, "version": 1, "steps": steps}
    if goal: q["goal"] = goal
    return q

def offer(who, lines, accept_label, toast, reply, later):
    return {"lines": [{"who": who, "text": t} for t in lines],
            "choices": [{"label": accept_label, "set_state": 1, "toast": toast, "reply": [{"who": who, "text": reply}]},
                        {"label": "Nanti dulu.", "reply": [{"who": who, "text": later}]}]}

NOTE = "Konten adaptasi anak, belum ada dalil. WAJIB diverifikasi reviewer sebelum publish."

# ---------- q08 Membantu Ibu ----------
q8 = base("q.help_mother", "Membantu Ibu", {"q.help_neighbor": 3}, "ibu", "Berbakti kepada orang tua: membantu dan menjawab panggilan dengan sopan", NOTE, [
    {"text": "Temui Ibu di rumah", "done_if": {"state_gte": 1}, "target": "ibu"},
    {"text": "Rapikan mainan di kamar ({n}/{goal})", "done_if": {"counter_gte": 3}, "target": "mainan"},
    {"text": "Lapor ke Ibu", "done_if": {"state_gte": 2}, "target": "ibu"}], goal=3)
q8["spawn_items"] = [{"id": "mainan", "key": "mainan_%d" % i, "x": x, "z": z, "name": "Mainan", "prompt": "Rapikan mainan", "model": "toy", "color": c}
                     for i, (x, z, c) in enumerate([(96.6, 2.2, "F6B73C"), (103.6, 1.9, "7B61FF"), (99.6, -2.5, "22A061")])]
q8["npcs"] = {"ibu": {
    "0": offer("Ibu", ["Ahmad, kamarmu berantakan. Mainannya tersebar di lantai.", "Bisa bantu Ibu merapikan tiga mainan itu?"],
               "Iya, Bu. Ahmad rapikan.", "Misi sampingan: Membantu Ibu", "Terima kasih, Nak. Mainannya ada di lantai kamar.", "Baik, tapi jangan lama-lama, ya."),
    "1": [{"if": {"counter_lt": 3}, "lines": [{"who": "Ibu", "text": "Masih ada mainan di lantai, Ahmad. Sudah {n} yang dirapikan."}]},
          {"if": {"counter_gte": 3}, "lines": [{"who": "Ahmad", "text": "Bu, mainannya sudah rapi semua."},
                                                {"who": "Ibu", "text": "Masya Allah, terima kasih. Ibu mau tanya: kalau Ibu memanggil saat Ahmad sedang bermain, Ahmad menjawab apa?"}],
           "choices": [
               {"label": "Diam saja, pura-pura tidak dengar", "reply": [{"who": "Ibu", "text": "Kalau diam, Ibu jadi sedih. Coba pikirkan jawaban yang lebih baik, lalu bicara lagi dengan Ibu."}]},
               {"label": "\"Iya, Bu. Ahmad segera ke sana.\"", "set_state": 2, "add_sticker": 1, "sfx": "done",
                "learn": "adab.orang_tua", "learn_title": "Berbakti kepada Orang Tua",
                "learn_text": "Ahmad membantu Ibu merapikan kamar dan menjawab panggilan Ibu dengan sopan. Membantu dan berkata lembut kepada orang tua termasuk berbakti.",
                "reply": [{"who": "Ibu", "text": "Jawaban yang sopan. Ibu senang punya anak seperti Ahmad."}]},
               {"label": "\"Nanti saja, Bu!\"", "reply": [{"who": "Ibu", "text": "Hmm, jawaban itu kurang sopan. Coba pikirkan lagi, lalu bicara lagi dengan Ibu."}]}]}],
    "2": {"lines": [{"who": "Ibu", "text": "Kamarnya jadi nyaman. Terima kasih, Ahmad."}]}}}
q8["items"] = {"mainan": {"1": {"if": {"counter_lt": 3}, "counter_add": 1, "hide_self": True, "sfx": "pick", "toast": "Mainan dirapikan {n}/{goal}"}}}

# ---------- q09 Adab di Masjid ----------
masjid_qs = [
    ("Saat masuk masjid, kaki mana yang didahulukan?", "Kaki kanan", ["Kaki kiri", "Melompat dengan dua kaki"]),
    ("Di dalam masjid, sebaiknya Ahmad...", "Berjalan pelan dan tenang", ["Berlari main kejar-kejaran", "Berteriak memanggil teman"]),
    ("Ada orang yang sedang shalat. Ahmad...", "Tidak lewat di depannya", ["Lewat di depannya karena terburu-buru", "Mengajaknya mengobrol"]),
    ("Saat shalat berjamaah, shaf sebaiknya...", "Lurus dan rapat", ["Renggang dan berjauhan", "Bebas di mana saja"]),
    ("Sebelum ke masjid, pakaian Ahmad sebaiknya...", "Bersih dan rapi", ["Kotor bekas main lumpur", "Asal pakai saja"])]
q9 = base("q.adab_masjid", "Adab di Masjid", {"q.rukun_islam": 2}, "imam", "Adab di masjid", NOTE, [
    {"text": "Temui Pak Imam Yusuf", "done_if": {"state_gte": 1}, "target": "imam"},
    {"text": "Jawab pertanyaan adab masjid ({n}/{goal})", "done_if": {"state_gte": 2}, "target": "imam"}], goal=5)
q9["npcs"] = {"imam": {
    "0": offer("Pak Imam Yusuf", ["Ahmad, kamu sering ke masjid sekarang. Pak Imam senang.", "Mau belajar adab di masjid lewat beberapa pertanyaan?"],
               "Mau, Pak Imam!", "Misi sampingan: Adab di Masjid", "Bagus. Bicara lagi dengan Pak Imam untuk mulai.", "Baik, kapan-kapan saja."),
    "1": quiz_chain("Pak Imam Yusuf", masjid_qs,
                    {"set_state": 2, "add_sticker": 1, "sfx": "done", "learn": "adab.masjid", "learn_title": "Adab di Masjid",
                     "learn_text": "Masuk dengan kaki kanan, berjalan tenang, tidak lewat di depan orang shalat, merapatkan shaf, dan berpakaian bersih saat ke masjid.",
                     "reply": [{"who": "Pak Imam Yusuf", "text": "Masya Allah, semuanya benar. Jaga adab ini setiap ke masjid, ya."}]},
                    "Hampir. Coba pikirkan lagi, lalu bicara lagi dengan Pak Imam."),
    "2": {"lines": [{"who": "Pak Imam Yusuf", "text": "Sampai jumpa di shalat berjamaah, Ahmad."}]}}}

# ---------- q10 Kampung Bersih ----------
q10 = base("q.clean_village", "Kampung Bersih", {"q.help_neighbor": 3}, "pak_rt", "Menjaga kebersihan lingkungan", NOTE, [
    {"text": "Temui Pak RT Salim", "done_if": {"state_gte": 1}, "target": "pak_rt"},
    {"text": "Pungut sampah di kampung ({n}/{goal})", "done_if": {"counter_gte": 5}, "target": "sampah"},
    {"text": "Buang ke tempat sampah", "done_if": {"state_gte": 2}, "target": "tempat_sampah"},
    {"text": "Lapor ke Pak RT Salim", "done_if": {"state_gte": 3}, "target": "pak_rt"}], goal=5)
q10["spawn_items"] = [{"id": "sampah", "key": "sampah_%d" % i, "x": x, "z": z, "name": "Sampah", "prompt": "Pungut sampah", "model": "trash"}
                      for i, (x, z) in enumerate([(3.6, 0.4), (-12.6, 4.6), (12.2, 4.9), (-2.5, 11.4), (7.2, -2.4)])]
q10["npcs"] = {"pak_rt": {
    "0": offer("Pak RT Salim", ["Assalamu'alaikum, Ahmad. Ada sampah tercecer di beberapa tempat di kampung.", "Mau bantu Bapak memungutnya? Kampung yang bersih membuat semua warga nyaman."],
               "Siap, Pak RT!", "Misi sampingan: Kampung Bersih", "Terima kasih. Kumpulkan lima sampah, lalu buang ke tempat sampah di sebelah Bapak.", "Baik, Ahmad."),
    "1": {"lines": [{"who": "Pak RT Salim", "text": "Sudah {n} sampah terkumpul. Ikuti panah kuning, ya."}]},
    "2": {"lines": [{"who": "Ahmad", "text": "Pak RT, sampahnya sudah Ahmad buang ke tempat sampah."},
                    {"who": "Pak RT Salim", "text": "Alhamdulillah, kampung kita jadi bersih. Terima kasih, Ahmad."}],
          "set_state": 3, "add_sticker": 1, "sfx": "done", "learn": "adab.kebersihan", "learn_title": "Menjaga Kebersihan",
          "learn_text": "Ahmad memungut sampah dan membuangnya ke tempatnya. Menjaga kebersihan lingkungan membuat kampung nyaman untuk semua."},
    "3": {"lines": [{"who": "Pak RT Salim", "text": "Kampung bersih, warga senang."}]}}}
q10["items"] = {
    "sampah": {"1": {"if": {"counter_lt": 5}, "counter_add": 1, "hide_self": True, "sfx": "pick", "toast": "Sampah {n}/{goal}"}},
    "tempat_sampah": {"1": {"if": {"counter_gte": 5}, "set_state": 2, "sfx": "pick", "toast": "Sampah sudah dibuang ke tempatnya"}}}

# ---------- q11 Kembalian yang Lebih ----------
q11 = base("q.honest_change", "Kembalian yang Lebih", {"q.adab_makan": 3}, "aminah", "Jujur dalam jual beli", NOTE, [
    {"text": "Terima titipan belanja dari Bu Aminah", "done_if": {"state_gte": 1}, "target": "aminah"},
    {"text": "Beli tomat di pasar Bu Sari", "done_if": {"state_gte": 2}, "target": "sari"},
    {"text": "Antarkan belanjaan ke Bu Aminah", "done_if": {"state_gte": 3}, "target": "aminah"}])
q11["npcs"] = {
    "aminah": {
        "0": {"lines": [{"who": "Bu Aminah", "text": "Ahmad, Ibu kehabisan tomat. Boleh tolong belikan di pasar Bu Sari?"}],
              "choices": [{"label": "Boleh, Bu!", "set_state": 1, "give_item": "uang", "toast": "Misi sampingan: Kembalian yang Lebih",
                           "reply": [{"who": "Bu Aminah", "text": "Ini uangnya. Hati-hati, ya."}]},
                          {"label": "Nanti dulu, Bu.", "reply": [{"who": "Bu Aminah", "text": "Iya, Nak, kapan-kapan saja."}]}]},
        "1": {"lines": [{"who": "Bu Aminah", "text": "Pasar Bu Sari ada di sebelah kanan jalan, Nak."}]},
        "2": {"lines": [{"who": "Ahmad", "text": "Bu, ini tomatnya. Tadi Bu Sari kelebihan memberi kembalian, sudah Ahmad kembalikan."},
                        {"who": "Bu Aminah", "text": "Masya Allah, kamu jujur sekali, Ahmad. Terima kasih."}],
              "set_state": 3, "remove_item": "belanjaan", "add_sticker": 1, "sfx": "done", "learn": "adab.jujur_jualbeli",
              "learn_title": "Jujur dalam Jual Beli",
              "learn_text": "Saat kembalian yang diterima lebih dari seharusnya, Ahmad mengembalikan kelebihannya. Jujur dalam jual beli menjaga kepercayaan dan hak orang lain."},
        "3": {"lines": [{"who": "Bu Aminah", "text": "Tomatnya sudah Ibu masak. Terima kasih, Ahmad."}]}},
    "sari": {
        "1": {"lines": [{"who": "Ahmad", "text": "Bu Sari, Ahmad mau beli tomat untuk Bu Aminah."},
                        {"who": "Bu Sari", "text": "Ini tomatnya, dan ini kembaliannya."},
                        {"who": "Ahmad", "text": "Hmm, kembaliannya sepertinya lebih banyak dari seharusnya..."}],
              "choices": [
                  {"label": "\"Bu, kembaliannya kelebihan. Ini Ahmad kembalikan.\"", "set_state": 2, "remove_item": "uang", "give_item": "belanjaan", "sfx": "pick",
                   "reply": [{"who": "Bu Sari", "text": "Masya Allah, Ibu salah hitung. Terima kasih sudah jujur, Ahmad."}]},
                  {"label": "Diam saja, lumayan buat jajan", "reply": [{"who": "Ahmad", "text": "Eh, uang lebih itu bukan hakku. Sebaiknya kubicarakan dengan Bu Sari."}]}]}}}

# ---------- q12 Bola Zaid ----------
q12 = base("q.zaid_ball", "Bola Zaid", {"q.harvest_tomato": 2}, "kid_zaid", "Menolong teman", NOTE, [
    {"text": "Dengarkan cerita Zaid", "done_if": {"state_gte": 1}, "target": "kid_zaid"},
    {"text": "Ambil bola di dekat kolam", "done_if": {"state_gte": 2}, "target": "bola_zaid"},
    {"text": "Kembalikan bola ke Zaid", "done_if": {"state_gte": 3}, "target": "kid_zaid"}])
q12["spawn_items"] = [{"id": "bola_zaid", "key": "bola_zaid_0", "x": 12.8, "z": -11.6, "name": "Bola", "prompt": "Ambil bola", "model": "ball", "hide_until_available": True}]
q12["npcs"] = {"kid_zaid": {
    "0": offer("Zaid", ["Ahmad! Bola cadanganku tertendang jauh sampai dekat kolam.", "Bisa bantu ambilkan? Aku takut ke dekat kolam sendirian."],
               "Ayo, aku bantu!", "Misi sampingan: Bola Zaid", "Terima kasih! Bolanya di dekat kolam, sebelah kanan masjid.", "Oke, nanti saja."),
    "1": {"lines": [{"who": "Zaid", "text": "Bolanya di dekat kolam, Ahmad."}]},
    "2": {"lines": [{"who": "Ahmad", "text": "Zaid, ini bolamu."},
                    {"who": "Zaid", "text": "Alhamdulillah, terima kasih, Ahmad! Ayo kita main bareng, gantian menendang."}],
          "set_state": 3, "remove_item": "bola", "add_sticker": 1, "sfx": "done", "learn": "adab.teman",
          "learn_title": "Menolong dan Berbagi dengan Teman",
          "learn_text": "Ahmad menolong Zaid mengambil bolanya, lalu mereka bermain bersama secara bergantian. Teman yang baik saling menolong dan berbagi."},
    "3": {"lines": [{"who": "Zaid", "text": "Main bola lagi, yuk!"}]}}}
q12["items"] = {"bola_zaid": {"1": {"give_item": "bola", "set_state": 2, "hide_self": True, "sfx": "pick", "toast": "Bola Zaid didapat"}}}

for name, q in [("08_help_mother", q8), ("09_adab_masjid", q9), ("10_clean_village", q10), ("11_honest_change", q11), ("12_zaid_ball", q12)]:
    json.dump(q, open(f"{R}/quests/{name}.json", "w"), ensure_ascii=False, indent=2)

# NPCs, places, items
p = f"{R}/world/npcs.json"; d = json.load(open(p))
ids = {n["id"] for n in d["npcs"]}
if "ibu" not in ids:
    d["npcs"].append({"id": "ibu", "name": "Ibu", "prompt": "Bicara dengan Ibu", "x": 101.4, "z": 0.9,
                      "look": {"robe": "1e7a4f", "dress": True, "hijab": "0f5132"},
                      "idle": [{"who": "Ibu", "text": "Ahmad, jangan lupa membantu warga, ya."}]})
if "pak_rt" not in ids:
    d["npcs"].append({"id": "pak_rt", "name": "Pak RT Salim", "prompt": "Bicara dengan Pak RT", "x": -4.2, "z": 8.6,
                      "look": {"robe": "8a9a5b", "pants": "4b5a6a", "peci": "2b2418"},
                      "idle": [{"who": "Pak RT Salim", "text": "Assalamu'alaikum, Ahmad. Semoga kampung kita selalu rukun."}]})
json.dump(d, open(p, "w"), ensure_ascii=False, indent=2)
p = f"{R}/world/places.json"; d = json.load(open(p))
if not any(s["id"] == "tempat_sampah" for s in d["spots"]):
    d["spots"].append({"id": "tempat_sampah", "prompt": "Buang sampah", "x": -2.8, "z": 7.6, "model": "bin"})
json.dump(d, open(p, "w"), ensure_ascii=False, indent=2)
p = f"{R}/world/items.json"; d = json.load(open(p))
d["items"].update({"uang": {"name": "Uang belanja", "color": "22A061", "short": "Uang"},
                   "belanjaan": {"name": "Tomat belanjaan", "color": "e2463a", "short": "Tomat"},
                   "bola": {"name": "Bola Zaid", "color": "ffffff", "short": "Bola"}})
json.dump(d, open(p, "w"), ensure_ascii=False, indent=2)
print("generated")
