#!/usr/bin/env python3
"""
Personal Coding Agent Benchmark Leaderboard Builder
Generates a static Depot-styled leaderboard site for GitHub Pages by dynamically
discovering and parsing benchmark reports from git branches (evalcode_*).
"""

import argparse
import datetime
import html
import json
import os
from pathlib import Path
import re
import subprocess
import sys


def run_cmd(cmd, cwd=None):
    """Run a shell command and return stdout as string."""
    try:
        res = subprocess.run(
            cmd,
            cwd=cwd,
            stdout=subprocess.PIPE,
            stderr=subprocess.PIPE,
            text=True,
            check=True
        )
        return res.stdout
    except subprocess.CalledProcessError:
        return ""


def get_git_file(ref, filepath, cwd=None):
    """Retrieve file content from a specific git ref."""
    return run_cmd(["git", "show", f"{ref}:{filepath}"], cwd=cwd)


def discover_evaluation_branches(cwd=None, include_all_evalcode=False):
    """
    Find all local and remote branches that contain benchmark reports.
    Matches any branch starting with evalcode_ or having a report/ directory.
    """
    raw_refs = run_cmd(
        ["git", "for-each-ref", "--format=%(refname:short)", "refs/heads/", "refs/remotes/origin/"],
        cwd=cwd
    )
    all_refs = [r.strip() for r in raw_refs.splitlines() if r.strip()]
    
    seen_branches = set()
    candidate_refs = []

    for ref in all_refs:
        branch_name = ref
        if branch_name.startswith("origin/"):
            branch_name = branch_name[len("origin/"):]
        
        if branch_name in ["HEAD", "main"]:
            continue
            
        if branch_name in seen_branches:
            continue

        has_perf = bool(get_git_file(ref, "report/perf.md", cwd=cwd))
        has_exec = bool(get_git_file(ref, "report/execution.md", cwd=cwd))
        has_score = bool(get_git_file(ref, "report/score.md", cwd=cwd))
        
        has_reports = has_perf or has_exec or has_score
        
        if has_reports or (include_all_evalcode and branch_name.startswith("evalcode_")):
            seen_branches.add(branch_name)
            candidate_refs.append({
                "ref": ref,
                "name": branch_name,
                "has_reports": has_reports
            })

    # Sort branches
    candidate_refs.sort(key=lambda x: x["name"])
    return candidate_refs


def parse_perf_report(raw_md):
    """Parse report/perf.md into scenario records."""
    if not raw_md:
        return {"scenarios": {}, "wall_time": "—", "mean_ready_ms": None}

    scenarios = {}
    wall_time = "—"
    wt_match = re.search(r"Wall time:\s*([\d\.]+s)", raw_md)
    if wt_match:
        wall_time = wt_match.group(1)

    lines = raw_md.splitlines()
    ready_values = []

    for line in lines:
        if line.startswith("|") and not line.startswith("| Scenario") and not line.startswith("| ---"):
            parts = [p.strip() for p in line.split("|")[1:-1]]
            if len(parts) >= 10:
                scenario, status, n, ready, ttfb, lcp, dcl, load, doc_bytes, js_css = parts[:10]
                ready_ms = None
                ms_match = re.search(r"(\d+)ms", ready)
                if ms_match:
                    ready_ms = int(ms_match.group(1))
                    ready_values.append(ready_ms)

                scenarios[scenario] = {
                    "scenario": scenario,
                    "status": status,
                    "n": n,
                    "ready": ready,
                    "ready_ms": ready_ms,
                    "ttfb": ttfb,
                    "lcp": lcp,
                    "dcl": dcl,
                    "load": load,
                    "doc_bytes": doc_bytes,
                    "js_css_bytes": js_css
                }

    mean_ready_ms = round(sum(ready_values) / len(ready_values), 1) if ready_values else None

    return {
        "scenarios": scenarios,
        "wall_time": wall_time,
        "mean_ready_ms": mean_ready_ms
    }


def parse_a11y_report(raw_md):
    """Parse report/a11y.md into accessibility audit records."""
    if not raw_md:
        return {
            "screens": {},
            "total_violations": 0,
            "total_affected_nodes": 0,
            "clean_screens": 0,
            "screen_count": 0,
            "clean_percentage": 0,
            "wall_time": "—"
        }

    screens = {}
    total_violations = 0
    clean_screens = 0
    wall_time = "—"

    wt_match = re.search(r"Wall time:\s*([\d\.]+s)", raw_md)
    if wt_match:
        wall_time = wt_match.group(1)

    for line in raw_md.splitlines():
        if line.startswith("|") and not line.startswith("| Screen") and not line.startswith("| ---"):
            parts = [p.strip() for p in line.split("|")[1:-1]]
            if len(parts) >= 8:
                screen, status, viols, crit, serious, mod, minor, rules = parts[:8]
                v_count = int(viols) if viols.isdigit() else 0
                total_violations += v_count
                if v_count == 0:
                    clean_screens += 1

                screens[screen] = {
                    "screen": screen,
                    "status": status,
                    "violations": v_count,
                    "critical": int(crit) if crit.isdigit() else 0,
                    "serious": int(serious) if serious.isdigit() else 0,
                    "moderate": int(mod) if mod.isdigit() else 0,
                    "minor": int(minor) if minor.isdigit() else 0,
                    "rules": rules
                }

    node_matches = re.findall(r"\(serious,\s*(\d+)\s*nodes\)", raw_md)
    total_affected_nodes = sum(int(n) for n in node_matches) if node_matches else 0

    screen_count = len(screens)
    clean_pct = round((clean_screens / screen_count) * 100, 1) if screen_count > 0 else 0

    return {
        "screens": screens,
        "total_violations": total_violations,
        "total_affected_nodes": total_affected_nodes,
        "clean_screens": clean_screens,
        "screen_count": screen_count,
        "clean_percentage": clean_pct,
        "wall_time": wall_time
    }


