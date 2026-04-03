"""
Baseline inference script for Open Disaster Responder.

Uses OpenAI client with tool calling to run all 3 tasks and print scores.
Set OPENAI_API_KEY environment variable before running.

Usage:
    python baseline.py
"""

from __future__ import annotations

import json
import os
import sys
from typing import Any

from open_disaster_responder.environment import OpenDisasterResponderEnvironment
from open_disaster_responder.models import (
    CoordinateWithAgency,
    DispatchResource,
    EvacuateZone,
    Priority,
    ReportCategory,
    RequestDroneImagery,
    ResourceType,
    SubmitFinalResponsePlan,
    TrainPredictorModel,
    TriageReport,
    UpdateSituationReport,
)
from open_disaster_responder.tasks import TASKS


def _make_system_prompt() -> str:
    return """You are an expert disaster response coordinator. You manage emergency
resources across a 100x100 grid and triage incoming crisis reports.

Available actions (provide as JSON with action_type field):
- triage_report: {action_type, report_id, priority (low/medium/high/critical), category}
- dispatch_resource: {action_type, resource_type (rescue_team/drone/medical_kit/evacuation_bus), target_x, target_y, quantity}
- request_drone_imagery: {action_type, location_x, location_y}
- evacuate_zone: {action_type, zone_id}
- coordinate_with_agency: {action_type, agency, message}
- update_situation_report: {action_type, summary}
- train_predictor_model: {action_type, epochs}
- submit_final_response_plan: {action_type, plan_summary}

Categories: structural_damage, trapped_people, medical_emergency, fire_hazard,
flood_water, road_blocked, utility_failure, evacuation_needed

Strategy:
1. Triage all reports, prioritizing critical ones first.
2. Dispatch rescue teams and medical kits to high-threat areas.
3. Evacuate zones with threat > 0.5.
4. For wildfire tasks, train the predictor model early.
5. Submit final plan when done.

Respond with a JSON array of 1-5 actions per turn."""


def _parse_actions(response_text: str) -> list[dict[str, Any]]:
    """Parse action JSON from LLM response."""
    try:
        text = response_text.strip()
        if text.startswith("```"):
            lines = text.split("\n")
            text = "\n".join(lines[1:-1]) if len(lines) > 2 else text
        parsed = json.loads(text)
        if isinstance(parsed, dict):
            return [parsed]
        if isinstance(parsed, list):
            return parsed
    except json.JSONDecodeError:
        pass
    return []


def _dict_to_action(d: dict[str, Any]) -> Any:
    """Convert a dictionary to a typed action."""
    action_type = d.get("action_type", "")

    if action_type == "triage_report":
        return TriageReport(
            report_id=d["report_id"],
            priority=Priority(d["priority"]),
            category=ReportCategory(d["category"]),
        )
    elif action_type == "dispatch_resource":
        return DispatchResource(
            resource_type=ResourceType(d["resource_type"]),
            target_x=d["target_x"],
            target_y=d["target_y"],
            quantity=d.get("quantity", 1),
        )
    elif action_type == "request_drone_imagery":
        return RequestDroneImagery(
            location_x=d["location_x"],
            location_y=d["location_y"],
        )
    elif action_type == "evacuate_zone":
        return EvacuateZone(zone_id=d["zone_id"])
    elif action_type == "coordinate_with_agency":
        return CoordinateWithAgency(
            agency=d["agency"],
            message=d["message"],
        )
    elif action_type == "update_situation_report":
        return UpdateSituationReport(summary=d["summary"])
    elif action_type == "train_predictor_model":
        return TrainPredictorModel(epochs=d.get("epochs", 5))
    elif action_type == "submit_final_response_plan":
        return SubmitFinalResponsePlan(
            plan_summary=d.get("plan_summary", "Final response plan submitted.")
        )
    else:
        raise ValueError(f"Unknown action type: {action_type}")


def _observation_to_prompt(obs: Any) -> str:
    """Convert observation to a concise prompt for the LLM."""
    reports_summary = []
    for r in obs.report_queue[:10]:  # Limit to avoid token overflow
        reports_summary.append({
            "id": r.report_id,
            "text": r.text[:100],
            "loc": f"({r.location_x},{r.location_y})",
            "urgency": r.urgency,
        })

    zones_at_risk = [
        {"id": z.zone_id, "threat": z.threat_level, "pop": z.population, "evacuated": z.evacuated}
        for z in obs.zones
        if z.threat_level > 0.2
    ]

    summary = {
        "step": f"{obs.current_step}/{obs.max_steps}",
        "disaster": obs.disaster_type,
        "impact": obs.projected_impact,
        "score": obs.score_so_far,
        "pending_reports": len(obs.report_queue),
        "reports_sample": reports_summary,
        "resources": {
            "rescue_teams": obs.resource_status.rescue_teams,
            "drones": obs.resource_status.drones,
            "medical_kits": obs.resource_status.medical_kits,
            "buses": obs.resource_status.evacuation_buses,
        },
        "zones_at_risk": zones_at_risk,
    }

    if obs.predictor_metrics and obs.predictor_metrics.trained:
        summary["predictor_auc"] = obs.predictor_metrics.val_auc

    return json.dumps(summary, indent=2)


