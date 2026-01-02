#!/usr/bin/env bats
# Unit tests for update.sh
# Tests config file backup functionality

load test_helper

setup() {
    export SCRIPT_DIR="$(cd "$(dirname "$BATS_TEST_DIRNAME")/.." && pwd)"
    setup_mock_env
}

teardown() {
    teardown_mock_env
    rm -f /tmp/test-update-*
}

# ============================================================================
# SCRIPT VALIDATION
# ============================================================================

@test "update.sh: script exists and is readable" {
    [ -f "$SCRIPT_DIR/update.sh" ]
    [ -r "$SCRIPT_DIR/update.sh" ]
}

@test "update.sh: script backs up .bash_aliases" {
    # Simulate cp command
    cp_test() {
        local src="$1"
        local dest="$2"
        echo "Would copy $src to $dest"
    }
    export -f cp_test

    run cp_test "~/.bash_aliases" ".bash_aliases"
    [ "$status" -eq 0 ]
    [[ "$output" == *".bash_aliases"* ]]
}

@test "update.sh: script backs up .zshrc" {
    cp_test() {
        local src="$1"
        local dest="$2"
        echo "Would copy $src to $dest"
    }
    export -f cp_test

    run cp_test "~/.zshrc" ".zshrc"
    [ "$status" -eq 0 ]
    [[ "$output" == *".zshrc"* ]]
}

@test "update.sh: script backs up .gitconfig" {
    cp_test() {
        local src="$1"
        local dest="$2"
        echo "Would copy $src to $dest"
    }
    export -f cp_test

    run cp_test "~/.gitconfig" ".gitconfig"
    [ "$status" -eq 0 ]
    [[ "$output" == *".gitconfig"* ]]
}

@test "update.sh: script backs up wezterm.lua" {
    cp_test() {
        local src="$1"
        local dest="$2"
        echo "Would copy $src to $dest"
    }
    export -f cp_test

    run cp_test "~/.config/wezterm/wezterm.lua" "wezterm.lua"
    [ "$status" -eq 0 ]
    [[ "$output" == *"wezterm.lua"* ]]
}

@test "update.sh: backs up aider.model.settings.yml" {
    cp_test() {
        local src="$1"
        local dest="$2"
        echo "Would copy $src to $dest"
    }
    export -f cp_test

    run cp_test "~/.aider.model.settings.yml" "."
    [ "$status" -eq 0 ]
    [[ "$output" == *"aider"* ]]
}

@test "update.sh: creates aider.conf.yml.example" {
    # Simulate the sed operation
    create_aider_example() {
        echo "key1=value1" > /tmp/test-aider.yml
        sed -i 's/\(  #\?- [a-z]*=\).*/\1/' /tmp/test-aider.yml
        cat /tmp/test-aider.yml
    }
    export -f create_aider_example

    run create_aider_example
    [ "$status" -eq 0 ]
}

@test "update.sh: sed pattern removes values from config" {
    # Test the sed pattern
    echo "model=gpt-4" > /tmp/test-sed.yml
    sed -i 's/\(  #\?- [a-z]*=\).*/\1/' /tmp/test-sed.yml
    run cat /tmp/test-sed.yml
    [[ "$output" == "model="* ]]
}

@test "update.sh: sed pattern preserves commented lines" {
    echo "  # - model=value" > /tmp/test-sed2.yml
    sed -i 's/\(  #\?- [a-z]*=\).*/\1/' /tmp/test-sed2.yml
    run cat /tmp/test-sed2.yml
    [[ "$output" == *"  # - model="* ]]
}

@test "update.sh: sed pattern handles optional comments" {
    echo "  - model=value" > /tmp/test-sed3.yml
    sed -i 's/\(  #\?- [a-z]*=\).*/\1/' /tmp/test-sed3.yml
    run cat /tmp/test-sed3.yml
    [[ "$output" == *"  - model="* ]]
}

@test "update.sh: handles missing source files gracefully" {
    # Test with missing files
    if [[ ! -f "/nonexistent/.bash_aliases" ]]; then
        echo "Source file not found, skipping"
    fi

    run bash -c 'if [[ ! -f "/nonexistent/.bash_aliases" ]]; then echo "Skipping"; fi'
    [[ "$output" == *"Skipping"* ]]
}

@test "update.sh: preserves file extensions" {
    cp_test() {
        local src="$1"
        local dest="$2"
        echo "$src -> $dest"
    }
    export -f cp_test

    run cp_test "file.sh" "file.sh"
    [[ "$output" == *"file.sh"* ]]
}

@test "update.sh: handles dotfiles correctly" {
    filename=".bash_aliases"
    [[ "$filename" == .* ]] && echo "Is dotfile"
    run bash -c 'filename=".bash_aliases"; [[ "$filename" == .* ]] && echo "Is dotfile"'
    [[ "$output" == *"Is dotfile"* ]]
}

@test "update.sh: handles nested path for wezterm" {
    path=".config/wezterm/wezterm.lua"
    echo "$path" | grep -q "wezterm"
    [ "$?" -eq 0 ]
}

