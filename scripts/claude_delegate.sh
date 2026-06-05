#!/usr/bin/env bash
set -euo pipefail

usage() {
  cat <<'EOF'
usage:
  scripts/claude_delegate.sh prepare <subtask-id-topic> [progress-file]
  scripts/claude_delegate.sh launch <subtask-id-topic> <prompt-file> [progress-file]
  scripts/claude_delegate.sh status <subtask-id-topic> [progress-file]
  scripts/claude_delegate.sh wait <subtask-id-topic> [progress-file] [auto|interval-seconds] [max-checks]
  scripts/claude_delegate.sh cleanup <subtask-id-topic> [progress-file]

environment overrides:
  CLAUDE_DELEGATE_MODEL=glm-5.1
  CLAUDE_DELEGATE_AGENT=general-purpose
  CLAUDE_DELEGATE_EFFORT=medium
  CLAUDE_DELEGATE_PERMISSION_MODE=dontAsk
  CLAUDE_DELEGATE_TOOLS='Skill,Read,Edit,MultiEdit,Write,Bash,Grep,Glob,LS'
  CLAUDE_DELEGATE_ALLOWED_TOOLS='Skill,Read,Edit,MultiEdit,Write,Bash,Grep,Glob,LS'
  CLAUDE_DELEGATE_SETTING_SOURCES=user,local
  CLAUDE_DELEGATE_MODE=tmux    # tmux or print
  CLAUDE_DELEGATE_TMUX_STYLE=native  # native uses bare --tmux; classic uses --tmux=classic
  CLAUDE_DELEGATE_NONINTERACTIVE_FALLBACK=0 # set to print only when tmux cannot be used
  CLAUDE_DELEGATE_AGENT_PREFLIGHT=0 # set 1 to run claude agents --json before launch
  CLAUDE_DELEGATE_MAX_BUDGET_USD=30.00 # print mode only; general GLM coding budget guard
  CLAUDE_DELEGATE_SHOW_FLOW_LOGS=0     # set 1 only for diagnostics / failed acceptance
  CLAUDE_DELEGATE_TASK_ROOT=docs/subtasks
  CLAUDE_DELEGATE_LOG_DIR=$CLAUDE_DELEGATE_TASK_ROOT/logs
  CLAUDE_DELEGATE_WAIT_SCHEDULE=180,360,540 # default auto wait backoff in seconds
  CLAUDE_DELEGATE_OVERWRITE_WORKER_PROGRESS=0 # set 1 only to intentionally reset worker progress
  CLAUDE_DELEGATE_RESOURCE_GUARD=1
  CLAUDE_DELEGATE_MAX_CODEX_ZOMBIES=20
  CLAUDE_DELEGATE_MAX_TOTAL_ZOMBIES=80
  CLAUDE_DELEGATE_PRELAUNCH_CLEANUP=1
  CLAUDE_DELEGATE_CLEANUP_ON_STALL=0

notes:
  In non-interactive shells, tmux launch stays in tmux mode by default. Set
  CLAUDE_DELEGATE_NONINTERACTIVE_FALLBACK=print only when you intentionally
  want a foreground print-mode worker.
  Print mode still runs inside the isolated worker worktree.
  For large delegated tasks, set CLAUDE_DELEGATE_MAX_BUDGET_USD=60.00 or higher explicitly.
  Event/raw logs are flow logs: retained by default, not consumed during routine manager checks.
  Progress files are the conclusion source: worker checkpoints, findings, concerns, and handoff.
  Default wait uses auto backoff: 3m, then 6m, then 9m. If those checks show no
  conclusion-progress movement and no HANDOFF, the manager may intervene after
  classifying the stall.
  cleanup terminates only processes whose command line names this subtask's
  worker worktree or Claude --worktree target. It does not remove worktrees or
  inspect raw logs.
EOF
}

repo_root="$(git rev-parse --show-toplevel)"
cd "$repo_root"

