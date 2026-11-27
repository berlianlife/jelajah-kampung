# Jelajah-Kampung — Godot 4 (Phase 1)

Petualangan Kebaikan. Vertical slice: karakter faceless, kamera three-quarter (Perspective 60°), gerak 8 arah, collision, kampung + kebun berpagar, rumah Ahmad bisa dimasuki, minimap + penanda tujuan, 5 NPC, quest engine data-driven: **Membantu Tetangga** (utama), **Panen Tomat**, **Belajar Wudhu**, **Dompet yang Tercecer**, **Mengenal Rukun Islam** (sampingan), masjid bisa dimasuki, siklus waktu pagi-siang-sore-malam, anak-anak bermain bola, Jurnal (J), hotbar inventaris, kartu pelajaran, menu Pengaturan, SFX prosedural tanpa musik.

**Target MVP awal: localhost.** VPS/domain belum dipakai.

## Status
- Diuji dengan Godot 4.3 headless: **smoke test lulus semua** (movement, collision, pagar & pintu kebun, 2 quest penuh, kartu pelajaran, fade bangunan, pengaturan, audio bus, save/load).
- Web build siap pakai ada di `export/web/` (Thread Support OFF).
- Belum diuji visual di layar asli dan di HP.
- Konten Islam di `data/` berstatus `draft_pending_review`. Jangan publish sebelum reviewer menyetujui.

## Jalankan (desktop, paling cepat)
1. Pasang Godot 4.3 atau lebih baru (standard, bukan .NET).
2. Godot → Import → pilih `project.godot`.
3. Tekan F5.

Kontrol: WASD/panah jalan, E/Spasi bicara/ambil, J jurnal, Esc pengaturan. HP: joystick + tombol Aksi (UI otomatis menyesuaikan portrait/landscape). Uji touch di desktop: jalankan dengan `-- --touch`. Di layar sentuh muncul joystick dan tombol Aksi.

## Jalankan di browser (localhost) — paling cepat
Build sudah ada: `python3 tools/serve_web.py` → buka http://localhost:8060

## Export ulang Web build
1. Editor → Manage Export Templates → Download (sekali saja).
2. Project → Export → Add… → **Web**.
   - **Thread Support: OFF** (supaya tidak butuh header COOP/COEP).
   - Export Path: `export/web/index.html`.
3. Export Project.
4. `python3 tools/serve_web.py` → buka http://localhost:8060

Alternatif: tombol "Run in Browser" (ikon HTML5) di kanan atas editor.

## Struktur
```
project.godot
scenes/main.tscn                 # root, script main.gd
scripts/main.gd                  # bootstrap + quest runner (data-driven)
scripts/data/game_data.gd        # autoload: input map, state
scripts/data/save_repository.gd  # interface repository
scripts/data/local_save_repository.gd  # user://save.json (IndexedDB di Web)
scripts/player/player.gd         # CharacterBody3D, 8 arah
scripts/camera/camera_rig.gd     # pitch/distance/fov/ortho configurable
scripts/characters/character_mesh.gd   # model faceless + animasi tubuh
scripts/world/world_builder.gd   # blockout kampung
scripts/world/interactable.gd    # NPC & objek
scripts/ui/hud.gd                # quest, prompt, dialog, toast, touch
scripts/ui/virtual_joystick.gd
data/quests/*.json               # quest: langkah, dialog, kondisi, efek (draf, perlu review)
data/world/npcs.json             # spawn NPC + dialog idle
data/world/places.json           # pintu (portal), prop kamar, spot quest
data/world/items.json            # nama/warna item untuk hotbar
# quest: prioritas NPC = quest berjalan > belum dimulai > selesai > default
scripts/ui/minimap.gd            # minimap bulat + titik tujuan
scripts/quest/quest_engine.gd    # runner quest data-driven
scripts/audio/audio_manager.gd   # autoload: bus Voice/Ambience/SFX, SFX sintetis
tools/serve_web.py               # server localhost untuk Web export
tests/smoke_test.gd              # godot --headless --path . -s res://tests/smoke_test.gd
export_presets.cfg               # preset Web (Thread Support OFF)
```

Alur data: `Gameplay → GameData → SaveRepository → LocalSaveRepository`. Nanti tambah repository server tanpa mengubah gameplay.

## Known issues / next
- Belum ada voice-over NPC (bus Voice sudah siap) dan minimap. Jurnal (J) dan hotbar inventaris sudah ada.
- Konten Belajar Wudhu (urutan langkah) WAJIB diverifikasi reviewer beserta dalilnya sebelum publish.
- Menambah quest: buat `data/quests/03_xxx.json`, daftarkan di `QUEST_FILES` (main.gd) dan `include_filter` export.
