# =======
# Imports
# =======

import os
import osproc
import tables
import sequtils
import strutils
import parsecfg
import parseopt2
import asyncdispatch

var status = newSeq[string]()
GC_ref(status)

proc execCallback(index: int, process: Process): void {.gcsafe.} = 
  let output_handle = process.outputHandle()
  var output_file: File
  discard open(output_file, output_handle, fmRead)
  let output = output_file.readAll().string
  var lines = output.split("\n")
  lines.keepIf(proc(x: string): bool = len(x) > 0)
  if len(lines) == 0:
    status[index] = ""

# ===========
# Entry Point
# ===========

let base_path =
  if not existsEnv("XDG_CONFIG_HOME"):
    getEnv("XDG_CONFIG_HOME")
  else:
    expandTilde("~/.config")
let coven_config_path = base_path.joinPath("coven/coven.ini")

if not existsFile(coven_config_path):
  echo("Unable to load settings file at path: " & coven_config_path)
  quit(QuitFailure)

var commands = newSeq[string]()

let commands_file = loadConfig(coven_config_path)
for key, value in commands_file["display"].pairs():
  status.add(key)
  commands.add(value)

for kind, key, value in getopt():
  case kind
  of cmdLongOption, cmdShortOption:
    case key:
    of "help", "h":
      echo()
    of "--version", "-v":
      echo("coven v0.1")
    else:
      discard
  else:
    discard
  quit(QuitSuccess)

discard execProcesses(commands, {}, countProcessors(), nil, execCallback)

status.keepIf(proc(x: string): bool = len(x) > 0)
echo(status.join(" "))

GC_unref(status)
