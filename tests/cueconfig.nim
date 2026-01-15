## Copyright (c) 2025 Ben Tomlin
## Licensed under the MIT license
## Test data `tests/config.cue`_
import std/[unittest, json, paths, strutils, envVars,macros,times,os]
when not defined(js):
  import std/[files,osproc,dirs]

import ../src/cueconfig
import ../src/cueconfig/[util,jsonextra]

const ENV = """
nim_env_test=testing123
Nim_common_z=3
NIM_COMMON_Z=100
OBJ_COMMON_Z=100
NIM_common_w=0
NIm_COMMON_Z=110
"""

const ppath = getProjectPath().Path

template setupBody() =
  registerEnvPrefix("NIM_")
  registerConfigFileSelector(ppath/"config.cue")
  
  
# NodeJS (compile with -d:nodejs) or C backend
proc injectEnv(env: string) =
  for line in env.splitLines():
    let parts = line.split('=')
    if parts.len == 2:
      putEnv(parts[0].strip, parts[1])

suite "Env registrations":
  setup:
    injectEnv(ENV)
    registerEnvPrefix("NIM_",caseInsensitive=false)
  teardown:
    clearConfig()
  test "Case sensitive prefix":
    check getConfig[int]("COMMON.Z") == 100
    check getConfig[int]("common.w") == 0
  test "Case insensitive prefix":
    registerEnvPrefix("NiM_",caseInsensitive=true)
    loadRegisteredConfig()
    check getConfig[int]("common.z") == 3
    check getConfig[string]("env.test") == "testing123"
  test "JSON key sensitivity":
    expect(ValueError): discard getConfig[int]("cOMMON.Z") 
  test "Precedence (later registrations precedent)":
    registerEnvPrefix("NiM_",caseInsensitive=true)
    check getConfig[int]("COMMON.Z") == 110
    registerEnvPrefix("OBJ_")
    loadRegisteredConfig()
    check getConfig[int]("COMMON.Z") == 100