def parse_execution_report(raw_md, branch_name):
    """Parse report/execution.md for agent metadata, milestones, test counts, and coverage."""
    agent_name = branch_name
    model_name = "Unknown Model"
    harness_name = "Harness"

    if raw_md:
        headings = re.findall(r"^#\s+(.*)", raw_md, re.MULTILINE)
        for h in headings:
            h_clean = h.strip()
            if h_clean != "Getting Started":
                agent_name = h_clean
                break

    if " - " in agent_name:
        parts = agent_name.split(" - ", 1)
        harness_name = parts[0].strip()
        model_name = parts[1].strip()
    else:
        harness_name = agent_name

    milestones = []
    total_turns = 0
    total_uncached = 0
    total_cached = 0
    total_output = 0
    total_reasoning = 0
    total_cost = 0.0

    notes = ""
    if raw_md:
        notes_match = re.search(r"^## Notes\s*\n(.*)\Z", raw_md, re.DOTALL | re.MULTILINE)
        if notes_match:
            notes = notes_match.group(1).strip()

        m_matches = re.findall(
            r"^## (?:Milestone\s+([1-8])|M([1-8]))\b[^\n]*\n(.*?)(?=^## |\Z)",
            raw_md,
            re.DOTALL | re.MULTILINE,
        )
        for num_long, num_short, m_body in m_matches:
            m_id = f"M{num_long or num_short}"
            test_match = re.search(r"Result:\s*(\d+)\s*passed", m_body)
            cov_match = re.search(r"Total\s*\|\s*\n\|\s*([\d\.]+)%", m_body) or re.search(r"Coverage:\s*([\d\.]+)%", m_body)
            cost_match = re.search(r"Cost:\s*\$([0-9\.]+)", m_body)
            if not cost_match:
                cost_match = re.search(r"#### Cost\s*\n\s*\$([0-9\.]+)", m_body)
            time_match = re.search(r"[Tt]otal time:\s*([^\n]+)", m_body)

            tok_m = re.search(r"([\d,]+)\s*tok\s*\nProvider", m_body)
            uncached_m = re.search(r"Uncached input\s*\n\s*([\d,]+)\s*tok", m_body)
            cached_m = re.search(r"Cached input\s*\n\s*([\d,]+)\s*tok", m_body)
            output_m = re.search(r"Output\s*\n\s*([\d,]+)\s*tok(?:\s*\(([\d,]+)\s*tok reasoning\))?", m_body)
            ctx_m = re.search(r"([\d.]+)\s*K used\s*/\s*([\d.]+)\s*K", m_body, re.IGNORECASE)

            turn_val = int(tok_m.group(1).replace(',', '')) if tok_m else 0
            uncached_val = int(uncached_m.group(1).replace(',', '')) if uncached_m else 0
            cached_val = int(cached_m.group(1).replace(',', '')) if cached_m else 0
            out_val = int(output_m.group(1).replace(',', '')) if output_m else 0
            reason_val = int(output_m.group(2).replace(',', '')) if (output_m and output_m.group(2)) else 0
            cost_val = float(cost_match.group(1)) if cost_match else 0.0
            context_used = f"{ctx_m.group(1)}K / {ctx_m.group(2)}K" if ctx_m else None

            total_turns += turn_val
            total_uncached += uncached_val
            total_cached += cached_val
            total_output += out_val
            total_reasoning += reason_val
            total_cost += cost_val

            # Gemini Flash cost per milestone ($0.075 / 1M uncached, $0.01875 / 1M cached, $0.30 / 1M output)
            gemini_m_cost = round((uncached_val / 1_000_000) * 0.075 + (cached_val / 1_000_000) * 0.01875 + (out_val / 1_000_000) * 0.30, 2)
            if turn_val == 0 and cost_val > 0:
                gemini_m_cost = round(cost_val * 1.3, 2)

            milestones.append({
                "milestone": m_id,
                "tests_passed": int(test_match.group(1)) if test_match else None,
                "coverage": float(cov_match.group(1)) if cov_match else None,
                "cost": f"${cost_val:.2f}" if cost_match else "—",
                "cost_num": cost_val,
                "gemini_cost": f"${gemini_m_cost:.2f}" if (turn_val > 0 or cost_val > 0) else "—",
                "gemini_cost_num": gemini_m_cost,
                "time": time_match.group(1).strip() if time_match else None,
                "turn_tokens": turn_val,
                "uncached_tokens": uncached_val,
                "cached_tokens": cached_val,
                "output_tokens": out_val,
                "reasoning_tokens": reason_val,
                "context_used": context_used
            })

    total_milestones = 8
    completed_milestones = len(milestones) if milestones else 0
    final_tests = milestones[-1]["tests_passed"] if (milestones and milestones[-1]["tests_passed"] is not None) else 0
    final_coverage = milestones[-1]["coverage"] if (milestones and milestones[-1]["coverage"] is not None) else 0.0

    # Total Gemini Flash estimate with Context Caching ($0.075/1M uncached, $0.01875/1M cached, $0.30/1M output + M7 est)
    gemini_total = round((total_uncached / 1_000_000) * 0.075 + (total_cached / 1_000_000) * 0.01875 + (total_output / 1_000_000) * 0.30 + 0.10, 2)
    gemini_nocache_total = round(((total_uncached + total_cached) / 1_000_000) * 0.075 + (total_output / 1_000_000) * 0.30 + 0.10, 2)
    cache_hit_rate = round((total_cached / (total_cached + total_uncached) * 100), 1) if (total_cached + total_uncached) > 0 else 0.0

    if total_turns >= 1_000_000:
        total_tokens_str = f"{total_turns / 1_000_000:.1f}M"
    elif total_turns >= 1_000:
        total_tokens_str = f"{total_turns / 1_000:.1f}K"
    elif total_turns > 0:
        total_tokens_str = str(total_turns)
    else:
        total_tokens_str = "—"

    is_gemini = "gemini" in model_name.lower() or "agy" in branch_name.lower()
    has_token_log = total_turns > 0
    has_cost_log = total_cost > 0
    if is_gemini and has_token_log:
        cost_display = f"${gemini_total:.2f} (est)"
    elif has_cost_log:
        cost_display = f"${total_cost:.2f}"
    else:
        cost_display = "—"
        gemini_total = 0.0
        gemini_nocache_total = 0.0

    return {
        "agent_name": agent_name,
        "harness_name": harness_name,
        "model_name": model_name,
        "notes": notes,
        "milestones": milestones,
        "completed_milestones": completed_milestones,
        "total_milestones": total_milestones,
        "completion_rate": round((completed_milestones / total_milestones) * 100, 1),
        "final_tests": final_tests,
        "final_coverage": final_coverage,
        "total_turns": total_turns,
        "total_tokens_str": total_tokens_str,
        "total_uncached": total_uncached,
        "total_cached": total_cached,
        "total_output": total_output,
        "total_reasoning": total_reasoning,
        "cache_hit_rate": cache_hit_rate,
        "total_cost": total_cost,
        "gemini_total": gemini_total,
        "gemini_nocache_total": gemini_nocache_total,
        "cost_display": cost_display,
        "has_token_log": has_token_log,
        "has_cost_log": has_cost_log,
        "is_gemini": is_gemini
    }


def parse_score_report(raw_md):
    """Parse report/score.md for held-out rubric results per milestone."""
    empty = {
        "pass": 0,
        "fail": 0,
        "skip": 0,
        "has_results": False,
        "milestones": {},
        "failed_milestones": [],
        "passed_milestones": [],
        "held_out_passed": 0,
        "held_out_total": 8,
    }
    if not raw_md:
        return empty

    pass_count = 0
    fail_count = 0
    skip_count = 0

    p_match = re.search(r"pass:\s*(\d+)", raw_md)
    if p_match:
        pass_count = int(p_match.group(1))

    f_match = re.search(r"fail:\s*(\d+)", raw_md)
    if f_match:
        fail_count = int(f_match.group(1))

    s_match = re.search(r"skip:\s*(\d+)", raw_md)
    if s_match:
        skip_count = int(s_match.group(1))

    statuses_by_m = {}
    for line in raw_md.splitlines():
        if not line.startswith("|"):
            continue
        parts = [p.strip() for p in line.split("|")[1:-1]]
        if len(parts) < 3:
            continue
        m_id, _bullet, status = parts[0], parts[1], parts[2].lower()
        if not re.fullmatch(r"M[1-8]", m_id):
            continue
        if status not in ("pass", "fail", "skip"):
            continue
        statuses_by_m.setdefault(m_id, []).append(status)

    def rollup(statuses):
        if "fail" in statuses:
            return "fail"
        if "pass" in statuses:
            return "pass"
        if "skip" in statuses:
            return "skip"
        return None

    rolled = {m: rollup(sts) for m, sts in statuses_by_m.items()}
    failed = sorted([m for m, st in rolled.items() if st == "fail"], key=lambda x: int(x[1:]))
    passed = sorted([m for m, st in rolled.items() if st == "pass"], key=lambda x: int(x[1:]))
    has_results = (pass_count + fail_count) > 0 or any(rolled.values())

    return {
        "pass": pass_count,
        "fail": fail_count,
        "skip": skip_count,
        "has_results": has_results,
        "milestones": rolled,
        "failed_milestones": failed,
        "passed_milestones": passed,
        "held_out_passed": len(passed),
        "held_out_total": 8,
    }


def run_has_held_out_failures(r):
    score = r.get("score") or {}
    return bool(score.get("has_results") and score.get("failed_milestones"))


def run_is_prd_complete(r):
    """100% PRD only when all 8 milestones are logged and held-out has no failures."""
    if r["execution"].get("completion_rate") != 100.0:
        return False
    if run_has_held_out_failures(r):
        return False
    return True


def get_git_metadata(ref, cwd=None):
    """Extract commit metadata and test file density directly from git."""
    commit_log = run_cmd(["git", "log", "-n", "1", "--format=%H|%an|%cI|%s", ref], cwd=cwd)
    commit_hash, author, commit_date, commit_msg = ("", "", "", "")
    if commit_log and "|" in commit_log:
        parts = commit_log.strip().split("|", 3)
        if len(parts) == 4:
            commit_hash, author, commit_date, commit_msg = parts

    tree_out = run_cmd(["git", "ls-tree", "-r", "--name-only", ref, "test"], cwd=cwd)
    test_files = [f for f in tree_out.splitlines() if f.endswith("_test.exs")]
    test_file_count = len(test_files)

    has_scope = bool(get_git_file(ref, "lib/alur/accounts/scope.ex", cwd=cwd))

    return {
        "commit_hash": commit_hash[:7] if commit_hash else "",
        "author": author,
        "commit_date": commit_date,
        "commit_msg": commit_msg,
        "test_file_count": test_file_count,
        "has_phx_18_scope": has_scope
    }


def collect_branch_data(branch_info, cwd=None):
    """Collect and synthesize all metrics for a given branch."""
    ref = branch_info["ref"]
    branch_name = branch_info["name"]
    has_reports = branch_info.get("has_reports", True)

    perf_raw = get_git_file(ref, "report/perf.md", cwd=cwd)
    a11y_raw = get_git_file(ref, "report/a11y.md", cwd=cwd)
    exec_raw = get_git_file(ref, "report/execution.md", cwd=cwd)
    score_raw = get_git_file(ref, "report/score.md", cwd=cwd)

    perf_data = parse_perf_report(perf_raw)
    a11y_data = parse_a11y_report(a11y_raw)
    exec_data = parse_execution_report(exec_raw, branch_name)
    score_data = parse_score_report(score_raw)
    git_meta = get_git_metadata(ref, cwd=cwd)

    display_title = exec_data["agent_name"]
    if display_title == branch_name:
        if "agy" in branch_name:
            display_title = "Antigravity CLI (Gemini 3.8 Flash High)"
        elif "dsh" in branch_name:
            display_title = "DeepSeek Harness (DeepSeek V4 Flash High)"
        elif "cursor" in branch_name:
            display_title = "Cursor Agent (Claude 3.7 Sonnet)"
        elif "codex" in branch_name:
            display_title = "Codex CLI (GPT 5.6-luna Medium)"
        elif "zcode" in branch_name:
            display_title = "ZCode Agent"

    return {
        "branch": branch_name,
        "ref": ref,
        "has_reports": has_reports,
        "title": display_title,
        "harness": exec_data["harness_name"],
        "model": exec_data["model_name"],
        "perf": perf_data,
        "a11y": a11y_data,
        "execution": exec_data,
        "score": score_data,
        "git": git_meta,
        "badges": []
    }


