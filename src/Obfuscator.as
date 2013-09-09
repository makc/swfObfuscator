package {
	import com.bit101.components.*;
	import flash.display.*;
	import flash.events.*;
	import flash.geom.*;
	import flash.net.*;
	import flash.utils.*;
	
	/**
	 * SWF obfuscator v2.
	 * @author makc
	 */
	public class Obfuscator extends Sprite {
		public var hg:BitmapData;
	public var iswf:
		ByteArray, oswf:ByteArray;
		public var inames:Array, ipnames:Dictionary;
		public var excluded:Vector.<CheckBox> = new Vector.<CheckBox>;
		public var minchars:NumericStepper, replacements:List, method:ComboBox, remover:PushButton;
		public var progress:ProgressBar;
		public function Obfuscator () {
			[Embed(source="../hourglass.png")]var HG:Class;
			(hg = (new HG).bitmapData).floodFill (0, 0, 0x40000000);
			stage.align = "TL";
			stage.scaleMode = "noScale";
			new PushButton (this, 10, 10, "LOAD SWF", loadSWFFile);
			new PushButton (this, 120, 10, "OBFUSCATE", obfuscate);
			new PushButton (this, 230, 10, "SAVE SWF", saveSWFFile);
			new Label (this, 10, 65, "Replace identifiers that are at least                   characters, excluding:");
			with (minchars = new NumericStepper (this, 165, 66, createReplaceList)) {
				minimum = 5; maximum = 15; value = 8; width = 50;
			}
			new CheckBox (this, 10, 90, "FP/AIR", createReplaceList).selected = true; // ex. 0
			new CheckBox (this, 60, 90, "Public identifiers", createReplaceList); // ex. 1
			new CheckBox (this, 150, 90, "Flex", createReplaceList); // ex. 2
			new CheckBox (this, 190, 90, "MochiAds sensitive stuff", createReplaceList).selected = true; // ex. 3
			new Label (this, 10, 111, "with:");
			replacements = new List (this, 10, 145);
			replacements.width = 320;
			stage.addEventListener (KeyboardEvent.KEY_DOWN, scrollTheList);
			remover = new PushButton (this, 10, 1234, "remove selected replacement from list before obfuscation", removeSelectedReplacement);
			remover.width = 320;
			method = new ComboBox (this, 40, 110, "", [
				{ label: "random word combinations                                                            " },
				{ label: "random ASCII characters                                                             " },
				{ label: "random garbage (not even valid UTF-8)                                               " }
			]);
			method.addEventListener (Event.SELECT, createReplaceList);
			method.numVisibleItems = method.items.length;
			method.selectedIndex = 0;
			method.width = 290;
			
			for (var i:int = 0; i < numChildren; i++) {
				var dobj:DisplayObject = getChildAt (i);
				if (dobj is CheckBox) excluded.push (dobj as CheckBox);
			}
			
			new Label (this, 10, 40, "Obfuscation progress:");
			progress = new ProgressBar (this, 110, 45); progress.width = 330 - progress.x;
			Style.PROGRESS_BAR = 0xff7f;
			
			stage.addEventListener (Event.RESIZE, onResize); onResize ();
		}
		
		private function scrollTheList(e:KeyboardEvent):void {
			if ((e.target == stage) && (replacements.selectedIndex > -1)) {
				switch (e.keyCode) {
					case 38:
						replacements.selectedIndex = Math.max (0, replacements.selectedIndex - 1);
						replacements.scrollToSelection ();
						break;
					case 40:
						var n:int = replacements.items.length - 1;
						replacements.selectedIndex = Math.min (n, replacements.selectedIndex + 1);
						replacements.scrollToSelection ();
						break;
				}
			}
		}
		
		private var block:Sprite;
		private function addBlock ():void {
			if (block == null) {
				addChild (block = new Sprite);
				block.graphics.beginBitmapFill (hg, new Matrix (1, 0, 0, 1, (stage.stageWidth - hg.width) >> 1, (stage.stageHeight - hg.height) >> 1), false);
				block.graphics.drawRect (0, 0, stage.stageWidth, stage.stageHeight);
				block.graphics.endFill ();
			}
		}
		private function removeBlock ():void {
			if (block) {
				removeChild (block);
				block.graphics.clear ();
				block = null;
			}
		}
		
		private function onResize(e:Event = null):void {
			remover.y = stage.stageHeight - remover.height - 10;
			replacements.height = remover.y - replacements.y - 10;
			if (block) { removeBlock (); addBlock (); }
		}
		
		public function loadSWFFile (...f):void {
			addBlock ();
			new FileLoader (parseSWFFile);
		}
		
		public function parseSWFFile (data:ByteArray):void {
			if (data == null) { removeBlock (); return; }
			
			// decompress
			data.position = 0;
			if (data.readMultiByte (3, "us-ascii") == "CWS") {
				iswf = decompress (data);
			} else {
				iswf = data;
			}
			
			inames = SWFUtils.collectNames (iswf, 1);
			ipnames = new Dictionary;
			for each (var pname:String in SWFUtils.collectNames (iswf, 1, true)) ipnames [pname] = true;
			// createReplaceList will remove block in the end
			createReplaceList ();
		}
		
		public function createReplaceList (...f):void {
			if (iswf == null) return;
			
			// this might be lengthy operation so make sure we show hour glass 1st
			addBlock (); setTimeout (createReplaceList2, 42);
		}
		
		private function createReplaceList2 ():void {
			
			var namegen:INameGenerator;
			switch (method.selectedIndex) {
				case 0: namegen = new ReadableNameGenerator (); break;
				case 1: namegen = new RandomStringGenerator (0x21, 0x7E); break;
				case 2: namegen = new RandomStringGenerator (); break;
			}
			
			const FLASH:int = 0, PUBLIC:int = 1, FLEX:int = 2, MOCHI:int = 3;
			
			var items:Array = [];
			for (var i:int = 0, n:int = minchars.value; i < inames.length; i++) {
				var iname:String = inames [i];
				if (iname.length < n) continue; //break;
				// see if the name is excluded
				if (excluded [PUBLIC].selected && isInDictionary (iname, ipnames)) continue;
				if (excluded [FLASH].selected && isInDictionary (iname, SWFUtils.AIR)) continue;
				if (excluded [FLEX].selected && isInDictionary (iname, SWFUtils.FLEX)) continue;
				if (excluded [MOCHI].selected && isInDictionary (iname, SWFUtils.MOCHI)) continue;
				// generate replacement
				items.push (new Replacement (iname, namegen.generate (iname.length, iname.indexOf (".") > 0)));
			}
			replacements.items = items;
			
			removeBlock ();
		}
		
		private function isInDictionary (string:String, dictionary:Dictionary):Boolean {
			if (dictionary [string]) return true;
			for (var key:String in dictionary) {
				if (key.indexOf (string) > -1) {
					return true;
				}
			}
			return false;
		}
		
		public function removeSelectedReplacement (...f):void {
			if (replacements.selectedIndex >= 0) {
				replacements.removeItemAt (replacements.selectedIndex);
			}
		}
		
		private function obfuscate (...f):void {
			if (iswf == null) return;
			
			// this might be lengthy operation so make sure we show hour glass 1st
			addBlock (); setTimeout (obfuscate2, 42);
		}
		
		private function obfuscate2 ():void {
			oswf = new ByteArray;
			oswf.writeBytes (iswf, 0, iswf.length);
			
			if (replacements.items.length > 0) {
				progress.value = 0.05;
				new Replacer (replacements.items, oswf, obfuscate3, obfuscate4);
			} else {
				obfuscate4 ();
			}
		}
		
		private function obfuscate3 (p:Number):void {
			progress.value = 0.05 + p * 0.95;
		}
		
		private function obfuscate4 ():void {
			progress.value = 0;
			
			removeBlock ();
		}
		
		private function saveSWFFile (...f):void {
			if (oswf) new FileReference().save (compress (oswf), "obfuscated.swf");
		}

		// compression functions by Nikita Leshenko
		// http://active.tutsplus.com/tutorials/workflow/protect-your-flash-files-from-decompilers-by-using-encryption/

		private function compress (data:ByteArray):ByteArray {
			var header:ByteArray = new ByteArray;
			var decompressed:ByteArray = new ByteArray;
			var compressed:ByteArray = new ByteArray;

			header.writeBytes (data, 3, 5); // read the header, excluding the signature
			decompressed.writeBytes (data, 8); // read the rest

			decompressed.compress ();

			compressed.writeMultiByte ("CWS", "us-ascii"); // mark as compressed
			compressed.writeBytes (header);
			compressed.writeBytes (decompressed);

			return compressed;
		}

		private function decompress (data:ByteArray):ByteArray {
			var header:ByteArray = new ByteArray;
			var compressed:ByteArray = new ByteArray;
			var decompressed:ByteArray = new ByteArray;

			header.writeBytes (data, 3, 5); // read the uncompressed header, excluding the signature
			compressed.writeBytes (data, 8); // read the rest, compressed

			compressed.uncompress ();

			decompressed.writeMultiByte ("FWS", "us-ascii"); // mark as uncompressed
			decompressed.writeBytes (header); // write the header back
			decompressed.writeBytes (compressed); // write the now uncompressed content

			return decompressed;
		}
	}

}

