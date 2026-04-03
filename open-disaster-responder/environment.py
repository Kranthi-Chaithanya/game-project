"""
Main OpenEnv environment for the Real-Time Disaster Response Intelligence System.

Implements the full simulation loop with cellular automata disaster evolution,
report generation, resource management, and PyTorch predictor training.
"""

from __future__ import annotations

import math
import random
import uuid
from typing import Any, Optional

import numpy as np

from open_disaster_responder.models import (
    Action,
    CoordinateWithAgency,
    CrisisReport,
    DispatchResource,
    EvacuateZone,
    Observation,
    PredictorMetrics,
    Priority,
    ReportCategory,
    RequestDroneImagery,
    ResourceStatus,
    ResourceType,
    Reward,
    State,
    SubmitFinalResponsePlan,
    TrainPredictorModel,
    TriageReport,
    UpdateSituationReport,
    ZoneInfo,
)


# ---------------------------------------------------------------------------
# PyTorch predictor (used in hard task)
# ---------------------------------------------------------------------------

def _train_predictor(grid: np.ndarray, epochs: int = 5) -> dict[str, Any]:
    """Train a small PyTorch MLP to predict disaster spread on the grid."""
    try:
        import torch
        import torch.nn as nn
        from sklearn.metrics import roc_auc_score  # noqa: F401
    except ImportError:
        return {
            "trained": False,
            "epochs_completed": 0,
            "train_loss": 0.0,
            "val_auc": 0.0,
            "predictions": [],
        }

    # Build training data from current grid state
    coords = []
    labels = []
    for i in range(grid.shape[0]):
        for j in range(grid.shape[1]):
            coords.append([i / 100.0, j / 100.0])
            labels.append(1.0 if grid[i, j] > 0.5 else 0.0)

    X = torch.tensor(coords, dtype=torch.float32)
    y = torch.tensor(labels, dtype=torch.float32).unsqueeze(1)

    # Stratified split
    n = len(X)
    idx = list(range(n))
    random.shuffle(idx)
    split = int(0.8 * n)
    train_idx, val_idx = idx[:split], idx[split:]

    X_train, y_train = X[train_idx], y[train_idx]
    X_val, y_val = X[val_idx], y[val_idx]

    # Small MLP
    model = nn.Sequential(
        nn.Linear(2, 32),
        nn.ReLU(),
        nn.Linear(32, 16),
        nn.ReLU(),
        nn.Linear(16, 1),
        nn.Sigmoid(),
    )

    optimizer = torch.optim.Adam(model.parameters(), lr=0.01)
    criterion = nn.BCELoss()

    train_loss = 0.0
    for epoch in range(epochs):
        model.train()
        optimizer.zero_grad()
        pred = model(X_train)
        loss = criterion(pred, y_train)
        loss.backward()
        optimizer.step()
        train_loss = loss.item()

    # Evaluate
    model.eval()
    with torch.no_grad():
        val_pred = model(X_val).numpy().flatten()
        val_labels = y_val.numpy().flatten()

    try:
        if len(set(val_labels)) > 1:
            auc = roc_auc_score(val_labels, val_pred)
        else:
            auc = 0.5
    except Exception:
        auc = 0.5

    # Generate predictions grid (downsampled 10x10)
    predictions = []
    model.eval()
    with torch.no_grad():
        for i in range(0, 100, 10):
            row = []
            for j in range(0, 100, 10):
                inp = torch.tensor([[i / 100.0, j / 100.0]], dtype=torch.float32)
                row.append(float(model(inp).item()))
            predictions.append(row)

    return {
        "trained": True,
        "epochs_completed": epochs,
        "train_loss": train_loss,
        "val_auc": auc,
        "predictions": predictions,
    }


# ---------------------------------------------------------------------------
# Report generation utilities
# ---------------------------------------------------------------------------

