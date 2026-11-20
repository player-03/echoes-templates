package;

import Components;
import echoes.Entity;
import echoes.System;
import MethodCounter;

using StringTools;

class AppearanceSystem extends System implements IMethodCounter {
	@:a private function colorAdded(color:Color):Void {}
	@:u private function colorUpdated(color:Color):Void {}
	@:r private function colorRemoved(color:Color):Void {}
	
	@:add private function shapeAdded(shape:Shape, entity:Entity):Void {}
	@:upd private function shapeUpdated(shape:Shape, entity:Entity):Void {}
	@:rem private function shapeRemoved(shape:Shape, entity:Entity):Void {}
	
	@:added private function colorAndShapeAdded(shape:Shape, color:Color):Void {}
	@:updated private function colorAndShapeUpdated(shape:Shape, color:Color):Void {}
	@:removed private function colorAndShapeRemoved(shape:Shape, color:Color):Void {}
}

class NameSystem extends System implements IMethodCounter {
	@:add private function nameAdded(name:Name):Void {}
	@:update private function nameUpdated(name:Name):Void {}
	@:remove private function nameRemoved(name:Name, entity:Entity):Void {
		if(entity.exists(Name) && name != entity.get(Name)) {
			MethodCounter.count("NameSystem.nameReplaced");
		}
	}
}
