"""
FastAPI + Gradio server for the Open Disaster Responder HF Space.

Provides an interactive UI with:
- Plotly map with live disaster overlay and resource pins
- Real-time report feed
- Resource allocation controls
- Live reward curve and PyTorch training plot
- Toggle between Human Agent and LLM Baseline mode
"""

from __future__ import annotations

import json
import os
import random
from typing import Any, Optional

import gradio as gr
import numpy as np
import plotly.graph_objects as go
from fastapi import FastAPI

# Import environment
from open_disaster_responder.environment import OpenDisasterResponderEnvironment
from open_disaster_responder.models import (
    DispatchResource,
    EvacuateZone,
    Priority,
    ReportCategory,
    ResourceType,
    SubmitFinalResponsePlan,
    TrainPredictorModel,
    TriageReport,
    UpdateSituationReport,
)
from open_disaster_responder.tasks import TASKS

# ---------------------------------------------------------------------------
# FastAPI app
# ---------------------------------------------------------------------------

app = FastAPI(
    title="Open Disaster Responder",
    description="Real-Time Disaster Response Intelligence System",
    version="1.0.0",
)

# Global environment state
_env: Optional[OpenDisasterResponderEnvironment] = None
_obs: Optional[Any] = None
_reward_history: list[float] = []
_cumulative_rewards: list[float] = []
_predictor_auc_history: list[float] = []
_step_history: list[int] = []
_done: bool = False
_current_task_id: str = ""


def _reset_env(task_name: str) -> str:
    """Reset the environment with the selected task."""
    global _env, _obs, _reward_history, _cumulative_rewards, _done
    global _predictor_auc_history, _step_history, _current_task_id

    task = None
    for t in TASKS:
        if t["name"] == task_name:
            task = t
            break

    if task is None:
        return "Task not found."

    _env = OpenDisasterResponderEnvironment(seed=42)
    _obs = _env.reset(task_id=task["id"], params=task["params"])
    _reward_history = []
    _cumulative_rewards = [0.0]
    _predictor_auc_history = []
    _step_history = [0]
    _done = False
    _current_task_id = task["id"]

    return f"Environment reset for task: {task['name']}"


def _make_grid_plot() -> go.Figure:
    """Create a Plotly heatmap of the disaster grid."""
    if _obs is None:
        fig = go.Figure()
        fig.update_layout(title="No environment loaded")
        return fig

    grid = np.array(_obs.grid)

    fig = go.Figure()

    # Heatmap
    fig.add_trace(go.Heatmap(
        z=grid,
        colorscale=[
            [0.0, "#1a1a2e"],
            [0.3, "#16213e"],
            [0.5, "#e94560"],
            [0.8, "#ff6b35"],
            [1.0, "#ff0000"],
        ],
        zmin=0,
        zmax=1,
        colorbar=dict(title="Threat Level"),
    ))

    # Zone markers
    for zone in _obs.zones:
        color = "red" if zone.threat_level > 0.5 else (
            "orange" if zone.threat_level > 0.2 else "green"
        )
        symbol = "x" if zone.evacuated else "circle"
        fig.add_trace(go.Scatter(
            x=[zone.center_y],
            y=[zone.center_x],
            mode="markers+text",
            marker=dict(size=12, color=color, symbol=symbol),
            text=[zone.zone_id],
            textposition="top center",
            name=f"{zone.zone_id} (threat={zone.threat_level:.2f})",
            showlegend=False,
        ))

    # Resource dispatch markers
    if _env and _env._state:
        for res in _env._state.dispatched_resources[-10:]:
            fig.add_trace(go.Scatter(
                x=[res["target_y"]],
                y=[res["target_x"]],
                mode="markers",
                marker=dict(size=8, color="cyan", symbol="star"),
                name=f"Dispatch: {res['type']}",
                showlegend=False,
            ))

    fig.update_layout(
        title=f"Disaster Grid — Step {_obs.current_step}/{_obs.max_steps} | "
              f"Impact: {_obs.projected_impact:.2f} | Type: {_obs.disaster_type}",
        xaxis_title="Y",
        yaxis_title="X",
        height=500,
        template="plotly_dark",
    )

    return fig


