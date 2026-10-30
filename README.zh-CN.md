# 小米 AX3000T（RD03v2）OpenWrt 固件

> **本仓库是 [ADCDS/openwrt-xiaomi-ax3000t-rd03v2](https://github.com/ADCDS/openwrt-xiaomi-ax3000t-rd03v2) 的个人 fork**，
> 在上游 `main` 之上追加了若干改动（逐条说明见文末 [「本 fork 的修改」](#本-fork-的修改)）：
>
> - 把上游基底 bump 到 `kuncy7/openwrt-nss-edma` 的 `ipq50xx-2026.10.28`（两个 lock、树补丁、feeds 一起钉住）
> - **已合入上游 v2.1.0/v2.1.1 的修复**：REO 片段环卡死（#53）、host 模式路由 UDP 触发固件 assert（#52）、
>   apsta 重启后客户端假关联（#54）、host 模式片段 double-free（#55）、NSS 卸载下 watchdog 改为重启而不是 reload、
>   station 默认留在 NSS 通路并可用 `wifi_offload_sta=0` 逃生（#48）、CE RX 片段缓存/加锁补丁，
>   以及 v1.x 配置迁移只摘 `qca-nss-ecm` 并把动作写入 `/etc/rd03v2-migrate.log`（#51）
> - 镜像内置自定义包单：中文界面（zh-CN）、Argon v3.1.1 主题（**构建期从 release tarball 现拼，仓库不含第三方源码**）、常用工具、zram-swap
> - 首启默认值：双频 AP 默认开启（WPA2/PSK）、WISP/中继客户端默认走 NSS 卸载（tree patch 0008 的默认；
>   需要 host 通路时设 `nss.general.wifi_offload_sta=0`）、首启标记写在 `/etc/config/rd03v2`
> - 用自己的 EC 密钥签名镜像（`keys/public-key.pem`），软件包仓库由本 fork 发布
> - `build.sh` 全程校验（`tools/verify-v2.sh`），并拒绝覆盖上游文件
>
> 英文版：**[README.md](README.md)**（上游 v2.1.1 原文 + 本 fork 的头部说明）

面向小米 AX3000T **RD03v2 硬件版本**的 OpenWrt：高通 IPQ5018 + QCN6122 5 GHz 射频，256 MB 内存、128 MB NAND。
可永久安装到 NAND，支持全部 4 个以太网口、双频 Wi-Fi、状态指示灯、NFC 标签和 LuCI，路由与 Wi-Fi 均启用高通 NSS 硬件加速。

**仅限 RD03v2。** MediaTek 的 RD03/RD23 版本硬件不同、固件不兼容，刷机前请先确认硬件版本。

镜像基于 [kuncy7/openwrt-nss-edma](https://github.com/kuncy7/openwrt-nss-edma) 的固定发布（内核 6.18，NSS 跑在
mainline stmmac 上），叠加[本移植层的新增内容](docs/what-this-port-adds.md)，用户态软件来自 OpenWrt 官方 snapshot 软件源。
发布在 [releases 页](https://github.com/ADCDS/openwrt-xiaomi-ax3000t-rd03v2/releases)；真机验证了什么、没验证什么，见
[VALIDATION.md](VALIDATION.md)。

## 安装

- **从原厂固件安装：** 运行 [xiaomi-openwrt-install](https://github.com/ADCDS/xiaomi-openwrt-install) 里的
  `python3 install.py`。它通过网线或 Wi-Fi 安装最新发布，**不拆机、不接 UART**，会校验板型与 NAND，并校验写入的镜像。
  其 `--wifi-ssid`、`--wifi-key`、`--wifi-country`、`--root-password` 选项用于配置装好的系统。
- **从已安装的 OpenWrt 升级（含 v1.x）：** 启动该发布的 RAM 安装器，在安装器里执行 `sysupgrade`，**绝不要就地升级**
  （见[不接 UART 重刷](docs/no-uart-reflash.md)）。保留配置可把 v1.x 的配置带过来（见[从 v1.x 升级](docs/upgrading-from-v1.md)）。
- **回原厂：** 用 xiaomi-openwrt-install 里的 `revert.py`。

## 装好之后

- 用网线接 LAN 口，浏览器打开 **http://192.168.1.1** 进 LuCI，设置 root 口令。
  除非安装器给了 Wi-Fi 参数，否则 Wi-Fi 默认关闭，需要自己配置。
- **每次刷机（包括升级）都要从 RAM 安装器执行。** 在 NAND 系统里直接 `sysupgrade` 会被拒绝。
- 装包：先 `apk update`，再 `apk add <包名>`。用户态来自 OpenWrt snapshot 源；内核模块（`kmod-*`）和 AmneziaWG 来自本移植层
  为每个发布签名过的仓库（见 [packages](docs/packages.md)）。`sysupgrade` 会保留配置但不保留后装的包，升级后需重装。
- 首次启动会清空 NFC 标签，因为标签上还留着原厂最后写入的 Wi-Fi 名和口令。想用碰一碰分享网络见 [NFC 标签](docs/nfc.md)。

## 已知问题

- **802.11s 组网需要 host Wi-Fi 模式**（`nss.general.wifi_offload='0'`）。开着 NSS Wi-Fi 卸载时，mesh 接口起不来，还会把它
  所在射频的 AP 一起带下线，直到接口被删除。v2.0.0 在有设备连接时会直接重启：请用 v2.0.1 或更新版本（#47）。
- **station（客户端）接口默认留在 NSS 通路**（#48，v2.1.0 起）：在更新的基座上实测可正常收发全尺寸帧；需要 host 通路时设
  `nss.general.wifi_offload_sta=0`（或 off/no/false/disabled），重启生效，`nss-status` 会提示。
- **v2.0.0–v2.0.2 上，host Wi-Fi 模式把路由 UDP 转发到 Wi-Fi 客户端可能触发固件 assert**（#52，QUIC/YouTube 几秒触发；
  v2.0.1/v2.0.2 加 station 后的 host 模式、或 `wifi_offload=0`）：本 fork 已合入 v2.1.0 的修复（ECM 9001 + ath11k 988 + mac80211 989）。
- **v2.0.0–v2.0.2 上，客户端发 802.11 分片约 42 小时可让该射频停止收包并持续泄漏内存**（#53，只有重启能恢复）：
  已合入 v2.1.0 的 990；host 模式修复后不再卡死，但会丢较多分片（上游注明）。
- **v2.1.0 上，Wi-Fi 固件恢复后客户端可能假关联约 30 秒**（#54，station 上行与 AP 同射频时约 1/3 概率）：已合入 v2.1.1 的 0012。
- **v2.1.1 之前，host 模式收分片时的小内存分配失败会 double free**（#55，罕见，仅 bench 强制触发）：已合入 992。
- **NSS Wi-Fi 卸载下不要手动 `rmmod`/`modprobe` ath11k**：reload 后两个射频看着正常但无法完成四次握手，直到重启；
  watchdog 已改为这种情况下直接重启。
- **成对密钥重协商会导致客户端重连**（`wpa_deny_ptk0_rekey`，默认 1，#49）。两个射频都无法原地换密钥：作 AP 时一次重协商会让
  流量卡住 16–31 秒并以去认证收场；打开该选项后客户端改为重连，约 1 秒恢复。作为 AP 的客户端时，本机也会在约 5 秒内自行重连，
  而不是等 AP 握手超时。
- **v2.0.0 / v2.0.1 上每次 LuCI 登录会泄漏约 175 KiB 的 `rpcd` 内存**（json-c 0.19，#50），直到 `rpcd` 重启为止。v2.0.2 已修复。
- **还没有数天的长稳观察。** 本 fork 尚未跑长稳；上游的记录见 [VALIDATION.md](VALIDATION.md)（v2.1.0 上每种 Wi-Fi 模式
  30 分钟分片流量、6.3 小时 CPU 负载、v2.0.0 的 100 分钟流量/崩溃恢复等）。
- **2.4 GHz 信号读数只核对到约 ±10 dB。** 5 GHz 与测试客户端的差异在 3 dB 以内。
- 走 NSS 卸载的 PPPoE 上传时 `n2h_rx_queue[0]_drops` 会上涨：256 MB 板子上这个 NSS 队列只有 256 项。

细节都在 [VALIDATION.md](VALIDATION.md)。

## 文档

- [本移植层给 kuncy7 的发布加了什么](docs/what-this-port-adds.md)，以及因为他树里已有而不再携带的内容
- [软件包](docs/packages.md)：仓库、内核模块与钉住的包
- [AmneziaWG](docs/amneziawg.md)：安装、LuCI 导入、全隧道
- [从 v1.x 升级](docs/upgrading-from-v1.md)
- [构建](docs/building.md)
- [VALIDATION.md](VALIDATION.md)：真机测过什么、没测什么
- [NFC 标签](docs/nfc.md)
- [不接 UART 重刷](docs/no-uart-reflash.md)
- [英国 5.8 GHz 信道与固件的 regulatory 数据库](docs/regulatory-gb-5ghz.md)

## v1.x

v1.x 系列（内核 6.12，v1.0 到 v1.14）在 `v1` 分支上，已停止开发。其中 `standard` 镜像是不带 NSS 卸载的版本。

## 致谢与贡献

感谢 [kuncy7](https://github.com/kuncy7) 的 openwrt-nss-edma 及其 IPQ50xx 的 NSS 栈（v2 就建立在它之上）；
[csharper2005](https://github.com/csharper2005/openwrt) 的 AN8855 集成与基础设备树；Min Yao / Airoha 和 Christian Marangi
的驱动工作；thmalmeida、Edrikk 和 [OpenWrt 论坛的贡献者](https://forum.openwrt.org/t/adding-support-for-xiaomi-ax3000t-rd03v2/235136)
在硬件与救砖方向的打底工作；以及 [Ziyang Huang](https://github.com/hzyitc) 的 ath11k smallbuffers 支持。

欢迎贡献，尤其是帮忙把这个移植 upstream 进 OpenWrt。
按 [GPL-2.0-only](LICENSE) 授权；各补丁保留原始作者署名。

## 本 fork 的修改

相对上游 `main`（`85d91d8`，v2.0.2），本 fork 领先 20 个提交、落后 14 个；**不 merge/rebase 上游**，只按内容取用。
下面按主题摘要（逐条历史见 `git log`）：

### 基座、补丁与迁移

- **基座**：bump 到 kuncy7 的 `ipq50xx-2026.10.28`，`upstream.lock` / `feeds.lock` 一起钉住；随之删掉上游已合并的 tree patch 0010/0011，
  0008 按 10.28 的树重写，999-972 走 `mac80211-fuzz-reviewed.txt` 的 reviewed-fuzz 维护，自带的 #984 因上游 999-997 已实现同样功能而删除。
- **Wi-Fi / NSS 数据通路**：合入上游 v2.1.0/v2.1.1 的修复——984/988/989/990/991/992 与 ECM 9001（对应 #52、#53、#54、#55、#48 及 CE RX
  片段缓存/加锁），965 的说明同步更新；hostapd tree patch 0012（apsta 重启时去认证旧客户端，#54）；NSS Wi-Fi 卸载下 watchdog
  改为重启，而不是 reload ath11k。
- **v1.x 迁移（#51）**：`10_disable_services` 只摘 `qca-nss-ecm` 一行，保留用户禁用过的其他服务；动作写入 `/etc/rd03v2-migrate.log`
  （由 keep.d 保留），`tools/test-migrate-v1x.py` 跑 8 个场景，verify 在宿主机与镜像 BusyBox 两边都跑。

### 镜像内容、签名与默认值

- **包单**：zh-CN 界面（`CONFIG_LUCI_LANG_zh_Hans`，并在 `image-must-have` 里断言中文包确实进镜像）、Argon v3.1.1（见补充说明）、
  `luci-app-ttyd`/`statistics`/`travelmate`/`filemanager`、`curl`/`bash`/`unzip`/`openssh-sftp-server`、zram-swap；
  AmneziaWG / WireGuard / SQM 编成 `=m`，随签名的本地包仓库发布。
- **签名与仓库**：用本 fork 的 EC 密钥签名构建产物与包仓库（`keys/public-key.pem` 公开，私钥不入库）；没有发布包仓库时，
  镜像里不列自己的仓库 URL（避免 `apk update` 报 404）。
- **首启默认值**：双频 AP 默认开启（WPA2/PSK，SSID `MiNet_OpWrt`）、Argon 居中登录页、AX 射频自动信道、`home.me` 本地域名；
  首启标记写在 `/etc/config/rd03v2`。station 默认留在 NSS 通路，因此不再写 `wifi_offload_sta=1`（需要 host 通路时设 `wifi_offload_sta=0`）。
- **发布卫生**：`mkrelease-v2.sh` 的发布物不带构建机路径——`feeds.buildinfo` 的 NSS 源换成 `upstream.lock` 的 `NSS_URL`（pin 所在的
  fork tag 下），删掉 `config.buildinfo` 的 `CONFIG_CCACHE_DIR`，并对发布文本资产加 `/home|/root|/tmp` 护栏。

### 修复与工具

- **进程页空白**：libubox 的 SIGCHLD handler 改为 `SA_RESTART`（EINTR/SIGCHLD，记录见工作区文档 `13-进程页面空白-EINTR与SIGCHLD.md`）。
- **验证工具**：`tools/verify-v2.sh` 增加 0012、mac80211 core/ECM 指纹、json-c/libffi 来源护栏、mac80211 每次在 scratch 里无 fuzz
  重套、迁移测试；`tools/check-host-rx.py` 按 10.28 的语义重写（15 项检查）；`tools/test-watchdog.sh` 覆盖 46 个场景。
- **文档**：`README.md`、`VALIDATION.md`、`docs/what-this-port-adds.md` 同步到上游 v2.1.1（`b62ba92`）原文；本文件为中文说明。

补充说明：

- **Argon 主题**：`luci.mk` 在 make 解析期就要读 `po/` 和 `root/`，所以只能用"构建前 stage"而不是 `PKG_SOURCE`；
  `tools/stage-argon-v2.sh` 只保留 Makefile/htdocs/ucode/root/po/compat，产物与原 vendor 副本逐字节一致。
- **首启 Wi-Fi 口令**：本 fork 的 `99-rd03v2-firstboot` 里是一个可公开的默认口令（`Passwd.123`），刷机后请自行修改。
- 构建方式与上游一致（`build.sh` + `tools/finish-build-v2.sh`），差异只在包单、签名密钥、首启默认值与 Argon 的 stage 步骤。
- **上游文档**：`README.md`、`VALIDATION.md`、`docs/what-this-port-adds.md` 已同步到上游 v2.1.1（`b62ba92`）的原文；
  英文 README/VALIDATION 保留上游写法（基座与发布流程以上游为准），本 fork 的差异见本文件与 README 头部的说明。
- **未采纳的上游改动**：`CONFIG_KERNEL_DEBUG_INFO`（镜像不变，只是构建树保留 DWARF；本 fork 不留构建树、设备侧也没有 crash dump
  管道，暂不采纳——将来做 crash 分析时要和“构建后归档 vmlinux”一起做）。#51 与 `50687ae` 已并入，见上面两节。
