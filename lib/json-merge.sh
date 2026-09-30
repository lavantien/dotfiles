#!/usr/bin/env bash
# JSON merge helpers sourced by deploy.sh.
# Requires jq or python3; degrades by skipping, never by clobbering.
# Expects $SCRIPT_DIR and the deploy.sh color vars to be set by the caller.

# Delete dotted paths listed in .claude/settings.retired.json from the merged
# settings file. The file maps "section.key" paths to the reason and reference
# for retirement. Skips silently when the list is absent or unparsable.
retire_settings_keys() {
	local merged="$1"
	local retired="$SCRIPT_DIR/.claude/settings.retired.json"
	[[ -f "$retired" ]] || return 0

	if command -v jq >/dev/null 2>&1; then
		local out="${merged}.retired"
		# Only paths whose parent resolves to an object are deletable; getpath
		# returns null for scalar or missing intermediates, so those skip
		if jq --slurpfile r "$retired" '
			. as $doc |
			[$r[0] | keys[] | split(".") | . as $p
				| select(($doc | getpath($p[:-1]) | type) == "object")] as $del |
			$doc | delpaths($del)
		' "$merged" >"$out" 2>/dev/null; then
			mv "$out" "$merged"
		else
			rm -f "$out"
		fi
	elif command -v python3 >/dev/null 2>&1; then
		python3 - "$merged" "$retired" <<'PY'
import json, sys

try:
    with open(sys.argv[2], encoding="utf-8") as f:
        retired = json.load(f)
except (OSError, ValueError):
    sys.exit(0)
if not isinstance(retired, dict):
    sys.exit(0)
with open(sys.argv[1], encoding="utf-8") as f:
    doc = json.load(f)
for dotted in retired:
    segs = dotted.split(".")
    node = doc
    for seg in segs[:-1]:
        node = node.get(seg) if isinstance(node, dict) else None
        if node is None:
            break
    if isinstance(node, dict):
        node.pop(segs[-1], None)
with open(sys.argv[1], "w", encoding="utf-8") as f:
    json.dump(doc, f, indent=2)
    f.write("\n")
PY
	fi
}

# Template-priority merge of the committed template into live Claude Code settings.
# Template values win for shared keys recursively; live-only keys are preserved.
# env.ANTHROPIC_AUTH_TOKEN never exists in the template, so it is never touched.
inject_claude_settings() {
	local template="$SCRIPT_DIR/.claude/settings.template.json"
	local settings="$HOME/.claude/settings.json"

	if [[ ! -f "$template" ]]; then
		echo -e "${YELLOW}Settings template not found: $template${NC}"
		return 0
	fi

	# No live settings yet: seed from template (covers statusLine on fresh installs)
	if [[ ! -f "$settings" ]]; then
		cp "$template" "$settings"
		retire_settings_keys "$settings"
		echo -e "${GREEN}Created $settings from template${NC}"
		return 0
	fi

	local tmp="${settings}.tmp"

	if command -v jq >/dev/null 2>&1; then
		# jq object-multiply: .[1] (live) * .[0] (template), template wins shared
		# keys recursively, live-only keys survive
		if jq -s '.[1] * .[0]' "$template" "$settings" >"$tmp" 2>/dev/null; then
			retire_settings_keys "$tmp"
			mv "$tmp" "$settings"
			echo -e "${GREEN}Claude settings merged (template values applied, local-only keys preserved)${NC}"
			return 0
		fi
		rm -f "$tmp"
	elif command -v python3 >/dev/null 2>&1; then
		if python3 - "$template" "$settings" >"$tmp" <<'PY'
import json, sys

def overlay(live, template):
    if isinstance(live, dict) and isinstance(template, dict):
        out = dict(live)
        for key, value in template.items():
            out[key] = overlay(live[key], value) if key in live else value
        return out
    return template

with open(sys.argv[1]) as f:
    template = json.load(f)
with open(sys.argv[2]) as f:
    live = json.load(f)
if not isinstance(template, dict) or not isinstance(live, dict):
    sys.exit(1)
print(json.dumps(overlay(live, template), indent=2))
PY
		then
			retire_settings_keys "$tmp"
			mv "$tmp" "$settings"
			echo -e "${GREEN}Claude settings merged (template values applied, local-only keys preserved)${NC}"
			return 0
		fi
		rm -f "$tmp"
	else
		echo -e "${YELLOW}Neither jq nor python3 found, skipping settings merge${NC}"
		return 0
	fi

	echo -e "${YELLOW}$settings is not a valid JSON object, skipping settings merge${NC}"
	return 0
}

