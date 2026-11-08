# 面具男／荷官基础绑骨样例

来源为用户提供的 `mysterious masked man 3d model.glb`。原文件保持完整，本目录为独立工作副本，尚未替换游戏场景中的荷官。

## 文件

- `荷官_绑骨与动作样例.blend`：Blender 5.2.1 工程，保留骨架、可编辑权重、原贴图和动作，贴图已打包。打开后选择 `Dealer_Rig` 可在姿态模式编辑骨骼。
- `masked_dealer_rigged.glb`：供 Godot 等支持 glTF 2.0 的程序导入，包含蒙皮和 4 个测试动作。
- `rig_report.json`：骨骼名称、关节位置、几何数量和权重检查数据。

## 本次完成

按原有弯臂姿势放置了 28 根骨骼，其中 27 根参与蒙皮。覆盖骨盆、脊柱、颈头、锁骨、上臂、前臂、手、大小腿、脚和脚尖；长外套有 6 根下摆辅助骨骼。主体高约 1.8 m，约 20.3 万三角面，工作网格为 122,744 个顶点。

动作编辑器可选择：

| 动作 | 用途 |
| --- | --- |
| `idle` | 原始站姿，便于检查外观 |
| `gesture` | 摊掌、腕部摆动和转头，验证上肢蒙皮 |
| `seated` | 屈髋屈膝的固定坐姿，抬起展示骰子的手 |
| `bend_test` | 双臂和小腿的变形压力检查 |

时间轴为 1—31 帧、30 FPS，选择动作后可按空格预览。默认打开为 `gesture` 动作；这是 FK 骨架，可选中骨骼旋转。没有增加 IK 操纵器或逐指、面部表情控制。

## 验证和边界

- 蒙皮每个顶点最多 4 个骨骼影响，工作网格权重和约为 1。
- GLB 在 Godot 4.7.2 中通过 29 项导入、骨骼、动作和关节运动检查；已渲染检查手势和坐姿。
- Blender 可编辑源文件已重新打开检查，纹理已打包。
- 这是按原姿势建立的基础骨架。胸前手与衣服距离很近，大幅离胸、复杂抓握等动作仍需逐帧精修权重或局部拓扑；当前不承诺所有任意姿势都无穿模。
- 手上的红骰沿用原模型，与手部一同变形，尚未拆为可拿取、可释放的独立赌具。
- 衣摆由辅助骨骼控制，尚无布料模拟；坐姿是固定样例，尚未制作坐下和起身的连续过渡动画。

## 复现

使用本机 Blender 5.2 依次运行：

```powershell
& 'D:\Blender\blender-5.2.1-windows-x64\blender.exe' --background --python-exit-code 1 --python tools/prepare_dealer_rig_sample.py
& 'D:\Blender\blender-5.2.1-windows-x64\blender.exe' --background --python-exit-code 1 --python tools/build_dealer_rig_sample.py
```

准备文件与检查渲染在 `game/verification/dealer_rig/`。运行 `res://verification/verify_dealer_rig.gd` 可以复查 GLB；无窗口模式执行数值检查，有窗口模式还会输出手势、坐姿与动作帧。
