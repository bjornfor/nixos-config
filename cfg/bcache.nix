{ config, lib, pkgs, ... }:

{
  systemd.tmpfiles.rules = [
    # Backing device
    "w /sys/block/bcache*/bcache/sequential_cutoff - - - - ${builtins.toString (256*1024*1024)}" # default: 4MiB
    "w /sys/block/bcache*/bcache/cache_mode - - - - writeback" # default: writethrough
    "w /sys/block/bcache*/bcache/writeback_percent - - - - 30" # default: 10

    # Cache device.
    # Prevent reads and writes going to the hdd when the ssd is slow, because
    # using this feature doesn't work well in my experience. Things become even
    # slower.
    "w /sys/fs/bcache/*/congested_read_threshold_us  - - - - 0" # default: 2000
    "w /sys/fs/bcache/*/congested_write_threshold_us - - - - 0" # default: 20000
  ];
}
