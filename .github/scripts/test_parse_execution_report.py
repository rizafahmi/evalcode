#!/usr/bin/env python3
"""Tests for parse_execution_report milestone headings and empty cost/token logs."""

import unittest

from build_leaderboard import parse_execution_report


class ParseExecutionMilestoneHeadingsTest(unittest.TestCase):
    def test_parses_milestone_n_headings(self):
        raw = """# Codex CLI - GPT 5.6-luna Effort Medium

## Milestone 1
total time: 12m3s
Result: 114 passed
Coverage: 84.80%
Context window:       57% left (119K used / 258K)

## Milestone 2
total time: 9m0s
Result: 118 passed
Coverage: 86.49%

## Notes
The design, especially layout is bad. There is two navigation bar.
"""
        data = parse_execution_report(raw, "evalcode_codex_cli")
        self.assertEqual([m["milestone"] for m in data["milestones"]], ["M1", "M2"])
        self.assertEqual(data["milestones"][0]["tests_passed"], 114)
        self.assertEqual(data["milestones"][1]["tests_passed"], 118)
        self.assertEqual(data["milestones"][0]["context_used"], "119K / 258K")
        self.assertEqual(data["completed_milestones"], 2)
        self.assertEqual(data["final_tests"], 118)
        self.assertEqual(data["final_coverage"], 86.49)
        self.assertEqual(data["cost_display"], "—")
        self.assertFalse(data["has_token_log"])
        self.assertFalse(data["has_cost_log"])
        self.assertNotIn("Notes", [m["milestone"] for m in data["milestones"]])
        self.assertIn("navigation bar", data["notes"])

    def test_parses_legacy_m_headings(self):
        raw = """# DeepSeek Harness - Deepseek v4 Flash High

## M1
total time: 24m20s
Result: 27 passed
Coverage: 80.00%

## M2
Result: 40 passed
Coverage: 82.00%
Cost: $0.13
"""
        data = parse_execution_report(raw, "evalcode_dsh")
        self.assertEqual([m["milestone"] for m in data["milestones"]], ["M1", "M2"])
        self.assertEqual(data["milestones"][0]["tests_passed"], 27)
        self.assertEqual(data["milestones"][1]["tests_passed"], 40)
        self.assertEqual(data["cost_display"], "$0.13")
        self.assertTrue(data["has_cost_log"])

    def test_empty_report_does_not_show_zero_dollars(self):
        data = parse_execution_report("", "evalcode_codex_cli")
        self.assertEqual(data["cost_display"], "—")
        self.assertEqual(data["total_tokens_str"], "—")
        self.assertEqual(data["completed_milestones"], 0)
        self.assertEqual(data["gemini_total"], 0.0)


if __name__ == "__main__":
    unittest.main()