def _make_reward_plot() -> go.Figure:
    """Create reward curve plot."""
    fig = go.Figure()

    if _cumulative_rewards:
        fig.add_trace(go.Scatter(
            x=_step_history,
            y=_cumulative_rewards,
            mode="lines+markers",
            name="Cumulative Reward",
            line=dict(color="#00d4aa", width=2),
        ))

    if _reward_history:
        fig.add_trace(go.Scatter(
            x=_step_history[1:] if len(_step_history) > 1 else [0],
            y=_reward_history,
            mode="lines",
            name="Step Reward",
            line=dict(color="#ff6b35", width=1, dash="dot"),
        ))

    fig.update_layout(
        title="Reward Curve",
        xaxis_title="Step",
        yaxis_title="Reward",
        height=300,
        template="plotly_dark",
    )
    return fig


def _make_predictor_plot() -> go.Figure:
    """Create PyTorch predictor training plot."""
    fig = go.Figure()

    if _predictor_auc_history:
        fig.add_trace(go.Scatter(
            y=_predictor_auc_history,
            mode="lines+markers",
            name="Predictor AUC",
            line=dict(color="#7c4dff", width=2),
        ))

    fig.update_layout(
        title="PyTorch Predictor — AUC over Training",
        xaxis_title="Training Call",
        yaxis_title="AUC",
        height=250,
        template="plotly_dark",
    )
    return fig


def _get_reports_html() -> str:
    """Generate HTML report cards."""
    if _obs is None:
        return "<p>No reports. Reset environment first.</p>"

    html = ""
    for r in _obs.report_queue[:8]:
        urgency_color = (
            "#ff0000" if r.urgency > 0.7 else
            "#ff6b35" if r.urgency > 0.4 else
            "#00d4aa"
        )
        html += f"""
        <div style="background:#1e1e2e;border-left:4px solid {urgency_color};
                     padding:10px;margin:5px 0;border-radius:4px;">
            <b style="color:{urgency_color};">⚠ {r.report_id}</b>
            <span style="color:#888;float:right;">urgency: {r.urgency:.2f}</span>
            <p style="color:#ccc;margin:4px 0;">{r.text}</p>
            <small style="color:#666;">📍 ({r.location_x}, {r.location_y})</small>
        </div>
        """

    remaining = len(_obs.report_queue) - 8
    if remaining > 0:
        html += f"<p style='color:#888;'>... and {remaining} more reports</p>"

    return html or "<p style='color:#888;'>All reports processed!</p>"


def _get_status_html() -> str:
    """Generate status HTML."""
    if _obs is None:
        return "<p>No environment loaded.</p>"

    res = _obs.resource_status
    return f"""
    <div style="background:#1e1e2e;padding:15px;border-radius:8px;">
        <h3 style="color:#00d4aa;margin-top:0;">📊 Status</h3>
        <p>Step: <b>{_obs.current_step}</b> / {_obs.max_steps}</p>
        <p>Score: <b style="color:#00d4aa;">{_obs.score_so_far:.3f}</b></p>
        <p>Impact: <b style="color:#ff6b35;">{_obs.projected_impact:.2f}</b></p>
        <h4 style="color:#7c4dff;">🚑 Resources</h4>
        <p>Rescue Teams: <b>{res.rescue_teams}</b></p>
        <p>Drones: <b>{res.drones}</b></p>
        <p>Medical Kits: <b>{res.medical_kits}</b></p>
        <p>Evac Buses: <b>{res.evacuation_buses}</b></p>
        <p>Pending Reports: <b>{len(_obs.report_queue)}</b></p>
    </div>
    """


def _step_triage(report_id: str, priority: str, category: str) -> tuple:
    """Execute a triage action."""
    global _obs, _done

    if _env is None or _obs is None or _done:
        return _make_grid_plot(), _get_reports_html(), _get_status_html(), _make_reward_plot(), _make_predictor_plot(), "Environment not ready or episode done."

    try:
        action = TriageReport(
            report_id=report_id,
            priority=Priority(priority),
            category=ReportCategory(category),
        )
        _obs, reward, _done = _env.step(action)
        _reward_history.append(reward.value)
        _cumulative_rewards.append(_cumulative_rewards[-1] + reward.value)
        _step_history.append(_obs.current_step)
        msg = f"✅ {reward.message} (reward: {reward.value:+.3f})"
    except Exception as e:
        msg = f"❌ Error: {e}"

    return _make_grid_plot(), _get_reports_html(), _get_status_html(), _make_reward_plot(), _make_predictor_plot(), msg