def attach_run_metadata(runs):
    """Assign objective metadata tags and sort runs alphabetically by branch."""
    if not runs:
        return runs

    # Sort runs alphabetically by branch name (no arbitrary ranking or medals)
    runs.sort(key=lambda r: r["branch"])

    for r in runs:
        if r["git"]["has_phx_18_scope"]:
            r["badges"].append({"type": "blue", "text": "Phx 1.8 Scoped"})
        if r["git"]["test_file_count"] >= 30:
            r["badges"].append({"type": "neutral", "text": "Modular Tests"})
        if run_is_prd_complete(r):
            r["badges"].append({"type": "neutral", "text": "100% PRD"})
        elif run_has_held_out_failures(r):
            failed = ", ".join(r["score"]["failed_milestones"])
            r["badges"].append({"type": "neutral", "text": f"Held-out fail {failed}"})
        if not r.get("has_reports", True):
            r["badges"].append({"type": "neutral", "text": "Pending Report"})

    return runs


# Backwards compatibility alias
compute_ranks_and_badges = attach_run_metadata


# Helper rendering functions
def render_badges_html(badges):
    out = []
    for b in badges:
        cls_type = b.get("type", "")
        tag_cls = "tag"
        if cls_type in ["blue", "violet", "neutral"]:
            tag_cls += f" tag-{cls_type}"
        out.append(f'<span class="{tag_cls}">{html.escape(b["text"])}</span>')
    return "".join(out)


def screen_violation_cell(screens, name):
    if name not in screens:
        return "—"
    return str(screens[name].get("violations", 0))


def run_cost_parts(r):
    """Return (cost_str, subtitle) from a run's own logs only."""
    ex = r["execution"]
    if ex.get("is_gemini") and ex.get("has_token_log"):
        return f"${ex['gemini_total']:.2f}", "Gemini Flash est"
    if ex.get("has_cost_log"):
        return f"${ex['total_cost']:.2f}", ex.get("model_name") or r.get("harness") or "reported"
    if any(m.get("context_used") for m in ex.get("milestones", [])):
        return "—", "context window only"
    return "—", "no billed log"


def billed_cost_values(runs):
    costs = []
    for r in runs:
        ex = r["execution"]
        if ex.get("is_gemini") and ex.get("has_token_log"):
            costs.append(ex["gemini_total"])
        elif ex.get("has_cost_log"):
            costs.append(ex["total_cost"])
    return costs


def render_insights_html(runs):
    items = []
    tests = [(r["execution"]["final_tests"], r) for r in runs if r["execution"].get("final_tests")]
    if tests:
        top_n, top_r = max(tests, key=lambda t: t[0])
        others = [n for n, rr in tests if rr["branch"] != top_r["branch"]]
        if others:
            lo, hi = min(others), max(others)
            other_str = f"{lo}" if lo == hi else f"{lo}–{hi}"
            items.append(
                f"{html.escape(top_r['harness'])} logged all 8 milestones with "
                f"{top_n} in-tree tests vs {other_str} on the other runs."
            )
    for r in runs:
        harness = html.escape(r["harness"])
        scenarios = r["perf"].get("scenarios", {})
        expected = ["deal-open", "cold-app", "nav-contacts"]
        missing = [s for s in expected if s not in scenarios]
        if missing and scenarios:
            present = ", ".join(html.escape(k) for k in scenarios)
            miss = " / ".join(html.escape(s) for s in missing)
            items.append(
                f"{harness} perf probe only recorded {present}; no {miss}."
            )
        a11y_screens = r["a11y"].get("screens", {})
        if a11y_screens and ("vue-app" not in a11y_screens or "deal-show" not in a11y_screens):
            items.append(
                f"{harness} accessibility audit did not include vue-app and/or deal-show."
            )
        if not r["execution"].get("has_token_log"):
            items.append(
                f"{harness} has no billed token or dollar log; "
                "context-window snapshots are not comparable to DeepSeek turn totals."
            )
        if run_has_held_out_failures(r):
            failed = ", ".join(r["score"]["failed_milestones"])
            items.append(
                f"{harness} held-out score.md marks {html.escape(failed)} failed "
                f"(Vue /app mount and Vue Kanban probes; {r['score']['pass']} pass / "
                f"{r['score']['fail']} fail / {r['score']['skip']} skip)."
            )
        notes = (r["execution"].get("notes") or "").strip()
        if notes:
            first = notes.splitlines()[0].strip()
            if first:
                items.append(f"{harness} notes: {html.escape(first)}")

    seen = set()
    uniq = []
    for item in items:
        if item not in seen:
            seen.add(item)
            uniq.append(item)
    if not uniq:
        return ""
    lis = "".join(f"<li>{item}</li>" for item in uniq)
    return f'''
    <section class="insight-panel">
      <div class="panel-title" style="margin-bottom: 12px;">Run insights</div>
      <ul>{lis}</ul>
    </section>'''


def render_token_run_section(r):
    ex = r["execution"]
    harness = html.escape(r["harness"])
    total = ex["total_turns"]
    cached = ex["total_cached"]
    uncached = ex["total_uncached"]
    output = ex["total_output"]
    reasoning = ex["total_reasoning"]
    denom = cached + uncached + output
    pct_c = (cached / denom * 100) if denom else 0
    pct_u = (uncached / denom * 100) if denom else 0
    pct_o = (output / denom * 100) if denom else 0
    cache_hit = ex.get("cache_hit_rate", 0.0)
    cost_str, cost_sub = run_cost_parts(r)

    m_names = {
        "M1": "M1 (Auth & Session)",
        "M2": "M2 (Contacts CRUD)",
        "M3": "M3 (Deals Engine)",
        "M4": "M4 (Kanban Pipeline)",
        "M5": "M5 (Activity Timeline)",
        "M6": "M6 (Todos & Notes)",
        "M7": "M7 (Vue Setup & SPA)",
        "M8": "M8 (Vue Kanban Integration)"
    }
    rows = []
    for m in ex.get("milestones", []):
        tot_in = m["uncached_tokens"] + m["cached_tokens"]
        m_hit_rate = f"{(m['cached_tokens'] / tot_in * 100):.1f}%" if tot_in > 0 else "—"
        rows.append(f'''
            <tr>
              <td style="font-weight: 600; color: var(--color-chalk);">{html.escape(m_names.get(m["milestone"], m["milestone"]))}</td>
              <td class="mono-cell">{m["turn_tokens"]:,}</td>
              <td class="mono-cell text-blue">{m["uncached_tokens"]:,}</td>
              <td class="mono-cell text-green">{m["cached_tokens"]:,}</td>
              <td class="mono-cell text-violet">{m["output_tokens"]:,}</td>
              <td class="mono-cell text-fog" style="font-size: 11px;">{m["reasoning_tokens"]:,}</td>
              <td class="mono-cell text-green">{m_hit_rate}</td>
              <td class="mono-cell">{html.escape(m["cost"])}</td>
              <td class="mono-cell text-green" style="font-weight: 600;">{html.escape(m["gemini_cost"])}</td>
            </tr>''')
    nocache = ex.get("gemini_nocache_total", 0)
    gem = ex.get("gemini_total", 0)
    savings_pct = "—"
    savings_amt = "—"
    if nocache > 0 and gem > 0 and nocache >= gem:
        savings_pct = f"{-((nocache - gem) / nocache * 100):.1f}%"
        savings_amt = f"${nocache - gem:.2f}"

    return f'''
        <div style="margin-bottom: 32px;">
          <div style="font-family: var(--font-mono); font-size: 12px; text-transform: uppercase; color: var(--color-silver); margin-bottom: 12px;">
            {harness} · {html.escape(ex.get("model_name", ""))}
          </div>
          <div class="cost-card-grid">
            <div class="cost-card">
              <div class="kpi-label">Reported run cost</div>
              <div class="kpi-value">{html.escape(cost_str)}</div>
              <div class="kpi-subtext">{html.escape(cost_sub)}</div>
            </div>
            <div class="cost-card">
              <div class="kpi-label">Turn tokens</div>
              <div class="kpi-value">{html.escape(ex.get("total_tokens_str", "—"))}</div>
              <div class="kpi-subtext">{cache_hit}% prompt cache hit rate</div>
            </div>
            <div class="cost-card">
              <div class="kpi-label">Gemini 3.8 Flash (est)</div>
              <div class="kpi-value">${gem:.2f}</div>
              <div class="kpi-subtext">With context caching; no-cache ${nocache:.2f}</div>
            </div>
            <div class="cost-card">
              <div class="kpi-label">Prompt cache savings (est)</div>
              <div class="kpi-value">{savings_pct}</div>
              <div class="kpi-subtext">Saved {savings_amt} vs no-cache Gemini estimate</div>
            </div>
          </div>
          <div style="background: var(--color-obsidian); border: 1px solid var(--color-basalt); border-radius: 6px; padding: 20px; margin-bottom: 16px;">
            <div style="display: flex; justify-content: space-between; align-items: center; margin-bottom: 8px;">
              <span class="mono-cell text-chalk" style="font-size: 13px; font-weight: 600;">Token distribution ({total:,} total)</span>
              <span class="tag">{cache_hit}% CACHE HIT</span>
            </div>
            <div class="token-dist-bar">
              <div class="token-dist-seg seg-cached" style="width: {pct_c:.2f}%;" title="Cached Input"></div>
              <div class="token-dist-seg seg-uncached" style="width: {pct_u:.2f}%;" title="Uncached Input"></div>
              <div class="token-dist-seg seg-output" style="width: {pct_o:.2f}%;" title="Output"></div>
            </div>
            <div class="token-legend">
              <div class="legend-item"><span class="legend-dot dot-cached"></span><span>Cached Input: <strong class="text-green">{cached:,}</strong></span></div>
              <div class="legend-item"><span class="legend-dot dot-uncached"></span><span>Uncached Input: <strong class="text-blue">{uncached:,}</strong></span></div>
              <div class="legend-item"><span class="legend-dot dot-output"></span><span>Output: <strong class="text-violet">{output:,}</strong></span></div>
              <div class="legend-item text-fog"><span>(Includes {reasoning:,} reasoning tokens)</span></div>
            </div>
          </div>
          <div class="table-responsive">
            <table class="depot-table">
              <thead>
                <tr>
                  <th>Milestone</th>
                  <th>Turn Tokens</th>
                  <th>Uncached Input</th>
                  <th>Cached Input</th>
                  <th>Output Tokens</th>
                  <th>Reasoning Tokens</th>
                  <th>Cache Hit %</th>
                  <th>Reported Cost</th>
                  <th>Gemini 3.8 Flash (Est)</th>
                </tr>
              </thead>
              <tbody>
                {"".join(rows)}
              </tbody>
              <tfoot>
                <tr style="background: var(--color-obsidian); font-weight: 600;">
                  <td class="text-chalk">TOTAL (M1–M8)</td>
                  <td class="mono-cell text-chalk">{total:,}</td>
                  <td class="mono-cell text-blue">{uncached:,}</td>
                  <td class="mono-cell text-green">{cached:,}</td>
                  <td class="mono-cell text-violet">{output:,}</td>
                  <td class="mono-cell text-fog">{reasoning:,}</td>
                  <td class="mono-cell text-green">{cache_hit}%</td>
                  <td class="mono-cell text-chalk">{html.escape(f"${ex['total_cost']:.2f}" if ex.get("has_cost_log") else "—")}</td>
                  <td class="mono-cell text-green">${gem:.2f}</td>
                </tr>
              </tfoot>
            </table>
          </div>
        </div>'''


