import html
S={'進行中':'doing','未着手':'todo','アイデア':'idea','約束済':'must'}
cats=[
("集客：アウトバウンド","#2f6fed",[
("フォーム営業の締めと転用","進行中",["残り数百件を送り切る（現状1,387通で反応2件）","以降はイベント集客用に使い直す","続けるならAIで自動化（三吉さん助言）"]),
("テレアポ","未着手",["健心・穂高・インターンの3人で半日まとめて","電話番号のみの会社・安藤さん営業済み先もリスト化","DMリスト2,440件を含め3,000件超を活用"]),
("飛び込み営業","未着手",["三吉さん「一番効率がいい。やらずに他をやるのは逃げ」"]),
("金融機関ルート","進行中",["営業資料を金融機関に送る","信金などのつながりから紹介をもらう"]),
]),
("集客：インバウンド","#0e9f6e",[
("実名SNS運用","未着手",["X／Threadsを実名・顔出しで（1ヶ月で数件アポの例）","KPASS型：Claude編集で量産＋開発の裏側＋機能紹介","短尺動画は実写かAIか要議論／AI広告クリエイティブ試作済み"]),
("広告","アイデア",["Meta広告で集めてセミナー開催","「ラクハブ」検索のリスティング広告（ロジックスが出る）"]),
("サイト・SEO","進行中",["記事を増やす（いまGoogleに出るのは2ページ）","導入事例ページ（しんけん）","キャラクターのチュートリアル"]),
("ポッドキャスト・ラジオ","進行中",["方向性と導入の言い回しは9/28に検討済み","10/15定例後に企画"]),
]),
("イベント・コミュニティ","#d97706",[
("自主開催イベント＋運送×AIコミュニティ","アイデア",["イベントから商談化までの導線を設計","AIで楽になった運送会社が事例を持ち寄る場","若い人を呼べば採用・プラットフォームにも"]),
("外部イベント・経営者ネットワーク","進行中",["参加する展示会・交流会を選ぶ","10/22 大宮の運送会社飲み会（crestさんも）","浦和会・渋沢ミックス"]),
]),
("売り方・提案","#7c3aed",[
("商品設計：ラクハブ×AX伴走","進行中",["3ヶ月週1→以降月1（3ヶ月30万→月15万）","料金の根拠づくり（20台で月15万想定）・出張料金","入口は無料診断（オンライン30分／出張60分）","補助金はまず自分たちで申請"]),
("商談の型とメッセージ","進行中",["何を売るかを一言に／「配車・原価管理システム」の言い換え","ITリテラシーで型を分ける・「誰からAIを触るか」まで提案","運送会社育ちの健心が作った／既存システムはそのまま"]),
("野口さん商談","約束済",["ハンズオンで悩みを解決→AXエバンジェリスト契約へ","日程は再調整済み"]),
]),
("営業ツール・計測","#db2777",[
("営業資料・LP・名刺の磨き込み","進行中",["要素を減らす／タイトルのAIっぽさ・AI画像をなくす","顔写真の撮影と掲載／ラクハブの名刺","ロードネット向け資料・チラシ（お父さんからの依頼）"]),
("計測と営業管理","進行中",["UTM・GA4でチャネル別に効果測定","営業ダッシュボードの運用","TimeRexの使いやすさ確認／「返信でも可」を明記"]),
]),
("プロダクト","#0891b2",[
("約束している機能","約束済",["1運行ごとの利益を出す機能（10月末）","ラクハブの自律化（12月末）","自動点呼（認定 JM26-027）を前面に"]),
("倉庫向けへの応用","アイデア",["作業時間を見える化して値上げ交渉に","運送と倉庫の相互紹介"]),
]),
("体制","#475569",[
("営業の実行体制","進行中",["インターン・クラウドワーカーの運用／荻原さんにフォーム100件","外注先候補（conlax）と組む","木曜のラクハブ定例に穂高も参加"]),
("穂高の関わり方と資本関係","未着手",["業務委託／直接参画／資本参加の3案から決める"]),
]),
]
n=0
def card(t,c,items):
  global n
  rows=""
  for name,s,notes in items:
    n+=1
    li="".join(f"<li>{html.escape(x)}</li>" for x in notes)
    rows+=f'<div class=it><div class=hd><span class=n>{n}</span><span class=t>{html.escape(name)}</span><span class="s {S[s]}">{s}</span></div><ul>{li}</ul></div>'
  return f'<section style="--c:{c}"><h2>{t}</h2>{rows}</section>'
cols=[[0,1],[2,3,6],[4,5]]
body="".join("<div class=col>"+"".join(card(*cats[i]) for i in col)+"</div>" for col in cols)
open("list.html","w").write(f'''<!doctype html><meta charset=utf-8><style>
*{{box-sizing:border-box;margin:0;padding:0}}body{{font-family:"IPAGothic",sans-serif;background:#f4f5f7;color:#1f2937;padding:40px;width:2000px}}
header{{display:flex;justify-content:space-between;align-items:flex-end;margin-bottom:24px}}h1{{font-size:38px}}h1 small{{font-size:19px;color:#6b7280;margin-left:14px}}
.kpi{{font-size:17px;background:#fff;border:1px solid #e5e7eb;border-radius:10px;padding:10px 16px;line-height:1.6}}.kpi b{{color:#dc2626;font-size:21px}}
.grid{{display:grid;grid-template-columns:repeat(3,1fr);gap:22px;align-items:start}}.col{{display:flex;flex-direction:column;gap:22px}}
section{{background:#fff;border-radius:12px;border-top:6px solid var(--c);box-shadow:0 1px 3px rgba(0,0,0,.08);padding:16px 20px 6px}}
h2{{font-size:21px;color:var(--c);margin-bottom:4px}}
.it{{padding:12px 0;border-top:1px solid #eef0f2}}.hd{{display:flex;align-items:center;gap:10px}}
.n{{background:var(--c);color:#fff;border-radius:50%;width:28px;height:28px;display:inline-flex;align-items:center;justify-content:center;font-size:15px;font-weight:bold;flex:none}}
.t{{font-size:20px;font-weight:bold;flex:1}}
ul{{margin:6px 0 0 38px;font-size:15px;color:#4b5563;line-height:1.6;list-style:none}}li::before{{content:"・";color:#9ca3af}}
.s{{font-size:13px;padding:3px 10px;border-radius:99px;white-space:nowrap}}
.doing{{background:#dbeafe;color:#1e40af}}.todo{{background:#f3f4f6;color:#4b5563}}.idea{{background:#fef3c7;color:#92400e}}.must{{background:#fee2e2;color:#991b1b;font-weight:bold}}
footer{{margin-top:20px;font-size:15px;color:#6b7280;display:flex;gap:18px;align-items:center}}
</style><header><h1>ラクハブ施策 やりたいこと一覧<small>2026/9中旬〜10/14 のLINEより・{n}施策（元の57項目をまとめたもの）</small></h1>
<div class=kpi>フォーム営業：1,387通 → 反応 <b>2件</b>（約0.1%）<br>方針：運送に集中（他業界は年数千万規模か信頼につながる場合のみ）</div></header>
<div class=grid>{body}</div>
<footer><span><span class="s must">約束済</span> 期限・相手との約束あり</span><span class="s doing">進行中</span><span class="s todo">未着手</span><span><span class="s idea">アイデア</span> 話に出ただけ</span></footer>''')
