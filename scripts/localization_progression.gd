extends RefCounted

# Pure display catalog. English simulation IDs and rule text remain untouched.
# Dynamic templates retain argument order; %% is a literal percent sign.
const EXACT = {
	"Warden": "护卫",
	"Brace": "架盾",
	"Spend 1 focus: block 35% of total battle loss (rounded down).": "消耗1专注：下场战斗减伤35%（减伤量向下取整）。",
	"Ranger": "游侠",
	"Precision": "精准破甲",
	"Spend 1 focus: ignore 10 enemy DEF for the next battle.": "消耗1专注：下场战斗忽略敌方10防御。",
	"Scholar": "学者",
	"Mend": "治愈",
	"Spend 1 focus outside battle: recover 80 HP.": "在战斗外消耗1专注，恢复80生命。",
	"Traveler's kit": "旅人行装",
	"No bonuses or penalties. The safe baseline.": "无加成，也无负面效果。稳妥的基础行装。",
	"Heavy buckler": "重盾",
	"+6 DEF / -4 ATK. Block the first enemy attack, not thorns.": "防御+6／攻击-4。格挡敌方首击，不挡荆棘。",
	"Duelist's rig": "决斗装",
	"WARNING: take an EXTRA opening counter, even on a one-shot. Enemy DEF -8; +6 ATK / -3 DEF.": "注意：开局额外挨一次反击，秒杀也不例外。本场敌防-8；攻击+6／防御-3。",
	"Iron skin": "铁壁",
	"+2 effective DEF in every battle.": "每场战斗防御+2。",
	"Keen edge": "利刃",
	"+3 effective ATK in every battle.": "每场战斗攻击+3。",
	"Clean finish": "干净利落",
	"After a zero-loss victory, recover 15 HP.": "无伤击败敌人后，恢复15生命。",
	"Last stand": "背水一战",
	"Below 200 HP before battle: +20% damage per hit (floor).": "战前生命低于200时，每击伤害+20%（向下取整）。",
	"Sentinel lore": "哨卫研习",
	"+4 effective DEF against Sentinels only.": "仅对战哨卫时，防御+4。",
	"Trained focus": "专注精修",
	"Brace blocks 45% (floor); Precision ignores 14 DEF; Mend heals 100.": "架盾减伤45%（减伤量向下取整）；精准破甲忽略14防御；治愈恢复100生命。",
	"Giant slayer": "巨兽猎手",
	"Against enemies with at least 180 HP: +10% hit damage (floor).": "敌人初始生命不少于180时，每击伤害+10%（向下取整）。",
	"Battle medic": "战地救护",
	"Recover 10 HP after a surviving victory.": "获胜且存活后，恢复10生命。",
	"Unbroken": "不屈",
	"At 400+ HP before battle: reduce total loss by 20.": "战前生命不少于400时，本场总损血减少20。",
	"Unknown hero.": "未知英雄。",
	"Invalid battle input.": "战斗数据无效。",
	"Cannot break armor. Change equipment, use Precision, or return later.": "无法破防。换装、使用精准破甲，或成长后再来。",
	"Victory possible.": "可以获胜。",
	"Lethal. Post-battle recovery cannot save you.": "这场会战死；战后恢复不能抵消致死伤害。"
}

const TEMPLATES = [
	["Spend 1 focus: block %d%% of total battle loss (rounded down).", "消耗1专注：下场战斗减伤%d%%（减伤量向下取整）。"],
	["Spend 1 focus: ignore %d enemy DEF for the next battle.", "消耗1专注：下场战斗忽略敌方%d防御。"],
	["Spend 1 focus outside battle: recover %d HP.", "在战斗外消耗1专注，恢复%d生命。"]
]