def render_context_run_section(r):
    ex = r["execution"]
    harness = html.escape(r["harness"])
    rows = []
    for m in ex.get("milestones", []):
        rows.append(f'''
            <tr>
              <td style="font-weight: 600; color: var(--color-chalk);">{html.escape(m["milestone"])}</td>
              <td class="mono-cell">{html.escape(m.get("time") or "—")}</td>
              <td class="mono-cell">{html.escape(m.get("context_used") or "—")}</td>
              <td class="mono-cell">{m["tests_passed"] if m.get("tests_passed") is not None else "—"} passed</td>
            </tr>''')
    return f'''
        <div style="margin-bottom: 32px;">
          <div style="font-family: var(--font-mono); font-size: 12px; text-transform: uppercase; color: var(--color-silver); margin-bottom: 12px;">
            {harness} · {html.escape(ex.get("model_name", ""))} · no billed token log
          </div>
          <div class="cost-card-grid">
            <div class="cost-card">
              <div class="kpi-label">Reported run cost</div>
              <div class="kpi-value">—</div>
              <div class="kpi-subtext">Context-window snapshots only; omit rather than invent dollars</div>
            </div>
          </div>
          <div class="table-responsive">
            <table class="depot-table">
              <thead>
                <tr>
                  <th>Milestone</th>
                  <th>Time</th>
                  <th>Context window used</th>
                  <th>In-tree tests</th>
                </tr>
              </thead>
              <tbody>
                {"".join(rows)}
              </tbody>
            </table>
          </div>
        </div>'''


def render_cost_tab_inner(runs):
    parts = []
    token_runs = [r for r in runs if r["execution"].get("has_token_log")]
    context_runs = [
        r for r in runs
        if not r["execution"].get("has_token_log")
        and any(m.get("context_used") for m in r["execution"].get("milestones", []))
    ]
    other_runs = [
        r for r in runs
        if r not in token_runs and r not in context_runs
    ]
    for r in token_runs:
        parts.append(render_token_run_section(r))
    for r in context_runs:
        parts.append(render_context_run_section(r))
    for r in other_runs:
        harness = html.escape(r["harness"])
        parts.append(f'''
        <div class="cost-card" style="margin-bottom: 16px;">
          <div class="kpi-label">{harness}</div>
          <div class="kpi-value">—</div>
          <div class="kpi-subtext">No token or cost log on this branch</div>
        </div>''')
    parts.append('''
          <div class="formula-grid">
            <div class="formula-card">
              <div class="panel-title" style="margin-bottom: 12px; color: var(--color-chalk);">Google Gemini 3.8 Flash pricing (estimates only)</div>
              <ul style="list-style: none; display: flex; flex-direction: column; gap: 8px; font-size: 13px; color: var(--color-silver);">
                <li>&bull; <strong class="text-chalk">Uncached Input:</strong> <span class="mono-cell">$0.075</span> per 1M tokens</li>
                <li>&bull; <strong class="text-chalk">Context Caching Read:</strong> <span class="mono-cell">$0.01875</span> per 1M tokens (75% discount)</li>
                <li>&bull; <strong class="text-chalk">Output Tokens:</strong> <span class="mono-cell">$0.30</span> per 1M tokens</li>
                <li>&bull; <strong class="text-chalk">Formula:</strong> <code class="mono-cell text-fog">Cost = (Uncached / 1M &times; 0.075) + (Cached / 1M &times; 0.01875) + (Output / 1M &times; 0.30)</code></li>
              </ul>
            </div>
            <div class="formula-card">
              <div class="panel-title" style="margin-bottom: 12px; color: var(--color-chalk);">Why some runs look cheap at huge token volume</div>
              <p style="font-size: 13px; color: var(--color-silver); line-height: 1.6;">
                Harnesses that log billed turns often reuse a long conversation prefix. Cached input is billed at a discount, so tens of millions of tokens can still land near a couple of dollars.
                Runs that only snapshot context-window fill (used / limit) are <strong class="text-chalk">not</strong> the same unit and are shown as em dashes instead of a fake dollar total.
              </p>
            </div>
          </div>
    ''')
    return "".join(parts)


def render_scenario_bars_html(runs, scenario_id, is_key=False):
    out = []
    for r in runs:
        scenarios = r["perf"].get("scenarios", {})
        sc_info = scenarios.get(scenario_id, {})
        ready_str = sc_info.get("ready") or "—"
        ready_ms = sc_info.get("ready_ms")

        is_highlight = ready_ms is not None and ready_ms < 30
        green_cls = 'text-green' if is_highlight else ''
        bar_fill_cls = 'bar-fill' if is_highlight else 'bar-fill bar-fill-secondary'
        pct = min(100, int(ready_ms * 1.8)) if ready_ms is not None else 0

        harness_label = html.escape(r["harness"])
        out.append(f'''
        <div class="bar-row">
          <div class="bar-label">
            <span>{harness_label}</span>
            <span class="mono-cell {green_cls}">{ready_str}</span>
          </div>
          <div class="bar-track">
            <div class="{bar_fill_cls}" style="width: {pct}%;"></div>
          </div>
        </div>''')
    return "".join(out)