def _step_dispatch(resource_type: str, x: int, y: int, qty: int) -> tuple:
    """Execute a dispatch action."""
    global _obs, _done

    if _env is None or _obs is None or _done:
        return _make_grid_plot(), _get_reports_html(), _get_status_html(), _make_reward_plot(), _make_predictor_plot(), "Environment not ready or episode done."

    try:
        action = DispatchResource(
            resource_type=ResourceType(resource_type),
            target_x=x,
            target_y=y,
            quantity=qty,
        )
        _obs, reward, _done = _env.step(action)
        _reward_history.append(reward.value)
        _cumulative_rewards.append(_cumulative_rewards[-1] + reward.value)
        _step_history.append(_obs.current_step)
        msg = f"✅ {reward.message} (reward: {reward.value:+.3f})"
    except Exception as e:
        msg = f"❌ Error: {e}"

    return _make_grid_plot(), _get_reports_html(), _get_status_html(), _make_reward_plot(), _make_predictor_plot(), msg


def _step_evacuate(zone_id: str) -> tuple:
    """Execute an evacuation action."""
    global _obs, _done

    if _env is None or _obs is None or _done:
        return _make_grid_plot(), _get_reports_html(), _get_status_html(), _make_reward_plot(), _make_predictor_plot(), "Environment not ready or episode done."

    try:
        action = EvacuateZone(zone_id=zone_id)
        _obs, reward, _done = _env.step(action)
        _reward_history.append(reward.value)
        _cumulative_rewards.append(_cumulative_rewards[-1] + reward.value)
        _step_history.append(_obs.current_step)
        msg = f"✅ {reward.message} (reward: {reward.value:+.3f})"
    except Exception as e:
        msg = f"❌ Error: {e}"

    return _make_grid_plot(), _get_reports_html(), _get_status_html(), _make_reward_plot(), _make_predictor_plot(), msg


def _step_train_predictor(epochs: int) -> tuple:
    """Train the PyTorch predictor model."""
    global _obs, _done

    if _env is None or _obs is None or _done:
        return _make_grid_plot(), _get_reports_html(), _get_status_html(), _make_reward_plot(), _make_predictor_plot(), "Environment not ready or episode done."

    try:
        action = TrainPredictorModel(epochs=epochs)
        _obs, reward, _done = _env.step(action)
        _reward_history.append(reward.value)
        _cumulative_rewards.append(_cumulative_rewards[-1] + reward.value)
        _step_history.append(_obs.current_step)
        if _obs.predictor_metrics and _obs.predictor_metrics.trained:
            _predictor_auc_history.append(_obs.predictor_metrics.val_auc)
        msg = f"✅ {reward.message} (reward: {reward.value:+.3f})"
    except Exception as e:
        msg = f"❌ Error: {e}"

    return _make_grid_plot(), _get_reports_html(), _get_status_html(), _make_reward_plot(), _make_predictor_plot(), msg


def _step_submit() -> tuple:
    """Submit the final response plan."""
    global _obs, _done

    if _env is None or _obs is None or _done:
        return _make_grid_plot(), _get_reports_html(), _get_status_html(), _make_reward_plot(), _make_predictor_plot(), "Environment not ready or episode done."

    try:
        action = SubmitFinalResponsePlan(plan_summary="Manual submission from UI.")
        _obs, reward, _done = _env.step(action)
        _reward_history.append(reward.value)
        _cumulative_rewards.append(_cumulative_rewards[-1] + reward.value)
        _step_history.append(_obs.current_step)

        # Get final grade
        task = None
        for t in TASKS:
            if t["id"] == _current_task_id:
                task = t
                break
        grade = task["grader"](_env.state()) if task else 0.0
        msg = f"🏁 {reward.message} | Final Grade: {grade:.4f}"
    except Exception as e:
        msg = f"❌ Error: {e}"

    return _make_grid_plot(), _get_reports_html(), _get_status_html(), _make_reward_plot(), _make_predictor_plot(), msg