class Replacement {
	public var iname:String, oname:String;
	public function Replacement (i:String, o:String) { iname = i; oname = o; }
	public function get label ():String { return iname + " => " + oname; }
}

import flash.utils.ByteArray;
import flash.utils.getTimer;
import flash.utils.setTimeout;
class Replacer {
	private var bytes:ByteArray;
	private var tree:Object;
	private var progress:Function;
	private var over:Function;
	public function Replacer (what:Array, where:ByteArray, progress:Function, over:Function) {
		this.bytes = where;
		this.progress = progress;
		this.over = over;
		
		// build the tree
		tree = {};
		for (var i:int = 0; i < what.length; i++) {
			var r:Replacement = what [i];
			var o:Object = tree;
			for (var j:int = 0; j < r.iname.length; j++) {
				var cj:int = r.iname.charCodeAt (j);
				if (o [cj] == null) {
					o [cj] = {};
				}
				o = o [cj];
			}
			o ["oname"] = r.oname;
		}
		
		// release the kraken
		setTimeout (replace, 1, 0);
	}

	private function replace (p:int):void {
		var t:int = getTimer ();
		while (getTimer () - t < 100) {
			p = replaceAt (p);
			if (p < 0) return;
		}
		progress (p / bytes.length); setTimeout (replace, 1, p);
	}
	
	private function replaceAt (p:uint):int {
		var n:int = bytes.length;
		if (p >= n) {
			// we're done
			over (); return -1;
		}
		
		var o:Object = tree, oname:String = "";
		for (var i:int = p; i < n; i++) {
			o = o [bytes [i]];
			if (o == null) break; // no matches at this position - break out
			var s:String = o.oname; if (s != null) oname = s; // yay! we have the match
		}
		// replace whatever we have to
		for (i = 0, n = oname.length; i < n; i++) {
			bytes [p + i] = oname.charCodeAt (i);
		}
		
		return p + 1 + n;
	}
}