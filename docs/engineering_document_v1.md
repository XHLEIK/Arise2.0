<div align="center">

# 📜 Engineering Document v1
*Legacy architecture and initial product vision.*

[⬅️ Back to README](../README.md)

</div>

---

## 🔹 1. System Goal
A.R.I.S.E. is a local, voice-first, Windows AI assistant designed to control the computer, browse websites, process files, assist with coding, monitor the screen, learn user workflows, and respond naturally through speech.

Primary goals:
- Fully local and private
- Fast voice-only operation
- Safe browser and system automation
- Strong document and code handling
- Memory that improves over time
- Minimal model count with high capability

---

## 🔹 2. High-Level Architecture

```text
User Voice / Screen / Text
        ↓
Input Layer
        ↓
Intent Router
        ↓
Planner / Orchestrator
        ↓
Specialized Agents
        ↓
Tool Executor + Policy Engine
        ↓
Memory + Logs + Response
        ↓
Voice Output / UI Update
```

### 🔸 Core Layers
1. **UI Layer** – Flutter Windows app
2. **Input Layer** – voice, text, screen events, hotkeys
3. **Intent Router** – classifies the request type
4. **Planner / Orchestrator** – creates task steps
5. **Agents** – execute domain-specific tasks
6. **Tool Executor** – performs actual actions on the OS, browser, files, or media
7. **Memory Layer** – stores history, preferences, and semantic knowledge
8. **Security Layer** – validates and approves risky actions

---

## 🔹 3. Model Stack

### 🔸 Main model
- **Qwen2.5 7B Instruct**
- Used for conversation, planning, reasoning, tool selection, coding assistance, and document reasoning

### 🔸 Speech-to-Text
- **Whisper Small**
- Used for voice recognition and command transcription

### 🔸 Text-to-Speech
- **XTTS-v2**
- Used for natural voice output

### 🔸 Embeddings
- **Nomic Embed Text**
- Used for semantic memory, file search, and knowledge retrieval

### 🔸 Optional vision model
- Used for screen analysis and image understanding when required
- Keep as fallback or add later if needed

---

## 🔹 4. Module Responsibilities

### 🔸 4.1 UI Layer
Responsibilities:
- Show orb, logs, metrics, suggestions, and task status
- Render voice input state
- Display notifications
- Show system activity and memory panels
- Provide settings and safety prompts

### 🔸 4.2 Input Layer
Responsibilities:
- Capture voice input
- Listen for wake word
- Observe screen changes
- Detect active window
- Capture clipboard changes
- Track hotkeys and system events

### 🔸 4.3 Intent Router
Responsibilities:
- Classify commands into categories such as:
  - conversation
  - coding
  - browser automation
  - document processing
  - system control
  - media generation
  - real-time query
  - memory search
- Route request to the right agent

### 🔸 4.4 Planner / Orchestrator
Responsibilities:
- Break requests into steps
- Choose tools and agents
- Request confirmations for risky tasks
- Retry failed steps
- Track progress and completion

### 🔸 4.5 Agents
#### Conversation Agent
Handles general chat and explanations.

#### Coding Agent
Handles project creation, debugging, file edits, scripts, and terminal execution.

#### Browser Agent
Handles website opening, navigation, form filling, social posting, downloads, and web workflows.

#### File Agent
Handles PDF, DOCX, PPTX, XLSX, TXT, CSV, and file operations.

#### Media Agent
Handles speech, image generation, image understanding, and multimedia workflows.

#### System Agent
Handles apps, windows, volume, brightness, shutdown, restart, and system controls.

#### Screen Awareness Agent
Observes the screen and suggests actions proactively.

### 🔸 4.6 Tool Executor
Responsibilities:
- Execute approved actions
- Call OS APIs, browser automation, file operations, and media tools
- Return action results to the orchestrator

### 🔸 4.7 Memory Layer
Responsibilities:
- Store short-term conversation state
- Store long-term user preferences
- Store semantic embeddings of files and notes
- Track workflow patterns and repeated tasks

### 🔸 4.8 Security Layer
Responsibilities:
- Validate commands
- Block unsafe actions
- Require confirmation for sensitive operations
- Restrict folders, domains, and commands
- Write audit logs

---

## 🔹 5. Suggested Folder Structure