suite "File registrations":
  teardown:
    clearConfig()
    setCurrentDir(ppath)
  suite "Relative paths":
    setup:
      setCurrentDir(ppath / "assets")
    test "Relative fskPath":
      registerConfigFileSelector("fallback.json")
      loadRegisteredConfig()
      check getConfig[string]("fileExtUsed") == "json"
      
      var c1,c2:int
      c1 = checksumConfig()
      registerConfigFileSelector("subdir.json") # no subdir.json in assets
      loadRegisteredConfig()
      check c1==checksumConfig() # no change as no subdir.json exists
      
      setCurrentDir(ppath / "assets/subdir")
      registerConfigFileSelector("subdir.json")
      loadRegisteredConfig()
      check getConfig[string]("subdirjson") == "here"
      
    test "Relative fskRegex":
      # going to recurse and find
      registerConfigFileSelector(("", r"subdir\.json$"))
      loadRegisteredConfig()
      echo "SHOW"
      echo showConfig()
      check getConfig[string]("subdirjson") == "here"
      setCurrentDir(ppath / "../src")
      
      loadRegisteredConfig()
      expect(ValueError): # reload now will not find anything
        check getConfig[string]("subdirjson") == "here"
        
  suite "Interpolation":
    test "fskPath {getCurrentDir()}":
      setCurrentDir(ppath / "assets/subdir")
      registerConfigFileSelector("{getCurrentDir()}/subdir.json")
      loadRegisteredConfig()
      check getConfig[string]("subdirjson") == "here"
      setCurrentDir(ppath / "assets")
      
      expect(ValueError):
        # now the interpolated path won't be correck
        loadRegisteredConfig()
        check getConfig[string]("subdirjson") == "here"
        
    test "fskPath {ENV}":
      putEnv("STUB","subdir")
      setCurrentDir(ppath/"assets/subdir")
      registerConfigFileSelector("{STUB}.json")
      loadRegisteredConfig()
      check getConfig[string]("subdirjson") == "here"
      
    test "fskRegex {getCurrentDir()}":
      setCurrentDir(ppath/"assets/subdir")
      registerConfigFileSelector(("{getCurrentDir()}",r"subdir.json$"))
      loadRegisteredConfig()
      check getConfig[string]("subdirjson") == "here"
      
      setCurrentDir(ppath/"assets")
      loadRegisteredConfig() # still finds it as we recurse
      check getConfig[string]("subdirjson") == "here"
    
      setCurrentDir(ppath/"../src")
      expect(ValueError):
        # now the interpolated path won't be correct
        loadRegisteredConfig()
        check getConfig[string]("subdirjson") == "here"
      
    test "fskRegex {ENV}":
      putEnv("S1","assets")
      putEnv("S2","subdir")
      setCurrentDir(ppath)
      registerConfigFileSelector(("{S1}/{S2}",r"subdir.json$"))
      loadRegisteredConfig()
      check getConfig[string]("subdirjson") == "here"
      
      putEnv("S1","../src")
      loadRegisteredConfig()
      expect(ValueError):
        # now the interpolated path won't be correct
        check getConfig[string]("subdirjson") == "here"
      
      
  suite "Fallback and precedence":
    setup:
      let fsnofallback = initFileSelector(Path(getProjectPath()) / "assets/fallback.cue" , useJsonFallback=false)
      let fsjson = initFileSelector(Path(getProjectPath()) / "assets/fallback.json", useJsonFallback=false)
      let fsfallback = initFileSelector(Path(getProjectPath()) / "assets/fallback.cue", useJsonFallback=true)
      
      let rxNoFallback = initFileSelector(ppath,r"assets/fall\w+\.cue$", useJsonFallback=false)
      let rxFallback = initFileSelector(ppath,r"assets/fall\w+\.cue$", useJsonFallback=true)
      
      let rxRecurse = initFileSelector(ppath / "assets",r"regexmatch\.cue$", useJsonFallback=false)
      
    test "Path no fallback":
      registerConfigFileSelector(fsnofallback)
      loadRegisteredConfig()
      check getConfig[string]("fileExtUsed") == "cue"
    test "Cue precedent":
      registerConfigFileSelector(fsnofallback) # fallback.cue
      registerConfigFileSelector(fsjson) # fallback.json
      loadRegisteredConfig()
      check getConfig[string]("fileExtUsed") == "cue"
    test "Path with fallback":
      putEnv("PATH","")
      registerConfigFileSelector(fsfallback)
      loadRegisteredConfig()
      check getConfig[string]("fileExtUsed") == "json"
      #moveFile("assets/fallback.cue.bak","assets/fallback.cue")
      
    test "Regex no fallback":
      registerConfigFileSelector(rxNoFallback)
      putEnv("PATH","")
      expect(ValueError): # cue found, load fails
        loadRegisteredConfig()
    test "Regex with fallback":
      registerConfigFileSelector(rxFallback)
      putEnv("PATH","")
      loadRegisteredConfig() # cue found, load fails, fallback succeeds
      check getConfig[string]("fileExtUsed") == "json"
    test "Regex, match recurse to subpaths":
      registerConfigFileSelector(rxRecurse)
      loadRegisteredConfig()
      check getConfig[string]("regexmatch.onlyroot") == "here"
      check getConfig[string]("regexmatch.subdir") == "here"
    test "Clear config":
      registerConfigFileSelector(rxRecurse)
      loadRegisteredConfig()
      check getConfig[string]("regexmatch.common") == "subdir"
      clearConfig()
      expect(ValueError): discard getConfig[string]("regexmatch.common")
    test "Subdir precedent":
      registerConfigFileSelector(rxRecurse)
      loadRegisteredConfig()
      check getConfig[string]("regexmatch.common") == "subdir"
      clearConfig()
    test "Subdir precedent order independant":
      # order independence
      setCurrentDir(ppath)
      registerConfigFileSelector(["assets/regexmatch.cue", "assets/subdir/regexmatch.cue"])
      check getConfig[string]("regexmatch.common") == "subdir"
      clearConfig()
      registerConfigFileSelector(["assets/subdir/regexmatch.cue","assets/regexmatch.cue"])
      check getConfig[string]("regexmatch.common") == "subdir"
    template setupTimePrecedentFiles(t1,t2:Time) = 
      writeFile("assets/subdir/mtime1.cue", "mtime:value: \"mtime1\"")
      setLastModificationTime("assets/subdir/mtime1.cue",t1)
      writeFile("assets/subdir/mtime2.cue", "mtime:value: \"mtime2\"")
      setLastModificationTime("assets/subdir/mtime2.cue",t2)
    test "Newest precedent":
      registerConfigFileSelector(("assets/subdir",r"mtime.*\.cue$"))
      var tnow = getTime()
      var tolder = tnow - initDuration(seconds=10)
      setupTimePrecedentFiles(tnow,tolder)
      loadRegisteredConfig()
      check getConfig[string]("mtime.value") == "mtime1"
    test "Lexicographical precedent":
      registerConfigFileSelector(("assets/subdir",r"mtime.*\.cue$"))
      var tnow = getTime()
      setupTimePrecedentFiles(tnow,tnow)
      loadRegisteredConfig()
      check getConfig[string]("mtime.value") == "mtime1"
    test "Cue precedent": # two different files in same dir with conflicting keys
      setCurrentDir(ppath/"assets")
      registerConfigFileSelector(["conflictA.cue","conflictB.json"])
      loadRegisteredConfig()
      check getConfig[string]("conflict") == "A"
    test "Shadow, not clobber":
      registerConfigFileSelector(["conflictB.json","conflictA.cue"])
      loadRegisteredConfig()
      check getConfig[string]("onlyInA") == "A"
      check getConfig[string]("other") == "here"
  
  ## file registration
  ## register cue
  ## register json
  ## register cue fallback json
  ## register sops
  ## sops precedence
  ## cue precedent over json
  ## 
  # suite "File registrations":
  #   setup:
  #     const testDir = getProjectPath() / "tests" / "test_configs"
  #     registerConfigFileSelector(testDir / "config1.cue")
  #     registerConfigFileSelector(testDir / "config2.cue")
  #     loadRegisteredConfig()
  #     echo showConfig()
  #   test "File registration precedence":
  #     check getConfig[string]("file.testString") == "from config2"
  #     check getConfig[int]("file.testNumber") == 200
    

  ## file registration
  ## register cue
  ## register json
  ## register cue fallback json
  ## register sops
  ## sops precedence
  ## cue precedent over json
  ## 
  # suite "File registrations":
  #   setup:
  #     const testDir = getProjectPath() / "tests" / "test_configs"
  #     registerConfigFileSelector(testDir / "config1.cue")
  #     registerConfigFileSelector(testDir / "config2.cue")
  #     loadRegisteredConfig()
  #     echo showConfig()
  #   test "File registration precedence":
  #     check getConfig[string]("file.testString") == "from config2"
  #     check getConfig[int]("file.testNumber") == 200
    
    
