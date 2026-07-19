package echoes;

import echoes.ComponentStorage;
import echoes.macro.EntityTools;
import haxe.macro.Expr;

using echoes.macro.ComponentStorageBuilder;
using echoes.macro.MacroTools;
using haxe.macro.Context;
using Lambda;

/**
 * A build macro for entity templates. An entity template fills a similar role
 * to a class, allowing a user to easily create entities with pre-defined sets
 * of components. But unlike classes, it's possible to apply multiple templates
 * to a single entity.
 * 
 * Templates also offer syntax sugar for accessing components. For example,
 * if the template declares `var component:Component`, the user can then refer
 * to `entity.component` instead of `entity.get(Component)`.
 * 
 * Sample usage:
 * 
 * ```haxe
 * //`Fighter` is a template for entities involved in combat. A `Fighter` entity
 * //will have `Damage`, `Health`, and `Hitbox` components.
 * @:build(echoes.Template.build())
 * abstract Fighter(Entity) {
 *     //Each variable represents the component of that type. For instance,
 *     //`fighter.damage` will get/set the entity's `Damage` component.
 *     public var damage:Damage = 1;
 *     public var health:Health = 10;
 *     
 *     //Components listed in the constructor (see below) don't need a value.
 *     public var hitbox:Hitbox;
 *     
 *     //Components without a value that aren't listed in the constructor are
 *     //considered optional, and default to null.
 *     public var sprite:Sprite;
 *     
 *     //The constructor determines what arguments the template takes. The body
 *     //will be generated automatically, and should be left blank.
 *     public function new(hitbox:Hitbox);
 *     
 *     //An `applyTemplateTo()` function will be generated automatically, taking
 *     //the same arguments as the constructor (plus `entity`). This converts
 *     //any entity into a `Fighter`.
 *     //public static function applyTemplateTo(entity:Entity, hitbox:Hitbox);
 *     
 *     //The constructor is generated automatically, but you can declare
 *     //`onApplyTemplate()` to run code afterwards. As the name indicates, this
 *     //also runs after `applyTemplateTo()`.
 *     private inline function onApplyTemplate():Void {
 *         if(health <= 0) {
 *             health = 1;
 *         }
 *     }
 *     
 *     //You may add any other function as normal.
 *     public inline function getDamageDealt(target:Hitbox):Damage {
 *         if(target.overlapping(hitbox)) {
 *             return damage;
 *         } else {
 *             return 0;
 *         }
 *     }
 * }
 * 
 * //Templates may inherit from one another. The `@:forward` metadata will be
 * //automatically added if not present.
 * @:build(echoes.Template.build())
 * abstract RangedFighter(Fighter) {
 *     public var fireRate:FireRate = 1;
 *     public var range:Range = 2;
 *     
 *     //Components set in the child template override those from the parent.
 *     public var health:Health = 5;
 * }
 * 
 * class Main {
 *     public static function main():Void {
 *         var knight:Fighter = new Fighter(new SquareHitbox(1), new Sprite("fighter.png"));
 *         
 *         //The variables now act as shortcuts for `add()` and `get()`.
 *         trace(knight.health); //10
 *         trace(knight.get(Health)); //10
 *         
 *         //Because each variable has a different type, you don't need to
 *         //specify which type you mean.
 *         knight.health = 9;
 *         knight.damage = 3;
 *         trace(knight.get(Health)); //9
 *         trace(knight.get(Damage)); //3
 *         
 *         //If using `add()`, you still have to specify types.
 *         knight.add((8:Health));
 *         trace(knight.health); //8
 *         
 *         //It's also possible to convert a pre-existing entity to `Fighter`.
 *         var greenEntity:Entity = new Entity();
 *         greenEntity.add(Color.GREEN);
 *         greenEntity.add((20:Health));
 *         
 *         //`Fighter.applyTemplateTo()` adds all required components that are
 *         //currently missing, and casts the entity to `Fighter`.
 *         var greenKnight:Fighter = Fighter.applyTemplateTo(greenEntity, new RectHitbox(1, 2));
 *         
 *         //`Health` and `Color` remain the same as before.
 *         trace(greenKnight.health); //20
 *         trace("0x" + StringTools.hex(greenKnight.get(Color), 6)); //0x00FF00
 *         
 *         //`Damage` wasn't already defined, so it has its default value.
 *         trace(greenKnight.damage); //1
 *         
 *         //Since `sprite` is optional, `applyTemplateTo()` won't add one.
 *         trace(greenKnight.sprite); //null
 *     }
 * }
 * ```
 */
class Template {
	public static macro function build():Array<Field> {
		return echoes.macro.TemplateBuilder.build();
	}
}