_REPORT_TEMPLATES = [
    "Building collapsed at sector {loc}. People may be trapped.",
    "Fire spreading near {loc}. Urgent evacuation needed.",
    "Flood water rising rapidly in zone {loc}.",
    "Medical emergency reported at {loc}. Multiple casualties.",
    "Road blocked by debris at {loc}. Emergency vehicles cannot pass.",
    "Power lines down at {loc}. Electrocution hazard.",
    "Gas leak detected near {loc}. Immediate evacuation required.",
    "People stranded on rooftop at {loc}. Need helicopter rescue.",
    "Hospital at {loc} running low on medical supplies.",
    "Bridge structurally compromised at {loc}.",
    "Large aftershock felt near {loc}. New structural damage.",
    "Wildfire approaching residential area at {loc}.",
]

_CATEGORY_MAP = {
    "collapsed": ReportCategory.STRUCTURAL_DAMAGE,
    "trapped": ReportCategory.TRAPPED_PEOPLE,
    "fire": ReportCategory.FIRE_HAZARD,
    "wildfire": ReportCategory.FIRE_HAZARD,
    "flood": ReportCategory.FLOOD_WATER,
    "medical": ReportCategory.MEDICAL_EMERGENCY,
    "road": ReportCategory.ROAD_BLOCKED,
    "power": ReportCategory.UTILITY_FAILURE,
    "gas": ReportCategory.EVACUATION_NEEDED,
    "stranded": ReportCategory.TRAPPED_PEOPLE,
    "hospital": ReportCategory.MEDICAL_EMERGENCY,
    "bridge": ReportCategory.STRUCTURAL_DAMAGE,
    "aftershock": ReportCategory.STRUCTURAL_DAMAGE,
}


def _classify_template(template: str) -> ReportCategory:
    text_lower = template.lower()
    for keyword, cat in _CATEGORY_MAP.items():
        if keyword in text_lower:
            return cat
    return ReportCategory.STRUCTURAL_DAMAGE


def _urgency_to_priority(urgency: float) -> Priority:
    if urgency >= 0.8:
        return Priority.CRITICAL
    if urgency >= 0.6:
        return Priority.HIGH
    if urgency >= 0.35:
        return Priority.MEDIUM
    return Priority.LOW


def _generate_reports(
    disaster_type: str,
    num_reports: int,
    grid: np.ndarray,
    time_elapsed: float,
) -> list[CrisisReport]:
    """Generate synthetic crisis reports based on the current grid state."""
    reports = []
    hot_cells = list(zip(*np.where(grid > 0.3)))
    if not hot_cells:
        hot_cells = [(random.randint(0, 99), random.randint(0, 99)) for _ in range(5)]

    for i in range(num_reports):
        cell = random.choice(hot_cells)
        x, y = int(cell[0]), int(cell[1])

        # Add some jitter
        x = max(0, min(99, x + random.randint(-5, 5)))
        y = max(0, min(99, y + random.randint(-5, 5)))

        template = random.choice(_REPORT_TEMPLATES)
        text = template.format(loc=f"({x},{y})")
        urgency = min(1.0, grid[x, y] + random.uniform(-0.1, 0.2))
        urgency = max(0.0, urgency)

        category = _classify_template(template)
        priority = _urgency_to_priority(urgency)

        reports.append(
            CrisisReport(
                report_id=f"RPT-{uuid.uuid4().hex[:8]}",
                text=text,
                location_x=x,
                location_y=y,
                image_url=None,
                urgency=round(urgency, 3),
                timestamp=time_elapsed + i * 0.1,
                ground_truth_priority=priority,
                ground_truth_category=category,
            )
        )

    return reports


# ---------------------------------------------------------------------------
# Cellular automata for disaster evolution
# ---------------------------------------------------------------------------

