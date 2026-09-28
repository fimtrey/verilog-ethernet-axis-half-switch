# SPDX-FileCopyrightText: 2026 Tim Frey
# SPDX-License-Identifier: Apache-2.0

# Run the Python test suite.
test:
    uv run pytest

# Check REUSE compliance and run `uv check`.
lint:
    uv run reuse lint
    uv check

# Format Python and Verilog/SystemVerilog sources.
format:
    uv format
    uv run verible-cli verible-verilog-format --flagfile .verilog_format --inplace src/*.v src/*.sv

# Run all checks: format, lint, and test.
all: format lint test
