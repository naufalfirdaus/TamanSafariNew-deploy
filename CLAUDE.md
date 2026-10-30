# Workspace Presales Multi-Agent

Folder ini dipakai untuk (1) menyusun proposal presales dan (2) membangun demo di org Salesforce, dengan tim subagent.

## Struktur folder
- `input/<klien>/` — bahan mentah dari klien: transkrip, notulen, RFP, email
- `pricelist/` — file price list (opsional)
- `templates/` — template proposal perusahaan (opsional)
- `output/<klien>/` — hasil proposal (01–05) dan demo (`demo/10`–`13`)
- `force-app/main/default/` — source metadata Salesforce (SFDX) untuk demo
- `scripts/data/<klien>/` — generator data dummy, Id yang dibuat, script cleanup
- `config/project-scratch-def.json` — definisi scratch org

## Alur agent
- Proposal: discovery → solution → pricing → writer → reviewer → `/proposal <klien> <path-bahan>`
- Demo: demo-planner → sf-builder → data-seeder → demo-tester → `/demo <klien> <alias|scratch> [brief]`

## Aturan umum
- Semua output dalam Bahasa Indonesia.
- Jangan mengarang angka, jumlah user, fitur, atau nilai picklist. Yang tidak diketahui ditulis TBD.
- Nama file output selalu mengikuti pola di atas.

## Aturan Salesforce org (wajib)
- Setiap perintah `sf` yang mengubah org WAJIB memakai `-o <alias>`; alias harus ada di `.claude/allowed-orgs.txt`.
- Hanya org demo: sandbox, scratch org, trial/demo org, atau Developer Edition. Jangan pernah production atau org klien.
- Dilarang: hapus org, destructive changes, `--purge-on-delete`, mengubah setting keamanan org.
- Jika hook pengaman memblokir perintah, jangan diakali — laporkan ke user.

<!-- presales-project:start -->
## Project ini
- Klien: tamansafari
- Bahan klien: `input/tamansafari/`  |  Hasil: `output/tamansafari/`
- Org demo: `TamanSafari`
- Deck proposal: bahasa `en` · template `label` · mata uang lisensi `USD` (ubah dengan `presales-init tamansafari --bahasa-deck id|en --template-deck label|nomor --mata-uang USD|IDR`)
- Bahasa (menggantikan aturan bahasa umum di atas):
  - Proposal untuk klien (`04-proposal.md`, `04-slide-outline.md`): Bahasa Inggris.
  - Isi demo di org/tenant (label, picklist, nama app/report/dashboard, template email, data dummy): Bahasa Inggris. Ubah dengan `--bahasa-demo id|en`.
  - Dokumen kerja internal (discovery, solution, pricing, review, hasil grill, rencana dan laporan demo), catatan pembicara, dan percakapan dengan user: Bahasa Indonesia.
- Contoh: `/proposal tamansafari input/tamansafari/`  |  `/demo tamansafari TamanSafari`
<!-- presales-project:end -->
