#!/usr/bin/env bash

setup() {
    load '../lib/logging.sh'
}

@test "Check that log_info prints messages" {
  run log_info "Test message"
  [ "$status" -eq 0 ]
  [[ "$output" =~ "Test message" ]]
}
