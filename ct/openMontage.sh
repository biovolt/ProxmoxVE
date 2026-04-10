#!/usr/bin/env bash
# Copyright (c) 2021-2026 community-scripts ORG
# Author: calesthio
# License: MIT | https://github.com/community-scripts/ProxmoxVE/raw/main/LICENSE
# Source: https://github.com/calesthio/OpenMontage
# shellcheck disable=SC1090
# TODO: Change back to community-scripts/ProxmoxVE before PR submission
source <(curl -fsSL https://raw.githubusercontent.com/biovolt/ProxmoxVE/main/misc/build.func)

APP="OpenMontage"
var_tags="${var_tags:-media;ai}"
var_cpu="${var_cpu:-2}"
var_ram="${var_ram:-2048}"
var_disk="${var_disk:-12}"
var_os="${var_os:-debian}"
var_version="${var_version:-12}"
var_unprivileged="${var_unprivileged:-1}"
var_gpu="${var_gpu:-yes}"

header_info "$APP"
variables
color
catch_errors

function update_script() {
  header_info
  check_container_storage
  check_container_resources

  if [[ ! -f /opt/OpenMontage_version.txt ]]; then
    msg_error "No ${APP} installation found!"
    exit 1
  fi

  RELEASE=$(curl -fsSL https://api.github.com/repos/calesthio/OpenMontage/releases/latest | grep '"tag_name":' | sed -E 's/.*"([^"]+)".*/\1/')

  if [[ -z "${RELEASE}" ]]; then
    msg_error "Could not fetch latest release from GitHub"
    exit 1
  fi

  if [[ "${RELEASE}" != "$(cat /opt/OpenMontage_version.txt)" ]]; then
    msg_info "Updating ${APP} to ${RELEASE}"
    cd /opt/openmontage || { msg_error "Cannot find /opt/openmontage"; exit 1; }
    $STD git pull
    $STD git -C /opt/openmontage checkout "${RELEASE}"
    msg_ok "Pulled ${APP} ${RELEASE}"

    msg_info "Reinstalling Python dependencies"
    $STD uv pip install --python /opt/openmontage/.venv/bin/python -r /opt/openmontage/requirements.txt
    msg_ok "Reinstalled Python dependencies"

    msg_info "Reinstalling Node.js dependencies"
    cd /opt/openmontage/remotion-composer || { msg_error "Cannot find remotion-composer"; exit 1; }
    $STD npm install
    msg_ok "Reinstalled Node.js dependencies"

    { git -C /opt/openmontage describe --tags --exact-match 2>/dev/null || git -C /opt/openmontage rev-parse --short HEAD; } >/opt/OpenMontage_version.txt
    msg_ok "Updated ${APP} to ${RELEASE}"
  else
    msg_ok "No update required. ${APP} is already at ${RELEASE}"
  fi
  exit 0
}

start
build_container
description

# Append usage instructions to the Proxmox container notes
EXISTING_DESC=$(pct config "$CTID" 2>/dev/null | sed -n 's/^description: //p' | sed 's/%0A/\n/g')
pct set "$CTID" -description "${EXISTING_DESC}
<hr/>
<h3>How to Use</h3>
<p>OpenMontage is an <b>agentic video production system</b> — you control it through an AI coding assistant (Claude Code, Cursor, Copilot, etc.) connected to the container.</p>
<h4>Connect</h4>
<p>Claude Code is pre-installed. SSH into the container and start:</p>
<pre>ssh root@LXC_IP
cd /opt/openmontage
claude</pre>
<p>Or use Cursor, Copilot, or Windsurf via remote SSH to <code>/opt/openmontage</code>.</p>
<h4>Create a video</h4>
<p>Tell your assistant what you want:</p>
<pre>\"Make a 60-second animated explainer about how neural networks learn\"</pre>
<p>The agent handles research, scripting, asset generation, editing, and final composition. No web UI or exposed ports needed.</p>
<h3>API Keys (optional)</h3>
<p>Works without keys using Piper TTS + free stock media. For premium providers (~\$0.15-\$1.50/video):</p>
<ol>
<li><code>nano /opt/openmontage/.env</code></li>
<li>Uncomment and fill in: <b>FAL_KEY</b>, <b>ELEVENLABS_API_KEY</b>, <b>OPENAI_API_KEY</b></li>
</ol>
<p><b>Docs:</b> <a href='https://github.com/calesthio/OpenMontage'>github.com/calesthio/OpenMontage</a></p>" 2>/dev/null || true

msg_ok "Completed Successfully!\n"
echo -e "${CREATING}${GN}${APP} setup has been successfully initialized!${CL}"
echo -e "${INFO}${YW} SSH in and run: cd /opt/openmontage && claude${CL}"
echo -e "${INFO}${YW} API keys (optional): nano /opt/openmontage/.env${CL}"
