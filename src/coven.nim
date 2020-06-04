
# =======
# Imports
# =======

# Standard Library Imports
import os
import osproc
import tables
import parsecfg
import sequtils
import strutils
import strformat

# Third Party Package Imports
import commandeer
# import unicodedb
# import unicodedb/widths

# =====
# Types
# =====

type
  CommandOutput = object
    idx: int
    output: string
  ParallelCommand = object
    idx: int
    command: string
    status: string
    completed: bool

# =========
# Constants
# =========

const
  NimblePkgName {.strdefine.} = ""
  NimblePkgVersion {.strdefine.} = ""
  DefaultConfigFilePath = getConfigDir() / NimblePkgName / fmt"{NimblePkgName}.ini"

# =========
# Functions
# =========

proc findIndex[T](s: seq[T], match: T): int =
  result = 0
  var found = false
  for item in s:
    found = (match == item)
    if found:
      break
    inc(result)
  if not found:
    result = -1

# ===========
# Entry Point
# ===========

when isMainModule:
  commandline:
    option setConfigurationPath, string, "config", "c", DefaultConfigFilePath
    subcommand Command_Dump, "dump":
      discard
    exitoption "help", "h", fmt"{NimblePkgName} [-h|--help] [-v|--version] [-c|--config <path>] [dump]"
    exitoption "version", "v", fmt"{NimblePkgName} v{NimblePkgVersion}"

  if not existsFile(setConfigurationPath):
    echo fmt"No configuration file at path: {setConfigurationPath}"
    quit(QuitFailure)

  let configuration = loadConfig(setConfigurationPath)

  if Command_Dump:
    echo fmt"# Using Configuration File: {setConfigurationPath}" & "\n"
    for section in configuration.keys():
      echo fmt"[{section}]"
      for key, value in configuration[section].pairs():
        echo fmt"  '{key}' = '{value}'"
  else:
    let config_commands = toSeq(configuration["display"].pairs())
    var commands = config_commands.mapIt(ParallelCommand(idx: findIndex(config_commands, it), command: it[1], status: it[0], completed: false))

    var channel: Channel[CommandOutput]
    channel.open()

    proc execParallelCommand(arg: ParallelCommand) =
      let output_raw = execProcess(arg.command)
      let msg = CommandOutput(idx: arg.idx, output: output_raw)
      channel.send(msg)

    for command in commands:
      var worker: Thread[ParallelCommand]
      createThread(worker, execParallelCommand, command)
      worker.joinThread()

    while commands.anyIt(it.completed == false):
      let tried = channel.tryRecv()
      if tried.dataAvailable:
        let response = tried.msg
        var lines = response.output.strip(chars = Whitespace + Newlines)
        if not (len(lines) > 0 and lines != "0"):
          commands[response.idx].status = ""
        commands[response.idx].completed = true
      sleep(50)

    commands.keepItIf(len(it.status) > 0)
    echo commands.mapIt(it.status).join(" ")

  # var commands = newSeq[string]()

  # let commands_file = loadConfig(coven_config_path)
  # for key, value in commands_file["display"].pairs():
  #   status.add(key)
  #   commands.add(value)

#[
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
              of uwdtWide, uwdtFull, uwdtAmbiguous:
                length.inc(2)
              else:
                length.inc(1)
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
]#

