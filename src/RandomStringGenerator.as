package  {
	import flash.utils.Dictionary;
	/**
	 * Generates the string from random characters in specified range.
	 * @author makc
	 */
	public class RandomStringGenerator implements INameGenerator {
		public var from:uint, to:uint, prev:Dictionary = new Dictionary;
		public function RandomStringGenerator(from:uint = 1, to:uint = 255) {
			this.from = from;
			this.to = to;
		}
		
		public function generate(targetLength:uint, hasPoint : Boolean):String {
			var s:String = "";
			do {
				while (s.length < targetLength) {
					var c:String = String.fromCharCode (from + uint ((to - from + 0.4) * Math.random()) );
					if ((c != ".") || hasPoint) {
						s += c;
					}
				}
			} while (prev [s]);
			prev [s] = true;
			return s;
		}
		
	}

}