def _evolve_grid(grid: np.ndarray, disaster_type: str, step: int) -> np.ndarray:
    """Evolve the disaster grid using simple cellular automata rules."""
    new_grid = grid.copy()
    rows, cols = grid.shape

    for i in range(rows):
        for j in range(cols):
            neighbors = []
            for di in [-1, 0, 1]:
                for dj in [-1, 0, 1]:
                    if di == 0 and dj == 0:
                        continue
                    ni, nj = i + di, j + dj
                    if 0 <= ni < rows and 0 <= nj < cols:
                        neighbors.append(grid[ni, nj])

            avg_neighbor = np.mean(neighbors) if neighbors else 0

            if disaster_type in ("fire", "wildfire"):
                # Fire spreads to neighbors with probability proportional to heat
                if grid[i, j] > 0.6:
                    spread = 0.05 * avg_neighbor + random.uniform(0, 0.02)
                    new_grid[i, j] = min(1.0, grid[i, j] + spread)
                elif avg_neighbor > 0.5 and random.random() < 0.15:
                    new_grid[i, j] = min(1.0, grid[i, j] + 0.1)

            elif disaster_type == "flood":
                # Water level rises and spreads
                if grid[i, j] > 0.3:
                    new_grid[i, j] = min(1.0, grid[i, j] + 0.02)
                if avg_neighbor > 0.4 and grid[i, j] < avg_neighbor:
                    new_grid[i, j] = min(1.0, grid[i, j] + 0.05)

            elif disaster_type == "earthquake":
                # Aftershocks: random spikes
                if random.random() < 0.02 and step % 5 == 0:
                    new_grid[i, j] = min(1.0, grid[i, j] + random.uniform(0.1, 0.3))
                else:
                    new_grid[i, j] = max(0.0, grid[i, j] - 0.01)

            elif disaster_type == "multi":
                # Combined effects
                if grid[i, j] > 0.5:
                    new_grid[i, j] = min(1.0, grid[i, j] + random.uniform(0, 0.03))
                if avg_neighbor > 0.4:
                    new_grid[i, j] = min(1.0, grid[i, j] + 0.03)

    return new_grid


def _init_grid(disaster_type: str, rng: random.Random) -> np.ndarray:
    """Initialize the 100x100 grid with disaster epicenters."""
    grid = np.zeros((100, 100), dtype=np.float64)

    if disaster_type == "earthquake":
        # Single epicenter
        cx, cy = rng.randint(20, 80), rng.randint(20, 80)
        for i in range(100):
            for j in range(100):
                dist = math.sqrt((i - cx) ** 2 + (j - cy) ** 2)
                if dist < 25:
                    grid[i, j] = max(0, 0.9 - dist * 0.03 + rng.uniform(-0.05, 0.05))

    elif disaster_type in ("fire", "wildfire"):
        # Multiple fire sources
        n_sources = 3 if disaster_type == "wildfire" else 1
        for _ in range(n_sources):
            cx, cy = rng.randint(10, 90), rng.randint(10, 90)
            for i in range(max(0, cx - 15), min(100, cx + 15)):
                for j in range(max(0, cy - 15), min(100, cy + 15)):
                    dist = math.sqrt((i - cx) ** 2 + (j - cy) ** 2)
                    if dist < 15:
                        grid[i, j] = max(
                            grid[i, j],
                            0.8 - dist * 0.04 + rng.uniform(-0.05, 0.05),
                        )

    elif disaster_type == "flood":
        # Flood zone along a river-like band
        river_y = rng.randint(30, 70)
        for i in range(100):
            for j in range(100):
                dist = abs(j - river_y)
                if dist < 20:
                    grid[i, j] = max(0, 0.7 - dist * 0.03 + rng.uniform(-0.05, 0.05))

    elif disaster_type == "multi":
        # Fire zone + flood zone
        cx, cy = rng.randint(60, 90), rng.randint(60, 90)
        for i in range(max(0, cx - 15), min(100, cx + 15)):
            for j in range(max(0, cy - 15), min(100, cy + 15)):
                dist = math.sqrt((i - cx) ** 2 + (j - cy) ** 2)
                if dist < 15:
                    grid[i, j] = 0.8 - dist * 0.04

        river_y = rng.randint(10, 40)
        for i in range(100):
            for j in range(100):
                dist = abs(j - river_y)
                if dist < 15:
                    grid[i, j] = max(grid[i, j], 0.6 - dist * 0.03)

    return np.clip(grid, 0, 1)