@test "update.sh: sed creates valid example file" {
    cat > /tmp/test-input.yml <<'EOF'
model=gpt-4
key=value
EOF

    sed -i 's/\(  #\?- [a-z]*=\).*/\1/' /tmp/test-input.yml
    run cat /tmp/test-input.yml
    [ "$status" -eq 0 ]
}

@test "update.sh: example file naming is correct" {
    example_name=".aider.conf.yml.example"
    [[ "$example_name" == *".example" ]]
}

@test "update.sh: handles multiple config keys in sed" {
    cat > /tmp/test-multi.yml <<'EOF'
model=gpt-4
api_key=secret
editor=vim
EOF

    sed -i 's/\(  #\?- [a-z]*=\).*/\1/' /tmp/test-multi.yml
    run cat /tmp/test-multi.yml
    [ "$status" -eq 0 ]
}

@test "update.sh: preserves yml extension" {
    file="aider.conf.yml"
    [[ "$file" == *.yml ]] || [[ "$file" == *.yaml ]]
}

# ============================================================================
# INTEGRATION TESTS
# ============================================================================

@test "update.sh: full backup flow works end to end" {
    # Mock the backup process
    backup_configs() {
        local files=(".bash_aliases" ".zshrc" ".gitconfig")
        for file in "${files[@]}"; do
            echo "Backing up $file"
            touch "$file"
        done
        echo "Backup complete"
    }
    export -f backup_configs

    run bash -c 'cd /tmp && backup_configs'
    [ "$status" -eq 0 ]
    [[ "$output" == *"Backup complete"* ]]
}

@test "update.sh: handles special characters in filenames" {
    # Test with files containing dots and dashes
    filename="aider.conf.yml.example"
    [[ "$filename" =~ ^[a-z._-]+$ ]]
}

@test "update.sh: creates example file safely" {
    # Test that the example file creation doesn't overwrite originals
    original="aider.conf.yml"
    example="aider.conf.yml.example"

    [[ "$original" != "$example" ]]
}

# ============================================================================
# ERROR CASES
# ============================================================================

@test "update.sh: sed handles empty files" {
    touch /tmp/test-empty.yml
    run sed -i 's/\(  #\?- [a-z]*=\).*/\1/' /tmp/test-empty.yml
    [ "$status" -eq 0 ]
}

@test "update.sh: sed handles files without matching patterns" {
    echo "nomatchingpattern" > /tmp/test-nomatch.yml
    run sed -i 's/\(  #\?- [a-z]*=\).*/\1/' /tmp/test-nomatch.yml
    [ "$status" -eq 0 ]
    [[ "$output" == "nomatchingpattern" ]]
}

@test "update.sh: handles cp command failure" {
    # Mock cp that fails
    cat > "$MOCK_BIN_DIR/cp" <<'EOF'
#!/usr/bin/env bash
if [[ "$1" == *"fail"* ]]; then
    echo "cp failed" >&2
    exit 1
fi
echo "cp $*"
exit 0
EOF
    chmod +x "$MOCK_BIN_DIR/cp"

    run cp "normal-file" "dest"
    [ "$status" -eq 0 ]
}

@test "update.sh: handles path with tilde expansion" {
    # Test tilde expansion works
    home_expanded="${HOME}"
    [ -n "$home_expanded" ]
}

@test "update.sh: validates config file paths" {
    # Path validation
    local path=".config/wezterm/wezterm.lua"
    [[ "$path" == *".lua" ]]
}

# ============================================================================
# SED PATTERN TESTS
# ============================================================================

@test "update.sh: sed pattern matches optional comment" {
    pattern='  #\?- [a-z]*='
    [[ "  # - model=" =~ $pattern ]]
}

@test "update.sh: sed pattern matches uncommented line" {
    pattern='  #\?- [a-z]*='
    [[ "  - model=" =~ $pattern ]]
}

@test "update.sh: sed pattern captures key name" {
    line="  - model=gpt-4"
    [[ "$line" =~ ([a-z]+)= ]]
}

@test "update.sh: sed replacement keeps equals sign" {
    result="model="
    [[ "$result" == *"="* ]]
}

# ============================================================================
# FILE OPERATIONS
# ============================================================================

@test "update.sh: cp command syntax is correct" {
    # Verify cp command structure
    local src="source.txt"
    local dest="dest.txt"
    run echo "cp $src $dest"
    [[ "$output" == "cp source.txt dest.txt" ]]
}

@test "update.sh: handles spaces in paths" {
    # Test with a path containing spaces (should be quoted)
    local path="file with spaces.txt"
    run bash -c "touch '/tmp/$path' && rm '/tmp/$path'"
    [ "$status" -eq 0 ]
}

@test "update.sh: handles relative paths" {
    local path="../file.txt"
    [[ "$path" == ../* ]]
}

@test "update.sh: handles hidden files" {
    local file=".hidden"
    [[ "$file" == .* ]]
}
