local Lplus = dofile("ch03_methods_static.lua")
local Person = Lplus.Class("Person")
local def = Person.define

def.field().name = "anoymous"

def.method().getName = function(self)
    return self.name
end

def.static().Version = function()
    return "0.4"
end

local p = Person()

assert(p:getName() == "anoymous")
assert(Person.Version == "0.4")
assert(rawget(p, "getName") == nil)
assert(p.getName(p) == "anoymous")
