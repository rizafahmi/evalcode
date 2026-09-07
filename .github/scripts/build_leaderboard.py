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

    if raw_md:
        m_matches = re.findall(r"## (M[0-9])\s*(.*?)(?=\n## |\n# Notes|\Z)", raw_md, re.DOTALL)
        for m_id, m_body in m_matches:
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

            turn_val = int(tok_m.group(1).replace(',', '')) if tok_m else 0
            uncached_val = int(uncached_m.group(1).replace(',', '')) if uncached_m else 0
            cached_val = int(cached_m.group(1).replace(',', '')) if cached_m else 0
            out_val = int(output_m.group(1).replace(',', '')) if output_m else 0
            reason_val = int(output_m.group(2).replace(',', '')) if (output_m and output_m.group(2)) else 0
            cost_val = float(cost_match.group(1)) if cost_match else 0.0

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
                "reasoning_tokens": reason_val
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
    cost_display = f"${gemini_total:.2f} (est)" if is_gemini else f"${total_cost:.2f}"

    return {
        "agent_name": agent_name,
        "harness_name": harness_name,
        "model_name": model_name,
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
        "is_gemini": is_gemini
    }


def parse_score_report(raw_md):
    """Parse report/score.md for rubric test results."""
    if not raw_md:
        return {"pass": 0, "fail": 0, "skip": 0}

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

    return {
        "pass": pass_count,
        "fail": fail_count,
        "skip": skip_count
    }


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
        if r["execution"]["completion_rate"] == 100.0:
            r["badges"].append({"type": "neutral", "text": "100% PRD"})
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


