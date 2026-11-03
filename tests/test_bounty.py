#!/usr/bin/env python3
"""Unit tests for Bounty Studio core calculation rules and data schemas."""
import json
from pathlib import Path
import unittest

PROJECT_ROOT = Path(__file__).resolve().parents[1]
DATA_DIR = PROJECT_ROOT / "src" / "BountyStudio.Shared" / "Data"


def build_level_table(rule):
    value = round(rule["base"] * 100)
    values, spent = [value / 100], [0]
    total = 0
    for band in rule["bands"]:
        end, step = round(band["until"] * 100), round(band["step"] * 100)
        cost = band["initialCost"]
        while value < end:
            value = min(end, value + step)
            values.append(value / 100)
            total += cost
            spent.append(total)
            cost += band["costStep"]
    return {"values": values, "spent": spent}


class TestBountyRules(unittest.TestCase):
    def setUp(self):
        self.rules = json.loads((DATA_DIR / "rules.json").read_text(encoding="utf-8"))
        self.defaults = json.loads((DATA_DIR / "defaults.json").read_text(encoding="utf-8"))
        self.slot_costs = json.loads((DATA_DIR / "slot-costs.json").read_text(encoding="utf-8"))

    def test_slot_costs(self):
        self.assertEqual(len(self.slot_costs), 5)
        self.assertEqual(self.slot_costs[0], 0)
        self.assertEqual(self.slot_costs[1], 300)
        self.assertEqual(self.slot_costs[2], 600)
        self.assertEqual(self.slot_costs[3], 900)
        self.assertEqual(self.slot_costs[4], 1200)
        self.assertEqual(sum(self.slot_costs), 3000)

    def test_damage_rule_table(self):
        rule = self.rules["damage"]
        self.assertEqual(rule["base"], 2.5)
        self.assertEqual(rule["max"], 50)
        table = build_level_table(rule)
        self.assertEqual(table["values"][0], 2.5)
        self.assertEqual(table["spent"][0], 0)
        self.assertEqual(table["values"][-1], 50.0)
        self.assertTrue(all(table["spent"][i] <= table["spent"][i + 1] for i in range(len(table["spent"]) - 1)))

    def test_leech_loot_bestiary_bounds(self):
        for key in ("leech", "loot"):
            rule = self.rules[key]
            self.assertEqual(rule["base"], 2.5)
            self.assertEqual(rule["max"], 50)
            table = build_level_table(rule)
            self.assertEqual(table["values"][-1], 50.0)

        bestiary = self.rules["bestiary"]
        self.assertEqual(bestiary["base"], 5)
        self.assertEqual(bestiary["max"], 100)
        table = build_level_table(bestiary)
        self.assertEqual(table["values"][-1], 100.0)

    def test_defaults_schema(self):
        self.assertEqual(self.defaults["schemaVersion"], 7)
        self.assertEqual(self.defaults["damage"], 2.5)
        self.assertEqual(self.defaults["leech"], 2.5)
        self.assertEqual(self.defaults["loot"], 2.5)
        self.assertEqual(self.defaults["bestiary"], 5)
        self.assertEqual(self.defaults["slot0"], True)


if __name__ == "__main__":
    unittest.main()

