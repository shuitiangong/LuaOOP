local Lplus = dofile("ch04_inheritance.lua")

local Animal = Lplus.Class("Animal")
local animalDef = Animal.define

animalDef.field().name = "animal"
animalDef.method().speak = function(self)
    return self.name .. " makes a sound"
end
animalDef.static().Kingdom = function()
    return "animalia"
end

local Dog = Lplus.Extend(Animal, "Dog")
local dogDef = Dog.define

dogDef.field().breed = "unknown"
dogDef.method().bark = function(self)
    return self.name .. " barks"
end

local animal = Animal()
local dog = Dog()


assert(animal.name == "animal")
assert(dog.name == "animal")
assert(dog.breed == "unknown")
assert(dog:speak() == "animal makes a sound")
assert(dog:bark() == "animal barks")
assert(Dog.Kingdom() == "animalia")


dog.name = "Lucky"
assert(dog:speak() == "Lucky makes a sound")
assert(animal.name == "animal")
