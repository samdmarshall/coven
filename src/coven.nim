# =======
# Imports
# =======

import os
import osproc
import tables
import unicode
import sequtils
import strutils
import parsecfg
import parseopt
import strformat
import algorithm
import asyncdispatch

import unicodedb
import unicodedb/widths

var status = newSeq[string]()
GC_ref(status)

proc execCallback(index: int, process: Process): void {.gcsafe.} = 
  let output_handle = process.outputHandle()
  var output_file: File
  discard open(output_file, output_handle, fmRead)
  let output = output_file.readAll().string
  var lines = output.split("\n")
  lines.keepIf(proc(x: string): bool = len(x) > 0 and x != "0")
  if len(lines) == 0:
    status[index] = ""

# ===========
# Entry Point
# ===========

let coven_config_path = getConfigDir() / "coven" / "coven.ini"

if not existsFile(coven_config_path):
  echo("Unable to load settings file at path: " & coven_config_path)
  quit(QuitFailure)

var commands = newSeq[string]()

let commands_file = loadConfig(coven_config_path)
for key, value in commands_file["display"].pairs():
  status.add(key)
  commands.add(value)

var p = initOptParser()
for kind, key, value in p.getopt():
  case kind
  of cmdLongOption, cmdShortOption:
    case key:
    of "help", "h":
      echo("coven [-v|--version] [-h|--help] [dump]")
    of "version", "v":
      echo("coven v0.2.0")
    else:
      discard
  of cmdArgument:
    case key
    of "dump":
      echo("Using configuration file: " & coven_config_path)
      for section in commands_file.keys():
        echo "\n" & fmt"[{section}]"
        var kvpairs: seq[tuple[key: string, value: string]] = toSeq(commands_file[section].pairs())
        var lengths = newSeq[int]()
        for item in kvpairs:
          var length = 0
          for rune in item.key.toRunes:
            case unicodeWidth(rune)
            of uwdtWide, uwdtFull, uwdtAmbiguous: length.inc(2)
            else: length.inc(1)
          lengths.add(length)
        var entries: seq[tuple[a: tuple[key: string, value: string], b: int]] = kvpairs.zip(lengths)
        var longest = lengths.sorted(system.cmp[int], SortOrder.Descending)[0]
        for item in entries:
          let key_string = 
            if item.b == longest: fmt"'{item.a.key}'"
            else: unicode.align((fmt"'{item.a.key}'"), longest + 2)
          let value_string = fmt"`{item.a.value}`"
          echo fmt"{key_string} = {value_string}"
    else:
      discard
  else:
    discard
  quit(QuitSuccess)

discard execProcesses(commands, {}, countProcessors(), nil, execCallback)

status.keepIf(proc(x: string): bool = len(x) > 0)
echo(status.join(" "))

GC_unref(status)
