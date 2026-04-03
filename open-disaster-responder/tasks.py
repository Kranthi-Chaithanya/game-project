"""
Tasks and deterministic graders for the Open Disaster Responder environment.

Three tasks:
  - Easy: Single earthquake, ~30 reports
  - Medium: Multi-incident (flood+fire), ~80 reports
  - Hard: Evolving wildfire with PyTorch predictor requirement
"""

from __future__ import annotations

from typing import Any

from open_disaster_responder.models import Priority, State


# ---------------------------------------------------------------------------
# Graders (deterministic, return 0.0–1.0)
# ---------------------------------------------------------------------------

def easy_grader(state: State) -> float:
    """
    Easy task grader: Single disaster with ~30 reports.

    Score = 60% critical reports handled quickly + 20% triage accuracy + 20% no waste.
    """
    total_reports = len(state.reports)
    if total_reports == 0:
        return 0.0

    # Critical reports handled
    critical_reports = [
        r for r in state.reports
        if r.ground_truth_priority == Priority.CRITICAL
    ]
    critical_handled = sum(
        1 for r in critical_reports
        if r.report_id in state.processed_report_ids
    )
    critical_ratio = critical_handled / max(1, len(critical_reports))

    # Triage accuracy
    triage_accuracy = state.correct_triages / max(1, state.total_triages)

    # No waste
    waste_penalty = min(1.0, state.resources_wasted / 10.0)
    no_waste = 1.0 - waste_penalty

    score = 0.6 * critical_ratio + 0.2 * triage_accuracy + 0.2 * no_waste
    return round(max(0.0, min(1.0, score)), 4)


def medium_grader(state: State) -> float:
    """
    Medium task grader: Multi-incident with ~80 reports.

    Score = 40% weighted response coverage + 30% impact reduction + 30% efficiency.
    """
    total_reports = len(state.reports)
    if total_reports == 0:
        return 0.0

    # Weighted response coverage (critical reports count double)
    handled = 0
    total_weight = 0
    for r in state.reports:
        weight = 2.0 if r.ground_truth_priority == Priority.CRITICAL else 1.0
        total_weight += weight
        if r.report_id in state.processed_report_ids:
            handled += weight
    coverage = handled / max(1.0, total_weight)

    # Impact reduction (lives saved vs total population at risk)
    total_pop = sum(z.population for z in state.zones if z.threat_level > 0.3)
    evac_pop = sum(
        z.population for z in state.zones
        if z.zone_id in state.evacuated_zones
    )
    impact_reduction = evac_pop / max(1, total_pop) if total_pop > 0 else 0.5

    # Efficiency
    total_dispatched = len(state.dispatched_resources)
    waste_ratio = state.resources_wasted / max(1, total_dispatched) if total_dispatched > 0 else 0.0
    efficiency = 1.0 - min(1.0, waste_ratio)

    score = 0.4 * coverage + 0.3 * impact_reduction + 0.3 * efficiency
    return round(max(0.0, min(1.0, score)), 4)


def hard_grader(state: State) -> float:
    """
    Hard task grader: Evolving wildfire with PyTorch predictor.

    Score = 40% triage quality + 40% PyTorch model AUC + 20% efficiency.
    """
    # Triage quality
    triage_accuracy = state.correct_triages / max(1, state.total_triages)
    total_reports = len(state.reports)
    coverage = len(state.processed_report_ids) / max(1, total_reports)
    triage_quality = 0.6 * triage_accuracy + 0.4 * coverage

    # PyTorch model AUC
    model_auc = 0.0
    if state.predictor_metrics and state.predictor_metrics.trained:
        model_auc = state.predictor_metrics.val_auc

    # Efficiency
    total_dispatched = len(state.dispatched_resources)
    waste_ratio = (
        state.resources_wasted / max(1, total_dispatched)
        if total_dispatched > 0
        else 0.0
    )
    efficiency = 1.0 - min(1.0, waste_ratio)

    score = 0.4 * triage_quality + 0.4 * model_auc + 0.2 * efficiency
    return round(max(0.0, min(1.0, score)), 4)


# ---------------------------------------------------------------------------
# Task definitions
# ---------------------------------------------------------------------------

TASKS: list[dict[str, Any]] = [
    {
        "id": "easy_single_disaster",
        "name": "Single Disaster - Earthquake Response",
        "description": (
            "Small single earthquake disaster with ~30 incoming reports. "
            "Agent must triage reports and dispatch resources efficiently."
        ),
        "difficulty": "easy",
        "grader": easy_grader,
        "params": {
            "disaster_type": "earthquake",
            "num_reports": 30,
            "grid_size": 100,
            "max_steps": 50,
        },
    },
    {
        "id": "medium_multi_incident",
        "name": "Multi-Incident - Flood & Fire Response",
        "description": (
            "Multi-incident scenario with simultaneous flood and fire. "
            "~80 incoming reports require coordinated multi-agency response."
        ),
        "difficulty": "medium",
        "grader": medium_grader,
        "params": {
            "disaster_type": "multi",
            "num_reports": 80,
            "grid_size": 100,
            "max_steps": 100,
        },
    },
    {
        "id": "hard_evolving_wildfire",
        "name": "Evolving Wildfire with Predictive Modeling",
        "description": (
            "Large evolving wildfire with uncertainty. Agent must train a "
            "PyTorch MLP predictor model to forecast spread. "
            "Graded: 40% triage + 40% PyTorch AUC + 20% efficiency."
        ),
        "difficulty": "hard",
        "grader": hard_grader,
        "params": {
            "disaster_type": "wildfire",
            "num_reports": 120,
            "grid_size": 100,
            "max_steps": 200,
            "require_predictor": True,
        },
    },
]
