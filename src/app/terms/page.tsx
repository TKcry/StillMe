'use client';

import React, { useState, useEffect } from 'react';

export default function TermsOfService() {
  const [lang, setLang] = useState<'en' | 'ja'>('en');

  useEffect(() => {
    if (typeof window !== 'undefined' && navigator.language.startsWith('ja')) {
      setLang('ja');
    }
  }, []);


  return (
    <div className="max-w-4xl mx-auto py-12 px-6">
      <button
        onClick={() => window.history.back()}
        className="text-white hover:text-gray-300 transition-colors mb-6 flex items-center group"
        aria-label="Back"
      >
        <svg className="w-6 h-6" fill="none" stroke="currentColor" viewBox="0 0 24 24">
          <path strokeLinecap="round" strokeLinejoin="round" strokeWidth="2" d="M15 19l-7-7 7-7" />
        </svg>
      </button>

      <div className="flex justify-between items-start mb-8">
        <div>
          <h1 className="text-3xl font-bold mb-2">
            {lang === 'ja' ? '利用規約' : 'Terms of Service'}
          </h1>
          <p className="text-sm text-gray-400">
            {lang === 'ja' ? '最終更新日：2026年2月22日' : 'Last Updated: February 22, 2026'}
          </p>
        </div>
        <div className="relative">
          <select
            value={lang}
            onChange={(e) => setLang(e.target.value as 'en' | 'ja')}
            className="appearance-none pl-4 pr-10 py-2 bg-blue-600 hover:bg-blue-500 text-white rounded-full text-sm font-bold transition-colors shadow-lg cursor-pointer outline-none"
          >
            <option value="en">English</option>
            <option value="ja">日本語</option>
          </select>
          <div className="absolute inset-y-0 right-0 flex items-center pr-3 pointer-events-none text-white/80">
            <svg className="w-4 h-4" fill="none" stroke="currentColor" viewBox="0 0 24 24">
              <path strokeLinecap="round" strokeLinejoin="round" strokeWidth="2" d="M19 9l-7 7-7-7" />
            </svg>
          </div>
        </div>
      </div>

      <section className="space-y-8 text-gray-300">
        <div className="bg-white/5 p-6 rounded-lg border border-white/10">
          <p className="font-semibold text-white mb-2">
            {lang === 'ja' ? '運営：StillMe（以下「当サービス」といいます。）' : 'Operator: StillMe (hereinafter referred to as "the Service")'}
          </p>
          <p>
            {lang === 'ja' ?
              '本利用規約（以下「本規約」といいます。）は、当サービスが提供するモバイルアプリケーション「StillMe」および関連機能の利用条件を定めるものです。ユーザーは、本規約に同意したうえで当サービスを利用するものとします。' :
              'These Terms of Service (hereinafter referred to as the "Terms") define the conditions for using the mobile application "StillMe" and related features provided by the Service. Users shall use the Service upon agreeing to these Terms.'
            }
          </p>
        </div>

        {/* Article 1 */}
        <div className="space-y-4">
          <h2 className="text-xl font-bold text-white border-l-4 border-blue-500 pl-4">
            {lang === 'ja' ? '第1条（適用）' : 'Article 1 (Applicability)'}
          </h2>
          <ol className="list-decimal list-inside space-y-2">
            <li>{lang === 'ja' ? '本規約は、当サービスの利用に関する当サービスとユーザーとの間の一切の関係に適用されます。' : 'These Terms shall apply to all relationships between the Service and Users regarding the use of the Service.'}</li>
            <li>{lang === 'ja' ? '当サービスがアプリ内または当サービスが管理するWebページ上で掲載するガイドライン、注意事項、ヘルプ、運用ルール、プライバシーポリシーは、本規約の一部を構成します。' : 'Guidelines, precautions, help, operational rules, and the privacy policy posted by the Service within the app or on web pages managed by the Service shall constitute a part of these Terms.'}</li>
            <li>{lang === 'ja' ? '本規約と前項の内容が矛盾する場合、本規約が優先します（ただし、当サービスが個別に優先順位を明示した場合はその限りではありません）。' : 'In the event of any conflict between these Terms and the contents of the preceding paragraph, these Terms shall prevail (unless the Service explicitly states a different priority).'}</li>
            <li>{lang === 'ja' ? 'ユーザーが当サービスを利用した時点で、ユーザーは本規約に同意したものとみなします。' : 'By using the Service, the User is deemed to have agreed to these Terms.'}</li>
          </ol>
        </div>

        {/* Article 2 */}
        <div className="space-y-4">
          <h2 className="text-xl font-bold text-white border-l-4 border-blue-500 pl-4">
            {lang === 'ja' ? '第2条（定義）' : 'Article 2 (Definitions)'}
          </h2>
          <p>{lang === 'ja' ? '本規約において使用する用語を、次のとおり定義します。' : 'The terms used in these Terms are defined as follows:'}</p>
          <ul className="list-disc list-inside space-y-2">
            <li>{lang === 'ja' ? '「ユーザー」：当サービスを利用する個人。' : '"User": An individual who uses the Service.'}</li>
            <li>{lang === 'ja' ? '「アカウント」：ユーザーが当サービスを利用するために作成する認証情報およびそれに紐づく識別情報。' : '"Account": Authentication information created by the User to use the Service and the identification information associated with it.'}</li>
            <li>{lang === 'ja' ? '「フレンド」：ユーザー同士が相互承認により接続した関係（当サービス内の相互接続関係）。' : '"Friend": A relationship where Users are connected through mutual approval (interconnection within the Service).'}</li>
            <li>{lang === 'ja' ? '「投稿」：ユーザーが当サービスに写真・動画等をアップロードし、保存・共有状態にする行為。' : '"Post": The act of a User uploading photos, videos, etc., to the Service and making them stored or shared.'}</li>
            <li>{lang === 'ja' ? '「コンテンツ」：写真（JPEG等）、動画（MP4等）、テキスト、メタデータ（撮影日時・公開範囲・識別情報等）その他ユーザーが当サービス上で保存・表示・共有する情報。' : '"Content": Photos (JPEG, etc.), videos (MP4, etc.), text, metadata (shooting date/time, publication scope, identification info, etc.), and other information stored, displayed, or shared by the User on the Service.'}</li>
            <li>{lang === 'ja' ? '「ユーザーコンテンツ」：コンテンツのうち、ユーザーが当サービスに投稿・保存したもの。' : '"User Content": Content that the User has posted and stored in the Service.'}</li>
            <li>{lang === 'ja' ? '「公開範囲」：投稿時にユーザーが選択する閲覧可能な範囲。' : '"Publication Scope": The range of viewable access selected by the User at the time of posting.'}</li>
            <li>{lang === 'ja' ? '「外部サービス」：当サービスの提供に利用される第三者サービス（第7条で明示するFirebase等）。' : '"External Services": Third-party services used providing the Service (such as Firebase specified in Article 7).'}</li>
          </ul>
        </div>

        {/* Article 3 */}
        <div className="space-y-4">
          <h2 className="text-xl font-bold text-white border-l-4 border-blue-500 pl-4">
            {lang === 'ja' ? '第3条（アカウント）' : 'Article 3 (Account)'}
          </h2>
          <ol className="list-decimal list-inside space-y-2">
            <li>{lang === 'ja' ? 'ユーザーは、当サービス所定の方法によりアカウントを作成することで当サービスを利用できます。' : 'Users can use the Service by creating an account through the method prescribed by the Service.'}</li>
            <li>{lang === 'ja' ? 'ユーザーは、登録情報に変更があった場合、当サービス所定の方法で速やかに変更するものとします。' : 'If there is a change in registration information, the User shall promptly update it using the method prescribed by the Service.'}</li>
            <li>{lang === 'ja' ? 'アカウントの管理はユーザーの責任で行うものとし、ユーザーは第三者にアカウントを利用させてはなりません。' : 'The management of the account shall be the responsibility of the User, and the User must not allow a third party to use the account.'}</li>
            <li>{lang === 'ja' ? '当サービスは、当該アカウントを用いて行われた一切の行為を、当該アカウントを保有するユーザー本人の行為とみなします。' : 'The Service shall deem any and all acts performed using an account as acts performed by the User who holds said account.'}</li>
            <li>{lang === 'ja' ? 'ユーザーは、アカウントの不正利用が疑われる場合、速やかに第23条の窓口へ連絡するものとします。' : 'If unauthorized use of the account is suspected, the User shall promptly contact the window specified in Article 23.'}</li>
          </ol>
        </div>

        {/* Article 4 */}
        <div className="space-y-4">
          <h2 className="text-xl font-bold text-white border-l-4 border-blue-500 pl-4">
            {lang === 'ja' ? '第4条（年齢制限）' : 'Article 4 (Age Restriction)'}
          </h2>
          <ol className="list-decimal list-inside space-y-2">
            <li>{lang === 'ja' ? '13歳未満の方は当サービスを利用できません。' : 'Persons under the age of 13 cannot use the Service.'}</li>
            <li>{lang === 'ja' ? '未成年者が当サービスを利用する場合、親権者その他の法定代理人の同意を得たうえで利用するものとします。' : 'If a minor uses the Service, they shall do so after obtaining the consent of a parent or other legal guardian.'}</li>
            <li>{lang === 'ja' ? '未成年者が当サービスを利用した時点で、法定代理人の同意があったものとみなします。' : 'Upon usage of the Service by a minor, it shall be deemed that the consent of a legal guardian has been obtained.'}</li>
          </ol>
        </div>

        {/* Article 5 */}
        <div className="space-y-4">
          <h2 className="text-xl font-bold text-white border-l-4 border-blue-500 pl-4">
            {lang === 'ja' ? '第5条（当サービスの内容）' : 'Article 5 (Service Content)'}
          </h2>
          <p>{lang === 'ja' ? '当サービスは、次の機能を提供します。' : 'The Service provides the following features:'}</p>
          <ul className="list-disc list-inside space-y-2">
            <li>{lang === 'ja' ? 'フロントカメラおよびバックカメラによる撮影（同時または逐次）' : 'Photography using the front and back cameras (simultaneous or sequential)'}</li>
            <li>{lang === 'ja' ? '写真（JPEG等）および動画（MP4等）の投稿・保存' : 'Posting and storing photos (JPEG, etc.) and videos (MP4, etc.)'}</li>
            <li>{lang === 'ja' ? 'フレンド検索（ユーザーID／ハンドル等）および相互承認によるフレンド接続' : 'Friend search (User ID/handle, etc.) and friend connection through mutual approval'}</li>
            <li>{lang === 'ja' ? 'フィード（カード形式）での閲覧' : 'Viewing through a feed (card format)'}</li>
            <li>{lang === 'ja' ? 'カレンダー／履歴による日付単位の振り返り' : 'Reviewing by date via calendar/history'}</li>
            <li>{lang === 'ja' ? 'リマインダー通知（ユーザーによるON/OFF、通知時刻の設定）' : 'Reminder notifications (ON/OFF and notification time set by the User)'}</li>
            <li>{lang === 'ja' ? 'ウィークリー・アンロック（週の規定日数の投稿達成に応じた特別コンテンツ等の解放ロジック）' : 'Weekly Unlock (unlock logic for special content, etc., according to the achievement of the specified number of posts per week)'}</li>
            <li>{lang === 'ja' ? 'ブロック機能（特定ユーザーとの接点遮断）' : 'Block feature (blocking contact with specific users)'}</li>
            <li>{lang === 'ja' ? '通報機能（不適切コンテンツの報告）' : 'Reporting feature (reporting inappropriate content)'}</li>
            <li>{lang === 'ja' ? '非公開設定（他ユーザーからのID検索を拒否する設定）' : 'Privacy settings (settings to decline ID search from other users)'}</li>
            <li>{lang === 'ja' ? 'アカウント削除（退会）機能' : 'Account deletion (withdrawal) feature'}</li>
          </ul>
        </div>

        {/* Article 6 */}
        <div className="space-y-4">
          <h2 className="text-xl font-bold text-white border-l-4 border-blue-500 pl-4">
            {lang === 'ja' ? '第6条（公開範囲・共有）' : 'Article 6 (Publication Scope and Sharing)'}
          </h2>
          <ol className="list-decimal list-inside space-y-2">
            <li>{lang === 'ja' ? 'ユーザーは投稿時に、公開範囲として少なくとも次のいずれかを選択できます。' : 'At the time of posting, the User can select at least one of the following as the publication scope:'}
              <ul className="pl-6 mt-2 space-y-1">
                <li>{lang === 'ja' ? '(1) 「全フレンドに公開」：投稿時点で当該ユーザーと接続しているフレンド全員が閲覧可能' : '(1) "Public to all Friends": All friends connected with the User at the time of posting can view it.'}</li>
                <li>{lang === 'ja' ? '(2) 「特定フレンドに公開」：投稿時点で当該ユーザーが指定したフレンドのみが閲覧可能' : '(2) "Public to specific Friends": Only friends designated by the User at the time of posting can view it.'}</li>
              </ul>
            </li>
            <li>{lang === 'ja' ? 'ユーザーは、公開範囲の選択が閲覧可能者を直接決定することを理解し、自らの責任で公開範囲を設定するものとします。' : 'The User understands that the selection of the publication scope directly determines the viewers and shall set the publication scope on their own responsibility.'}</li>
            <li>{lang === 'ja' ? 'フレンド関係が成立していないユーザーは、当該投稿を閲覧できません（当サービスが別途公開型機能を提供する場合を除きます）。' : 'Users without an established friend relationship cannot view said posts (except where the Service provides separate public features).'}</li>
            <li>{lang === 'ja' ? '当サービスの仕様上、フレンド解除またはブロックにより共有権限が失効した場合、相手ユーザーは当該投稿を閲覧できなくなります（第9条）。' : 'Due to the specifications of the Service, if sharing permissions are revoked due to unfriending or blocking, the other user will no longer be able to view the post (Article 9).'}</li>
          </ol>
        </div>

        {/* Article 7 */}
        <div className="space-y-4">
          <h2 className="text-xl font-bold text-white border-l-4 border-blue-500 pl-4">
            {lang === 'ja' ? '第7条（外部サービス：Firebaseの利用と保存場所）' : 'Article 7 (External Services: Use of Firebase and Storage Location)'}
          </h2>
          <ol className="list-decimal list-inside space-y-2">
            <li>{lang === 'ja' ? '当サービスは、Google LLC が提供する「Firebase」を利用します。' : 'The Service uses "Firebase" provided by Google LLC.'}</li>
            <li>{lang === 'ja' ? '当サービスが利用するFirebaseの機能は、次のとおりです。' : 'The Firebase features used by the Service are as follows:'}
              <ul className="pl-6 mt-2 space-y-1 text-sm text-gray-400">
                <li>{lang === 'ja' ? '(1) Firebase Authentication（アカウント認証）' : '(1) Firebase Authentication (Account authentication)'}</li>
                <li>{lang === 'ja' ? '(2) Cloud Firestore（プロフィール、フレンド関係、投稿メタデータ等の保存）' : '(2) Cloud Firestore (Storage of profiles, friend relations, post metadata, etc.)'}</li>
                <li>{lang === 'ja' ? '(3) Firebase Storage（写真・動画ファイルの保存）' : '(3) Firebase Storage (Storage of photo and video files)'}</li>
              </ul>
            </li>
            <li>{lang === 'ja' ? 'ユーザーのデータは、Firebaseが稼働するGoogle Cloudのインフラ上に保存されます。' : "User data is stored on Google Cloud infrastructure where Firebase operates."}</li>
            <li>{lang === 'ja' ? '当サービスは、Google Cloud（Firebase）のUSリージョンを利用します。したがって、ユーザーのデータは米国に設置されたサーバー上に保存されます。' : 'The Service uses the US region for Google Cloud (Firebase). Therefore, User data is stored on servers located in the United States.'}</li>
            <li>{lang === 'ja' ? 'ユーザーは、前項の保存場所（米国）に同意したうえで当サービスを利用するものとします。' : 'Users shall use the Service upon agreeing to the storage location (United States) mentioned in the preceding paragraph.'}</li>
          </ol>
        </div>

        {/* Article 8 */}
        <div className="space-y-4">
          <h2 className="text-xl font-bold text-white border-l-4 border-blue-500 pl-4">
            {lang === 'ja' ? '第8条（フレンド：成立）' : 'Article 8 (Friends: Formation)'}
          </h2>
          <ol className="list-decimal list-inside space-y-2">
            <li>{lang === 'ja' ? 'フレンド関係は、一方の招待に対し、他方が承認した場合に成立します（相互承認制）。' : 'A friend relationship is formed when one party accepts an invitation from the other (mutual approval system).'}</li>
            <li>{lang === 'ja' ? 'フレンド関係が成立するまで、当該相手ユーザーに対して投稿の共有は行われません。' : 'Posts will not be shared with the other user until a friend relationship is formed.'}</li>
          </ol>
        </div>

        {/* Article 9 */}
        <div className="space-y-4">
          <h2 className="text-xl font-bold text-white border-l-4 border-blue-500 pl-4">
            {lang === 'ja' ? '第9条（フレンド解除・ブロック：相互削除と閲覧権限の失効）' : 'Article 9 (Unfriend and Block: Mutual Deletion and Loss of Access Rights)'}
          </h2>
          <div className="pl-4 border-l-2 border-white/5 ml-2">
            <h3 className="font-semibold text-white mb-2 decoration-blue-500/50 underline-offset-4 underline">
              {lang === 'ja' ? '1. フレンド解除（解除の効果）' : '1. Unfriending (Effect of Unfriending)'}
            </h3>
            <ul className="list-disc list-inside space-y-2 ml-2">
              <li>{lang === 'ja' ? 'ユーザーは、当サービス所定の方法により、いつでもフレンド解除を行うことができます。' : 'Users can unfriend at any time using the method prescribed by the Service.'}</li>
              <li>{lang === 'ja' ? 'いずれか一方がフレンド解除を行った場合、Cloud Firestore上の相互接続データ（pairRefs）を削除します（相互削除）。' : 'If either party unfriends, the interconnection data (pairRefs) on Cloud Firestore will be deleted (mutual deletion).'}</li>
              <li>{lang === 'ja' ? '前項の削除により、解除は双方に即時反映され、相手側のフレンド一覧から当該ユーザーの表示が消えます。' : 'Due to the deletion in the preceding paragraph, the unfriend action is immediately reflected for both parties, and the User will disappear from the other party\'s friend list.'}</li>
              <li>{lang === 'ja' ? 'フレンド解除後、相手ユーザーは当該ユーザーのプロフィールおよび投稿を一切閲覧できません。' : 'After unfriending, the other user cannot view the User\'s profile or posts at all.'}</li>
              <li>{lang === 'ja' ? 'フレンド解除は、当該相手ユーザーに付与されていた「閲覧・共有の権限」を失効させるものです。投稿データ自体（写真・動画・メタデータ）は、投稿者のアカウントに保持されます。' : 'Unfriending revokes the "viewing and sharing permissions" granted to the other user. The post data itself (photos, videos, metadata) is retained in the poster\'s account.'}</li>
            </ul>

            <h3 className="font-semibold text-white mt-6 mb-2 decoration-blue-500/50 underline-offset-4 underline">
              {lang === 'ja' ? '2. ブロック（ブロックの効果）' : '2. Blocking (Effect of Blocking)'}
            </h3>
            <ul className="list-disc list-inside space-y-2 ml-2">
              <li>{lang === 'ja' ? 'ユーザーは、当サービス所定の方法により、特定ユーザーをブロックできます。' : 'Users can block specific users using the method prescribed by the Service.'}</li>
              <li>{lang === 'ja' ? 'ブロックは、当該ユーザーとの接点を遮断する措置であり、ブロックが行われた場合、当サービスは当該ユーザーとのフレンド関係を維持しません（pairRefsの削除を含みます）。' : 'Blocking is a measure to cut off contact with said user. If a block is performed, the Service will not maintain a friend relationship with said user (including deletion of pairRefs).'}</li>
              <li>{lang === 'ja' ? 'ブロック後、双方は互いのプロフィールおよび投稿を閲覧できません。' : 'After blocking, both parties cannot view each other\'s profile or posts.'}</li>
              <li>{lang === 'ja' ? '当サービスは、ブロックの有無や理由を相手に通知する義務を負いません。' : 'The Service has no obligation to notify the other party of the existence or reason for the block.'}</li>
            </ul>

            <h3 className="font-semibold text-white mt-6 mb-2 decoration-blue-500/50 underline-offset-4 underline">
              {lang === 'ja' ? '3. 再接続' : '3. Reconnection'}
            </h3>
            <ul className="list-disc list-inside space-y-2 ml-2">
              <li>{lang === 'ja' ? 'フレンド解除またはブロック後に再度接続する場合、改めて招待・承認の手続が必要です。' : 'To reconnect after unfriending or blocking, new invitation and approval procedures are required.'}</li>
              <li>{lang === 'ja' ? '新たなフレンド関係が成立しない限り、解除前に投稿者側に保持されている過去データであっても、相手は閲覧できません。' : 'Unless a new friend relationship is established, the other party cannot view past data retained on the poster\'s side prior to the detachment.'}</li>
            </ul>
          </div>
        </div>

        {/* Article 10 */}
        <div className="space-y-4">
          <h2 className="text-xl font-bold text-white border-l-4 border-blue-500 pl-4">
            {lang === 'ja' ? '第10条（スクリーンショット等の保存可能性）' : 'Article 10 (Possibility of Saving via Screenshots, etc.)'}
          </h2>
          <ol className="list-decimal list-inside space-y-2">
            <li>{lang === 'ja' ? 'ユーザーは、共有されたコンテンツについて、相手ユーザーがスクリーンショット、画面収録、外部端末による撮影等により保存する可能性があることを了承します。' : 'The User acknowledges that shared content may be saved by the other user via screenshots, screen recording, photography by external devices, etc.'}</li>
            <li>{lang === 'ja' ? '当サービスは、前項の保存行為を技術的に完全に防止することはできません。' : 'The Service cannot technically completely prevent the saving acts mentioned in the preceding paragraph.'}</li>
            <li>{lang === 'ja' ? 'フレンド解除・ブロック・退会により当サービス上の閲覧権限が失効しても、相手ユーザーが前項の方法で既に保存したデータの削除まで当サービスが保証するものではありません。' : 'Even if the viewing rights on the Service expire due to unfriending, blocking, or withdrawal, the Service does not guarantee the deletion of data already saved by the other user through the methods in the preceding paragraph.'}</li>
          </ol>
        </div>

        {/* Article 11 */}
        <div className="space-y-4">
          <h2 className="text-xl font-bold text-white border-l-4 border-blue-500 pl-4">
            {lang === 'ja' ? '第11条（ユーザーコンテンツの権利帰属）' : 'Article 11 (Ownership of User Content)'}
          </h2>
          <ol className="list-decimal list-inside space-y-2">
            <li>{lang === 'ja' ? 'ユーザーコンテンツに関する著作権その他の権利は、投稿したユーザーまたは正当な権利者に帰属します。' : 'Copyrights and other rights regarding User Content belong to the User who posted it or to the legitimate right holders.'}</li>
            <li>{lang === 'ja' ? 'ユーザーは、ユーザーコンテンツを投稿するにあたり、当該コンテンツの投稿・共有に必要な権利（被写体の同意、第三者の著作物利用許諾等）を有していることを保証します。' : 'In posting User Content, the User guarantees that they possess the necessary rights (consent of the subject, permission to use a third party\'s work, etc.) required for the posting and sharing of said content.'}</li>
            <li>{lang === 'ja' ? 'ユーザーが前項に違反して第三者との間で紛争が生じた場合、ユーザーは自己の費用と責任でこれを解決し、当サービスに損害を与えないものとします。' : 'In the event of a dispute with a third party due to the User violating the preceding paragraph, the User shall resolve it at their own expense and responsibility and shall not cause any damage to the Service.'}</li>
          </ol>
        </div>

        {/* Article 12 */}
        <div className="space-y-4">
          <h2 className="text-xl font-bold text-white border-l-4 border-blue-500 pl-4">
            {lang === 'ja' ? '第12条（ユーザーコンテンツの利用許諾）' : 'Article 12 (License to Use User Content)'}
          </h2>
          <ol className="list-decimal list-inside space-y-2">
            <li>{lang === 'ja' ? 'ユーザーは、当サービスに対し、当サービスの提供に必要な範囲でユーザーコンテンツを利用する権利を許諾します。許諾の範囲は次のとおりです。' : 'The User grants the Service the right to use User Content within the scope necessary for providing the Service. The scope of the license is as follows:'}
              <ul className="pl-6 mt-2 space-y-1 text-sm text-gray-400">
                <li>{lang === 'ja' ? '(1) サーバーへの保存' : '(1) Storage on servers'}</li>
                <li>{lang === 'ja' ? '(2) 端末・通信環境に応じた最適化のための変換（サイズ変更、圧縮、形式変換等）' : '(2) Conversion for optimization according to device and network environments (resizing, compression, format conversion, etc.)'}</li>
                <li>{lang === 'ja' ? '(3) 公開範囲に応じた配信・表示（フレンドへの表示を含む）' : '(3) Distribution and display according to the publication scope (including display to friends)'}</li>
                <li>{lang === 'ja' ? '(4) 障害対応・不正対策・サポート対応のために必要な処理' : '(4) Processing required for troubleshooting, anti-fraud measures, and support responses'}</li>
              </ul>
            </li>
            <li>{lang === 'ja' ? '前項の許諾は、非独占的かつ無償であり、ユーザーコンテンツの権利帰属を移転するものではありません。' : 'The license in the preceding paragraph is non-exclusive and free of charge and does not transfer the ownership of rights to User Content.'}</li>
            <li>{lang === 'ja' ? '当サービスは、ユーザーの明示的同意なく、ユーザーコンテンツを第三者に販売しません。' : 'The Service will not sell User Content to a third party without the User\'s explicit consent.'}</li>
          </ol>
        </div>

        {/* Article 13 */}
        <div className="space-y-4">
          <h2 className="text-xl font-bold text-white border-l-4 border-blue-500 pl-4">
            {lang === 'ja' ? '第13条（動画に関する特則）' : 'Article 13 (Special Provisions Regarding Video)'}
          </h2>
          <ol className="list-decimal list-inside space-y-2">
            <li>{lang === 'ja' ? '現時点において、当サービスに投稿される動画には音声は含まれません。' : 'At the present time, videos posted to the Service do not contain audio.'}</li>
            <li>{lang === 'ja' ? '現時点において、当サービスは動画にBGMを付与しません。' : 'At the present time, the Service does not add BGM to videos.'}</li>
            <li>{lang === 'ja' ? '将来、Spotify等の外部音楽サービス連携機能を導入する場合、当サービスは導入時に必要な利用条件（対象機能、連携方法、適用規約、権利処理等）を当サービス上で明示します。' : 'If features for integration with external music services such as Spotify are introduced in the future, the Service will clarify the necessary terms of use (target features, integration method, applicable terms, rights handling, etc.) within the Service upon introduction.'}</li>
            <li>{lang === 'ja' ? '動画はFirebase Storageに保存されますが、当サービスは、データが永続的に保存されること、または常に復元可能であることを保証しません（第20条参照）。' : 'Videos are stored in Firebase Storage, but the Service does not guarantee that data will be stored permanently or that it will always be restorable (see Article 20).'}</li>
            <li>{lang === 'ja' ? '当サービスは、現時点で「過去の記録をまとめた自動生成動画（タイムラプス等）の生成・再生成」を提供していません。将来導入する場合は、第3項と同様に条件を明示します。' : 'The Service currently does not provide "generation or regeneration of automatically generated videos summarizing past records (time-lapses, etc.)". If introduced in the future, terms will be clarified as in paragraph 3.'}</li>
          </ol>
        </div>

        {/* Article 14 */}
        <div className="space-y-4">
          <h2 className="text-xl font-bold text-white border-l-4 border-blue-500 pl-4">
            {lang === 'ja' ? '第14条（通報）' : 'Article 14 (Reporting)'}
          </h2>
          <ol className="list-decimal list-inside space-y-2">
            <li>{lang === 'ja' ? 'ユーザーは、当サービス所定の方法により、不適切なコンテンツを通報できます。' : 'Users can report inappropriate content through the method prescribed by the Service.'}</li>
            <li>{lang === 'ja' ? '通報は、当サービスが管理するCloud Firestoreの「reports」コレクションへの情報送信として記録されます。' : 'Reports are recorded as information transmission to the "reports" collection in Cloud Firestore managed by the Service.'}</li>
            <li>{lang === 'ja' ? '当サービスは、通報内容を確認し、必要に応じて第18条に定める措置を行います。' : 'The Service will verify the content of the report and take measures defined in Article 18 as necessary.'}</li>
            <li>{lang === 'ja' ? '当サービスは、通報者に対し、対応結果や対応理由を個別に回答する義務を負いません。' : 'The Service has no obligation to individually reply to the reporter regarding results or reasons for the response.'}</li>
          </ol>
        </div>

        {/* Article 15 */}
        <div className="space-y-4">
          <h2 className="text-xl font-bold text-white border-l-4 border-blue-500 pl-4">
            {lang === 'ja' ? '第15条（禁止事項）' : 'Article 15 (Prohibited Actions)'}
          </h2>
          <p>{lang === 'ja' ? 'ユーザーは、次の行為をしてはなりません。' : 'Users must not perform the following actions:'}</p>
          <ul className="list-disc list-inside space-y-2">
            <li>{lang === 'ja' ? '法令または公序良俗に違反する行為' : 'Actions that violate laws, regulations, or public order and standards of decency.'}</li>
            <li>{lang === 'ja' ? '当サービスまたは第三者の著作権、商標権、肖像権、プライバシー権、名誉権その他の権利利益を侵害する行為' : 'Actions that infringe upon the copyrights, trademarks, portrait rights, privacy rights, honor rights, or other rights and interests of the Service or a third party.'}</li>
            <li>{lang === 'ja' ? '誹謗中傷、脅迫、差別、嫌がらせ、ストーキング、またはこれらを助長する行為' : 'Slander, threats, discrimination, harassment, stalking, or actions that promote these.'}</li>
            <li>{lang === 'ja' ? 'なりすまし、虚偽の登録、アカウントの譲渡・売買・貸与' : 'Impersonation, false registration, or the transfer, sale, or lending of an account.'}</li>
            <li>{lang === 'ja' ? 'わいせつ表現、児童性的虐待に該当または関連するコンテンツ、過度に暴力的な表現、自傷・自殺を助長する表現、薬物の不正利用を助長する表現を含むコンテンツの投稿' : 'Posting content that includes obscene expressions, content that corresponds to or is related to Child Sexual Abuse Material (CSAM), excessively violent expressions, expressions that promote self-harm or suicide, or expressions that promote the illegal use of drugs.'}</li>
            <li>{lang === 'ja' ? '当サービスまたは外部サービスへの不正アクセス、リバースエンジニアリング、解析、改変、脆弱性の悪用' : 'Unauthorized access to the Service or External Services, reverse engineering, analysis, modification, or exploitation of vulnerabilities.'}</li>
            <li>{lang === 'ja' ? '当サービスのサーバーに過度の負荷を与える行為、ボット等による不正利用' : 'Actions that impose an excessive load on the servers of the Service, or unauthorized use via bots, etc.'}</li>
            <li>{lang === 'ja' ? '当サービスの運営、通報対応、審査、モデレーションを妨害する行為' : 'Actions that interfere with the operation of the Service, response to reports, review, or moderation.'}</li>
            <li>{lang === 'ja' ? 'その他、当サービスが合理的な理由に基づき不適切と判断する行為' : 'Other actions deemed inappropriate by the Service based on reasonable grounds.'}</li>
          </ul>
        </div>

        {/* Article 16 */}
        <div className="space-y-4">
          <h2 className="text-xl font-bold text-white border-l-4 border-blue-500 pl-4">
            {lang === 'ja' ? '第16条（フレンド数の制限・課金）' : 'Article 16 (Friend Limit and Billing)'}
          </h2>
          <ol className="list-decimal list-inside space-y-2">
            <li>{lang === 'ja' ? '現時点において、当サービスはフレンド登録数の上限を設けません（無料で無制限）。' : 'At the present time, the Service does not set an upper limit on the number of friend registrations (unlimited for free).'}</li>
            <li>{lang === 'ja' ? '当サービスは、将来的に有料プラン（サブスクリプション等）を導入する場合があります。' : 'The Service may introduce paid plans (subscriptions, etc.) in the future.'}</li>
            <li>{lang === 'ja' ? '有料プランを導入する場合、当サービスは、料金、課金周期、自動更新の有無、解約方法、提供機能、無料トライアルの有無をアプリ内で明示します。' : 'If paid plans are introduced, the Service will clarify the price, billing cycle, existence of automatic renewal, cancellation method, provided features, and existence of free trials within the app.'}</li>
            <li>{lang === 'ja' ? '課金および返金は、プラットフォーム（例：Apple）の規約および運用に従います。' : 'Billing and refunds shall follow the terms and operations of the platform (e.g., Apple).'}</li>
          </ol>
        </div>

        {/* Article 17 */}
        <div className="space-y-4">
          <h2 className="text-xl font-bold text-white border-l-4 border-blue-500 pl-4">
            {lang === 'ja' ? '第17条（アカウント削除・退会とデータ削除）' : 'Article 17 (Account Deletion, Withdrawal, and Data Deletion)'}
          </h2>
          <ol className="list-decimal list-inside space-y-2">
            <li>{lang === 'ja' ? 'ユーザーは、当サービス所由の方法により、いつでもアカウント削除（退会）できます。' : 'Users can delete their account (withdraw) at any time through the method prescribed by the Service.'}</li>
            <li>{lang === 'ja' ? '当サービスは、退会後、最大30日間、復旧対応のためにユーザーのデータ（プロフィール、投稿、関連メタデータ、認証情報）を保持します。' : 'The Service will retain User data (profile, posts, related metadata, authentication info) for up to 30 days after withdrawal for restoration purposes.'}</li>
            <li>{lang === 'ja' ? '退会後30日が経過した時点で、当サービスは次のデータを削除します。' : 'After 30 days have elapsed since withdrawal, the Service will delete the following data:'}
              <ul className="pl-6 mt-2 space-y-1 text-sm text-gray-400">
                <li>{lang === 'ja' ? '(1) Cloud Firestore上のユーザープロフィール（users/{uid}）' : '(1) User profile on Cloud Firestore (users/{uid})'}</li>
                <li>{lang === 'ja' ? '(2) Cloud Firestore上のデイリーログ等の投稿メタデータ（daily等）' : '(2) Post metadata such as daily logs on Cloud Firestore (daily, etc.)'}</li>
                <li>{lang === 'ja' ? '(3) Firebase Storage上の当該ユーザーに紐づく画像（JPEG等）および動画（MP4等）' : '(3) Images (JPEG, etc.) and videos (MP4, etc.) associated with said User on Firebase Storage'}</li>
                <li>{lang === 'ja' ? '(4) Firebase Authentication上の認証情報' : '(4) Authentication info on Firebase Authentication'}</li>
              </ul>
            </li>
            <li>{lang === 'ja' ? '退会により、フレンド側の画面からは当該ユーザーのプロフィールおよび投稿は表示されなくなります。' : 'Upon withdrawal, the User\'s profile and posts will no longer be displayed on the screens of friends.'}</li>
            <li>{lang === 'ja' ? '前各項にかかわらず、当サービスは、法令遵守、不正防止、セキュリティ確保、紛争対応のために必要なアクセスログ等を、必要な範囲で保持することがあります。' : 'Notwithstanding the preceding paragraphs, the Service may retain access logs, etc., as necessary for legal compliance, fraud prevention, safety and security, and dispute resolution.'}</li>
            <li>{lang === 'ja' ? '技術的理由（バックアップ・キャッシュ等）により、第3項の削除が完了するまで一定期間を要することがあります。' : 'Due to technical reasons (backup, cache, etc.), it may take a certain period for the deletion in paragraph 3 to be completed.'}</li>
          </ol>
        </div>

        {/* Article 18 */}
        <div className="space-y-4">
          <h2 className="text-xl font-bold text-white border-l-4 border-blue-500 pl-4">
            {lang === 'ja' ? '第18条（利用制限・停止・削除等の措置）' : 'Article 18 (Usage Restrictions, Suspension, Deletion, etc.)'}
          </h2>
          <ol className="list-decimal list-inside space-y-2">
            <li>{lang === 'ja' ? '当サービスは、ユーザーが第15条（禁止事項）に違反した場合、または不正利用が合理的に疑われる場合、事前通知なく次の措置を行うことができます。' : 'If a User violates Article 15 (Prohibited Actions) or if unauthorized use is reasonably suspected, the Service may take the following measures without prior notice:'}
              <ul className="pl-6 mt-2 space-y-1">
                <li>{lang === 'ja' ? '(1) 投稿の非表示または削除' : '(1) Hiding or deletion of posts'}</li>
                <li>{lang === 'ja' ? '(2) 機能の一部停止' : '(2) Partial suspension of features'}</li>
                <li>{lang === 'ja' ? '(3) アカウントの一時停止' : '(3) Temporary suspension of the account'}</li>
                <li>{lang === 'ja' ? '(4) アカウント削除' : '(4) Account deletion'}</li>
              </ul>
            </li>
            <li>{lang === 'ja' ? '当サービスは、前項の措置の理由をユーザーに開示する義務を負いません（法令により開示が必要な場合を除きます）。' : 'The Service has no obligation to disclose the reason for the measures in the preceding paragraph to the User (unless disclosure is required by law).'}</li>
            <li>{lang === 'ja' ? '当サービスは、前項の措置によりユーザーに生じた損害について、当サービスに故意または重大な過失がある場合を除き責任を負いません。' : 'The Service shall not be liable for any damage caused to the User by the measures in the preceding paragraph, unless there is intentional misconduct or gross negligence on the part of the Service.'}</li>
          </ol>
        </div>

        {/* Article 19 */}
        <div className="space-y-4">
          <h2 className="text-xl font-bold text-white border-l-4 border-blue-500 pl-4">
            {lang === 'ja' ? '第19条（データ保存に関する非保証）' : 'Article 19 (Non-Guarantee of Data Preservation)'}
          </h2>
          <ol className="list-decimal list-inside space-y-2">
            <li>{lang === 'ja' ? '当サービスは、ユーザーコンテンツを保存するためにFirebase Storage等を利用しますが、次の事項を保証しません。' : 'The Service uses Firebase Storage, etc., to store User Content, but does not guarantee the following:'}
              <ul className="pl-6 mt-2 space-y-1">
                <li>{lang === 'ja' ? '(1) データが消失しないこと' : '(1) That data will not be lost'}</li>
                <li>{lang === 'ja' ? '(2) いつでも閲覧できること' : '(2) That it can be viewed at any time'}</li>
                <li>{lang === 'ja' ? '(3) 同期が常に成功すること' : '(3) That synchronization will always succeed'}</li>
              </ul>
            </li>
            <li>{lang === 'ja' ? '通信障害、端末不具合、外部サービス（Firebase）側の障害、当サービスの不具合等により、データが消失または閲覧不能となる可能性があります。' : 'Data may be lost or become unviewable due to communication failures, device malfunctions, failures on the part of external services (Firebase), or malfunctions of the Service.'}</li>
          </ol>
        </div>

        {/* Article 20 */}
        <div className="space-y-4">
          <h2 className="text-xl font-bold text-white border-l-4 border-blue-500 pl-4">
            {lang === 'ja' ? '第20条（免責）' : 'Article 20 (Disclaimer)'}
          </h2>
          <ol className="list-decimal list-inside space-y-2">
            <li>{lang === 'ja' ? '当サービスは現状有姿で提供されます。' : 'The Service is provided on an "as is" basis.'}</li>
            <li>{lang === 'ja' ? '当サービスは、当サービスの正確性、完全性、特定目的適合性、継続性、バグが存在しないことを保証しません。' : 'The Service does not guarantee the accuracy, completeness, fitness for a particular purpose, continuity, or absence of bugs of the Service.'}</li>
            <li>{lang === 'ja' ? '当サービスは、当サービスに故意または重大な過失がある場合を除き、当サービスの利用または利用不能によりユーザーに生じた損害について責任を負いません。' : 'The Service shall not be liable for any damage caused to the User by the use or inability to use the Service, unless there is intentional misconduct or gross negligence on the part of the Service.'}</li>
          </ol>
        </div>

        {/* Article 21 */}
        <div className="space-y-4">
          <h2 className="text-xl font-bold text-white border-l-4 border-blue-500 pl-4">
            {lang === 'ja' ? '第21条（責任制限：損害賠償上限）' : 'Article 21 (Limitation of Liability: Maximum Amount of Damages)'}
          </h2>
          <ol className="list-decimal list-inside space-y-2">
            <li>{lang === 'ja' ? '当サービスが損害賠償責任を負う場合であっても、その責任の範囲および上限は、法令上許容される範囲に限定されます。' : 'Even in cases where the Service bears liability for damages, the scope and upper limit of such liability shall be limited to the extent permitted by law.'}</li>
            <li>{lang === 'ja' ? '当サービスの損害賠償責任の上限は、次のとおりとします。' : 'The upper limit of the Service\'s liability for damages shall be as follows:'}
              <ul className="pl-6 mt-2 space-y-1">
                <li>{lang === 'ja' ? '(1) 有料ユーザー：当該損害が発生した月の直近1か月にユーザーが当サービスに支払った利用料金' : '(1) Paid Users: The usage fee paid by the User to the Service in the most recent one month prior to the month in which the damage occurred.'}</li>
                <li>{lang === 'ja' ? '(2) 無料ユーザー：0円' : '(2) Free Users: 0 yen.'}</li>
              </ul>
            </li>
            <li>{lang === 'ja' ? '当サービスは、逸失利益、間接損害、特別損害、データ消失、機会損失、精神的損害について、当サービスに故意または重大な過失がある場合を除き責任を負いません。' : 'The Service shall not be liable for lost profits, indirect damages, special damages, data loss, loss of opportunity, or emotional distress, unless there is intentional misconduct or gross negligence on the part of the Service.'}</li>
          </ol>
        </div>

        {/* Article 22 */}
        <div className="space-y-4">
          <h2 className="text-xl font-bold text-white border-l-4 border-blue-500 pl-4">
            {lang === 'ja' ? '第22条（サービスの停止・中断・終了）' : 'Article 22 (Suspension, Interruption, and Termination of Service)'}
          </h2>
          <ol className="list-decimal list-inside space-y-2">
            <li>{lang === 'ja' ? '当サービスは、次の場合、事前通知なく当サービスの全部または一部を停止または中断できます。' : 'The Service may suspend or interrupt all or part of the Service without prior notice in the following cases:'}
              <ul className="pl-6 mt-2 space-y-1">
                <li>{lang === 'ja' ? '(1) 保守点検または更新' : '(1) Maintenance inspection or updates'}</li>
                <li>{lang === 'ja' ? '(2) 障害対応' : '(2) Troubleshooting of failures'}</li>
                <li>{lang === 'ja' ? '(3) 外部サービス（Firebase）の障害または停止' : '(3) Failure or suspension of External Services (Firebase)'}</li>
                <li>{lang === 'ja' ? '(4) 天災、停電、通信障害等の不可抗力' : '(4) Force majeure such as natural disasters, power outages, or network failures'}</li>
              </ul>
            </li>
            <li>{lang === 'ja' ? '当サービスは、運営上の都合により当サービスを終了することがあります。' : 'The Service may terminate the Service due to operational reasons.'}</li>
          </ol>
        </div>

        {/* Article 23 */}
        <div className="space-y-4">
          <h2 className="text-xl font-bold text-white border-l-4 border-blue-500 pl-4">
            {lang === 'ja' ? '第23条（連絡・問い合わせ）' : 'Article 23 (Contact and Inquiry)'}
          </h2>
          <ol className="list-decimal list-inside space-y-2">
            <li>{lang === 'ja' ? '当サービスからユーザーへの連絡は、アプリ内表示、プッシュ通知その他当サービスが適切と判断する方法で行います。' : 'Communication from the Service to Users will be made via in-app displays, push notifications, or other methods deemed appropriate by the Service.'}</li>
            <li>
              {lang === 'ja' ? 'ユーザーから当サービスへの問い合わせ窓口は次のとおりです。' : 'The window for inquiries from Users to the Service is as follows:'}<br />
              <div className="mt-4 p-4 bg-yellow-500/10 border border-yellow-500/30 rounded">
                <p className="font-bold text-yellow-500 mb-1">
                  {lang === 'ja' ? '問い合わせ先：' : 'Contact Information:'}
                </p>
                <p className="text-white">official.stillme@gmail.com</p>
                <p className="text-xs text-gray-500 mt-2">
                  {lang === 'ja' ? '※お問い合わせは上記メールアドレスまでお願いいたします。' : '*Please send inquiries to the above email address.'}
                </p>
              </div>
            </li>
          </ol>
        </div>

        {/* Article 24 */}
        <div className="space-y-4">
          <h2 className="text-xl font-bold text-white border-l-4 border-blue-500 pl-4">
            {lang === 'ja' ? '第24条（規約の変更）' : 'Article 24 (Modification of Terms)'}
          </h2>
          <ol className="list-decimal list-inside space-y-2">
            <li>{lang === 'ja' ? '当サービスは、本規約を変更することができます。' : 'The Service may modify these Terms.'}</li>
            <li>{lang === 'ja' ? '変更後の規約は、当サービス上に掲示した時点から効力を生じます。' : 'The modified Terms shall take effect from the time they are posted on the Service.'}</li>
            <li>{lang === 'ja' ? 'ユーザーが変更後に当サービスを利用した場合、変更後の規約に同意したものとみなします。' : 'By using the Service after modification, the User is deemed to have agreed to the modified Terms.'}</li>
          </ol>
        </div>

        {/* Article 25 */}
        <div className="space-y-4">
          <h2 className="text-xl font-bold text-white border-l-4 border-blue-500 pl-4">
            {lang === 'ja' ? '第25条（準拠法・管轄）' : 'Article 25 (Governing Law and Jurisdiction)'}
          </h2>
          <ol className="list-decimal list-inside space-y-2">
            <li>{lang === 'ja' ? '本規約は日本法に準拠します。' : 'These Terms shall be governed by the laws of Japan.'}</li>
            <li>{lang === 'ja' ? '当サービスとユーザーとの間で紛争が生じた場合、日本の裁判所を第一審の管轄裁判所とします。' : 'In the event of a dispute between the Service and a User, the courts of Japan shall have exclusive jurisdiction as the court of first instance.'}</li>
          </ol>
        </div>

        <div className="mt-12 pt-8 border-t border-white/10 text-right">
          <p className="font-bold text-white">{lang === 'ja' ? '付則' : 'Supplementary Provisions'}</p>
          <p className="text-sm">
            {lang === 'ja' ? '2026年2月22日 制定・施行' : 'Enacted and Effective: February 22, 2026'}
          </p>
        </div>
      </section>
    </div>
  );
}
