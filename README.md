# Echoes-templates

An extension for [Echoes](https://github.com/player-03/echoes), adding support for entity templates. Templates are syntax sugar, allowing you to treat entities more like classes.

## Usage

To install Echoes-templates, run `haxelib install echoes-templates` or `haxelib git https://github.com/player-03/echoes-templates.git`.

If you're switching from Echoes' built-in entity templates, make the following changes:

- Find "@:build(echoes.Entity.build())", and replace it with "@:build(echoes.Template.build())".
- Find "@:arguments" and "@:optionalArguments", and replace them with [constructors](#Template arguments). For instance, if a template has `@:arguments(Foo) @:optionalArguments(Bar)`, delete both and add `public function new(foo:Foo, ?bar:Bar);`.

## Entity templates

Sometimes, a combination of components comes up frequently enough that you want to be able to add them as a batch. For this, you can define an entity template, which is an abstract wrapping `Entity`.

```haxe
@:build(echoes.Template.build())
abstract Fighter(Entity) {
	public var attack:Attack = 1;
	public var health:Health = 10;
}
```

In this example, the `Fighter` template represents an entity with `Attack` and `Health` components. In other words, it's an entity that can both deal and receive damage.

The build macro (`echoes.Template.build()`) generates a constructor, as well as getters and setters for each component. This gives you a couple ways to interact with the fighter.

```haxe
var fighter:Fighter = new Fighter();

//You can treat components like variables.
trace(fighter.attack); //1
trace(fighter.health); //10
trace(fighter.hitbox); //"Square with width 1"

fighter.attack = 2;
trace(fighter.attack); //2

//Or you can treat `fighter` like a normal entity.
fighter.add((8:Health));
trace(fighter.get(Health)); //8

fighter.add(new TemporaryPowerup(7.5));
trace(fighter.get(TemporaryPowerup).timeLeft); //7.5
```

Under the hood, setting `Fighter`'s variables adds and removes those components. Systems will receive `@:add`, `@:update`, and `@:remove` events as normal for that combination of components.

## Combining templates

It's possible to apply multiple templates to a single entity.

```haxe
@:build(echoes.Template.build())
abstract Fighter(Entity) {
	public var attack:Attack = 4;
	public var health:Health = 10;
}

@:build(echoes.Template.build())
abstract Scout(Entity) {
	public var health:Health = 5;
	public var stealth:Stealth = 12;
}

class Main {
	public static function main():Void {
		var scout:Scout = new Scout();
		
		trace(scout.get(Attack)); //null
		
		//Each template provides an `applyTemplateTo()` function, which adds the
		//template's components to an entity.
		var scoutFighter:Fighter = Fighter.applyTemplateTo(scout);
		
		//It's still the same entity afterwards, just with more components.
		trace(scout == scoutFighter); //true
		
		trace(scout.get(Attack)); //4
		trace(scoutFighter.attack); //4
		
		trace(scout.stealth); //12
		
		//Since Haxe 
		trace(scoutFighter.get(Stealth)); //12
		
		//If a component already exists, `applyTemplateTo()` won't overwrite it.
		//In this case, `Scout` had already set `Health`.
		trace(scoutFighter.health); //5
	}
}
```

## Template arguments

You can define a constructor that takes components as arguments.

```haxe
@:build(echoes.Template.build())
abstract Fighter(Entity) {
	public var attack:Attack = 4;
	public var health:Health = 10;
	public var sprite:Sprite;
	
	//You don't have to define a body; the macro will add it for you.
	public function new(sprite:Sprite);
}

class Main {
	public static function main():Void {
		//To construct a `Fighter`, you must pass a `Sprite`.
		var fighter:Fighter = new Fighter(new Sprite("meleeFighter.png"));
		
		//This also applies when calling `applyTemplateTo()`.
		var entity:Entity = new Entity();
		Fighter.applyTemplateTo(entity, new Sprite("rangedFighter.png"));
		
		//Note: if the entity already has a `Sprite`, the old one will be kept.
		Fighter.applyTemplateTo(entity, new Sprite("meleeFighter.png"));
		trace(entity.get(Sprite).path); //"rangedFighter.png"
	}
}
```

### Optional arguments

Constructor arguments may be optional, with or without default values. If an optional argument has no default, and the corresponding field also has no default, it will default to null.

```haxe
@:build(echoes.Template.build())
abstract Fighter(Entity) {
	public var attack:Attack = 4;
	public var health:Health;
	public var sprite:Sprite;
	
	//`attack` defaults to 4, as specified above. `sprite` doesn't have that, so
	//it defaults to null, meaning `new Fighter().exists(Sprite)` will be false.
	public function new(?attack:Attack, ?health:Health = 15, ?sprite:Sprite);
}
```

Variables can refer to variables above them, since they're initialized in order.

```haxe
@:build(echoes.Template.build())
abstract Fighter(Entity) {
	public var attack:Attack = 1;
	public var health:Health = 10;
	public var maxHealth:MaxHealth = health + 2;
}
```

## Child templates

Templates can wrap one another, which behaves similarly to extending a class. The one being wrapped is referred to as the "parent," and the one doing the wrapping is the "child."

```haxe
@:build(echoes.Template.build())
abstract Unit(Entity) {
	public var health:Health;
	
	public function new(health:Health);
}

@:build(echoes.Template.build())
abstract Scout(Unit) {
	public var stealth:Stealth = 12;
	
	//`health` will be passed through to the `Unit` constructor.
	public function new(?health:Health = 5, ?stealth:Stealth);
}
```

Child templates automatically forward all of their parents' fields.

```haxe
final scout:Scout = new Scout();

//`health` is forwarded from `Unit`.
trace(scout.health); //5

//`add()` is forwarded from `Entity`.
scout.add(new Sprite("forestScout.png"));
```

And they can be automatically converted to any parent type.

```haxe
final unit:Unit = scout;
final entity:Entity = scout;
```

## Abstract features

All entity templates are [abstracts](https://haxe.org/manual/types-abstract.html), and all the usual features work as normal.

```haxe
@:build(echoes.Template.build())
abstract Unit(Entity) {
	//Instance variables and constructors are handled by the macro.
	public var maxHealth:MaxHealth = DEFAULT_MAX_HEALTH;
	public var health:Health = maxHealth;
	public function new(?health:Health, ?maxHealth:MaxHealth);
	
	//Everything else is fair game.
	
	//Static variables:
	public static inline final DEFAULT_MAX_HEALTH:MaxHealth = 20;
	
	//Properties:
	public var damage(get, set):Int;
	private inline function get_damage():Int {
		return maxHealth - health;
	}
	private inline function set_damage(value:Int):Int {
		health = maxHealth - value;
		return value;
	}
	
	//Type conversion:
	@:to public inline function toString():String {
		return haxe.Json.stringify({ health: health, maxHealth: maxHealth });
	}
	@:from public static inline function fromString(string:String):Unit {
		final values = haxe.Json.parse(string);
		return new Unit(values.health, values.maxHealth);
	}
	
	//Operators:
	@:op(A > B) private inline function greaterThan(other:Unit):Bool {
		return health > other.health;
	}
	@:op(A < B) private inline function lessThan(other:Unit):Bool {
		return health < other.health;
	}
	@:op(A == B) private inline function equal(other:Unit):Bool {
		return health == other.health;
	}
}
```
