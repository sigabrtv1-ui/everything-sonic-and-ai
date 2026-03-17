# Agent Skills

This directory contains reusable skills that can be composed into AI agents.

## Overview

A skill is a self-contained unit of functionality that an agent can invoke. Skills encapsulate specific capabilities (e.g., querying SONiC state, applying configuration changes, or interpreting telemetry data).

## Adding a Skill

Place each skill in its own subdirectory with the following layout:

```
skills/
└── <skill-name>/
    ├── README.md       # Description and usage
    └── skill.py        # Skill implementation (or other entry point)
```
