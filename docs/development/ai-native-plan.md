# Yojana AI-Native — Implementation Plan

## Vision

Make Yojana an AI-native project management platform — powered by local LLMs via Ollama, with zero dependency on cloud AI providers. AI features are split into free (community) and enterprise tiers.

## Architecture

```
┌─────────────────────────────────────────┐
│              Ollama (sidecar)            │
│  ┌──────────┐  ┌──────────┐  ┌───────┐ │
│  │ Llama3.2 │  │ Qwen2.5  │  │ etc.  │ │
│  │  (3B)    │  │          │  │       │ │
│  └──────────┘  └──────────┘  └───────┘ │
│         REST API (localhost:11434)       │
└─────────────┬───────────────────────────┘
              │
┌─────────────▼───────────────────────────┐
│          Yojana Rails App                │
│                                          │
│  ┌────────────────────────────────────┐  │
│  │   modules/ai/  (plugin module)     │  │
│  │  ┌─────────┐ ┌──────────────────┐  │  │
│  │  │ LLM     │ │ Tools/Function   │  │  │
│  │  │ Client  │ │ Calling          │  │  │
│  │  └─────────┘ └──────────────────┘  │  │
│  │  ┌─────────┐ ┌──────────────────┐  │  │
│  │  │ Chat    │ │ Inline AI        │  │  │
│  │  │ Engine  │ │ Features (free)  │  │  │
│  │  └─────────┘ └──────────────────┘  │  │
│  │  ┌──────────────────────────────┐  │  │
│  │  │  AI Agents (enterprise)      │  │  │
│  │  └──────────────────────────────┘  │  │
│  └────────────────────────────────────┘  │
└──────────────────────────────────────────┘
```

## Tiers

| Tier | Features |
|---|---|
| **Free (Community)** | NL search bar, smart autofill, work package summarization, sprint suggestions |
| **Enterprise** | AI chat assistant, scheduled agents, meeting minutes generator, portfolio insights |

## Build Order

**Phase 1 (Foundation)** → **Phase 3 (Chat/Enterprise)** → **Phase 2 (Inline/Free)** → **Phase 4 (Agents)**

---

## Phase 1 — Foundation

### 1a. Module Scaffold

`modules/ai/` — Rails Engine following existing plugin conventions.

**File structure:**
```
modules/ai/
├── app/
│   ├── components/          # Primer ViewComponents
│   ├── controllers/         # Rails controllers
│   ├── models/              # ActiveRecord models
│   ├── services/            # Business logic
│   └── views/               # ERB templates
├── config/
│   ├── locales/             # Translations
│   └── routes.rb            # Routes
├── frontend/
│   └── src/stimulus/controllers/
├── lib/
│   └── ai/engine.rb
├── db/migrate/
├── ai.gemspec
└── spec/
```

### 1b. Feature Flags

```ruby
# config/initializers/feature_decisions.rb
OpenProject::FeatureDecisions.add :ai_chat_assistant     # enterprise
OpenProject::FeatureDecisions.add :ai_inline_features     # free
OpenProject::FeatureDecisions.add :ai_agents              # enterprise
```

### 1c. Models

- **`Ai::Conversation`** — `belongs_to :user`, `belongs_to :project` (optional), `title`
- **`Ai::Message`** — `belongs_to :conversation`, `role` (user/assistant/tool), `content`, `tool_calls` (JSONB)
- **`Ai::Setting`** — singleton config: `ollama_endpoint` (default: `http://localhost:11434`), `default_model` (default: `llama3.2:3b`), `max_tokens`, `temperature`

### 1d. Ollama Client

**`Ai::LlmClient`** service — Faraday-based HTTP client for Ollama REST API.

- `chat(messages, tools, stream:)` — calls `/api/chat` endpoint
- `embed(text)` — calls `/api/embed` endpoint
- Streaming support via block/yield
- Handles errors: connection refused, model not found, timeout
- Compatible with OpenAI API format for future provider flexibility

### 1e. Bundled Docker Setup

Add to `docker-compose.yml`:

```yaml
ollama:
  image: ollama/ollama
  restart: unless-stopped
  volumes:
    - ollama_data:/root/.ollama
  ports:
    - "11434:11434"

volumes:
  ollama_data:
```

Rake task `ai:setup` — pulls `llama3.2:3b` model.

Graceful degradation — all AI features rescue connection errors and display "AI unavailable".

---

## Phase 2 — AI Chat Assistant (Enterprise)

### 2a. Chat Engine

**`Ai::ChatService`** — orchestrates conversations.