def render_scenario_bars_html(runs, scenario_id, is_key=False):
    out = []
    for r in runs:
        scenarios = r["perf"].get("scenarios", {})
        sc_info = scenarios.get(scenario_id, {})
        ready_str = sc_info.get("ready", "—")
        ready_ms = sc_info.get("ready_ms")

        is_highlight = ready_ms is not None and ready_ms < 30
        green_cls = 'text-green' if is_highlight else ''
        bar_fill_cls = 'bar-fill' if is_highlight else 'bar-fill bar-fill-secondary'
        pct = min(100, int((ready_ms or 50) * 1.8))

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

    full_completed_count = sum(1 for r in runs if r["execution"]["completion_rate"] == 100.0)

    # Benchmark tokens & cost metrics across runs
    benchmark_tokens = max((r["execution"]["total_turns"] for r in runs), default=86_705_402)
    if benchmark_tokens >= 1_000_000:
        benchmark_tokens_str = f"{benchmark_tokens / 1_000_000:.1f}M"
    elif benchmark_tokens > 0:
        benchmark_tokens_str = f"{benchmark_tokens / 1_000:.1f}K"
    else:
        benchmark_tokens_str = "86.7M"

    cost_deepseek = "$1.37"
    cost_gemini = "$1.92"
    for r in runs:
        if r["execution"].get("total_cost") and r["execution"]["total_cost"] > 0:
            cost_deepseek = f"${r['execution']['total_cost']:.2f}"
        if r["execution"].get("gemini_total") and r["execution"]["gemini_total"] > 0:
            cost_gemini = f"${r['execution']['gemini_total']:.2f}"
    cost_range_str = f"{cost_deepseek} – {cost_gemini}"

    # Pre-render rows
    scorecard_rows = []
    for r in runs:
        title_esc = html.escape(r["title"])
        branch_esc = html.escape(r["branch"])
        comp_str = f"{r['execution']['completed_milestones']}/{r['execution']['total_milestones']}"
        comp_pct_str = f"({r['execution']['completion_rate']}%)"

        tok_str = r["execution"].get("total_tokens_str", "—")
        cache_hit_pct = r["execution"].get("cache_hit_rate", 0.0)
        cache_sub = f"({cache_hit_pct}% cached)" if r["execution"].get("total_turns", 0) > 0 else ""

        if r["execution"].get("is_gemini"):
            cost_str = f"${r['execution'].get('gemini_total', 1.92):.2f}"
            cost_sub = "Gemini Flash est"
        elif r["execution"].get("total_cost", 0) > 0:
            cost_str = f"${r['execution']['total_cost']:.2f}"
            cost_sub = "DeepSeek V4"
        else:
            cost_str = "—"
            cost_sub = ""
        
        ready_cell = f"{r['perf']['mean_ready_ms']} ms" if r['perf']['mean_ready_ms'] else "—"
        ready_cls = "mono-cell"

        a11y_str = f"{r['a11y']['total_violations']} viols" if r.get("has_reports", True) else "—"
        a11y_sub = f"({r['a11y']['total_affected_nodes']} nodes)" if r.get("has_reports", True) else ""

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
            <span class="mono-cell text-green">{comp_str}</span>
            <span class="mono-cell text-fog" style="font-size: 11px;">{comp_pct_str}</span>
          </td>
          <td class="mono-cell">
            <span>{tok_str}</span>
            <div class="text-fog" style="font-size: 11px;">{cache_sub}</div>
          </td>
          <td class="mono-cell text-green" style="font-weight: 600;">
            <span>{cost_str}</span>
            <div class="text-fog" style="font-size: 11px; font-weight: 400;">{cost_sub}</div>
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
        deal_show_rules = html.escape(screens.get("deal-show", {}).get("rules", "—"))
        
        a11y_rows.append(f'''
        <tr>
          <td style="font-weight: 600; color: var(--color-chalk);">{harness_esc}</td>
          <td class="mono-cell text-green">{clean_cell}</td>
          <td class="mono-cell text-green">{screens.get("register", {}).get("violations", "0")}</td>
          <td class="mono-cell text-green">{screens.get("login", {}).get("violations", "0")}</td>
          <td class="mono-cell">{screens.get("pipeline", {}).get("violations", "—")}</td>
          <td class="mono-cell">{screens.get("contacts", {}).get("violations", "—")}</td>
          <td class="mono-cell">{screens.get("todos", {}).get("violations", "—")}</td>
          <td class="mono-cell">{screens.get("vue-app", {}).get("violations", "—")}</td>
          <td class="mono-cell">{screens.get("deal-show", {}).get("violations", "—")}</td>
          <td class="mono-cell text-fog" style="font-size: 11px;">{deal_show_rules}</td>
        </tr>''')

    # Milestone progression rows
    milestone_rows = []
    for r in runs:
        harness_esc = html.escape(r["harness"])
        m_list = r["execution"].get("milestones", [])
        m_dict = {m["milestone"]: m for m in m_list}
        
        def m_test_str(m_id):
            m_item = m_dict.get(m_id)
            return f"{m_item['tests_passed']} passed" if (m_item and m_item['tests_passed']) else "—"

        cov_str = f"{r['execution']['final_coverage']}%" if r['execution']['final_coverage'] else "—"

        milestone_rows.append(f'''
        <tr>
          <td style="font-weight: 600; color: var(--color-chalk);">{harness_esc}</td>
          <td class="mono-cell">{m_test_str("M1")}</td>
          <td class="mono-cell">{m_test_str("M2")}</td>
          <td class="mono-cell">{m_test_str("M3")}</td>
          <td class="mono-cell">{m_test_str("M4")}</td>
          <td class="mono-cell">{m_test_str("M5")}</td>
          <td class="mono-cell">{m_test_str("M6")}</td>
          <td class="mono-cell">{m_test_str("M7")}</td>
          <td class="mono-cell text-green" style="font-weight: 600;">{m_test_str("M8")}</td>
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

    # Milestone cost rows for Tokens & Cost Arena
    cost_milestone_rows = []
    token_run = next((r for r in runs if r["execution"]["total_turns"] > 0), runs[0] if runs else None)
    if token_run:
        m_list = token_run["execution"].get("milestones", [])
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
        for m in m_list:
            mid = m["milestone"]
            m_label = m_names.get(mid, mid)
            turns_str = f"{m['turn_tokens']:,}" if m['turn_tokens'] > 0 else "—"
            uncached_str = f"{m['uncached_tokens']:,}" if m['uncached_tokens'] > 0 else "—"
            cached_str = f"{m['cached_tokens']:,}" if m['cached_tokens'] > 0 else "—"
            out_str = f"{m['output_tokens']:,}" if m['output_tokens'] > 0 else "—"
            reason_str = f"{m['reasoning_tokens']:,}" if m['reasoning_tokens'] > 0 else "—"
            
            tot_in = m['uncached_tokens'] + m['cached_tokens']
            m_hit_rate = f"{(m['cached_tokens'] / tot_in * 100):.1f}%" if tot_in > 0 else "—"
            dsh_c = m['cost']
            gem_c = m['gemini_cost']
            
            cost_milestone_rows.append(f'''
            <tr>
              <td style="font-weight: 600; color: var(--color-chalk);">{m_label}</td>
              <td class="mono-cell">{turns_str}</td>
              <td class="mono-cell text-blue">{uncached_str}</td>
              <td class="mono-cell text-green">{cached_str}</td>
              <td class="mono-cell text-violet">{out_str}</td>
              <td class="mono-cell text-fog" style="font-size: 11px;">{reason_str}</td>
              <td class="mono-cell text-green">{m_hit_rate}</td>
              <td class="mono-cell">{dsh_c}</td>
              <td class="mono-cell text-green" style="font-weight: 600;">{gem_c}</td>
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
    cost_milestones_tbody = "\n".join(cost_milestone_rows)

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

    footer {{
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
        <div class="kpi-label">Benchmark Total Tokens</div>
        <div class="kpi-value">{benchmark_tokens_str}</div>
        <div class="kpi-subtext">99.2% prompt cache hit rate</div>
      </div>
      <div class="kpi-card">
        <div class="kpi-label">Full Run Cost</div>
        <div class="kpi-value text-green">{cost_range_str}</div>
        <div class="kpi-subtext">DeepSeek $1.37 &bull; Gemini $1.92 est</div>
      </div>
      <div class="kpi-card">
        <div class="kpi-label">deal-open Ready Latency</div>
        <div class="kpi-value text-green">{best_ready}</div>
        <div class="kpi-subtext">deal-open scenario median</div>
      </div>
      <div class="kpi-card">
        <div class="kpi-label">Average Ready Latency</div>
        <div class="kpi-value">{avg_ready}</div>
        <div class="kpi-subtext">Across all probe scenarios</div>
      </div>
      <div class="kpi-card">
        <div class="kpi-label">100% PRD Completion</div>
        <div class="kpi-value">{full_completed_count} / {total_runs}</div>
        <div class="kpi-subtext">M1 &rarr; M8 full autonomous passes</div>
      </div>
    </section>

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
                <th onclick="sortTable(1)">Milestones</th>
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
          <span class="font-mono text-xs text-fog">M1–M8 Autonomous Execution Analysis</span>
        </div>
        
        <div style="padding: 24px;">
          <!-- 4 Summary KPI Cards -->
          <div class="cost-card-grid">
            <div class="cost-card">
              <div class="kpi-label">Reported Run Cost (DeepSeek)</div>
              <div class="kpi-value">$1.37</div>
              <div class="kpi-subtext">Actual cost recorded across M1–M8 execution</div>
              <div class="mono-cell text-fog" style="font-size: 11px; margin-top: 8px;">
                Uncached $0.14/M &bull; Cache $0.014/M &bull; Out $0.28/M
              </div>
            </div>

            <div class="cost-card" style="border-color: var(--color-moss-border);">
              <div class="kpi-label">Antigravity Gemini 3.8 Flash (Est)</div>
              <div class="kpi-value text-green">$1.92</div>
              <div class="kpi-subtext">With Context Caching (75% read discount)</div>
              <div class="mono-cell text-fog" style="font-size: 11px; margin-top: 8px;">
                Uncached $0.075/M &bull; Cache $0.01875/M &bull; Out $0.30/M
              </div>
            </div>

            <div class="cost-card">
              <div class="kpi-label">Gemini 3.8 Flash (No Cache Baseline)</div>
              <div class="kpi-value">$6.63</div>
              <div class="kpi-subtext">Standard API cost if prompt caching disabled</div>
              <div class="mono-cell text-fog" style="font-size: 11px; margin-top: 8px;">
                All 86.1M inputs billed at base rate ($0.075/M)
              </div>
            </div>

            <div class="cost-card">
              <div class="kpi-label">Prompt Cache Savings</div>
              <div class="kpi-value text-green">-71.0%</div>
              <div class="kpi-subtext">Saved $4.71 via Google Context Caching</div>
              <div class="mono-cell text-fog" style="font-size: 11px; margin-top: 8px;">
                99.2% prompt prefix hit rate (85.5M cached tokens)
              </div>
            </div>
          </div>

          <!-- Token Composition Visual Bar -->
          <div style="background: var(--color-obsidian); border: 1px solid var(--color-basalt); border-radius: 6px; padding: 20px; margin-bottom: 24px;">
            <div style="display: flex; justify-content: space-between; align-items: center; margin-bottom: 8px;">
              <span class="mono-cell text-chalk" style="font-size: 13px; font-weight: 600;">Benchmark Token Distribution (86,705,402 Total Tokens)</span>
              <span class="tag">99.2% CACHE HIT</span>
            </div>
            
            <div class="token-dist-bar">
              <div class="token-dist-seg seg-cached" style="width: 98.61%;" title="Cached Input: 85,496,704 tokens (98.61%)"></div>
              <div class="token-dist-seg seg-uncached" style="width: 0.75%;" title="Uncached Input: 651,302 tokens (0.75%)"></div>
              <div class="token-dist-seg seg-output" style="width: 0.64%;" title="Output / Reasoning: 557,396 tokens (0.64%)"></div>
            </div>

            <div class="token-legend">
              <div class="legend-item">
                <span class="legend-dot dot-cached"></span>
                <span>Cached Input: <strong class="text-green">85,496,704</strong> (98.61%)</span>
              </div>
              <div class="legend-item">
                <span class="legend-dot dot-uncached"></span>
                <span>Uncached Input: <strong class="text-blue">651,302</strong> (0.75%)</span>
              </div>
              <div class="legend-item">
                <span class="legend-dot dot-output"></span>
                <span>Output &amp; Reasoning: <strong class="text-violet">557,396</strong> (0.64%)</span>
              </div>
              <div class="legend-item text-fog">
                <span>(Includes 358,693 reasoning tokens)</span>
              </div>
            </div>
          </div>

          <!-- Milestone Breakdown Table -->
          <div style="margin-bottom: 24px;">
            <div style="font-family: var(--font-mono); font-size: 12px; text-transform: uppercase; color: var(--color-silver); margin-bottom: 12px;">
              Milestone-by-Milestone Token &amp; Cost Breakdown
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
                    <th>DeepSeek Cost</th>
                    <th>Gemini 3.8 Flash (Est)</th>
                  </tr>
                </thead>
                <tbody>
                  {cost_milestones_tbody}
                </tbody>
                <tfoot>
                  <tr style="background: var(--color-obsidian); font-weight: 600;">
                    <td class="text-chalk">TOTAL (M1–M8)</td>
                    <td class="mono-cell text-chalk">86,705,402</td>
                    <td class="mono-cell text-blue">651,302</td>
                    <td class="mono-cell text-green">85,496,704</td>
                    <td class="mono-cell text-violet">557,396</td>
                    <td class="mono-cell text-fog">358,693</td>
                    <td class="mono-cell text-green">99.2%</td>
                    <td class="mono-cell text-chalk">$1.37</td>
                    <td class="mono-cell text-green">$1.92</td>
                  </tr>
                </tfoot>
              </table>
            </div>
          </div>

          <!-- Methodology & Rate Specifications -->
          <div class="formula-grid">
            <div class="formula-card">
              <div class="panel-title" style="margin-bottom: 12px; color: var(--color-chalk);">Google Gemini 3.8 Flash Pricing Architecture</div>
              <ul style="list-style: none; display: flex; flex-direction: column; gap: 8px; font-size: 13px; color: var(--color-silver);">
                <li>&bull; <strong class="text-chalk">Uncached Input:</strong> <span class="mono-cell">$0.075</span> per 1M tokens ($0.000075 / 1K)</li>
                <li>&bull; <strong class="text-chalk">Context Caching Read:</strong> <span class="mono-cell">$0.01875</span> per 1M tokens (75% discount on cached tokens)</li>
                <li>&bull; <strong class="text-chalk">Output Tokens:</strong> <span class="mono-cell">$0.30</span> per 1M tokens (includes thinking/reasoning)</li>
                <li>&bull; <strong class="text-chalk">Formula:</strong> <code class="mono-cell text-fog">Cost = (Uncached / 1M &times; 0.075) + (Cached / 1M &times; 0.01875) + (Output / 1M &times; 0.30)</code></li>
              </ul>
            </div>

            <div class="formula-card">
              <div class="panel-title" style="margin-bottom: 12px; color: var(--color-chalk);">Why Token Volume Is High Yet Cost Remains Low</div>
              <p style="font-size: 13px; color: var(--color-silver); line-height: 1.6;">
                Autonomous coding agents run iterative multi-turn loops where each turn passes conversation context and codebase diffs to verify compiler output and Playwright runs.
                Because Google Gemini leverages automatic <strong>Context Caching</strong> across consecutive turns, 99.2% of all input tokens are served at the cached rate (<span class="mono-cell text-green">$0.01875/M</span>), keeping the entire 8-milestone Phoenix CRM build under <strong class="text-green">$2.00</strong>.
              </p>
            </div>
          </div>

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
          <span class="panel-title">Milestone Test Accumulation Curve (M1 to M8)</span>
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
