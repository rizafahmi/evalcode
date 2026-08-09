<!--
Bahasa Indonesia atau English, dua-duanya boleh.
Either language is fine.
-->

## Perubahan perilakunya / The behavior change

<!-- Apa yang jadi berbeda, bukan daftar file yang disentuh.
     What behaves differently now — not a list of files touched. -->

## Kalau ini mengubah gate penilaian / If this changes a grading gate

<!-- Angka salah seperti apa yang bisa lolos tanpa perubahan ini?
     What wrong number could get through without this change?
     Kosongkan kalau tidak relevan / leave blank if not applicable. -->

## Checklist

- [ ] `bash test/evalcode_test.sh` hijau / green
- [ ] `shellcheck --severity=warning bin/evalcode test/evalcode_test.sh` bersih / clean
- [ ] Perubahan perilaku `bin/evalcode` datang bersama test-nya / behavior changes to `bin/evalcode` come with a test
- [ ] Task baru menyertakan catatan validasi `NOTES.md` / a new task ships its `NOTES.md` validation record
- [ ] Tidak menambah baris ke `RESULTS.md` / no new rows in `RESULTS.md`

<!-- Aturan lengkapnya / the full rules:
     https://github.com/rizafahmi/evalcode/blob/main/CONTRIBUTING.md -->
