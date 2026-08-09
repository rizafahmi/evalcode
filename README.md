# evalcode

Harness kecil untuk mengukur model coding di codebase kamu sendiri — Elixir 1.20 / Phoenix 1.8 LiveView, dinilai dengan test yang tidak pernah dilihat model.

[![CI](../../actions/workflows/ci.yml/badge.svg)](../../actions/workflows/ci.yml)

**🇮🇩 Bahasa Indonesia** · [🇬🇧 English](#evalcode-english)

---

## Kenapa repo ini ada

Ini **contoh lengkap sebuah eval mandiri**, dipublikasikan untuk dibongkar dan dicontek. Harness-nya satu file bash ~550 baris — cukup pendek untuk dibaca habis dalam satu duduk — dan hampir tiap komentar di dalamnya mencatat satu bug nyata yang pernah menghasilkan angka salah tapi terlihat meyakinkan. Kalau cuma sempat baca satu bagian, baca [Yang layak dicontek](#yang-layak-dicontek).

Kenapa orang perlu punya eval sendiri: leaderboard publik mengukur model di soal yang bukan soal kamu. evalcode mengukur satu hal — **apakah model X, di harness Y, bisa menyelesaikan pekerjaan nyata di stack kamu.** Hasilnya satu baris tabel yang bisa kamu pertahankan kalau ditanya orang.

---

## Hasil

Empat putaran, diukur 3–4 Agustus 2026 — sebelum repo ini publik, saat held-out test masih rahasia.

| run | task | model | harness | completed | tests | duration | cost | compile | notes |
|---|---|---|---|---|---|---|---|---|---|
| 2026-08-03-opus5-01 | 01-live-orders | opus5 | claude-code | yes | 35/32 | 5m | $2.83 | clean |  |
| 2026-08-03-opus5-02 | 02-type-clean | opus5 | claude-code | yes | 52/41 | 2m | $0.88 | clean |  |
| 2026-08-04-mixed-01 | 01-live-orders | mixed | ampcode | yes | 33/32 | 2m | $0.99 | clean |  |
| 2026-08-04-gpt-56-02 | 02-type-clean | gpt-56 | ampcode | yes | 51/41 | 3m | $1.03 | clean |  |

Keempatnya lolos, jadi `notes` kosong; kolom itu baru terisi saat ada yang gagal. Kolom `tests` yang paling informatif: `35/32` artinya model menyelesaikan task lalu menulis 3 test sendiri, `33/32` artinya pas di batas.

Empat baris jelas bukan sampel untuk menyimpulkan model mana lebih baik — dan memang bukan itu gunanya. Tabel ini contoh **bentuk**: apa yang layak dicatat per putaran, dan mana kolom yang boleh dipercaya. Lihat [cara membacanya](#membaca-resultsmd) dan [`RESULTS.md`](RESULTS.md).

### Task 01 dan 02 adalah contoh, bukan alat ukur aktif

Keduanya tervalidasi dan benar-benar jalan — clone repo ini, dan kamu bisa menyelesaikan satu putaran penuh. Tapi keduanya **sudah tidak bisa dipakai mengukur**, dan alasannya justru pelajarannya sendiri.

Pertama, `tasks/*/holdout/` ikut publik. Test rahasianya bisa diindeks dan masuk data training model berikutnya.

Kedua — dan ini yang lebih penting — solusi task 02 tidak perlu dicari sampai ke `holdout/`. Ia ada di skeleton:

```bash
diff skeleton/lib/warung_web/order_params.ex \
     tasks/02-type-clean/overlay/lib/warung_web/order_params.ex
```

`skeleton/` adalah titik awal setiap run, jadi tidak mungkin dibuang. **Permukaan bocor selalu lebih luas dari direktori yang kamu tandai rahasia** — history git, artefak build, dan `NOTES.md` juga termasuk.

Kalau kamu butuh angka yang bebas kontaminasi: **fork repo ini, hapus `tasks/`, tulis task dari codebase kamu sendiri, dan simpan repo-nya privat.** Yang dipublikasikan di sini metodenya, bukan soal ujiannya.

---

## Cara kerjanya

Satu putaran = satu model, satu task, satu agent harness.

```
                  bin/evalcode start
skeleton/  ────────────────────────────────►  runs/<id>/     ← agent kerja di sini
+ tasks/<id>/overlay                          + TASK.md          (repo git sendiri)
                                              + .git

                  bin/evalcode grade
runs/<id>/  ───────────────────────────────►  1 baris di RESULTS.md
+ tasks/<id>/holdout   (baru disalin di sini)  + runs/<id>.{test,compile,diff}.log
```

Poin pentingnya: **held-out test baru masuk ke workspace saat grading.** Selama agent bekerja, test itu tidak ada di disk mana pun yang bisa dia jangkau.

---

## Setup

Butuh [Nix](https://nixos.org/download) (opsional: [direnv](https://direnv.net)).

```bash
git clone <url-repo-ini>
cd evalcode
direnv allow      # atau: nix develop
```

Devshell-nya mengunci **Elixir 1.20.x + Erlang/OTP 27**. `start` dan `grade` menolak jalan di luar itu — bukan rewel: seluruh task 02 dinilai berdasarkan kelas warning yang cuma ada di type checker Elixir 1.20. Di Elixir 1.18 kode start state-nya compile bersih dan akan tercatat sebagai "selesai" padahal model belum mengerjakan apa pun.

---

## Menjalankan satu putaran

### 1. Mulai

```bash
bin/evalcode start 01-live-orders opus5 claude-code
#                  <task>         <model> <harness>
```

Perintah ini mencetak path workspace, misalnya `runs/2026-08-09-opus5-01/`.

### 2. Kerjakan

Buka coding agent kamu **di workspace itu**, bukan di repo ini. Suruh agent baca `TASK.md`, lalu biarkan bekerja seperti biasa.

> Workspace punya `.git` sendiri, jadi `git log` dari dalam sana berhenti di batas workspace dan tidak bisa merangkak ke repo induk yang menyimpan kunci jawaban. Tapi jangan `--add-dir` ke repo ini.

Mau menjalankan model yang sama di task yang sama dua kali dalam sehari? Boleh — run kedua otomatis dapat sufiks `-2`. Variansi antar-run di model yang sama itu justru data yang berharga.

### 3. Nilai

```bash
bin/evalcode grade 2026-08-09-opus5-01 --cost 2.10
```

- `--cost` diambil dari laporan agent-nya sendiri (`/cost` di Claude Code). Formatnya harus angka desimal seperti `2.10`.
- `--duration 12m` opsional. Kalau tidak diisi, durasi dihitung wall-clock dari `start` sampai `grade` — **termasuk waktu kamu ditinggal makan siang.** Isi manual kalau agent-nya melaporkan waktu kerjanya sendiri.
- Format yang salah ditolak, bukan ditulis apa adanya ke tabel.

Satu baris ditambahkan ke `RESULTS.md`. Run yang sudah dinilai ditandai file `runs/<id>.graded`, dan menilai ulang akan ditolak kecuali kamu pakai `--regrade`.

---

## Arti `completed`

`completed=yes` cuma kalau **semua** ini benar:

| Gate | Kenapa ada |
|---|---|
| `mix test` lolos dengan held-out test disalin masuk | Ini ujian sebenarnya |
| Minimal `min_tests` test benar-benar **berjalan** | Exit code 0 tidak bilang apa-apa soal berapa test yang jalan. `ExUnit.configure(exclude: [:test])` exit 0. Menghapus file test yang merah juga exit 0. Dua-duanya pernah tercatat lolos. |
| Tidak ada atribut `@compile` / `@dialyzer` yang ditambahkan | Membungkam compiler bukan perbaikan |
| `mix compile --force --warnings-as-errors` exit 0 | Hanya untuk task yang `grading.conf`-nya menyetel `requires_clean_compile=yes` |

Kalau gagal, kolom `notes` menyebut alasannya: `suppressions added`, `only 10 of 32 tests ran`, `tests failed`, `compile failed`. Kolom ini kosong kalau lolos. Tanpa itu, tabel tidak bisa membedakan model yang **mencoba lalu gagal** dari model yang **membungkam checker**.

## Membaca `RESULTS.md`

Tidak semua kolom sama derajatnya, dan tabelnya menyatakan itu terang-terangan:

- **Diukur harness:** `completed`, `tests`, `compile`, `notes`
- **Diketik operator, tidak diverifikasi:** `cost`, `duration` (kalau `--duration` dipakai), serta label `model` dan `harness`

Kolom `tests` berformat `<jalan>/<batas>`. `35/32` artinya model menyelesaikan task lalu menulis 3 test tambahan sendiri. `?` di pembilang berarti jumlahnya tidak terbaca dari log — dan itu selalu dihitung gagal.

Kolom `run` adalah satu-satunya jembatan baris itu ke buktinya: `runs/<run>.diff.log` adalah apa yang benar-benar ditulis model.

---

## Task yang tersedia

| id | yang diukur |
|---|---|
| `01-live-orders` | Phoenix LiveView, PubSub, streams — dan apakah broadcast-nya ditaruh di layer yang benar (context, bukan LiveView) |
| `02-type-clean` | Type inference Elixir 1.20 — dan apakah perbaikannya nyata atau cuma dibungkam |

---

## Menambah task sendiri

Satu task = satu direktori di `tasks/`:

```
tasks/03-punya-kamu/
├── task.md          # yang dibaca agent (disalin jadi TASK.md di workspace)
├── grading.conf     # WAJIB — tanpa ini start & grade menolak
├── holdout/         # test yang tidak pernah dilihat agent
├── overlay/         # opsional: file yang menimpa skeleton (start state yang rusak)
└── NOTES.md         # catatan validasi
```

`grading.conf` di-source oleh shell, jadi formatnya `key=value` tanpa spasi:

```sh
min_tests=32               # test skeleton + test held-out, dihitung dari log
requires_clean_compile=no  # yes = --warnings-as-errors ikut menentukan completed
```

### Aturan wajib untuk held-out test

1. **Namespace modulnya di bawah `Holdout`** — `WarungWeb.Holdout.NamaTest` — dan awali nama filenya `holdout_`.
   Kalau tidak: model yang menyelesaikan task lalu menulis test untuk modul yang baru dia ubah akan bentrok nama modul dengan held-out test, seluruh run gagal compile, dan `completed=no` untuk model yang sebenarnya mengerjakan tugas **dan** melakukan hal yang benar.

2. **Setiap modul test yang menyentuh database harus `async: false`.**
   SQLite mengunci seluruh file database. Penulis async flake sekitar 1 dari 30 run, dan itu terbaca sebagai kegagalan model.

### Validasi sebelum dipakai

Kerjakan manual, jangan diasumsikan:

1. Jalankan `start`, lalu `grade` workspace yang **belum disentuh sama sekali**. Held-out test-nya **harus gagal**. Kalau lolos, task-nya sudah selesai duluan dan tidak mengukur apa-apa.
2. Selesaikan sendiri task-nya, `grade` lagi, pastikan lolos.
3. Pastikan `min_tests` cocok dengan jumlah yang benar-benar jalan.
4. Catat semuanya di `NOTES.md` — termasuk apa yang held-out test-nya **sengaja tidak** tangkap.

---

## Test harness-nya sendiri

```bash
bash test/evalcode_test.sh      # tidak butuh Elixir — mix & elixir di-stub
shellcheck bin/evalcode         # opsional
```

Keduanya dijalankan CI di setiap push dan PR.

---

## Struktur repo

```
bin/evalcode            harness-nya, satu file bash
skeleton/               app Phoenix 1.8 yang jadi titik awal setiap run
tasks/<id>/             definisi task (lihat di atas)
runs/                   workspace + log (gitignored, boleh dihapus kapan saja)
test/evalcode_test.sh   unit test untuk harness-nya
docs/                   temuan yang membentuk desainnya
flake.nix               devshell terkunci: Elixir 1.20 / OTP 27
RESULTS.md              tabelnya
```

---

## Yang layak dicontek

Kalau kamu bikin benchmark sendiri, delapan hal ini yang paling mahal dipelajari — semuanya berasal dari bug nyata di repo ini yang menghasilkan angka salah tapi meyakinkan:

1. **Kunci toolchain-nya, dan tolak jalan di luar itu.** Elixir 1.18 membuat task 02 mencetak "selesai" untuk nol pekerjaan.
2. **Exit code 0 bukan kelulusan.** Hitung berapa test yang benar-benar berjalan, dan bandingkan dengan batas minimum.
3. **Anggap agent bisa menemukan kunci jawaban.** Workspace dijadikan repo git sendiri karena `git log` di repo induk menampilkan nama held-out test di judul commit-nya. Instruksi "jangan buka repo induk" tidak melindungi apa pun dari tooling agent.
4. **Jangan menyalin artefak hasil compile ke start state.** `_build/test/.../OrderParams.beam` bisa didekompilasi dan mengembalikan solusi referensi apa adanya.
5. **Deteksi pembungkaman, jangan cuma percaya hasil hijau.** Diff base-vs-run mencari `@compile`/`@dialyzer` yang baru ditambahkan — dan pemeriksanya sendiri harus diuji, karena versi pertamanya tidak pernah bisa menyala sama sekali (`diff` exit 1 mengalahkan `grep` di bawah `pipefail`).
6. **Pisahkan kolom yang diukur dari kolom yang diketik tangan.** `cost` dan `duration` adalah klaim operator, bukan pengukuran, dan tabelnya bilang begitu.
7. **Setiap baris gagal harus menyebut alasannya.** Tanpa kolom `notes`, "gagal" mencampur model yang mencoba dengan model yang curang.
8. **Lebih baik menolak daripada mencetak angka yang salah.** Timestamp yang tidak terbaca pernah menghasilkan durasi `29762072m` dan exit 0. Sekarang itu error.

Detail lengkap tiap keputusan ada di komentar `bin/evalcode` — komentarnya adalah catatan desain, bukan basa-basi.

---

## Kontribusi & lisensi

Lihat [CONTRIBUTING.md](CONTRIBUTING.md). Kode harness berlisensi [MIT](LICENSE); `skeleton/` adalah app Phoenix hasil generate dan mengikuti lisensi Phoenix.

<br>

---

# evalcode (English)

A small harness for measuring coding models against **your** codebase — Elixir 1.20 / Phoenix 1.8 LiveView, graded with tests the model never sees.

[🇮🇩 Bahasa Indonesia](#evalcode) · **🇬🇧 English**

---

## Why this exists

This is a **complete worked example of a self-built eval**, published to be taken apart and copied. The harness is a single ~550-line bash file — short enough to read in one sitting — and nearly every comment in it records a real bug that once produced a confidently wrong number. If you only read one section, read [What's worth stealing](#whats-worth-stealing).

Why anyone needs their own eval: public leaderboards measure models on problems that aren't yours. evalcode measures one thing — **can model X, in harness Y, finish real work in your stack.** The output is one row in a table you can defend when someone asks.

---

## Results

Four rounds, measured 3–4 August 2026 — before this repo went public, while the held-out tests were still private.

| run | task | model | harness | completed | tests | duration | cost | compile | notes |
|---|---|---|---|---|---|---|---|---|---|
| 2026-08-03-opus5-01 | 01-live-orders | opus5 | claude-code | yes | 35/32 | 5m | $2.83 | clean |  |
| 2026-08-03-opus5-02 | 02-type-clean | opus5 | claude-code | yes | 52/41 | 2m | $0.88 | clean |  |
| 2026-08-04-mixed-01 | 01-live-orders | mixed | ampcode | yes | 33/32 | 2m | $0.99 | clean |  |
| 2026-08-04-gpt-56-02 | 02-type-clean | gpt-56 | ampcode | yes | 51/41 | 3m | $1.03 | clean |  |

All four passed, so `notes` is empty; that column only fills in on a failure. The `tests` column is the interesting one: `35/32` means the model solved the task and then wrote 3 tests of its own, `33/32` means it cleared the floor exactly.

Four rows is obviously not a sample you can rank models with — that isn't what it's for. The table is here as an example of **shape**: what's worth recording per round, and which columns you are allowed to trust. See [how to read it](#reading-resultsmd) and [`RESULTS.md`](RESULTS.md).

### Tasks 01 and 02 are examples, not live instruments

Both are validated and genuinely runnable — clone this repo and you can complete a full round. But neither can be **used for measurement any more**, and the reason is itself the lesson.

First, `tasks/*/holdout/` is public along with everything else. The held-out tests are indexable and can end up in the next model's training data.

Second — and this matters more — task 02's solution doesn't even require digging into `holdout/`. It's sitting in the skeleton:

```bash
diff skeleton/lib/warung_web/order_params.ex \
     tasks/02-type-clean/overlay/lib/warung_web/order_params.ex
```

`skeleton/` is where every run starts, so it can't be removed. **The leak surface is always wider than the directory you marked secret** — git history, build artifacts, and `NOTES.md` all count.

So if you need uncontaminated numbers: **fork this, delete `tasks/`, write tasks from your own codebase, and keep that repo private.** What's published here is the method, not the exam.

---

## How it works

One round = one model, one task, one agent harness.

```
                  bin/evalcode start
skeleton/  ────────────────────────────────►  runs/<id>/     ← the agent works here
+ tasks/<id>/overlay                          + TASK.md          (its own git repo)
                                              + .git

                  bin/evalcode grade
runs/<id>/  ───────────────────────────────►  one row in RESULTS.md
+ tasks/<id>/holdout   (copied in only now)   + runs/<id>.{test,compile,diff}.log
```

The key property: **held-out tests enter the workspace only at grading time.** While the agent works, they exist on no disk it can reach.

---

## Setup

Requires [Nix](https://nixos.org/download) (optional: [direnv](https://direnv.net)).

```bash
git clone <url-of-this-repo>
cd evalcode
direnv allow      # or: nix develop
```

The devshell pins **Elixir 1.20.x + Erlang/OTP 27**. `start` and `grade` refuse to run outside it — not pedantry: task 02 is scored entirely on a warning class that only exists in Elixir 1.20's type checker. Under 1.18 its untouched start state compiles clean and would be recorded as completed work for zero effort.

---

## Running a round

### 1. Start

```bash
bin/evalcode start 01-live-orders opus5 claude-code
#                  <task>         <model> <harness>
```

This prints a workspace path, e.g. `runs/2026-08-09-opus5-01/`.

### 2. Work it

Open your coding agent **in that workspace**, not in this repo. Point it at `TASK.md` and let it work normally.

> The workspace is its own git repository, so `git log` from inside stops at the workspace boundary instead of walking up into the parent repo that holds the answer key. Still, don't `--add-dir` this repo into the agent.

Running the same model on the same task twice in one day is fine — the second run gets a `-2` suffix. Within-model variance is worth measuring.

### 3. Grade

```bash
bin/evalcode grade 2026-08-09-opus5-01 --cost 2.10
```

- `--cost` comes from the agent's own reporting (`/cost` in Claude Code). Must look like `2.10`.
- `--duration 12m` is optional. Without it, duration is wall-clock from `start` to `grade` — **including the time you spent at lunch.** Pass it explicitly if your agent reports its own working time.
- Malformed values are refused, not written into the table.

One row is appended to `RESULTS.md`. A graded run is marked with `runs/<id>.graded`; grading it again is refused unless you pass `--regrade`.

---

## What `completed` means

`completed=yes` only when **all** of these hold:

| Gate | Why it exists |
|---|---|
| `mix test` passes with held-out tests copied in | The actual exam |
| At least `min_tests` tests actually **ran** | Exit code 0 says nothing about how many tests ran. `ExUnit.configure(exclude: [:test])` exits 0. Deleting the test files that won't go green exits 0. Both once scored as passes. |
| No `@compile` / `@dialyzer` attributes were added | Silencing the compiler is not a fix |
| `mix compile --force --warnings-as-errors` exits 0 | Only for tasks whose `grading.conf` sets `requires_clean_compile=yes` |

On a failure, the `notes` column carries the reason: `suppressions added`, `only 10 of 32 tests ran`, `tests failed`, `compile failed`. It's empty on a pass. Without it the table can't tell a model that **tried and failed** from one that **silenced the checker**.

## Reading `RESULTS.md`

Not all columns carry equal weight, and the table says so out loud:

- **Measured by the harness:** `completed`, `tests`, `compile`, `notes`
- **Typed in by the operator, unverified:** `cost`, `duration` (whenever `--duration` was passed), and the `model` / `harness` labels

The `tests` column is `<ran>/<floor>`. `35/32` means the model solved the task and then wrote 3 tests of its own. A `?` numerator means the count couldn't be read from the log — which never passes.

The `run` column is the row's only link to its evidence: `runs/<run>.diff.log` is what the model actually wrote.

---

## Available tasks

| id | what it measures |
|---|---|
| `01-live-orders` | Phoenix LiveView, PubSub, streams — and whether the broadcast is put in the right layer (the context, not the LiveView) |
| `02-type-clean` | Elixir 1.20 type inference — and whether the fix is real or a suppression |

---

## Adding your own task

A task is one directory under `tasks/`:

```
tasks/03-your-task/
├── task.md          # what the agent reads (copied in as TASK.md)
├── grading.conf     # REQUIRED — without it, start and grade both refuse
├── holdout/         # tests the agent never sees
├── overlay/         # optional: files that replace skeleton files (the broken start state)
└── NOTES.md         # validation record
```

`grading.conf` is shell-sourced, so it's `key=value` with no spaces:

```sh
min_tests=32               # skeleton tests + held-out tests, counted by running
requires_clean_compile=no  # yes makes --warnings-as-errors part of completed
```

### Non-negotiable rules for held-out tests

1. **Namespace the modules under `Holdout`** — `WarungWeb.Holdout.MyThingTest` — and prefix the filenames `holdout_`.
   Otherwise: a model that solves the task and then writes the obvious test for the module it just changed collides with a held-out module of the same name, the whole run fails to compile, and you record `completed=no` for a model that did the work **and** then did the diligent thing.

2. **Any test module that touches the database must be `async: false`.**
   SQLite locks the whole database file. Async writers flake about one run in thirty, and that reads as a model failure.

### Validate before you trust it

Do this by hand, don't assume:

1. `start` a run, then `grade` the **completely untouched** workspace. The held-out tests **must fail**. If they pass, the task is already solved and measures nothing.
2. Solve the task yourself, grade again, confirm it passes.
3. Confirm `min_tests` matches what actually runs.
4. Record all of it in `NOTES.md` — including what the held-out tests deliberately **don't** catch.

---

## Testing the harness itself

```bash
bash test/evalcode_test.sh      # no Elixir needed — mix and elixir are stubbed
shellcheck bin/evalcode         # optional
```

Both run in CI on every push and PR.

---

## Repo layout

```
bin/evalcode            the harness, one bash file
skeleton/               the Phoenix 1.8 app every run starts from
tasks/<id>/             task definitions (see above)
runs/                   workspaces + logs (gitignored, safe to delete)
test/evalcode_test.sh   unit tests for the harness
docs/                   findings that shaped the design
flake.nix               pinned devshell: Elixir 1.20 / OTP 27
RESULTS.md              the table
```

---

## What's worth stealing

If you're building your own benchmark, these eight are the expensive lessons — every one came from a real bug in this repo that produced a confidently wrong number:

1. **Pin the toolchain, and refuse to run outside it.** Elixir 1.18 made task 02 report "completed" for zero work.
2. **Exit code 0 is not a pass.** Count how many tests actually ran and compare against a floor.
3. **Assume the agent can find the answer key.** Workspaces are made into their own git repos because `git log` in the parent repo names the held-out tests in its commit subjects. "Don't open the parent repo" is an instruction to the operator and protects nothing from the agent's own tooling.
4. **Never copy compiled artifacts into the start state.** `_build/test/.../OrderParams.beam` decompiles back to the reference solution verbatim.
5. **Detect silencing; don't just trust green.** A base-vs-run diff looks for newly added `@compile`/`@dialyzer` — and the detector itself needs tests, because the first version could never fire at all (`diff` exits 1, which beats `grep`'s 0 under `pipefail`).
6. **Separate measured columns from hand-typed ones.** `cost` and `duration` are operator claims, not measurements, and the table says so.
7. **Every failing row must say why.** Without a `notes` column, "failed" lumps the model that tried in with the model that cheated.
8. **Refuse rather than print a wrong number.** An unparseable timestamp once produced a duration of `29762072m` and exited 0. Now it's an error.

The full reasoning behind each decision lives in the comments in `bin/evalcode` — those comments are the design record, not decoration.

---

## Contributing & license

See [CONTRIBUTING.md](CONTRIBUTING.md). The harness is [MIT](LICENSE) licensed; `skeleton/` is a generated Phoenix app and follows Phoenix's license.
