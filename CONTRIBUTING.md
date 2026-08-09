# Contributing

[🇮🇩 Bahasa Indonesia](#bahasa-indonesia) · [🇬🇧 English](#english)

## Bahasa Indonesia

Issue dan PR boleh bahasa Indonesia maupun Inggris. Peserta diharapkan
mengikuti [Code of Conduct](CODE_OF_CONDUCT.md). Kalau temuanmu adalah lubang
keamanan — bukan bug biasa — ikuti [SECURITY.md](SECURITY.md), jangan buka issue
publik.

### Kontribusi yang paling berguna

1. **Task baru** — task yang mengukur sesuatu yang belum diukur task 01 dan 02.
2. **Bug di harness** — terutama bug yang bisa membuat `grade` mencetak angka yang salah tapi terlihat benar. Itu kelas bug paling parah di repo ini.
3. **Perbaikan dokumentasi** — kalau ada langkah di README yang tidak jalan di mesin kamu, itu bug.

### Yang tidak dicari

- **PR yang menambah baris ke `RESULTS.md`.** Tabel itu adalah catatan pengukuran di mesin maintainer, bukan leaderboard komunitas. Hasil kamu ada di fork kamu.
- Refactor kosmetik pada `bin/evalcode`. Komentar panjang di file itu adalah catatan desain — tiap paragraf mencatat satu kegagalan nyata. Jangan dihapus.

### Sebelum kirim PR

```bash
bash test/evalcode_test.sh            # wajib hijau
shellcheck --severity=warning bin/evalcode test/evalcode_test.sh
```

Kalau kamu mengubah perilaku `bin/evalcode`, **tambahkan test-nya di `test/evalcode_test.sh`.** Test-nya men-stub `mix` dan `elixir`, jadi tidak butuh Elixir terpasang dan jalan dalam hitungan detik.

Kalau kamu mengubah gate penilaian, jelaskan di deskripsi PR **angka salah seperti apa** yang bisa lolos tanpa perubahan itu.

### Mengirim task baru

Ikuti struktur dan aturan di [bagian "Menambah task sendiri" di README](README.md#menambah-task-sendiri). PR task baru harus menyertakan `NOTES.md` yang mencatat:

- Bahwa held-out test-nya **gagal** di workspace yang belum disentuh (ini yang membuktikan task-nya nyata)
- Bahwa test-nya **lolos** setelah kamu selesaikan sendiri
- Bahwa `min_tests` cocok dengan jumlah test yang benar-benar berjalan
- Apa yang held-out test-nya sengaja **tidak** tangkap

Task tanpa catatan validasi ini tidak bisa dipercaya, dan tidak akan di-merge.

### Gaya commit

Judul commit menjelaskan **perubahan perilakunya**, bukan file yang disentuh. Contoh dari riwayat repo ini: `Stop the skeleton fixture lying to the model it is measuring`.

---

## English

Issues and pull requests are welcome in Indonesian or English. Participants are
expected to follow the [Code of Conduct](CODE_OF_CONDUCT.md). If what you found
is a security hole rather than an ordinary bug, follow
[SECURITY.md](SECURITY.md) instead of opening a public issue.

### Most useful contributions

1. **New tasks** — ones that measure something tasks 01 and 02 don't.
2. **Harness bugs** — especially any bug that lets `grade` print a wrong number that looks right. That's the worst bug class in this repo.
3. **Documentation fixes** — if a step in the README doesn't work on your machine, that's a bug.

### Not looking for

- **PRs that add rows to `RESULTS.md`.** That table is a record of measurements taken on the maintainer's machine, not a community leaderboard. Your results belong in your fork.
- Cosmetic refactors of `bin/evalcode`. The long comments in that file are the design record — each paragraph documents a real observed failure. Don't delete them.

### Before opening a PR

```bash
bash test/evalcode_test.sh            # must be green
shellcheck --severity=warning bin/evalcode test/evalcode_test.sh
```

If you change `bin/evalcode`'s behavior, **add a test in `test/evalcode_test.sh`.** The suite stubs `mix` and `elixir`, so it needs no Elixir install and runs in seconds.

If you change a grading gate, say in the PR description **what wrong number** could get through without your change.

### Submitting a new task

Follow the structure and rules in [the README's "Adding your own task" section](README.md#adding-your-own-task). A new-task PR must include a `NOTES.md` recording:

- That the held-out tests **fail** on an untouched workspace (this is what proves the task is real)
- That they **pass** once you solve it yourself
- That `min_tests` matches what actually runs
- What the held-out tests deliberately **don't** catch

A task without that validation record can't be trusted and won't be merged.

### Commit style

Commit subjects describe the **behavior change**, not the files touched. From this repo's history: `Stop the skeleton fixture lying to the model it is measuring`.
