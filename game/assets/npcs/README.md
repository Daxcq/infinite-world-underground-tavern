# 地下桌边人物

2026-11-08 接入用户已提供的角色。来源为本机微信文件目录 `D:/电脑管家迁移文件/xwechat_files/wxid_vehdh1cvzy4k22_7f3c/msg/file/2026-11/`；原文件没有修改。

`underground_npcs.json` 是可选客人名单：落单的冒险者、阿努比斯、防毒面具医生、面具客、秘骰面具人、疫医、木偶。酒保使用 `vintage gentleman 3d model.glb`，固定承担荷官职能，不作为同伴候选。

六份原始模型直接复制。秘骰面具人使用已制作的 `美术资产/荷官绑骨样例_v1/masked_dealer_rigged.glb` 动作副本；原始 `mysterious masked man 3d model.glb` 也保留在此供溯源。冒险者沿用 `assets/characters/motion/adventurer_motion.glb`。重复的绅士文件与冒险者文件不作为不同人物加入名单。

冒险者和秘骰面具人有现成坐姿；其余模型没有骨架，保留源姿势。统一身高与脚底原点仅作用于场景实例。新增人物使用现有 GENERIC 策略，尚未制作各自的独立行为、对白或专属能力。

`spectators.png` 原样复制自首批“权贵观众_八人透明图集”，用于外围两圈共 32 名低亮度平面观众；近处可选人物使用实体 3D。`light_shaft.gdshader` 是 Compatibility 可用的轻量光束示意，实际桌面照明来自头顶 SpotLight3D，不依赖体积雾。

灯光参数参考 Godot 官方 [SpotLight3D](https://docs.godotengine.org/en/stable/classes/class_spotlight3d.html) 和 [Environment](https://docs.godotengine.org/en/stable/classes/class_environment.html)，并在本机 4.7.2 Compatibility 渲染下检查。
