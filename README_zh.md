# 在 imagent 中验证 NSURLSession

用于 iPhone XS / iOS 16.2 / Dopamine rootless。编译为当前 arm64e ABI 的 dylib，由 ElleKit 根据进程过滤配置加载到 imagent。不是之前的 arm64 命令行程序，也不需要运行独立二进制。

将本包全部文件放到 GitHub 仓库根目录，包括 .github。Actions → Build imagent NSURLSession Test → Run workflow。成功后下载 vhx-imagent-test-rootless。

## 配置、安装和启动

1. 编辑 config.plist 的 BaseURL，替换成你的服务器地址，不带末尾斜杠；默认超时 5 秒、状态码 200（原常量仍待确认）。
2. 将配置上传为 /var/mobile/Library/Preferences/local.vhx.imagenttest.plist。配置不在 deb 中自动安装，避免触发示例地址请求。
3. 将 deb 上传到 /var/mobile，在 root 终端执行：

```bash
chmod 644 /var/mobile/Library/Preferences/local.vhx.imagenttest.plist
/var/jb/usr/bin/dpkg -i /var/mobile/vhx-imagent-test_1.0.0_iphoneos-arm64.deb
killall imagent
```

最后一条用于结束现有 imagent，让系统重新启动并加载 dylib；可能短暂中断消息服务。包安装过程不会自动重启进程。需保持 Dopamine 对 imagent 的 tweak 注入启用；若使用 Choicy 等工具禁用该进程注入，需先启用。

每次 imagent 启动时只发一次请求；不会定时循环，不修改原进程任何方法。修改配置后再次 killall imagent 触发新测试。

## 查看结果

```bash
cat /var/mobile/Library/Logs/VHXImagentTest.log
```

输出 RESULT、最终地址、HTTP 状态、正文预览、NSError 及其 userInfo、耗时。文件保存最新一次结果。如果 imagent 的沙盒拒绝配置读取，将记录“无可读配置”并不发请求；若拒绝日志文件写入，NSLog 仍输出 [VHXImagentTest]，需在设备系统日志中查看。缺少日志文件不等于请求失败或注入成功。

此测试使用 imagent 中的 NSURLSession.sharedSession，沿用宿主的网络策略、权限、缓存和 Cookie；不改宿主 ATS、不忽略 HTTPS 证书错误。原 _sharedSession 初始化未知，因此尚不能复现所有原始配置。

请求为基础地址直接追加 /vhx、GET、timeoutInterval、后台信号量等待 timeout+2 秒，等待超时取消。成功判定为无错误、状态码匹配、非空有效 UTF-8 正文 trim 后不区分大小写等于 ok。保留了无效 UTF-8 的 nil 检查，原伪代码的误判边界未复现。

## 结束测试

```bash
/var/jb/usr/bin/dpkg -r local.vhx.imagenttest
killall imagent
```

卸载并重启进程后不再加载测试 dylib。配置和日志保留，可自行删除。

## 验证范围

构建脚本语法、plist 和压缩包可在交付环境检查；这里没有 Xcode SDK，没有实际启动 GitHub 构建，也没有进行 imagent 真机验证。不能保证该包能解决此前签名/启动问题。系统进程注入的架构要求与独立 CLI 不同，此包针对 arm64e 系统进程构建。
