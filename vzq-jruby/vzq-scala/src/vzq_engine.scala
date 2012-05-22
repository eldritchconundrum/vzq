package vzq.engine
{
  import vzq.utils._

  class PlaceHolder { } // used by main.rb
  object TmpTest {
    def foo {
    }
  }

  // V2I = Vector 2D Immutable
  case class V2I(x: Double, y: Double) { // case classes get structural equality for free
    def w = x
    def h = y
    def width = x
    def height = y
    override def toString = "(%s,%s)" % (x, y)
    def sqr_dist = x*x + y*y
    def +(p: V2I) = V2I(x + p.x, y + p.y)
    def -(p: V2I) = V2I(x - p.x, y - p.y)
    def *(n: Double) = V2I(x*n, y*n)
    def /(n: Double) = V2I(x/n, y/n)
    def plus(p: V2I) = this + p
    def minus(p: V2I) = this - p
    def mult(n: Double) = this * n
    def div(n: Double) = this / n
    def norm = math.sqrt(x*x + y*y)
    def distance(p: V2I) = V2I(this.x - p.x, this.y - p.y).norm
    def normalized = this * (1.0 / norm)
  }

  import java.nio.IntBuffer
  import java.nio.ByteBuffer

  import java.awt.image.BufferedImage
  import scala.collection.mutable.HashMap

  import java.awt.Rectangle
  import scala.collection.mutable.HashMap
  import java.util.Vector
  import scala.reflect.BeanProperty

  class DoubleRectangle {
    @BeanProperty var x: Double = 0
    @BeanProperty var y: Double = 0
    @BeanProperty var width: Double = 0
    @BeanProperty var height: Double = 0
    def setBounds(x: Double, y: Double, width: Double, height: Double) {
      this.x = x;
      this.y = y;
      this.width = width;
      this.height = height;
    }
    def intersects(other: DoubleRectangle): Boolean = {
      if ((y > (other.y + other.height)) || ((y + height) < other.y))
        return false
      if ((x > (other.x + other.width)) || ((x + width) < other.x))
        return false
      return true
    }
  }

  class EntityBase { // TODO
    @BeanProperty var x: Double = _
    @BeanProperty var y: Double = _
    @BeanProperty var w: Double = _
    @BeanProperty var h: Double = _
    var collisionBox = new DoubleRectangle
    def update_collision_box() {
      collisionBox.setBounds(x+w*0.1, y+h*0.1, w*0.8, h*0.8)
    }
  }
  class ScalaCollisionDetector {
  }

  class EntitiesSet {
    val entityList = new Vector[EntityBase]
  }

  class ScalaRectCollisionDetectorImpl {

    class HashMap2[K, V] extends HashMap[K, Option[V]] {
      override def default(key: K) = null
    }

    val rectanglesByObj: HashMap2[Any, Rectangle] = new HashMap2[Any, Rectangle]

    def setRect(obj: Any, x1: Int, y1: Int, w: Int, h: Int) =
      rectanglesByObj.getOrElseUpdate(obj, new Some(new Rectangle)).get.setBounds(x1, y1, w, h)

    def clear() {
      rectanglesByObj.clear()
    }

    private val resultVectorCache = new Vector[Any]

    def detect(list1: Array[Any], list2: Array[Any]) = {
      val r1List = list1.map(rectanglesByObj)
      val r2List = list2.map(rectanglesByObj)
      resultVectorCache.clear()
      val result = resultVectorCache
      for (i <- 0 to list1.size - 1) {
	val (e1, r1) = (list1(i), r1List(i));
	for (rect1 <- r1; j <- 0 to list2.size - 1) {
	  val r2 = r2List(j)
	  for (rect2 <- r2) {
	    if (rect1 intersects rect2) {
	      result add e1
	      val e2 = list2(j)
	      result add e2
	    }
	  }
	}
      }
      result
    }
  }

  class FastDrawer(name: String) {
    def draw() : BufferedImage = {
      if (name == "mandel")
	return Drawer.drawMandelbrot(800, 600)
      if (name == "noise")
	return Drawer.drawNoise(32, 32)
      if (name == "perlin")
	return Drawer.drawPerlinNoise(32, 32, 5)
      throw new Exception("generated texture name: " + name)
    }
    def cache_key = name
  }

  import scala.math
  import scala.util.Random

  object PerlinNoise {
    val rnd = new Random
    val p = {
      val p = new Array[Int](512)
      for (i <- 0 to 255)
	p(i) = i
      for (i <- 256 to 2) {
	val idx = rnd.nextInt(i)
	val tmp = p(idx)
	p(idx) = p(i-1)
	p(i-1) = tmp
      }
      for (i <- 256 to 511)
	p(i) = p(i - 256)
      p
    }
    def fade(t: Double) = t * t * t * (t * (t * 6 - 15) + 10)
    def lerp(t: Double, a: Double, b: Double) = a + t * (b - a)
    def grad(hash: Int, x: Double, y: Double) = {
      val h = hash & 2
      if ((h & 1) == 0)
	if (h < 2) x else y
      else
	if (h < 2) -x else -y
    }
    // x and y loops modulo 255
    // return value is in [-1, 1] ?
    def noise(xx: Double, yy: Double) = {
      val (xi, yi) = (xx.toInt & 255, yy.toInt & 255); // ints in 0..255
      val (x, y) = (xx - xx.toInt, yy - yy.toInt); // floats in 0..1
      val (u, v) = (fade(x), fade(y)); // floats in 0..1
      // corners of the square
      val (aa, ba) = (p(xi) + yi, p(xi + 1) + yi);
      val (ab, bb) = (aa + 1, ba + 1);
      lerp(v, lerp(u, grad(aa, x  , y),
		      grad(ba, x-1, y)),
	      lerp(u, grad(ab, x  , y-1),
		      grad(bb, x-1, y-1)))
    }
  }

  object Drawer {
    import java.awt.Graphics2D
    import java.awt.Graphics
    import java.awt.Color

    def drawPerlinNoise(xmax: Int, ymax: Int, scale: Double) = { // TODO: faire marcher
      val image = new BufferedImage(xmax, ymax, BufferedImage.TYPE_INT_ARGB)
      val g: Graphics = image.createGraphics

      val colors = new HashMap[Double, Color]
      def getColor(f: Double) = colors.getOrElseUpdate(f, new Color((0.3 * f).toInt, (0.5 * f).toInt, (0.9 * f).toInt, 255)) // f in 0..255

      for (i <- 0 to xmax - 1; j <- 0 to ymax - 1) {
	val c = (PerlinNoise.noise(i * scale, j * scale) + 1) / 2.0
	g.setColor(getColor(c * 255)) // RGBA
	g.drawLine(i, j, i, j) // I found no drawPoint
      }
      image
    }

    def drawNoise(xmax: Int, ymax: Int) = {
      val image = new BufferedImage(xmax, ymax, BufferedImage.TYPE_INT_ARGB)
      val g: Graphics = image.createGraphics

      val colors = new HashMap[Double, Color]
      def getColor(f: Double) = colors.getOrElseUpdate(f, new Color((0.3 * f).toInt, (0.5 * f).toInt, (0.9 * f).toInt, 255))
      val rnd = new Random

      val a = new Array[Double](xmax * ymax)
      val b = new Array[Double](xmax * ymax)
      def t(i: Int, j: Int) = ((i + xmax) % xmax) * ymax + ((j + ymax) % ymax)
      for (i <- 0 to xmax - 1; j <- 0 to ymax - 1)
	a(t(i, j)) = rnd.nextDouble
      for (i <- 0 to xmax - 1; j <- 0 to ymax - 1)
	b(t(i, j)) = a(t(i, j)) / 4.0 +
	  (a(t(i+1, j)) + a(t(i-1, j)) + a(t(i, j+1)) + a(t(i, j-1))) / 8.0 +
	  (a(t(i+1, j+1)) + a(t(i+1, j-1)) + a(t(i-1, j+1)) + a(t(i-1, j-1))) / 16.0
      for (i <- 0 to xmax - 1; j <- 0 to ymax - 1) {
	val c = b(i * ymax + j)
	g.setColor(getColor(c * 255)) // RGBA
	g.drawLine(i, j, i, j) // I found no drawPoint
      }
      image
    }

    def drawMandelbrot(xmax: Int = 512, ymax: Int = 512): BufferedImage = {
      val image = new BufferedImage(xmax, ymax, BufferedImage.TYPE_INT_ARGB)
      val g: Graphics = image.createGraphics

      // mandel
      Console.println("mandel texture gen started")

      // color looping
      def getPointOnCircle(radian: Double) = V2I(math.cos(radian), math.sin(radian))
      //val rgbPoints = (0 to 2) map (n => getPointOnCircle(n * 2 * math.Pi / 3))
      def getColor(n: Double): Color = { // 0 to 1 does a full color loop
	return new Color(Color.HSBtoRGB(n.toFloat,1f,1f))
	//val radian = n * 2 * math.Pi
	//val point = V2I(math.cos(radian), math.sin(radian))
	//val rgb = rgbPoints map (p => (p.distance(point) / 2 * 255).toInt)
	//new Color(rgb(0), rgb(1), rgb(2), 255)
      }
      def getNextIter(a: Double, b: Double, za: Double, zb: Double) = (za * za - zb * zb + a, 2 * za * zb + b);
      import scala.annotation.tailrec
      @tailrec def mandelbrot(a: Double, b: Double, iterCutoff: Int = 50, escapeRadius: Double = 4,
			      za: Double = 0, zb: Double = 0, iter: Int = 0): (Int, V2I) = {
	if (iter > iterCutoff) return (-1, null)
	if (za * za + zb * zb > escapeRadius) return (iter, V2I(za, zb))
	val z = getNextIter(a, b, za, zb)
	mandelbrot(a, b, iterCutoff, escapeRadius, z._1, z._2, iter + 1)
      }
      //val (xmi, xma, ymi, yma) = (-2f, 1f, -1.2f, 1.2f);
      val (xmi, xma, ymi, yma) = (-0.76f, -0.74f, 0.14f, 0.16f)
	for (i <- 0 to xmax - 1; j <- 0 to ymax - 1) {
	  val x = xmi + ((xma - xmi) * i) / xmax
	  val y = ymi + ((yma - ymi) * j) / ymax
	  val (iter, z) = mandelbrot(x, y);

	  // basic coloring (based on iteration count which is an int)
	  val col = if (iter == -1) new Color(0, 0, 0, 255) else getColor(iter / 30.0) // 30 iterations = full color circle

	  // a continuous (smooth) coloring based on non-int: http://linas.org/art-gallery/escape/escape.html
	  val smoothColor = if (iter == -1) new Color(0, 0, 0, 255) else {
	    var zz = (z.x, z.y);
	    for (i <- 1 to 2)
	      zz = getNextIter(x, y, zz._1, zz._2)
	    val modulus = V2I(zz._1, zz._2).norm
	    val mu: Double = iter - math.log(math.log(modulus)) / math.log(2)
	    getColor(mu / 5)
	  }

	  g.setColor(smoothColor)
	  g.drawLine(i, j, i, j) // I found no drawPoint
	}
      Console.println("mandel texture gen finished")

      // debug color circle
      var i = 0.0
      while (i < 1) {
	val smoothColor2 = getColor(i)
	val smoothColor = new Color(smoothColor2.getRed(), smoothColor2.getGreen(), smoothColor2.getBlue(), 128)
	//Log.info("%s %s %s" % (smoothColor.getRed(), smoothColor.getGreen(), smoothColor.getBlue()))
	g.setColor(smoothColor)
	val p = getPointOnCircle(i * 2 * math.Pi)
	g.drawLine(xmax/2, ymax/2, xmax/2+(p.x*256).toInt, ymax/2+(p.y*256).toInt)
	i += 0.001
      }

      image
    }
  }

}
