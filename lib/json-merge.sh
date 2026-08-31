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
