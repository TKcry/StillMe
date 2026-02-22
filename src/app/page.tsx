import Link from "next/link";

export default function Home() {
  return (
    <div className="flex flex-col items-center justify-center min-h-screen space-y-6">
      <h1 className="text-4xl font-bold tracking-tighter">StillMe</h1>
      <div className="flex space-x-4">
        <Link href="/terms" className="text-gray-400 hover:text-white transition-colors">利用規約</Link>
        <span className="text-gray-600">|</span>
        <Link href="/privacy" className="text-gray-400 hover:text-white transition-colors">プライバシーポリシー</Link>
      </div>
    </div>
  );
}