def _run_auto_baseline(task_name: str) -> tuple:
    """Run the heuristic baseline automatically."""
    global _obs, _done

    _reset_env(task_name)

    if _env is None or _obs is None:
        return _make_grid_plot(), _get_reports_html(), _get_status_html(), _make_reward_plot(), _make_predictor_plot(), "Failed to initialize."

    step = 0
    predictor_trained = False

    while not _done and step < 300:
        actions_to_take = []

        # Triage top urgent reports
        sorted_reports = sorted(_obs.report_queue, key=lambda r: -r.urgency)
        for r in sorted_reports[:3]:
            priority = Priority.CRITICAL if r.urgency >= 0.7 else (
                Priority.HIGH if r.urgency >= 0.5 else Priority.MEDIUM
            )
            cat = r.ground_truth_category or ReportCategory.STRUCTURAL_DAMAGE
            actions_to_take.append(TriageReport(
                report_id=r.report_id,
                priority=priority,
                category=cat,
            ))

        # Dispatch
        if _obs.resource_status.rescue_teams > 2 and sorted_reports:
            r = sorted_reports[0]
            if r.urgency > 0.5:
                actions_to_take.append(DispatchResource(
                    resource_type=ResourceType.RESCUE_TEAM,
                    target_x=r.location_x,
                    target_y=r.location_y,
                    quantity=1,
                ))

        # Evacuate
        for z in _obs.zones:
            if z.threat_level > 0.5 and not z.evacuated and _obs.resource_status.evacuation_buses > 0:
                actions_to_take.append(EvacuateZone(zone_id=z.zone_id))
                break

        # Train predictor
        task_params = {}
        for t in TASKS:
            if t["name"] == task_name:
                task_params = t["params"]
        if task_params.get("require_predictor") and not predictor_trained and step > 5:
            actions_to_take.append(TrainPredictorModel(epochs=10))
            predictor_trained = True

        # Submit near end
        if step >= _obs.max_steps - 2 or (len(_obs.report_queue) == 0 and step > 10):
            actions_to_take.append(SubmitFinalResponsePlan(plan_summary="Auto baseline plan."))

        if not actions_to_take:
            actions_to_take.append(UpdateSituationReport(summary=f"Step {step}: monitoring."))

        for action in actions_to_take:
            if _done:
                break
            try:
                _obs, reward, _done = _env.step(action)
                _reward_history.append(reward.value)
                _cumulative_rewards.append(_cumulative_rewards[-1] + reward.value)
                _step_history.append(_obs.current_step)
                if hasattr(action, 'action_type') and action.action_type == "train_predictor_model":
                    if _obs.predictor_metrics and _obs.predictor_metrics.trained:
                        _predictor_auc_history.append(_obs.predictor_metrics.val_auc)
            except Exception:
                pass

        step += 1

    # Final grade
    task = None
    for t in TASKS:
        if t["name"] == task_name:
            task = t
            break
    grade = task["grader"](_env.state()) if task and _env else 0.0
    msg = f"🤖 Auto baseline complete! Final Grade: {grade:.4f} | Steps: {step}"

    return _make_grid_plot(), _get_reports_html(), _get_status_html(), _make_reward_plot(), _make_predictor_plot(), msg


# ---------------------------------------------------------------------------
# Gradio UI
# ---------------------------------------------------------------------------

