#!/usr/bin/env bash

set -euo pipefail

debug_log() {
    if [[ "${AI_NOTIFY_DEBUG:-0}" == "1" ]]; then
        printf '[ai-notify] %s\n' "$*" >&2
    fi
}

command -v powershell.exe > /dev/null 2>&1 || {
    debug_log "wsl2 backend skipped: powershell.exe not found"
    exit 0
}

export AI_NOTIFY_TITLE="${AI_NOTIFY_TITLE:-Task finished}"
export AI_NOTIFY_BODY="${AI_NOTIFY_BODY:-A background task completed.}"
export AI_NOTIFY_WINDOWS_SUPPRESS_PROCESS="${AI_NOTIFY_WINDOWS_SUPPRESS_PROCESS:-alacritty}"

debug_log "notifier=wsl2-toast"
powershell.exe -NoProfile -NonInteractive -ExecutionPolicy Bypass -Command '
try {
  Add-Type -TypeDefinition @"
using System;
using System.Runtime.InteropServices;
public static class Win32Focus {
  [DllImport("user32.dll")]
  public static extern IntPtr GetForegroundWindow();

  [DllImport("user32.dll")]
  public static extern uint GetWindowThreadProcessId(IntPtr hWnd, out uint processId);
}
"@ -ErrorAction Stop | Out-Null

  $foreground = [Win32Focus]::GetForegroundWindow()
  if ($foreground -ne [IntPtr]::Zero) {
    $pid = 0
    [void][Win32Focus]::GetWindowThreadProcessId($foreground, [ref]$pid)
    if ($pid -gt 0) {
      $name = (Get-Process -Id $pid -ErrorAction SilentlyContinue | Select-Object -ExpandProperty ProcessName -ErrorAction SilentlyContinue)
      if ($name -and $name.ToLowerInvariant() -eq $env:AI_NOTIFY_WINDOWS_SUPPRESS_PROCESS.ToLowerInvariant()) {
        exit 0
      }
    }
  }

  Add-Type -AssemblyName System.Runtime.WindowsRuntime | Out-Null
  [Windows.UI.Notifications.ToastNotificationManager, Windows.UI.Notifications, ContentType = WindowsRuntime] | Out-Null
  [Windows.Data.Xml.Dom.XmlDocument, Windows.Data.Xml.Dom.XmlDocument, ContentType = WindowsRuntime] | Out-Null

  $title = [Security.SecurityElement]::Escape($env:AI_NOTIFY_TITLE)
  $body = [Security.SecurityElement]::Escape($env:AI_NOTIFY_BODY)
  $xml = New-Object Windows.Data.Xml.Dom.XmlDocument
  $xml.LoadXml("<toast><visual><binding template=""ToastGeneric""><text>$title</text><text>$body</text></binding></visual></toast>")
  $toast = [Windows.UI.Notifications.ToastNotification]::new($xml)
  [Windows.UI.Notifications.ToastNotificationManager]::CreateToastNotifier("GNU AI Tools").Show($toast)
} catch {
  exit 0
}
' > /dev/null 2>&1 &
