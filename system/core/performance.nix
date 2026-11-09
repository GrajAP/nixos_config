_: {
  # 2026-11-09: the PC had 11G in disk swap and 20% full IO pressure. Gradle
  # daemons and the like got paged to the NVMe, and every page fault on the
  # desktop (quickshell, the browser) waited on that disk. Compressed RAM swap
  # takes those pages first; the disk partition stays for hibernation and as a
  # last resort, because priority 100 outranks it.
  zramSwap = {
    enable = true;
    algorithm = "zstd";
    memoryPercent = 50;
    priority = 100;
  };

  # Swap-in from zram is cheaper than re-reading evicted file pages from disk,
  # so prefer swapping idle anonymous memory over dropping page cache. These
  # are the values ArchWiki and Pop!_OS use for zram.
  boot.kernel.sysctl = {
    "vm.swappiness" = 180;
    "vm.page-cluster" = 0;
    "vm.watermark_boost_factor" = 0;
    "vm.watermark_scale_factor" = 125;
  };

  # Builds (including the nightly auto-rebuild) yield the CPU and disk to the
  # desktop instead of competing with it.
  nix = {
    daemonCPUSchedPolicy = "batch";
    daemonIOSchedClass = "best-effort";
    daemonIOSchedPriority = 7;
  };
}