def render_html_page(runs, generated_at):
    """Generate a self-contained Depot Design System HTML dashboard."""
    runs_json = json.dumps(runs, indent=2)
    total_runs = len(runs)
    
    avg_ready = "—"
    valid_readys = [r["perf"]["mean_ready_ms"] for r in runs if r["perf"]["mean_ready_ms"]]
    if valid_readys:
        avg_ready = f"{round(sum(valid_readys) / len(valid_readys), 1)} ms"

    best_ready = min(valid_readys) if valid_readys else "—"
    if best_ready != "—":
        best_ready = f"{best_ready} ms"

    full_completed_count = sum(1 for r in runs if run_is_prd_complete(r))

    token_runs = [r for r in runs if r["execution"].get("has_token_log")]
    token_strs = []
    seen_tok = set()
    for r in token_runs:
        s = r["execution"].get("total_tokens_str", "—")
        if s not in seen_tok:
            seen_tok.add(s)
            token_strs.append(s)
    if not token_strs:
        benchmark_tokens_str = "—"
        tokens_sub = "No billed token logs"
    elif len(token_strs) == 1:
        benchmark_tokens_str = token_strs[0]
        tokens_sub = f"{len(token_runs)} run(s) with billed turn tokens"
    else:
        benchmark_tokens_str = " / ".join(token_strs)
        tokens_sub = "Billed turn tokens (not all runs)"

    billed_costs = billed_cost_values(runs)
    if not billed_costs:
        cost_range_str = "—"
        cost_subtext = "No billed or estimated costs logged"
    elif min(billed_costs) == max(billed_costs):
        cost_range_str = f"${min(billed_costs):.2f}"
        cost_subtext = "Runs with billed or estimated cost"
    else:
        cost_range_str = f"${min(billed_costs):.2f} – ${max(billed_costs):.2f}"
        cost_subtext = "Runs with billed or estimated cost"

    insights_html = render_insights_html(runs)
    cost_tab_inner = render_cost_tab_inner(runs)
    insights_html = insights_html.replace("{", "{{").replace("}", "}}")
    cost_tab_inner = cost_tab_inner.replace("{", "{{").replace("}", "}}")

    # Pre-render rows
    scorecard_rows = []
    for r in runs:
        title_esc = html.escape(r["title"])
        branch_esc = html.escape(r["branch"])
        score = r.get("score") or {}
        if run_has_held_out_failures(r):
            failed = ", ".join(score["failed_milestones"])
            comp_str = f"{score['held_out_passed']}/{score['held_out_total']}"
            comp_pct_str = f"held-out fail {failed}"
            comp_cls = "mono-cell"
        else:
            comp_str = f"{r['execution']['completed_milestones']}/{r['execution']['total_milestones']}"
            comp_pct_str = f"({r['execution']['completion_rate']}%)"
            comp_cls = "mono-cell text-green"

        tok_str = r["execution"].get("total_tokens_str", "—")
        cache_hit_pct = r["execution"].get("cache_hit_rate", 0.0)
        cache_sub = f"({cache_hit_pct}% cached)" if r["execution"].get("has_token_log") else ""

        cost_str, cost_sub = run_cost_parts(r)
        cost_str_esc = html.escape(cost_str)
        cost_sub_esc = html.escape(cost_sub)
        
        ready_cell = f"{r['perf']['mean_ready_ms']} ms" if r['perf']['mean_ready_ms'] else "—"
        ready_cls = "mono-cell"

        a11y_str = f"{r['a11y']['total_violations']} viols" if r['a11y'].get("screen_count") else "—"
        a11y_sub = f"({r['a11y']['total_affected_nodes']} nodes)" if r['a11y'].get("screen_count") else ""

        tests_str = f"{r['execution']['final_tests']} passed" if r['execution']['final_tests'] else "—"
        tests_sub = f"({r['git']['test_file_count']} files)"
        cov_str = f"{r['execution']['final_coverage']}%" if r['execution']['final_coverage'] else "—"
        badges_html = render_badges_html(r["badges"])

        scorecard_rows.append(f'''
        <tr data-name="{title_esc.lower()} {branch_esc.lower()}">
          <td>
            <div style="font-weight: 600; color: var(--color-chalk);">{title_esc}</div>
            <div class="mono-cell text-fog" style="font-size: 11px;">branch: {branch_esc}</div>
          </td>
          <td>
            <span class="{comp_cls}">{comp_str}</span>
            <span class="mono-cell text-fog" style="font-size: 11px;">{comp_pct_str}</span>
          </td>
          <td class="mono-cell">
            <span>{tok_str}</span>
            <div class="text-fog" style="font-size: 11px;">{cache_sub}</div>
          </td>
          <td class="mono-cell text-green" style="font-weight: 600;">
            <span>{cost_str_esc}</span>
            <div class="text-fog" style="font-size: 11px; font-weight: 400;">{cost_sub_esc}</div>
          </td>
          <td class="{ready_cls}" style="font-size: 14px; font-weight: 500;">{ready_cell}</td>
          <td class="mono-cell">
            <span>{a11y_str}</span>
            <span class="text-fog" style="font-size: 11px;">{a11y_sub}</span>
          </td>
          <td class="mono-cell">
            <span>{tests_str}</span>
            <span class="text-fog" style="font-size: 11px;">{tests_sub}</span>
          </td>
          <td class="mono-cell"><span>{cov_str}</span></td>
          <td><div style="display: flex; flex-wrap: wrap; gap: 4px;">{badges_html}</div></td>
        </tr>''')

    # A11y rows
    a11y_rows = []
    for r in runs:
        harness_esc = html.escape(r["harness"])
        screens = r["a11y"].get("screens", {})
        clean_cell = f"{r['a11y']['clean_screens']}/{r['a11y']['screen_count']} ({r['a11y']['clean_percentage']}%)" if r['a11y']['screen_count'] else "—"
        deal_show_rules = html.escape(screens["deal-show"]["rules"]) if "deal-show" in screens else "—"
        def viol_td(name):
            val = screen_violation_cell(screens, name)
            cls = "text-green" if val == "0" else ""
            return f'<td class="mono-cell {cls}">{val}</td>'

        a11y_rows.append(f'''
        <tr>
          <td style="font-weight: 600; color: var(--color-chalk);">{harness_esc}</td>
          <td class="mono-cell text-green">{clean_cell}</td>
          {viol_td("register")}
          {viol_td("login")}
          {viol_td("pipeline")}
          {viol_td("contacts")}
          {viol_td("todos")}
          {viol_td("vue-app")}
          {viol_td("deal-show")}
          <td class="mono-cell text-fog" style="font-size: 11px;">{deal_show_rules}</td>
        </tr>''')

    # Milestone progression rows
    milestone_rows = []
    for r in runs:
        harness_esc = html.escape(r["harness"])
        m_list = r["execution"].get("milestones", [])
        m_dict = {m["milestone"]: m for m in m_list}
        
        score_ms = (r.get("score") or {}).get("milestones") or {}

        def m_test_str(m_id):
            m_item = m_dict.get(m_id)
            in_tree = f"{m_item['tests_passed']} passed" if (m_item and m_item['tests_passed']) else "—"
            ho = score_ms.get(m_id)
            if ho == "fail":
                return f"{in_tree} · held-out fail"
            return in_tree

        def m_td(m_id, extra_cls=""):
            ho = score_ms.get(m_id)
            cls = extra_cls
            if ho == "fail":
                cls = ""
            return f'<td class="mono-cell {cls}">{m_test_str(m_id)}</td>'

        cov_str = f"{r['execution']['final_coverage']}%" if r['execution']['final_coverage'] else "—"
        m8_cls = "text-green" if score_ms.get("M8") != "fail" else ""
        style8 = ' style="font-weight: 600;"' if score_ms.get("M8") != "fail" else ""

        milestone_rows.append(f'''
        <tr>
          <td style="font-weight: 600; color: var(--color-chalk);">{harness_esc}</td>
          {m_td("M1")}
          {m_td("M2")}
          {m_td("M3")}
          {m_td("M4")}
          {m_td("M5")}
          {m_td("M6")}
          {m_td("M7")}
          <td class="mono-cell {m8_cls}"{style8}>{m_test_str("M8")}</td>
          <td class="mono-cell">{cov_str}</td>
        </tr>''')

    # Provenance rows
    provenance_rows = []
    for r in runs:
        branch_esc = html.escape(r["branch"])
        commit_h = r["git"].get("commit_hash", "—")
        author_esc = html.escape(r["git"].get("author", "—"))
        date_esc = html.escape(r["git"].get("commit_date", "—")[:10])
        files_cnt = r["git"].get("test_file_count", 0)
        arch_badge = '<span class="tag tag-blue">Phoenix 1.8 Scoped (Modern)</span>' if r["git"]["has_phx_18_scope"] else '<span class="tag tag-neutral">Phoenix 1.7 Controller Plugs</span>'

        provenance_rows.append(f'''
        <tr>
          <td><span class="mono-cell text-chalk" style="font-weight: 600;">{branch_esc}</span></td>
          <td class="mono-cell text-fog"><code>{commit_h}</code></td>
          <td>{author_esc}</td>
          <td class="mono-cell text-fog" style="font-size: 11px;">{date_esc}</td>
          <td class="mono-cell text-chalk">{files_cnt} files</td>
          <td>{arch_badge}</td>
        </tr>''')

    # Scenario blocks
    deal_open_bars = render_scenario_bars_html(runs, "deal-open", is_key=True)
    cold_app_bars = render_scenario_bars_html(runs, "cold-app")
    cold_home_bars = render_scenario_bars_html(runs, "cold-home")
    nav_contacts_bars = render_scenario_bars_html(runs, "nav-contacts")

    scorecard_tbody = "\n".join(scorecard_rows)
    a11y_tbody = "\n".join(a11y_rows)
    milestones_tbody = "\n".join(milestone_rows)
    provenance_tbody = "\n".join(provenance_rows)

    return f"""<!DOCTYPE html>
<html lang="en" class="dark">
<head>
  <meta charset="UTF-8">
  <meta name="viewport" content="width=device-width, initial-scale=1.0">
  <title>Evalcode // Coding Agent Benchmark</title>
  <link rel="preconnect" href="https://fonts.googleapis.com">
  <link rel="preconnect" href="https://fonts.gstatic.com" crossorigin>
  <link href="https://fonts.googleapis.com/css2?family=Red+Hat+Display:wght@600;700&family=Red+Hat+Mono:wght@400;500&family=Red+Hat+Text:wght@400;500;600&display=swap" rel="stylesheet">
  <style>
    :root {{
      --color-carbon: #04040b;
      --color-graphite: #121113;
      --color-obsidian: #1a191b;
      --color-slate: #232225;
      --color-basalt: #2b292d;
      --color-iron: #323035;
      --color-pewter: #3c393f;
      --color-steel: #49474e;
      --color-fog: #7c7a85;
      --color-silver: #b5b2bc;
      --color-ash: #eeeef0;
      --color-chalk: #e5e5e5;
      --color-signal-green: #71d083;
      --color-led-green: #366740;
      --color-moss-border: #2d5736;
      --color-forest-wash: #1d3a24;
      --color-fern-ground: #1b2a1e;
      --color-link-blue: #70b8ff;
      --color-lilac-accent: #baa7ff;
      --color-plum-edge: #291f43;
      --font-display: 'Red Hat Display', -apple-system, BlinkMacSystemFont, sans-serif;
      --font-text: 'Red Hat Text', -apple-system, BlinkMacSystemFont, sans-serif;
      --font-mono: 'Red Hat Mono', monospace;
      --shadow-subtle: rgba(255, 255, 255, 0.06) 0px 1px 0px 0px inset;
    }}

    * {{
      box-sizing: border-box;
      margin: 0;
      padding: 0;
    }}

    body {{
      background-color: var(--color-carbon);
      color: var(--color-ash);
      font-family: var(--font-text);
      letter-spacing: 0.025em;
      line-height: 1.5;
      -webkit-font-smoothing: antialiased;
      padding-bottom: 80px;
    }}

    .top-banner {{
      width: 100%;
      background: var(--color-carbon);
      border-bottom: 1px solid var(--color-moss-border);
      padding: 8px 16px;
      text-align: center;
      font-size: 13px;
      color: var(--color-ash);
    }}
    .top-banner a {{
      color: var(--color-link-blue);
      text-decoration: none;
      margin-left: 6px;
    }}
    .top-banner a:hover {{
      text-decoration: underline;
    }}

    header.depot-nav {{
      position: sticky;
      top: 0;
      z-index: 40;
      background: rgba(4, 4, 11, 0.92);
      backdrop-filter: blur(8px);
      border-bottom: 1px solid var(--color-basalt);
      padding: 14px 24px;
    }}
    .nav-inner {{
      max-width: 1200px;
      margin: 0 auto;
      display: flex;
      align-items: center;
      justify-content: space-between;
    }}
    .brand-group {{
      display: flex;
      align-items: center;
      gap: 12px;
    }}
    .brand-logo {{
      font-family: var(--font-display);
      font-weight: 700;
      letter-spacing: -0.025em;
      font-size: 18px;
      color: var(--color-chalk);
      text-decoration: none;
      display: flex;
      align-items: center;
      gap: 8px;
    }}
    .led-dot {{
      width: 8px;
      height: 8px;
      border-radius: 50%;
      background: var(--color-signal-green);
      box-shadow: 0 0 6px rgba(113, 208, 131, 0.4);
    }}
    .tag {{
      display: inline-flex;
      align-items: center;
      padding: 2px 8px;
      font-family: var(--font-mono);
      font-size: 11px;
      text-transform: uppercase;
      letter-spacing: 0.025em;
      border-radius: 2px;
      border: 1px solid var(--color-moss-border);
      background: var(--color-fern-ground);
      color: var(--color-signal-green);
    }}
    .tag-blue {{
      border-color: #2b3d54;
      background: #101c2a;
      color: var(--color-link-blue);
    }}
    .tag-violet {{
      border-color: var(--color-plum-edge);
      background: #181324;
      color: var(--color-lilac-accent);
    }}
    .tag-neutral {{
      border-color: var(--color-basalt);
      background: var(--color-obsidian);
      color: var(--color-silver);
    }}

    .container {{
      max-width: 1200px;
      margin: 0 auto;
      padding: 40px 24px;
    }}

    .hero {{
      margin-bottom: 36px;
    }}
    .hero-eyebrow {{
      font-family: var(--font-mono);
      font-size: 12px;
      color: var(--color-signal-green);
      text-transform: uppercase;
      letter-spacing: 0.05em;
      margin-bottom: 8px;
    }}
    .hero h1 {{
      font-family: var(--font-display);
      font-size: 38px;
      font-weight: 700;
      letter-spacing: -0.025em;
      color: var(--color-chalk);
      line-height: 1.15;
    }}
    .hero p {{
      color: var(--color-silver);
      font-size: 16px;
      margin-top: 12px;
      max-width: 780px;
    }}

    .kpi-grid {{
      display: grid;
      grid-template-columns: repeat(auto-fit, minmax(180px, 1fr));
      gap: 16px;
      margin-bottom: 32px;
    }}
    .kpi-card {{
      background: var(--color-graphite);
      border: 1px solid var(--color-basalt);
      border-radius: 6px;
      padding: 20px;
      box-shadow: var(--shadow-subtle);
    }}
    .kpi-label {{
      font-family: var(--font-mono);
      font-size: 11px;
      text-transform: uppercase;
      color: var(--color-fog);
      letter-spacing: 0.05em;
    }}
    .kpi-value {{
      font-family: var(--font-mono);
      font-size: 26px;
      font-weight: 500;
      color: var(--color-chalk);
      margin-top: 6px;
    }}
    .kpi-subtext {{
      font-size: 12px;
      color: var(--color-silver);
      margin-top: 4px;
    }}

    .tabs-bar {{
      display: flex;
      align-items: center;
      gap: 8px;
      border-bottom: 1px solid var(--color-basalt);
      margin-bottom: 24px;
      overflow-x: auto;
      scrollbar-width: none;
      -ms-overflow-style: none;
    }}
    .tabs-bar::-webkit-scrollbar {{
      display: none;
    }}
    @media (min-width: 768px) {{
      .tabs-bar {{
        overflow-x: visible;
      }}
    }}
    .tab-button {{
      background: none;
      border: none;
      outline: none;
      color: var(--color-fog);
      font-family: var(--font-text);
      font-size: 14px;
      font-weight: 500;
      letter-spacing: 0.025em;
      padding: 10px 16px;
      cursor: pointer;
      position: relative;
      white-space: nowrap;
      transition: color 0.15s;
      border-bottom: 2px solid transparent;
      margin-bottom: -1px;
    }}
    .tab-button:hover {{
      color: var(--color-ash);
    }}
    .tab-button.active {{
      color: var(--color-chalk);
      font-weight: 600;
      border-bottom-color: var(--color-signal-green);
    }}

    .filter-bar {{
      display: flex;
      flex-wrap: wrap;
      align-items: center;
      justify-content: space-between;
      gap: 16px;
      margin-bottom: 16px;
    }}
    .search-input {{
      background: var(--color-obsidian);
      border: 1px solid var(--color-basalt);
      border-radius: 6px;
      padding: 8px 14px;
      color: var(--color-ash);
      font-family: var(--font-text);
      font-size: 13px;
      min-width: 260px;
      outline: none;
    }}
    .search-input:focus {{
      border-color: var(--color-pewter);
    }}
    .filter-meta {{
      font-family: var(--font-mono);
      font-size: 12px;
      color: var(--color-fog);
    }}

    .panel {{
      background: var(--color-graphite);
      border: 1px solid var(--color-basalt);
      border-radius: 6px;
      box-shadow: var(--shadow-subtle);
      overflow: hidden;
      margin-bottom: 32px;
    }}
    .panel-header {{
      background: var(--color-obsidian);
      border-bottom: 1px solid var(--color-basalt);
      padding: 12px 20px;
      display: flex;
      align-items: center;
      justify-content: space-between;
    }}
    .panel-title {{
      font-family: var(--font-mono);
      font-size: 12px;
      text-transform: uppercase;
      letter-spacing: 0.05em;
      color: var(--color-silver);
    }}

    .table-responsive {{
      width: 100%;
      overflow-x: auto;
    }}
    table.depot-table {{
      width: 100%;
      border-collapse: collapse;
      text-align: left;
      font-size: 13px;
    }}
    table.depot-table th {{
      background: var(--color-obsidian);
      color: var(--color-fog);
      font-family: var(--font-mono);
      font-size: 11px;
      text-transform: uppercase;
      letter-spacing: 0.05em;
      padding: 12px 18px;
      border-bottom: 1px solid var(--color-basalt);
      cursor: pointer;
      user-select: none;
    }}
    table.depot-table th:hover {{
      color: var(--color-chalk);
    }}
    table.depot-table td {{
      padding: 16px 18px;
      border-bottom: 1px solid var(--color-basalt);
      vertical-align: middle;
    }}
    table.depot-table tr:last-child td {{
      border-bottom: none;
    }}
    table.depot-table tr:hover td {{
      background: rgba(255, 255, 255, 0.015);
    }}

    .mono-cell {{
      font-family: var(--font-mono);
    }}
    .text-green {{
      color: var(--color-signal-green);
    }}
    .text-blue {{
      color: var(--color-link-blue);
    }}
    .text-violet {{
      color: var(--color-lilac-accent);
    }}
    .text-fog {{
      color: var(--color-fog);
    }}

    .scenario-grid {{
      display: grid;
      grid-template-columns: repeat(auto-fit, minmax(260px, 1fr));
      gap: 16px;
      padding: 20px;
    }}
    .scenario-card {{
      background: var(--color-obsidian);
      border: 1px solid var(--color-basalt);
      border-radius: 6px;
      padding: 16px;
    }}
    .scenario-title {{
      font-family: var(--font-mono);
      font-size: 13px;
      color: var(--color-chalk);
      display: flex;
      align-items: center;
      justify-content: space-between;
      margin-bottom: 12px;
    }}
    .bar-row {{
      display: flex;
      flex-direction: column;
      gap: 6px;
      margin-bottom: 12px;
    }}
    .bar-label {{
      font-size: 12px;
      color: var(--color-silver);
      display: flex;
      justify-content: space-between;
    }}
    .bar-track {{
      width: 100%;
      height: 8px;
      background: var(--color-slate);
      border-radius: 2px;
      overflow: hidden;
    }}
    .bar-fill {{
      height: 100%;
      background: var(--color-signal-green);
      border-radius: 2px;
    }}
    .bar-fill-secondary {{
      background: var(--color-steel);
    }}

    .btn-outline {{
      display: inline-flex;
      align-items: center;
      gap: 8px;
      background: transparent;
      border: 1px solid var(--color-basalt);
      border-radius: 6px;
      padding: 8px 16px;
      color: var(--color-ash);
      font-size: 13px;
      font-family: var(--font-text);
      text-decoration: none;
      cursor: pointer;
      transition: all 0.15s;
    }}
    .btn-outline:hover {{
      border-color: var(--color-pewter);
      background: var(--color-obsidian);
    }}

    .tab-content {{
      display: none;
    }}
    .tab-content.active {{
      display: block;
    }}

    .cost-card-grid {{
      display: grid;
      grid-template-columns: repeat(auto-fit, minmax(240px, 1fr));
      gap: 16px;
      margin-bottom: 24px;
    }}
    .cost-card {{
      background: var(--color-graphite);
      border: 1px solid var(--color-basalt);
      border-radius: 6px;
      padding: 20px;
      box-shadow: var(--shadow-subtle);
    }}
    .token-dist-bar {{
      width: 100%;
      height: 16px;
      background: var(--color-slate);
      border-radius: 4px;
      overflow: hidden;
      display: flex;
      margin: 16px 0;
      border: 1px solid var(--color-basalt);
    }}
    .token-dist-seg {{
      height: 100%;
    }}
    .seg-cached {{
      background: var(--color-signal-green);
    }}
    .seg-uncached {{
      background: var(--color-link-blue);
    }}
    .seg-output {{
      background: var(--color-lilac-accent);
    }}
    .token-legend {{
      display: flex;
      flex-wrap: wrap;
      gap: 20px;
      font-size: 12px;
      margin-top: 12px;
      font-family: var(--font-mono);
    }}
    .legend-item {{
      display: flex;
      align-items: center;
      gap: 8px;
    }}
    .legend-dot {{
      width: 10px;
      height: 10px;
      border-radius: 2px;
    }}
    .dot-cached {{
      background: var(--color-signal-green);
    }}
    .dot-uncached {{
      background: var(--color-link-blue);
    }}
    .dot-output {{
      background: var(--color-lilac-accent);
    }}
    .formula-grid {{
      display: grid;
      grid-template-columns: repeat(auto-fit, minmax(320px, 1fr));
      gap: 16px;
      margin-top: 24px;
    }}
    .formula-card {{
      background: var(--color-obsidian);
      border: 1px solid var(--color-basalt);
      border-radius: 6px;
      padding: 20px;
    }}

    .insight-panel {{
      background: var(--color-obsidian);
      border: 1px solid var(--color-basalt);
      border-radius: 6px;
      padding: 20px 24px;
      margin-bottom: 32px;
      box-shadow: var(--shadow-subtle);
    }}
    .insight-panel ul {{
      list-style: none;
      display: flex;
      flex-direction: column;
      gap: 10px;
      font-size: 14px;
      color: var(--color-silver);
      letter-spacing: 0.025em;
    }}
    .insight-panel li {{
      padding-left: 14px;
      border-left: 1px solid var(--color-basalt);
    }}
      max-width: 1200px;
      margin: 40px auto 0;
      padding: 24px;
      border-top: 1px solid var(--color-basalt);
      display: flex;
      flex-wrap: wrap;
      align-items: center;
      justify-content: space-between;
      color: var(--color-fog);
      font-size: 12px;
      font-family: var(--font-mono);
    }}
  </style>
</head>
<body>

  <aside class="top-banner">
    <span>✨ Continuous benchmark evaluation registry across autonomous coding agent branches</span>
    <a href="https://github.com/rizafahmi/evalcode" target="_blank" rel="noreferrer">View Repository on GitHub &rarr;</a>
  </aside>

  <header class="depot-nav">
    <div class="nav-inner">
      <div class="brand-group">
        <a href="#" class="brand-logo">
          <span class="led-dot"></span> Evalcode
        </a>
        <span class="tag">BENCHMARK</span>
      </div>
      <div>
        <a href="data/runs.json" class="btn-outline" download>
          <svg width="14" height="14" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2"><path d="M21 15v4a2 2 0 0 1-2 2H5a2 2 0 0 1-2-2v-4"/><polyline points="7 10 12 15 17 10"/><line x1="12" y1="15" x2="12" y2="3"/></svg>
          Export runs.json
        </a>
      </div>
    </div>
  </header>

  <main class="container">
    
    <section class="hero">
      <div class="hero-eyebrow">Autonomous Coding Agent Benchmark</div>
      <h1>Personal Benchmark Results</h1>
      <p>
        Evaluating AI coding agents on full-stack Phoenix 1.8 + Vue 3 CRM synthesis across 8 milestones (M1–M8).
        Every row represents an isolated autonomous run with measured UI latency, accessibility audits, and test coverage.
      </p>
    </section>

    <section class="kpi-grid">
      <div class="kpi-card">
        <div class="kpi-label">Discovered Agent Runs</div>
        <div class="kpi-value">{total_runs}</div>
        <div class="kpi-subtext">Dynamic git branches scanned</div>
      </div>
      <div class="kpi-card">
        <div class="kpi-label">Billed Turn Tokens</div>
        <div class="kpi-value">{benchmark_tokens_str}</div>
        <div class="kpi-subtext">{tokens_sub}</div>
      </div>
      <div class="kpi-card">
        <div class="kpi-label">Logged Run Cost</div>
        <div class="kpi-value text-green">{cost_range_str}</div>
        <div class="kpi-subtext">{cost_subtext}</div>
      </div>
      <div class="kpi-card">
        <div class="kpi-label">Lowest Mean Ready</div>
        <div class="kpi-value text-green">{best_ready}</div>
        <div class="kpi-subtext">Among runs with UI probes</div>
      </div>
      <div class="kpi-card">
        <div class="kpi-label">Average Ready Latency</div>
        <div class="kpi-value">{avg_ready}</div>
        <div class="kpi-subtext">Across all probe scenarios</div>
      </div>
      <div class="kpi-card">
        <div class="kpi-label">100% PRD Completion</div>
        <div class="kpi-value">{full_completed_count} / {total_runs}</div>
        <div class="kpi-subtext">Held-out complete (no score.md failures)</div>
      </div>
    </section>

    {insights_html}

    <nav class="tabs-bar">
      <button class="tab-button active" onclick="switchTab('overview', this)">Overview Matrix</button>
      <button class="tab-button" onclick="switchTab('cost', this)">Tokens &amp; Cost</button>
      <button class="tab-button" onclick="switchTab('perf', this)">Performance Arena</button>
      <button class="tab-button" onclick="switchTab('a11y', this)">Accessibility Matrix</button>
      <button class="tab-button" onclick="switchTab('milestones', this)">Milestone Progression</button>
      <button class="tab-button" onclick="switchTab('provenance', this)">Branch Provenance</button>
    </nav>

    <div class="filter-bar">
      <input type="text" id="agentFilter" class="search-input" placeholder="Search by agent, model, or branch..." oninput="filterTable()">
      <div class="filter-meta">Auto-updated: {generated_at} UTC</div>
    </div>

    <!-- TAB 1: OVERVIEW MATRIX -->
    <div id="tab-overview" class="tab-content active">
      <div class="panel">
        <div class="panel-header">
          <span class="panel-title">Agent Evaluation &amp; Resource Metrics</span>
          <span class="font-mono text-xs text-fog">Click headers to sort</span>
        </div>
        <div class="table-responsive">
          <table class="depot-table" id="leaderboardTable">
            <thead>
              <tr>
                <th onclick="sortTable(0)">Agent / Model</th>
                <th onclick="sortTable(1)">PRD / Held-out</th>
                <th onclick="sortTable(2)">Tokens</th>
                <th onclick="sortTable(3)">Cost</th>
                <th onclick="sortTable(4)">Mean Ready (ms)</th>
                <th onclick="sortTable(5)">A11y Violations</th>
                <th onclick="sortTable(6)">Tests (Passed)</th>
                <th onclick="sortTable(7)">Coverage</th>
                <th>Tags</th>
              </tr>
            </thead>
            <tbody>
              {scorecard_tbody}
            </tbody>
          </table>
        </div>
      </div>
    </div>

    <!-- TAB 2: TOKENS & COST ARENA -->
    <div id="tab-cost" class="tab-content">
      <div class="panel">
        <div class="panel-header">
          <span class="panel-title">End-to-End Token Utilization &amp; Model Cost Estimation</span>
          <span class="font-mono text-xs text-fog">Per-run logs only &mdash; missing values are em dashes</span>
        </div>
        
        <div style="padding: 24px;">
          {cost_tab_inner}
        </div>
      </div>
    </div>

    <!-- TAB 3: PERFORMANCE ARENA -->
    <div id="tab-perf" class="tab-content">
      <div class="panel">
        <div class="panel-header">
          <span class="panel-title">End-User UI Latency Probes (Median Time to Ready Locator)</span>
          <span class="font-mono text-xs text-fog">Playwright measured</span>
        </div>
        <div class="scenario-grid">
          <div class="scenario-card">
            <div class="scenario-title">
              <span>deal-open (Drawer)</span>
              <span class="tag">KEY SIGNAL</span>
            </div>
            {deal_open_bars}
          </div>

          <div class="scenario-card">
            <div class="scenario-title">
              <span>cold-app (Vue Mount)</span>
              <span class="mono-cell text-fog text-xs">/app</span>
            </div>
            {cold_app_bars}
          </div>

          <div class="scenario-card">
            <div class="scenario-title">
              <span>cold-home (LiveView)</span>
              <span class="mono-cell text-fog text-xs">/</span>
            </div>
            {cold_home_bars}
          </div>

          <div class="scenario-card">
            <div class="scenario-title">
              <span>nav-contacts (LiveNav)</span>
              <span class="mono-cell text-fog text-xs">/contacts</span>
            </div>
            {nav_contacts_bars}
          </div>
        </div>
      </div>
    </div>

    <!-- TAB 3: ACCESSIBILITY MATRIX -->
    <div id="tab-a11y" class="tab-content">
      <div class="panel">
        <div class="panel-header">
          <span class="panel-title">Axe-Core WCAG 2.2 AA Audited Screens</span>
          <span class="font-mono text-xs text-fog">Lower violations is better</span>
        </div>
        <div class="table-responsive">
          <table class="depot-table">
            <thead>
              <tr>
                <th>Agent Run</th>
                <th>Clean Screens</th>
                <th>register</th>
                <th>login</th>
                <th>pipeline</th>
                <th>contacts</th>
                <th>todos</th>
                <th>vue-app</th>
                <th>deal-show</th>
                <th>Rules Triggered</th>
              </tr>
            </thead>
            <tbody>
              {a11y_tbody}
            </tbody>
          </table>
        </div>
      </div>
    </div>

    <!-- TAB 4: MILESTONE PROGRESSION -->
    <div id="tab-milestones" class="tab-content">
      <div class="panel">
        <div class="panel-header">
          <span class="panel-title">Milestone tests (in-tree) and held-out score.md</span>
          <span class="font-mono text-xs text-fog">Continuous verification</span>
        </div>
        <div class="table-responsive">
          <table class="depot-table">
            <thead>
              <tr>
                <th>Agent Run</th>
                <th>M1 (Auth)</th>
                <th>M2 (Contacts)</th>
                <th>M3 (Deals)</th>
                <th>M4 (Kanban)</th>
                <th>M5 (Activity)</th>
                <th>M6 (Todos)</th>
                <th>M7 (Vue setup)</th>
                <th>M8 (Vue Board)</th>
                <th>Final Coverage</th>
              </tr>
            </thead>
            <tbody>
              {milestones_tbody}
            </tbody>
          </table>
        </div>
      </div>
    </div>

    <!-- TAB 5: BRANCH PROVENANCE -->
    <div id="tab-provenance" class="tab-content">
      <div class="panel">
        <div class="panel-header">
          <span class="panel-title">Git Branch Provenance &amp; Implementation Artifacts</span>
          <span class="font-mono text-xs text-fog">Reproducible benchmark audit</span>
        </div>
        <div class="table-responsive">
          <table class="depot-table">
            <thead>
              <tr>
                <th>Branch</th>
                <th>Commit</th>
                <th>Author</th>
                <th>Date</th>
                <th>Test Files</th>
                <th>Architecture Pattern</th>
              </tr>
            </thead>
            <tbody>
              {provenance_tbody}
            </tbody>
          </table>
        </div>
      </div>
    </div>

  </main>

  <footer>
    <div>Evalcode Benchmark &bull; Built with Depot developer-console aesthetic</div>
    <div>Static deployment via GitHub Actions &bull; {generated_at} UTC</div>
  </footer>

  <script>
    const RUNS_DATA = {runs_json};

    function switchTab(tabId, el) {{
      document.querySelectorAll('.tab-content').forEach(tc => tc.classList.remove('active'));
      document.querySelectorAll('.tab-button').forEach(tb => tb.classList.remove('active'));
      
      const target = document.getElementById('tab-' + tabId);
      if (target) target.classList.add('active');
      if (el) el.classList.add('active');
    }}

    function filterTable() {{
      const query = document.getElementById('agentFilter').value.toLowerCase();
      const rows = document.querySelectorAll('#leaderboardTable tbody tr');
      rows.forEach(row => {{
        const searchKey = row.getAttribute('data-name') || '';
        if (searchKey.includes(query)) {{
          row.style.display = '';
        }} else {{
          row.style.display = 'none';
        }}
      }});
    }}

    let sortAsc = true;
    function sortTable(colIndex) {{
      const table = document.getElementById('leaderboardTable');
      const tbody = table.querySelector('tbody');
      const rows = Array.from(tbody.querySelectorAll('tr'));

      rows.sort((a, b) => {{
        const aVal = a.children[colIndex].innerText.trim();
        const bVal = b.children[colIndex].innerText.trim();
        const aNum = parseFloat(aVal.replace(/[^0-9.-]/g, ''));
        const bNum = parseFloat(bVal.replace(/[^0-9.-]/g, ''));

        if (!isNaN(aNum) && !isNaN(bNum)) {{
          return sortAsc ? aNum - bNum : bNum - aNum;
        }}
        return sortAsc ? aVal.localeCompare(bVal) : bVal.localeCompare(aVal);
      }});

      sortAsc = !sortAsc;
      rows.forEach(r => tbody.appendChild(r));
    }}
  </script>
</body>
</html>
"""


