'use client';

import React, { useState, useEffect } from 'react';

export default function PrivacyPolicy() {
    const [lang, setLang] = useState<'en' | 'ja'>('en');

    useEffect(() => {
        if (typeof window !== 'undefined' && navigator.language.startsWith('ja')) {
            setLang('ja');
        }
    }, []);


    const contactEmail = 'official.stillme@gmail.com';

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
                        {lang === 'ja' ? 'プライバシーポリシー' : 'Privacy Policy'}
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
                            '本プライバシーポリシー（以下「本ポリシー」といいます。）は、当サービスが提供するモバイルアプリケーション「StillMe」における、ユーザーに関する情報（個人情報・個人データを含む）の取得、利用、保存、共有、削除および安全管理の方法を定めるものです。ユーザーは当サービスを利用することで、本ポリシーに同意したものとみなされます。' :
                            'This Privacy Policy (hereinafter referred to as the "Policy") defines the methods for acquiring, using, storing, sharing, deleting, and safely managing information related to users (including personal information and personal data) in the mobile application "StillMe" provided by the Service. By using the Service, users are deemed to have agreed to this Policy.'
                        }
                    </p>
                </div>

                {/* 1. Definitions */}
                <div className="space-y-4">
                    <h2 className="text-xl font-bold text-white border-l-4 border-blue-500 pl-4">
                        {lang === 'ja' ? '1. 用語の定義' : '1. Definitions'}
                    </h2>
                    <ul className="list-disc list-inside space-y-2">
                        <li>{lang === 'ja' ? '「個人情報」：特定の個人を識別できる情報（日本法における「個人情報」）。' : '"Personal Information": Information that can identify a specific individual (as defined under Japanese law).'}</li>
                        <li>{lang === 'ja' ? '「個人データ」：個人情報データベース等を構成する個人情報（日本法における「個人データ」）。' : '"Personal Data": Personal information constituting a personal information database, etc. (as defined under Japanese law).'}</li>
                        <li>{lang === 'ja' ? '「個人データの処理」：取得、記録、保存、編集、参照、利用、提供、削除等（GDPRの概念を含む）。' : '"Processing of Personal Data": Acquisition, recording, storage, editing, reference, use, provision, deletion, etc. (including the concept under GDPR).'}</li>
                        <li>{lang === 'ja' ? '「ユーザーコンテンツ」：ユーザーが当サービスに投稿・保存した写真、動画、テキスト、メタデータ等。' : '"User Content": Photos, videos, text, metadata, etc., posted and stored by the user on the Service.'}</li>
                        <li>{lang === 'ja' ? '「公開範囲」：ユーザーが投稿時に選択する閲覧可能者の範囲（全フレンド／特定フレンド）。' : '"Publication Scope": The range of viewable persons selected by the user at the time of posting (All Friends / Specific Friends).'}</li>
                        <li>{lang === 'ja' ? '「フレンド」：当サービス上で相互承認により接続したユーザー関係。' : '"Friend": A user relationship connected through mutual approval on the Service.'}</li>
                        <li>{lang === 'ja' ? '「委託先」：当サービスの業務（データ保存・処理等）を委託する第三者。' : '"Subcontractor": A third party to whom the Service entrusts operations (data storage/processing, etc.).'}</li>
                        <li>{lang === 'ja' ? '「EEA」：欧州経済領域。' : '"EEA": European Economic Area.'}</li>
                    </ul>
                </div>

                {/* 2. Administrator */}
                <div className="space-y-4">
                    <h2 className="text-xl font-bold text-white border-l-4 border-blue-500 pl-4">
                        {lang === 'ja' ? '2. 管理者（データ管理者）・連絡先' : '2. Administrator (Data Controller) and Contact Information'}
                    </h2>
                    <p>
                        {lang === 'ja' ?
                            '当サービスは、当サービスで取得する個人データの管理者（controller）として、処理の目的および手段を決定します。' :
                            'The Service, as the controller of personal data acquired through the Service, determines the purposes and means of processing.'
                        }
                    </p>
                    <div className="p-4 bg-white/5 rounded border border-white/10">
                        <p className="font-bold text-white mb-1">
                            {lang === 'ja' ? '本ポリシーに関する問い合わせ・権利行使の申出窓口：' : 'Inquiry and Rights Exercise Window for this Policy:'}
                        </p>
                        <p className="text-blue-400">{contactEmail}</p>
                    </div>
                </div>

                {/* 3. Information Collected */}
                <div className="space-y-4">
                    <h2 className="text-xl font-bold text-white border-l-4 border-blue-500 pl-4">
                        {lang === 'ja' ? '3. 取得する情報（固定一覧）' : '3. Information Collected (Fixed List)'}
                    </h2>
                    <p>
                        {lang === 'ja' ?
                            '当サービスが取得する情報を、種類・保存場所・利用目的まで固定して列挙します。本項に記載のない情報は取得しません。' :
                            'The information collected by the Service is listed below, spanning types, storage locations, and purposes of use. Information not mentioned in this section will not be collected.'
                        }
                    </p>

                    <div className="overflow-x-auto">
                        <table className="w-full text-sm text-left border-collapse">
                            <thead>
                                <tr className="bg-white/10 text-white">
                                    <th className="p-2 border border-white/20">{lang === 'ja' ? '区分' : 'Category'}</th>
                                    <th className="p-2 border border-white/20">{lang === 'ja' ? '取得する情報' : 'Information Collected'}</th>
                                    <th className="p-2 border border-white/20">{lang === 'ja' ? '保存場所' : 'Storage'}</th>
                                    <th className="p-2 border border-white/20">{lang === 'ja' ? '目的' : 'Purpose'}</th>
                                </tr>
                            </thead>
                            <tbody className="text-gray-400">
                                <tr>
                                    <td className="p-2 border border-white/10 text-white">{lang === 'ja' ? 'アカウント' : 'Account'}</td>
                                    <td className="p-2 border border-white/10">Firebase Auth UID</td>
                                    <td className="p-2 border border-white/10">Auth / Firestore</td>
                                    <td className="p-2 border border-white/10">{lang === 'ja' ? '本人識別' : 'Identification'}</td>
                                </tr>
                                <tr>
                                    <td className="p-2 border border-white/10 text-white">{lang === 'ja' ? 'プロフィール' : 'Profile'}</td>
                                    <td className="p-2 border border-white/10">{lang === 'ja' ? 'ハンドル、名、誕生日、画像' : 'Handle, Name, DOB, Avatar'}</td>
                                    <td className="p-2 border border-white/10">Firestore / Storage</td>
                                    <td className="p-2 border border-white/10">{lang === 'ja' ? '表示・検索' : 'Display/Search'}</td>
                                </tr>
                                <tr>
                                    <td className="p-2 border border-white/10 text-white">{lang === 'ja' ? '投稿' : 'Post'}</td>
                                    <td className="p-2 border border-white/10">{lang === 'ja' ? '写真（JPEG）、動画（MP4）' : 'Photos (JPEG), Video (MP4)'}</td>
                                    <td className="p-2 border border-white/10">Storage</td>
                                    <td className="p-2 border border-white/10">{lang === 'ja' ? '表示・共有' : 'Display/Sharing'}</td>
                                </tr>
                                <tr>
                                    <td className="p-2 border border-white/10 text-white">{lang === 'ja' ? 'メタデータ' : 'Metadata'}</td>
                                    <td className="p-2 border border-white/10">{lang === 'ja' ? '日時、公開範囲等' : 'Timestamp, Scope, etc.'}</td>
                                    <td className="p-2 border border-white/10">Firestore</td>
                                    <td className="p-2 border border-white/10">{lang === 'ja' ? '共有制御・履歴' : 'Control/History'}</td>
                                </tr>
                                <tr>
                                    <td className="p-2 border border-white/10 text-white">{lang === 'ja' ? '通知' : 'Notification'}</td>
                                    <td className="p-2 border border-white/10">{lang === 'ja' ? 'デバイストークン等' : 'Push Token, Settings'}</td>
                                    <td className="p-2 border border-white/10">Firestore</td>
                                    <td className="p-2 border border-white/10">{lang === 'ja' ? 'プッシュ通知' : 'Push Delivery'}</td>
                                </tr>
                            </tbody>
                        </table>
                    </div>
                    <p className="text-xs text-gray-400">
                        {lang === 'ja' ?
                            '※当サービスは広告配信SDKを導入していないため、広告識別子（IDFA等）を取得しません。' :
                            '*Because the Service does not use ad SDKs, it does not collect advertising identifiers (IDFA, etc.).'
                        }
                    </p>
                </div>

                {/* 4. Information NOT Collected */}
                <div className="space-y-4">
                    <h2 className="text-xl font-bold text-white border-l-4 border-blue-500 pl-4">
                        {lang === 'ja' ? '4. 取得しない情報（断定）' : '4. Information NOT Collected'}
                    </h2>
                    <p>
                        {lang === 'ja' ?
                            '当サービスは以下の情報を取得しません（アプリ設計および実装仕様により取得不可能、または送信しないため）。' :
                            'The Service does not collect the following information (either impossible to collect due to app design or simply not transmitted).'
                        }
                    </p>
                    <ul className="list-disc list-inside space-y-2">
                        <li>{lang === 'ja' ? 'GPS位置情報（位置情報権限を要求しない／Info.plistに記載がないため）' : 'GPS location info (as location permissions are not requested/required in Info.plist).'}</li>
                        <li>{lang === 'ja' ? '写真のEXIFメタデータ（位置情報・撮影日時等）' : 'EXIF metadata of photos (location, shooting timestamp, etc.).'}</li>
                        <li>{lang === 'ja' ? '動画の位置情報等のメタデータ' : 'Location and other metadata for videos.'}</li>
                        <li>{lang === 'ja' ? 'マイク音声（動画に音声を含めない仕様）' : 'Microphone audio (videos are silent by design).'}</li>
                    </ul>

                    <div className="bg-blue-600/10 p-4 rounded border border-blue-500/20 mt-4">
                        <h3 className="text-white font-bold mb-2">
                            {lang === 'ja' ? '4.1 EXIF削除の根拠（仕様）' : '4.1 Basis for EXIF Deletion (Specifications)'}
                        </h3>
                        <p className="text-sm">
                            {lang === 'ja' ?
                                '当サービスは、写真アップロード時に UIImage を jpegData でJPEGデータ化して送信します。この変換処理により、位置情報等のEXIFメタデータは保持されず、純粋な画像データのみがクラウドへ送信・保存されます。動画についても同様にメタデータを埋め込みません。' :
                                'When uploading photos, the Service converts UIImage to JPEG data using jpegData. Through this process, EXIF metadata such as location is discarded, and only pure image data is transmitted and stored. Similarly, metadata is not embedded during video export.'
                            }
                        </p>
                    </div>
                </div>

                {/* 5. Storage / International Transfer */}
                <div className="space-y-4">
                    <h2 className="text-xl font-bold text-white border-l-4 border-blue-500 pl-4">
                        {lang === 'ja' ? '5. 保存場所・国際データ移転' : '5. Storage and International Data Transfer'}
                    </h2>
                    <ul className="list-disc list-inside space-y-2">
                        <li>{lang === 'ja' ? '当サービスは Google LLC が提供する Firebase（米国USリージョン）を利用します。' : 'The Service utilizes Firebase provided by Google LLC (specifically the US region).'}</li>
                        <li>{lang === 'ja' ? 'ユーザーのデータは米国に設置されたサーバーに保存されます。' : 'User data is stored on servers located in the United States.'}</li>
                        <li>{lang === 'ja' ? 'EEA/英国のユーザーについては、適用法令に基づき適切な保護措置（SCC等）を用います。' : 'For users in the EEA/UK, appropriate safeguards (such as SCCs) are applied in accordance with applicable laws.'}</li>
                    </ul>
                </div>

                {/* 6. Purpose of Use */}
                <div className="space-y-4">
                    <h2 className="text-xl font-bold text-white border-l-4 border-blue-500 pl-4">
                        {lang === 'ja' ? '6. 利用目的' : '6. Purposes of Use'}
                    </h2>
                    <p>{lang === 'ja' ? '取得した情報を次の目的に限り利用します。' : 'Collected information is used exclusively for the following purposes:'}</p>
                    <ul className="list-disc list-inside space-y-2 text-sm">
                        <li>{lang === 'ja' ? 'アカウント認証、本人識別、ログイン維持' : 'Account authentication, identification, and maintaining login state.'}</li>
                        <li>{lang === 'ja' ? 'プロフィール表示（ニックネーム・アバター等）' : 'Profile display (nicknames, avatars, etc.).'}</li>
                        <li>{lang === 'ja' ? 'フレンド機能（検索、招待、承認、一覧）' : 'Friend features (search, invitation, approval, list).'}</li>
                        <li>{lang === 'ja' ? '写真・動画の保存、表示、共有制御' : 'Storing, displaying, and controlling the sharing of photos/videos.'}</li>
                        <li>{lang === 'ja' ? 'カレンダー・履歴表示（振り返り機能）' : 'Calendar and history display (Review feature).'}</li>
                        <li>{lang === 'ja' ? 'ブロック機能、通報対応、モデレーション' : 'Blocking features, responding to reports, and moderation.'}</li>
                        <li>{lang === 'ja' ? '不正防止、セキュリティ確保、障害解析' : 'Fraud prevention, safety and security, and failure analysis.'}</li>
                        <li>{lang === 'ja' ? 'リマインダー通知（ONにした場合のみ）' : 'Reminder notifications (only if enabled by the user).'}</li>
                    </ul>
                </div>

                {/* 11. Retention / Deletion */}
                <div className="space-y-4">
                    <h2 className="text-xl font-bold text-white border-l-4 border-blue-500 pl-4">
                        {lang === 'ja' ? '11. 保持期間・削除（30日ルール）' : '11. Retention and Deletion (30-Day Rule)'}
                    </h2>
                    <div className="pl-4 border-l-2 border-white/5 space-y-4">
                        <div>
                            <h3 className="font-semibold text-white mb-1">{lang === 'ja' ? '11.1 退会（アカウント削除）' : '11.1 Withdrawal (Account Deletion)'}</h3>
                            <ul className="list-disc list-inside space-y-1">
                                <li>{lang === 'ja' ? '退会後、復旧対応のため最大30日間データを保持します。' : 'After withdrawal, data is retained for up to 30 days for restoration purposes.'}</li>
                                <li>{lang === 'ja' ? '30日経過後、Firestore、Storage、Auth上の全データを物理削除します。' : 'After 30 days, all data on Firestore, Storage, and Auth is physically deleted.'}</li>
                            </ul>
                        </div>
                        <div>
                            <h3 className="font-semibold text-white mb-1">{lang === 'ja' ? '11.2 ログ保持' : '11.2 Log Retention'}</h3>
                            <p className="text-sm">{lang === 'ja' ? '法令遵守やセキュリティに不可欠なログは、必要な期間保持することがあります。' : 'Logs essential for legal compliance and security may be retained for the required period.'}</p>
                        </div>
                    </div>
                </div>

                {/* 16. Analytics / Ads */}
                <div className="space-y-4">
                    <h2 className="text-xl font-bold text-white border-l-4 border-blue-500 pl-4">
                        {lang === 'ja' ? '16. 解析・広告（導入なし）' : '16. Analytics and Ads (Not Implemented)'}
                    </h2>
                    <p>
                        {lang === 'ja' ?
                            '当サービスは、2026-02-22時点で、広告配信のための第三者SDKの導入や、行動ターゲティング広告を行いません。将来解析ツール等を導入する場合は、本ポリシーを改定して明示します。' :
                            'As of February 22, 2026, the Service does not use third-party SDKs for advertising or perform behavioral targeting. Should analytics tools be introduced in the future, this Policy will be revised to reflect such changes.'
                        }
                    </p>
                </div>

                {/* 18. Inquiry */}
                <div className="space-y-4">
                    <h2 className="text-xl font-bold text-white border-l-4 border-blue-500 pl-4">
                        {lang === 'ja' ? '18. 問い合わせ窓口' : '18. Contact Information'}
                    </h2>
                    <div className="mt-4 p-4 bg-yellow-500/10 border border-yellow-500/30 rounded">
                        <p className="font-bold text-yellow-500 mb-1">
                            {lang === 'ja' ? 'プライバシーに関する問い合わせ先：' : 'For Privacy Inquiries:'}
                        </p>
                        <p className="text-white">{contactEmail}</p>
                    </div>
                </div>

                <div className="mt-12 pt-8 border-t border-white/10 text-right">
                    <p className="font-bold text-white">{lang === 'ja' ? '付則' : 'Supplementary Provisions'}</p>
                    <p className="text-sm">
                        {lang === 'ja' ? '2026年2月22日 制定' : 'Enacted: February 22, 2026'}
                    </p>
                </div>
            </section>
        </div>
    );
}
