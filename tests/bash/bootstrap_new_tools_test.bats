#!/usr/bin/env bats
# Unit tests for new tools being added to bootstrap.sh
# Tests that installation code exists for each new tool

setup() {
    export SCRIPT_DIR="$(cd "$(dirname "$BATS_TEST_DIRNAME")/.." && pwd)"
    export BOOTSTRAP_DIR="$SCRIPT_DIR/bootstrap"
    export BOOTSTRAP_SH="$BOOTSTRAP_DIR/bootstrap.sh"
}

@test "bootstrap.sh contains pytest installation" {
    run grep -q "pytest" "$BOOTSTRAP_SH"
    [ "$status" -eq 0 ]
}

@test "bootstrap.sh contains cppcheck installation" {
    run grep -q "cppcheck" "$BOOTSTRAP_SH"
    [ "$status" -eq 0 ]
}

@test "bootstrap.sh contains composer installation" {
    run grep -q "composer" "$BOOTSTRAP_SH"
    [ "$status" -eq 0 ]
}

@test "bootstrap.sh contains pint installation" {
    run grep -q "pint" "$BOOTSTRAP_SH"
    [ "$status" -eq 0 ]
}

@test "bootstrap.sh contains phpstan installation" {
    run grep -q "phpstan" "$BOOTSTRAP_SH"
    [ "$status" -eq 0 ]
}

@test "bootstrap.sh contains psalm installation" {
    run grep -q "psalm" "$BOOTSTRAP_SH"
    [ "$status" -eq 0 ]
}

@test "bootstrap.sh contains stylua installation" {
    run grep -q "stylua" "$BOOTSTRAP_SH"
    [ "$status" -eq 0 ]
}

@test "bootstrap.sh contains selene installation" {
    run grep -q "selene" "$BOOTSTRAP_SH"
    [ "$status" -eq 0 ]
}

@test "bootstrap.sh contains busted installation" {
    run grep -q "busted" "$BOOTSTRAP_SH"
    [ "$status" -eq 0 ]
}

@test "bootstrap.sh contains scalafix installation" {
    run grep -q "scalafix" "$BOOTSTRAP_SH"
    [ "$status" -eq 0 ]
}

@test "bootstrap.sh contains checkstyle installation" {
    run grep -q "checkstyle" "$BOOTSTRAP_SH"
    [ "$status" -eq 0 ]
}

@test "bootstrap.sh contains catch2 installation" {
    run grep -q "catch2" "$BOOTSTRAP_SH"
    [ "$status" -eq 0 ]
}
