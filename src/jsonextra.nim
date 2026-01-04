## Copyright (c) 2025 Ben Tomlin
## Licensed under the MIT license

import std/[json,sequtils,strutils]
proc contains*(n: JsonNode, key: varargs[string]): bool =
  ## Determine if a nested key is present in a json node
  discard foldl(
    key,
    if not a.contains(b):
      return false
    else:
      a[b],
    n,
  )
  return true
  
type Catenatable[T] = concept
  proc `&`(x,y: T): T
    
iterator cartesianProduct[T:Catenatable](a,b: openArray[T], op:proc(x,y:T):T): T=
  ## Compute the cartesian product of two sequences of strings
  for itemA in a:
    for itemB in b:
      yield(op(itemA,itemB))
      
iterator cartesianProduct[T:Catenatable](a,b: openArray[T]): T =
  for x in cartesianProduct(a,b,proc(x,y:T):T = x & y): yield x
    
proc mergeIn*(dest, src: JsonNode): void =
  ## Merge src into dest, overwriting any existing keys in dest
  ## When an object value is found in src, and the corresponding key in dest is 
  ## also an object, the merge is done recursively retaining exclusive keys in 
  ## dest, clobbering common keys with those from src and adding exclusive keys 
  ## from src.
  ## When an array value is found in src, any corresponding key in dest is 
  ## overwritten with the array from src.
  for k,v in src:
    case v.kind
    of JObject:
      if dest.contains(k) and dest[k].kind == JObject:
        mergeIn(dest[k], v)
      else:
        dest[k] = v
    else:
      dest[k] = v

proc parse*(x:string): JsonNode =
  ## Change string to JsonNode interpreting the following format;
  ##  [v1,v2,v3,...]   -> array of values, all of type inferred from first value
  ##  (+|-)\d+         -> integer
  ##  (+|-)?\d+\.\d+   -> float
  ##  (+|-)?(inf|nan)  -> float infinity or NAN
  ##  true|false       -> boolean
  ##  null             -> null
  ##  otherwise        -> string
  ## ^{.*}$            -> json string
  ## 
  ## Numbers may contains underscores for readability which are ignored
  ## Objects must be valid json
  var s=x.strip()
  var sLower = s.toLowerAscii()
  if s.len == 0:  return newJString("")
  if sLower == "null": return newJNull()
  if sLower in ["true", "false"]: return newJBool(sLower == "true")
  # take out sign only strings so not interpreted as int without number
  if sLower in ["+","-"]:  return newJString(s)
    
  if sLower[0] == '[' and sLower[^1] == ']': # Array
    result = newJArray()
    for element in s[1..^2].split(','): result.add(parse(element))
    return result
    
  if sLower in toSeq(cartesianProduct(["+","-",""],["nan","inf"])): # Float special
    return newJFloat(parseFloat(s))
    
  if sLower[0] in {'+','-','0'..'9','.','_'}: # Number possibly
    if sLower[1..^1].allCharsInSet({'0'..'9','_','.','e','+','-'}):
      case sLower.count('.')
      of 0: return newJInt(parseInt(s.replace("_")))
      of 1: return newJFloat(parseFloat(s.replace("_")))
      else: discard # continue and try as object or string
        
  if sLower[0] == '{' and sLower[^1] == '}': # Object (we trimmed whitespace)
    when defined(js): # JS backends std/json does not support raw numbers
      return parseJson(s)
    else:
      # raw*=false will convert to JInt/JFloat instead of JString for numbers
      return parseJson(s,rawIntegers=false, rawFloats=false)
    
  return newJString(s)