# Deep-merge MCP servers from the platform template into an existing
# opencode.json. Template values win for template-defined properties,
# user-added servers and user-added keys are preserved. Mirrors the
# Compare-Property merge in deploy.ps1.
merge_opencode_config() {
	local target="$1"
	local template="$2"

	command -v jq >/dev/null 2>&1 || {
		echo -e "${YELLOW}jq not found, skipping smart merge of OpenCode MCPs${NC}"
		return 0
	}

	# Repair a missing or scalar (malformed) mcp section before indexing into it
	if ! jq -e '(.mcp | type) == "object"' "$target" >/dev/null 2>&1; then
		local repaired="${target}.tmp"
		if jq '.mcp = {}' "$target" >"$repaired" 2>/dev/null; then
			mv "$repaired" "$target"
			echo -e "${YELLOW}Repaired malformed mcp section in opencode.json${NC}"
		else
			rm -f "$repaired"
			echo -e "${YELLOW}opencode.json is not valid JSON, skipping smart merge${NC}"
			return 0
		fi
	fi

	local merged=0
	local mcp tmpl_val live_val new_val
	local tmp="${target}.tmp"
	while IFS= read -r mcp; do
		tmpl_val=$(jq ".mcp[\"$mcp\"]" "$template")
		live_val=$(jq "if (.mcp[\"$mcp\"] | type) == \"object\" then .mcp[\"$mcp\"] else {} end" "$target")
		# live * template: template wins shared keys recursively,
		# user-only keys inside the server entry survive
		new_val=$(jq -n --argjson a "$live_val" --argjson b "$tmpl_val" '$a * $b')
		if [[ "$new_val" != "$live_val" ]]; then
			jq --arg mcp "$mcp" --argjson config "$new_val" '.mcp[$mcp] = $config' "$target" >"$tmp" &&
				mv "$tmp" "$target"
			((merged++)) || true
		fi
	done < <(jq -r '.mcp | keys[]' "$template")

	if ((merged > 0)); then
		echo -e "${GREEN}OpenCode config merged $merged MCP server(s) from template${NC}"
	else
		echo -e "${BLUE}OpenCode config up to date with template MCPs${NC}"
	fi
}

# On Linux/macOS, remove cmd.exe wrappers that a marketplace.json carried
# over from a Windows machine may contain for npm-installed LSP servers.
# Mirrors the gh.exe cleanup in update_git_config. Idempotent: silent when
# nothing changes.
strip_windows_lsp_wrappers() {
	case "$OS" in
	linux | macos) ;;
	*) return 0 ;;
	esac

	local marketplace="$HOME/.claude/plugins/marketplaces/claude-plugins-official/.claude-plugin/marketplace.json"
	[[ -f "$marketplace" ]] || return 0
	command -v jq >/dev/null 2>&1 || return 0

	local tmp="${marketplace}.tmp"
	if ! jq '
		def bins: {
			"typescript": "typescript-language-server",
			"pyright": "pyright-langserver",
			"intelephense": "intelephense"
		};
		.plugins //= [] |
		.plugins |= map(
			if has("lspServers") and (.lspServers | type) == "object"
			then .lspServers |= with_entries(
				(bins[.key]) as $bin |
				if $bin != null and (.value.command? == "cmd.exe")
				then .value.command = $bin | .value.args = ["--stdio"]
				else .
				end
			)
			else .
			end
		)' "$marketplace" >"$tmp" 2>/dev/null; then
		rm -f "$tmp"
		return 0
	fi

	if cmp -s "$tmp" "$marketplace"; then
		rm -f "$tmp"
		return 0
	fi

	if jq -e . "$tmp" >/dev/null 2>&1; then
		mv "$tmp" "$marketplace"
		echo -e "${GREEN}Stripped cmd.exe wrappers from Claude LSP marketplace${NC}"
	else
		rm -f "$tmp"
	fi
}
