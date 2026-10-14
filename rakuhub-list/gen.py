import html
S={'済':'done','進行中':'doing','未着手':'todo','アイデア':'idea','決定':'done','約束済':'must'}
cats=[
("1. 集客：アウトバウンド","#2f6fed",[
(1,"営業フォームの残り数百件を送り切る","10/14","進行中","1,387通で反応2件（約0.1%）"),
(2,"フォームは止めて、イベント集客用に使い直す","10/14","アイデア",""),
(3,"送るならAIで自動化（三吉さん助言）","10/5","未着手",""),
(4,"テレアポを3人で半日（担当者が出たら確度の高い人に交代）","10/5・10/6","未着手","日程未定"),
(5,"電話番号のみの会社をテレアポリスト化","10/1","未着手",""),
(6,"飛び込み営業（三吉さん「一番効率がいい」）","10/5","未着手",""),
(7,"DMリスト2,440件の使い道を決める","10/6","未着手","合計3,000件超"),
(8,"安藤さん営業済みの会社をリストに入れる","10/1","決定",""),
(9,"営業資料を金融機関にも送る","9/30","未着手",""),
(10,"金融機関のつながりから紹介をもらう","10/8","進行中",""),
]),
("2. 集客：インバウンド","#0e9f6e",[
(11,"実名・顔出しでX／Threads運用","10/2・10/5","未着手","1ヶ月で数件アポの例"),
(12,"KPASS型：Claude編集で量産＋開発の裏側＋機能紹介","10/8","アイデア",""),
(13,"短尺動画（実写かAIかは要議論）","10/14","アイデア",""),
(14,"科学系AI広告をまねたクリエイティブ","10/8","進行中","試作済み"),
(15,"SNS広告（Meta広告など）","10/14","アイデア",""),
(16,"Meta広告で集めてセミナー開催","10/5","アイデア",""),
(17,"「ラクハブ」検索対策のリスティング広告","10/1","未着手","ロジックスが表示される"),
(18,"SEO：記事を増やす","10/1","未着手","今は2ページのみ"),
(19,"導入事例ページ（しんけん）","9/29","進行中",""),
(20,"ポッドキャスト／ラジオで発信","9/28・10/13","進行中",""),
(21,"キャラクターのチュートリアル","9/23","アイデア",""),
]),
("3. イベント・コミュニティ","#d97706",[
(22,"自主開催のオフラインイベント（商談化の導線まで）","9/28〜10/13","アイデア",""),
(23,"運送×AIコミュニティ（事例共有・採用にも）","9/28","アイデア",""),
(24,"参加する展示会・交流会を選ぶ","10/5","未着手",""),
(25,"10/22 大宮の運送会社飲み会","10/2","決定","crestさんも"),
(26,"浦和会・渋沢ミックスで動く","10/7","進行中",""),
]),
("4. 売り方・提案の型","#7c3aed",[
(27,"ラクハブ＋AX伴走で売る（3ヶ月週1→月1）","10/1","アイデア",""),
(28,"ITリテラシーで商談の型を分ける","10/1","アイデア",""),
(29,"「誰からAIを触るか」まで提案","10/1","アイデア",""),
(30,"運送会社育ちの健心が作った、を前に出す","10/1","アイデア",""),
(31,"何を売るかを一言にする","9/28","進行中",""),
(32,"「配車・原価管理システム」の言い換え","9/27","進行中",""),
(33,"料金の根拠（20台月15万／3ヶ月30万→15万）","9/24・10/6","進行中",""),
(34,"野口さん商談の流れ（AXエバンジェリスト契約へ）","10/6","約束済","日程再調整済み"),
(35,"無料診断を入口に（オンライン30分／出張60分）","10/5・10/8","進行中",""),
(36,"補助金をまず自分たちで申請","9/24","未着手",""),
(37,"出張料金を決める","10/7","未着手",""),
]),
("5. 営業ツール","#db2777",[
(38,"資料・サイトの要素を減らす","9/28","進行中",""),
(39,"スライドのタイトルからAIっぽさをなくす","9/25","進行中",""),
(40,"AIっぽい画像をイラストへ","9/27","進行中",""),
(41,"資料に顔写真（撮影も）","9/30","進行中",""),
(42,"ラクハブの名刺","10/1","未着手",""),
(43,"ロードネット向け資料・チラシ","9/16","約束済",""),
(44,"TimeRexの使いやすさ確認／「返信でも可」","10/7","進行中",""),
(45,"流入計測（UTM・GA4）","10/4","進行中",""),
(46,"営業ダッシュボードの運用","10/1","進行中",""),
]),
("6. プロダクト（約束していること）","#0891b2",[
(47,"1運行ごとの利益を出す機能","10/5","約束済","10月末"),
(48,"ラクハブが自律的に動く","10/6","約束済","12月末"),
(49,"自動点呼（認定 JM26-027）を前面に","9/30","進行中",""),
(50,"既存システム・様式はそのまま、足りない所だけAIで","10/8","進行中",""),
(51,"倉庫向け応用（作業時間の見える化／相互紹介）","9/25","アイデア",""),
]),
("7. 体制","#475569",[
(52,"インターン・クラウドワーカーの運用","10/1","進行中","Drive権限は済"),
(53,"荻原さんにフォーム100件","10/1","進行中",""),
(54,"外注先候補（conlax）と組む","9/17","アイデア",""),
(55,"木曜のラクハブ定例に穂高も参加","10/9","決定",""),
(56,"穂高の関わり方と資本関係（3案）","9/3・9/10","未着手",""),
(57,"運送に集中（他業界は条件付き）","10/7","決定",""),
]),
]
def card(t,c,items):
  rows="".join(f'<tr><td class=n>{n}</td><td class=t>{html.escape(x)}{f"<div class=m>{html.escape(m)}</div>" if m else ""}</td><td class=d>{d}</td><td><span class="s {S[s]}">{s}</span></td></tr>' for n,x,d,s,m in items)
  return f'<section style="--c:{c}"><h2>{t}<span>{len(items)}件</span></h2><table>{rows}</table></section>'
