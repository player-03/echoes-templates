package;

import Components;
import echoes.ComponentStorage;
import echoes.Echoes;
import echoes.Entity;
import echoes.System;
import echoes.SystemList;
import echoes.utils.ComponentTypes;
import echoes.utils.Signal;
import echoes.View;
import haxe.PosInfos;
import MethodCounter.assertTimesCalled;
import Systems;
import Templates;
import utest.Assert;
import utest.Test;

class TemplateTest extends Test {
	private function teardown():Void {
		//Echoes.reset() is called by echoes.test.UTest.
		MethodCounter.reset();
	}
	
	//Tests may be run in any order, but not in parallel.
	
	private function testBasicTemplates():Void {
		new NameSystem().activate();
		new AppearanceSystem().activate();
		
		final entity:Entity = new Entity();
		entity.add(("John":Name));
		
		final namedEntity:NamedEntity = NamedEntity.applyTemplateTo(entity);
		Assert.equals(entity, namedEntity);
		Assert.equals("John", namedEntity.name);
		assertTimesCalled(1, "NameSystem.nameAdded");
		assertTimesCalled(0, "NameSystem.nameRemoved");
		
		namedEntity.name = null;
		Assert.equals(null, namedEntity.name);
		assertTimesCalled(1, "NameSystem.nameAdded");
		assertTimesCalled(1, "NameSystem.nameRemoved");
		
		final visualEntity:VisualEntity = VisualEntity.applyTemplateTo(namedEntity);
		Assert.equals(VisualEntity.DEFAULT_COLOR, visualEntity.color);
		assertTimesCalled(1, "AppearanceSystem.colorAdded");
		assertTimesCalled(0, "AppearanceSystem.colorRemoved");
		
		Assert.equals(VisualEntity.DEFAULT_SHAPE, (visualEntity:Entity).get(Shape));
		
		Assert.equals(NamedEntity.DEFAULT_NAME, new NamedEntity().name);
		Assert.notEquals(NamedEntity.DEFAULT_NAME, new NamedEntity("not default").name);
		assertTimesCalled(3, "NameSystem.nameAdded");
		assertTimesCalled(1, "NameSystem.nameRemoved");
		
		NameStringEntity.applyTemplateTo(visualEntity);
		Assert.equals(NameStringEntity.DEFAULT_NAME, namedEntity.name);
		assertTimesCalled(4, "NameSystem.nameAdded");
		assertTimesCalled(1, "NameSystem.nameRemoved");
		
		NamedEntity.removeTemplateFrom(namedEntity);
		Assert.isNull(namedEntity.name);
		Assert.notNull(namedEntity.get(String));
		assertTimesCalled(2, "NameSystem.nameRemoved");
		
		final nullEntity:Null<NamedEntity> = null;
		Assert.isNull(nullEntity);
		#if cpp
		Assert.notNull((nullEntity:Null<Entity>), "C++ code generation has improved, and a warning can be removed from EntityTemplateBuilder.");
		#else
		Assert.isNull((nullEntity:Null<Entity>));
		#end
	}
	
	private function testInheritance():Void {
		final entity:RequiredArgumentEntity = new RequiredArgumentEntity("abc");
		Assert.equals("abc", entity.string);
		
		final entity:OptionalRequiredArgumentEntity = new OptionalRequiredArgumentEntity(
			"abc", "xyz", (0xFFFFFF:Color));
		Assert.equals("xyz", entity.string);
		Assert.equals("abc", entity.stringTypedef);
		Assert.equals(0xFFFFFF, entity.get(Color));
		
		final entity:OptionalRequiredArgumentEntity = new OptionalRequiredArgumentEntity(
			null, "xyz");
		Assert.equals("xyz", entity.string);
		Assert.equals("default", entity.stringTypedef);
		Assert.isNull(entity.get(Color));
		
		final entity:InheritingEntity = new InheritingEntity("string");
		Assert.equals("string", entity.string);
		Assert.equals("default", entity.stringTypedef);
	}
}
