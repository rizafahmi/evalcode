# Security

[🇮🇩 Bahasa Indonesia](#bahasa-indonesia) · [🇬🇧 English](#english)

## Bahasa Indonesia

### Dua hal yang perlu kamu tahu sebelum menjalankan benchmark ini

**1. `grade` menjalankan kode yang ditulis model, di mesin kamu.**

`bin/evalcode grade` menjalankan `mix test` dan `mix compile` di dalam
`runs/<id>/` — direktori yang isinya baru saja diedit bebas oleh sebuah coding
agent. Kode itu jalan dengan hak akses user kamu: bisa membaca file di luar
workspace, dan bisa membuka koneksi jaringan. `bin/evalcode` **tidak** melakukan
sandboxing.

Kalau kamu mengukur model atau agent harness yang belum kamu percaya, jalankan seluruh
putaran di VM atau container sekali pakai. [`Dockerfile`](Dockerfile) di root
sudah cukup untuk itu — perlu diingat, bind mount `-v "$PWD:/work"` yang
disarankan README memang membuka checkout kamu ke dalam container, jadi
mount checkout terpisah kalau isolasinya yang kamu cari, bukan sekadar
kepraktisan toolchain.

**2. `tasks/<id>/grading.conf` di-source oleh shell.**

`grade` memanggil `source` pada `grading.conf` untuk membaca `min_tests` dan
`requires_clean_compile`. File itu bukan data — apa pun di dalamnya dieksekusi
sebagai perintah shell dengan hak akses kamu.

Artinya: **baca isi `tasks/*/grading.conf` sebelum menjalankan task dari fork
atau PR orang lain.** Ini konsekuensi yang disengaja dari format `key=value`
sederhana, dan disebut di sini supaya tidak jadi kejutan.

### Melaporkan kerentanan

Jangan buka issue publik. Pakai tab **Security → Report a vulnerability** di repo
ini; laporannya privat sampai ada perbaikan.

Yang paling relevan di repo ini: cara membuat `grade` mencatat `completed=yes`
untuk pekerjaan yang tidak dilakukan, atau membuat held-out test terbaca oleh
agent sebelum grading. Dua-duanya merusak angka, dan itu kerusakan yang sama
seriusnya dengan kerentanan biasa.

### Versi yang didukung

Hanya `main`. Repo ini tidak punya rilis bernomor.

---

## English

### Two things to know before you run this benchmark

**1. `grade` executes model-written code on your machine.**

`bin/evalcode grade` runs `mix test` and `mix compile` inside `runs/<id>/` — a
directory a coding agent just edited freely. That code runs with your user's
privileges: it can read files outside the workspace and open network
connections. `bin/evalcode` does **no** sandboxing.

If you are measuring a model or agent harness you do not already trust, run the
whole round inside a disposable VM or container. The [`Dockerfile`](Dockerfile)
at the root is enough for that — but note that the `-v "$PWD:/work"` bind mount
the README suggests does expose your checkout to the container, so mount a
separate checkout when isolation is what you are after rather than just a
convenient toolchain.

**2. `tasks/<id>/grading.conf` is shell-sourced.**

`grade` calls `source` on `grading.conf` to read `min_tests` and
`requires_clean_compile`. That file is not data — anything in it executes as a
shell command with your privileges.

So: **read `tasks/*/grading.conf` before running a task from someone else's fork
or pull request.** This is a deliberate consequence of the simple `key=value`
format, written down here so it is not a surprise.

### Reporting a vulnerability

Please don't open a public issue. Use the **Security → Report a vulnerability**
tab on this repository; the report stays private until there's a fix.

The most relevant class here: any way to make `grade` record `completed=yes` for
work that wasn't done, or to expose the held-out tests to the agent before
grading. Both corrupt the numbers, which in a benchmark is the same severity as
a conventional vulnerability.

### Supported versions

`main` only. This repository has no numbered releases.
