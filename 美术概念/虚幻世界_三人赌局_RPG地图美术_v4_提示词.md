# 虚幻世界：三人赌局·RPG地图美术 v4

- 交付类型：按照酒馆地图的俯视2D RPG画法重绘的美术概念图。
- 保留：三角座位、面具荷官、玩家、NPC同伴，以及贴近桌沿和椅背的权贵人群。
- 材质与氛围：暗红天鹅绒、黑金木质圆桌、骰子聚光和昏暗环境。
- 调整方向：平面地图视角、小比例角色、统一人物与家具画法、手绘木地板。
- 生成方式：内置 image_gen 工具。
- RPG画风标准：[已确认的酒馆地图](./初始场景_俯视2D_RPG含NPC_v6.png)
- 内容参考：[密集围观v3](./虚幻世界_三人赌局_密集围观_v3.png)
- 图像：[虚幻世界_三人赌局_RPG地图美术_v4.png](./虚幻世界_三人赌局_RPG地图美术_v4.png)

## 最终生成提示词

Use case: style-transfer
Asset type: 虚幻赌局的2D RPG地图美术概念图，竖向3:5。

REFERENCE PRIORITY:
Image 1 is the MASTER ART STANDARD. The output must look like another map made by the same 2D RPG art team: same fixed top-down orthographic camera, same small hand-painted NPC sprites, same flat wooden floor tiles, same furniture rendering and simplified character detail. This is a 2D GAME MAP, not a scene illustration.
Image 2 supplies ONLY story content and relative arrangement: red round gambling table, three gamblers 120 degrees apart, and many richly dressed spectators close around it. Do NOT copy image 2's close-up character rendering, large detailed faces, sculpted 3D volume or dramatic perspective.

Create a new fully redrawn game map in Image 1's visual language. Think of walking from Image 1's tavern map into a new dark gambling map in the SAME 2D game.

CAMERA / GAME SCALE — critical:
Use Image 1's orthographic top-down RPG map projection. All floorboard edges parallel, no vanishing point, no depth blur, no cinematic foreshortening. Furniture tops fully readable, vertical side faces shallow. Characters must be actual small map sprites, not portrait illustrations standing on a floor.
At an output of roughly 970 x 1620, each standing person should be about 100–120 pixels tall. On this same scale, the large circular table should be about 430–470 pixels in diameter. This makes the table huge in game-world scale while fitting into a proper map view. Do not draw 200–300 pixel tall spectators or close-up faces. Heads have just a few controlled painted details, matching Image 1; clothing has readable shapes and restrained fine accents, not individually rendered portrait detail. Characters do not change size with screen position. This is detailed hand-painted 2D, not crude pixel art, not cartoon chibi and not 3D.

MAP CONTENT:
In the center of a dark flat wooden floor is ONE large round gambling table. Its top is circular, covered with dark burgundy velvet, framed by black-stained wood and aged gold trim. Three ornate but modestly sized chairs sit evenly around it:
- At 12 o'clock, the white-masked dealer in an ivory shirt and dark waistcoat.
- At 8 o'clock, the dark-haired player in a plain brown travel coat.
- At 4 o'clock, the NPC companion with brown hair and a worn dark-green coat.
The three seats are equally distant from table center and 120 degrees apart, forming an equilateral triangle. Keep only these three seated participants.
Each has chips and a dice cup in front. Three small ivory dice sit in the center, surrounded by some chip stacks, a chip tray and a small hourglass. Table items are clear game props, not enlarged still-life objects.

CLOSE WATCHING CROWD:
About eighteen adult nobles stand VERY CLOSE around the outside of the table and directly behind the three chair backs. Preserve the sense of a tight, oppressive circle of onlookers from Image 2. No large empty gap between spectators and the table. Two shallow staggered rows in a few places are fine. All spectators face inward. They must be the same RPG map-sprite scale as the dealer, player and companion, not giant foreground people.
Costumes include dark-purple velvet, dark-red silk, deep-green brocade, black gold-embroidered cloaks, fur collars and chains. A few have feathered hats, jeweled headpieces or pearl hair ornaments. Most bodies dissolve into the shadows; only small side profiles, shoulders, headdresses and gold accents catch very weak spill light. Spectators must not cover the three seated participants, dice or game props.

DARKNESS AND LIGHT:
The world around this map is nearly black and very oppressive. The wooden floor is only faintly visible around the gathering and fades into black farther out. Use a single overhead spotlight focused on the three central dice, with rapid falloff. The dice are brightest, table and participants next, crowd much dimmer. Represent the spotlight as a 2D light pool on the floor and tabletop, like in-engine lighting in Image 1. If the hanging light fixture is shown, make it a very small prop near the upper area, not a giant cinematic lamp or enormous beam. No other light sources.
Dark burgundy, black, aged gold and ivory palette. Do NOT copy Image 1's bright amber tavern lighting, bar, shelves, four drinking tables, rug, windows or ordinary tavern guests. Copy its map art style and sprite scale only.

Finish as one complete 2D RPG GAME MAP screenshot without UI. No typography, labels, arrows, grid, dialogue boxes, title, watermark, split view or concept sheet. The result should be visibly more flat and game-map-like than Image 2.

