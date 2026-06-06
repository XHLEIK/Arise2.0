"""
A.R.I.S.E Action Handler — Windows Application Scanner & Action Executor.

Thread-safe app database with O(1) exact, O(log n) prefix, and fuzzy-match
lookup.  Covers **Win32 shortcuts** (Start Menu .lnk / .exe) *and*
**UWP / system apps** (Calculator, Camera, Settings …) via PowerShell
``Get-StartApps``.

Launching:
  • Win32 apps  → ``os.startfile(path)``
  • UWP apps    → ``subprocess.Popen(["explorer.exe", shell_uri])``
  • URLs        → ``webbrowser`` (Brave-preferred)

No ``os.system`` or ``shell=True`` is ever used.
"""

import os
import json
import re
import bisect
import subprocess
import threading
import webbrowser
import difflib
import structlog
from pathlib import Path
from typing import Optional

logger = structlog.get_logger()

# ── Compiled regex (module-load time) ────────────────────────────────────
_URL_RE = re.compile(
    r"^https?://[^\s/$.?#].[^\s]*$|"
    r"^[a-zA-Z0-9][-a-zA-Z0-9]*\.[a-zA-Z]{2,}",
    re.IGNORECASE,
)
_STRIP_SPECIAL_RE = re.compile(r"[^a-z0-9\s+]")
_MULTI_SPACE_RE = re.compile(r"\s{2,}")

# ── Register Brave as preferred browser ──────────────────────────────────
_BRAVE_CANDIDATES = [
    r"C:\Program Files\BraveSoftware\Brave-Browser\Application\brave.exe",
    r"C:\Program Files (x86)\BraveSoftware\Brave-Browser\Application\brave.exe",
    os.path.join(
        os.environ.get("LOCALAPPDATA", ""),
        r"BraveSoftware\Brave-Browser\Application\brave.exe",
    ),
]
_BRAVE_REGISTERED = False
for _bp in _BRAVE_CANDIDATES:
    if os.path.isfile(_bp):
        webbrowser.register("brave", None, webbrowser.BackgroundBrowser(_bp))
        _BRAVE_REGISTERED = True
        break


