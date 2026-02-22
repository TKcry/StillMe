import React from 'react';

export default function TermsOfService() {
  return (
    <div className="max-w-4xl mx-auto py-12 px-6">
      <h1 className="text-3xl font-bold mb-4">利用規約</h1>
      <p className="text-sm text-gray-400 mb-8">最終更新日：2026年2月22日</p>

      <section className="space-y-8 text-gray-300">
        <div className="bg-white/5 p-6 rounded-lg border border-white/10">
          <p className="font-semibold text-white mb-2">運営：StillMe（以下「当サービス」といいます。）</p>
          <p>
            本利用規約（以下「本規約」といいます。）は、当サービスが提供するモバイルアプリケーション「StillMe」および関連機能の利用条件を定めるものです。
            ユーザーは、本規約に同意したうえで当サービスを利用するものとします。
          </p>
        </div>

        <div className="space-y-4">
          <h2 className="text-xl font-bold text-white border-l-4 border-blue-500 pl-4">第1条（適用）</h2>
          <ol className="list-decimal list-inside space-y-2">
            <li>本規約は、当サービスの利用に関する当サービスとユーザーとの間の一切の関係に適用されます。</li>
            <li>当サービスがアプリ内または当サービスが管理するWebページ上で掲載するガイドライン、注意事項、ヘルプ、運用ルール、プライバシーポリシーは、本規約の一部を構成します。</li>
            <li>本規約と前項の内容が矛盾する場合、本規約が優先します（ただし、当サービスが個別に優先順位を明示した場合はその限りではありません）。</li>
            <li>ユーザーが当サービスを利用した時点で、ユーザーは本規約に同意したものとみなします。</li>
          </ol>
        </div>

        <div className="space-y-4">
          <h2 className="text-xl font-bold text-white border-l-4 border-blue-500 pl-4">第2条（定義）</h2>
          <p>本規約において使用する用語を、次のとおり定義します。</p>
          <ul className="list-disc list-inside space-y-2">
            <li>「ユーザー」：当サービスを利用する個人。</li>
            <li>「アカウント」：ユーザーが当サービスを利用するために作成する認証情報およびそれに紐づく識別情報。</li>
            <li>「フレンド」：ユーザー同士が相互承認により接続した関係（当サービス内の相互接続関係）。</li>
            <li>「投稿」：ユーザーが当サービスに写真・動画等をアップロードし、保存・共有状態にする行為。</li>
            <li>「コンテンツ」：写真（JPEG等）、動画（MP4等）、テキスト、メタデータ（撮影日時・公開範囲・識別情報等）その他ユーザーが当サービス上で保存・表示・共有する情報。</li>
            <li>「ユーザーコンテンツ」：コンテンツのうち、ユーザーが当サービスに投稿・保存したもの。</li>
            <li>「公開範囲」：投稿時にユーザーが選択する閲覧可能な範囲。</li>
            <li>「外部サービス」：当サービスの提供に利用される第三者サービス（第7条で明示するFirebase等）。</li>
          </ul>
        </div>

        <div className="space-y-4">
          <h2 className="text-xl font-bold text-white border-l-4 border-blue-500 pl-4">第3条（アカウント）</h2>
          <ol className="list-decimal list-inside space-y-2">
            <li>ユーザーは、当サービス所定の方法によりアカウントを作成することで当サービスを利用できます。</li>
            <li>ユーザーは、登録情報に変更があった場合、当サービス所定の方法で速やかに変更するものとします。</li>
            <li>アカウントの管理はユーザーの責任で行うものとし、ユーザーは第三者にアカウントを利用させてはなりません。</li>
            <li>当サービスは、当該アカウントを用いて行われた一切の行為を、当該アカウントを保有するユーザー本人の行為とみなします。</li>
            <li>ユーザーは、アカウントの不正利用が疑われる場合、速やかに第23条の窓口へ連絡するものとします。</li>
          </ol>
        </div>

        <div className="space-y-4">
          <h2 className="text-xl font-bold text-white border-l-4 border-blue-500 pl-4">第4条（年齢制限）</h2>
          <ol className="list-decimal list-inside space-y-2">
            <li>13歳未満の方は当サービスを利用できません。</li>
            <li>未成年者が当サービスを利用する場合、親権者その他の法定代理人の同意を得たうえで利用するものとします。</li>
            <li>未成年者が当サービスを利用した時点で、法定代理人の同意があったものとみなします。</li>
          </ol>
        </div>

        <div className="space-y-4">
          <h2 className="text-xl font-bold text-white border-l-4 border-blue-500 pl-4">第5条（当サービスの内容）</h2>
          <p>当サービスは、次の機能を提供します。</p>
          <ul className="list-disc list-inside space-y-2">
            <li>フロントカメラおよびバックカメラによる撮影（同時または逐次）</li>
            <li>写真（JPEG等）および動画（MP4等）の投稿・保存</li>
            <li>フレンド検索（ユーザーID／ハンドル等）および相互承認によるフレンド接続</li>
            <li>フィード（カード形式）での閲覧</li>
            <li>カレンダー／履歴による日付単位の振り返り</li>
            <li>リマインダー通知（ユーザーによるON/OFF、通知時刻の設定）</li>
            <li>ウィークリー・アンロック（週の規定日数の投稿達成に応じた特別コンテンツ等の解放ロジック）</li>
            <li>ブロック機能（特定ユーザーとの接点遮断）</li>
            <li>通報機能（不適切コンテンツの報告）</li>
            <li>非公開設定（他ユーザーからのID検索を拒否する設定）</li>
            <li>アカウント削除（退会）機能</li>
          </ul>
        </div>

        <div className="space-y-4">
          <h2 className="text-xl font-bold text-white border-l-4 border-blue-500 pl-4">第6条（公開範囲・共有）</h2>
          <ol className="list-decimal list-inside space-y-2">
            <li>ユーザーは投稿時に、公開範囲として少なくとも次のいずれかを選択できます。
              <ul className="pl-6 mt-2 space-y-1">
                <li>(1) 「全フレンドに公開」：投稿時点で当該ユーザーと接続しているフレンド全員が閲覧可能</li>
                <li>(2) 「特定フレンドに公開」：投稿時点で当該ユーザーが指定したフレンドのみが閲覧可能</li>
              </ul>
            </li>
            <li>ユーザーは、公開範囲の選択が閲覧可能者を直接決定することを理解し、自らの責任で公開範囲を設定するものとします。</li>
            <li>フレンド関係が成立していないユーザーは、当該投稿を閲覧できません（当サービスが別途公開型機能を提供する場合を除きます）。</li>
            <li>当サービスの仕様上、フレンド解除またはブロックにより共有権限が失効した場合、相手ユーザーは当該投稿を閲覧できなくなります（第9条）。</li>
          </ol>
        </div>

        <div className="space-y-4">
          <h2 className="text-xl font-bold text-white border-l-4 border-blue-500 pl-4">第7条（外部サービス：Firebaseの利用と保存場所）</h2>
          <ol className="list-decimal list-inside space-y-2">
            <li>当サービスは、Google LLC が提供する「Firebase」を利用します。</li>
            <li>当サービスが利用するFirebaseの機能は、次のとおりです。
              <ul className="pl-6 mt-2 space-y-1 text-sm text-gray-400">
                <li>(1) Firebase Authentication（アカウント認証）</li>
                <li>(2) Cloud Firestore（プロフィール、フレンド関係、投稿メタデータ等の保存）</li>
                <li>(3) Firebase Storage（写真・動画ファイルの保存）</li>
              </ul>
            </li>
            <li>ユーザーのデータは、Firebaseが稼働するGoogle Cloudのインフラ上に保存されます。</li>
            <li>当サービスは、Google Cloud（Firebase）のUSリージョンを利用します。したがって、ユーザーのデータは米国に設置されたサーバー上に保存されます。</li>
            <li>ユーザーは、前項の保存場所（米国）に同意したうえで当サービスを利用するものとします。</li>
          </ol>
        </div>

        <div className="space-y-4">
          <h2 className="text-xl font-bold text-white border-l-4 border-blue-500 pl-4">第8条（フレンド：成立）</h2>
          <ol className="list-decimal list-inside space-y-2">
            <li>フレンド関係は、一方の招待に対し、他方が承認した場合に成立します（相互承認制）。</li>
            <li>フレンド関係が成立するまで、当該相手ユーザーに対して投稿の共有は行われません。</li>
          </ol>
        </div>

        <div className="space-y-4">
          <h2 className="text-xl font-bold text-white border-l-4 border-blue-500 pl-4">第9条（フレンド解除・ブロック：相互削除と閲覧権限の失効）</h2>
          <div className="pl-4 border-l-2 border-white/5 ml-2">
            <h3 className="font-semibold text-white mb-2 decoration-blue-500/50 underline-offset-4 underline">1. フレンド解除（解除の効果）</h3>
            <ul className="list-disc list-inside space-y-2 ml-2">
              <li>ユーザーは、当サービス所定の方法により、いつでもフレンド解除を行うことができます。</li>
              <li>いずれか一方がフレンド解除を行った場合、Cloud Firestore上の相互接続データ（pairRefs）を削除します（相互削除）。</li>
              <li>前項の削除により、解除は双方に即時反映され、相手側のフレンド一覧から当該ユーザーの表示が消えます。</li>
              <li>フレンド解除後、相手ユーザーは当該ユーザーのプロフィールおよび投稿を一切閲覧できません。</li>
              <li>フレンド解除は、当該相手ユーザーに付与されていた「閲覧・共有の権限」を失効させるものです。投稿データ自体（写真・動画・メタデータ）は、投稿者のアカウントに保持されます。</li>
            </ul>

            <h3 className="font-semibold text-white mt-6 mb-2 decoration-blue-500/50 underline-offset-4 underline">2. ブロック（ブロックの効果）</h3>
            <ul className="list-disc list-inside space-y-2 ml-2">
              <li>ユーザーは、当サービス所定の方法により、特定ユーザーをブロックできます。</li>
              <li>ブロックは、当該ユーザーとの接点を遮断する措置であり、ブロックが行われた場合、当サービスは当該ユーザーとのフレンド関係を維持しません（pairRefsの削除を含みます）。</li>
              <li>ブロック後、双方は互いのプロフィールおよび投稿を閲覧できません。</li>
              <li>当サービスは、ブロックの有無や理由を相手に通知する義務を負いません。</li>
            </ul>

            <h3 className="font-semibold text-white mt-6 mb-2 decoration-blue-500/50 underline-offset-4 underline">3. 再接続</h3>
            <ul className="list-disc list-inside space-y-2 ml-2">
              <li>フレンド解除またはブロック後に再度接続する場合、改めて招待・承認の手続が必要です。</li>
              <li>新たなフレンド関係が成立しない限り、解除前に投稿者側に保持されている過去データであっても、相手は閲覧できません。</li>
            </ul>
          </div>
        </div>

        <div className="space-y-4">
          <h2 className="text-xl font-bold text-white border-l-4 border-blue-500 pl-4">第10条（スクリーンショット等の保存可能性）</h2>
          <ol className="list-decimal list-inside space-y-2">
            <li>ユーザーは、共有されたコンテンツについて、相手ユーザーがスクリーンショット、画面収録、外部端末による撮影等により保存する可能性があることを了承します。</li>
            <li>当サービスは、前項の保存行為を技術的に完全に防止することはできません。</li>
            <li>フレンド解除・ブロック・退会により当サービス上の閲覧権限が失効しても、相手ユーザーが前項の方法で既に保存したデータの削除まで当サービスが保証するものではありません。</li>
          </ol>
        </div>

        <div className="space-y-4">
          <h2 className="text-xl font-bold text-white border-l-4 border-blue-500 pl-4">第11条（ユーザーコンテンツの権利帰属）</h2>
          <ol className="list-decimal list-inside space-y-2">
            <li>ユーザーコンテンツに関する著作権その他の権利は、投稿したユーザーまたは正当な権利者に帰属します。</li>
            <li>ユーザーは、ユーザーコンテンツを投稿するにあたり、当該コンテンツの投稿・共有に必要な権利（被写体の同意、第三者の著作物利用許諾等）を有していることを保証します。</li>
            <li>ユーザーが前項に違反して第三者との間で紛争が生じた場合、ユーザーは自己の費用と責任でこれを解決し、当サービスに損害を与えないものとします。</li>
          </ol>
        </div>

        <div className="space-y-4">
          <h2 className="text-xl font-bold text-white border-l-4 border-blue-500 pl-4">第12条（ユーザーコンテンツの利用許諾）</h2>
          <ol className="list-decimal list-inside space-y-2">
            <li>ユーザーは、当サービスに対し、当サービスの提供に必要な範囲でユーザーコンテンツを利用する権利を許諾します。許諾の範囲は次のとおりです。
              <ul className="pl-6 mt-2 space-y-1 text-sm text-gray-400">
                <li>(1) サーバーへの保存</li>
                <li>(2) 端末・通信環境に応じた最適化のための変換（サイズ変更、圧縮、形式変換等）</li>
                <li>(3) 公開範囲に応じた配信・表示（フレンドへの表示を含む）</li>
                <li>(4) 障害対応・不正対策・サポート対応のために必要な処理</li>
              </ul>
            </li>
            <li>前項の許諾は、非独占的かつ無償であり、ユーザーコンテンツの権利帰属を移転するものではありません。</li>
            <li>当サービスは、ユーザーの明示的同意なく、ユーザーコンテンツを第三者に販売しません。</li>
          </ol>
        </div>

        <div className="space-y-4">
          <h2 className="text-xl font-bold text-white border-l-4 border-blue-500 pl-4">第13条（動画に関する特則）</h2>
          <ol className="list-decimal list-inside space-y-2">
            <li>現時点において、当サービスに投稿される動画には音声は含まれません。</li>
            <li>現時点において、当サービスは動画にBGMを付与しません。</li>
            <li>将来、Spotify等の外部音楽サービス連携機能を導入する場合、当サービスは導入時に必要な利用条件（対象機能、連携方法、適用規約、権利処理等）を当サービス上で明示します。</li>
            <li>動画はFirebase Storageに保存されますが、当サービスは、データが永続的に保存されること、または常に復元可能であることを保証しません（第20条参照）。</li>
            <li>当サービスは、現時点で「過去の記録をまとめた自動生成動画（タイムラプス等）の生成・再生成」を提供していません。将来導入する場合は、第3項と同様に条件を明示します。</li>
          </ol>
        </div>

        <div className="space-y-4">
          <h2 className="text-xl font-bold text-white border-l-4 border-blue-500 pl-4">第14条（通報）</h2>
          <ol className="list-decimal list-inside space-y-2">
            <li>ユーザーは、当サービス所定の方法により、不適切なコンテンツを通報できます。</li>
            <li>通報は、当サービスが管理するCloud Firestoreの「reports」コレクションへの情報送信として記録されます。</li>
            <li>当サービスは、通報内容を確認し、必要に応じて第18条に定める措置を行います。</li>
            <li>当サービスは、通報者に対し、対応結果や対応理由を個別に回答する義務を負いません。</li>
          </ol>
        </div>

        <div className="space-y-4">
          <h2 className="text-xl font-bold text-white border-l-4 border-blue-500 pl-4">第15条（禁止事項）</h2>
          <p>ユーザーは、次の行為をしてはなりません。</p>
          <ul className="list-disc list-inside space-y-2">
            <li>法令または公序良俗に違反する行為</li>
            <li>当サービスまたは第三者の著作権、商標権、肖像権、プライバシー権、名誉権その他の権利利益を侵害する行為</li>
            <li>誹謗中傷、脅迫、差別、嫌がらせ、ストーキング、またはこれらを助長する行為</li>
            <li>なりすまし、虚偽の登録、アカウントの譲渡・売買・貸与</li>
            <li>わいせつ表現、児童性的虐待に該当または関連するコンテンツ、過度に暴力的な表現、自傷・自殺を助長する表現、薬物の不正利用を助長する表現を含むコンテンツの投稿</li>
            <li>当サービスまたは外部サービスへの不正アクセス、リバースエンジニアリング、解析、改変、脆弱性の悪用</li>
            <li>当サービスのサーバーに過度の負荷を与える行為、ボット等による不正利用</li>
            <li>当サービスの運営、通報対応、審査、モデレーションを妨害する行為</li>
            <li>その他、当サービスが合理的な理由に基づき不適切と判断する行為</li>
          </ul>
        </div>

        <div className="space-y-4">
          <h2 className="text-xl font-bold text-white border-l-4 border-blue-500 pl-4">第16条（フレンド数の制限・課金）</h2>
          <ol className="list-decimal list-inside space-y-2">
            <li>現時点において、当サービスはフレンド登録数の上限を設けません（無料で無制限）。</li>
            <li>当サービスは、将来的に有料プラン（サブスクリプション等）を導入する場合があります。</li>
            <li>有料プランを導入する場合、当サービスは、料金、課金周期、自動更新の有無、解約方法、提供機能、無料トライアルの有無をアプリ内で明示します。</li>
            <li>課金および返金は、プラットフォーム（例：Apple）の規約および運用に従います。</li>
          </ol>
        </div>

        <div className="space-y-4">
          <h2 className="text-xl font-bold text-white border-l-4 border-blue-500 pl-4">第17条（アカウント削除・退会とデータ削除）</h2>
          <ol className="list-decimal list-inside space-y-2">
            <li>ユーザーは、当サービス所定の方法により、いつでもアカウント削除（退会）できます。</li>
            <li>当サービスは、退会後、最大30日間、復旧対応のためにユーザーのデータ（プロフィール、投稿、関連メタデータ、認証情報）を保持します。</li>
            <li>退会後30日が経過した時点で、当サービスは次のデータを削除します。
              <ul className="pl-6 mt-2 space-y-1 text-sm text-gray-400">
                <li>(1) Cloud Firestore上のユーザープロフィール（users/&#123;uid&#125;）</li>
                <li>(2) Cloud Firestore上のデイリーログ等の投稿メタデータ（daily等）</li>
                <li>(3) Firebase Storage上の当該ユーザーに紐づく画像（JPEG等）および動画（MP4等）</li>
                <li>(4) Firebase Authentication上の認証情報</li>
              </ul>
            </li>
            <li>退会により、フレンド側の画面からは当該ユーザーのプロフィールおよび投稿は表示されなくなります。</li>
            <li>前各項にかかわらず、当サービスは、法令遵守、不正防止、セキュリティ確保、紛争対応のために必要なアクセスログ等を、必要な範囲で保持することがあります。</li>
            <li>技術的理由（バックアップ・キャッシュ等）により、第3項の削除が完了するまで一定期間を要することがあります。</li>
          </ol>
        </div>

        <div className="space-y-4">
          <h2 className="text-xl font-bold text-white border-l-4 border-blue-500 pl-4">第18条（利用制限・停止・削除等の措置）</h2>
          <ol className="list-decimal list-inside space-y-2">
            <li>当サービスは、ユーザーが第15条（禁止事項）に違反した場合、または不正利用が合理的に疑われる場合、事前通知なく次の措置を行うことができます。
              <ul className="pl-6 mt-2 space-y-1">
                <li>(1) 投稿の非表示または削除</li>
                <li>(2) 機能の一部停止</li>
                <li>(3) アカウントの一時停止</li>
                <li>(4) アカウント削除</li>
              </ul>
            </li>
            <li>当サービスは、前項の措置の理由をユーザーに開示する義務を負いません（法令により開示が必要な場合を除きます）。</li>
            <li>当サービスは、前項の措置によりユーザーに生じた損害について、当サービスに故意または重大な過失がある場合を除き責任を負いません。</li>
          </ol>
        </div>

        <div className="space-y-4">
          <h2 className="text-xl font-bold text-white border-l-4 border-blue-500 pl-4">第19条（データ保存に関する非保証）</h2>
          <ol className="list-decimal list-inside space-y-2">
            <li>当サービスは、ユーザーコンテンツを保存するためにFirebase Storage等を利用しますが、次の事項を保証しません。
              <ul className="pl-6 mt-2 space-y-1">
                <li>(1) データが消失しないこと</li>
                <li>(2) いつでも閲覧できること</li>
                <li>(3) 同期が常に成功すること</li>
              </ul>
            </li>
            <li>通信障害、端末不具合、外部サービス（Firebase）側の障害、当サービスの不具合等により、データが消失または閲覧不能となる可能性があります。</li>
          </ol>
        </div>

        <div className="space-y-4">
          <h2 className="text-xl font-bold text-white border-l-4 border-blue-500 pl-4">第20条（免責）</h2>
          <ol className="list-decimal list-inside space-y-2">
            <li>当サービスは現状有姿で提供されます。</li>
            <li>当サービスは、当サービスの正確性、完全性、特定目的適合性、継続性、バグが存在しないことを保証しません。</li>
            <li>当サービスは、当サービスに故意または重大な過失がある場合を除き、当サービスの利用または利用不能によりユーザーに生じた損害について責任を負いません。</li>
          </ol>
        </div>

        <div className="space-y-4">
          <h2 className="text-xl font-bold text-white border-l-4 border-blue-500 pl-4">第21条（責任制限：損害賠償上限）</h2>
          <ol className="list-decimal list-inside space-y-2">
            <li>当サービスが損害賠償責任を負う場合であっても、その責任の範囲および上限は、法令上許容される範囲に限定されます。</li>
            <li>当サービスの損害賠償責任の上限は、次のとおりとします。
              <ul className="pl-6 mt-2 space-y-1">
                <li>(1) 有料ユーザー：当該損害が発生した月の直近1か月にユーザーが当サービスに支払った利用料金</li>
                <li>(2) 無料ユーザー：0円</li>
              </ul>
            </li>
            <li>当サービスは、逸失利益、間接損害、特別損害、データ消失、機会損失、精神的損害について、当サービスに故意または重大な過失がある場合を除き責任を負いません。</li>
          </ol>
        </div>

        <div className="space-y-4">
          <h2 className="text-xl font-bold text-white border-l-4 border-blue-500 pl-4">第22条（サービスの停止・中断・終了）</h2>
          <ol className="list-decimal list-inside space-y-2">
            <li>当サービスは、次の場合、事前通知なく当サービスの全部または一部を停止または中断できます。
              <ul className="pl-6 mt-2 space-y-1">
                <li>(1) 保守点検または更新</li>
                <li>(2) 障害対応</li>
                <li>(3) 外部サービス（Firebase）の障害または停止</li>
                <li>(4) 天災、停電、通信障害等の不可抗力</li>
              </ul>
            </li>
            <li>当サービスは、運営上の都合により当サービスを終了することがあります。</li>
          </ol>
        </div>

        <div className="space-y-4">
          <h2 className="text-xl font-bold text-white border-l-4 border-blue-500 pl-4">第23条（連絡・問い合わせ）</h2>
          <ol className="list-decimal list-inside space-y-2">
            <li>当サービスからユーザーへの連絡は、アプリ内表示、プッシュ通知その他当サービスが適切と判断する方法で行います。</li>
            <li>
              ユーザーから当サービスへの問い合わせ窓口は次のとおりです。<br />
              <div className="mt-4 p-4 bg-yellow-500/10 border border-yellow-500/30 rounded">
                <p className="font-bold text-yellow-500 mb-1">問い合わせ先：</p>
                <p className="text-white">official.stillme@gmail.com</p>
                <p className="text-xs text-gray-500 mt-2">※お問い合わせは上記メールアドレスまでお願いいたします。</p>
              </div>
            </li>
          </ol>
        </div>

        <div className="space-y-4">
          <h2 className="text-xl font-bold text-white border-l-4 border-blue-500 pl-4">第24条（規約の変更）</h2>
          <ol className="list-decimal list-inside space-y-2">
            <li>当サービスは、本規約を変更することができます。</li>
            <li>変更後の規約は、当サービス上に掲示した時点から効力を生じます。</li>
            <li>ユーザーが変更後に当サービスを利用した場合、変更後の規約に同意したものとみなします。</li>
          </ol>
        </div>

        <div className="space-y-4">
          <h2 className="text-xl font-bold text-white border-l-4 border-blue-500 pl-4">第25条（準拠法・管轄）</h2>
          <ol className="list-decimal list-inside space-y-2">
            <li>本規約は日本法に準拠します。</li>
            <li>当サービスとユーザーとの間で紛争が生じた場合、日本の裁判所を第一審の管轄裁判所とします。</li>
          </ol>
        </div>

        <div className="mt-12 pt-8 border-t border-white/10 text-right">
          <p className="font-bold text-white">付則</p>
          <p className="text-sm">2026年2月22日 制定・施行</p>
        </div>
      </section>
    </div>
  );
}
