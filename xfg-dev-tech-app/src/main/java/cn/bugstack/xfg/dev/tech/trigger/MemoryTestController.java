package cn.bugstack.xfg.dev.tech.trigger;

import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.RequestMapping;
import org.springframework.web.bind.annotation.RestController;

import java.util.ArrayList;
import java.util.HashMap;
import java.util.List;
import java.util.Map;
import java.util.concurrent.ConcurrentHashMap;

/**
 * 内存测试控制器 - 用于VisualVM测试
 * @author fuzhengwei
 */
@RestController
@RequestMapping("/api/memory")
public class MemoryTestController {

    // 用于存储大对象的静态变量，模拟内存泄漏
    private static final Map<String, Object> MEMORY_CACHE = new ConcurrentHashMap<>();
    private static final List<byte[]> BIG_OBJECTS = new ArrayList<>();

    /**
     * 普通接口 - 正常的HTTP响应
     */
    @GetMapping("/normal")
    public Map<String, Object> normalApi() {
        Map<String, Object> result = new HashMap<>();
        result.put("status", "success");
        result.put("message", "这是一个普通的接口响应");
        result.put("timestamp", System.currentTimeMillis());
        result.put("data", generateSmallData());
        return result;
    }

    /**
     * 大对象接口 - 创建大量对象占用内存
     */
    @GetMapping("/big-object")
    public Map<String, Object> bigObjectApi() {
        // 创建大对象（10MB的字节数组）
        byte[] bigData = new byte[10 * 1024 * 1024]; // 10MB
        for (int i = 0; i < bigData.length; i++) {
            bigData[i] = (byte) (i % 256);
        }
        
        // 将大对象存储到静态集合中，模拟内存泄漏
        BIG_OBJECTS.add(bigData);
        
        Map<String, Object> result = new HashMap<>();
        result.put("status", "success");
        result.put("message", "创建了一个大对象（10MB）");
        result.put("timestamp", System.currentTimeMillis());
        result.put("bigObjectsCount", BIG_OBJECTS.size());
        result.put("totalMemoryUsed", BIG_OBJECTS.size() * 10 + "MB");
        
        return result;
    }

    /**
     * 内存泄漏接口 - 持续创建对象并缓存
     */
    @GetMapping("/memory-leak")
    public Map<String, Object> memoryLeakApi() {
        String key = "data_" + System.currentTimeMillis();
        
        // 创建大量小对象并缓存
        List<String> dataList = new ArrayList<>();
        for (int i = 0; i < 10000; i++) {
            dataList.add("这是第" + i + "个数据对象，包含一些文本内容用于占用内存空间");
        }
        
        MEMORY_CACHE.put(key, dataList);
        
        Map<String, Object> result = new HashMap<>();
        result.put("status", "success");
        result.put("message", "创建了10000个小对象并缓存");
        result.put("timestamp", System.currentTimeMillis());
        result.put("cacheSize", MEMORY_CACHE.size());
        result.put("cacheKey", key);
        
        return result;
    }

    /**
     * 超大对象接口 - 创建超大对象
     */
    @GetMapping("/huge-object")
    public Map<String, Object> hugeObjectApi() {
        // 创建超大对象（100MB的字节数组）
        byte[] hugeData = new byte[100 * 1024 * 1024]; // 100MB
        
        // 填充数据
        for (int i = 0; i < hugeData.length; i++) {
            hugeData[i] = (byte) (Math.random() * 256);
        }
        
        BIG_OBJECTS.add(hugeData);
        
        Map<String, Object> result = new HashMap<>();
        result.put("status", "success");
        result.put("message", "创建了一个超大对象（100MB）");
        result.put("timestamp", System.currentTimeMillis());
        result.put("bigObjectsCount", BIG_OBJECTS.size());
        
        return result;
    }

    /**
     * 清理缓存接口
     */
    @GetMapping("/clear-cache")
    public Map<String, Object> clearCacheApi() {
        int cacheSize = MEMORY_CACHE.size();
        int bigObjectsSize = BIG_OBJECTS.size();
        
        MEMORY_CACHE.clear();
        BIG_OBJECTS.clear();
        
        // 强制垃圾回收
        System.gc();
        
        Map<String, Object> result = new HashMap<>();
        result.put("status", "success");
        result.put("message", "已清理所有缓存");
        result.put("timestamp", System.currentTimeMillis());
        result.put("clearedCacheSize", cacheSize);
        result.put("clearedBigObjectsSize", bigObjectsSize);
        
        return result;
    }

    /**
     * 获取内存状态接口
     */
    @GetMapping("/status")
    public Map<String, Object> getMemoryStatus() {
        Runtime runtime = Runtime.getRuntime();
        long totalMemory = runtime.totalMemory();
        long freeMemory = runtime.freeMemory();
        long usedMemory = totalMemory - freeMemory;
        long maxMemory = runtime.maxMemory();
        
        Map<String, Object> result = new HashMap<>();
        result.put("status", "success");
        result.put("timestamp", System.currentTimeMillis());
        result.put("totalMemory", formatBytes(totalMemory));
        result.put("usedMemory", formatBytes(usedMemory));
        result.put("freeMemory", formatBytes(freeMemory));
        result.put("maxMemory", formatBytes(maxMemory));
        result.put("cacheSize", MEMORY_CACHE.size());
        result.put("bigObjectsCount", BIG_OBJECTS.size());
        
        return result;
    }

    /**
     * 生成小数据
     */
    private List<Map<String, Object>> generateSmallData() {
        List<Map<String, Object>> dataList = new ArrayList<>();
        for (int i = 0; i < 10; i++) {
            Map<String, Object> item = new HashMap<>();
            item.put("id", i);
            item.put("name", "数据项_" + i);
            item.put("value", Math.random() * 100);
            dataList.add(item);
        }
        return dataList;
    }

    /**
     * 格式化字节数
     */
    private String formatBytes(long bytes) {
        if (bytes < 1024) {
            return bytes + " B";
        } else if (bytes < 1024 * 1024) {
            return String.format("%.2f KB", bytes / 1024.0);
        } else if (bytes < 1024 * 1024 * 1024) {
            return String.format("%.2f MB", bytes / (1024.0 * 1024.0));
        } else {
            return String.format("%.2f GB", bytes / (1024.0 * 1024.0 * 1024.0));
        }
    }

}