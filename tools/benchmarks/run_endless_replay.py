#!/usr/bin/env python3
"""Run six synthetic v5 replay cases locally. Writes results only when --output supplied."""
import argparse, json, os, pathlib, platform, statistics, subprocess, tempfile, time
ROOT = pathlib.Path(__file__).resolve().parents[2]
p = argparse.ArgumentParser()
p.add_argument('--godot', default='godot')
p.add_argument('--output', type=pathlib.Path)
a = p.parse_args()
results = []
for profile in ('corridor', 'primary', 'alternate'):
    for count in (1000, 10000):
        with tempfile.TemporaryDirectory(prefix='tower-replay-bench-') as tmp:
            env = dict(os.environ, HOME=tmp, XDG_CONFIG_HOME=tmp, XDG_CACHE_HOME=tmp, XDG_DATA_HOME=tmp)
            cmd = [a.godot, '--headless', '--path', str(ROOT), '--script', 'tools/benchmarks/endless_replay.gd', '--', profile, str(count)]
            start = time.monotonic()
            proc = subprocess.Popen(cmd, env=env, text=True, stdout=subprocess.PIPE, stderr=subprocess.PIPE)
            max_rss = 0
            while proc.poll() is None:
                try:
                    status = pathlib.Path(f'/proc/{proc.pid}/status').read_text()
                    values = [int(line.split()[1]) for line in status.splitlines() if line.startswith('VmHWM:')]
                    if values: max_rss = max(max_rss, values[0])
                except FileNotFoundError: pass
                if time.monotonic()-start > 180:
                    proc.kill();proc.communicate();raise SystemExit('Benchmark timed out')
                time.sleep(0.005)
            stdout, stderr = proc.communicate()
            run = subprocess.CompletedProcess(cmd, proc.returncode, stdout, stderr)
            if run.returncode or 'SCRIPT ERROR' in run.stderr:
                raise SystemExit(f'{profile}/{count} failed:\n{run.stdout}\n{run.stderr}')
            lines = [s.removeprefix('BENCH_RESULT ') for s in run.stdout.splitlines() if s.startswith('BENCH_RESULT ')]
            if len(lines) != 1: raise SystemExit(f'Missing result: {run.stdout}\n{run.stderr}')
            row = json.loads(lines[0])
            row.update(process_wall_seconds=round(time.monotonic()-start, 4), process_sampled_max_rss_kib=max_rss)
            row['replay_median_us'] = statistics.median(row['replay_us'])
            row['replay_max_us'] = max(row['replay_us'])
            results.append(row)
            print(f'{profile:9} {count:5} actions: median {row["replay_median_us"]/1000:.3f} ms; RSS peak {row["process_sampled_max_rss_kib"]} KiB', flush=True)
report = {'measured_at_utc': time.strftime('%Y-%m-%dT%H:%M:%SZ', time.gmtime()), 'machine': platform.platform(), 'cpu': platform.processor(), 'logical_cpus': os.cpu_count(), 'scope': 'Local synthetic Godot v5 benchmark; not Worker/Edge CPU measurements. Linux /proc VmHWM sampled every 5 ms; a final peak may be missed. RSS includes engine, fixtures and assertion copies. Timing is elapsed wall time, not measured CPU time.', 'results': results}
if a.output:
    a.output.parent.mkdir(parents=True, exist_ok=True)
    a.output.write_text(json.dumps(report, ensure_ascii=False, indent=2)+'\n')
else: print(json.dumps(report, ensure_ascii=False, indent=2))
