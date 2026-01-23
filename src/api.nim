## Copyright (c) 2025 Ben Tomlin
## Licensed under the MIT license
##
## API for end users
##
## Internal API with more descriptive names in `cueconfig/cueconfig module`_
##
## # API
## This is the basic API which should serve 98% of use cases. Import `cueconfig/cueconfig module`_ for a more detailed api.
##
## | Call | CT/RT | Usage |
## | ---  | ---   |
## | register | 1/1 | Select (sops, cue, json) files for use in config, or environment variable prefixes for selecting sets of environment variables to contributo to the config |
## | deregister | 1/1 | Remove selected files or env prefixes |
## | commit | 0/1 | Commit all current (static) registrations to binary. |
## | config | 1/1 | Lookup config key |
## | reload | 1/1 | Reload config after external changes such as environment variables or working directory |
## | inpect | 1/1 | Get a string representation of the config, registrations and other state |
##
## # Context
## ## CT/RT contexts
## Access of config at compiletime as well as runtime is supported. The procs behave the same in both contexts. However, only the config (statically) registered before a commit() call will be persist into runtime.
##
## ## External context
## Env vars, the pwd() and the availibility of selected files all change the resulting config. reload() should be called if the env or pwd() changes to have the config reflect these. Otherwise, *new* registrations are included automatically on the next config access.
##
## # CUE, SOPS Integration
## For SOPS you need your sops access key in the SOPS_AGE_KEY_FILE environment variable and the sops binary in PATH. For cue you need the cue binary in PATH. You dont need either of these things if you dont want to use CUE or SOPS support.
##
## # PEGS
## PEGs not regexes are used to match patterns. Basic regexes will work as a peg also.
import std/[paths, pegs]
import cueconfig/cueconfig

template registerFile*(path: string, fallback: bool = true) =
  registerConfigFileSelector(path, fallback)

template deregisterFile*(path: string) =
  deregisterConfigFileSelector(path)

template registerFile*(searchdir: string, peg: string, fallback: bool = true) =
  registerConfigFileSelector((searchdir, peg, fallback))

template deregisterFile*(searchpath: string, peg: string) =
  deregisterConfigFileSelector(searchpath, peg)

template registerEnv*(prefix: string, caseSensitive: bool = false) =
  registerEnvPrefix(prefix, caseInsensitive = not caseSensitive)

template deregisterEnv*(prefix: string) =
  deregisterEnvPrefix(prefix)
  
template clear*() =
  clearConfigAndRegistrations()

template reload*() =
  ## All calls will automatically update your config after a (de)registration.
  ## However, if you change the contex directory, or an env var, you cen signal
  ## this by calling this
  reload()

template commit*() =
  ## Commit all parsed (earlier) registrations made in a static context to binary
  commitCompiletimeConfig()

template inspect*(): string =
  ## Dump config with useful diagnostic information such as ct/rt registrations
  showConfig()

template config*[T](keypath: string):T = getConfig[T](keypath)
template config*[T](keypath: varargs[string]):T = getConfig[T](keypath)