```text
ARISE/
├── app/
│   ├── main.dart
│   ├── ui/
│   │   ├── dashboard/
│   │   ├── settings/
│   │   ├── logs/
│   │   ├── memory/
│   │   ├── plugins/
│   │   └── widgets/
│   ├── state/
│   ├── theme/
│   └── services/
│
├── backend/
│   ├── main.py
│   ├── api/
│   │   ├── routes.py
│   │   ├── websocket.py
│   │   └── auth.py
│   ├── core/
│   │   ├── router.py
│   │   ├── planner.py
│   │   ├── config.py
│   │   ├── permissions.py
│   │   └── model_manager.py
│   ├── agents/
│   │   ├── conversation_agent.py
│   │   ├── coding_agent.py
│   │   ├── browser_agent.py
│   │   ├── file_agent.py
│   │   ├── media_agent.py
│   │   ├── system_agent.py
│   │   └── screen_agent.py
│   ├── tools/
│   │   ├── system_tools.py
│   │   ├── browser_tools.py
│   │   ├── file_tools.py
│   │   ├── code_tools.py
│   │   ├── media_tools.py
│   │   └── safety_tools.py
│   ├── memory/
│   │   ├── redis_cache.py
│   │   ├── sqlite_store.py
│   │   ├── chroma_store.py
│   │   └── embeddings.py
│   ├── llm/
│   │   ├── ollama_client.py
│   │   ├── prompts.py
│   │   └── schemas.py
│   ├── automation/
│   │   ├── app_launcher.py
│   │   ├── browser_driver.py
│   │   ├── file_manager.py
│   │   ├── terminal_runner.py
│   │   └── workflow_engine.py
│   ├── media/
│   │   ├── stt.py
│   │   ├── tts.py
│   │   ├── vision.py
│   │   ├── image_gen.py
│   │   └── video.py
│   ├── security/
│   │   ├── validator.py
│   │   ├── sanitizer.py
│   │   ├── sandbox.py
│   │   ├── policy_engine.py
│   │   └── audit_log.py
│   └── utils/
│       ├── logger.py
│       ├── helpers.py
│       └── constants.py
│
├── data/
│   ├── sqlite/
│   ├── chroma/
│   ├── redis/
│   ├── logs/
│   ├── memory/
│   └── profiles/
│
├── plugins/
│   ├── web_search/
│   ├── browser_control/
│   ├── code_generation/
│   ├── file_read_write/
│   ├── ppt_generator/
│   ├── doc_generator/
│   ├── xlsx_generator/
│   └── image_generation/
│
├── scripts/
│   ├── install_models.py
│   ├── start_backend.py
│   ├── start_ui.py
│   └── build_release.py
│
└── installer/
    ├── nsis/
    └── inno_setup/
```

---

## 🔹 6. Runtime Task Flow

### 🔸 6.1 Conversation
1. User speaks
2. Whisper transcribes
3. Intent router classifies as conversation
4. Qwen2.5 answers
5. XTTS speaks the reply

### 🔸 6.2 System command
1. User says “open Chrome”
2. Router classifies as system control
3. Planner checks safety rules
4. Tool executor opens the app
5. UI shows success

### 🔸 6.3 Coding request
1. User says “create a landing page”
2. Router classifies as coding
3. Planner creates steps
4. Coding agent creates folder and files
5. Editor opens
6. Local server runs
7. UI asks for preview confirmation

### 🔸 6.4 Browser automation
1. User says “post this on Facebook”
2. Router classifies as browser automation
3. Browser agent opens website
4. Page is navigated using Playwright or UI automation
5. Sensitive action requires confirmation
6. Post is submitted only after approval

### 🔸 6.5 Document query
1. User asks about a file
2. File agent extracts text
3. Embeddings are generated
4. Chroma returns relevant chunks
5. Qwen summarizes or answers

---

## 🔹 7. Database Design

### 🔸 7.1 SQLite tables
#### users
- id
- name
- preferences
- created_at

#### settings
- id
- key
- value
- updated_at

#### conversations
- id
- title
- created_at
- last_message_at

#### messages
- id
- conversation_id
- role
- content
- timestamp

#### workflows
- id
- name
- trigger_pattern
- steps_json
- last_used_at

#### logs
- id
- level
- source
- message
- timestamp

#### plugins
- id
- name
- version
- enabled
- config_json

---

### 🔸 7.2 Chroma collections
#### user_memory
Stores preferences, habits, and important facts.

#### documents
Stores chunks from PDFs, DOCX, PPTX, notes, and code files.

#### workflows
Stores repeated command sequences and automations.

#### codebase
Stores code chunks for semantic code search.

---

### 🔸 7.3 Redis keys
Use for:
- session state
- recent prompts
- recent responses
- temporary task queues
- cached search results

Examples:
- `session:active_conversation`
- `cache:recent_reply`
- `queue:embedding_jobs`
- `cache:last_file_search`

---

## 🔹 8. API Endpoints

### 🔸 Auth and session
- `POST /auth/login`
- `POST /auth/logout`
- `GET /auth/status`

### 🔸 Assistant
- `POST /assistant/message`
- `POST /assistant/voice`
- `GET /assistant/state`

### 🔸 System control
- `POST /system/open-app`
- `POST /system/close-app`
- `POST /system/volume`
- `POST /system/brightness`
- `POST /system/power`

### 🔸 Browser automation
- `POST /browser/open`
- `POST /browser/navigate`
- `POST /browser/click`
- `POST /browser/type`
- `POST /browser/upload`

### 🔸 File operations
- `POST /files/read`
- `POST /files/write`
- `POST /files/create-folder`
- `POST /files/search`

