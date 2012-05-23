package vzq.engine;
import java.util.*;
import java.nio.IntBuffer;

final class JavaRectCollisionDetectorImpl2
{
    // I replaced the Rectangle class by four int16 in an int64

    // and it's full of bugs and slower.  FIXME

    static Hashtable<Object, Long> rectanglesByObj = new Hashtable<Object, Long>(); // suppress boxing by specializing Hashtable? try HashMap?
    public static void setRect(Object obj, int x1, int y1, int w, int h)
    {
	rectanglesByObj.put(obj, create_rect((short)x1, (short)y1, (short)w, (short)h));
    }
    public static void clear()
    {
	rectanglesByObj.clear();
    }
    static Vector<Object> resultVectorCache = new Vector<Object>();
    public static Vector<Object> detect(Object[] list1, Object[] list2)
    {
	long[] r1List = new long[list1.length];
	for (int i = 0; i < r1List.length; ++i) if (rectanglesByObj.get(list1[i]) != null)
	    r1List[i] = rectanglesByObj.get(list1[i]);
	long[] r2List = new long[list2.length];
	for (int i = 0; i < r2List.length; ++i) if (rectanglesByObj.get(list2[i]) != null)
	    r2List[i] = rectanglesByObj.get(list2[i]);

	resultVectorCache.clear();
	Vector<Object> result = resultVectorCache;
	for (int i = 0; i < list1.length; ++i)
	    {
		Object e1 = list1[i];
		long r1 = r1List[i];
		//if (r1 != null)
		    for (int j = 0; j < list2.length; ++j)
			{
			    long r2 = r2List[j];
			    //if (r2 != null)
				if (intersects(r1, r2))
				    {
					result.add(e1);
					Object e2 = list2[j];
					result.add(e2);
				    }
			}
	    }
	return result;
    }
    static long create_rect(short x, short y, short w, short h) { return (long)x | ((long)y << 16) | ((long)w << 32) | ((long)h << 48); }
    static short get_x(long v) { return (short)((v & 0x000000FF) >> 0); }
    static short get_y(long v) { return (short)((v & 0x0000FF00) >> 16); }
    static short get_width(long v) { return (short)((v & 0x00FF0000) >> 32); }
    static short get_height(long v) { return (short)((v & 0xFF000000) >> 48); }
    static boolean intersects(long r2, long r)
    {
	short tw = get_width(r2);
	short th = get_height(r2);
	short rw = get_width(r);
	short rh = get_height(r);
	if (rw <= 0 || rh <= 0 || tw <= 0 || th <= 0) {
	    return false;
	}
	short tx = get_x(r2);
	short ty = get_y(r2);
	short rx = get_x(r);
	short ry = get_y(r);
	rw += rx;
	rh += ry;
	tw += tx;
	th += ty;
	// overflow || intersect
	return ((rw < rx || rw > tx) &&
		(rh < ry || rh > ty) &&
		(tw < tx || tw > rx) &&
		(th < ty || th > ry));
    }
}
