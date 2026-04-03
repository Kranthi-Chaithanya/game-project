"""
Pydantic models for the Open Disaster Responder environment.

Defines Observation, Action (discriminated union), Reward, and State models.
"""

from __future__ import annotations

from enum import Enum
from typing import Annotated, Any, Literal, Optional, Union

from pydantic import BaseModel, Field


# ---------------------------------------------------------------------------
# Enums
# ---------------------------------------------------------------------------

class DisasterType(str, Enum):
    EARTHQUAKE = "earthquake"
    FLOOD = "flood"
    FIRE = "fire"
    WILDFIRE = "wildfire"
    MULTI = "multi"


class ResourceType(str, Enum):
    RESCUE_TEAM = "rescue_team"
    DRONE = "drone"
    MEDICAL_KIT = "medical_kit"
    EVACUATION_BUS = "evacuation_bus"


class Priority(str, Enum):
    LOW = "low"
    MEDIUM = "medium"
    HIGH = "high"
    CRITICAL = "critical"


class ReportCategory(str, Enum):
    STRUCTURAL_DAMAGE = "structural_damage"
    TRAPPED_PEOPLE = "trapped_people"
    MEDICAL_EMERGENCY = "medical_emergency"
    FIRE_HAZARD = "fire_hazard"
    FLOOD_WATER = "flood_water"
    ROAD_BLOCKED = "road_blocked"
    UTILITY_FAILURE = "utility_failure"
    EVACUATION_NEEDED = "evacuation_needed"


# ---------------------------------------------------------------------------
# Sub-models
# ---------------------------------------------------------------------------

class CrisisReport(BaseModel):
    """An incoming crisis report from the field."""
    report_id: str
    text: str
    location_x: int = Field(ge=0, le=99)
    location_y: int = Field(ge=0, le=99)
    image_url: Optional[str] = None
    urgency: float = Field(ge=0.0, le=1.0)
    timestamp: float
    ground_truth_priority: Optional[Priority] = None
    ground_truth_category: Optional[ReportCategory] = None


class ResourceStatus(BaseModel):
    """Current status of available resources."""
    rescue_teams: int = Field(ge=0)
    drones: int = Field(ge=0)
    medical_kits: int = Field(ge=0)
    evacuation_buses: int = Field(ge=0)
    deployed_resources: list[dict[str, Any]] = Field(default_factory=list)


class ZoneInfo(BaseModel):
    """Information about a geographic zone."""
    zone_id: str
    center_x: int
    center_y: int
    radius: int
    population: int
    threat_level: float = Field(ge=0.0, le=1.0)
    evacuated: bool = False


class PredictorMetrics(BaseModel):
    """Metrics from the PyTorch predictor model training."""
    trained: bool = False
    epochs_completed: int = 0
    train_loss: float = 0.0
    val_auc: float = 0.0
    predictions: list[list[float]] = Field(default_factory=list)


# ---------------------------------------------------------------------------
# Observation
# ---------------------------------------------------------------------------

class Observation(BaseModel):
    """What the agent observes at each step."""
    grid: list[list[float]] = Field(
        description="100x100 grid representing the disaster region. "
        "Values: 0=clear, 0.1-0.5=low threat, 0.5-0.8=medium, 0.8-1.0=critical."
    )
    report_queue: list[CrisisReport] = Field(
        description="Queue of incoming crisis reports to process."
    )
    resource_status: ResourceStatus
    zones: list[ZoneInfo] = Field(default_factory=list)
    time_elapsed: float = Field(ge=0.0)
    current_step: int = Field(ge=0)
    max_steps: int
    projected_impact: float = Field(
        ge=0.0, le=1.0,
        description="Estimated overall disaster impact (0=none, 1=catastrophic)."
    )
    disaster_type: str
    predictor_metrics: Optional[PredictorMetrics] = None
    score_so_far: float = 0.0
    messages: list[str] = Field(
        default_factory=list,
        description="System messages and feedback from previous actions."
    )


# ---------------------------------------------------------------------------
# Actions (discriminated union)
# ---------------------------------------------------------------------------

