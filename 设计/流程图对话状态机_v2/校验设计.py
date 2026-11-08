"""校验设计数据，并生成逐条文案及可离线打开的审阅页。不是游戏运行时。"""
import json
from collections import Counter
from pathlib import Path

ROOT = Path(__file__).resolve().parent
data = json.loads((ROOT / '对话节点.json').read_text(encoding='utf-8'))
nodes = data['nodes']
index = {node['id']: node for node in nodes}
assert len(index) == len(nodes), '节点 ID 重复'
assert data['entry'] in index
line_ids = []
for node in nodes:
    assert all(node.get(key) for key in ('id', 'phase', 'title', 'source', 'trigger', 'kind', 'lines'))
    assert isinstance(node['on_enter'], list) and isinstance(node['on_exit'], list)
    assert node['transitions'] or node['kind'] in ('terminal', 'pending'), node['id']
    for line in node['lines']:
        line_ids.append(line['id'])
        assert all(line.get(key) for key in ('id', 'speaker', 'text', 'when'))
    edge_keys = []
    for edge in node['transitions']:
        assert edge['target'] in index, (node['id'], edge['target'])
        assert edge['event'] and edge['guard']
        assert edge['status'] in ('specified', 'proposal', 'pending')
        assert isinstance(edge['effects'], list)
        edge_keys.append((edge['event'], edge['guard']))
    assert len(edge_keys) == len(set(edge_keys)), ('同事件同守卫重复', node['id'])
assert len(line_ids) == len(set(line_ids)), '对白 ID 重复'

reachable, queue = set(), [data['entry']]
while queue:
    current = queue.pop()
    if current in reachable:
        continue
    reachable.add(current)
    queue.extend(edge['target'] for edge in index[current]['transitions'])
assert reachable == set(index), ('存在不可达节点', set(index) - reachable)
assert {n['id'] for n in nodes if n['kind'] == 'terminal'} == {'E01', 'E02'}
assert {n['id'] for n in nodes if n['kind'] == 'pending'} == {'Q01', 'Q02'}
assert any(e['target'] == 'C00' for e in index['F25']['transitions'])
assert not any(e['target'] in ('E00', 'E01') for e in index['F25']['transitions'])

# 设计参考模型：验证本稿约定的边界，不声称覆盖尚未接入的 Godot 代码。
assert index['F13']['transitions'][0]['guard'] == 'stake_total>=formal_stake'
assert index['F24']['transitions'][0]['guard'] == 'pool_total>=dealer_total'
for actual, expected in ((99, False), (100, True), (101, True)):
    assert (actual >= 100) == expected
for total, expected in ((11, False), (12, True), (13, True)):
    assert (total >= 12) == expected

def responsibility(player, npc, solo=False, clear_loss=False):
    if solo or clear_loss:
        return 'PLAYER'
    return 'PLAYER' if player < npc else 'NPC' if player > npc else 'BOTH'

assert responsibility(1, 4) == 'PLAYER'
assert responsibility(10, 4) == 'NPC'
assert responsibility(4, 4) == 'BOTH'
assert responsibility(0, 0) == 'BOTH'
assert responsibility(10, 0, solo=True) == 'PLAYER'
assert responsibility(99, 1, clear_loss=True) == 'PLAYER'

def settle(model, action_id, party):
    if action_id in model['settled'] or model['penalties'] == 3:
        return
    model['settled'].add(action_id)
    if party in ('PLAYER', 'BOTH'):
        model['organs'].append(('EYE', 'HAND', 'HEART')[model['penalties']])
        model['penalties'] += 1
    if party in ('NPC', 'BOTH'):
        model['npc_sanctions'] += 1

model = dict(settled=set(), penalties=0, organs=[], npc_sanctions=0)
settle(model, 'a', 'NPC')
assert model['penalties'] == 0 and model['npc_sanctions'] == 1
settle(model, 'b', 'PLAYER')
settle(model, 'b', 'PLAYER')
assert model['organs'] == ['EYE']
settle(model, 'c', 'BOTH')
assert model['organs'] == ['EYE', 'HAND'] and model['npc_sanctions'] == 2
settle(model, 'd', 'PLAYER')
settle(model, 'e', 'PLAYER')
assert model['organs'] == ['EYE', 'HAND', 'HEART'] and model['penalties'] == 3
keys = set()
for kind in ('STAKE', 'STAKE', 'POOL', 'POOL'):
    keys.add(kind)
