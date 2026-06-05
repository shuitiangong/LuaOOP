local Lplus = dofile("ch01_minimal_class.lua")

local Person = Lplus.Class("Person")
local p1 = Person()
local p2 = Person()

assert(type(Person) == "table")
assert(type(p1) == "table")
assert(type(p2) == "table")
assert(p1 ~= p2)
assert(getmetatable(p1).typeTable == Person)
assert(getmetatable(p2).typeTable == Person)
