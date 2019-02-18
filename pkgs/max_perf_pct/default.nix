{ runCommand }:

runCommand "max_perf_pct" {} ''
  mkdir -p "$out/bin"
  cp "${./max_perf_pct}" "$out/bin/max_perf_pct"
''