### 🔸 Memory
- `POST /memory/store`
- `POST /memory/search`
- `GET /memory/list`
- `DELETE /memory/item/{id}`

### 🔸 Media
- `POST /media/stt`
- `POST /media/tts`
- `POST /media/image-generate`
- `POST /media/vision-analyze`

### 🔸 Security
- `POST /security/confirm`
- `GET /security/audit-log`
- `POST /security/policy-check`

---

## 🔹 9. DSA Layer

High-level DSA is critical for performance.

### 🔸 9.1 Hash Map / Dictionary
Use for:
- installed app lookup
- plugin registry
- config cache
- command-to-action mapping

Why:
- instant lookup
- very fast routing

Example:
```python
installed_apps = {
    "chrome": "C:/Program Files/Google/Chrome/Application/chrome.exe",
    "vscode": "C:/Users/.../Code.exe"
}
```

---

### 🔸 9.2 Trie
Use for:
- command autocomplete
- voice command prefixes
- smart suggestions

Examples:
- open chrome
- open github
- open camera
- open calculator

Why:
- fast prefix matching
- great for suggestion chips and command prediction

---

### 🔸 9.3 Priority Queue / Heap
Use for:
- task scheduling
- agent execution order
- background jobs
- retry prioritization

Example:
- urgent system error fix gets higher priority than a long report generation task

---

### 🔸 9.4 Graph / DAG
Use for:
- multi-step workflows
- dependency planning
- code generation pipelines
- document creation pipelines

Example workflow:
```text
read doc → extract key points → generate slides → export ppt → send file
```

Why:
- ensures correct order
- enables parallel work where possible

---

### 🔸 9.5 LRU Cache
Use for:
- recent replies
- repeated memory searches
- repeated file lookups
- recent embeddings

Why:
- instant reuse of recent results
- reduces LLM calls and vector search calls

---

### 🔸 9.6 Inverted Index
Use for:
- file search
- local note search
- keyword lookup inside documents
- log search

Why:
- fast exact and partial keyword retrieval
- complements vector search

---

### 🔸 9.7 Vector Index
Use for:
- semantic memory
- document similarity search
- codebase understanding
- long-term recall

Backed by Chroma.

---

### 🔸 9.8 Queue / Ring Buffer
Use for:
- live transcript buffering
- recent screen events
- streaming TTS chunks
- task event stream

Why:
- keeps real-time pipelines smooth

---

### 🔸 9.9 Set
Use for:
- duplicate prevention
- visited websites
- processed files
- deduped memory chunks

---

### 🔸 9.10 Stack
Use for:
- undo history
- navigation history
- nested task rollback

---

## 🔹 10. Algorithms

### 🔸 10.1 Intent classification
A small classifier determines the category of a request.

### 🔸 10.2 Topological sort
Used to execute multi-step workflows in correct order.

### 🔸 10.3 Similarity search
Uses cosine similarity for semantic retrieval.

### 🔸 10.4 State machine
Use for:
- listening
- thinking
- speaking
- waiting
- executing
- error

### 🔸 10.5 Retry logic
Use exponential backoff for:
- browser actions
- file operations
- web requests

---

## 🔹 11. Safety Model

### 🔸 Always require confirmation for:
- deleting files
- sending messages
- buying items
- posting online
- changing system settings
- running scripts from unknown sources
- account login actions

### 🔸 Policy checks should validate:
- allowed folders
- allowed domains
- allowed commands
- allowed tools
- user confirmation state

### 🔸 Important principle
The LLM suggests actions, but the policy engine decides whether the action is allowed.

---

## 🔹 12. Performance Rules
- Load only one heavy model at a time when possible
- Keep prompts short
- Use Redis for repeated work
- Use Chroma only when memory retrieval is needed
- Stream responses instead of waiting for full generation
- Prefer DOM automation before vision fallback
- Use event-driven screen monitoring, not constant heavy analysis

---

## 🔹 13. Build Order
1. Flutter UI shell
2. Voice input/output
3. Intent router
4. System control
5. Browser automation
6. File/document tools
7. Memory system
8. Coding agent
9. Screen awareness
10. Security layer
11. Plugins
12. Installer

---

## 🔹 14. Final Recommended Stack

### 🔸 AI
- Qwen2.5 7B Instruct
- Whisper Small
- XTTS-v2
- Nomic Embed Text

### 🔸 Memory
- Redis
- SQLite
- Chroma

### 🔸 Automation
- Playwright
- Windows UI Automation
- file system tools
- terminal tools

### 🔸 Documents
- PDF parser
- DOCX writer
- PPTX writer
- XLSX writer

### 🔸 Optional media
- Stable Diffusion
- vision model later if needed

---

## 🔹 15. Summary
A.R.I.S.E. is best built as a modular, voice-first AI operating layer with:
- one strong general LLM
- lightweight speech models
- a dedicated memory stack
- a strong automation and browser layer
- a planner-orchestrator design
- a DSA-backed fast routing and retrieval system
- strict safety controls

This gives you a system that is fast, scalable, and practical on your hardware.