class TriageReport(BaseModel):
    """Triage an incoming crisis report by assigning priority and category."""
    action_type: Literal["triage_report"] = "triage_report"
    report_id: str
    priority: Priority
    category: ReportCategory


class DispatchResource(BaseModel):
    """Dispatch a resource to a target location."""
    action_type: Literal["dispatch_resource"] = "dispatch_resource"
    resource_type: ResourceType
    target_x: int = Field(ge=0, le=99)
    target_y: int = Field(ge=0, le=99)
    quantity: int = Field(ge=1, le=10)


class RequestDroneImagery(BaseModel):
    """Request drone imagery for a location."""
    action_type: Literal["request_drone_imagery"] = "request_drone_imagery"
    location_x: int = Field(ge=0, le=99)
    location_y: int = Field(ge=0, le=99)


class EvacuateZone(BaseModel):
    """Evacuate a zone of the disaster region."""
    action_type: Literal["evacuate_zone"] = "evacuate_zone"
    zone_id: str


class CoordinateWithAgency(BaseModel):
    """Coordinate with an external agency."""
    action_type: Literal["coordinate_with_agency"] = "coordinate_with_agency"
    agency: str
    message: str


class UpdateSituationReport(BaseModel):
    """Update the overall situation report summary."""
    action_type: Literal["update_situation_report"] = "update_situation_report"
    summary: str


class TrainPredictorModel(BaseModel):
    """Train a PyTorch predictor model for disaster spread forecasting."""
    action_type: Literal["train_predictor_model"] = "train_predictor_model"
    epochs: int = Field(ge=1, le=50, default=5)


class SubmitFinalResponsePlan(BaseModel):
    """Submit the final response plan, ending the episode."""
    action_type: Literal["submit_final_response_plan"] = "submit_final_response_plan"
    plan_summary: str = ""


# Discriminated union of all actions
Action = Annotated[
    Union[
        TriageReport,
        DispatchResource,
        RequestDroneImagery,
        EvacuateZone,
        CoordinateWithAgency,
        UpdateSituationReport,
        TrainPredictorModel,
        SubmitFinalResponsePlan,
    ],
    Field(discriminator="action_type"),
]


# ---------------------------------------------------------------------------
# Reward
# ---------------------------------------------------------------------------

class Reward(BaseModel):
    """Reward signal returned after each action."""
    value: float = Field(
        description="Dense reward in range [-1.0, 1.0]."
    )
    breakdown: dict[str, float] = Field(
        default_factory=dict,
        description="Breakdown of reward components."
    )
    message: str = ""


# ---------------------------------------------------------------------------
# State
# ---------------------------------------------------------------------------

class State(BaseModel):
    """Full internal state of the environment (for serialization)."""
    grid: list[list[float]]
    reports: list[CrisisReport]
    triaged_reports: dict[str, dict[str, str]] = Field(default_factory=dict)
    resource_status: ResourceStatus
    zones: list[ZoneInfo]
    step_count: int = 0
    max_steps: int = 50
    time_elapsed: float = 0.0
    disaster_type: str = "earthquake"
    total_reward: float = 0.0
    done: bool = False
    dispatched_resources: list[dict[str, Any]] = Field(default_factory=list)
    drone_requests: list[dict[str, Any]] = Field(default_factory=list)
    evacuated_zones: list[str] = Field(default_factory=list)
    agency_coordinations: list[dict[str, str]] = Field(default_factory=list)
    situation_reports: list[str] = Field(default_factory=list)
    predictor_metrics: PredictorMetrics = Field(default_factory=PredictorMetrics)
    pending_reports: list[CrisisReport] = Field(default_factory=list)
    processed_report_ids: set[str] = Field(default_factory=set)
    correct_triages: int = 0
    total_triages: int = 0
    lives_saved: int = 0
    resources_wasted: int = 0
    critical_reports_missed: int = 0
    delay_penalties: float = 0.0
    plan_submitted: bool = False
    predictor_trained: bool = False

    class Config:
        arbitrary_types_allowed = True
