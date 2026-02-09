#!/usr/bin/env bash
# Nest Thermostat control script
set -e

CONFIG_DIR="${HOME}/.openclaw/integrations/nest"
mkdir -p "$CONFIG_DIR"

python3 - "$@" << 'PYTHON_SCRIPT'
import json
import sys
import os
import webbrowser
import http.server
import urllib.request
import urllib.parse
import urllib.error
import threading

CONFIG_DIR = os.path.expanduser("~/.openclaw/integrations/nest")
CONFIG_FILE = f"{CONFIG_DIR}/config.json"
TOKEN_FILE = f"{CONFIG_DIR}/tokens.json"

def load_json(path):
    if os.path.exists(path):
        with open(path) as f:
            return json.load(f)
    return {}

def save_json(path, data):
    with open(path, "w") as f:
        json.dump(data, f, indent=2)

def api_request(method, url, data=None, headers=None):
    req = urllib.request.Request(url, method=method, headers=headers or {})
    if data:
        req.data = json.dumps(data).encode() if isinstance(data, dict) else urllib.parse.urlencode(data).encode()
    try:
        with urllib.request.urlopen(req, timeout=30) as resp:
            body = resp.read().decode().strip()
            if not body or body == "{}":
                return {"status": "success"}
            return json.loads(body)
    except urllib.error.HTTPError as e:
        return {"error": e.code, "message": e.read().decode()}

config = load_json(CONFIG_FILE)
tokens = load_json(TOKEN_FILE)

def refresh_token():
    global tokens
    if not tokens.get("refresh_token"):
        return False
    result = api_request("POST", "https://www.googleapis.com/oauth2/v4/token", {
        "client_id": config["client_id"],
        "client_secret": config["client_secret"],
        "refresh_token": tokens["refresh_token"],
        "grant_type": "refresh_token",
    }, {"Content-Type": "application/x-www-form-urlencoded"})
    if "access_token" in result:
        tokens["access_token"] = result["access_token"]
        save_json(TOKEN_FILE, tokens)
        return True
    return False

def sdm_request(endpoint, method="GET", data=None):
    if not config.get("project_id") or not tokens.get("access_token"):
        print("Not configured. Run: nest.sh setup <project_id> <client_id> <client_secret>")
        sys.exit(1)

    base = "https://smartdevicemanagement.googleapis.com/v1"
    if endpoint.startswith("/enterprises/"):
        url = f"{base}{endpoint}"
    else:
        url = f"{base}/enterprises/{config['project_id']}{endpoint}"
    headers = {"Authorization": f"Bearer {tokens['access_token']}", "Content-Type": "application/json"}

    result = api_request(method, url, data, headers)
    if result.get("error") == 401:
        if refresh_token():
            headers["Authorization"] = f"Bearer {tokens['access_token']}"
            result = api_request(method, url, data, headers)
    return result

def setup(project_id, client_id, client_secret):
    save_json(CONFIG_FILE, {
        "project_id": project_id,
        "client_id": client_id,
        "client_secret": client_secret,
    })
    
    redirect_uri = "http://localhost:8888/callback"
    scope = "https://www.googleapis.com/auth/sdm.service"
    auth_url = (
        f"https://nestservices.google.com/partnerconnections/{project_id}/auth"
        f"?redirect_uri={redirect_uri}&access_type=offline&prompt=consent"
        f"&client_id={client_id}&response_type=code&scope={scope}"
    )
    
    print("Opening browser for authorization...")
    webbrowser.open(auth_url)
    
    code_holder = {}
    
    class Handler(http.server.BaseHTTPRequestHandler):
        def do_GET(self):
            query = urllib.parse.urlparse(self.path).query
            params = urllib.parse.parse_qs(query)
            if "code" in params:
                code_holder["code"] = params["code"][0]
                self.send_response(200)
                self.end_headers()
                self.wfile.write(b"<h1>Success! Close this window.</h1>")
            threading.Thread(target=self.server.shutdown).start()
        def log_message(self, *args): pass
    
    server = http.server.HTTPServer(("localhost", 8888), Handler)
    server.handle_request()
    
    if "code" in code_holder:
        result = api_request("POST", "https://www.googleapis.com/oauth2/v4/token", {
            "client_id": client_id,
            "client_secret": client_secret,
            "code": code_holder["code"],
            "grant_type": "authorization_code",
            "redirect_uri": redirect_uri,
        }, {"Content-Type": "application/x-www-form-urlencoded"})
        
        if "access_token" in result:
            save_json(TOKEN_FILE, result)
            print("✓ Setup complete!")
        else:
            print(f"Error: {result}")