- Loads message history
- Builds system prompt with context (current project, user permissions)
- Calls `LlmClient.chat` with streaming
- Handles tool call loops (LLM → tool → LLM → response)

**System prompt includes:**
- User's name, role, permissions
- Current project context
- Available tools with descriptions
- Yojana data model overview (work packages, projects, etc.)

### 2b. Tool System

Each tool is a class with a standard interface:

```ruby
class Ai::Tools::SearchWorkPackages < Ai::Tools::Base
  def name        = "search_work_packages"
  def description = "Search work packages using natural language filters"
  def parameters_schema = { ... }  # JSON Schema
  def execute(params)              # calls API v3
end
```

**Planned tools:**

| Tool | Description |
|---|---|
| `search_work_packages` | NL → structured filters → API v3 query |
| `create_work_package` | Create work package from natural language |
| `update_work_package` | Update fields of existing work package |
| `get_project_info` | Get project details, status, members |
| `get_user_tasks` | Get tasks assigned to current user |
| `list_projects` | List projects user has access to |

### 2c. Streaming Architecture

```
User message → Ai::Message(role: user)
  → SSE endpoint: GET /ai/chat/:id/stream
    → Rails streams tokens from Ollama via ActionController::Live
    → Stimulus appends tokens to chat UI in real-time
    → If tool call: pause stream, execute tool, send result back to LLM
    → Continue streaming final response
    → Save Ai::Message(role: assistant)
```

### 2d. Tool Calling Flow

```
User: "Create a bug for the login page"
  → LLM: tool_call("create_work_package", { type: "Bug", subject: "..." })
  → Rails: validates, creates, returns work package ID
  → LLM: "Done! Created bug #456"
  → User sees response in chat
```

### 2e. Frontend — Stimulus Controller

**`ai-chat-controller.ts`**
- Slide-out panel (toggle from navbar)
- Markdown message rendering
- Real-time SSE streaming
- Conversation history sidebar
- Typing indicator
- Tool call visual feedback ("Creating work package...")

---

## Phase 3 — Inline AI Features (Free)

| Feature | Behavior |
|---|---|
| **NL Quick Search** | Search bar takes natural language. LLM parses to structured filters → API v3. Fallback to keyword search if LLM unavailable. |
| **Smart Autofill** | On work package create/edit: title field → LLM suggests type, priority, assignee. Shown as suggestion pills. |
| **Summarize** | Button on work package detail page → 2-line LLM summary of description/notes |
| **Sprint Suggestions** | Suggest work packages for next sprint based on priority, dependencies, workload |

---

## Phase 4 — AI Agents (Enterprise)

| Feature | Behavior |
|---|---|
| **Scheduled agents** | Cron-backed GoodJob tasks. E.g.: "Check overdue tasks daily at 9 AM, notify assignees" |
| **Meeting minutes** | Raw notes → LLM → structured minutes with action items. Integrates with Meeting model. |
| **Portfolio insights** | Analyze project health (status, budget, timeline). Generate natural language risk summaries. |
| **Custom tools** | Admin-defined tools (webhooks, custom queries) the AI can invoke. |

---

## Key Technical Decisions

| Aspect | Decision | Rationale |
|---|---|---|
| **AI provider** | Ollama (local-first) | Free, private, no API keys. Compatible with OpenAI API format for future flexibility. |
| **Default model** | `llama3.2:3b` | ~3GB RAM, good tool calling, runs on most hardware |
| **LLM SDK** | Faraday HTTP (no gem) | Full control, no external dependency maintenance |
| **Streaming** | SSE via ActionController::Live | Real-time tokens without WebSocket complexity |
| **Tool calling** | Ollama native tool API | Supported in llama3.2, qwen2.5, and most modern models |
| **Chat persistence** | PostgreSQL | No additional infra. Works with existing GoodJob pattern. |
| **Embeddings** | Ollama embed endpoint | Local semantic search, no cloud dependency |
| **Module location** | `modules/ai/` | Clean separation, follows existing plugin pattern. Easier enterprise gating. |
| **Docker bundling** | `ollama` service in compose | One-command setup for users |
| **Graceful degradation** | Rescue all connection errors | AI unavailable ≠ broken app |

## Model Sizing

| Model | RAM | Quality | Tool Calling |
|---|---|---|---|
| `llama3.2:3b` (default) | ~3GB | Good | Yes |
| `llama3.1:8b` | ~8GB | Better | Yes |
| `qwen2.5:7b` | ~7GB | Very good | Yes |
| `mistral:7b` | ~7GB | Very good | Yes |

Users can switch models in admin settings at any time.
