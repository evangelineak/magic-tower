# 全球排行榜：可选最小方案（尚未实现）

只读核查日期：2026-11-09。未创建账户/数据库/凭据，未新增工作流或开通服务，未产生费用，也未上传玩家回放。当前实际功能仍只有本设备历史榜。

## 现成资源与边界

已经确认：公开 `evangelineak/magic-tower`、GitHub Pages 静态游戏、仓库内固定版本 Godot 的 verification/desktop-preview Actions 工作流。未确认用户已有可复用 Cloudflare、Supabase 或其他后端项目，不能把“可能已有账号”当成可用资源。

GitHub Pages 只能提供静态资源，不能独立承接不可信玩家写入、全局去重与可信排名验算。浏览器 localStorage 和客户端计算分数都由玩家控制；隐藏 JS、客户端签名或把令牌写进页面不能解决作弊，反而会泄露持久访问权。

## A. 不新增服务账号的低风险试验：人工审核回放榜

可以复用现有公开 GitHub 仓库，但**没有实施**：

1. 玩家主动选择参赛，明示其 GitHub 身份与回放会公开；自行通过 GitHub 提交限定格式的 JSON。无需另办服务账号，但参与者仍须有自己的 GitHub 账号，不能称完全匿名、无登录。
2. 维护者先审核提交，再触发只读取固定可信分支的 Godot 验算。第一阶段不对任意公开 issue 自动消耗计算资源；不要为了方便把管理员 token 放入游戏。
3. 限制 JSON 字节、版本、事件数、处理超时与同账号/挑战频率；只将内容当数据，不拼接 shell，不执行用户脚本或检出提交者代码。验算 job 无写权限/secret，排名发布由单独审核步骤完成。
4. 使用冻结规则和统一挑战 seed 重放，服务器自己计算结果。相同日志哈希/同账号同赛季去重，按规则版本、seed/赛季隔离；只发布经过验算的最小字段静态榜 JSON。
5. 清楚标注更新时间、等待审核状态。故障只影响榜单，不影响本地游戏。

**限制与风险：** 这不是即时全球榜，不是无需感知的游戏内提交体验，人工队列和公开 GitHub 身份会明显增加门槛；公开日志可能暴露玩家路线、昵称及行为，不应偷偷提交，也不该要求上传完整本地存储、设备标识或无关个人信息。人工审核与限制减少滥用但不证明真人操作，不防解题器、脚本寻优或多账号。

官方当前说明公开仓库的 **标准 GitHub-hosted runner** 计算免费，larger runner 仍收费 [1]；不能把此当成任意 runner、artifact 存储、无上限工作量或未来政策永久免费承诺。现有工作流的存在也不等于新的榜单权限已授权。任何实际新增公开收集入口、发布权限和流程都应另行决定。

`issues` 事件能够触发默认分支工作流 [2]，但这只是技术能力，不是建议直接开放无门禁执行。初期维护者审核后的手动验证，是更低风险的概念验证。它不适合作为最终的无感排行榜体验。

## B. 游戏内即时提交：Worker + D1 + 可信验算

长期优先考虑保留 Pages 前端，使用 `workers.dev` API 域名，不必买域名；D1 保存最小排名结果。需用户确认服务账户、公开信息政策和费用边界。Cloudflare 账号存在与否尚未确认。

官方当前免费额度 [3][4]：Worker 每日 100,000 请求、每次 10 ms CPU；D1 每日 500 万行读取、10 万行写入、总 5 GB。Worker 付费方案基础 $5/月，并有超出请求/CPU额度后的按量计费；D1 付费超额读取、写入、存储亦计费。不要把免费额度说成永久零成本，也不能在资源耗尽时擅自升级。

**主要阻塞不是存分数，而是验算。** 目前规则是 Godot/GDScript，不能原样作为 Linux 程序直接运行在 Worker。已有本地基准（`docs/benchmarks/ENDLESS-REPLAY-V5.md`）显示真实路线 10k 事件重放约 1.4 秒机器墙钟，但这不是 Worker CPU 基准，不能直接换算预算。要么另提供隔离的 Godot 验算队列，要么移植/编译规则并做跨版本 RNG、整数、事件与保存语义的逐例对齐；不能只把客户端报告分数存入 D1 就叫防作弊榜。

最终协议至少包括：服务端生成挑战/运行 ID，冻结版本与 seed；日志限长、超时、速率限制；服务端重放而非信任客户端分数；一次结算及重试幂等；匿名身份不等于唯一真人，不能只凭可随便填写的昵称认证；用户主动提交，公开字段仅最小昵称/匿名 ID、规则/赛季、经验证成绩与日期，详细日志有保留上限。没有这些，最多应标“未经验证的社区展示榜”。

## 推荐顺序

1. 本批继续修复 v15 地图，不把联网服务阻塞游戏交付。
2. 如要先验证玩家是否愿意参与：明确征得公开回放与 GitHub 身份参与的同意后，采用 A 的人工试验，不承诺即时。
3. 若确实需要无感游戏内体验：用户选择 B 的账号与隐私/费用边界，再做隔离验算原型和负载测试；确认能在硬性资源限制内运行后部署。不要先开通收费账户再研究预算。

## 官方来源

[1] GitHub Actions billing（公开标准 runner 免费、larger runner 计费）：
https://docs.github.com/en/billing/concepts/product-billing/github-actions

[2] Events that trigger workflows（issues / 默认分支要求）：
https://docs.github.com/en/actions/reference/workflows-and-actions/events-that-trigger-workflows

[3] Cloudflare Workers pricing（100k/日、10 ms、付费 CPU/请求额度）：
https://developers.cloudflare.com/workers/platform/pricing/

[4] Cloudflare D1 pricing（行读写与存储额度）：
https://developers.cloudflare.com/d1/platform/pricing/

补充静态托管说明与免自购域名路由：
https://docs.github.com/en/pages/getting-started-with-github-pages/what-is-github-pages
https://developers.cloudflare.com/workers/configuration/routing/workers-dev/

价格与产品政策会变；实际选择账户或开通前应再核查，以上不是费用保证。
