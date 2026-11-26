import json
import re
from pathlib import Path
import matplotlib.pyplot as plt
import numpy as np
import pandas as pd

# Point to ~/fcup/sysAdmin/project/benchmarks (or ./benchmarks if run from project/)
BENCHMARKS_DIR = Path.home() / "fcup" / "sysAdmin" / "project" / "benchmarks"
OUTPUT_DIR = Path.home() / "fcup" / "sysAdmin" / "project" / "plots_uc1"
OUTPUT_DIR.mkdir(parents=True, exist_ok=True)

SCENARIO_ORDER = [
    "reference",
    "raid0",
    "raid1",
    "raid5",
    "raid5-degraded",
    "raid5-rebuild",
    "raid6",
    "raid10",
]

PROFILE_ORDER = [
    "seq-read",
    "seq-write",
    "rand-read",
    "rand-write",
]

FILE_RE = re.compile(
    r"^(?P<profile>seq-read|seq-write|rand-read|rand-write)-run(?P<run>\d+)\.json$",
    re.IGNORECASE,
)


def extract_metrics(json_path: Path, profile: str) -> dict:
    """Extract throughput (MB/s) and IOPS from a fio JSON output file."""
    with json_path.open("r", encoding="utf-8") as f:
        data = json.load(f)

    jobs = data.get("jobs", [])
    if not jobs:
        raise ValueError(f"No 'jobs' found in {json_path}")

    job = jobs[0]
    direction = "read" if "read" in profile.lower() else "write"
    stats = job.get(direction, {})

    if "bw_bytes" in stats and stats["bw_bytes"] is not None:
        mb_s = float(stats["bw_bytes"]) / 1e6
    else:
        mb_s = (float(stats.get("bw", 0.0)) * 1024.0) / 1e6

    iops = float(stats.get("iops", 0.0))
    return {"mb_s": mb_s, "iops": iops}


def load_all_runs(benchmarks_dir: Path) -> pd.DataFrame:
    rows = []
    for scenario_dir in sorted(benchmarks_dir.iterdir()):
        if not scenario_dir.is_dir():
            continue
        scenario = scenario_dir.name

        for json_path in sorted(scenario_dir.glob("*.json")):
            match = FILE_RE.match(json_path.name)
            if not match:
                print(f"[skip] Unexpected filename: {json_path}")
                continue

            profile = match.group("profile").lower()
            run = int(match.group("run"))
            metrics = extract_metrics(json_path, profile)

            rows.append(
                {
                    "scenario": scenario,
                    "profile": profile,
                    "run": run,
                    "mb_s": metrics["mb_s"],
                    "iops": metrics["iops"],
                }
            )

    if not rows:
        raise RuntimeError(f"No matching fio JSON files found under {benchmarks_dir}")

    df = pd.DataFrame(rows)
    df["scenario"] = pd.Categorical(df["scenario"], categories=SCENARIO_ORDER, ordered=True)
    df["profile"] = pd.Categorical(df["profile"], categories=PROFILE_ORDER, ordered=True)
    return df.sort_values(["scenario", "profile", "run"]).reset_index(drop=True)


def summarize_runs(df: pd.DataFrame) -> pd.DataFrame:
    summary = (
        df.groupby(["scenario", "profile"], observed=False, as_index=False)
        .agg(
            runs=("run", "count"),
            mb_s_mean=("mb_s", "mean"),
            mb_s_std=("mb_s", "std"),
            iops_mean=("iops", "mean"),
            iops_std=("iops", "std"),
        )
    )
    return summary.sort_values(["scenario", "profile"]).reset_index(drop=True)


def plot_grouped_metric(summary: pd.DataFrame, col_mean: str, col_std: str, ylabel: str, title: str, out_name: str) -> None:
    scenarios = [s for s in SCENARIO_ORDER if s in summary["scenario"].astype(str).unique()]
    profiles = [p for p in PROFILE_ORDER if p in summary["profile"].astype(str).unique()]

    x = np.arange(len(scenarios))
    width = 0.8 / max(len(profiles), 1)

    fig, ax = plt.subplots(figsize=(13, 6))
    for i, prof in enumerate(profiles):
        sub = summary[summary["profile"].astype(str) == prof].set_index("scenario").reindex(scenarios)
        offset = (i - (len(profiles) - 1) / 2) * width
        ax.bar(
            x + offset,
            sub[col_mean],
            width=width * 0.92,
            yerr=sub[col_std],
            capsize=3,
            label=prof,
        )

    ax.set_xticks(x)
    ax.set_xticklabels(scenarios, rotation=20, ha="right")
    ax.set_ylabel(ylabel)
    ax.set_title(title, fontsize=13, fontweight="bold")
    ax.legend(title="Workload Profile")
    ax.grid(axis="y", linestyle="--", alpha=0.4)

    fig.tight_layout()
    out_path = OUTPUT_DIR / out_name
    fig.savefig(out_path, dpi=200)
    plt.close(fig)
    print(f"[saved] {out_path}")


def main() -> None:
    raw_df = load_all_runs(BENCHMARKS_DIR)
    summary_df = summarize_runs(raw_df)

    print(f"Loaded {len(raw_df)} run files across {summary_df['scenario'].nunique()} scenarios.")
    print("\n=== 3-Run Mean Summary (MB/s & IOPS) ===")
    print(summary_df.to_string(index=False, float_format=lambda v: f"{v:.2f}"))

    # Pivot tables helpful for pasting directly into the UC1 report
    mb_pivot = summary_df.pivot(index="scenario", columns="profile", values="mb_s_mean")
    iops_pivot = summary_df.pivot(index="scenario", columns="profile", values="iops_mean")

    print("\n=== Mean Throughput (MB/s) Table ===")
    print(mb_pivot.to_string(float_format=lambda v: f"{v:.2f}"))

    print("\n=== Mean IOPS Table ===")
    print(iops_pivot.to_string(float_format=lambda v: f"{v:.1f}"))

    raw_df.to_csv(OUTPUT_DIR / "uc1_all_96_runs.csv", index=False)
    summary_df.to_csv(OUTPUT_DIR / "uc1_summary_means.csv", index=False)

    plot_grouped_metric(
        summary_df,
        col_mean="mb_s_mean",
        col_std="mb_s_std",
        ylabel="Mean Throughput (MB/s)",
        title="UC1 RAID Benchmark — Throughput by Scenario & Profile (3-Run Mean ± SD)",
        out_name="uc1_throughput_mbs.png",
    )
    plot_grouped_metric(
        summary_df,
        col_mean="iops_mean",
        col_std="iops_std",
        ylabel="Mean IOPS",
        title="UC1 RAID Benchmark — IOPS by Scenario & Profile (3-Run Mean ± SD)",
        out_name="uc1_iops.png",
    )


if __name__ == "__main__":
    main()