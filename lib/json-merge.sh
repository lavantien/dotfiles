#!/usr/bin/env bash
# JSON merge helpers sourced by deploy.sh.
# Requires jq or python3; degrades by skipping, never by clobbering.
# Expects $SCRIPT_DIR and the deploy.sh color vars to be set by the caller.

# Fill-missing merge of the committed template into live Claude Code settings.
# Live values always win; the template only adds missing keys recursively.
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
		echo -e "${GREEN}Created $settings from template${NC}"
		return 0
	fi

	local tmp="${settings}.tmp"

	if command -v jq >/dev/null 2>&1; then
		# jq object-multiply: recursive merge, right operand (live) wins
		if jq -s '.[0] * .[1]' "$template" "$settings" >"$tmp" 2>/dev/null; then
			mv "$tmp" "$settings"
			echo -e "${GREEN}Claude settings merged (missing fields filled, existing values preserved)${NC}"
			return 0
		fi
		rm -f "$tmp"
	elif command -v python3 >/dev/null 2>&1; then
		if python3 - "$template" "$settings" >"$tmp" <<'PY'
import json, sys

def fill(template, live):
    if isinstance(template, dict) and isinstance(live, dict):
        out = dict(live)
        for key, value in template.items():
            out[key] = fill(value, live[key]) if key in live else value
        return out
    return live

with open(sys.argv[1]) as f:
    template = json.load(f)
with open(sys.argv[2]) as f:
    live = json.load(f)
print(json.dumps(fill(template, live), indent=2))
PY
		then
			mv "$tmp" "$settings"
			echo -e "${GREEN}Claude settings merged (missing fields filled, existing values preserved)${NC}"
			return 0
		fi
		rm -f "$tmp"
	else
		echo -e "${YELLOW}Neither jq nor python3 found, skipping settings merge${NC}"
		return 0
	fi

	echo -e "${YELLOW}$settings is not valid JSON, skipping settings merge${NC}"
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
