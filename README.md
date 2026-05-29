# kernel-arch-cachy-custom

Resep build **kernel custom `linux-cachyos`** yang di-tune khusus untuk
**ThinkPad L13 Yoga Gen 1** (Intel **i5-10310U**, Comet Lake-U, 4c/8t) di Arch Linux.

Repo ini menyimpan **resep**-nya saja (PKGBUILD, patch, kernel config, script
build) — bukan source tree atau paket binary. Kernel bisa di-rebuild dari nol
kapan saja secara reproducible.

> Hidup berdampingan dengan kernel stock `linux` — stock tetap jadi fallback boot,
> tidak diganggu.

---

## Kenapa kernel custom?

Kernel stock dikompilasi **generik** agar jalan di semua CPU. Build ini dijahit
untuk satu mesin: optimasi instruksi CPU spesifik + scheduler responsif, tanpa
mengorbankan baterai maupun keamanan.

| Knob (`build.sh`) | Nilai | Alasan |
|---|---|---|
| `_cpusched` | `bore` | BORE scheduler — desktop lebih responsif |
| `_use_llvm_lto` | `thin` | Clang ThinLTO — optimasi lintas-modul saat link |
| `_processor_opt` | `native` | `-march=native` → Skylake (AVX2, FMA, BMI2, dll) |
| `_HZ_ticks` | `1000` | tick 1000 Hz — latensi rendah |
| `_tickrate` | `idle` | `NO_HZ_IDLE` — tickless saat idle → hemat baterai |
| `_preempt` | `full` | full preemption — latensi rendah |
| `_cc_harder` | `yes` | `-O3` |
| `_per_gov` | `no` | biarkan `schedutil` default (TLP atur baterai) |
| `_localmodcfg` | `yes` | trim modul ke mesin ini (`~/.config/modprobed.db`) |
| mitigations | **ON** | `CONFIG_CPU_MITIGATIONS=y` — keamanan tidak dikompromikan |

---

## Isi repo

| File | Keterangan |
|---|---|
| `build.sh` | Script build — semua env var tuning di atas + `makepkg` |
| `linux-cachyos.conf` | Entry boot systemd-boot |
| `linux-cachyos/PKGBUILD` | PKGBUILD CachyOS (b2sums sudah di-patch untuk BORE) |
| `linux-cachyos/.SRCINFO` | Metadata paket |
| `linux-cachyos/0001-bore-cachy.patch` | Patch BORE scheduler |
| `linux-cachyos/dkms-clang.patch` | Patch kompat DKMS + Clang |
| `linux-cachyos/config` | Kernel config dasar |
| `linux-cachyos/config-7.0.9-1-cachyos` | Kernel config final hasil build |

Artifact build (`src/`, `pkg/`, tarball source, `*.pkg.tar.zst`) sengaja
**di-exclude** lewat `.gitignore` — semua itu regenerable.

---

## Cara rebuild

### Prasyarat
- Arch Linux + base-devel
- Toolchain LLVM **sehat & versi cocok** (`clang`, `llvm`, `llvm-libs`, `lld` versi sama) — wajib untuk ThinLTO
- `rust` + `rust-src` (untuk Rust-for-Linux)
- `~/.config/modprobed.db` (untuk `localmodconfig`)

### Langkah
```bash
# 1. clone repo ini
git clone git@github.com:niceProg/kernel-arch-cachy-custom.git ~/kernel-build
cd ~/kernel-build

# 2. siapkan source CachyOS (PKGBUILD sudah ada; ambil source + verifikasi sums)
cd linux-cachyos
makepkg -o            # download & extract source saja

# 3. build pakai resep (env var tuning ada di build.sh)
cd ~/kernel-build
bash build.sh         # makepkg -fC --noconfirm --nocheck
```
ETA ~1.5–3 jam (ThinLTO + `-O3` di CPU 15W). Hasil: `linux-cachyos` +
`linux-cachyos-headers` `*.pkg.tar.zst`.

```bash
# 4. install
sudo pacman -U linux-cachyos/linux-cachyos-*.pkg.tar.zst \
               linux-cachyos/linux-cachyos-headers-*.pkg.tar.zst
```
Pasang `linux-cachyos.conf` ke `/boot/loader/entries/` (sesuaikan PARTUUID/root
mesin kamu), lalu reboot dan pilih entry-nya. `uname -r` → `7.0.9-cachyos`.

> ⚠️ **Spesifik mesin**: `-march=native` & `localmodconfig` membuat kernel ini
> di-tune untuk i5-10310U + set modul ThinkPad ini. Untuk hardware lain,
> regenerasi `modprobed.db` dan pertimbangkan ganti `_processor_opt`.

---

## Tuning opsional (tidak aktif secara default)

Beberapa penyetelan tambahan yang bisa dipertimbangkan, terpisah dari resep inti:

- **BBR v3** — CachyOS sudah menyediakan toggle-nya; aktifkan lewat `build.sh`:
  ```bash
  export _tcp_bbr3=yes
  ```
- **Tuning jaringan via sysctl** (tanpa rebuild kernel) — mis. `/etc/sysctl.d/99-net.conf`:
  ```conf
  net.core.default_qdisc = fq
  net.ipv4.tcp_congestion_control = bbr
  ```

Catatan: opsi di atas opsional dan tidak diaktifkan pada build default repo ini.

---

## Kredit
- [CachyOS](https://github.com/CachyOS) — PKGBUILD & patchset `linux-cachyos`
- [BORE scheduler](https://github.com/firelzrd/bore-scheduler) — Masahito Suzuki

## Lisensi
[GPL-2.0](./LICENSE) — kernel config & patch adalah turunan dari Linux kernel (GPL-2.0).
