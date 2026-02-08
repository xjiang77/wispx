现在设计一个claude code setup 的skill, 或者工具，下面是一些背景和要求：
  1. 我是一个有12年hands on 开发经验的软件工程师，对building/creating 简单当的，简洁的，有效的，robust的，state of
  art的软件系统有很强的passion, 这样的软件系统对用户来讲也应该是简洁的，直观易懂好用的；
  2. 我现在创建一个toolkit用来set up claude code, 这里的setup应该包含create/update/review/audit/package/install
  等完整的生命周期，形式应该是skill 或者make commands的形式，应该我会在多台mac上工作，我需要有一个工具把通用的setup
  一键安装好，然后有skill/工具来更新项目级的setup；
  3. 可以参考https://github.com/affaan-m/everything-claude-code/tree/main和https://github.com/obra/superpowers里面内容，但是我们不想刚
  开始就搞那么复杂，我需要一个最简单，简洁，有效的setup做为开始；
  4. 所有的claude code setup, 都应该check in到git, 你可以设计一下这里的目录结构，像skill这样的工具，因为我会使用claude
  code,codex和codebuddy等多个coding agent/工具，所以我希望它们是可以共用/复用的；
  5. 所有的setup elements, claude.md skills, command, mcp, hooks,
  都要先制定最佳实践规范，说明为什么这样是最佳实践规范，然后确保我们的setup是符合最近规范实践的；
  6. 对当前的setup要有一个详细的说明，为什么这样配置，以及给出最有效的使用建议和规范；