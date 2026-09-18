import Foundation

/// 所有文案。产品的性格都在这里。
enum Copy {

    // MARK: - 预警（最后 N 秒）
    // 秒数只显示在圆环里，这里不再重复，所以文案里没有 {n}。

    static func warning(_ level: SassLevel) -> [String] {
        switch level {
        case .mild:
            return [
                "准备站起来吧。",
                "该活动一下了。",
                "快到点了，别赖着。",
                "深呼吸，准备起身。",
                "马上就好，先动动脚。",
                "先动动脚踝，做个热身。",
                "站一下，就一下。",
                "现在起身最划算。",
                "给自己十秒钟准备。",
                "起来倒杯水，也是个理由。",
                "肩颈想跟你说声谢谢。",
                "腰会记住你这份好。"
            ]
        case .cheeky:
            return [
                "你的椅子已经开始嫌弃你了。",
                "屁股和椅子的爱情故事即将中断。",
                "请准备表演一个「人类站立」。",
                "别装没看见，我数着呢。",
                "趁现在，把腿从桌子底下收回来。",
                "最后几秒，体面一点。",
                "椅子说它想一个人待会儿。",
                "它已经在偷偷量你的体温了。",
                "准备告别你的第二个家。",
                "你的腿还记得怎么用吗？",
                "别假装在思考，你只是不想动。",
                "你的脖子已经在写抗议信了。",
                "倒计时结束前，你还是个体面人。"
            ]
        case .savage:
            return [
                "你的椎间盘正在写遗书。",
                "再不动，你的屁股就要和椅子长成一体了。",
                "公开处刑即将开始，请提前整理仪容。",
                "理疗师已经在路上了。",
                "你确定要把这具身体用到报废再换吗？",
                "你的核心肌群正在开最后一场会议。",
                "你的腰椎已经申请劳动仲裁了。",
                "再坐下去，你和椅子的关系就不清白了。",
                "你的屁股正在给未来的自己写道歉信。",
                "站起来。这是通知，不是商量。",
                "你的身体已经提交了离职申请。",
                "病假条不会替你站起来。",
                "此刻你还站得起来，是种幸运。",
                "别等到「想站也站不起来」那天。"
            ]
        }
    }

    // MARK: - 锁屏（起立中）

    static func lock(_ level: SassLevel) -> [String] {
        switch level {
        case .mild:
            return [
                "站起来走两步吧，对腰好。",
                "该起来活动一下了，顺便看看窗外。",
                "站一会儿，身体会谢谢你的。",
                "起来伸个懒腰，脖子也会轻松一点。",
                "慢慢起身，不用急。",
                "这几分钟，给自己倒杯水。",
                "看看远处，眼睛也歇一歇。",
                "站直，深呼吸三次。",
                "这一小段时间完全属于你。",
                "活动活动脚踝和肩膀。"
            ]
        case .cheeky:
            return [
                "站起来。你的椅子说它想静静。",
                "恭喜，你成功把自己焊在了椅子上。现在请拔掉焊点。",
                "人类不是海星，不需要一直贴在椅子上。",
                "起来走走。代码不会跑，你的腰椎会。",
                "站直了。你低头的样子，像在给键盘道歉。",
                "你的椅子已经记住了你的形状。这不叫成就。",
                "你和椅子的相处，已经过于融洽了。",
                "椅子是家具，不是器官。",
                "站起来，海拔立刻高出四十厘米。",
                "现在没人看得见你，正好可以扭一扭。",
                "别怕，地板不会咬人。",
                "你的腿只是睡着了，叫醒它们。",
                "你已经用一个姿势演完了整部电影。",
                "椅子在等你松手，像在等一场分手。"
            ]
        case .savage:
            return [
                "坐着很舒服吧？舒服的东西通常是慢性毒药。",
                "每次你选择「再坐五分钟」，就有一个椎间盘选择离职。",
                "起身。那张理疗账单你付不起，我知道。",
                "你的身体在替你加班，而你连站起来都不愿意。",
                "你的核心肌群已经集体辞职了，现在轮到你了。",
                "继续坐着吧。反正轮椅的广告总有人要看。",
                "你现在坐着的每一分钟，都在给未来的自己记账。",
                "腰不好的人，连叹气都得扶着墙。",
                "你可以继续坐着。反正疼的时候，我不会替你疼。",
                "站起来。你的身体不是一次性用品。",
                "瘫着很舒服，可惜它收费很贵。",
                "别把年轻当成可以随便透支的额度。",
                "你还有几十年的路要走，靠的是这两条腿，不是这把椅子。",
                "这不是提醒，这是最后通牒。"
            ]
        }
    }

