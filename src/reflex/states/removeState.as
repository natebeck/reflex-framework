package reflex.states
{
	
	import flash.display.DisplayObject;
	import mx.states.IOverride;
	import mx.states.State;
	
	public function removeState(target:Object, name:String, states:Array):void
	{
		for each(var state:State in states) {
			if(state.name == name) {
				for each(var override:IOverride in state.overrides) {
					override.remove(target);
				}
				return;
			}
		}
	}
	
}