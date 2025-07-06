package cn.bugstack.xfg.dev.tech.trigger;

import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.RequestMapping;
import org.springframework.web.bind.annotation.RestController;

import java.io.File;
import java.io.IOException;
import java.lang.management.ManagementFactory;
import java.text.SimpleDateFormat;
import java.util.Date;
import java.util.HashMap;
import java.util.Map;

/**
 * Jmap Dump 控制器
 * @author fuzhengwei
 */
@RestController
@RequestMapping("/api/jmap")
public class JmapDumpController {

    // 使用相对路径，基于项目根目录
    private static final String DUMP_DIR = "docs/dump";

    /**
     * 获取绝对路径的dump目录
     */
    private String getDumpDirectory() {
        // 获取项目根目录
        String userDir = System.getProperty("user.dir");
        // 如果当前目录是xfg-dev-tech-app，则需要回到上级目录
        if (userDir.endsWith("xfg-dev-tech-app")) {
            userDir = new File(userDir).getParent();
        }
        return userDir + File.separator + DUMP_DIR;
    }

    /**
     * 生成堆转储文件
     */
    @GetMapping("/dump")
    public Map<String, Object> generateHeapDump() {
        Map<String, Object> result = new HashMap<>();
        
        try {
            // 获取dump目录的绝对路径
            String dumpDir = getDumpDirectory();
            
            // 确保目录存在
            File dir = new File(dumpDir);
            if (!dir.exists()) {
                dir.mkdirs();
            }
            
            // 获取当前进程的PID
            String pid = ManagementFactory.getRuntimeMXBean().getName().split("@")[0];
            
            // 生成文件名（包含时间戳）
            SimpleDateFormat sdf = new SimpleDateFormat("yyyyMMdd_HHmmss");
            String timestamp = sdf.format(new Date());
            String fileName = "heap_dump_" + timestamp + ".hprof";
            String filePath = dumpDir + File.separator + fileName;
            
            // 执行jmap命令生成堆转储
            String command = "jmap -dump:format=b,file=" + filePath + " " + pid;
            Process process = Runtime.getRuntime().exec(command);
            int exitCode = process.waitFor();
            
            if (exitCode == 0) {
                result.put("status", "success");
                result.put("message", "堆转储文件生成成功");
                result.put("filePath", filePath);
                result.put("fileName", fileName);
            } else {
                result.put("status", "error");
                result.put("message", "堆转储文件生成失败");
                result.put("exitCode", exitCode);
            }
            
        } catch (IOException | InterruptedException e) {
            result.put("status", "error");
            result.put("message", "生成堆转储文件时发生异常: " + e.getMessage());
        }
        
        result.put("timestamp", System.currentTimeMillis());
        return result;
    }

    /**
     * 生成内存使用情况文本文件
     */
    @GetMapping("/memory-info")
    public Map<String, Object> generateMemoryInfo() {
        Map<String, Object> result = new HashMap<>();
        
        try {
            // 获取dump目录的绝对路径
            String dumpDir = getDumpDirectory();
            
            // 确保目录存在
            File dir = new File(dumpDir);
            if (!dir.exists()) {
                dir.mkdirs();
            }
            
            // 获取当前进程的PID
            String pid = ManagementFactory.getRuntimeMXBean().getName().split("@")[0];
            
            // 生成文件名
            SimpleDateFormat sdf = new SimpleDateFormat("yyyyMMdd_HHmmss");
            String timestamp = sdf.format(new Date());
            String fileName = "memory_info_" + timestamp + ".txt";
            String filePath = dumpDir + File.separator + fileName;
            
            // 执行jmap命令生成内存信息
            String command = "jmap -histo " + pid + " > " + filePath;
            Process process = Runtime.getRuntime().exec(new String[]{"/bin/sh", "-c", command});
            int exitCode = process.waitFor();
            
            if (exitCode == 0) {
                result.put("status", "success");
                result.put("message", "内存信息文件生成成功");
                result.put("filePath", filePath);
                result.put("fileName", fileName);
            } else {
                result.put("status", "error");
                result.put("message", "内存信息文件生成失败");
                result.put("exitCode", exitCode);
            }
            
        } catch (IOException | InterruptedException e) {
            result.put("status", "error");
            result.put("message", "生成内存信息文件时发生异常: " + e.getMessage());
        }
        
        result.put("timestamp", System.currentTimeMillis());
        return result;
    }

    /**
     * 获取当前进程信息
     */
    @GetMapping("/process-info")
    public Map<String, Object> getProcessInfo() {
        Map<String, Object> result = new HashMap<>();
        
        String pid = ManagementFactory.getRuntimeMXBean().getName().split("@")[0];
        String jvmName = ManagementFactory.getRuntimeMXBean().getVmName();
        String jvmVersion = ManagementFactory.getRuntimeMXBean().getVmVersion();
        
        result.put("status", "success");
        result.put("pid", pid);
        result.put("jvmName", jvmName);
        result.put("jvmVersion", jvmVersion);
        result.put("dumpDirectory", getDumpDirectory());
        result.put("timestamp", System.currentTimeMillis());
        
        return result;
    }

}