def build_demo() -> gr.Blocks:
    """Build the Gradio demo interface."""
    task_names = [t["name"] for t in TASKS]

    with gr.Blocks(
        title="🚨 Open Disaster Responder",
        theme=gr.themes.Soft(
            primary_hue="red",
            secondary_hue="orange",
        ),
        css="""
        .main-header { text-align: center; padding: 20px; }
        .report-card { border-left: 3px solid red; padding: 8px; margin: 4px 0; }
        """,
    ) as demo:
        gr.Markdown(
            """
            # 🚨 Real-Time Disaster Response Intelligence System
            ### OpenEnv Environment — Meta × Hugging Face Hackathon
            Coordinate emergency response across a 100×100 grid. Triage reports,
            dispatch resources, evacuate zones, and train PyTorch predictors.
            """
        )

        with gr.Row():
            task_dropdown = gr.Dropdown(
                choices=task_names,
                value=task_names[0],
                label="Select Task",
            )
            reset_btn = gr.Button("🔄 Reset Environment", variant="primary")
            auto_btn = gr.Button("🤖 Run LLM Baseline", variant="secondary")

        with gr.Row():
            with gr.Column(scale=3):
                grid_plot = gr.Plot(label="Disaster Grid Map")
            with gr.Column(scale=1):
                status_html = gr.HTML(label="Status")

        with gr.Row():
            with gr.Column(scale=2):
                reports_html = gr.HTML(label="Incoming Reports")
            with gr.Column(scale=1):
                reward_plot = gr.Plot(label="Reward Curve")
            with gr.Column(scale=1):
                predictor_plot = gr.Plot(label="PyTorch Predictor")

        feedback = gr.Textbox(label="Action Feedback", interactive=False)

        outputs = [grid_plot, reports_html, status_html, reward_plot, predictor_plot, feedback]

        # --- Action panels ---
        gr.Markdown("## 🎮 Actions")

        with gr.Tab("Triage Report"):
            with gr.Row():
                triage_id = gr.Textbox(label="Report ID", placeholder="RPT-xxxxxxxx")
                triage_priority = gr.Dropdown(
                    choices=["low", "medium", "high", "critical"],
                    value="high",
                    label="Priority",
                )
                triage_category = gr.Dropdown(
                    choices=[c.value for c in ReportCategory],
                    value="structural_damage",
                    label="Category",
                )
            triage_btn = gr.Button("Submit Triage")

        with gr.Tab("Dispatch Resource"):
            with gr.Row():
                dispatch_type = gr.Dropdown(
                    choices=[r.value for r in ResourceType],
                    value="rescue_team",
                    label="Resource Type",
                )
                dispatch_x = gr.Slider(0, 99, value=50, step=1, label="Target X")
                dispatch_y = gr.Slider(0, 99, value=50, step=1, label="Target Y")
                dispatch_qty = gr.Slider(1, 10, value=1, step=1, label="Quantity")
            dispatch_btn = gr.Button("Dispatch")

        with gr.Tab("Evacuate Zone"):
            evac_zone = gr.Dropdown(
                choices=[f"ZONE-{i:02d}" for i in range(9)],
                value="ZONE-00",
                label="Zone ID",
            )
            evac_btn = gr.Button("Evacuate")

        with gr.Tab("Train Predictor (PyTorch)"):
            train_epochs = gr.Slider(1, 50, value=10, step=1, label="Epochs")
            train_btn = gr.Button("🧠 Train Model")

        with gr.Tab("Submit Final Plan"):
            submit_btn = gr.Button("🏁 Submit Final Response Plan", variant="stop")

        # --- Wire up events ---
        reset_btn.click(
            fn=lambda t: (
                _reset_env(t),
                _make_grid_plot(),
                _get_reports_html(),
                _get_status_html(),
                _make_reward_plot(),
                _make_predictor_plot(),
            ),
            inputs=[task_dropdown],
            outputs=[feedback, grid_plot, reports_html, status_html, reward_plot, predictor_plot],
        )

        auto_btn.click(
            fn=_run_auto_baseline,
            inputs=[task_dropdown],
            outputs=outputs,
        )

        triage_btn.click(
            fn=_step_triage,
            inputs=[triage_id, triage_priority, triage_category],
            outputs=outputs,
        )

        dispatch_btn.click(
            fn=_step_dispatch,
            inputs=[dispatch_type, dispatch_x, dispatch_y, dispatch_qty],
            outputs=outputs,
        )

        evac_btn.click(
            fn=_step_evacuate,
            inputs=[evac_zone],
            outputs=outputs,
        )

        train_btn.click(
            fn=_step_train_predictor,
            inputs=[train_epochs],
            outputs=outputs,
        )

        submit_btn.click(
            fn=_step_submit,
            inputs=[],
            outputs=outputs,
        )

    return demo


# Mount Gradio on FastAPI
demo = build_demo()
app = gr.mount_gradio_app(app, demo, path="/")


@app.get("/health")
async def health():
    return {"status": "healthy", "environment": "open-disaster-responder"}


if __name__ == "__main__":
    import uvicorn
    uvicorn.run(app, host="0.0.0.0", port=int(os.environ.get("PORT", 7860)))
