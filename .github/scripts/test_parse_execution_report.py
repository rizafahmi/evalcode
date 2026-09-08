#!/usr/bin/env python3
"""Tests for parse_execution_report milestone heading formats."""

import unittest

from build_leaderboard import parse_execution_report


class ParseExecutionMilestoneHeadingsTest(unittest.TestCase):
    def test_parses_milestone_n_headings(self):
        raw = """# Codex CLI - GPT 5.6

## Milestone 1
total time: 12m3s
Result: 114 passed
Coverage: 84.80%

## Milestone 2
total time: 9m0s
Result: 118 passed
Coverage: 86.49%

## Notes
ignore this
"""
        data = parse_execution_report(raw, "evalcode_codex_cli")
        self.assertEqual([m["milestone"] for m in data["milestones"]], ["M1", "M2"])
        self.assertEqual(data["milestones"][0]["tests_passed"], 114)
        self.assertEqual(data["milestones"][1]["tests_passed"], 118)
        self.assertEqual(data["completed_milestones"], 2)
        self.assertNotIn("Notes", [m["milestone"] for m in data["milestones"]])

    def test_parses_legacy_m_headings(self):
        raw = """# DeepSeek Harness - Deepseek v4 Flash High

## M1
total time: 24m20s
Result: 27 passed
Coverage: 80.00%

## M2
Result: 40 passed
Coverage: 82.00%
"""
        data = parse_execution_report(raw, "evalcode_dsh")
        self.assertEqual([m["milestone"] for m in data["milestones"]], ["M1", "M2"])
        self.assertEqual(data["milestones"][0]["tests_passed"], 27)
        self.assertEqual(data["milestones"][1]["tests_passed"], 40)


if __name__ == "__main__":
    unittest.main()
