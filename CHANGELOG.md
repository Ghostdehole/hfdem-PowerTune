# hfdem PowerTune 更新日志

## v2.4.2
- 监听方式从轮询改为 inotifyd 事件驱动，降低功耗、提升响应速度（方案来自 [旧夏](https://github.com/djt889)）
- 防原子替换机制：监听文件删除事件，自动重绑定 inode
- 状态持久化到 /dev/hfdem_last_mode，重启后不丢状态
- zram 智能检测：已是 zstd/zstdp 则跳过重置，避免开机内存抖动
- DDRQOS 改用 hw_max_freq/hw_min_freq 节点
- 安装时检测 Yuni Kernel 附加模块，冲突时自动取消安装

## v2.4.1
- 添加 zram 重置为 zstd 压缩算法，提高压缩率 30-50%
- init_zram 提前到 boot_complete 之前，开机即生效
- swappiness 改为 60，解决打开应用瞬时功耗高的问题

## v2.4.0
- 全面优化 CPU/总线/内存/GPU/手动 Boost

## v2.3.2
- 省电模式 mod_percent 从 80% 改为 100% 避免潜在卡顿
- README 同步更新

## v2.3.1
- 优化启动延迟和模式切换轮询间隔

## v2.3.0
- GPU 动态调频改为运行时读取频率表
- 刷入时可选开启

## v2.2.0
- 初始版本
- 基于 hfdem 内核及 schedhorizon 调度的功耗管理模块
