package echoes.macro;

#if macro

import haxe.Exception;
import haxe.macro.Expr;
import haxe.macro.Printer;
import haxe.macro.Type;

using echoes.macro.ComponentStorageBuilder;
using echoes.macro.EntityTools;
using echoes.macro.MacroTools;
using haxe.EnumTools;
using haxe.macro.ComplexTypeTools;
using haxe.macro.Context;
using haxe.macro.ExprTools;
using Lambda;

/**
 * @see `echoes.Template.build()`
 */
class TemplateBuilder {
	/**
	 * For each template, maps the template's fully-qualified type name (e.g.,
	 * `com.pack.MyType` or `com.pack.MyType.SubType`) onto useful information
	 * gathered while building it.
	 * 
	 * If no information exists for this type name, it still needs to be built,
	 * which can usually be done by calling `abstractType.impl.get()`. If a
	 * mapping exists but is null, the type is in the process of being built.
	 */
	private static final builtTemplates:Map<String, BuildInfo> = new Map();
	
	@:allow(echoes)
	private static function build():Array<Field> {
		var fields:Array<Field> = Context.getBuildFields();
		
		//Information gathering
		//=====================
		
		//Get information about the `abstract` being built.
		final type:AbstractType = switch(Context.getLocalType()) {
			case TInst(_.get().kind => KAbstractImpl(_.get() => type), _):
				type;
			default:
				Context.fatalError("Entity.build() only works on abstract types.", Context.currentPos());
		};
		
		final qualifiedType:String = qualifyTypeName(type);
		if(builtTemplates.exists(qualifiedType)) {
			if(builtTemplates[qualifiedType] == null) {
				Context.fatalError('Loop detected: $qualifiedType is already in the middle of being built.', Context.currentPos());
			} else {
				Context.fatalError('$qualifiedType was already built.', Context.currentPos());
			}
		} else {
			builtTemplates[qualifiedType] = null;
		}
		
		if(type.params != null && type.params.length > 0) {
			Context.fatalError('${ type.name } may not have any parameters.', Context.currentPos());
		}
		
		/**
		 * The parent types, up to and including `Entity`.
		 */
		final parents:Array<{ complexType:ComplexType, abstractType:AbstractType }> = [];
		var nextParent:Type = type.type;
		for(_ in 0...100) {
			switch(nextParent.follow()) {
				case TInst(_.get().kind => KAbstractImpl(_.get() => parentAbstract), _),
					TAbstract(_.get() => parentAbstract, _):
					parents.push({
						complexType: nextParent.toComplexType(),
						abstractType: parentAbstract
					});
					
					if(parentAbstract.name == "Entity" && parentAbstract.pack.length == 1 && parentAbstract.pack[0] == "echoes") {
						break;
					} else {
						nextParent = parentAbstract.type;
					}
				default:
					return Context.fatalError('${ type.name } must wrap echoes.Entity.', Context.currentPos());
			}
		}
		
		//Check for important fields.
		var onTemplateApplied:Bool = false;
		var constructor:Field = null;
		for(field in fields) {
			switch(field.name) {
				case "new", "_new":
					constructor = field;
				case "applyTemplateTo", "applyTemplateToSelf":
					return Context.fatalError('${ field.name } is reserved. Instead, declare an onTemplateApplied() function.', field.pos);
				case "onTemplateApplied" if(field.kind.match(FFun(_.args => []))):
					onTemplateApplied = true;
				default:
			}
		}
		if(constructor != null) {
			fields.remove(constructor);
		}
		
		//Constructor arguments
		//---------------------
		
		//Check for the old format.
		if(type.meta.has(":arguments") || type.meta.has(":optionalArguments")) {
			Context.error("@:arguments and @:optionalArguments are no longer supported. "
				+ "Instead, add a constructor that takes the arguments you need.",
				Context.currentPos());
		}
		
		/**
		 * The immediate parent's build info.
		 */
		var superInfo:BuildInfo = null;
		if(parents.length > 1) {
			final superType:AbstractType = parents[0].abstractType;
			final qualifiedSuperType:String = qualifyTypeName(superType);
			superInfo = builtTemplates[qualifiedSuperType];
			
			if(superInfo == null) {
				if(superType.impl != null) {
					superType.impl.get();
					superInfo = builtTemplates[qualifiedSuperType];
					if(superInfo == null) {
						Context.fatalError('$qualifiedSuperType was not built, or is not an entity template. Do you need to add `@:build(echoes.Entity.build())`?', Context.currentPos());
					}
				} else {
					Context.fatalError('Don\'t know how to build $qualifiedSuperType, because its `impl` is null.', Context.currentPos());
				}
			}
		}
		
		/**
		 * An ordered list of parameters taken by the constructor and the
		 * "apply" functions. This does not include the `Entity` parameter for
		 * `applyTemplateTo()`.
		 */
		final parameters:Array<FunctionArg> = [];
		switch(constructor) {
			case null:
				if(superInfo != null) {
					for(superParam in superInfo.parameters) {
						if(!superParam.opt && superParam.value == null) {
							parameters.push(superParam);
						}
					}
				}
			case _.kind => FFun(f):
				for(arg in f.args) {
					//Fully qualify the argument type so child templates can
					//reference it, even if the user didn't import it.
					if(arg.type != null) {
						arg.type = arg.type.toType().toComplexType();
					}
					
					parameters.push(arg);
				}
				
				switch(f.expr) {
					case null, macro { }:
						//No problem.
					default:
						Context.warning("Constructor body will be ignored and replaced, remove it to disable this warning.", f.expr.pos);
				}
			default:
				Context.fatalError("Expected function.", constructor.pos);
		};
		
		/**
		 * The name of the component storage associated with each parameter, if
		 * `parameters` exists.
		 */
		final parameterStorage:Array<String> = [for(param in parameters)
			param.type != null
				? param.type.getComponentStorageName()
				: null
		];
		
		//Modifications
		//=============
		
		//Forward all parent fields.
		if(!type.meta.has(":forward")) {
			type.meta.add(":forward", [], Context.currentPos());
		}
		
		//Allow converting to all parent types.
		for(parent in parents) {
			final name:String = "to" + parent.abstractType.name;
			final parentType:ComplexType = parent.complexType;
			fields.pushFields(macro class ToParent {
				/**
				 * Caution: in C++, this converts `null` to `0`. Specifically,
				 * it generates the code `(int) entity` instead of `entity`.
				 * Tweaks like `Null<$parentType>` have no effect on this
				 * generated code.
				 */
				@:to private inline function $name():$parentType {
					return this;
				}
			});
		}
		
		//Process the component fields.
		final components:Array<FunctionArg> = [];
		for(field in fields) {
			if(field.access != null && field.access.contains(AStatic)) {
				continue;
			}
			
			if(field.access != null && field.access.contains(AFinal)) {
				Context.error("Components cannot have the final keyword.", field.pos);
			}
			
			//Parse the field.
			var componentType:Null<ComplexType>;
			var expr:Null<Expr>;
			switch(field.kind) {
				case FVar(t, e):
					componentType = t;
					expr = e;
				default:
					continue;
			}
			
			//Infer the component type, if not explicitly specified.
			if(componentType == null) {
				if(expr != null) {
					try {
						componentType = expr.parseComponentType().toComplexType();
					} catch(e:Exception) {
					}
				}
				
				if(componentType == null) {
					Context.fatalError('${ field.name } requires a type.', field.pos);
					continue;
				}
			} else {
				//Fully qualify the type to avoid "not found" errors.
				componentType = componentType.toType().toComplexType();
			}
			
			//Record the initial/default value.
			if(expr != null) {
				components.push({
					name: switch(componentType) {
						case TPath({ name: name, sub: null }):
							name;
						case TPath({ sub: sub }):
							sub;
						default:
							new Printer().printComplexType(componentType);
					},
					type: componentType,
					value: switch(expr) {
						case macro null:
							null;
						default:
							macro @:pos(expr.pos) ($expr:$componentType);
					}
				});
			}
			
			//Check for reserved types.
			switch(componentType) {
				case macro:Entity, macro:echoes.Entity:
					Context.fatalError("Entity is reserved. Consider using a typedef, abstract, or Int", field.pos);
				case macro:Float, macro:StdTypes.Float:
					Context.fatalError("Float is reserved for lengths of time. Consider using a typedef or abstract", field.pos);
				default:
			}
			
			//Convert the field to a property, and remove the expression.
			field.kind = FProp("get", "set", macro:Null<$componentType>, null);
			
			final getter:String = "get_" + field.name;
			final setter:String = "set_" + field.name;
			
			fields.pushFields(macro class Accessors {
				private inline function $getter():Null<$componentType> {
					return this.get((_:$componentType));
				}
				
				private inline function $setter(value:Null<$componentType>):Null<$componentType> {
					this.add(value);
					return value;
				}
			});
		}
		
		/**
		 * The number of components that were defined by a field. Everything in
		 * `components` at or after this index was instead defined by a
		 * constructor argument.
		 */
		final componentFields:Int = components.length;
		
		//Look for matches between `parameters` and `components`, and add any
		//missing values to the latter.
		{
			final componentStorage:Array<String> = [for(component in components)
				component.type.getComponentStorageName()];
			
			final printer:Printer = new Printer();
			for(i => parameter in parameters) {
				final componentIndex:Int = componentStorage.indexOf(parameterStorage[i]);
				if(componentIndex < 0) {
					components.push(parameter);
					continue;
				}
				
				final component:FunctionArg = components[componentIndex];
				if(component.value != null && parameter.value != null) {
					final componentValue:String = printer.printExpr(switch(component.value) {
						case macro ($componentValue:$_):
							componentValue;
						default:
							component.value;
					});
					
					final parameterValue:String = printer.printExpr(parameter.value);
					if(componentValue != parameterValue) {
						Context.warning('This default value will be ignored, because the constructor declares a default value of ${ parameterValue }.', component.value.pos);
					}
					
					//`component.value` isn't used anywhere other than the
					//constructor and `applyTemplateToSelf()`, and since
					//`parameter.value` is also defined, it's fully redundant.
					component.value = null;
				}
			}
		}
		
		//"Apply" functions
		//-----------------
		
		/**
		 * Adds `parameters` to each function in the given type definition, then
		 * inserts those functions at the beginning of `fields`, in order.
		 */
		function addFunctions(definition:TypeDefinition):Void {
			for(field in definition.fields) {
				switch(field.kind) {
					case FFun(f):
						f.args = f.args.concat(parameters);
					default:
						Context.fatalError("Not a function.", field.pos);
				}
			}
			
			//Insert the new fields first, so that if there's a name conflict,
			//Haxe will flag the user's version.
			fields = definition.fields.concat(fields);
		}
		
		//Add the constructor and `applyTemplateTo()`.
		final templateType:ComplexType = TPath({ pack: [], name: type.name });
		final arguments:Array<Expr> = [for(p in parameters) macro $i{ p.name }];
		addFunctions(macro class Constructor {
			public static inline function applyTemplateTo(entity:echoes.Entity):$templateType {
				(cast entity:$templateType).applyTemplateToSelf($a{ arguments });
				return cast entity;
			}
			
			public inline function new() {
				this = cast new echoes.Entity();
				applyTemplateToSelf($a{ arguments });
			}
		});
		fields[0].doc = 'Converts the given entity to `${ type.name }` by '
			+ "adding any missing components.";
		
		//Prepare the `applyTemplateToSelf()` function. Set the components in
		//order of priority: values passed by the user, then known values, then
		//inherited values.
		final applyToSelfExprs:Array<Expr> = [];
		for(parameter in parameters) {
			applyToSelfExprs.push(macro this.addIfMissing($i{ parameter.name }));
		}
		for(i in 0...componentFields) {
			final component:FunctionArg = components[i];
			if(component.value != null) {
				applyToSelfExprs.push(macro this.addIfMissing(${ component.value }));
			}
		}
		if(superInfo != null) {
			final superArguments:Array<Expr> = [for(i => superParam in superInfo.parameters) {
				final index:Int = parameterStorage.indexOf(superInfo.parameterStorage[i]);
				if(index < 0) {
					if(!superParam.opt && superParam.value == null && superParam.type != null) {
						Context.error('Please add ${ constructor == null ? "a constructor that takes " : "" }'
							+ 'an argument of type ${ new Printer().printComplexType(superParam.type) }, '
							+ 'as required by ${ parents[0].abstractType.name }.',
							constructor != null ? constructor.pos : Context.currentPos());
					}
					
					macro null;
				} else {
					macro $i{ parameters[index].name };
				}
			}];
			
			applyToSelfExprs.push(macro @:privateAccess this.applyTemplateToSelf($a{ superArguments }));
		}
		if(onTemplateApplied) {
			applyToSelfExprs.push(macro onTemplateApplied());
		}
		
		//Add `applyTemplateToSelf()`; it must not be static because
		//`components` may refer to instance properties or functions.
		addFunctions(macro class ApplyToSelf {
			@:noCompletion private function applyTemplateToSelf():Void $b{ applyToSelfExprs }
		});
		
		//"Remove" functions
		//------------------
		
		final removeFromSelfExprs:Array<Expr> = [];
		for(component in components) {
			final storage:Expr = component.type.getComponentStorage();
			removeFromSelfExprs.push(macro $storage.remove(this));
		}
		if(parents.length > 1) {
			removeFromSelfExprs.push(macro if(recursive) @:privateAccess this.removeTemplateFromSelf(true));
		}
		
		fields = (macro class RemoveTemplate {
			@:noCompletion public static inline function removeTemplateFrom(entity:echoes.Entity, ?recursive:Bool = false):echoes.Entity {
				(cast entity:$templateType).removeTemplateFromSelf(${ parents.length > 1 ? macro recursive : macro false });
				return cast entity;
			}
			
			@:noCompletion private function removeTemplateFromSelf(recursive:Bool):Void $b{ removeFromSelfExprs }
		}).fields.concat(fields);
		
		if(parents.length <= 1) {
			switch(fields[0].kind) {
				case FFun(f):
					f.args.pop();
				default:
			}
		}
		
		final parentNames:Array<String> = [for(i in 0...(parents.length - 1))
			"`" + parents[i].abstractType.name + "`"
		];
		if(parentNames.length > 2) {
			parentNames.push("and " + parentNames.pop());
		}
		fields[0].doc =
			(components.length == 1
				? 'Removes `${ new Printer().printComplexType(components[0].type) }`'
				: 'Removes `${ type.name }`\'s ${ components.length } components')
			+ " from the given entity.\n\nCaution: this feature is experimental, and may be subject to change."
			+ (parents.length > 1 ? '\n@param recursive Also removes components inherited from ${ parentNames.join(", ") }.' : "");
		
		builtTemplates[qualifiedType] = {
			fields: fields,
			parameters: parameters,
			parameterStorage: parameterStorage
		};
		
		return fields;
	}
	
	private static inline function qualifyTypeName(type:AbstractType):String {
		if(type.module == type.name || StringTools.endsWith(type.module, "." + type.name)) {
			return type.module;
		} else {
			return type.module + "." + type.name;
		}
	}
}

private typedef BuildInfo = {
	fields:Array<Field>,
	parameters:Array<FunctionArg>,
	parameterStorage:Array<String>
};

#end
