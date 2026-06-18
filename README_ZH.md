# Hydrapool

[Hydrapool](https://hydrapool.org) 是一个开源的比特币挖矿池软件，支持独立挖矿（Solo Mining）和 PPLNS 收益分配模式。

我们在主网运行了一个实例：[test.hydrapool.org](https://test.hydrapool.org)。但我们希望您能运行自己的矿池。请参阅下方的[如何运行](#运行)部分。目前限制最多 100 个用户（因 coinbase 和区块大小限制），矿机数量取决于您的硬件。

## 功能特性

1. **私有矿池** — 可运行私有独立矿池或社区 PPLNS 矿池
2. **Coinbase 直接支付** — 收益直接从 coinbase 支付，矿池运营商不托管任何资金
3. **透明可验证** — 用户可下载并验证 shares 和收益分配数据
4. **监控面板** — 基于 Prometheus 和 Grafana 的矿池、用户和矿机监控
5. **兼容性强** — 支持任何支持 Bitcoin RPC 的节点
6. **Rust 实现** — 易于扩展，支持自定义分配和支付方案
7. **开源协议** — AGPLv3 许可证

<a id="运行"></a>
# 运行自己的 Hydrapool 实例

## 使用 Docker 运行

我们提供 Dockerfile 和 docker compose 文件，方便快速部署。

### 下载 docker compose 和配置文件

```bash
curl --proto '=https' --tlsv1.2 -LsSf -o docker-compose.yml https://github.com/256foundation/hydrapool/releases/latest/download/docker-compose.yml
curl --proto '=https' --tlsv1.2 -LsSf -o config.toml https://github.com/256foundation/hydrapool/releases/latest/download/config-example.toml
```

### 编辑 config.toml

根据您的比特币节点配置修改以下参数：
- `bitcoinrpc` — 比特币节点 RPC 地址
- `zmqpubhashblock` — ZMQ 新区块通知地址
- `network` — 网络类型（signet/main）
- `bootstrap_address` — 主网需要修改为您的地址

### 配置比特币节点

需要在 `bitcoin.conf` 中允许 Hydrapool 连接：

```ini
# 允许所有接口连接
rpcbind=0.0.0.0

# 允许 Docker 网络访问
rpcallowip=172.16.0.0/12
```

### 启动矿池

```bash
docker compose -f docker-compose.yml up
```

启动后：
- Stratum 服务端口：`3333`
- 监控面板地址：`http://localhost:3000`

# 升级

```bash
cd <docker-compose.yml 所在目录>

# 拉取最新镜像
docker compose pull

# 重建容器
docker compose up -d --force-recreate
```

> **注意**：从 v1.x.x 升级到 **v2.x.x 或更高版本**时，数据库格式已更改，需要重置：
> ```bash
> docker compose down -v
> docker compose up -d
> ```

# 监控面板

## 矿池面板

显示矿池整体算力、每秒 shares、最高难度、用户和矿机数量、算力分布等。

![矿池面板预览](./docs/images/pool_dashboard.png)

## 用户面板

显示指定用户的所有矿机算力和独立矿机算力。

![用户面板预览](./docs/images/users_dashboard.png)

# 安全配置

如果对外提供 API 服务，建议配置认证。使用以下命令生成认证令牌：

```bash
docker compose run --rm hydrapool-cli gen-auth <用户名> <密码>
```

将生成的配置复制到 `config.toml` 中的 `auth_user` 和 `auth_token`。

# API 服务

矿池启动时会同时启动 API 服务器。

- 获取 PPLNS Shares：`http://<服务器IP>:<API端口>/pplns_shares`
- 支持 `start_time` 和 `end_time` 参数过滤时间范围

# 从源码构建

```bash
git clone https://github.com/256-foundation/Hydra-Pool/
cargo build --release
```

### 系统要求

- Rust 1.88.0 或更高版本
- OpenSSL 开发库
- libclang

### 安装依赖（Ubuntu）

```bash
sudo apt update
sudo apt install libssl-dev pkg-config clang libclang-dev
```

### 运行

```bash
./target/release/hydrapool --config config.toml
```

# 安装预编译二进制

```bash
curl --proto '=https' --tlsv1.2 -LsSf https://github.com/256-Foundation/Hydra-Pool/releases/latest/download/hydrapool-installer.sh | sh
```

将安装两个二进制文件：
- `hydrapool` — 矿池主程序
- `hydrapool_cli` — 命令行工具

# 许可证

本项目使用 [AGPLv3](LICENSE) 许可证。

---

*[English Version](README.md)*
