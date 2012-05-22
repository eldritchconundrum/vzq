package vzq.engine;
import java.awt.Rectangle;
import java.util.*;
import java.nio.IntBuffer;

final class JavaRectCollisionDetectorImpl
{
    static Hashtable<Object, Rectangle> rectanglesByObj = new Hashtable<Object, Rectangle>();
    public static void setRect(Object obj, int x1, int y1, int w, int h)
    {
	Rectangle r = rectanglesByObj.get(obj);
	if (r == null)
	    rectanglesByObj.put(obj, r = new Rectangle());
	r.setBounds(x1, y1, w, h);
    }
    public static void clear()
    {
	rectanglesByObj.clear();
    }
    static Vector<Object> resultVectorCache = new Vector<Object>();
    public static Vector<Object> detect(Object[] list1, Object[] list2)
    {
	Rectangle[] r1List = new Rectangle[list1.length];
	for (int i = 0; i < r1List.length; ++i)
	    r1List[i] = rectanglesByObj.get(list1[i]);
	Rectangle[] r2List = new Rectangle[list2.length];
	for (int i = 0; i < r2List.length; ++i)
	    r2List[i] = rectanglesByObj.get(list2[i]);

	resultVectorCache.clear();
	Vector<Object> result = resultVectorCache;
	for (int i = 0; i < list1.length; ++i)
	    {
		Object e1 = list1[i];
		Rectangle r1 = r1List[i];
		if (r1 != null)
		    for (int j = 0; j < list2.length; ++j)
			{
			    Rectangle r2 = r2List[j];
			    if (r2 != null)
				if (r1.intersects(r2))
				    {
					result.add(e1);
					Object e2 = list2[j];
					result.add(e2);
				    }
			}
	    }
	return result;
    }
}