# suite "Read static configuration (at compiletime)":
#   test "Compiletime get":
#     # will raise exception if fails
#     # const evaluated at conpiletime, so we are testing compile time access
#     try:
#       const cfgNode = getConfig[string]("compiled.testString")
#     except:
#       fail()
  
# suite "Read static configuration (at runtime)":
#   test "Read compiled":
#     check getConfigNode("compiled").kind == JObject
#   test "Read string":
#     check getConfig[string]("app.string") == "foo"
#   test "Read numbers":
#     check getConfig[int]("app.number") == 42
#     check getConfig[float]("app.n0") == -2.23
#     check getConfig[int]("app.n1") == 4200
#     check getConfig[float]("app.n2") == 2.32423e7
#     check getConfig[float]("app.n3") == 2.32423e-7
#     check getConfig[float]("app.n4") == -2.32423e-7
#     check getConfig[float]("app.n5") == 2.32423e7
#     check getConfig[float]("app.n6") == 2.32423e-7
#     check getConfig[float]("app.n7") == -0.3242e33
#     check getConfig[float]("app.n8") == 0.23
#     check getConfig[float]("app.n9") == -0.23
#     check getConfig[float]("app.fnumber") == 3.14
#   test "Read boolean":
#     check getConfig[bool]("app.nested.flag") == true
#     check getConfig[bool](["app", "nested", "flag"])
#     check getConfig[bool](@["app", "nested", "flag"])
#   test "Read object":
#     check getConfigNode("app.nested").kind == JObject
# suite "API":
#   test "Dot notation key":
#     check getConfig[bool]("app.nested.flag") == true
#   test "Array of strings key":
#     check getConfig[bool](["app","nested","flag"]) == true
#   test "Seq key":
#     check getConfig[bool](@["app","nested","flag"]) == true
#   test "Varargs key":
#     check getConfig[bool]("app","nested","flag") == true
  
# when not defined(js): # filesystem access required
#   const binCfg = Path("tests/bin/config.cue") # see --outdir flag in nimble file
#   const pwdCfg = Path("config.cue")
#   const binCfgBk = binCfg.changeFileExt("cue.bak")
#   const pwdCfgBk = pwdCfg.changeFileExt("cue.bak")
#   suite "Read runtime configuration":
#     # Compiled in config as per `tests/config.cue`_
#     # Overwrite `tests/config.cue`_, the working directory `config.cue`_
#     setup:
#       let binCfgCue =
#         """
#       bin: {
#         nested: {
#           flag: false
#         }
#         string: "Runtime Config"
#         number: 100
#         fnumber: 6.28
#       }
#       common: x: 1
#       common: y: 1
#       common: z: 1
#       """
#       let pwdCfgCue =
#         """
#       pwd: {
#         nested: {
#           flag: true
#         }
#         string: "Overwritten Runtime Config"
#         number: 200
#         fnumber: 9.42
#       }
#       common: y: 2
#       common: z: 2
#       """
#       # Note case sensitivity of env vars
#       let env =
#         """
#       nim_env_test=testing123
#       Nim_common_z=3
#       NIM_COMMON_Z=100
#       """
#       if fileExists(binCfg): moveFile(binCfg, binCfgBk)
#       if fileExists(pwdCfg): moveFile(pwdCfg, binCfgBk)
#       writeFile($binCfg, binCfgCue)
#       writeFile($pwdCfg, pwdCfgCue)
#       injectEnv(env)
#       reload()
#       #echo showConfig()
      
