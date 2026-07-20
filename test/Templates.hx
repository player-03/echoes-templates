package;

import Components;
import echoes.Entity;

@:build(echoes.Template.build())
abstract NamedEntity(Entity) {
	public static inline final DEFAULT_NAME:Name = "defaultName";
	
	public var name:Name;
	
	public function new(?name:Name = DEFAULT_NAME);
}
@:build(echoes.Template.build())
abstract NameStringEntity(NamedEntity) {
	public static inline final DEFAULT_STRING:String = "defaultString";
	public static inline final DEFAULT_NAME:String = "name";
	
	public var name:Name = DEFAULT_NAME;
	public var string:String = DEFAULT_STRING;
}

@:build(echoes.Template.build())
abstract RequiredArgumentEntity(Entity) {
	public var string:String;
	
	public function new(string:String);
}
@:build(echoes.Template.build())
abstract OptionalRequiredArgumentEntity(RequiredArgumentEntity) {
	public var stringTypedef:StringTypedef;
	
	public function new(?stringTypedef:StringTypedef = "default", string:String, ?color:Color);
}
@:build(echoes.Template.build())
abstract InheritingEntity(OptionalRequiredArgumentEntity) {
	public function new(string:String, ?applyVisualEntityTemplate:Bool = false) {
		super(null, string);
		
		if(applyVisualEntityTemplate) {
			VisualEntity.applyTemplateTo(this);
		}
	}
}

@:build(echoes.Template.build())
abstract VisualEntity(Entity) {
	public static inline final DEFAULT_COLOR:Color = 0x123456;
	public static inline final DEFAULT_SHAPE:Shape = SQUARE;
	
	public var color:Color = DEFAULT_COLOR;
	public var invertedColor:InvertedColor = 0xFFFFFF ^ color;
	public var shape = Shape.CIRCLE;
	
	private inline function onTemplateApplied():Void {
		shape = DEFAULT_SHAPE;
	}
	
	public inline function new(?color:Color);
}