absolute_or_repo_path() {
  local path="$1"
  if [[ "$path" == /* ]]; then
    printf '%s\n' "$path"
  else
    printf '%s/%s\n' "$repo_root" "$path"
  fi
}

timestamp() {
  date '+%Y-%m-%dT%H:%M:%S%z'
}

cmd="${1:-}"
if [[ -z "$cmd" || "$cmd" == "-h" || "$cmd" == "--help" ]]; then
  usage
  exit 0
fi
shift

subtask="${1:-}"
if [[ -z "$subtask" ]]; then
  usage >&2
  exit 64
fi
shift || true

task_root="${CLAUDE_DELEGATE_TASK_ROOT:-docs/subtasks}"
task_root_abs="$(absolute_or_repo_path "$task_root")"
task_log_dir="${CLAUDE_DELEGATE_LOG_DIR:-$task_root/logs}"
log_dir="$(absolute_or_repo_path "$task_log_dir")"
delegate_dir="$repo_root/.claude/delegation"
event_log="$log_dir/${subtask}-events.jsonl"
raw_log="$log_dir/${subtask}-claude-run.jsonl"
settings_file="$delegate_dir/${subtask}-settings.json"
worktree_name="subtask-${subtask}"
worker_path="$repo_root/.claude/worktrees/$worktree_name"
worker_branch="worker-$worktree_name"

model="${CLAUDE_DELEGATE_MODEL:-glm-5.1}"
agent="${CLAUDE_DELEGATE_AGENT:-general-purpose}"
effort="${CLAUDE_DELEGATE_EFFORT:-medium}"
permission_mode="${CLAUDE_DELEGATE_PERMISSION_MODE:-dontAsk}"
allowed_tools="${CLAUDE_DELEGATE_ALLOWED_TOOLS:-Skill,Read,Edit,MultiEdit,Write,Bash,Grep,Glob,LS}"
tools="${CLAUDE_DELEGATE_TOOLS:-Skill,Read,Edit,MultiEdit,Write,Bash,Grep,Glob,LS}"
setting_sources="${CLAUDE_DELEGATE_SETTING_SOURCES:-user,local}"
mode="${CLAUDE_DELEGATE_MODE:-tmux}"
tmux_style="${CLAUDE_DELEGATE_TMUX_STYLE:-native}"
noninteractive_fallback="${CLAUDE_DELEGATE_NONINTERACTIVE_FALLBACK:-0}"
agent_preflight="${CLAUDE_DELEGATE_AGENT_PREFLIGHT:-0}"
max_budget="${CLAUDE_DELEGATE_MAX_BUDGET_USD:-30.00}"
show_flow_logs="${CLAUDE_DELEGATE_SHOW_FLOW_LOGS:-0}"
overwrite_worker_progress="${CLAUDE_DELEGATE_OVERWRITE_WORKER_PROGRESS:-0}"
resource_guard_enabled="${CLAUDE_DELEGATE_RESOURCE_GUARD:-1}"
max_codex_zombies="${CLAUDE_DELEGATE_MAX_CODEX_ZOMBIES:-20}"
max_total_zombies="${CLAUDE_DELEGATE_MAX_TOTAL_ZOMBIES:-80}"
prelaunch_cleanup="${CLAUDE_DELEGATE_PRELAUNCH_CLEANUP:-1}"
cleanup_on_stall="${CLAUDE_DELEGATE_CLEANUP_ON_STALL:-0}"
effective_mode="$mode"

resolve_effective_mode() {
  effective_mode="$mode"
  if [[ "$effective_mode" == "tmux" && ! -t 0 && ! -t 1 && "$noninteractive_fallback" == "print" ]]; then
    effective_mode="print"
  fi
}

codex_app_pid() {
  ps -axo pid=,comm= | awk '$0 ~ /\/Applications\/Codex\.app\/Contents\/MacOS\/Codex$/ { print $1; exit }'
}

resource_guard() {
  local mode="${1:-fail}"
  [[ "$resource_guard_enabled" == "1" ]] || return 0

  local codex_pid=""
  local codex_zombies="0"
  local total_zombies="0"
  codex_pid="$(codex_app_pid || true)"
  total_zombies="$(ps -axo stat= | awk '$1 ~ /Z/ { count++ } END { print count + 0 }')"
  if [[ -n "$codex_pid" ]]; then
    codex_zombies="$(ps -axo stat=,ppid= | awk -v ppid="$codex_pid" '$1 ~ /Z/ && $2 == ppid { count++ } END { print count + 0 }')"
  fi

  local message="resource guard: codex_pid=${codex_pid:-unknown} codex_zombies=$codex_zombies total_zombies=$total_zombies thresholds=${max_codex_zombies}/${max_total_zombies}"
  if (( codex_zombies > max_codex_zombies || total_zombies > max_total_zombies )); then
    if [[ "$mode" == "warn" ]]; then
      echo "$message" >&2
      echo "resource guard warning: zombie thresholds exceeded; avoid launching new workers until Codex/system is restarted or zombies are reaped" >&2
      return 0
    fi
    echo "$message" >&2
    echo "resource guard blocked launch: zombie thresholds exceeded; restart Codex or the parent process before delegating more work" >&2
    exit 75
  fi
  echo "$message" >&2
}

worker_process_pids() {
  ps -axo pid=,ppid=,stat=,command= | awk -v path="$worker_path" -v wt="$worktree_name" '
    {
      pid = $1
      ppid = $2
      stat = $3
      $1 = ""; $2 = ""; $3 = ""
      sub(/^[[:space:]]+/, "")
      cmd = $0
      if (stat ~ /^Z/) next
      if (index(cmd, "ps -axo") > 0 || index(cmd, " awk ") > 0 || cmd ~ /^awk[[:space:]]/) next
      if (index(cmd, path) > 0 || index(cmd, "--worktree " wt) > 0 || index(cmd, "--worktree=" wt) > 0) {
        print pid
      }
    }
  '
}

worker_zombie_count() {
  ps -axo stat=,command= | awk -v path="$worker_path" -v wt="$worktree_name" '
    {
      stat = $1
      $1 = ""
      sub(/^[[:space:]]+/, "")
      cmd = $0
      if (stat ~ /^Z/ && (index(cmd, path) > 0 || index(cmd, "--worktree " wt) > 0 || index(cmd, "--worktree=" wt) > 0)) {
        count++
      }
    }
    END { print count + 0 }
  '
}

worker_process_count() {
  worker_process_pids | awk 'END { print NR + 0 }'
}

print_worker_liveness() {
  local active_count
  local zombie_count
  active_count="$(worker_process_count)"
  zombie_count="$(worker_zombie_count)"
  echo "worker liveness: active_processes=$active_count zombie_processes=$zombie_count worktree=$worker_path"
}

tmux_cli_args() {
  if [[ "$tmux_style" == "native" ]]; then
    printf '%s\n' "--tmux"
  elif [[ "$tmux_style" == "classic" ]]; then
    printf '%s\n' "--tmux=classic"
  else
    printf '%s\n' "--tmux=$tmux_style"
  fi
}

cleanup_worker_processes() {
  local reason="${1:-manual}"
  local pids=()
  while IFS= read -r pid; do
    [[ -n "$pid" ]] && pids+=("$pid")
  done < <(worker_process_pids)
  if [[ "${#pids[@]}" -eq 0 ]]; then
    printf '{"event":"manager_cleanup","time":"%s","reason":"%s","pids":[],"result":"no-active-worker-process"}\n' \
      "$(timestamp)" "$reason" >> "$event_log"
    echo "cleanup: no active worker processes for $subtask"
    return 0
  fi

  printf '{"event":"manager_cleanup","time":"%s","reason":"%s","pids":"%s","signal":"TERM"}\n' \
    "$(timestamp)" "$reason" "${pids[*]}" >> "$event_log"
  kill -TERM "${pids[@]}" 2>/dev/null || true
  sleep 2

  local remaining=()
  local pid
  for pid in "${pids[@]}"; do
    if kill -0 "$pid" 2>/dev/null; then
      remaining+=("$pid")
    fi
  done

  if [[ "${#remaining[@]}" -gt 0 ]]; then
    printf '{"event":"manager_cleanup","time":"%s","reason":"%s","pids":"%s","signal":"KILL"}\n' \
      "$(timestamp)" "$reason" "${remaining[*]}" >> "$event_log"
    kill -KILL "${remaining[@]}" 2>/dev/null || true
  fi

  echo "cleanup: terminated worker processes for $subtask: ${pids[*]}"
}

progress_file_for() {
  if [[ $# -gt 0 && -n "${1:-}" ]]; then
    printf '%s\n' "$1"
  else
    printf '%s/%s-progress.md\n' "$task_root" "$subtask"
  fi
}

repo_relative_path() {
  local path="$1"
  if [[ "$path" == /* ]]; then
    case "$path" in
      "$repo_root"/*) printf '%s\n' "${path#$repo_root/}" ;;
      *)
        echo "path is outside repo: $path" >&2
        exit 66
        ;;
    esac
  else
    printf '%s\n' "$path"
  fi
}

manager_file_path() {
  local path="$1"
  if [[ "$path" == /* ]]; then
    printf '%s\n' "$path"
  else
    printf '%s/%s\n' "$repo_root" "$path"
  fi
}

worker_file_path() {
  local rel_path
  rel_path="$(repo_relative_path "$1")"
  printf '%s/%s\n' "$worker_path" "$rel_path"
}

worker_progress_path_for() {
  local progress_file="$1"
  if [[ "$progress_file" == /* ]]; then
    case "$progress_file" in
      "$repo_root"/*) worker_file_path "$progress_file" ;;
      *) return 0 ;;
    esac
  else
    worker_file_path "$progress_file"
  fi
}

current_progress_path() {
  local progress_file="$1"
  local manager_progress
  local worker_progress=""
  manager_progress="$(manager_file_path "$progress_file")"
  worker_progress="$(worker_progress_path_for "$progress_file")"
  if [[ -f "$manager_progress" ]] && codex_accepted "$manager_progress"; then
    printf '%s\n' "$manager_progress"
    return
  fi
  if [[ -n "$worker_progress" && -f "$worker_progress" ]] && handoff_reached "$worker_progress"; then
    printf '%s\n' "$worker_progress"
    return
  fi
  if [[ -f "$manager_progress" ]] && handoff_reached "$manager_progress"; then
    printf '%s\n' "$manager_progress"
    return
  fi
  if [[ -n "$worker_progress" && -f "$worker_progress" ]]; then
    printf '%s\n' "$worker_progress"
  else
    printf '%s\n' "$manager_progress"
  fi
}

codex_accepted() {
  local progress_file="$1"
  [[ -f "$progress_file" ]] || return 1
  rg -q '^Status:[[:space:]]*CODEX_ACCEPTED\b' "$progress_file"
}

handoff_reached() {
  local progress_file="$1"
  [[ -f "$progress_file" ]] || return 1
  final_handoff_token_reached "$progress_file"
}

final_handoff_token_reached() {
  local progress_file="$1"
  [[ -f "$progress_file" ]] || return 1
  if rg -q '^(Status:[[:space:]]*(DONE|DONE_WITH_CONCERNS|NEEDS_CONTEXT|BLOCKED|CODEX_ACCEPTED)|Final status token:[[:space:]]*(DONE|DONE_WITH_CONCERNS|NEEDS_CONTEXT|BLOCKED)|-[[:space:]]+HANDOFF:[[:space:]]*(DONE|DONE_WITH_CONCERNS|NEEDS_CONTEXT|BLOCKED))\b' "$progress_file"; then
    return 0
  fi
  awk '
    /^##[[:space:]]+HANDOFF([[:space:]]|$)/ { in_handoff = 1; next }
    in_handoff && /^##[[:space:]]+/ { exit }
    in_handoff && /^(Status:|Final status token:)[[:space:]]*(DONE|DONE_WITH_CONCERNS|NEEDS_CONTEXT|BLOCKED)([[:space:]]|$)/ { found = 1; exit }
    in_handoff && /^[[:space:]]*-[[:space:]]*HANDOFF:[[:space:]]*(DONE|DONE_WITH_CONCERNS|NEEDS_CONTEXT|BLOCKED)([[:space:]]|$)/ { found = 1; exit }
    END { exit found ? 0 : 1 }
  ' "$progress_file"
}

print_handoff_summary() {
  local progress_file="$1"
  [[ -f "$progress_file" ]] || return
  awk '
    /^##[[:space:]]+HANDOFF([[:space:]]|$)/ { in_handoff = 1; print; next }
    in_handoff && /^##[[:space:]]+/ { exit }
    in_handoff { print }
  ' "$progress_file"
}

progress_has_checkpoint() {
  local progress_file="$1"
  [[ -f "$progress_file" ]] || return 1
  rg -q '^(Status:[[:space:]]*(START|IN_PROGRESS|RED|IMPLEMENTED|TARGETED_VERIFIED|HANDOFF|DONE|DONE_WITH_CONCERNS|NEEDS_CONTEXT|BLOCKED|CODEX_REVIEWED|CODEX_ACCEPTED)|##[[:space:]]+(START|RED|IMPLEMENTED|TARGETED_VERIFIED|HANDOFF)\b)' "$progress_file"
}

progress_fingerprint() {
  local progress_file="$1"
  if [[ -f "$progress_file" ]]; then
    cksum "$progress_file" | awk '{print $1 ":" $2}'
  else
    printf 'missing\n'
  fi
}

print_wait_schedule() {
  local interval="$1"
  local max_checks="$2"
  if [[ "$interval" == "auto" ]]; then
    local index
    local last_index
    last_index=$((${#wait_schedule[@]} - 1))
    printf 'wait schedule:'
    for ((index = 0; index < max_checks; index++)); do
      printf ' %ss' "${wait_schedule[$index]:-${wait_schedule[$last_index]}}"
    done
    printf '\n'
  else
    echo "wait schedule: ${interval}s repeated $max_checks checks"
  fi
}

ensure_worker_worktree() {
  mkdir -p "$(dirname "$worker_path")"
  if [[ -d "$worker_path/.git" || -f "$worker_path/.git" ]]; then
    return
  fi

  if git show-ref --verify --quiet "refs/heads/$worker_branch"; then
    git worktree add "$worker_path" "$worker_branch"
  else
    git worktree add -b "$worker_branch" "$worker_path" HEAD
  fi
}

copy_repo_file_to_worker() {
  local rel_path
  rel_path="$(repo_relative_path "$1")"
  [[ -f "$repo_root/$rel_path" ]] || return
  mkdir -p "$worker_path/$(dirname "$rel_path")"
  cp "$repo_root/$rel_path" "$worker_path/$rel_path"
}

copy_progress_file_to_worker() {
  local rel_path
  local worker_progress
  rel_path="$(repo_relative_path "$1")"
  [[ -f "$repo_root/$rel_path" ]] || return
  worker_progress="$worker_path/$rel_path"
  mkdir -p "$worker_path/$(dirname "$rel_path")"
  if [[ "$overwrite_worker_progress" != "1" ]] && progress_has_checkpoint "$worker_progress"; then
    printf '{"event":"worker_progress_preserved","time":"%s","progress_file":"%s","reason":"existing-worker-checkpoints","overwrite_env":"%s"}\n' \
      "$(timestamp)" "$rel_path" "$overwrite_worker_progress" >> "$event_log"
    return
  fi
  cp "$repo_root/$rel_path" "$worker_progress"
}

sync_worker_task_docs() {
  local prompt_file="$1"
  local progress_file="$2"
  local progress_rel
  progress_rel="$(repo_relative_path "$progress_file")"
  copy_repo_file_to_worker "scripts/claude_delegate.sh"
  copy_repo_file_to_worker "scripts/claude_event_bridge.sh"
  copy_repo_file_to_worker "$prompt_file"
  copy_progress_file_to_worker "$progress_file"

  local task_doc
  for task_doc in "$task_root_abs"/"$subtask"*; do
    [[ -f "$task_doc" ]] || continue
    local task_doc_rel="${task_doc#$repo_root/}"
    [[ "$task_doc_rel" == "$progress_rel" ]] && continue
    copy_repo_file_to_worker "$task_doc_rel"
  done
}

run_print_claude() {
  (
    cd "$worker_path"
    exec claude -p \
      --output-format stream-json \
      --verbose \
      --include-hook-events \
      --include-partial-messages \
      --settings "$settings_file" \
      --setting-sources "$setting_sources" \
      --permission-mode "$permission_mode" \
      --model "$model" \
      --effort "$effort" \
      --tools "$tools" \
      --max-budget-usd "$max_budget" \
      --allowedTools "$allowed_tools" \
      -- \
      "$prompt"
  )
}

write_settings() {
  mkdir -p "$delegate_dir" "$log_dir"
  local bridge="$repo_root/scripts/claude_event_bridge.sh"
  cat > "$settings_file" <<EOF
{
  "hooks": {
    "SessionStart": [
      {
        "matcher": "",
        "hooks": [
          {"type": "command", "command": "$bridge '$event_log' session_start"}
        ]
      }
    ],
    "PostToolUse": [
      {
        "matcher": "",
        "hooks": [
          {"type": "command", "command": "$bridge '$event_log' post_tool_use"}
        ]
      }
    ],
    "Notification": [
      {
        "matcher": "",
        "hooks": [
          {"type": "command", "command": "$bridge '$event_log' notification"}
        ]
      }
    ],
    "Stop": [
      {
        "matcher": "",
        "hooks": [
          {"type": "command", "command": "$bridge '$event_log' stop"}
        ]
      }
    ],
    "SubagentStop": [
      {
        "matcher": "",
        "hooks": [
          {"type": "command", "command": "$bridge '$event_log' subagent_stop"}
        ]
      }
    ]
  }
}
EOF
}

preflight() {
  command -v claude >/dev/null || { echo "claude CLI not found" >&2; exit 69; }
  command -v git >/dev/null || { echo "git not found" >&2; exit 69; }
  if [[ "$effective_mode" == "tmux" ]]; then
    command -v tmux >/dev/null || { echo "tmux not found" >&2; exit 69; }
  fi
  resource_guard fail
  if [[ "$agent_preflight" == "1" ]]; then
    claude agents --json --cwd "$repo_root" >/dev/null
  fi
}

case "$cmd" in
  prepare)
    progress_file="$(progress_file_for "$@")"
    [[ -f "$progress_file" ]] || { echo "missing progress file: $progress_file" >&2; exit 66; }
    resolve_effective_mode
    preflight
    write_settings
    mkdir -p "$log_dir"
    printf '{"event":"manager_prepare","time":"%s","mode_requested":"%s","mode_effective":"%s","model":"%s","agent":"%s","tools":"%s","setting_sources":"%s","progress_file":"%s","settings_file":"%s","event_log":"%s","worker_path":"%s"}\n' \
      "$(timestamp)" "$mode" "$effective_mode" "$model" "$agent" "$tools" "$setting_sources" "$progress_file" "$settings_file" "$event_log" "$worker_path" >> "$event_log"
    echo "prepared claude delegation settings: $settings_file"
    echo "event log: $event_log"
    ;;

  launch)
    prompt_file="${1:-}"
    if [[ -z "$prompt_file" ]]; then
      usage >&2
      exit 64
    fi
    shift || true
    progress_file="$(progress_file_for "$@")"
    [[ -f "$prompt_file" ]] || { echo "missing prompt file: $prompt_file" >&2; exit 66; }
    [[ -f "$progress_file" ]] || { echo "missing progress file: $progress_file" >&2; exit 66; }
    resolve_effective_mode
    preflight
    write_settings
    : > "$event_log"
    if [[ "$prelaunch_cleanup" == "1" ]]; then
      cleanup_worker_processes "prelaunch"
    fi
    ensure_worker_worktree
    sync_worker_task_docs "$prompt_file" "$progress_file"

    prompt_file="$(repo_relative_path "$prompt_file")"
    progress_file="$(repo_relative_path "$progress_file")"
    worker_progress_file="$(worker_file_path "$progress_file")"

    prompt="Use the Claude skill codex-delegated-worker if available. You are running in the isolated worker worktree at $worker_path. Read $prompt_file and execute it exactly. The progress file is $progress_file and is the source of truth. Mark START before broad source inspection. Keep scope narrow. Do not commit unless the prompt explicitly allows it."

    printf '{"event":"manager_launch","time":"%s","mode_requested":"%s","mode_effective":"%s","model":"%s","agent":"%s","tools":"%s","setting_sources":"%s","prompt_file":"%s","progress_file":"%s","worker_progress_file":"%s","worker_path":"%s"}\n' \
      "$(timestamp)" "$mode" "$effective_mode" "$model" "$agent" "$tools" "$setting_sources" "$prompt_file" "$progress_file" "$worker_progress_file" "$worker_path" >> "$event_log"

    if [[ "$mode" != "$effective_mode" ]]; then
      printf '{"event":"manager_mode_fallback","time":"%s","from":"%s","to":"%s","reason":"non-interactive-shell"}\n' \
        "$(timestamp)" "$mode" "$effective_mode" >> "$event_log"
    fi

    if [[ "$effective_mode" == "print" ]]; then
      if [[ "$show_flow_logs" == "1" ]]; then
        run_print_claude | tee "$raw_log"
      else
        run_print_claude > "$raw_log"
      fi
    elif [[ "$effective_mode" == "tmux" ]]; then
      launch_status="0"
      tmux_arg="$(tmux_cli_args)"
      if claude \
        --worktree "$worktree_name" \
        "$tmux_arg" \
        --settings "$settings_file" \
        --setting-sources "$setting_sources" \
        --permission-mode "$permission_mode" \
        --model "$model" \
        --effort "$effort" \
        --agent "$agent" \
        --tools "$tools" \
        --allowedTools "$allowed_tools" \
        -- \
        "$prompt" > "$raw_log" 2>&1; then
        launch_status="0"
      else
        launch_status="$?"
      fi
      if [[ "$launch_status" == "0" ]] && rg -q 'open terminal failed: not a terminal' "$raw_log"; then
        launch_status="75"
        printf '{"event":"manager_launch_false_success","time":"%s","reason":"non-tty-classic-tmux","raw_log":"%s"}\n' \
          "$(timestamp)" "$raw_log" >> "$event_log"
      fi
      printf '{"event":"manager_launch_exit","time":"%s","exit_code":%s,"raw_log":"%s","event_log":"%s","mode":"foreground-observed"}\n' \
        "$(timestamp)" "$launch_status" "$raw_log" "$event_log" >> "$event_log"
      if [[ "$launch_status" != "0" ]]; then
        echo "claude tmux launch failed with exit code $launch_status; inspect progress first, then raw log if needed: $raw_log" >&2
        exit "$launch_status"
      fi
      echo "launched claude tmux session request exit=0"
      echo "event log: $event_log"
      echo "raw log: $raw_log"
    else
      echo "unknown CLAUDE_DELEGATE_MODE: $mode" >&2
      exit 64
    fi
    ;;

  status)
    resource_guard warn
    progress_file="$(progress_file_for "$@")"
    manager_progress="$(manager_file_path "$progress_file")"
    worker_progress="$(worker_progress_path_for "$progress_file")"
    active_progress="$(current_progress_path "$progress_file")"
    echo "active progress: $active_progress"
    [[ -f "$active_progress" ]] && sed -n '1,80p' "$active_progress" || true
    if handoff_reached "$active_progress"; then
      echo
      echo "active handoff summary:"
      print_handoff_summary "$active_progress"
    fi
    echo
    echo "manager progress: $manager_progress"
    [[ -f "$manager_progress" ]] && sed -n '1,40p' "$manager_progress" || true
    if [[ -n "$worker_progress" ]]; then
      echo
      echo "worker progress: $worker_progress"
      [[ -f "$worker_progress" ]] && sed -n '1,40p' "$worker_progress" || true
    fi
    echo
    echo "flow logs retained:"
    echo "  events: $event_log"
    echo "  raw: $raw_log"
    if [[ "$show_flow_logs" == "1" ]]; then
      echo
      echo "flow event tail:"
      [[ -f "$event_log" ]] && tail -n 20 "$event_log" || true
    else
      echo "  set CLAUDE_DELEGATE_SHOW_FLOW_LOGS=1 to inspect after a problem or failed acceptance."
    fi
    echo
    print_worker_liveness
    active_worker_count="$(worker_process_count)"
    if ! handoff_reached "$active_progress" && ! progress_has_checkpoint "$active_progress" && [[ "$active_worker_count" == "0" ]]; then
      echo "worker liveness warning: no active worker process and no conclusion checkpoint; launch likely failed before START"
    fi
    echo
    echo "worker git status:"
    [[ -d "$worker_path/.git" || -f "$worker_path/.git" ]] && git -C "$worker_path" status --short || true
    if [[ "$show_flow_logs" == "1" ]]; then
      echo
      echo "agents:"
      claude agents --json --cwd "$repo_root" || true
    fi
    ;;

  wait)
    resource_guard fail
    progress_file="$(progress_file_for "${1:-}")"
    interval="${2:-auto}"
    max_checks="${3:-}"
    if [[ "$interval" == "auto" ]]; then
      IFS=',' read -r -a wait_schedule <<< "${CLAUDE_DELEGATE_WAIT_SCHEDULE:-180,360,540}"
      if [[ -z "$max_checks" ]]; then
        max_checks="${#wait_schedule[@]}"
      fi
    else
      if [[ -z "$max_checks" ]]; then
        max_checks="5"
      fi
    fi
    print_wait_schedule "$interval" "$max_checks"
    last_fingerprint=""
    initial_fingerprint=""
    progress_changed="0"
    for ((check = 1; check <= max_checks; check++)); do
      echo "check $check/$max_checks at $(timestamp)"
      active_progress="$(current_progress_path "$progress_file")"
      if handoff_reached "$active_progress"; then
        echo "HANDOFF found in $active_progress"
        exit 0
      fi
      print_worker_liveness
      fingerprint="$(progress_fingerprint "$active_progress")"
      if [[ -z "$initial_fingerprint" ]]; then
        initial_fingerprint="$fingerprint"
      elif [[ "$fingerprint" != "$initial_fingerprint" ]]; then
        progress_changed="1"
      fi
      if [[ -n "$last_fingerprint" && "$fingerprint" == "$last_fingerprint" ]]; then
        echo "no new conclusion progress since previous check"
      fi
      last_fingerprint="$fingerprint"
      echo "no HANDOFF yet; conclusion source: $active_progress"
      active_worker_count="$(worker_process_count)"
      if [[ "$active_worker_count" == "0" ]] && ! progress_has_checkpoint "$active_progress"; then
        echo "no active worker process and no conclusion checkpoint; launch likely failed before START" >&2
        exit 75
      fi
      if [[ "$show_flow_logs" == "1" && -f "$event_log" ]]; then
        tail -n 5 "$event_log"
      fi
      if [[ "$check" -lt "$max_checks" ]]; then
        if [[ "$interval" == "auto" ]]; then
          schedule_index=$((check - 1))
          last_schedule_index=$((${#wait_schedule[@]} - 1))
          sleep_for="${wait_schedule[$schedule_index]:-${wait_schedule[$last_schedule_index]}}"
        else
          sleep_for="$interval"
        fi
        echo "next check in ${sleep_for}s"
        sleep "$sleep_for"
      fi
    done
    if [[ "$progress_changed" == "0" ]]; then
      echo "no HANDOFF after $max_checks checks and no conclusion-progress movement; manager intervention is allowed after stall classification" >&2
      if [[ "$cleanup_on_stall" == "1" ]]; then
        cleanup_worker_processes "wait-stall"
      fi
    else
      echo "no HANDOFF after $max_checks checks, but conclusion progress moved; inspect the progress file first and allow one more check if build/test work is still active" >&2
    fi
    echo "flow logs remain diagnostic only; open them only for launch failure, contradiction, missing verification, or failed acceptance" >&2
    exit 75
    ;;

  cleanup)
    resource_guard warn
    progress_file="$(progress_file_for "$@")"
    mkdir -p "$log_dir"
    cleanup_worker_processes "manual"
    print_worker_liveness
    ;;

  *)
    usage >&2
    exit 64
    ;;
esac
