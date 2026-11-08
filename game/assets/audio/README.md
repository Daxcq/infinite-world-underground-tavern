# 背景音乐

`rusted_heartbeat.ogg` 由根目录 `音乐/地下赌局_锈蚀心跳_变奏试听.wav` 转换为 OGG Vorbis（quality 6、48 kHz、双声道），时长约 126.55 秒。只转换编码，不剪辑、不重新编曲；首尾沿用原曲淡入淡出，完整播放后从头循环。

该曲为项目已有的含《恶魔轮盘 / Buckshot Roulette》OST 短片段采样的重编试听稿；来源与制作记录见 [试听说明](../../../音乐/试听说明.md)。

`rusted_heartbeat.ogg.import` 中启用循环；`scenes/music.tscn` 作为 Autoload 自动播放，经 Music 总线独立调节音量。
