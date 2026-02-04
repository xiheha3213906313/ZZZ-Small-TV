# 绝区零登录界面电视机纹理生成工具

将输入视频自动转换为可直接加载的绝区零登录界面电视机纹理与完整 mod 包。

## 功能特性

- 全自动处理流程：从视频输入到最终 mod 文件生成
- 支持多种输入格式：.mp4、.avi、.mov、.wmv、.flv、.gif
- 智能帧率计算：自动分析帧率并使用众数作为最终帧率
- 高质量纹理转换：BC7 压缩格式，SRGB 颜色空间
- 完整 mod 包生成：输出 High 与 Low_Mid 配置
- 预览图自动生成：生成 preview.jpg 供 JASMmod 管理器预览
- 自适应布局：根据视频数量生成拼图（最多 9 张）

## 产物结构
```
Output/MMDDHHMM_Login TV v4/
├── Images/                # DDS 纹理文件目录
│   ├── frame_0000.dds     # 第 1 帧纹理
│   ├── frame_0001.dds     # 第 2 帧纹理
│   └── ...                # 更多帧纹理
├── Glow.jpg              # 发光效果图片
├── [High] LoginTV_v4.ini  # High 配置文件
├── [Low_Mid] LoginTV_v4.ini.backup  # Low_Mid 配置文件
└── preview.jpg           # 预览图（用于 JASMmod 管理器）
```

## 快速开始

### 环境要求
- Windows 10 及以上版本
- PowerShell 可用
- 无需额外安装 ffmpeg 或 texconv（已包含在 Work/Tools 中）

### 使用步骤
1. 将视频文件放入 `Input` 目录
2. 运行脚本：

```powershell
.\extract_frames.ps1
```

3. 在 `Output/MMDDHHMM_Login TV v4/` 查看输出，`MMDDHHMM` 为当前日期时间

## 工作流程

1. 初始化：清空临时目录
2. 视频裁剪：裁剪为 4:3（960×720）
3. 镜像处理：垂直镜像
4. 帧率计算：取众数作为最终帧率
5. 帧提取：输出帧序列
6. DDS 转换：PNG 转 DDS
7. 配置文件生成：输出 High 与 Low_Mid 配置
8. 预览图生成：生成拼图 preview.jpg
9. 清理临时文件

## 目录结构

```
Conversion/
├── Input/                 # 输入视频目录（需手动创建）
├── Output/                # 输出 mod 目录（自动生成）
├── Work/                  # 工作目录
│   ├── Crop video/        # 裁剪后视频目录（临时）
│   ├── Mirrored video/    # 镜像处理后视频目录（临时）
│   ├── Pending frame/     # 提取的帧序列目录（临时）
│   ├── Cover image/       # 封面图片目录（临时）
│   ├── Tools/             # 工具目录
│   │   ├── ffmpeg-master-latest-win64-gpl-shared/  # ffmpeg 工具
│   │   └── texconv.exe    # DDS 转换工具
│   ├── FPS.txt            # 帧率信息（临时）
│   ├── Glow.jpg           # 发光效果图片
│   └── white.png          # 白色占位图（自动生成）
├── extract_frames.ps1     # 主脚本
└── README.md              # 本说明文件
```

## 注意事项

1. 建议输入 16:9 或 4:3 比例视频以获得最佳效果
2. 预览图最多支持 9 个输入视频
3. 帧序列最多支持 9999 帧（4 位数字）
4. 请勿移动或删除 `Work/` 目录下的任何文件
5. 若脚本无法运行，请以管理员身份启动 PowerShell

## 故障排除

### 脚本无法运行
- 确保 PowerShell 允许执行脚本
- 以管理员身份运行 PowerShell

### 没有生成输出
- 确认 `Input` 目录存在可用视频
- 检查执行过程中是否有报错

### 预览图未生成
- 确认 `Input` 目录存在视频
- 确认 `Work/white.png` 存在

### 常见错误
- `Error: No video files found in Input folder!`
  - 将视频文件放入 `Input` 目录后重新运行脚本

## 许可证

本工具使用的 ffmpeg 工具遵循 LGPL 许可证，texconv 工具遵循 MIT 许可证。

## 更新日志

### v1.0
- 初始版本
- 支持多种输入格式
- 自动生成完整 mod 包
- 预览图生成功能
- 智能帧率计算
