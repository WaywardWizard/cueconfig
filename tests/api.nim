## Copyright (c) 2025 Ben Tomlin
## Licensed under the MIT license
## Test simple API wrapper functions
import std/[unittest, paths, envVars, macros,strutils]
when not defined(js):
  import std/[os]
import ../src/api

const ppath = getProjectPath().Path
const adir = $ppath & "/assets"
const sdir = $ppath & "/../src"

suite "Simple API - File registration":
  setup:
    clear()
    setCurrentDir adir

  test "Register and access config file":
    registerFile("fallback.json")
    check config[string]("fileExtUsed") == "json"

  test "Deregister config file":
    registerFile("fallback.json")
    deregisterFile("fallback.json")
    expect(ValueError):
      discard config[string]("fileExtUsed")

suite "Simple API - Environment registration":
  setup:
    clear()
    putEnv("NIM_test", "value123")

  test "Register and access env prefix":
    registerEnv("NIM_", caseSensitive = true)
    check config[string]("test") == "value123"

  test "Deregister env prefix":
    registerEnv("NIM_", caseSensitive = true)
    deregisterEnv("NIM_")
    expect(ValueError):
      discard config[string]("test")

suite "Simple API - Config access":
  setup:
    clear()
    setCurrentDir adir
    registerFile("config.cue")

  test "Config with dot notation":
    check config[string]("app.string") == "foo"
    check config[int]("app.number") == 42

  test "Config with varargs":
    check config[string]("app", "string") == "foo"
    check config[int]("app", "number") == 42

  test "Config with array":
    check config[string](["app", "string"]) == "foo"
    check config[int](["app", "number"]) == 42

suite "Simple API - Inspect and reload":
  setup:
    clear()
    setCurrentDir adir

  test "Inspect returns registration info":
    registerFile("fallback.json")
    let info = inspect()
    check info.len > 0
    check info.contains("fallback.json")

  test "Reload updates config":
    registerFile("fallback.json")
    check config[string]("fileExtUsed") == "json"
    setCurrentDir sdir
    reload()
    expect(ValueError):
      check config[string]("fileExtUsed") == "json"