class ActionHandler:
    """Scan installed Windows apps, resolve queries, launch apps / open URLs."""

    # Dangerous patterns — must never appear in user-supplied targets.
    BLOCKED_PATTERNS: list[str] = [
        "..", "%", "|", ";", "&", "`", "$", "!", ">", "<",
        "\x00", "\n", "\r",
    ]

    ALLOWED_EXTENSIONS: set[str] = {".lnk", ".exe", ".appref-ms", ".url"}

    # Human-friendly aliases → canonical normalised name.
    # User uses Brave (not Chrome), so "chrome" maps to Brave.
    _ALIASES: dict[str, str] = {
        # ── Browsers ─────────────────────────────────────────────────
        "brave": "brave browser",
        "chrome": "brave browser",          # user has Brave, not Chrome
        "browser": "brave browser",
        "edge": "microsoft edge",
        "firefox": "mozilla firefox",
        # ── IDEs / Editors ───────────────────────────────────────────
        "vs code": "visual studio code",
        "vscode": "visual studio code",
        "code": "visual studio code",
        "notepad++": "notepad++",
        # ── Office ───────────────────────────────────────────────────
        "word": "microsoft word",
        "excel": "microsoft excel",
        "ppt": "microsoft powerpoint",
        "powerpoint": "microsoft powerpoint",
        # ── System apps / UWP ────────────────────────────────────────
        "calc": "calculator",
        "camera": "camera",
        "photos": "photos",
        "paint": "paint",
        "snip": "snipping tool",
        "snipping": "snipping tool",
        "screenshot": "snipping tool",
        "clock": "clock",
        "alarm": "clock",
        "maps": "maps",
        "store": "microsoft store",
        "settings": "settings",
        "control panel": "control panel",
        "terminal": "windows terminal",
        "powershell": "windows powershell",
        "cmd": "command prompt",
        "command prompt": "command prompt",
        "explorer": "file explorer",
        "files": "file explorer",
        "task manager": "task manager",
        "taskmgr": "task manager",
        "notepad": "notepad",
        "recorder": "sound recorder",
        "mail": "mail",
        "calendar": "calendar",
        "weather app": "weather",
        "media player": "media player",
        "vlc": "vlc media player",
    }

    def __init__(self) -> None:
        self._lock = threading.Lock()
        self._apps_db: dict[str, str] = {}          # normalised_name → launch_path
        self._sorted_names: list[str] = []           # kept sorted for bisect
        self._db_path: Path = Path(__file__).resolve().parent.parent / "apps_db.json"
        self._load_db()

    # ------------------------------------------------------------------
    # Persistence
    # ------------------------------------------------------------------

    def _load_db(self) -> None:
        """Load the cached app database from disk (if present)."""
        if not self._db_path.is_file():
            return
        try:
            with open(self._db_path, "r", encoding="utf-8") as fh:
                data = json.load(fh)
            if isinstance(data, dict):
                self._apps_db = data
                self._sorted_names = sorted(self._apps_db.keys())
                logger.info("Loaded app DB from disk", count=len(self._apps_db))
        except (json.JSONDecodeError, OSError) as exc:
            logger.warning("Could not load app DB", error=str(exc))

    def _save_db(self) -> None:
        """Atomically persist the app database to JSON."""
        tmp_path = self._db_path.with_suffix(".tmp")
        try:
            with open(tmp_path, "w", encoding="utf-8") as fh:
                json.dump(self._apps_db, fh, indent=2, ensure_ascii=False)
            tmp_path.replace(self._db_path)
        except OSError as exc:
            logger.error("Failed to save app DB", error=str(exc))

    # ------------------------------------------------------------------
    # Scanning — Win32 shortcuts
    # ------------------------------------------------------------------

    def _scan_start_menu(self) -> dict[str, str]:
        """Walk Start-Menu folders and index every shortcut / executable."""
        scan_dirs: list[str] = [
            r"C:\ProgramData\Microsoft\Windows\Start Menu\Programs",
        ]
        user_appdata = os.environ.get("APPDATA", "")
        if user_appdata:
            scan_dirs.append(
                os.path.join(user_appdata, r"Microsoft\Windows\Start Menu\Programs")
            )

        found: dict[str, str] = {}
        for base_dir in scan_dirs:
            base = Path(base_dir)
            if not base.is_dir():
                continue
            for file_path in base.rglob("*"):
                if not file_path.is_file():
                    continue
                if file_path.suffix.lower() not in self.ALLOWED_EXTENSIONS:
                    continue
                app_name = file_path.stem
                norm = self._normalize_name(app_name)
                if not norm:
                    continue
                # First occurrence wins (user shortcuts take priority)
                if norm not in found:
                    found[norm] = str(file_path)

        return found

    # ------------------------------------------------------------------
    # Scanning — UWP / System apps  (PowerShell Get-StartApps)
    # ------------------------------------------------------------------

    def _scan_uwp_apps(self) -> dict[str, str]:
        """Scan ALL installed apps (UWP + system) via ``Get-StartApps``.

        Returns a dict of normalised_name → ``shell:AppsFolder\\{AppID}``.
        The ``shell:`` URI can be launched via ``explorer.exe``.
        """
        try:
            result = subprocess.run(
                [
                    "powershell", "-NoProfile", "-NonInteractive",
                    "-Command", "Get-StartApps | ConvertTo-Json -Compress",
                ],
                capture_output=True,
                text=True,
                timeout=30,
                creationflags=getattr(subprocess, "CREATE_NO_WINDOW", 0),
            )
            if result.returncode != 0:
                logger.warning("Get-StartApps failed", stderr=result.stderr[:200])
                return {}

            raw = result.stdout.strip()
            if not raw:
                return {}

            apps = json.loads(raw)
            if isinstance(apps, dict):          # single-result edge case
                apps = [apps]

            found: dict[str, str] = {}
            for app in apps:
                name = app.get("Name", "")
                app_id = app.get("AppID", "")
                if not name or not app_id:
                    continue
                norm = self._normalize_name(name)
                if norm and norm not in found:
                    found[norm] = f"shell:AppsFolder\\{app_id}"

            logger.info("UWP/system app scan complete", indexed=len(found))
            return found

        except subprocess.TimeoutExpired:
            logger.error("UWP scan timed out (30 s)")
            return {}
        except Exception as exc:
            logger.error("UWP scan failed", error=str(exc))
            return {}

    # ------------------------------------------------------------------
    # Combined scan
    # ------------------------------------------------------------------

    def scan_system_apps(self) -> tuple[int, bool]:
        """Index everything: Start-Menu shortcuts + UWP / system apps.

        UWP results are merged *under* Win32 shortcuts so that a .lnk
        file always takes precedence (more reliable launch path).
        Returns a tuple of (total_count, is_same).
        """
        # 1. Win32 shortcuts from Start Menu
        win32_apps = self._scan_start_menu()

        # 2. UWP / system apps
        uwp_apps = self._scan_uwp_apps()

        # 3. Merge — Win32 shortcuts take priority
        merged: dict[str, str] = {}
        merged.update(uwp_apps)           # UWP first (lower priority)
        merged.update(win32_apps)         # Win32 overwrites duplicates

        with self._lock:
            is_same = (merged == self._apps_db)
            self._apps_db = merged
            self._sorted_names = sorted(self._apps_db.keys())
            self._save_db()

        logger.info(
            "Full system app scan complete",
            win32=len(win32_apps),
            uwp=len(uwp_apps),
            total=len(merged),
            unchanged=is_same,
        )
        return len(merged), is_same

    # ------------------------------------------------------------------
    # Normalisation & matching
    # ------------------------------------------------------------------

    @staticmethod
    def _normalize_name(name: str) -> str:
        """Lower-case, strip specials, collapse spaces, resolve aliases."""
        n = name.lower().strip()
        n = n.replace("-", " ").replace("_", " ")
        n = _STRIP_SPECIAL_RE.sub("", n)
        n = _MULTI_SPACE_RE.sub(" ", n).strip()

        # Check aliases AFTER basic normalisation
        if n in ActionHandler._ALIASES:
            n = ActionHandler._ALIASES[n]
        return n

    def _find_app(self, query: str) -> Optional[str]:
        """Resolve a human query to an installed app's launch path.

        Resolution order (cheapest first):
        1. O(1)     — exact dict lookup
        2. O(log n) — binary-search prefix match
        3. O(n)     — substring containment
        4. O(n)     — difflib fuzzy match (cutoff 0.6)
        """
        norm = self._normalize_name(query)
        if not norm:
            return None

        with self._lock:
            # 1. Exact
            if norm in self._apps_db:
                return self._apps_db[norm]

            # 2. Prefix (bisect for O(log n) seek, then linear scan)
            idx = bisect.bisect_left(self._sorted_names, norm)
            if idx < len(self._sorted_names) and self._sorted_names[idx].startswith(norm):
                return self._apps_db[self._sorted_names[idx]]

            # 3. Substring
            for name in self._sorted_names:
                if norm in name:
                    return self._apps_db[name]

            # 4. Fuzzy
            matches = difflib.get_close_matches(
                norm, self._sorted_names, n=1, cutoff=0.6
            )
            if matches:
                return self._apps_db[matches[0]]

        return None

    # ------------------------------------------------------------------
    # URL detection & input sanitisation
    # ------------------------------------------------------------------

    @staticmethod
    def _is_url(target: str) -> bool:
        return bool(_URL_RE.match(target.strip()))

    def _sanitize_target(self, target: str) -> str:
        """Strip, length-limit, and reject dangerous patterns."""
        t = target.strip()
        if len(t) > 500:
            raise ValueError("Target exceeds maximum length (500 characters).")
        for pat in self.BLOCKED_PATTERNS:
            if pat in t:
                raise ValueError(f"Target contains blocked pattern: '{pat}'")
        return t

    # ------------------------------------------------------------------
    # Launching helpers
    # ------------------------------------------------------------------

    @staticmethod
    def _launch_path(path: str) -> None:
        """Launch an app by its stored path.

        • Win32 shortcuts (.lnk / .exe) → ``os.startfile``
        • UWP shell URIs                → ``subprocess.Popen(["explorer.exe", …])``
          (safe: fixed binary + URI from our own trusted DB, no shell=True)
        """
        if path.startswith("shell:"):
            subprocess.Popen(
                ["explorer.exe", path],
                creationflags=getattr(subprocess, "CREATE_NO_WINDOW", 0),
            )
        else:
            os.startfile(path)  # type: ignore[attr-defined]

    # ------------------------------------------------------------------
    # Public API
    # ------------------------------------------------------------------

    def is_db_empty(self) -> bool:
        """Return True if no applications have been indexed."""
        with self._lock:
            return len(self._apps_db) == 0

    # ------------------------------------------------------------------
    # Background Installer Watcher
    # ------------------------------------------------------------------

    def _get_start_menu_snapshot(self) -> set[tuple[str, float]]:
        """Collect paths and modification times of all shortcuts in Start Menu."""
        scan_dirs: list[str] = [
            r"C:\ProgramData\Microsoft\Windows\Start Menu\Programs",
        ]
        user_appdata = os.environ.get("APPDATA", "")
        if user_appdata:
            scan_dirs.append(
                os.path.join(user_appdata, r"Microsoft\Windows\Start Menu\Programs")
            )

        snapshot: set[tuple[str, float]] = set()
        for d in scan_dirs:
            base = Path(d)
            if not base.is_dir():
                continue
            for file_path in base.rglob("*"):
                if not file_path.is_file():
                    continue
                if file_path.suffix.lower() not in self.ALLOWED_EXTENSIONS:
                    continue
                try:
                    mtime = os.path.getmtime(file_path)
                    snapshot.add((str(file_path), mtime))
                except OSError:
                    continue  # Ignore locked/deleted files during walk
        return snapshot

    def _watcher_loop(self, interval: int) -> None:
        cache = self._get_start_menu_snapshot()
        while not self._watcher_stop_event.wait(timeout=interval):
            try:
                current = self._get_start_menu_snapshot()
                if current != cache:
                    logger.info("Newly installed or modified apps detected. Re-indexing...")
                    self.scan_system_apps()
                    cache = current
            except Exception as exc:
                logger.error("Error in app watcher loop", error=str(exc))

    def start_watcher(self, interval: int = 60) -> None:
        """Spawn a background thread to watch the Start Menu directories for changes."""
        self._watcher_stop_event = threading.Event()
        self._watcher_thread = threading.Thread(
            target=self._watcher_loop,
            args=(interval,),
            name="ARISE_AppWatcher",
            daemon=True
        )
        self._watcher_thread.start()
        logger.info("Background app installer watcher started", interval=interval)

    def stop_watcher(self) -> None:
        """Signal the watcher thread to stop and wait for it to exit."""
        if hasattr(self, "_watcher_stop_event"):
            self._watcher_stop_event.set()
        if hasattr(self, "_watcher_thread"):
            self._watcher_thread.join(timeout=2)
            logger.info("Background app installer watcher stopped")

    def execute_action(self, action: str, target: str) -> dict:
        """Dispatch an action (open_url | launch_app | scan_apps).

        Returns a dict with at least ``status`` and ``message`` keys.

        Special status ``scan_required`` is returned when the app DB is
        empty and the user tries to launch an app — the caller should ask
        the user for permission to scan.
        """
        target = self._sanitize_target(target)

        # --- URL ---------------------------------------------------------
        if action == "open_url" or self._is_url(target):
            url = target if target.startswith(("http://", "https://")) else f"https://{target}"
            try:
                # Prefer Brave if registered, else system default
                if _BRAVE_REGISTERED:
                    webbrowser.get("brave").open(url)
                else:
                    webbrowser.open(url)
                logger.info("Opened URL", url=url)
                return {"status": "success", "message": f"Opening {url} in your browser."}
            except Exception as exc:
                logger.error("Failed to open URL", url=url, error=str(exc))
                return {"status": "error", "message": f"Could not open URL: {exc}"}

        # --- Launch app --------------------------------------------------
        if action == "launch_app":
            # If app DB is empty, ask user to scan first
            if self.is_db_empty():
                return {
                    "status": "scan_required",
                    "message": (
                        "I haven't scanned your system for installed applications yet. "
                        "Would you like me to scan now so I can find and open apps for you?"
                    ),
                }

            path = self._find_app(target)
            if path:
                try:
                    self._launch_path(path)
                    display_name = Path(path).stem if not path.startswith("shell:") else target.title()
                    logger.info("Launched app", app=display_name, path=path)
                    return {
                        "status": "success",
                        "message": f"Launching {display_name}...",
                    }
                except OSError as exc:
                    logger.error("Failed to launch app", path=path, error=str(exc))
                    return {"status": "error", "message": f"Failed to launch: {exc}"}

            # Smart Fallback for Launch App
            norm_target = self._normalize_name(target)
            web_services = {
                "youtube": "youtube.com",
                "google": "google.com",
                "gmail": "mail.google.com",
                "github": "github.com",
                "wikipedia": "wikipedia.org",
                "facebook": "facebook.com",
                "twitter": "twitter.com",
                "x": "x.com",
                "instagram": "instagram.com",
                "chatgpt": "chatgpt.com",
                "openai": "openai.com",
                "reddit": "reddit.com",
                "netflix": "netflix.com",
                "amazon": "amazon.com",
                "linkedin": "linkedin.com",
                "spotify": "open.spotify.com",
                "canva": "canva.com",
                "whatsapp": "web.whatsapp.com",
                "outlook": "outlook.live.com",
                "teams": "teams.microsoft.com",
                "zoom": "zoom.us",
                "twitch": "twitch.tv",
                "pinterest": "pinterest.com",
                "tumblr": "tumblr.com",
                "quora": "quora.com",
                "ebay": "ebay.com",
                "apple": "apple.com",
                "microsoft": "microsoft.com",
                "yahoo": "yahoo.com",
                "bing": "bing.com",
                "duckduckgo": "duckduckgo.com"
            }

            if norm_target in web_services:
                url = f"https://{web_services[norm_target]}"
                try:
                    if _BRAVE_REGISTERED:
                        webbrowser.get("brave").open(url)
                    else:
                        webbrowser.open(url)
                    logger.info("Opened web service URL", target=norm_target, url=url)
                    return {"status": "success", "message": f"Opening {url} in your browser."}
                except Exception as exc:
                    logger.error("Failed to open web service URL", url=url, error=str(exc))
                    return {"status": "error", "message": f"Could not open browser: {exc}"}

            if "." in target and not target.endswith((".exe", ".lnk", ".appref-ms", ".url")):
                url = target if target.startswith(("http://", "https://")) else f"https://{target}"
                try:
                    if _BRAVE_REGISTERED:
                        webbrowser.get("brave").open(url)
                    else:
                        webbrowser.open(url)
                    logger.info("Opened direct URL", url=url)
                    return {"status": "success", "message": f"Opening {url} in your browser."}
                except Exception as exc:
                    logger.error("Failed to open direct URL", url=url, error=str(exc))
                    return {"status": "error", "message": f"Could not open browser: {exc}"}

            # Otherwise, fallback to web search
            url = f"https://www.google.com/search?q={target}"
            try:
                if _BRAVE_REGISTERED:
                    webbrowser.get("brave").open(url)
                else:
                    webbrowser.open(url)
                logger.info("Opened fallback web search", query=target)
                return {
                    "status": "success",
                    "message": f"I couldn't find a local app named '{target}', so I searched for it in your browser."
                }
            except Exception as exc:
                logger.error("Failed to open fallback search", query=target, error=str(exc))
                return {"status": "error", "message": f"Could not open browser: {exc}"}

        # --- Rescan ------------------------------------------------------
        if action == "scan_apps":
            count, is_same = self.scan_system_apps()
            if is_same:
                return {
                    "status": "success",
                    "message": f"Your system is already scanned. Currently, {count} applications are indexed and no new apps were detected."
                }
            else:
                return {
                    "status": "success",
                    "message": f"Scan complete! I have successfully scanned your system and indexed {count} applications."
                }

        # --- Unknown action ----------------------------------------------
        return {"status": "error", "message": "Unknown action type."}

    def get_app_count(self) -> int:
        """Return the number of indexed applications."""
        with self._lock:
            return len(self._apps_db)