    // MARK: - 认输嘲讽

    static func surrenderTaunt(_ level: SassLevel) -> [String] {
        switch level {
        case .mild:
            return [
                "确定要提前坐回去吗？",
                "再坚持一下会更好，确定吗？",
                "真的要现在解锁吗？",
                "其实你还能再站一会儿。",
                "已经站了一会儿了，现在放弃有点可惜。"
            ]
        case .cheeky:
            return [
                "才站了 {n}。椅子会怎么看你？",
                "确定？你的腰正在用沉默抗议。",
                "好吧。反正疼的不是我。",
                "这么急？椅子又不会跑。",
                "才 {n}，你连泡面都还没泡好。",
                "行吧，反正给椅子道歉的又不是我。",
                "这一键下去，你的椎间盘会记仇的。"
            ]
        case .savage:
            return [
                "才 {n}。你的意志力和核心肌群一样弱。",
                "当然，你随时可以坐下。反正账单写的是你的名字。",
                "认输了？我甚至都还没开始认真。",
                "坐下吧。你的身体会记住这次背叛的。",
                "才 {n}。你连站起来这件事都能半途而废。",
                "行，坐回去。反正后悔的额度还够你用几次。",
                "你刚证明了：让你站起来，比让你早睡还难。"
            ]
        }
    }

    // MARK: - 站满之后（开启了「休息结束后停留」时显示）

    static func finished(_ level: SassLevel) -> [String] {
        switch level {
        case .mild:
            return [
                "这一轮站满了，坐吧。",
                "辛苦了，接下来继续加油。",
                "做得好。下一轮见。",
                "休息够了，随时可以开始。"
            ]
        case .cheeky:
            return [
                "行了，坐下吧，我批准了。",
                "这一仗你赢了。暂时。",
                "站满的人才有资格坐下。",
                "看在你站满的份上，这次不骂你。",
                "难得。值得记一笔。"
            ]
        case .savage:
            return [
                "站满了？稀奇。",
                "这次算你赢。下一轮再说。",
                "很好，你还记得自己是个人类。",
                "坐吧。反正四十五分钟后我们还会见。",
                "别得意，这才一轮。"
            ]
        }
    }

    static func dismissButton(_ level: SassLevel) -> String {
        switch level {
        case .mild: return "开始下一轮"
        case .cheeky: return "好，继续坐着吧"
        case .savage: return "行，开始下一轮"
        }
    }

    // MARK: - 其它

    static let lockTitle = "站起来！"
    static let warningKicker = "预备——"

    static func surrenderButton(_ level: SassLevel) -> String {
        switch level {
        case .mild: return "提前结束休息"
        case .cheeky: return "我认输了，解锁"
        case .savage: return "我投降，让我坐回去"
        }
    }

    static func surrenderConfirm(_ level: SassLevel) -> String {
        switch level {
        case .mild: return "确认结束"
        case .cheeky: return "对，我就是要坐回去"
        case .savage: return "是的，我选择伤害自己"
        }
    }

    static let surrenderCancel = "算了，我再站会儿"

    static func renderDuration(_ template: String, remaining: TimeInterval) -> String {
        template.replacingOccurrences(of: "{n}", with: shortDuration(remaining))
    }

    static func shortDuration(_ interval: TimeInterval) -> String {
        let total = max(0, Int(interval.rounded(.up)))
        let minutes = total / 60
        let seconds = total % 60
        if minutes > 0 {
            return "\(minutes) 分 \(seconds) 秒"
        }
        return "\(seconds) 秒"
    }
}
