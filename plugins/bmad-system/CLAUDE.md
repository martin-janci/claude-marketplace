# BMAD System

BMAD (Build-Monitor-Analyze-Develop) autonomous orchestration framework for multi-agent workflows.

## Agents

| Agent | Description |
|-------|-------------|
| `bmad-orchestrator` | Main BMAD orchestration controller |
| `bmad-planner` | BMAD planning and strategy |
| `orchestrator-controller` | Orchestrator management |
| `agent-organizer` | Agent coordination |
| `multi-agent-coordinator` | Multi-agent management |
| `workflow-orchestrator` | Workflow coordination |

## BMAD Team Agents (_bmad/bmm/agents/)

| Agent | Role |
|-------|------|
| `analyst` | Business analysis |
| `architect` | System architecture |
| `dev` | Development |
| `pm` | Product management |
| `sm` | Scrum master |
| `tea` | Testing and QA |
| `tech-writer` | Technical documentation |
| `ux-designer` | UX design |
| `quick-flow-solo-dev` | Solo developer workflow |

## Skills

- **bmad-autopilot/** - Autonomous BMAD development
- **orchestrator-control/** - Orchestrator management
- **subagent-driven-development/** - Subagent orchestration

## Commands

- `/bmad` - Run BMAD Autopilot autonomous development
- `/bmad-full` - Full cycle: gap research → create epics → implement loop (requires claude-auto-agents)
- `/bmad-loop` - Run BMAD epics in autonomous loop (requires claude-auto-agents plugin)
- `/epics-parallel` - Run 2-4 epics in parallel using git worktrees
- `/bmad/*` - Nested BMAD commands for team workflows

## Usage

Start BMAD autonomous development:
```
/bmad "implement the user dashboard feature"
```

Spawn orchestration agents:
```
/spawn bmad-orchestrator "coordinate feature development"
/spawn multi-agent-coordinator "manage the review pipeline"
```

Run epics in autonomous loop (requires claude-auto-agents):
```
/bmad-loop "7A 8A"
/bmad-loop "sprint-12.*"
```

Full autonomous cycle (research → epics → implement):
```
/bmad-full "implement user authentication"
```

Run multiple epics in parallel (2-4 epics):
```
/epics-parallel "7A" "8A" "9A"
```
