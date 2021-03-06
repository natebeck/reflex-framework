package reflex.skins
{
	
	import flash.display.DisplayObject;
	import flash.display.InteractiveObject;
	import flash.display.Sprite;
	import flash.events.Event;
	import flash.events.EventDispatcher;
	import flash.events.IEventDispatcher;
	import flash.geom.Point;
	import flash.geom.Rectangle;
	
	import mx.collections.IList;
	import mx.events.CollectionEvent;
	import mx.events.CollectionEventKind;
	
	import reflex.binding.Bind;
	import reflex.binding.DataChange;
	import reflex.collections.SimpleCollection;
	import reflex.components.IStateful;
	import reflex.containers.IContainer;
	import reflex.invalidation.Invalidation;
	import reflex.layouts.BasicLayout;
	import reflex.layouts.ILayout;
	import reflex.measurement.IMeasurable;
	import reflex.measurement.IMeasurements;
	import reflex.measurement.Measurements;
	import reflex.metadata.resolveBindings;
	import reflex.states.applyState;
	import reflex.states.removeState;
	import reflex.templating.addItemsAt;
	
	/**
	 * Skin is a convenient base class for many skins, a swappable graphical
	 * definition. Skins decorate a target Sprite by drawing on its surface,
	 * adding children to the Sprite, or both.
	 * @alpha
	 */
	[DefaultProperty("content")]
	public class Skin extends EventDispatcher implements ISkin, IContainer, IStateful, IMeasurable
	{
		
		static public const MEASURE:String = "skinMeasure";
		static public const LAYOUT:String = "skinLayout";
		
		Invalidation.registerPhase(MEASURE, 201, false);
		Invalidation.registerPhase(LAYOUT, 299, true);
		
		private var renderers:Array = [];
		private var _layout:ILayout;
		private var _states:Array;
		private var _currentState:String; 
		private var _transitions:Array;
		private var _template:Object; // = new ReflexDataTemplate();
		
		private var unscaledWidth:Number = 160;
		private var unscaledHeight:Number = 22;
		
		private var _explicit:IMeasurements;
		private var _measured:IMeasurements;
		
		//
		
		/**
		 * @inheritDoc
		 */
		[Bindable(event="widthChange")]
		public function get width():Number { return unscaledWidth; }
		public function set width(value:Number):void {
			if (unscaledWidth == value) {
				return;
			}
			_explicit.width = value;
			Invalidation.invalidate(target, LAYOUT);
			DataChange.change(this, "width", unscaledWidth, unscaledWidth = value);
		}
		
		/**
		 * @inheritDoc
		 */
		[Bindable(event="heightChange")]
		public function get height():Number { return unscaledHeight; }
		public function set height(value:Number):void {
			if (unscaledHeight == value) {
				return;
			}
			_explicit.height = value;
			Invalidation.invalidate(target, LAYOUT);
			DataChange.change(this, "height", unscaledHeight, unscaledHeight = value);
		}
		
		/**
		 * @inheritDoc
		 */
		[Bindable(event="explicitChange")]
		public function get explicit():IMeasurements { return _explicit; }
		/*public function set explicit(value:IMeasurements):void {
			if (value == _explicit) {
				return;
			}
			if (value != null) { // must not be null
				PropertyEvent.dispatchChange(this, "explicit", _explicit, _explicit = value);
				InvalidationEvent.invalidate(target, LAYOUT);
			}
		}*/
		
		/**
		 * @inheritDoc
		 */
		[Bindable(event="measuredChange")]
		public function get measured():IMeasurements { return _measured; }
		/*public function set measured(value:IMeasurements):void {
			if (value == _measured) {
				return;
			}
			if (value != null) { // must not be null
				PropertyEvent.dispatchChange(this, "measured", _measured, _measured = value);
				InvalidationEvent.invalidate(target, LAYOUT);
			}
		}*/
		
		/**
		 * @inheritDoc
		 */
		public function setSize(width:Number, height:Number):void {
			if (unscaledWidth != width) { DataChange.change(this, "width", unscaledWidth, unscaledWidth = width); }
			if (unscaledHeight != height) { DataChange.change(this, "height", unscaledHeight, unscaledHeight = height); }
			Invalidation.invalidate(target, LAYOUT);
		}
		
		/**
		 * @inheritDoc
		 */
		[Bindable(event="layoutChange")]
		public function get layout():ILayout { return _layout; }
		public function set layout(value:ILayout):void {
			if (_layout == value) {
				return;
			}
			var oldLayout:ILayout = _layout;
			if (_layout) { _layout.target = null; }
			_layout = value;
			_layout.target = target;
			if (target) {
				Invalidation.invalidate(target, MEASURE);
				Invalidation.invalidate(target, LAYOUT);
			}
			DataChange.change(this, "layout", oldLayout, _layout);
		}
		
		[Bindable(event="templateChange")]
		public function get template():Object { return _template; }
		public function set template(value:Object):void {
			if (_template == value) {
				return;
			}
			DataChange.change(this, "template", _template, _template = value);
		}
		
		
		[Bindable(event="statesChange")]
		public function get states():Array { return _states; }
		public function set states(value:Array):void {
			if (_states == value) {
				return;
			}
			DataChange.change(this, "states", _states, _states = value);
		}
		
		[Bindable(event="transitionsChange")]
		public function get transitions():Array { return _transitions; }
		public function set transitions(value:Array):void {
			DataChange.change(this, "transitions", _transitions, _transitions = value);
		}
		
		[Bindable(event="currentStateChange")]
		public function get currentState():String { return _currentState; }
		public function set currentState(value:String):void {
			if (_currentState == value) {
				return;
			}
			// might need to add invalidation for this later
			reflex.states.removeState(this, _currentState, states);
			DataChange.change(this, "currentState", _currentState, _currentState = value);
			reflex.states.applyState(this, _currentState, states);
		}
		
		public function hasState(state:String):Boolean {
			for each(var s:Object in states) {
				if(s.name == state) {
					return true;
				}
			}
			return false;
		}
		
		
		private var _target:Sprite;
		private var _content:IList;
		
		public function Skin()
		{
			super();
			_content = new SimpleCollection();
			_explicit = new Measurements(this);
			_measured = new Measurements(this, 160, 22);
			//if (_layout == null) {
				//_layout = new BasicLayout();
			//}
			_content.addEventListener(CollectionEvent.COLLECTION_CHANGE, onChildrenChange);
			//Bind.addListener(this, onLayoutChange, this, "target.layout");
			//Bind.addListener(this, onLayoutChange, this, "layout");
			//Bind.addBinding(this, "data", this, "target.data");
			//Bind.addBinding(this, "state", this, "target.state");
			//addEventListener(MEASURE, onMeasure, false, 0, true);
			//addEventListener(LAYOUT, onLayout, false, 0, true);
			reflex.metadata.resolveBindings(this);
		}
		
		
		[Bindable(event="targetChange")]
		public function get target():Sprite{ return _target; }
		public function set target(value:Sprite):void
		{
			if (_target == value) {
				return;
			}
			
			var oldValue:Object = _target;
			_target = value;
			if (layout) {
				layout.target = _target;
			}
			
			if (this.hasOwnProperty('hostComponent')) {
				this['hostComponent'] = _target;
			}
			
			if (_target != null) {
			/*
				//var i:int;
				//for (i = 0; i < _children.length; i++) {
					//_target.addChildAt(_children.getItemAt(i) as DisplayObject, i);
				//}
				var items:Array = [];
				for (i = 0; i < _children.length; i++) {
					items.push(_children.getItemAt(i));
				}
				reflex.display.addItemsAt(_target, items, 0);
				/*
				containerPart = getSkinPart("container") as DisplayObjectContainer;
				if (_target is IContainer && containerPart != null) {
					
					skinnable = _target as IContainer;
					skinnable.children.addEventListener(ListEvent.LIST_CHANGE, onContentChange, false, 0xF);
					if (skinnable.children.length > 0) {
						defaultContainer = false;
						Bind.addBinding(containerPart, "padding", this, "target.padding");
						while (containerPart.numChildren) {
							removeContainerChildAt(containerPart.numChildren-1);
						}
						for (i = 0; i < skinnable.children.length; i++) {
							addContainerChildAt(skinnable.children.getItemAt(i) as DisplayObject, i);
						}
					}
				}
				*/
				target.addEventListener(MEASURE, onMeasure, false, 0, true);
				target.addEventListener(LAYOUT, onLayout, false, 0, true);
				Invalidation.invalidate(_target, MEASURE);
				Invalidation.invalidate(_target, LAYOUT);
			}
			
			var items:Array = _content.toArray();
			reset(items);
			DataChange.change(this, "target", oldValue, _target);
		}
		/*
		protected function init():void
		{
		}
		*/
		/**
		 * @inheritDoc
		 */
		[ArrayElementType("Object")]
		[Bindable(event="contentChange")]
		public function get content():IList { return _content; }
		public function set content(value:*):void
		{
			if (_content == value) {
				return;
			}
			
			var oldContent:IList = _content;
			
			if (_content) {
				_content.removeEventListener(CollectionEvent.COLLECTION_CHANGE, onChildrenChange);
			}
			
			if (value == null) {
				_content = null;
			} else if (value is IList) {
				_content = value as IList;
			} else if (value is Array || value is Vector) {
				_content = new SimpleCollection(value);
			} else {
				_content = new SimpleCollection([value]);
			}
			
			if (_content) {
				_content.addEventListener(CollectionEvent.COLLECTION_CHANGE, onChildrenChange);
				var items:Array = _content.toArray();
				reset(items);
			}
			
			DataChange.change(this, "content", oldContent, _content);
		}
		/*
		public function getSkinPart(part:String):InteractiveObject
		{
			return (part in this) ? this[part] : null;
		}
		*/
		private function onChildrenChange(event:CollectionEvent):void
		{
			if (_target == null) {
				return;
			}
			var child:DisplayObject;
			var loc:int = event.location;
			switch (event.kind) {
				case CollectionEventKind.ADD :
					add(event.items, loc);
					break;
				case CollectionEventKind.REMOVE :
					remove(event.items, loc);
					break;
				case CollectionEventKind.REPLACE :
					_target.removeChild(event.items[1]);
					_target.addChildAt(event.items[0], loc);
					break;
				case CollectionEventKind.RESET :
				default:
					reset(event.items);
					break;
			}
		}
		
		
		private function add(items:Array, index:int):void {
			var children:Array = reflex.templating.addItemsAt(_target, items, index, _template);
			
			var length:int = items.length;
			for(var i:int = 0; i < length; i++) {
				renderers.splice(index+i, 0, items[i]);
			}
			
			Invalidation.invalidate(_target, MEASURE);
			Invalidation.invalidate(_target, LAYOUT);
		}
		
		private function remove(items:Array, index:int):void {
			// this isn't working with templating yet
			var child:Object;
			for each (child in items) {
				_target.removeChild(child as DisplayObject);
				var index:int = renderers.indexOf(child);
				renderers.splice(index, 1);
			}
			Invalidation.invalidate(_target, MEASURE);
			Invalidation.invalidate(_target, LAYOUT);
		}
		
		private function reset(items:Array):void {
			if (_target) {
				while (_target.numChildren) {
					_target.removeChildAt(_target.numChildren-1);
				}
				renderers = reflex.templating.addItemsAt(_target, items, 0, template); // todo: correct ordering
				Invalidation.invalidate(_target, MEASURE);
				Invalidation.invalidate(_target, LAYOUT);
			}
		}
		
		/*
		private function onLayoutChange(value:ILayout):void
		{
			if (_target == null) {
				return;
			}
			// nada
		}
		*/
		private function onMeasure(event:Event):void {
			var target:IMeasurable= this.target as IMeasurable;
			if (layout && (isNaN(explicit.width) || isNaN(explicit.height))) {
				var items:Array = content.toArray();
				var point:Point = layout.measure(items);
				if (point.x != measured.width || point.y != measured.height) {
					measured.width = point.x;
					measured.height = point.y;
				}
			}
			
		}
		
		private function onLayout(event:Event):void {
			if (layout) {
				var items:Array = _content.toArray();
				var rectangle:Rectangle = new Rectangle(0, 0, unscaledWidth, unscaledHeight);
				//var rectangle:Rectangle = new Rectangle(0, 0, target.width, target.height);
				layout.update(items, rectangle);
			}
		}
		
	}
}