#     teardown:
#       removeFile(binCfg)
#       removeFile(pwdCfg)
#       if fileExists(binCfgBk): moveFile(binCfgBk, binCfg)
#       if fileExists(pwdCfgBk): moveFile(pwdCfgBk, pwdCfg)

#     test "Read binary folder configuration":
#       check getConfigNode("bin").kind == JObject
#     test "Read pwd configuration":
#       check getConfigNode("pwd").kind == JObject
#     test "Read env configuration":
#       check getConfigNode("env").kind == JObject
#     test "Precedence, reloading":
#       check getConfig[int]("common.w") == 0 # from compile time
#       check getConfig[int]("common.x") == 1 # from bindir
#       check getConfig[int]("common.y") == 2 # from pwd
#       check getConfig[int]("common.z") == 3 # from env
  
#   suite "JSON Fallback":
#     setup:
#       const binCue = """
#       fallback: {
#         fnumber: 6.28
#         string: "Runtime Config"
#       }
#       """
#       const cfgJson = binCfg.changeFileExt("json")
      
#       if fileExists(binCfg): moveFile(binCfg, binCfgBk)
        
#       var (json,mexit) = execCmdEx("echo '$#' | cue export -" % [binCue])
#       if mexit != 0: raise newException(IOError, "Could not run cue\n" & json)
#       writeFile($cfgJson, json)
#       reload()
      
#     teardown:
#       removeFile(cfgJson)
#       if fileExists(binCfgBk): moveFile(binCfgBk, binCfg)
        
#     test "Load cue file fallback to json":
#       check getConfig[float]("fallback.fnumber") == 6.28
#       check getConfig[string]("fallback.string") == "Runtime Config"
      
# when defined(js):
#   const testEnv = isNode()
# else:
#   const testEnv = true
# when testEnv:
#   suite "Env parsing":
#     setup:
#       const env = """
#       nim_env_sTr=stringValue
#       nim_env_inT=12345
#       nim_env_fLoat=3.14159
#       nim_env_array0=[one,two,three]
#       nim_env_array1=[1,2,3]
#       nim_env_array2=[1.1,1]
#       nim_env_array3=[1,1.1]
#       nim_env_obj={"old": 1,"key1":"value1","key2":2,"key3":3.0, "key4":true, "key5":null, "key6":[1,2,3],"key7":{"subkey":"subvalue"}}
#       nim_={"env": {"obj": {"old": 0}}, "topLevelKey": "topLevelValue"}
#       """
#       injectEnv(env)
#       reload()
#     test "Case sensitivity":
#       check getConfig[string]("env.sTr") == "stringValue"
#       check getConfig[int]("env.inT") == 12345
#       expect ValueError: discard getConfig[string]("env.str")
#     test "Arrays":
#       check getConfig[seq[string]]("env.array0") == @["one","two","three"]
#       check getConfig[seq[int]]("env.array1") == @[1,2,3]
#       check getConfig[seq[float]]("env.array2") == @[1.1,1.0]
#       # This will fail as mixed types not supported in nim, the JsonNode does
#       # check getConfig[seq[int]]("env.array3") == @[1,1]
#     test "Object":
#       let objNode = getConfigNode("env.obj")
#       check objNode["key1"].getStr() == "value1"
#       check objNode["key2"].getInt() == 2
#       check objNode["key3"].getFloat() == 3.0
#       check objNode["key4"].getBool() == true
#       check objNode["key5"].kind == JNull
#       check objNode["key6"].kind == JArray
#       check objNode["key7"].kind == JObject
#       check objNode["key7"]["subkey"].getStr() == "subvalue"
#     suite "Top level object env":
#       test "Object collision common key clobber":
#         check getConfig[int]("env.obj.old") == 0
#       test "Object collision old keys retained":
#         check getConfig[int]("env.obj.key2") == 2
#       test "Top level key":
#         check getConfig[string]("topLevelKey") == "topLevelValue"
      