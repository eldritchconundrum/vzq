
package vzq
package object utils {

  // C#-style Disposable, but better (structural interface, val block parameter)
  //usage:
  //  using(getWaveData()) { wave: WaveData =>
  //    VzqAL.registerWaveData(this.glId, wave)
  //  }
  // bugs: emacs indentation does not understand this.
  // use double {} to get it right: "using(getWaveData()) { wave: WaveData => { ... } }"
  type Disposable = { def dispose(): Unit }
  def using[T <% Disposable](resource: T)(block: T => Unit) {
    try {
      block(resource)
    }
    finally {
      resource.dispose
    }
  }


  // ruby-style formatting operator
  class RichString(str: String) {
    def %(args : Any*): String = str.format(args : _*)
  }
  implicit def stringToRichString(str: String) = new RichString(str)

  object Utils {
    // java doesn't even have this in std lib
    def readAllText(filename: String): Option[String] = {
      import java.io._
      import scala.collection.mutable._
      val file = new File(filename)
      if (!file.exists() || !file.canRead()) {
	return None
      }
      val reader = new BufferedReader(new InputStreamReader(new FileInputStream(filename), "UTF-8"))
      val stringBuilder = new StringBuilder
      val buffer = new Array[Char](1024)
      var read = 0
      while (read != -1) {
	read = reader.read(buffer)
	if (read > 0) {
	  stringBuilder.append(new String(buffer, 0, read))
	}
      }
      reader.close
      return Some(stringBuilder.toString)
    }
  }


  // readable if-expr
  class RichBoolean(b: Boolean) {
    def ?[T](pair: (T, T)) = if (b) pair._1 else pair._2
  }
  implicit def booleanToRichBoolean(b: Boolean) = new RichBoolean(b)
}