def main():
    parser = argparse.ArgumentParser(description="Build Evalcode Leaderboard for GitHub Pages")
    parser.add_argument("--output-dir", default="_site", help="Destination folder for static site files")
    parser.add_argument("--repo-root", default=".", help="Root directory of the git repository")
    parser.add_argument("--include-all", action="store_true", help="Include all evalcode_* branches even if reports are missing")
    args = parser.parse_args()

    repo_root = Path(args.repo_root).resolve()
    output_dir = Path(args.output_dir).resolve()
    data_dir = output_dir / "data"

    print(f"[*] Scanning git repository at: {repo_root}")
    branches = discover_evaluation_branches(cwd=repo_root, include_all_evalcode=args.include_all)
    print(f"[*] Found {len(branches)} candidate benchmark branch(es): {[b['name'] for b in branches]}")

    runs = []
    for b in branches:
        print(f"    - Processing {b['name']} (ref: {b['ref']})...")
        run_data = collect_branch_data(b, cwd=repo_root)
        runs.append(run_data)

    runs = compute_ranks_and_badges(runs)
    print(f"[*] Aggregated {len(runs)} benchmark runs")

    output_dir.mkdir(parents=True, exist_ok=True)
    data_dir.mkdir(parents=True, exist_ok=True)

    runs_json_path = data_dir / "runs.json"
    with open(runs_json_path, "w", encoding="utf-8") as f:
        json.dump(runs, f, indent=2)
    print(f"[*] Wrote JSON data to: {runs_json_path}")

    nojekyll_path = output_dir / ".nojekyll"
    nojekyll_path.touch()

    generated_at = datetime.datetime.now(datetime.timezone.utc).strftime("%Y-%m-%d %H:%M:%S")
    html_content = render_html_page(runs, generated_at)
    index_path = output_dir / "index.html"
    with open(index_path, "w", encoding="utf-8") as f:
        f.write(html_content)
    print(f"[*] Wrote static HTML dashboard to: {index_path}")
    print("[*] Leaderboard build completed successfully!")


if __name__ == "__main__":
    main()
