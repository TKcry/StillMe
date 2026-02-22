'use client';

import React, { useState, useEffect } from 'react';

export default function PrivacyPolicy() {
    const [lang, setLang] = useState<'en' | 'ja'>('en');

    useEffect(() => {
        if (typeof window !== 'undefined' && navigator.language.startsWith('ja')) {
            setLang('ja');
        }
    }, []);

    const toggleLang = () => {
        setLang(lang === 'en' ? 'ja' : 'en');
    };

    return (
        <div className="max-w-4xl mx-auto py-12 px-6">
            <div className="flex justify-between items-start mb-8">
                <div>
                    <h1 className="text-3xl font-bold mb-2">
                        {lang === 'ja' ? 'プライバシーポリシー' : 'Privacy Policy'}
                    </h1>
                </div>
                <button
                    onClick={toggleLang}
                    className="px-4 py-2 bg-blue-600 hover:bg-blue-500 text-white rounded-full text-sm font-bold transition-colors shadow-lg"
                >
                    {lang === 'ja' ? 'English' : '日本語'}
                </button>
            </div>

            <section className="space-y-8 text-gray-300">
                <p>
                    {lang === 'ja' ?
                        'StillMe（以下，「当サービス」といいます。）は，本サービスにおいて提供するサービスにおける，ユーザーの個人情報の取扱いについて，以下のとおりプライバシーポリシー（以下，「本ポリシー」といいます。）を定めます。' :
                        'StillMe (hereinafter referred to as "the Service") defines the following privacy policy (hereinafter referred to as the "Policy") regarding the handling of personal information of users in the services provided by the Service.'
                    }
                </p>

                <div className="space-y-4">
                    <h2 className="text-xl font-semibold text-white border-l-4 border-blue-500 pl-4">
                        {lang === 'ja' ? '第1条（個人情報の収集方法）' : 'Article 1 (Method of Collecting Personal Information)'}
                    </h2>
                    <p>
                        {lang === 'ja' ?
                            '当サービスは，ユーザーが利用登録をする際にニックネーム，メールアドレスなどの個人情報をお尋ねすることがあります。また、サービス内で撮影された写真は、暗号化され安全に保存されます。' :
                            'The Service may ask for personal information such as nicknames and email addresses when a User registers for use. Additionally, photos taken within the service are encrypted and stored securely.'
                        }
                    </p>
                </div>

                <div className="space-y-4">
                    <h2 className="text-xl font-semibold text-white border-l-4 border-blue-500 pl-4">
                        {lang === 'ja' ? '第2条（個人情報を収集・利用する目的）' : 'Article 2 (Purpose of Collecting and Using Personal Information)'}
                    </h2>
                    <p>
                        {lang === 'ja' ?
                            '当サービスが個人情報を収集・利用する目的は，本サービスの提供・運営のため、および本人確認のためです。' :
                            'The purposes for which the Service collects and uses personal information are for providing and operating the Service, and for identity verification.'
                        }
                    </p>
                </div>

                <div className="space-y-4">
                    <h2 className="text-xl font-semibold text-white border-l-4 border-blue-500 pl-4">
                        {lang === 'ja' ? '第3条（利用目的の変更）' : 'Article 3 (Change of Purpose of Use)'}
                    </h2>
                    <p>
                        {lang === 'ja' ?
                            '当サービスは，利用目的が変更前と関連性を有すると合理的に認められる場合に限り，個人情報の利用目的を変更するものとします。' :
                            'The Service shall change the purpose of use of personal information only when it is reasonably recognized that the purpose of use after the change is relevant to that before the change.'
                        }
                    </p>
                </div>

                <div className="space-y-4">
                    <h2 className="text-xl font-semibold text-white border-l-4 border-blue-500 pl-4">
                        {lang === 'ja' ? '第4条（個人情報の第三者提供）' : 'Article 4 (Provision of Personal Information to Third Parties)'}
                    </h2>
                    <p>
                        {lang === 'ja' ?
                            '当サービスは，法令に定める場合を除き，あらかじめユーザーの同意を得ることなく，第三者に個人情報を提供することはありません。' :
                            'The Service will not provide personal information to a third party without obtaining the prior consent of the User, except as provided by laws and regulations.'
                        }
                    </p>
                </div>

                <div className="mt-12 pt-8 border-t border-white/10 text-right text-sm">
                    {lang === 'ja' ? '附則：2026年2月22日 制定' : 'Supplementary Provision: Enacted February 22, 2026'}
                </div>
            </section>
        </div>
    );
}
