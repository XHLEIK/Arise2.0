<div align="center">

# 🏗️ Software Architecture
*Complete A.R.I.S.E. 2.0 system and software architecture.*

[⬅️ Back to README](../README.md)

</div>

---

A.R.I.S.E. 2.0 — Complete Software Architecture
1) High-level flow
Voice / Screen / Text
        ↓
Input Layer
        ↓
Intent Router
        ↓
Planner / Orchestrator
        ↓
Specialized Agents
        ↓
Tool Executor
        ↓
Memory + Logs + Response
        ↓
Voice Output / UI Update

The key idea is:

the router figures out what kind of task it is
the planner decides the steps
the agent performs the work
the tool executor actually runs system/browser/file actions
2) Main components
A. UI Layer

Built in Flutter for Windows.

Responsibilities:

orb animation
input box
voice controls
logs
system metrics
task dashboard
settings
memory panel
plugin panel
B. Input Layer

Handles:

microphone input
screen awareness input
text input
hotkeys
system events

Submodules:

speech-to-text
screen monitor
window focus watcher
clipboard watcher
keyboard listener
C. Intent Router

This is the first brain filter.

It classifies commands into:

conversation
coding
automation
browser
file/document
media
system control
real-time query
memory search

Example:

"Open Chrome" → system control
"Create a PPT" → document automation
"Fix this code" → coding
"What is gold price?" → realtime query
D. Planner / Orchestrator

This is the “task brain.”

It:

breaks the request into steps
decides tool order
chooses which model to use
asks for confirmation for risky tasks
handles retries and fallbacks

Example:

Create a landing page
→ make folder
→ open VS Code
→ create files
→ write code
→ run preview
→ report result
E. Agent Layer

Each agent has one job.

1. Conversation Agent

Handles normal chat, explanations, and assistant talk.

2. Coding Agent

Handles:

code generation
debugging
project scaffolding
file editing
terminal commands
3. Browser Agent

Handles:

opening websites
filling forms
reading pages
social media automation
downloads/uploads
4. File Agent

Handles:

PDFs
DOCX
PPTX
XLSX
TXT
CSV
folder operations
5. Media Agent

Handles:

image generation
image analysis
audio transcription
TTS
video analysis
6. System Agent

Handles:

apps
windows
volume
brightness
shutdown/restart
clipboard
file paths
7. Screen Awareness Agent

Handles:

current app recognition
code detection
error detection
proactive suggestions
F. Tool Executor

This is the layer that actually performs actions.

Examples:

open app
click button
type text
create file
run command
start browser
upload document

Very important:
The LLM should never execute anything directly.
It should only request a tool call, then the tool executor validates and runs it.

G. Memory Layer

Use a hybrid memory system.

Short-term memory
recent conversation
current task context
temporary state
Long-term memory
user preferences
repeated workflows
important facts
project knowledge
Semantic memory
document chunks
codebase chunks
notes and manuals

Suggested storage:

Redis for cache and short-term state
SQLite for system data and structured logs
Chroma for embeddings and semantic memory
H. Model Manager

This controls loading and unloading models.

Responsibilities:

load model only when needed
unload idle model
route tasks to the right model
monitor RAM/VRAM usage
prevent overload

For your setup, this is critical.

3) Suggested model mapping
Main model

Use one general model for most tasks.

Role:

conversation
planning
reasoning
general tool use
coding assistance
Voice models
speech-to-text
text-to-speech
Embedding model

For memory and document search.

Optional vision model

For screen understanding and image analysis.

4) Folder structure

Here is a professional structure for the whole project:

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
├── installer/
│   ├── nsis/
│   └── inno_setup/
│
└── README.md
5) Runtime workflow
Example: “Create a landing page”
voice input is transcribed
router detects coding task
planner creates steps
coding agent loads
files are created
VS Code opens
app is run
result is spoken back
Example: “Post on Facebook”
router detects browser automation
browser agent starts
browser opens
page structure is read
post is drafted
final confirmation is requested
post is submitted
action is logged
Example: “Summarize this PDF”
file agent extracts text
embeddings are created
Chroma stores chunks
relevant chunks are retrieved
LLM summarizes
response is spoken and shown
6) Safety architecture

This is very important for your assistant.

Mandatory safety layers
command validation
permission checks
confirmation for dangerous actions
restricted folders
restricted domains
audit logs
model output validation
Always require confirmation for:
deleting files
sending messages
buying items
posting content
changing system settings
running unknown scripts
logging into accounts
7) Recommendation for performance

To keep it fast:

load only one heavy model at a time
use Redis for cache
use Chroma only when needed
stream model output
keep prompt context short
use event-driven screen monitoring
use DOM/browser automation before vision fallback
8) Best build order

Build in this order:

UI shell
voice input/output
intent router
system control
browser automation
file/document tools
memory system
coding agent
screen awareness
safety layer
plugins
installer

That sequence keeps the project manageable.

9) Final architecture in one view
User Voice / Screen / Text
        ↓
Input Layer
        ↓
Intent Router
        ↓
Planner / Orchestrator
        ↓
Agents
 ├ Conversation
 ├ Coding
 ├ Browser
 ├ File
 ├ Media
 ├ System
 └ Screen
        ↓
Tools + Policy Engine
        ↓
Memory
 ├ Redis
 ├ SQLite
 └ Chroma
        ↓
Response
 ├ UI update
 └ Voice output
