package  {
	import flash.events.Event;
	import flash.net.FileFilter;
	import flash.net.FileReference;

	public class FileLoader {
		public var onComplete:Function;
		public function FileLoader (onComplete:Function = null) {
			this.onComplete = onComplete;
			this.file = new FileReference;
			this.file.addEventListener (Event.CANCEL, onFileSelectionCancelled);
			this.file.addEventListener (Event.SELECT, onFileSelected);
			this.file.addEventListener (Event.COMPLETE, onFileLoaded);
			this.file.browse ([ new FileFilter ("SWF files", "*.swf") ]);
		}
		private var file:FileReference;
		private function onFileSelectionCancelled (e:Event):void { if (onComplete != null) onComplete (null); }
		private function onFileSelected (e:Event):void { file.load (); }
		private function onFileLoaded (e:Event):void { if (onComplete != null) onComplete (file.data); }
	}
}