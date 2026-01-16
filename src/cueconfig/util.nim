import std/[paths, macros, os]
when nimvm:
  import std/[staticos]
  import system/nimscript
  

proc `/`*(a: Path, b: string): Path =
  result = a
  result.add(b.Path)

proc `/`*(a: string, b: Path): Path =
  result = a.Path
  result.add(b)

proc extant*(p: Path): bool =
  os.fileExists($p)

macro getField*(obj: typed, field: string, T: typedesc): untyped =
  ## Get field of object dynamically, where field value is of type T
  obj.expectKind({nnkSym, nnkRefTy, nnkObjectTy})
  let reclist = obj.getTypeImpl().findChild(it.kind == nnkRecList)
  var ifexpr = nnkIfExpr.newTree()
  let throw = nnkRaiseStmt.newTree(
    nnkCall.newTree(
      nnkDotExpr.newTree(ident"ValueError", ident"newException"),
      newLit"Field not found for given type",
    )
  )
  var targetType = T.getTypeInst[1]
  for identDef in reclist.children():
    if sameType(targetType, identDef[1]):
      ifexpr.add(
        nnkElifExpr.newTree(
          infix(field, "==", newLit($identDef[0])),
          newStmtList(newDotExpr(obj, identDef[0])),
        )
      )
  ifexpr.add(nnkElseExpr.newTree(newStmtList(throw)))
  result = ifexpr

proc getCurrentDir*(): string =
  ## Get current working directory as Path, supporting both compile-time and run-time
  when nimvm:
    result = nimscript.getCurrentDir()
  else:
    result = os.getCurrentDir()