import std/[os,paths,macros,strformat]
# when not defined(js):
#   import std/[os,paths,macros]
when nimvm:
  import std/[staticos]
  #from system/nimscript import getCurrentDir

type
  CodepathDefect* = object of Defect
  
proc `/`*(a: Path, b: string): Path =
  result = a
  result.add(b.Path)

proc `/`*(a: string, b: Path): Path =
  result = a.Path
  result.add(b)

macro getField*(obj: typed, field: string, T: typedesc): untyped =
  ## Get field of object dynamically, where field value is of type T
  var otype = obj.getTypeImpl()
  otype.expectKind({nnkRefTy, nnkObjectTy})
  if otype.kind() == nnkRefTy:
    otype = otype[0] # get the type sym strip the ref
  let otypeImpl = otype.getTypeImpl()
  let reclist = otypeImpl.findChild(it.kind == nnkRecList)
  if reclist.isNil:
    error("Could not find recList in type definition")
  var ifexpr = nnkIfExpr.newTree()
  let throw = nnkRaiseStmt.newTree(
    nnkCall.newTree(
      nnkDotExpr.newTree(ident"ValueError", ident"newException"),
      newLit"Field not found for given type",
    )
  )
  var targetType = T.getTypeInst[1]
  for identDef in reclist.children():
    if identDef.kind == nnkIdentDefs and targetType.repr == identDef[1].repr:
      ifexpr.add(
        nnkElifExpr.newTree(
          infix(field, "==", newLit($identDef[0])),
          newStmtList(newDotExpr(obj, newIdentNode($identDef[0]))),
        )
      )
  ifexpr.add(nnkElseExpr.newTree(newStmtList(throw)))
  result = ifexpr

when not defined(js):
  proc getCurrentDir*(): string =
    ## Working directory at runtime, project directory at compiletime.
    when nimvm:
      result = gorgeEx("pwd").output
    else:
      result = os.getCurrentDir()
proc getContextDir*(): string =
  when nimvm:
    getProjectPath()
  else:
    when defined(js):
      raise CodepathDefect("JS backend does not support getContextDir or fs access")
    else:
      getCurrentDir()
      
proc extant*(p: Path): bool =
  ## Compiletime or runtime existence of path relative to the context directory
  ##
  ## Context directory is projectpath at compile, working directory at runtime
  if not p.isAbsolute():
    os.fileExists($(getContextDir() / p))
  else:
    os.fileExists($p)

template dualVar*(name: untyped, Type: typedesc) =
  ## A variable that exists at runtime and compiletime, along with a getter and
  ## setter that act on the corresponding variable depending on their runtime
  ## context (either in the nimvm or as an executing binary)
  var name: Type # runtime
  when nimvm:
    var `vm name` {.compiletime.}: Type
  proc `dualGet name`(): Type =
    ## Getter that works in both compiletime and runtime contexts
    when nimvm:
      result = `vm name`
    else:
      result = name

  proc `dualMGet name`(): var Type =
    ## Mutable getter that works in both compiletime and runtime contexts
    ##
    ## Note that reassigning a var will lose the mutability status;
    ## var x = dualMGetMyVar()
    ## x.attr = "newval"
    ## does not modify the original, but dualMGetMyVar().attr = "newVal" does
    when nimvm:
      result = `vm name`
    else:
      result = `name`

  proc `dualSet name`(value: Type) =
    ## Setter working in both compile and runtime contexts
    when nimvm:
      `vm name` = value
    else:
      name = value

  template `dualInit name`(value: untyped): untyped =
    ## Init variable in both rt & ct context
    static:
      `dualSet name` value
    `dualSet name` value
