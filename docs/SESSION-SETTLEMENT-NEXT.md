# 完整旅程原子结算：设计约束与已实现范围

安全模式退役、首章与最终胜利结算已按本设计接入开发分支。下文记录其原子性与恢复约束；真实死亡及跨局天赋效果仍未实现，详细实测边界见 VERIFICATION.md。

## 必须一次提交

Session.finish(outcome) 先复制当前 World 并调用 finish_run，形成候选，不先保存终局再单独领奖。适配器 settle_run 接受 expected_slot、expected_revision、run_id、outcome、固定 request_id，不信任 UI 提供的摘要或奖励。

存储事务从当前完整 schema13 World 重新验证、结束并推导 settlement_summary，同一事务写 ended snapshot、archived 状态、唯一 receipt、profile、run revision+1、slot revision+1 和 last_op。任一失败均不得发布。现有六字段原型的 summary 方法不能复用冒充完整 World 验证。

## 成功与恢复

- 确认提交并匹配终局候选后才发布结果、清空 Undo，终局与存储冲突只读须区分。
- 启动/L 读到已归档旅程应显示终局及收据，不当作损坏，也不自动开局覆盖；只允许明确开新局。
- 丢失响应按同一 request_id 和原 CAS 重试返回原结果，不重复增加任何计数。不同 outcome 冲突。
- 新局已经建立后，旧结算重试不得切回旧局或覆盖活动视图。

## 玩家选择

首章胜利 K 不自动结算：继续远征，或明确结束并结算首章。探索中可明确确认退役，最终 Z 胜利明确结算。风险模式/死亡仍另批实现，不能把安全拒战当作死亡。首次里程碑解锁目前仅为标识，不能宣传为已生效的永久天赋。

## 验证清单

真实 K 继续不领奖、首章结算后不可继续；提前退出及 Z 结算；事务各故障点全回滚；丢响应/重启重复请求；跨窗口新局后旧结算不能恢复旧活动槽；终局撤销拒绝；旧无身份档不可补领；损坏 receipt/ended 摘要不一致拒绝；原生及生产 IndexedDB 使用相同完整 World 协议。

Web 特别约束：JS 事务不能调用 GDScript。Godot 先验证完整 base 并准备 ended 候选，IDB 事务内再校验 CAS、当前完整 base 与准备时完全一致，并确认候选只有允许的 ended 字段变化；JS 根据事务内实际状态推导同一摘要。不能把事务外验证当作并发安全，也不能声称 JS 在执行 World.restore。