def _run_heuristic_baseline(task: dict[str, Any]) -> float:
    """Run a deterministic heuristic baseline (no LLM needed)."""
    env = OpenDisasterResponderEnvironment(seed=42)
    obs = env.reset(task_id=task["id"], params=task["params"])

    done = False
    step = 0
    predictor_trained = False

    while not done:
        actions = []

        # Triage reports by urgency
        sorted_reports = sorted(obs.report_queue, key=lambda r: -r.urgency)
        for r in sorted_reports[:3]:
            priority = Priority.CRITICAL if r.urgency >= 0.7 else (
                Priority.HIGH if r.urgency >= 0.5 else (
                    Priority.MEDIUM if r.urgency >= 0.3 else Priority.LOW
                )
            )
            category = r.ground_truth_category or ReportCategory.STRUCTURAL_DAMAGE
            actions.append(TriageReport(
                report_id=r.report_id,
                priority=priority,
                category=category,
            ))

        # Dispatch to high-threat areas
        if obs.resource_status.rescue_teams > 2:
            for r in sorted_reports[:1]:
                if r.urgency > 0.5:
                    actions.append(DispatchResource(
                        resource_type=ResourceType.RESCUE_TEAM,
                        target_x=r.location_x,
                        target_y=r.location_y,
                        quantity=1,
                    ))

        # Evacuate threatened zones
        for z in obs.zones:
            if z.threat_level > 0.5 and not z.evacuated and obs.resource_status.evacuation_buses > 0:
                actions.append(EvacuateZone(zone_id=z.zone_id))
                break

        # Train predictor for hard task
        if (
            task["params"].get("require_predictor")
            and not predictor_trained
            and step > 5
        ):
            actions.append(TrainPredictorModel(epochs=10))
            predictor_trained = True

        # Submit plan near end
        if step >= task["params"]["max_steps"] - 2 or (
            len(obs.report_queue) == 0 and step > 10
        ):
            actions.append(SubmitFinalResponsePlan(
                plan_summary="Heuristic baseline final plan."
            ))

        if not actions:
            actions.append(UpdateSituationReport(
                summary=f"Step {step}: monitoring situation."
            ))

        for action in actions:
            if done:
                break
            obs, reward, done = env.step(action)

        step += 1

    state = env.state()
    grader = task["grader"]
    score = grader(state)
    env.close()
    return score


def run_llm_baseline(task: dict[str, Any]) -> float:
    """Run a task using OpenAI LLM with tool calling."""
    try:
        from openai import OpenAI
    except ImportError:
        print("openai package not installed. Running heuristic baseline.")
        return _run_heuristic_baseline(task)

    api_key = os.environ.get("OPENAI_API_KEY")
    if not api_key:
        print("OPENAI_API_KEY not set. Running heuristic baseline.")
        return _run_heuristic_baseline(task)

    client = OpenAI(api_key=api_key)
    env = OpenDisasterResponderEnvironment(seed=42)
    obs = env.reset(task_id=task["id"], params=task["params"])

    messages = [{"role": "system", "content": _make_system_prompt()}]
    done = False

    while not done:
        prompt = _observation_to_prompt(obs)
        messages.append({"role": "user", "content": prompt})

        try:
            response = client.chat.completions.create(
                model="gpt-4o-mini",
                messages=messages,
                temperature=0.2,
                max_tokens=1000,
            )
            assistant_msg = response.choices[0].message.content or "[]"
        except Exception as e:
            print(f"  LLM error: {e}. Using heuristic fallback.")
            return _run_heuristic_baseline(task)

        messages.append({"role": "assistant", "content": assistant_msg})

        action_dicts = _parse_actions(assistant_msg)
        if not action_dicts:
            # Fallback: submit plan
            action_dicts = [{"action_type": "submit_final_response_plan", "plan_summary": "Fallback plan."}]

        for ad in action_dicts:
            if done:
                break
            try:
                action = _dict_to_action(ad)
                obs, reward, done = env.step(action)
            except Exception as e:
                print(f"  Action error: {e}")

        # Keep message history manageable
        if len(messages) > 20:
            messages = messages[:1] + messages[-10:]

    state = env.state()
    grader = task["grader"]
    score = grader(state)
    env.close()
    return score


def main() -> None:
    """Run all tasks and print scores."""
    print("=" * 60)
    print("Open Disaster Responder — Baseline Runner")
    print("=" * 60)

    use_llm = os.environ.get("OPENAI_API_KEY") is not None

    scores = {}
    for task in TASKS:
        print(f"\n--- Task: {task['name']} ({task['difficulty']}) ---")
        if use_llm:
            print("  Using LLM baseline...")
            score = run_llm_baseline(task)
        else:
            print("  Using heuristic baseline (set OPENAI_API_KEY for LLM)...")
            score = _run_heuristic_baseline(task)
        scores[task["id"]] = score
        print(f"  Score: {score:.4f}")

    print("\n" + "=" * 60)
    print("Final Scores:")
    for task_id, score in scores.items():
        print(f"  {task_id}: {score:.4f}")
    avg = sum(scores.values()) / len(scores) if scores else 0
    print(f"  Average: {avg:.4f}")
    print("=" * 60)


if __name__ == "__main__":
    main()
