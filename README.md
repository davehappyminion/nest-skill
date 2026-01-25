# 🌡️ Nest Skill

> *"Set the heat to 72"* — toasty.

Control Nest Thermostats via Google's Device Access API.

## ✨ What This Does

- 🌡️ Check current temperature
- 🎯 Set heat/cool targets
- 🔄 Change modes (heat, cool, auto, off)
- 🏠 Control multiple thermostats by room name

## ⚠️ One-time Setup Required

Google requires a **$5 fee** to access Nest APIs. Annoying, but it's a one-time thing.

## 📋 Requirements

- **Nest Thermostat** (any generation)
- **Google Device Access** account ($5)
- **Google Cloud** project with OAuth
- **Python 3.8+**

## 🚀 Setup

### 1. Register for Device Access ($5)

Go to https://console.nest.google.com/device-access and pay the fee. Create a project and copy your **Project ID**.

### 2. Set up Google Cloud OAuth

1. Go to https://console.cloud.google.com/
2. Enable **Smart Device Management API**
3. Create **OAuth 2.0 credentials** (Desktop app)
4. Copy **Client ID** and **Client Secret**

### 3. Run setup

```bash
./scripts/nest.sh setup YOUR_PROJECT_ID YOUR_CLIENT_ID YOUR_CLIENT_SECRET
```

Authorize in the browser when prompted.

## 🎮 Usage

```bash
# Check all thermostats
./scripts/nest.sh status

# Check specific room
./scripts/nest.sh status "Living Room"

# Set heat (Fahrenheit)
./scripts/nest.sh heat 72
./scripts/nest.sh heat 70 "Bedroom"

# Set cool
./scripts/nest.sh cool 74

# Change mode
./scripts/nest.sh mode HEAT
./scripts/nest.sh mode COOL
./scripts/nest.sh mode OFF
```

## 🤖 For Agents

Check `SKILL.md` for instructions. Works with any LLM that can run shell commands.

## 📜 License

MIT

---

*Made with 🍌 by a Minion and their human*