cols=[[0,1],[3,2],[4,5,6]]
body="".join("<div class=col>"+"".join(card(*cats[i]) for i in col)+"</div>" for col in cols)
open("list.html","w").write(f'''<!doctype html><meta charset=utf-8><style>
*{{box-sizing:border-box;margin:0}}body{{font-family:"IPAGothic","IPAゴシック",sans-serif;background:#f4f5f7;color:#1f2937;padding:40px;width:2000px}}
header{{display:flex;justify-content:space-between;align-items:flex-end;margin-bottom:26px}}h1{{font-size:38px}}h1 small{{font-size:20px;color:#6b7280;margin-left:14px}}
.kpi{{font-size:18px;color:#374151;background:#fff;border:1px solid #e5e7eb;border-radius:10px;padding:10px 16px}}.kpi b{{color:#dc2626;font-size:22px}}
.grid{{display:grid;grid-template-columns:repeat(3,1fr);gap:22px;align-items:start}}.col{{display:flex;flex-direction:column;gap:22px}}
section{{background:#fff;border-radius:12px;border-top:6px solid var(--c);box-shadow:0 1px 3px rgba(0,0,0,.08);padding:16px 18px}}
h2{{font-size:22px;color:var(--c);display:flex;justify-content:space-between;margin-bottom:8px}}h2 span{{font-size:15px;color:#9ca3af}}
table{{width:100%;border-collapse:collapse;font-size:16px}}td{{padding:7px 4px;border-top:1px solid #f0f1f3;vertical-align:top}}
.n{{width:30px;color:#9ca3af;font-weight:bold}}.t{{line-height:1.4}}.m{{font-size:13px;color:#6b7280;margin-top:2px}}.d{{width:92px;font-size:13px;color:#6b7280;white-space:nowrap}}
.s{{display:inline-block;font-size:13px;padding:2px 8px;border-radius:99px;white-space:nowrap}}
.done{{background:#dcfce7;color:#166534}}.doing{{background:#dbeafe;color:#1e40af}}.todo{{background:#f3f4f6;color:#4b5563}}.idea{{background:#fef3c7;color:#92400e}}.must{{background:#fee2e2;color:#991b1b;font-weight:bold}}
footer{{margin-top:22px;font-size:15px;color:#6b7280;display:flex;gap:18px}}
</style><header><h1>ラクハブ施策 やりたいこと一覧<small>2026/9中旬〜10/14 のLINEより・全57件</small></h1>
<div class=kpi>フォーム営業の結果：1,387通 → 反応 <b>2件</b>（約0.1%）</div></header>
<div class=grid>{body}</div>
<footer><span><span class="s must">約束済</span> 期限・相手との約束あり</span><span><span class="s doing">進行中</span></span><span><span class="s done">決定</span></span><span><span class="s todo">未着手</span></span><span><span class="s idea">アイデア</span> 話に出ただけ</span></footer>''')
