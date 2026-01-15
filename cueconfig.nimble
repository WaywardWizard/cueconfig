## Copyright (c) 2025 Ben Tomlin
## Licensed under the MIT license

# Package
version       = "2.0.0"
author        = "Ben Tomlin"
description   = "Cue configuration with JSON fallback for Nim projects"
license       = "MIT"
srcDir        = "src"

# Dependencies

requires "nim >= 2.2.6"

proc recListFiles*(dir: string, ext: string="nim"): seq[string] =
  result = @[]
  for f in dir.listFiles:
    if f.endsWith(ext):
      result.add(f)
  for d in listDirs(dir):
    result.add d.recListFiles(ext)

# `BINCFG`_ will be the folder containing the cached binary for the nim test
# when --outdir is not used. Because we want to test the runtime loading of cue
# files in the binaries folder we want control over where that folder is to
# write cue files to it.
task test, "Run tests":
  echo "Running tests..."
  for file in recListFiles("tests", "nim"):
    exec "nim --outdir:tests/bin r " & file

  echo "Running node.js tests..."
  for file in recListFiles("tests", "nim"):
    exec "nim -b:js -d:nodejs --outdir:tests/bin js -r " & file

  echo "Running browser js tests..."
  for file in recListFiles("tests", "nim"):
    exec "nim -b:js --outdir:tests/bin js -r " & file

const DOCFOLDER = "docs"
import std/[strformat,sequtils]
task docgen, "Generate documentation":
  echo "Generating documentation..."
  exec &"rm -rf {DOCFOLDER}/*"
  # --outdir is bugged, only works immediately before doc command...
  var cmd = &"""
    nim \
      --colors:on \
      --path:$projectDir \
      --docInternal \
      --project \
      --index:on \
      --outdir:{DOCFOLDER} \
      doc \
        src/cueconfig.nim
  """
  var result = gorgeEx cmd
  if result.exitCode != 0:
    echo "Documentation generation had some errors;"
    # lines with "Error" in them
    echo ""
    echo result.output.splitLines().filterIt(it.contains "Error").join("\n")
    quit(result.exitCode)

task build, "Build the library":
  echo "Building library..."
  exec "nim c src/cueconfig.nim"