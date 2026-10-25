"""Isolated synthetic CLI diagnostics, never a GUI-latency or user-study claim.

Run only on a disposable runner after compilation, with the freshly built CLI.
No third-party Python packages, user documents, network, or tight timing thresholds.
"""
import argparse
import hashlib
import json
import os
from pathlib import Path
import platform
import statistics
import subprocess
import time


def fixture(pages):
    objects = [b"<< /Type /Catalog /Pages 2 0 R >>",
               f"<< /Type /Pages /Kids [{' '.join(f'{4+2*i} 0 R' for i in range(pages))}] /Count {pages} /MediaBox [0 0 595 842] >>".encode(),
               b"<< /Type /Font /Subtype /Type1 /BaseFont /Helvetica >>"]
    for i in range(pages):
        stream = f"BT /F1 16 Tf 30 790 Td (PAGE-{i+1:04}) Tj ET\n".encode()
        stream += b"0.9 0.94 1 rg\n" + b"".join(f"{20+j%8*65} {40+j//8*65} 45 40 re f\n".encode() for j in range(64))
        objects += [f"<< /Type /Page /Parent 2 0 R /Contents {5+2*i} 0 R /Resources << /Font << /F1 3 0 R >> >> >>".encode(),
                    f"<< /Length {len(stream)} >>\nstream\n".encode()+stream+b"endstream"]
    out = bytearray(b"%PDF-1.7\n"); offsets = []
    for i, obj in enumerate(objects, 1):
        offsets.append(len(out)); out.extend(f"{i} 0 obj\n".encode()+obj+b"\nendobj\n")
    xref = len(out)
    out.extend(f"xref\n0 {len(objects)+1}\n0000000000 65535 f \n".encode())
    for offset in offsets:
        out.extend(f"{offset:010} 00000 n \n".encode())
    out.extend(f"trailer\n<< /Size {len(objects)+1} /Root 1 0 R >>\nstartxref\n{xref}\n%%EOF\n".encode())
    assert len(out) <= 4 * 1024 * 1024
    return out


def main():
    parser = argparse.ArgumentParser(); parser.add_argument("--cli", required=True); parser.add_argument("--out", required=True)
    args = parser.parse_args(); binary = str(Path(args.cli).resolve()); root = Path(args.out).resolve()
    root.mkdir(parents=True, exist_ok=False)
    inputs = {}
    for pages in (50, 500):
        data = fixture(pages); name = f"Документ-{pages}.pdf"; (root/name).write_bytes(data)
        inputs[name] = {"pages": pages, "bytes": len(data), "sha256": hashlib.sha256(data).hexdigest(), "rectangles_per_page": 64}

    def check(arguments):
        result = subprocess.run([binary, *arguments], cwd=root, capture_output=True, timeout=90)
        if result.returncode:
            raise RuntimeError(f"{arguments}: {result.stderr.decode('utf-8',errors='replace')}")
        return result

    scenarios = {
        "open_50_cli_info": ["info", "Документ-50.pdf"],
        "open_500_cli_info": ["info", "Документ-500.pdf"],
        "first_render_500_96dpi": ["render", "Документ-500.pdf", "--page", "1", "--dpi", "96", "--out", "preview.png"],
        "combine_50_plus_50": ["combine", "Документ-50.pdf", "Документ-50.pdf", "--out", "combined.pdf"],
        "split_500_every_100": ["split", "Документ-500.pdf", "--every", "100", "--out-dir", "parts"],
    }
    records = []
    for scenario, arguments in scenarios.items():
        for sample in range(6):
            # Every output has a new destination; measured samples never benchmark overwriting.
            current = [a.replace("preview.png", f"preview-{sample}.png").replace("combined.pdf", f"combined-{sample}.pdf").replace("parts", f"parts-{sample}") for a in arguments]
            metric = root/f"{scenario}-{sample}.rss"; command = [binary, *current]
            linux_rss = platform.system() == "Linux"
            if linux_rss:
                command = ["/usr/bin/time", "-f", "%M", "-o", str(metric), *command]
            start = time.perf_counter()
            result = subprocess.run(command, cwd=root, capture_output=True, timeout=90)
            elapsed = time.perf_counter()-start
            if result.returncode:
                raise RuntimeError(f"{scenario}: {result.stderr.decode('utf-8',errors='replace')}")
            peak = int(metric.read_text().strip()) if linux_rss else None
            if sample:
                records.append({"scenario": scenario, "sample": sample, "elapsed_seconds": elapsed, "max_rss_kib": peak})
            if scenario.startswith("combine"):
                assert json.loads(check(["info", f"combined-{sample}.pdf"]).stdout)["pages"] == 100
                words = check(["text", f"combined-{sample}.pdf"]).stdout.decode("utf-8").split()
                assert words == [f"PAGE-{i+1:04}" for i in range(50)] * 2
            if scenario.startswith("split"):
                parts = sorted((root/f"parts-{sample}").glob("*.pdf")); assert len(parts) == 5
                words = []
                for part in parts:
                    assert json.loads(check(["info", str(part)]).stdout)["pages"] == 100
                    words.extend(check(["text", str(part)]).stdout.decode("utf-8").split())
                assert words == [f"PAGE-{i+1:04}" for i in range(500)]
            if scenario.startswith("first_render"):
                png = (root/f"preview-{sample}.png").read_bytes()
                assert png.startswith(b"\x89PNG\r\n\x1a\n") and png[12:16] == b"IHDR"
                assert int.from_bytes(png[16:20], "big") > 0 and int.from_bytes(png[20:24], "big") > 0
    for name, data in inputs.items():
        assert hashlib.sha256((root/name).read_bytes()).hexdigest() == data["sha256"]
    summary = {}
    for scenario in scenarios:
        samples = [r for r in records if r["scenario"] == scenario]
        times = [r["elapsed_seconds"] for r in samples]
        rss = [r["max_rss_kib"] for r in samples if r["max_rss_kib"] is not None]
        summary[scenario] = {"median_seconds": statistics.median(times), "min_seconds": min(times), "max_seconds": max(times), "median_max_rss_kib": statistics.median(rss) if rss else None}
    report = {"source": os.environ.get("GITHUB_SHA"), "platform": platform.platform(), "cpu_count": os.cpu_count(),
              "cli_version": check(["--version"]).stdout.decode("utf-8").strip(), "profile": "release",
              "fixtures": inputs, "warmup_processes_per_scenario": 1, "measured_processes_per_scenario": 5,
              "samples": records, "summary": summary,
              "limits": ["Whole fresh CLI process including startup and I/O, not internal engine-only or GUI latency.",
                         "Linux /usr/bin/time maximum RSS in KiB; Windows memory not measured by this harness.",
                         "Shared-runner observations, not controlled hardware or an improvement claim.",
                         "Synthetic bounded 50/500-page vector PDFs, not arbitrary huge scans or a user study."]}
    (root/"measurements.json").write_text(json.dumps(report, ensure_ascii=False, indent=2), encoding="utf-8")
    print(json.dumps(summary, indent=2))


if __name__ == "__main__":
    main()
