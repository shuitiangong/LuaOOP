local Lplus = dofile("ch01_minimal_class.lua")

local Person = Lplus.Class("Person")
local def = Person.define

def.field().name = "anonymous"
def.field().age = 0

local p1 = Person()
local p2 = Person()

assert(p1.name == "anonymous")
assert(p1.age == 0)
assert(p2.name == "anonymous")
assert(p2.age == 0)

p1.name = "Alice"
p1.age = 18

assert(p1.name == "Alice")
assert(p1.age == 18)
assert(p2.name == "anonymous")
assert(p2.age == 0)

p1.nickName = "tester"
assert(p1.nickname == "tester")