def get_thermostats():
    result = sdm_request("/devices")
    return [d for d in result.get("devices", []) if "THERMOSTAT" in d.get("type", "")]

def get_thermostat(name=None):
    for t in get_thermostats():
        room = t.get("parentRelations", [{}])[0].get("displayName", "")
        if name is None or name.lower() in room.lower():
            return t, room
    return None, None

def status(name=None):
    if name:
        t, room = get_thermostat(name)
        if t:
            show_thermostat(t, room)
        else:
            print(f"Thermostat '{name}' not found")
    else:
        for t in get_thermostats():
            room = t.get("parentRelations", [{}])[0].get("displayName", "Unknown")
            show_thermostat(t, room)

def show_thermostat(t, room):
    traits = t.get("traits", {})
    temp_c = traits.get("sdm.devices.traits.Temperature", {}).get("ambientTemperatureCelsius")
    humidity = traits.get("sdm.devices.traits.Humidity", {}).get("ambientHumidityPercent")
    mode = traits.get("sdm.devices.traits.ThermostatMode", {}).get("mode")
    hvac = traits.get("sdm.devices.traits.ThermostatHvac", {}).get("status")
    heat_c = traits.get("sdm.devices.traits.ThermostatTemperatureSetpoint", {}).get("heatCelsius")
    cool_c = traits.get("sdm.devices.traits.ThermostatTemperatureSetpoint", {}).get("coolCelsius")
    
    temp_f = round(temp_c * 9/5 + 32, 1) if temp_c else "?"
    heat_f = round(heat_c * 9/5 + 32, 1) if heat_c else None
    cool_f = round(cool_c * 9/5 + 32, 1) if cool_c else None
    
    setpoint = heat_f or cool_f or "?"
    print(f"{room}: {temp_f}°F (set: {setpoint}°F) | {mode} | {hvac} | {humidity}% humidity")

def set_heat(temp_f, name=None):
    t, room = get_thermostat(name)
    if not t:
        print("Thermostat not found")
        return
    temp_c = (float(temp_f) - 32) * 5/9
    result = sdm_request(f"/{t['name']}:executeCommand", "POST", {
        "command": "sdm.devices.commands.ThermostatTemperatureSetpoint.SetHeat",
        "params": {"heatCelsius": temp_c}
    })
    if "error" not in result:
        print(f"{room}: Heat set to {temp_f}°F")

def set_cool(temp_f, name=None):
    t, room = get_thermostat(name)
    if not t:
        print("Thermostat not found")
        return
    temp_c = (float(temp_f) - 32) * 5/9
    result = sdm_request(f"/{t['name']}:executeCommand", "POST", {
        "command": "sdm.devices.commands.ThermostatTemperatureSetpoint.SetCool",
        "params": {"coolCelsius": temp_c}
    })
    if "error" not in result:
        print(f"{room}: Cool set to {temp_f}°F")

def set_mode(mode, name=None):
    if name:
        thermostats = []
        t, room = get_thermostat(name)
        if t:
            thermostats = [(t, room)]
    else:
        thermostats = [(t, t.get("parentRelations", [{}])[0].get("displayName", "Unknown")) for t in get_thermostats()]
    if not thermostats:
        print("Thermostat not found")
        return
    for t, room in thermostats:
        result = sdm_request(f"/{t['name']}:executeCommand", "POST", {
            "command": "sdm.devices.commands.ThermostatMode.SetMode",
            "params": {"mode": mode.upper()}
        })
        if "error" not in result:
            print(f"{room}: Mode set to {mode.upper()}")

def main():
    args = sys.argv[1:]
    if not args:
        print("Usage: nest.sh setup <project_id> <client_id> <client_secret>")
        print("       nest.sh status [room_name]")
        print("       nest.sh heat <temp_f> [room_name]")
        print("       nest.sh cool <temp_f> [room_name]")
        print("       nest.sh mode <HEAT|COOL|HEATCOOL|OFF> [room_name]")
        sys.exit(1)
    
    cmd = args[0]
    
    if cmd == "setup" and len(args) >= 4:
        setup(args[1], args[2], args[3])
    elif cmd == "status":
        status(args[1] if len(args) > 1 else None)
    elif cmd == "heat" and len(args) >= 2:
        set_heat(args[1], args[2] if len(args) > 2 else None)
    elif cmd == "cool" and len(args) >= 2:
        set_cool(args[1], args[2] if len(args) > 2 else None)
    elif cmd == "mode" and len(args) >= 2:
        set_mode(args[1], args[2] if len(args) > 2 else None)
    else:
        print(f"Unknown command: {cmd}")

if __name__ == "__main__":
    main()
PYTHON_SCRIPT