def _init_zones(grid: np.ndarray, rng: random.Random) -> list[ZoneInfo]:
    """Create zones based on grid hot-spots."""
    zones = []
    zone_centers = [
        (25, 25), (25, 75), (75, 25), (75, 75), (50, 50),
        (15, 50), (85, 50), (50, 15), (50, 85),
    ]
    for idx, (cx, cy) in enumerate(zone_centers):
        r = 12
        region = grid[max(0, cx - r):min(100, cx + r), max(0, cy - r):min(100, cy + r)]
        threat = float(np.mean(region)) if region.size > 0 else 0.0
        zones.append(
            ZoneInfo(
                zone_id=f"ZONE-{idx:02d}",
                center_x=cx,
                center_y=cy,
                radius=r,
                population=rng.randint(500, 5000),
                threat_level=round(min(1.0, threat), 3),
            )
        )
    return zones


# ---------------------------------------------------------------------------
# Environment
# ---------------------------------------------------------------------------

class OpenDisasterResponderEnvironment:
    """
    Real-Time Disaster Response Intelligence System.

    Simulates disaster scenarios on a 100x100 grid with cellular automata
    evolution, incoming crisis reports, and resource management.
    """

    def __init__(self, seed: int = 42) -> None:
        self._seed = seed
        self._rng = random.Random(seed)
        self._state: Optional[State] = None
        self._task_params: dict[str, Any] = {}
        self._closed = False

    # -----------------------------------------------------------------------
    # Core API
    # -----------------------------------------------------------------------

    def reset(
        self,
        task_id: Optional[str] = None,
        params: Optional[dict[str, Any]] = None,
    ) -> Observation:
        """Reset the environment for a new episode."""
        self._rng = random.Random(self._seed)

        # Merge task params
        self._task_params = params or {}
        disaster_type = self._task_params.get("disaster_type", "earthquake")
        num_reports = self._task_params.get("num_reports", 30)
        grid_size = self._task_params.get("grid_size", 100)
        max_steps = self._task_params.get("max_steps", 50)

        grid = _init_grid(disaster_type, self._rng)
        zones = _init_zones(grid, self._rng)

        # Generate initial batch of reports
        initial_count = min(num_reports // 3, 10)
        initial_reports = _generate_reports(disaster_type, initial_count, grid, 0.0)

        # Remaining reports to be dripped in
        remaining_count = num_reports - initial_count
        pending = _generate_reports(disaster_type, remaining_count, grid, 0.0)

        self._state = State(
            grid=grid.tolist(),
            reports=initial_reports,
            resource_status=ResourceStatus(
                rescue_teams=10,
                drones=5,
                medical_kits=20,
                evacuation_buses=4,
            ),
            zones=zones,
            max_steps=max_steps,
            disaster_type=disaster_type,
            pending_reports=pending,
        )

        return self._make_observation()

    def step(self, action: Action) -> tuple[Observation, Reward, bool]:
        """Take one step in the environment."""
        if self._state is None:
            raise RuntimeError("Environment not initialized. Call reset() first.")
        if self._state.done:
            raise RuntimeError("Episode is done. Call reset() to start a new one.")

        reward = self._process_action(action)

        # Evolve disaster
        grid_np = np.array(self._state.grid)
        grid_np = _evolve_grid(grid_np, self._state.disaster_type, self._state.step_count)
        self._state.grid = grid_np.tolist()

        # Drip in new reports
        if self._state.pending_reports:
            drip_count = min(
                self._rng.randint(1, 4),
                len(self._state.pending_reports),
            )
            new_reports = self._state.pending_reports[:drip_count]
            # Update timestamps
            for r in new_reports:
                r.timestamp = self._state.time_elapsed
            self._state.reports.extend(new_reports)
            self._state.pending_reports = self._state.pending_reports[drip_count:]

        # Update zones threat levels
        for zone in self._state.zones:
            cx, cy, r = zone.center_x, zone.center_y, zone.radius
            region = grid_np[
                max(0, cx - r):min(100, cx + r),
                max(0, cy - r):min(100, cy + r),
            ]
            zone.threat_level = round(float(np.mean(region)), 3) if region.size > 0 else 0.0

        # Check for missed critical reports (delay penalty)
        for report in self._state.reports:
            if (
                report.report_id not in self._state.processed_report_ids
                and report.ground_truth_priority == Priority.CRITICAL
                and self._state.time_elapsed - report.timestamp > 3.0
            ):
                self._state.delay_penalties += 0.02
                self._state.critical_reports_missed += 1

        self._state.step_count += 1
        self._state.time_elapsed += 1.0
        self._state.total_reward += reward.value

        # Check termination
        done = (
            self._state.step_count >= self._state.max_steps
            or self._state.plan_submitted
        )
        self._state.done = done

        return self._make_observation(), reward, done

    def state(self) -> State:
        """Return the full internal state."""
        if self._state is None:
            raise RuntimeError("Environment not initialized.")
        return self._state

    def close(self) -> None:
        """Clean up environment resources."""
        self._state = None
        self._closed = True

    # -----------------------------------------------------------------------
    # Action processing
    # -----------------------------------------------------------------------

    def _process_action(self, action: Action) -> Reward:
        """Process an action and return a reward."""
        assert self._state is not None

        if isinstance(action, TriageReport):
            return self._handle_triage(action)
        elif isinstance(action, DispatchResource):
            return self._handle_dispatch(action)
        elif isinstance(action, RequestDroneImagery):
            return self._handle_drone_request(action)
        elif isinstance(action, EvacuateZone):
            return self._handle_evacuation(action)
        elif isinstance(action, CoordinateWithAgency):
            return self._handle_coordination(action)
        elif isinstance(action, UpdateSituationReport):
            return self._handle_sitrep(action)
        elif isinstance(action, TrainPredictorModel):
            return self._handle_train_predictor(action)
        elif isinstance(action, SubmitFinalResponsePlan):
            return self._handle_submit_plan(action)
        else:
            return Reward(value=-0.05, message="Unknown action type.")

    def _handle_triage(self, action: TriageReport) -> Reward:
        s = self._state
        assert s is not None

        # Find the report
        report = None
        for r in s.reports:
            if r.report_id == action.report_id:
                report = r
                break

        if report is None:
            return Reward(value=-0.05, message=f"Report {action.report_id} not found.")

        if report.report_id in s.processed_report_ids:
            return Reward(value=-0.02, message="Report already processed.")

        s.processed_report_ids.add(report.report_id)
        s.total_triages += 1
        s.triaged_reports[report.report_id] = {
            "priority": action.priority.value,
            "category": action.category.value,
        }

        reward_val = 0.0
        breakdown = {}

        # Check priority accuracy
        if report.ground_truth_priority and action.priority == report.ground_truth_priority:
            reward_val += 0.10
            breakdown["priority_correct"] = 0.10
            s.correct_triages += 1
        elif report.ground_truth_priority:
            reward_val -= 0.03
            breakdown["priority_wrong"] = -0.03
            # Extra penalty for missing critical
            if report.ground_truth_priority == Priority.CRITICAL and action.priority in (
                Priority.LOW, Priority.MEDIUM
            ):
                reward_val -= 0.05
                breakdown["missed_critical"] = -0.05

        # Check category accuracy
        if report.ground_truth_category and action.category == report.ground_truth_category:
            reward_val += 0.05
            breakdown["category_correct"] = 0.05

        # Speed bonus
        delay = s.time_elapsed - report.timestamp
        if delay < 2.0:
            reward_val += 0.02
            breakdown["speed_bonus"] = 0.02

        return Reward(
            value=round(reward_val, 4),
            breakdown=breakdown,
            message=f"Triaged report {action.report_id}.",
        )

    def _handle_dispatch(self, action: DispatchResource) -> Reward:
        s = self._state
        assert s is not None
        res = s.resource_status

        # Check resource availability
        available = {
            ResourceType.RESCUE_TEAM: res.rescue_teams,
            ResourceType.DRONE: res.drones,
            ResourceType.MEDICAL_KIT: res.medical_kits,
            ResourceType.EVACUATION_BUS: res.evacuation_buses,
        }

        if available.get(action.resource_type, 0) < action.quantity:
            return Reward(
                value=-0.05,
                message=f"Not enough {action.resource_type.value} available.",
            )

        # Deduct resources
        if action.resource_type == ResourceType.RESCUE_TEAM:
            res.rescue_teams -= action.quantity
        elif action.resource_type == ResourceType.DRONE:
            res.drones -= action.quantity
        elif action.resource_type == ResourceType.MEDICAL_KIT:
            res.medical_kits -= action.quantity
        elif action.resource_type == ResourceType.EVACUATION_BUS:
            res.evacuation_buses -= action.quantity

        s.dispatched_resources.append({
            "type": action.resource_type.value,
            "target_x": action.target_x,
            "target_y": action.target_y,
            "quantity": action.quantity,
            "step": s.step_count,
        })

        # Reward based on threat level at target
        grid_np = np.array(s.grid)
        threat = grid_np[action.target_x, action.target_y]

        reward_val = 0.0
        breakdown = {}

        if threat > 0.6:
            reward_val += 0.25
            breakdown["life_saving_dispatch"] = 0.25
            s.lives_saved += action.quantity * 10
            # Reduce threat at target
            grid_np[
                max(0, action.target_x - 3):min(100, action.target_x + 3),
                max(0, action.target_y - 3):min(100, action.target_y + 3),
            ] *= 0.7
            s.grid = grid_np.tolist()
        elif threat > 0.3:
            reward_val += 0.10
            breakdown["moderate_dispatch"] = 0.10
        else:
            reward_val -= 0.05
            breakdown["low_threat_waste"] = -0.05
            s.resources_wasted += action.quantity

        # Efficiency bonus for sending right resource type
        if threat > 0.7 and action.resource_type in (
            ResourceType.RESCUE_TEAM, ResourceType.MEDICAL_KIT
        ):
            reward_val += 0.05
            breakdown["right_resource_bonus"] = 0.05

        return Reward(
            value=round(reward_val, 4),
            breakdown=breakdown,
            message=f"Dispatched {action.quantity} {action.resource_type.value} to ({action.target_x},{action.target_y}).",
        )

    def _handle_drone_request(self, action: RequestDroneImagery) -> Reward:
        s = self._state
        assert s is not None

        if s.resource_status.drones < 1:
            return Reward(value=-0.03, message="No drones available.")

        s.drone_requests.append({
            "x": action.location_x,
            "y": action.location_y,
            "step": s.step_count,
        })

        # Reveal hidden info around the requested location
        grid_np = np.array(s.grid)
        threat = float(grid_np[action.location_x, action.location_y])

        return Reward(
            value=0.02 if threat > 0.3 else -0.01,
            breakdown={"recon_value": 0.02 if threat > 0.3 else -0.01},
            message=f"Drone imagery at ({action.location_x},{action.location_y}): threat={threat:.2f}.",
        )

    def _handle_evacuation(self, action: EvacuateZone) -> Reward:
        s = self._state
        assert s is not None

        zone = None
        for z in s.zones:
            if z.zone_id == action.zone_id:
                zone = z
                break

        if zone is None:
            return Reward(value=-0.05, message=f"Zone {action.zone_id} not found.")

        if zone.evacuated:
            return Reward(value=-0.02, message=f"Zone {action.zone_id} already evacuated.")

        if s.resource_status.evacuation_buses < 1:
            return Reward(value=-0.05, message="No evacuation buses available.")

        s.resource_status.evacuation_buses -= 1
        zone.evacuated = True
        s.evacuated_zones.append(zone.zone_id)

        reward_val = 0.0
        if zone.threat_level > 0.5:
            reward_val = 0.20
            s.lives_saved += zone.population
        elif zone.threat_level > 0.2:
            reward_val = 0.05
        else:
            reward_val = -0.05
            s.resources_wasted += 1

        return Reward(
            value=round(reward_val, 4),
            breakdown={"evacuation": reward_val},
            message=f"Evacuated zone {action.zone_id} (threat={zone.threat_level:.2f}, pop={zone.population}).",
        )

    def _handle_coordination(self, action: CoordinateWithAgency) -> Reward:
        s = self._state
        assert s is not None

        s.agency_coordinations.append({
            "agency": action.agency,
            "message": action.message,
            "step": str(s.step_count),
        })

        return Reward(
            value=0.03,
            breakdown={"coordination": 0.03},
            message=f"Coordinated with {action.agency}.",
        )

    def _handle_sitrep(self, action: UpdateSituationReport) -> Reward:
        s = self._state
        assert s is not None

        s.situation_reports.append(action.summary)

        return Reward(
            value=0.02,
            breakdown={"sitrep": 0.02},
            message="Situation report updated.",
        )

    def _handle_train_predictor(self, action: TrainPredictorModel) -> Reward:
        s = self._state
        assert s is not None

        grid_np = np.array(s.grid)
        metrics = _train_predictor(grid_np, epochs=action.epochs)

        s.predictor_metrics = PredictorMetrics(**metrics)
        s.predictor_trained = metrics.get("trained", False)

        auc = metrics.get("val_auc", 0.0)
        reward_val = 0.1 * auc  # reward proportional to AUC

        return Reward(
            value=round(reward_val, 4),
            breakdown={
                "predictor_auc": auc,
                "predictor_reward": reward_val,
            },
            message=f"Predictor trained: AUC={auc:.3f}, loss={metrics.get('train_loss', 0):.4f}.",
        )

    def _handle_submit_plan(self, action: SubmitFinalResponsePlan) -> Reward:
        s = self._state
        assert s is not None

        s.plan_submitted = True

        # Compute final bonus based on overall performance
        triage_accuracy = (
            s.correct_triages / max(1, s.total_triages)
        )
        total_reports = len(s.reports)
        coverage = len(s.processed_report_ids) / max(1, total_reports)

        grid_np = np.array(s.grid)
        avg_threat = float(np.mean(grid_np))
        impact_reduction = max(0, 1.0 - avg_threat)

        efficiency = max(0, 1.0 - s.resources_wasted / 20.0)

        # Final bonus
        final_score = (
            0.3 * triage_accuracy
            + 0.3 * coverage
            + 0.2 * impact_reduction
            + 0.2 * efficiency
        )
        final_score = max(0.0, min(1.0, final_score))
        bonus = 0.3 + 0.4 * final_score  # range [0.3, 0.7]

        return Reward(
            value=round(bonus, 4),
            breakdown={
                "triage_accuracy": triage_accuracy,
                "coverage": coverage,
                "impact_reduction": impact_reduction,
                "efficiency": efficiency,
                "final_score": final_score,
            },
            message=f"Final plan submitted. Score: {final_score:.3f}, Bonus: {bonus:.3f}.",
        )

    # -----------------------------------------------------------------------
    # Helpers
    # -----------------------------------------------------------------------

    def _make_observation(self) -> Observation:
        """Build an Observation from the current state."""
        s = self._state
        assert s is not None

        # Only show unprocessed reports in queue
        queue = [r for r in s.reports if r.report_id not in s.processed_report_ids]

        grid_np = np.array(s.grid)
        projected_impact = float(np.mean(grid_np[grid_np > 0.3])) if np.any(grid_np > 0.3) else 0.0

        return Observation(
            grid=s.grid,
            report_queue=queue,
            resource_status=s.resource_status,
            zones=s.zones,
            time_elapsed=s.time_elapsed,
            current_step=s.step_count,
            max_steps=s.max_steps,
            projected_impact=round(min(1.0, projected_impact), 3),
            disaster_type=s.disaster_type,
            predictor_metrics=s.predictor_metrics,
            score_so_far=round(s.total_reward, 4),
            messages=[],
        )
