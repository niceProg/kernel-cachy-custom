#!/usr/bin/env bash
# ============================================================================
# Custom kernel build — linux-cachyos 7.0.9
# Tuned for ThinkPad L13 Yoga Gen1 (i5-10310U / Comet Lake)
# Recipe: BORE + ThinLTO + native(skylake) + HZ1000 + NO_HZ_IDLE
#         + full preempt + O3 + localmodconfig.  CPU mitigations: ON.
# ============================================================================
set -uo pipefail

# --- cachyos build toggles (read by PKGBUILD via ${var:=default}) -----------
export _cpusched=bore              # Burst-Oriented Response Enhancer scheduler
export _use_llvm_lto=thin          # Clang ThinLTO
export _processor_opt=native       # -march=native -> skylake on this CPU
export _HZ_ticks=1000              # 1000 Hz tick (responsive)
export _tickrate=idle              # NO_HZ_IDLE (tickless idle -> battery)
export _preempt=full               # full preemption (low latency)
export _cc_harder=yes              # -O3
export _per_gov=no                 # keep schedutil default (TLP/battery)
export _localmodcfg=yes            # trim modules to this machine
export _localmodcfg_path="$HOME/.config/modprobed.db"
export _tcp_bbr3=yes               # Google BBR v3 as default TCP congestion control
# Untouched cachyos defaults: _hugepage=always, _cachy_config=yes,
# CONFIG_CPU_MITIGATIONS=y (mitigations stay ON).

# --- keep heavy build temp OFF tmpfs (/tmp is RAM-backed, 8G) ----------------
export TMPDIR="$HOME/kernel-build/tmp"
mkdir -p "$TMPDIR"

export MAKEFLAGS="-j$(nproc)"

cd "$HOME/kernel-build/linux-cachyos" || { echo "FATAL: source dir missing"; exit 1; }

echo "==================================================================="
echo "BUILD START : $(date)"
echo "MAKEFLAGS   : $MAKEFLAGS"
echo "TMPDIR      : $TMPDIR"
echo "==================================================================="

# -f overwrite; -C cleanbuild wipes $srcdir first so the non-idempotent
# bore patch can't conflict with leftovers from a previous failed run.
# no -s (deps pre-installed) so no sudo is needed mid-build.
makepkg -fC --noconfirm --nocheck
rc=$?

echo "==================================================================="
echo "MAKEPKG EXIT: $rc   at $(date)"
ls -la "$HOME/kernel-build/linux-cachyos"/*.pkg.tar.* 2>/dev/null || echo "(no packages produced)"
echo "==================================================================="
exit $rc