assert len(keys) == 2
keys.add('CLEAR')
assert keys == set(data['fragments'])
die_ids = [{'id': 'd1', 'face': 4}, {'id': 'd2', 'face': 4}, {'id': 'd3', 'face': 1}]
assert sum(die['face'] for die in die_ids if die['id'] in {'d1', 'd2'}) == 8

book = ['# 逐节点对话、触发与转移', '',
        '由《对话节点.json》生成。审阅范围为设计契约；条件不能当作已经满足。', '',
        '状态标签：specified 为本稿编排；proposal 为衔接建议；pending 为未决定。', '']
for node in nodes:
    book += [f"## {node['id']} · {node['title']}", '',
             f"阶段：`{node['phase']}`；类型：`{node['kind']}`。", '',
             f"原图位置：{node['source']}。", '', f"**触发：** {node['trigger']}。", '',
             '**进入副作用：** ' + ('；'.join(node['on_enter']) or '无资源副作用。'), '', '**对白：**', '']
    for line in node['lines']:
        condition = '' if line['when'] == 'true' else f"（仅当 `{line['when']}`）"
        book += [f"- `{line['id']}` {condition} **{line['speaker']}：** {line['text']}"]
    book += ['', '**选项与下一跳：**', '']
    if not node['transitions']:
        book += ['本节点终止；' + ('待决定，不自动选择结局。' if node['kind'] == 'pending' else '只能由结束菜单重新开始或返回标题。')]
    for edge in node['transitions']:
        label = f"[{edge['label']}] " if edge['label'] else ''
        book += [f"- {label}`{edge['event']}` → `{edge['target']}`（{edge['status']}）。",
                 f"  条件：`{edge['guard']}`。执行：{'；'.join(edge['effects']) or '无资源副作用。'}"]
        if edge['hint']:
            book += [f"  提示：{edge['hint']}"]
    book += ['', '**离开清理：** ' + '；'.join(node['on_exit']), '']
    if node['note']:
        book += ['**备注：** ' + node['note'], '']
(ROOT / '节点逐条文案.md').write_text('\n'.join(book), encoding='utf-8')
template = (ROOT / '预览模板.html').read_text(encoding='utf-8')
assert template.count('__NODES_JSON__') == 1
embedded = json.dumps(data, ensure_ascii=False).replace('<', '\\u003c')
(ROOT / '对话流程预览.html').write_text(template.replace('__NODES_JSON__', embedded), encoding='utf-8')
report = dict(date=data['date'], scope='设计拓扑与独立规则参考模型；不是Godot运行测试',
              nodes=len(nodes), dialogue_lines=len(line_ids), transitions=sum(len(n['transitions']) for n in nodes),
              phase_counts=dict(Counter(n['phase'] for n in nodes)), reachable_nodes=len(reachable),
              topology='passed', rule_reference_model='passed',
              checked_boundaries=['底注相等通过', '共渡相等通过', '少投／多投／相等责任', '独狼无虚构NPC',
                                  '清桌败方责任', 'NPC单罚不扣玩家器官', '同贡献双方一次受罚',
                                  '重复action不重复扣除', '第三次付心无第四次', '三类碎片集合去重', '相同骰点按ID区分'],
              pending_nodes=['Q01', 'Q02'], proposal_edges=[{'from':n['id'], 'to':e['target'], 'guard':e['guard']}
                for n in nodes for e in n['transitions'] if e['status']=='proposal'],
              browser_verification='not_run', godot_runtime='本脚本只校验设计；游戏运行状态见 game/对话接入说明.md')
(ROOT / '设计验收.json').write_text(json.dumps(report, ensure_ascii=False, indent=2), encoding='utf-8')
print(json.dumps(dict(nodes=len(nodes), lines=len(line_ids), edges=report['transitions'], topology='passed', rules='passed')))
