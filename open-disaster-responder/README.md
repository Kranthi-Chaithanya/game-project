# 🚨 Open Disaster Responder

## Real-Time Disaster Response Intelligence System

An OpenEnv environment for the **Meta × Hugging Face OpenEnv Hackathon** that simulates real-time disaster response coordination. Agents must triage crisis reports, dispatch emergency resources, coordinate evacuations, and train predictive models — all on a dynamic 100×100 grid with evolving disaster conditions.

---

## 🌍 Motivation

Natural disasters kill thousands and displace millions every year. Effective emergency response requires rapid decision-making under uncertainty: triaging reports, allocating scarce resources, and predicting how disasters evolve. This environment provides a rich, multimodal testbed for AI agents to develop and demonstrate disaster response capabilities using real crisis data patterns.

---

## 🏗️ Environment Design

### State Space
- **100×100 grid** (NumPy array) representing a geographic region
- **Cellular automata** disaster evolution (fire spread, flood rise, aftershocks)
- **Resource pool**: rescue teams, drones, medical kits, evacuation buses
- **Live incoming reports queue** with text, location, urgency, and optional images

### Data Source
- Crisis report patterns inspired by **QCRI/CrisisMMD** dataset
- Synthetic multimodal tweets with location and urgency metadata
- Loaded at `reset()` with configurable disaster scenarios

### Observation Space (Pydantic model)
| Field | Type | Description |
|-------|------|-------------|
| `grid` | `list[list[float]]` | 100×100 threat level grid (0=clear, 1=critical) |
| `report_queue` | `list[CrisisReport]` | Pending crisis reports with text, location, urgency |
| `resource_status` | `ResourceStatus` | Available rescue teams, drones, kits, buses |
| `zones` | `list[ZoneInfo]` | Geographic zones with threat levels and population |
| `time_elapsed` | `float` | Simulation time |
| `projected_impact` | `float` | Overall disaster impact estimate (0–1) |
| `predictor_metrics` | `PredictorMetrics` | PyTorch model training metrics (if applicable) |

### Action Space (Discriminated Union)

| Action | Description |
|--------|-------------|
| `TriageReport` | Assign priority (low/medium/high/critical) and category to a report |
| `DispatchResource` | Send rescue team/drone/medical kit/bus to a grid location |
| `RequestDroneImagery` | Scout a location with a drone |
| `EvacuateZone` | Evacuate a population zone |
| `CoordinateWithAgency` | Send coordination message to an agency |
| `UpdateSituationReport` | Update the overall situation summary |
| `TrainPredictorModel` | Train a PyTorch MLP for disaster spread prediction |
| `SubmitFinalResponsePlan` | End the episode with a final plan |

### Reward (Dense)
- **+0.15** correct triage priority/category
- **+0.25** life-saving dispatch to high-threat areas
- **+0.20** efficient resource allocation
- **+0.30–0.70** final bonus based on mission score
- **Penalties** for delays, resource waste, missed critical reports

### Episode Length
- 50–200 steps depending on task, or until `SubmitFinalResponsePlan`

---

## 📋 Tasks

### 1. Easy: Single Disaster — Earthquake Response
- **Scenario**: Single earthquake, ~30 incoming reports
- **Grader**: 60% critical reports handled + 20% triage accuracy + 20% no waste
- **Max Steps**: 50

### 2. Medium: Multi-Incident — Flood & Fire Response
- **Scenario**: Simultaneous flood + fire, ~80 reports
- **Grader**: 40% weighted coverage + 30% impact reduction + 30% efficiency
- **Max Steps**: 100

### 3. Hard: Evolving Wildfire with Predictive Modeling
- **Scenario**: Large evolving wildfire, ~120 reports, high uncertainty
- **Requires**: `TrainPredictorModel` to forecast spread with PyTorch MLP
- **Grader**: 40% triage quality + 40% PyTorch model AUC + 20% efficiency
- **Max Steps**: 200

---

## 🤗 HF + 🔥 PyTorch Integration

### Hugging Face
- **datasets**: Crisis report data patterns from CrisisMMD
- **sentence-transformers**: Report embedding and similarity matching

### PyTorch
- **Hard task**: Train a small `torch.nn` MLP (2–3 layers) on-the-fly
- Predicts disaster spread probability across the grid
- AUC score directly contributes to the task grade (40%)
- Training progress visible in reward signal and UI

---

## 🚀 Setup & Running

### Local Development

```bash
# Clone and install
cd open-disaster-responder
pip install -r requirements.txt

# Run baseline (heuristic mode)
python baseline.py

# Run baseline with LLM
export OPENAI_API_KEY=your-key-here
python baseline.py

# Start the UI server
python -m server.app
# Open http://localhost:7860
```

### Docker

```bash
# Build
docker build -t open-disaster-responder .

# Run
docker run -p 7860:7860 open-disaster-responder

# With LLM baseline
docker run -p 7860:7860 -e OPENAI_API_KEY=your-key open-disaster-responder
```

### HF Spaces

Deploy to Hugging Face Spaces using the included Dockerfile. The Gradio UI will be available at your Space URL.

---

## 📊 Baseline Scores

| Task | Heuristic Baseline | LLM Baseline (GPT-4o-mini) |
|------|-------------------|---------------------------|
| Easy (Earthquake) | ~0.55 | ~0.70 |
| Medium (Multi-incident) | ~0.45 | ~0.60 |
| Hard (Wildfire + PyTorch) | ~0.35 | ~0.55 |

*Scores are approximate and may vary with seed.*

---

## 📁 Project Structure

```
open-disaster-responder/
├── __init__.py          # Package init
├── models.py            # Pydantic models (Observation, Action, Reward, State)
├── environment.py       # Main environment (step, reset, state, close)
├── tasks.py             # 3 tasks with deterministic graders
├── baseline.py          # Inference script (OpenAI + heuristic)
├── server/
│   ├── __init__.py
│   └── app.py           # FastAPI + Gradio HF Space UI
├── openenv.yaml         # Environment metadata + task definitions
├── pyproject.toml       # Project configuration
├── requirements.txt     # Python dependencies
├── Dockerfile           # Docker build for HF Spaces
├── .dockerignore
└── README.md            # This file
```

---

## 🔧 OpenEnv Validation

```bash
openenv validate
```

The environment passes all OpenEnv validation checks:
- ✅ Valid `openenv.yaml` with metadata and tasks
- ✅ Pydantic models for Observation, Action, Reward, State
- ✅ Environment class with `reset()`, `step()`, `state()`, `close()`
- ✅ Deterministic graders returning 0.0–1.0
- ✅ Dockerfile compatible with `openenv build`
- ✅ Baseline script with reproducible scores

---

## 📜 License

MIT License
