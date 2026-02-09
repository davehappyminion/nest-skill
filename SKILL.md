---
name: nest
description: Control Nest Thermostats via Google Device Access API. Use for checking temperature, setting heat/cool targets, and changing modes. Requires one-time Google setup ($5 fee).
---

# Nest Thermostat

Control Nest Thermostats via Google's Smart Device Management (SDM) API.

## Requirements

- Nest Thermostat (any generation)
- Google Device Access Console account ($5 one-time fee)
- Google Cloud project with OAuth credentials

## Initial Setup (One-time)

### 1. Register for Device Access

1. Go to https://console.nest.google.com/device-access
2. Pay the $5 registration fee
3. Create a project → note the **Project ID**

### 2. Set up Google Cloud OAuth

1. Go to https://console.cloud.google.com/
2. Create or select a project
3. Enable **Smart Device Management API**
4. Create **OAuth 2.0 credentials** (Desktop app)
5. Note the **Client ID** and **Client Secret**

### 3. Run setup

```bash
{baseDir}/scripts/nest.sh setup <project_id> <client_id> <client_secret>
```

This opens a browser for authorization. Click through to allow access.

## Commands

```bash
# Check status of all thermostats
{baseDir}/scripts/nest.sh status

# Check specific thermostat
{baseDir}/scripts/nest.sh status "Living Room"

# Set heat target (Fahrenheit)
{baseDir}/scripts/nest.sh heat 72
{baseDir}/scripts/nest.sh heat 72 "Bedroom"

# Set cool target (Fahrenheit)
{baseDir}/scripts/nest.sh cool 74
{baseDir}/scripts/nest.sh cool 74 "Living Room"

# Change mode
{baseDir}/scripts/nest.sh mode HEAT
{baseDir}/scripts/nest.sh mode COOL
{baseDir}/scripts/nest.sh mode HEATCOOL
{baseDir}/scripts/nest.sh mode OFF
```

## Configuration

Config files in `{baseDir}/config/`:
- `config.json` — Project ID, OAuth credentials
- `tokens.json` — Access/refresh tokens (auto-managed)

## Multiple Thermostats

If you have multiple thermostats, specify by room name:

```bash
{baseDir}/scripts/nest.sh heat 70 "Bedroom"
{baseDir}/scripts/nest.sh status "Living Room"
```

Without a room name, `mode` applies to all thermostats. Other commands (`heat`, `cool`, `status`) affect the first thermostat found.

## Troubleshooting

**"Not authorized"** — Run setup again to re-authenticate

**"No thermostat found"** — Check your Nest app, ensure device is online

**"API error"** — Token may have expired; script auto-refreshes, but re-run setup if needed
