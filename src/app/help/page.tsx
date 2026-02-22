'use client';

import React, { useState, useEffect } from 'react';

export default function HelpCenter() {
    const [lang, setLang] = useState<'en' | 'ja'>('en');

    useEffect(() => {
        if (typeof window !== 'undefined' && navigator.language.startsWith('ja')) {
            setLang('ja');
        }
    }, []);

    const contactEmail = 'official.stillme@gmail.com';

    return (
        <div className="max-w-4xl mx-auto py-12 px-6">
            <div className="flex justify-between items-start mb-8">
                <div>
                    <h1 className="text-3xl font-bold mb-2">
                        {lang === 'ja' ? 'ヘルプセンター' : 'Help Center'}
                    </h1>
                    <p className="text-sm text-gray-400">
                        {lang === 'ja' ? 'StillMeの使い方ガイド' : 'Guide to using StillMe'}
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

            <section className="space-y-12 text-gray-300">
                {/* 1. Today Tab Guide */}
                <div className="space-y-4">
                    <h2 className="text-xl font-bold text-white border-l-4 border-blue-500 pl-4">
                        {lang === 'ja' ? '1. 今日の写真（Todayタブ）の使い方' : '1. Using Today\'s Photo (Today Tab)'}
                    </h2>
                    <div className="bg-white/5 p-6 rounded-lg border border-white/10 space-y-4">
                        <p>
                            {lang === 'ja' ?
                                'Todayタブは、あなたとフレンドの「今」を共有するメイン画面です。' :
                                'The Today tab is the main screen for sharing the "now" with you and your friends.'}
                        </p>
                        <ul className="list-disc list-inside space-y-2">
                            <li>
                                <strong>{lang === 'ja' ? '撮影する' : 'Capturing'}</strong>:
                                {lang === 'ja' ?
                                    'シャッターを押すと、フロントとバックのカメラで同時に「今」を切り取ります。' :
                                    'Press the shutter to capture the "now" with both front and back cameras simultaneously.'}
                            </li>
                            <li>
                                <strong>{lang === 'ja' ? 'Moment（動く写真）' : 'Moment (Moving Photo)'}</strong>:
                                {lang === 'ja' ?
                                    '静止画だけでなく、シャッターを切る前後の数秒間も「動く思い出」として保存されます。' :
                                    'In addition to the still photo, a few seconds before and after the shutter are saved as a "moving memory".'}
                            </li>
                            <li>
                                <strong>{lang === 'ja' ? 'シェアする' : 'Sharing'}</strong>:
                                {lang === 'ja' ?
                                    '投稿はリアルタイムでフレンドに届きます。公開範囲を指定して、特定の相手だけに送ることも可能です。' :
                                    'Posts reach your friends in real-time. You can also specify the publication scope to send to only specific people.'}
                            </li>
                        </ul>
                    </div>
                </div>

                {/* 2. Pairing & Disconnecting */}
                <div className="space-y-4">
                    <h2 className="text-xl font-bold text-white border-l-4 border-blue-500 pl-4">
                        {lang === 'ja' ? '2. ペアの状態と解消について' : '2. Pairing and Disconnecting'}
                    </h2>
                    <div className="bg-white/5 p-6 rounded-lg border border-white/10 space-y-4">
                        <p>
                            {lang === 'ja' ?
                                'StillMeは相互承認した相手と「ペア」になって楽しみます。' :
                                'StillMe is enjoyed by becoming a "pair" with mutually approved partners.'}
                        </p>
                        <div className="space-y-4">
                            <h3 className="text-white font-semibold">{lang === 'ja' ? 'ペアを解消（フレンド解除）するとどうなる？' : 'What happens if you unpair (unfriend)?'}</h3>
                            <ul className="list-disc list-inside space-y-1 text-sm">
                                <li>{lang === 'ja' ? '双方のフレンド一覧から相手が消え、お互いの投稿が見られなくなります。' : 'The partner disappears from both friend lists, and you can no longer see each other\'s posts.'}</li>
                                <li>{lang === 'ja' ? 'ペア解消後、30日間はデータが保持されます。30日以内に再接続すれば、過去の思い出も復旧します。' : 'Data is retained for 30 days after unpairing. If you reconnect within 30 days, past memories will be restored.'}</li>
                                <li>{lang === 'ja' ? '30日を過ぎてから再接続した場合、過去の投稿履歴（カレンダー等）はリセットされます。' : 'If you reconnect after 30 days, past post history (calendars, etc.) will be reset.'}</li>
                            </ul>
                        </div>
                    </div>
                </div>

                {/* 3. Account Deletion */}
                <div className="space-y-4">
                    <h2 className="text-xl font-bold text-white border-l-4 border-blue-500 pl-4">
                        {lang === 'ja' ? '3. アカウント削除（退会）' : '3. Account Deletion (Withdrawal)'}
                    </h2>
                    <div className="bg-white/5 p-6 rounded-lg border border-white/10 space-y-4">
                        <p>
                            {lang === 'ja' ?
                                'アカウントを削除すると、StillMe上のすべてのデータにアクセスできなくなります。' :
                                'Deleting your account means you will lose access to all data on StillMe.'}
                        </p>
                        <div className="p-4 bg-red-500/10 border border-red-500/20 rounded">
                            <h3 className="text-red-400 font-bold mb-2">{lang === 'ja' ? '重要事項' : 'Important Notice'}</h3>
                            <ul className="list-disc list-inside space-y-1 text-sm text-gray-300">
                                <li>{lang === 'ja' ? '退会後、すべてのペア関係が解消されます。' : 'After withdrawal, all pair relationships are dissolved.'}</li>
                                <li>{lang === 'ja' ? 'セキュリティのため、完全にデータが削除されるまで30日間の猶予期間があります。' : 'For security reasons, there is a 30-day grace period before data is permanently deleted.'}</li>
                                <li>{lang === 'ja' ? '30日以内であれば、同じアカウントで再ログインすることで退会を取り消し、データを復旧できます。' : 'Within 30 days, you can cancel the withdrawal and restore your data by logging back in with the same account.'}</li>
                                <li>{lang === 'ja' ? '30日経過後は、写真や動画を含むすべてのデータが完全に消去され、復旧はできなくなります。' : 'After 30 days, all data including photos and videos will be completely erased and cannot be recovered.'}</li>
                            </ul>
                        </div>
                    </div>
                </div>

                {/* 4. Troubleshooting & Contact */}
                <div className="space-y-4">
                    <h2 className="text-xl font-bold text-white border-l-4 border-blue-500 pl-4">
                        {lang === 'ja' ? '4. お問い合わせ' : '4. Contact Us'}
                    </h2>
                    <div className="bg-white/5 p-6 rounded-lg border border-white/10">
                        <p className="mb-4">
                            {lang === 'ja' ?
                                'アプリの不具合や、その他ご不明な点がありましたら下記までメールにてお問い合わせください。' :
                                'If you encounter any app issues or have other questions, please contact us via email below.'}
                        </p>
                        <p className="text-blue-400 font-bold">{contactEmail}</p>
                    </div>
                </div>

                <div className="mt-12 pt-8 border-t border-white/10 text-right text-xs text-gray-500">
                    <p>© 2026 StillMe</p>
                </div>
            </section>
        </div>
    );
}
